errors = require('./errors')

module.exports = class Unpacker 
    constructor: (packagePath)->

    unpack: (targetDir, callback)->
        fs.exists targetDir, (exists)->
            return callback(new errors.ArgumentError("targetDir must not exist yet")) if exists 

            callback(null)


