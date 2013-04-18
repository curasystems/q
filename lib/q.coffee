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

module.exports.unpack = (packagePath, targetDir, callback)->

    if not packagePath
        throw new errors.ArgumentError("packagePath is required")

    if not targetDir
        throw new errors.ArgumentError("targetDir is required")

    e = new Unpacker(packagePath)
    e.unpack(targetDir, callback)


