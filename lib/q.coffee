path = require('path')
fs = require('fs')

_ = require('underscore')
Buffers = require('buffers')
AdmZip = require('adm-zip')
async = require('async')
signer = require('ssh-signer')
streamBuffers = require('stream-buffers')
temp = require('temp')
sha1 = require('./sha1')
superagent = require('superagent')
qStore = require('q-fs-store')
bs = require('bsdiff-bin')
humanize = require('humanize')

Packer = require('./Packer')
Unpacker = require('./Unpacker')

calculateListingUid = require('./calculateListingUid')
listing = require('./listing')


# Exports all errors
module.exports = class Q

    DEFAULT_OPTIONS = 
        store:new qStore(path:process.cwd())
        verifyRequiresSignature: yes
        minForPatch: 128 # packages smaller than 'minForDiff' kb are uploaded without diff
        patch: yes
    
    constructor: (options={})->
        @options = _.defaults options, DEFAULT_OPTIONS
        @errors = require('./errors')

    pack: (manifestPath, callback)->

        if not manifestPath
            throw new @errors.ArgumentError("missing path to manifest")

        p = new Packer(@options)

        async.series [ 
            (cb)->p.create(manifestPath,cb)
            (cb)->p.saveToCache(cb)
            ],
            (err)->callback(err,p)
        
        return p   

    unpack: (packageIdentifier, targetDir, callback)->

        if not packageIdentifier
            throw new @errors.ArgumentError("packageIdentifier is required")

        if not targetDir
            throw new @errors.ArgumentError("targetDir is required")

        @_readPackage packageIdentifier, (err,packageStream)->
            return callback(err) if err

            u = new Unpacker()
            u.unpack(packageStream, targetDir, callback)

    publish: (packageIdentifier, targetUrl, callback)->
        
        console.log "#{packageIdentifier} => #{targetUrl}"

        @listPackageContent packageIdentifier, (err, content)=>
            return callback(err) if err
            
            request = superagent.agent()
            
            packageUrl = "#{targetUrl}/packages/#{content.name}"
            latestServerPackageUrl = "#{packageUrl}/latest"

            request.get(latestServerPackageUrl).end (err,res)=>
        
                return callback(err) if err

                if res.status is 404 or not @options.patch
                    @_uploadFullPackage request, packageIdentifier, "#{targetUrl}/packages", (res)->
                        return callback(null) if res.ok
                            
                        callback(res.statusCode)
                else
                    return callback('error') if not res.ok

                    latestServerPackage = res.body

                    if latestServerPackage.version == content.version
                        return callback('version already on target server')

                    @_attemptUploadPatch packageIdentifier, latestServerPackage, packageUrl, request, (err)=>
                        
                        return callback(null) unless err
                        console.log "could not upload patch trying full upload", err
                        return
                        
                        @_uploadFullPackage request, packageIdentifier, "#{targetUrl}/packages", (res)->
                            return callback(null) if res.ok
                            
                            callback(res.statusCode)

    _attemptUploadPatch: (packageIdentifier, serverPackageInfo, packageUrl, request, callback)->
            
        @options.store.getPackageStoragePath packageIdentifier, (err, packagePath)=>
            return callback(err) if err
           
            return callback('too small') if fs.statSync(packagePath).size / 1024 < @options.minForPatch
           
            @_accessPreviousPackagePathForDiff serverPackageInfo, packageUrl, request, (err,previousVersionPath,args)=>
                return callback(err) if err

                patchPath = temp.path(suffix:'.patch')
                bs.diff previousVersionPath, packagePath, patchPath, (err)=>
                    return callback(err) if err

                    originalSize = fs.statSync(packagePath).size
                    patchSize = fs.statSync(patchPath).size
                    savedBytes = originalSize-patchSize

                    console.log "uploading #{humanize.filesize(patchSize)} ... (saved #{humanize.filesize(savedBytes)})"
                    
                    previousVersionUrl = "#{packageUrl}/#{serverPackageInfo.version}"
                    @_uploadPatch request, patchPath, previousVersionUrl, (err)=>
                        fs.unlinkSync(patchPath)
                        fs.unlinkSync(previousVersionPath) if args.deleteAfterUse
                        callback(err)

    _accessPreviousPackagePathForDiff: (serverPackageInfo, serverPackageUrl, request, callback)->

        @options.store.getInfo serverPackageInfo.name, serverPackageInfo.version, (err, localInfo)=>

            canUseLocalPackageForDiff = (not err and serverPackageInfo.uid is localInfo.uid)

            if canUseLocalPackageForDiff
                @options.store.getPackageStoragePath "#{serverPackageInfo.name}@#{serverPackageInfo.version}", (err, packagePath)=>
                    return callback(err) if err
                    callback(null, packagePath, deleteAfterUse:false)
            else
                console.log "previous version not locally available or usable, downloading..."

                previousVersionUrl = "#{serverPackageUrl}/#{serverPackageInfo.version}"
                downloadUrl = "#{previousVersionUrl}/download"

                downloadRequest = request.get(downloadUrl)
                    
                downloadPath = temp.path(suffix:'.pkg')
                downloadStream = fs.createWriteStream(downloadPath)
                downloadRequest.pipe(downloadStream)

                downloadStream.on 'close',(err)=>
                    return callback(err) if err           
                    callback(null, downloadPath, deleteAfterUse:true)

    _uploadPatch: (request, patchPath, previousVersionUrl, callback)->
        patchUrl = "#{previousVersionUrl}/patch"
        request.post(patchUrl)
            .attach('upload.patch', patchPath)
            .end (err,res)->
                return callback(err) if err
                return callback(res.statusCode) unless res.ok
                callback(null)
    _uploadFullPackage: (request, packageIdentifier, targetUrl, callback)->

        @options.store.getPackageStoragePath packageIdentifier, (err, packagePath)=>
            return callback(err) if err

            packageSize = fs.statSync(packagePath).size            
            console.log "uploading #{humanize.filesize(packageSize)} ..."

            req = request.post(targetUrl)
                .attach(packageIdentifier+'.pkg', packagePath)
                .end(callback)
            
    listPackageContent: (packageIdentifier, callback) ->        
        @_readPackage packageIdentifier, (err, packageStream)=>
            return callback(err) if err
            @_listPackageStreamContent(packageStream, callback)

    _readPackage: (packageIdentifier, callback)->
        if not packageIdentifier
            throw new @errors.ArgumentError("packageIdentifier is required")

        fs.exists packageIdentifier, (exists)=>
            if exists
                packageStream = fs.createReadStream(packageIdentifier)
                callback(null, packageStream)
            else
                @options.store.readPackage packageIdentifier, callback

    _listPackageStreamContent: (packageStream, callback)->
        
        packageListing = null

        @_loadZip packageStream, (err,zip)=>
            return callback(err) if err

            zipEntries = zip.getEntries()
            
            zipEntries.forEach (entry)=>
                if @_isListingEntry(entry)
                    content = entry.getData().toString('utf8')
                    packageListing = JSON.parse(content)
        
            if not packageListing
                callback(new @errors.NoListingError("No .q.listing file in package")) 
            else 
                callback(null, packageListing)

    verifyDirectory: (packageDirectoryPath, callback) ->

        if not packageDirectoryPath
            throw new @errors.ArgumentError("packageDirectoryPath is required")

        listingPath = path.join(packageDirectoryPath, '.q.listing')

        fs.exists listingPath, (exists)=>
            if not exists
                return callback(new @errors.NoListingError(".q.listing expected at #{listingPath}"))

            fs.readFile listingPath, encoding:'utf8', (err,content)=>
                return callback(err) if err

                storedListing = JSON.parse(content)

                listing.createFromDirectory packageDirectoryPath, storedListing, (err,calculatedListing)=>
                    
                    calculatedListing.signedBy = storedListing.signedBy
                    calculatedListing.uid = calculateListingUid(calculatedListing)

                    result = @_verifyListing(calculatedListing, storedListing)
                    callback(null, result)

    _verifyListing: (actualListing, expectedListing)->

        result = 
            verified: actualListing.uid is expectedListing.uid
            errors: []
            filesManipulated: no
            uid: actualListing.uid
            files: actualListing.files
        
        if @options.verifyRequiresSignature
            if actualListing.signature
                result.verified = !!result.signed
                if not result.verified
                        result.errors.push( "could not find matching key for signature")
                    else
                        console.log "verified: signedBy #{result.signed}"
            else
                result.verified = no    
                result.errors.push( "package has no signature" )

        result.files.forEach (actualFile)->
            expectedFile = _.find expectedListing.files, (f)->f.name is actualFile.name
            
            if not expectedFile 
                actualFile.extra = yes
            else
                actualFile.verified = actualFile.sha1 is expectedFile.sha1
                result.verified = false unless actualFile.verified
                result.filesManipulated = true unless actualFile.verified

        return result

    verifyPackage: (packageIdentifier, callback) ->

        @listPackageContent packageIdentifier, (err,listing)=>
            return callback(err) if err

            result = listing
            result.verified = (listing.uid == calculateListingUid(listing))

            result.errors = []
            result.extraFiles = []
            
            if not result.verified 
                result.errors.push( "listing uid does not match files" )

            if @options.keys
                if not listing.signature
                    result.signed = null
                else
                    result.signed = @_findSigningKey listing, @options.keys
                    

            if @options.verifyRequiresSignature
                if listing.signature
                    result.verified = !!result.signed
                    if not result.verified
                        result.errors.push( "could not find matching key for signature")
                    else
                        console.log "verified: signedBy #{result.signed}"
                else
                    result.verified = no    
                    result.errors.push( "package has no signature" )


            @_readPackage packageIdentifier, (err, packageStream)=>
             
                @_loadZip packageStream, (err,zip)=>
                    return callback(err) if err

                    verifyQueue = async.queue(@_verifySha1, 1)
                    verifyQueue.drain = ()->callback(null,result)

                    zipEntries = zip.getEntries()

                    zipEntries.forEach (entry)=>
                        listEntry = _.find listing.files, (f)->f.name is entry.entryName

                        if not listEntry
                            if not @_isListingEntry entry
                                result.extraFiles.push( entry.entryName )
                        else
                            verifyQueue.push result:result, listEntry:listEntry, data:entry.getData()
    
    _loadZip: (stream, callback)=>
        zipBufferStream = new streamBuffers.WritableStreamBuffer()
        stream.pipe(zipBufferStream)

        zipBufferStream.on 'close', ()->
            zip = new AdmZip(zipBufferStream.getContents())
            callback(null,zip)

    _findSigningKey: (listing, keys)->

        for own name in Object.keys(keys)
            signed = @_listingWasSignedWith(listing,keys[name])
            return name if signed        

    _listingWasSignedWith: (listing,key)->

        signerOptions = 
            alg: 'RSA-SHA256'
            hash: 'base64'

        value = listing.uid + listing.signedBy

        return signer.verifyStr( listing.signature, value, key, signerOptions )

    _verifySha1: (job, callback)->

        hash = sha1.calculate job.data

        if job.listEntry.sha1 isnt hash
            job.result.verified = false
            job.listEntry.verified = false
        else
            job.listEntry.verified = true

        callback(null)

    _isListingEntry: (entry)->entry.entryName is '.q.listing'

    _readObjectFromStream: (stream, callback)->

        bufs = Buffers();

        stream.on 'error', (error)->
            callback(error)
        stream.on 'data', (data)->
            bufs.push(data)
        stream.on 'end', ()->
            json = bufs.toString('utf8')
            callback( null, JSON.parse( json ) )
