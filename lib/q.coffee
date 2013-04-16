path = require('path')
fs = require('fs')
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

    p = new Package

    async.series [ 
        (cb)->p.create(manifestPath,cb)
        (cb)->p.save(cb)
        ],
        (err)->callback(err,p)
    
    return p       

# Classes
class Package extends events.EventEmitter

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

            async.eachLimit files, 8, (file,cb)=>
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

    save: (callback)->

        cacheDirectoryPath = path.join @path, '.q'

        fs.mkdir cacheDirectoryPath, (err)=>

            return callback(err) if err?.errno is not 47

            @cachePath = path.join cacheDirectoryPath, @uid
            callback(null, @cachePath)


