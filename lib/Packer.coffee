mkdirp = require('mkdirp')
util = require('util')
events = require('events')
lazystream = require('lazystream')

async = require('async')
semver = require('semver')

_ = require('underscore')
archiver = require('archiver')

errors = require('./errors')

sha1 = require('./sha1')
gatherFiles = require('./gatherFiles')
readManifest = require('./readManifest')

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
        
    create: (folderPath, callback)->

        @manifestPath = path.normalize path.join(folderPath, @options.manifestName)
        
        fs.exists @manifestPath, (exists)=>
            return callback() if not exists

            @path = path.dirname(@manifestPath)

            async.waterfall [
                    (cb)=>
                         readManifest(folderPath, @options.manifestName, cb)
                    ,(manifest, cb)=>
                        @_processManifest manifest, (err)->cb(err,manifest)
                    ,(manifest, cb)=>
                        @_addFiles(manifest, cb)   
                    ,(cb)=>
                        @_calculateUid(cb)
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

    _addFiles: (manifest,callback)->

        gatherFiles @path, '**/*', (err,files)=>
            return callback(err) if err
            @files = files
            callback(null)

    _calculateUid: (cb)->
        
        listing = 
            name: @name
            version: @version
            files: ({name:f.name,sha1:f.sha1} for f in @files)

        sha1OfListing = sha1.calculate new Buffer(JSON.stringify(listing))
        @uid = sha1OfListing
        
        cb(null, @uid)        

    saveToCache: (callback)->

        @cachePath = @_buildCachePath()
        mkdirp path.dirname(@cachePath), (err)=>
            return callback(err) if err #?.errno is not 47

            archive = archiver('zip');
            archive.on 'error', (err)->callback(err)

            output = fs.createWriteStream @cachePath
            archive.pipe(output)
            
            @files.forEach (file)->
                lazyFileStream = new lazystream.Readable ()->
                    return fs.createReadStream(file.path)
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