mkdirp = require('mkdirp')
util = require('util')
events = require('events')
lazystream = require('lazystream')

async = require('async')
semver = require('semver')

_ = require('underscore')
archiver = require('archiver')

errors = require('./errors')

listing = require('./listing')
gatherFiles = require('./gatherFiles')
readManifest = require('./readManifest')
calculateListingUid = require('./calculateListingUid')

module.exports = class Packer extends events.EventEmitter

    DEFAULT_OPTIONS = 
        manifestName: 'q.manifest'

    constructor: (options={})->

        @options = _.defaults(options, DEFAULT_OPTIONS)

        @name = null
        @version = null
        @description = null
        @files = []
        @path = null
        @manifestPath = null
        @cachePath = null
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
            ],
            (err)=>
                @emit 'end'
                callback(err)
  
    _processManifest: (manifest, callback)->
        
        @name = manifest.name
        @version = manifest.version
        @description = manifest.description

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
            #console.log directoryListing
            @listing = directoryListing
            @uid = directoryListing.uid
            callback(null)

    saveToCache: (callback)->

        @cachePath = @_buildCachePath()
        mkdirp path.dirname(@cachePath), (err)=>
            return callback(err) if err

            archive = archiver('zip');
            archive.on 'error', (err)->callback(err)

            output = fs.createWriteStream @cachePath
            archive.pipe(output)
            
            archive.append JSON.stringify(@listing,null, " "), {name:'.q.listing'}

            @listing.files.forEach (file)=>

                filePath = path.join @path, file.name

                lazyFileStream = new lazystream.Readable ()->
                    return fs.createReadStream(filePath)
                archive.append(lazyFileStream, {name:file.name})

            hadError = no

            archive.finalize (err,written)=>
                if err 
                    hadError = yes
                    return callback(err) 
                
            output.on 'close', =>
                if hadError
                    fs.unlinkSync @cachePath
                    return

                callback(null)


    _buildCachePath: ()->       
        cacheDirectoryPath = path.join @path, '.q'
        return path.join cacheDirectoryPath, @_buildPackageFilePathInCache()
                    
    _buildPackageFilePathInCache: ()->

        firstDir = 'objects'
        secondDir = @uid.substr 0,2
        filename = @uid + '.pkg'

        return path.join firstDir, secondDir, filename