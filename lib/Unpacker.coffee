fs = require('fs')

path = require('path')

mkdirp = require('mkdirp')
AdmZip = require('adm-zip')
streamBuffers = require('stream-buffers')

errors = require('./errors')

module.exports = class Unpacker 
    
    unpack: (packageStream, targetDir, callback)->

        fs.exists targetDir, (exists)=>
            return callback(new errors.ArgumentError("targetDir must not exist yet")) if exists 

            mkdirp targetDir, (err)=>
                return callback(err) if err

                console.log('Starting unzip into', targetDir);
                
                zipBufferStream = new streamBuffers.WritableStreamBuffer()
                packageStream.pipe(zipBufferStream)

                zipBufferStream.on 'close', ()->

                    try
                        zip = new AdmZip(zipBufferStream.getContents())
                        zipEntries = zip.getEntries()
                        zipEntries.forEach (entry)->

                            return if( entry.isDirectory )                                
                            targetPath = path.join(targetDir, entry.entryName)
                            mkdirp.sync path.dirname(targetPath)
                            fs.writeFileSync targetPath, entry.getData()
                        
                        callback(null)
                    catch e
                        console.log("ERROR: Could not unpack Zip to '#{targetDir}' Possibly corrupted.")
                        callback(e)