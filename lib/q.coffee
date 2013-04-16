path = require('path')
fs = require('fs')
util = require('util')
events = require('events')

async = require('async')
yaml = require('js-yaml')
glob = require('glob')

#_ = require('underscore')
#archiver = require('archiver')
#sha1 = require('./sha1')

module.exports.InvalidManifestError = class InvalidManifestError extends Error
    constructor:(@details)->

module.exports.bundle = (manifestPath, callback)->
    bundle = new Bundle
    bundle.fill(manifestPath,callback)
    return bundle       

class Bundle extends events.EventEmitter

    constructor: ()->
        @files = []
        @bundlePath = null

    fill: (@manifestPath, callback)->

        fs.exists @manifestPath, (exists)=>
            return callback() if not exists

            @bundlePath = path.dirname(@manifestPath)

            async.waterfall [
                     (cb)=>
                         @_readManifest(@manifestPath,cb)
                    ,(data, cb)=>
                        @_parseManifest(data,cb)
                    ,(manifest, cb)=>
                        #console.log(manifest)
                        @_addFiles(manifest, cb)   
                ],
                (err)=>
                    @emit 'end'
                    callback(err, this)


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

    _addFiles: (manifest,callback)->

        glober = new glob.Glob '*', cwd:@bundlePath, debug:no

        glober.on 'match', (file)=>
            @emit 'file', file
        glober.on 'error', callback
        glober.on 'end', (files)=>
            @files = files
            callback(null,files)
