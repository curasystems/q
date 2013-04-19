fs = require('fs')

fstream = require('fstream')
unzip = require('unzip')
mkdirp = require('mkdirp')

errors = require('./errors')

module.exports = class Unpacker 
    
    unpack: (packageStream, targetDir, callback)->

        fs.exists targetDir, (exists)=>
            return callback(new errors.ArgumentError("targetDir must not exist yet")) if exists 

            mkdirp targetDir, (err)=>
                return callback(err) if err

                targetDirWriter = fstream.Writer(targetDir)
                packageStream.pipe( unzip.Parse() ).pipe( targetDirWriter )

                targetDirWriter.on 'close', ()->
                    callback()
        