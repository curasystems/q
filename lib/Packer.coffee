util = require('util')
events = require('events')
path = require('path')
fs = require('fs')
crypto = require('crypto')

_ = require('underscore')
mkdirp = require('mkdirp')
lazystream = require('lazystream')
async = require('async')
semver = require('semver')
archiver = require('archiver')
signer = require('ssh-signer')

errors = require('./errors')

listing = require('./listing')
gatherFiles = require('./gatherFiles')
readManifest = require('./readManifest')
calculateListingUid = require('./calculateListingUid')

module.exports = class Packer extends events.EventEmitter

    DEFAULT_OPTIONS = 
        store: null
        manifestName: 'q.manifest'

    constructor: (options={})->

        @options = _.defaults(options, DEFAULT_OPTIONS)

        @name = null
        @version = null
        @description = null
        @files = []
        @path = null
        @manifestPath = null
        @listing = null

    create: (folderPath, callback)->

        @path = path.normalize(folderPath)
        
        async.waterfall [
                (cb)=>
                    readManifest(folderPath, @options.manifestName, cb)
                ,(manifestPath, manifest, cb)=>
                    @manifestPath = manifestPath
                    @_processManifest manifest, (err)->
                        cb(err,manifest)
                ,(manifest, cb)=>
                    @_createListing(manifest, cb)
                ,(cb)=>
                    @_sign(cb)
            ],
            (err)=>
                @emit 'end'
                callback(err)
  
    _processManifest: (manifest, callback)->
        
        @name = manifest.name
        @version = manifest.version
        @description = manifest.description
        @signed = false

        if not @name 
            return callback(new errors.InvalidManifestError("missing package name"))
        if not semver.valid(@version)
            return callback(new errors.InvalidManifestError("invalid version in package => #{@name}/version = '#{@version}'"))
        if not @description
            return callback(new errors.InvalidManifestError("package must have a description"))

        callback(null)

    _createListing: (manifest,callback)->
        listing.createFromDirectory @path, manifest, (err,directoryListing)=>
            return callback(err) if err
            
            @listing = directoryListing
            @listing.signedBy = @options.signedBy
            @listing.uid = calculateListingUid(@listing)
            @uid = @listing.uid

            callback(null)

    _sign: (cb)->
        if @options.key and @options.signedBy

            signerOptions = 
                alg: 'hmac-sha256'
                hash: 'base64'

            key = @options.key
            value = @listing.uid + @options.signedBy

            @signature = signer.signPrivateKeyStr( value, key, signerOptions )
            @listing.signature = @signature

            @signed = true
            @signedBy = @options.signedBy

            

        cb()

    saveToCache: (callback)->
        
        packageInfo =
            uid: @uid
            name: @name
            version: @version
            description: @description

        @options.store.writePackage packageInfo, (error,packageWriteStream)=>
    
            @_createPackageStream (err,packageStream)->
                packageStream.pipe(packageWriteStream)                
                packageWriteStream.on 'close', callback

    _createPackageStream: (callback)->
        archive = archiver('zip');
        archive.append JSON.stringify(@listing,null, " "), {name:'.q.listing'}

        @listing.files.forEach (file)=>

            filePath = path.join @path, file.name

            lazyFileStream = new lazystream.Readable ()->
                return fs.createReadStream(filePath)
            archive.append(lazyFileStream, {name:file.name})

        archive.finalize()
        callback(null,archive)        
