path = require('path')
fs = require('fs')
async = require('async')
Buffers = require('buffers')
unzip = require('unzip')

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


module.exports.listPackage = (packagePath, callback) ->
    
    foundListing = no

    zip = fs.createReadStream(packagePath)
      .pipe(unzip.Parse())
      .on 'entry', (entry) ->
        
        if isListingEntry entry
            foundListing = yes
            readObjectFromStream entry, (err, listing)->
                callback(err, listing)
        else
            entry.autodrain()

    zip.on 'close', ()->
        if not foundListing
            callback(new errors.NoListingError("No .q.listing file in #{packagePath}")) 

module.exports.verify = (packagePath, targetDir, callback) ->

    listing = null
    filesToCheck = []
    failedFiles = []

    zip = fs.createReadStream(packagePath)
      .pipe(unzip.Parse())
      .on 'entry', (entry) ->
        
        if entry.path is '.q.listing'
            readObjectFromStream entry, (err, storedListing)->
                return callback(err) if err
                listing = storedListing

        if not listing 
            filesToCheck.push(entry)       

    zip.on 'close', ()->
        callback()

isListingEntry = (entry)->entry.path is '.q.listing'

readObjectFromStream = (stream, callback)->

    bufs = Buffers();

    stream.on 'error', (error)->
        callback(error)
    stream.on 'data', (data)->
        bufs.push(data)
    stream.on 'end', ()->
        json = bufs.toString('utf8')
        callback( null, JSON.parse( json ) )
