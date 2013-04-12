path = require('path')
fs = require('fs')
util = require('util')
zlib = require('zlib')
Buffer = require('buffer').Buffer

_ = require('underscore')
Zip = require('node-native-zip')
folder = require('./folder')
sha1 = require('./sha1')

module.exports.bundle = (sourceDir, cb)->
    (new Q()).bundle(sourceDir, cb)

class Q

    DEFAULT_EXTENSION = '.gz-pkg'

    constructor:()->

        @ignore = [/^.*\.gz-pkg$/]

    bundle:(sourceDir)->
        targetDir = process.cwd()
        console.log("creating package from path: #{sourceDir} @ #{targetDir} ...")
        
        @_createPackageFromFolder sourceDir, targetDir, (err, packageFile)->
            console.log "Created package #{packageFile}."

    _createPackageFromFolder: (sourceDir, targetDir, callback)->

        @_createPackageListing sourceDir, (err, listingHash, listing)=>
            return callback(err) if err

            targetPackagePath = path.join(targetDir, listingHash + DEFAULT_EXTENSION)
            @_writePackageToFile listing, targetPackagePath

            callback(err, targetPackagePath)

     _createPackageListing: (sourceDir, callback) ->

        mapFile = (filePath, stats, callback) =>
          
            if( excludeFile(filePath) )
                return callback()
            else
                fileStream = fs.createReadStream(filePath)

                sha1.calculate fileStream, (err,hash)->
                    return callback() if(err)

                    callback
                        name: filePath.replace(sourceDir, "").substr(1)
                        path: filePath
                        sha1: hash

        excludeFile = (filePath)=>
            fileName = path.basename(filePath)
            for i in @ignore
                return true if i.test(fileName)
                
            return false

        folder.mapAllFiles sourceDir, mapFile, (err,data)->

            return callback(err) if err

            # calculate SHA1 of listing itself
            namesAndShaOnly = _.map( data, (v)->{name:v.name,sha1:v.sha1} )
            dataBuffer = new Buffer(JSON.stringify(namesAndShaOnly))          
            dataSha1 = sha1.calculate(dataBuffer)

            
            callback(null,dataSha1,data)


    _writePackageToFile: (listing, targetPackagePath)->

        archive = new Zip()
    
        # add the files to the zip
        archive.addFiles listing, (err) ->
            return callback(err)  if err
            
            compressionStream = zlib.createGzip()
            targetFileStream = fs.createWriteStream(targetPackagePath)

            compressionStream.pipe(targetFileStream)
            compressionStream.write(archive.toBuffer())
            #targetFileStream.write(archive.toBuffer())
