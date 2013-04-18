path = require('path')
fs = require('fs')
async = require('async')
Packer = require('./Packer')

# Errors
module.exports.InvalidManifestError = class InvalidManifestError extends Error
    constructor:(@details)->

module.exports.ArgumentError = class ArgumentError extends Error
    constructor:(@message)->super(@message)


# Api
module.exports.pack = (manifestPath, callback)->

    if not manifestPath
        throw new ArgumentError("missing path to manifest")

    p = new Packer

    async.series [ 
        (cb)->p.create(manifestPath,cb)
        (cb)->p.saveToCache(cb)
        ],
        (err)->callback(err,p)
    
    return p       

module.exports.extract = (packagePath, targetDir, callback)->

    if not packagePath
        throw new ArgumentError("packagePath is required")

    e = new Unpacker(packagePath)
    e.unpack(targetDir, callback)

class Unpacker

    constructor: (@packagePath)->
    extract: (@targetDir,callback)->
        fs.exists @targetDir, (exists)->
            return callback(new ArgumentError("targetDir must not exist yet")) if exists 


