assert = require('assert')
path = require('path')
fs = require('fs')
mkdirp = require('mkdirp')
util = require('util')
events = require('events')

async = require('async')
yaml = require('js-yaml')
glob = require('glob')
semver = require('semver')

#_ = require('underscore')
#archiver = require('archiver')
sha1 = require('./sha1')

# Errors
module.exports.InvalidManifestError = class InvalidManifestError extends Error
    constructor:(@details)->

module.exports.ArgumentError = class ArgumentError extends Error
    constructor:(@message)->super(@message)


# Api
module.exports.bundle = (manifestPath, callback)->

    if not manifestPath
        throw new ArgumentError("missing path to manifest")

    p = new PackageBundler

    async.series [ 
        (cb)->p.create(manifestPath,cb)
        (cb)->p.saveToCache(cb)
        ],
        (err)->callback(err,p)
    
    return p       

module.exports.extract = (packagePath, targetDir, callback)->

    if not packagePath
        throw new ArgumentError("packagePath is required")

    e = new PackageExtractor(packagePath)
    e.extract(targetDir, callback)

class PackageExtractor

    constructor: (@packagePath)->
    extract: (@targetDir,callback)->
        fs.exists @targetDir, (exists)->
            return callback(new ArgumentError("targetDir must not exist yet")) if exists 



# Classes
class PackageBundler extends events.EventEmitter

    constructor: ()->
        @name = null
        @version = null
        @description = null
        @files = []
        @path = null
        @manifestPath = null
        @cachePath = null
        
    create: (manifestPath, callback)->

        @manifestPath = path.normalize(manifestPath)
    
        fs.exists @manifestPath, (exists)=>
            return callback() if not exists

            @path = path.dirname(@manifestPath)

            async.waterfall [
                     (cb)=>
                         @_readManifest(@manifestPath,cb)
                    ,(data, cb)=>
                        @_parseManifest(data,cb)
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


    _readManifest: (manifestPath, callback)->
        fs.readFile manifestPath, encoding:'utf8', callback
    
    _parseManifest: (data, callback)->
        try
            manifest = yaml.load(data)

            if manifest==null
                callback(new InvalidManifestError("Could not parse manifest"))
            else
                callback(null, manifest)            
        catch e
            callback(new InvalidManifestError(e))

    _processManifest: (manifest, callback)->
        
        packageNames = Object.keys manifest
        
        @name = packageNames[0]
        @version = manifest[@name].version
        @description = manifest[@name].description

        if not @name 
            return callback(new InvalidManifestError("missing package name"))
        if not semver.valid(@version)
            return callback(new InvalidManifestError("invalid version in package => #{@name}/version = '#{@version}'"))
        if not @description
            return callback(new InvalidManifestError("package must have a description"))

        callback(null)

    _addFiles: (manifest,callback)->

        glober = new glob.Glob '**/*', cwd:@path, dot:no, debug:no

        #glober.on 'match', (match)->console.log match
        glober.on 'error', callback
        glober.on 'end', (files)=>

            @i = 0
            async.eachSeries files, (file,cb)=>
                    @_addFile(file,cb)
                , callback
        
    _addFile: (filePath, callback)->

        fullPath = path.join(@path,filePath)
        
        fs.stat fullPath, (err,stats)=>

            return callback(err) if err
            return callback(null) if stats.isDirectory()

            file = 
                name: filePath
                path: fullPath
                sha1: null

            sha1.calculate fs.createReadStream(file.path, encoding:'utf8'), (err,sha1)=>

                file.sha1 = sha1
                @files.push(file)
                @emit 'file', file

                callback()

    _calculateUid: (cb)->
        
        listing = 
            name: @name
            version: @version
            files: @files

        sha1OfListing = sha1.calculate new Buffer(JSON.stringify(listing))
        @uid = sha1OfListing
        
        cb(null, @uid)        

    saveToCache: (callback)->

        @cachePath = @_buildCachePath()
        mkdirp path.dirname(@cachePath), (err)=>
            return callback(err) if err?.errno is not 47

            fs.writeFile @cachePath, "DUMMY", (err)->
                callback(err, @cachePath)

    _buildCachePath: ()->       
        cacheDirectoryPath = path.join @path, '.q'
        return path.join cacheDirectoryPath, @_buildPackageFilePathInCache()
                    
    _buildPackageFilePathInCache: ()->

        firstDir = 'objects'
        secondDir = @uid.substr 0,2
        filename = @uid.substr(2) + '.pkg'

        assert @uid + '.pkg' == secondDir + filename

        return path.join firstDir, secondDir, filename