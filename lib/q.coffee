path = require('path')
fs = require('fs')
async = require('async')
Packer = require('./Packer')
Unpacker = require('./Unpacker')

# Exports all errors
module.exports = errors = require('./errors')

# Api
module.exports.pack = (manifestPath, callback)->

    if not manifestPath
        throw new errors.ArgumentError("missing path to manifest")

    p = new Packer

    async.series [ 
        (cb)->p.create(manifestPath,cb)
        (cb)->p.saveToCache(cb)
        ],
        (err)->callback(err,p)
    
    return p   

module.exports.extract = (packagePath, targetDir, callback)->

    if not packagePath
        throw new errors.ArgumentError("packagePath is required")

    e = new Unpacker(packagePath)
    e.unpack(targetDir, callback)

class Unpacker

    constructor: (@packagePath)->
    extract: (@targetDir,callback)->
        fs.exists @targetDir, (exists)->
            return callback(new errors.ArgumentError("targetDir must not exist yet")) if exists 


