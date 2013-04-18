fs = require('fs')

fstream = require('fstream')
unzip = require('unzip')

errors = require('./errors')

module.exports = class Unpacker 
    constructor: (@packagePath)->

    unpack: (targetDir, callback)->

        fs.exists targetDir, (exists)=>
            return callback(new errors.ArgumentError("targetDir must not exist yet")) if exists 

            fs.mkdir targetDir, (err)=>
                return callback(err) if err

                packageStream = fs.createReadStream(@packagePath)
                targetDirWriter = fstream.Writer(targetDir)

                packageStream.pipe( unzip.Parse() ).pipe( targetDirWriter )

                targetDirWriter.on 'close', ()->
                    callback()
            