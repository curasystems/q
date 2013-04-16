#path = require('path')
fs = require('fs')
util = require('util')
events = require('events')

async = require('async')
yaml = require('js-yaml')
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

    fill: (manifestPath, callback)->

        fs.exists manifestPath, (exists)=>
            return callback() if not exists

            async.waterfall [
                     (cb)=>
                         @_readManifest(manifestPath,cb)
                    ,(data, cb)=>
                        @_parseManifest(data,cb)
                    ,(manifest, cb)=>
                        #console.log(manifest)
                        @_createFileListing(manifest, cb)                      
                    ,(listing, cb)=>
                        cb()
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

    _createFileListing: (manifest,callback)->
        callback(null,null)