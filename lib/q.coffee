path = require('path')
fs = require('fs')
async = require('async')
Buffers = require('buffers')
unzip = require('unzip')
_ = require('underscore')

qStore = require 'q-fs-store'

Packer = require('./Packer')
Unpacker = require('./Unpacker')

sha1 = require('./sha1')
calculateListingUid = require('./calculateListingUid')
listing = require('./listing')

# Exports all errors
module.exports = class Q

    DEFAULT_OPTIONS = 
        store:new qStore(path:process.cwd())
    
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
        
        zipClosed = no
        packageListing = null

        zip = packageStream.pipe(unzip.Parse())
        zip.on 'entry', (entry) =>
            
            if @_isListingEntry entry
                foundListing = yes
                @_readObjectFromStream entry, (err, listingFound)->

                    packageListing = listingFound
                    packageListing.uid = calculateListingUid(packageListing)
                    
                    if zipClosed
                        callback(null, packageListing)
            else
                entry.autodrain()

        zip.on 'close', ()=>
            zipClosed = yes
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
                    
                    result = @_verifyListing(calculatedListing, storedListing)
                    callback(null, result)

    _verifyListing: (actualListing, expectedListing)->

        result = 
            valid: actualListing.uid is expectedListing.uid
            filesManipulated: no
            uid: actualListing.uid
            files: actualListing.files

        result.files.forEach (actualFile)->
            expectedFile = _.find expectedListing.files, (f)->f.name is actualFile.name
            
            if not expectedFile 
                actualFile.extra = yes
            else
                actualFile.valid = actualFile.sha1 is expectedFile.sha1
                result.valid = false unless actualFile.valid
                result.filesManipulated = true unless actualFile.valid

        return result

    verifyPackage: (packageIdentifier, callback) ->

        #callback()

        verifyQueue = async.queue(@_verifySha1, 100)

        @listPackageContent packageIdentifier, (err,listing)=>
            return callback(err) if err

            result = listing
            result.valid = true
            result.extraFiles = []
        
            @_readPackage packageIdentifier, (err, packageStream)=>
                zip = packageStream.pipe(unzip.Parse())
                zip.on 'entry', (entry) ->
                    
                    if entry.path is '.q.listing'
                        entry.autodrain()
                    else
                        listEntry = _.find listing.files, (f)->f.name is entry.path

                        if not listEntry
                            result.extraFiles.push( entry.path )
                            entry.autodrain()
                        else
                            verifyQueue.push result:result, listEntry:listEntry, stream:entry

                zip.on 'close', ()->
                    if verifyQueue.length() == 0
                        callback(null,result)
                    else
                        verifyQueue.drain = ()->
                            callback(null,result)

    _verifySha1: (job, callback)->

        sha1.calculate job.stream, (err,hash)->
            if job.listEntry.sha1 isnt hash
                job.result.valid = false
                job.listEntry.valid = false
            else
                job.listEntry.valid = true

            callback(null)

    _isListingEntry: (entry)->entry.path is '.q.listing'

    _readObjectFromStream: (stream, callback)->

        bufs = Buffers();

        stream.on 'error', (error)->
            callback(error)
        stream.on 'data', (data)->
            bufs.push(data)
        stream.on 'end', ()->
            json = bufs.toString('utf8')
            callback( null, JSON.parse( json ) )
