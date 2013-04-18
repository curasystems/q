path = require('path')
fs = require('fs')
async = require('async')
Buffers = require('buffers')
unzip = require('unzip')
_ = require('underscore')

Packer = require('./Packer')
Unpacker = require('./Unpacker')

sha1 = require('./sha1')
calculateListingUid = require('./calculateListingUid')

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


listPackage = module.exports.listPackage = (packagePath, callback) ->
    
    zipClosed = no
    listing = null

    zip = fs.createReadStream(packagePath)
      .pipe(unzip.Parse())
      .on 'entry', (entry) ->
        
        if isListingEntry entry
            foundListing = yes
            readObjectFromStream entry, (err, listingFound)->

                listing = listingFound
                listing.uid = calculateListingUid(listing)
                
                if zipClosed
                    callback(null, listing)
        else
            entry.autodrain()

    zip.on 'close', ()->
        zipClosed = yes
        if not listing
            callback(new errors.NoListingError("No .q.listing file in #{packagePath}")) 
        else 
            callback(null, listing)

module.exports.verifyPackage = (packagePath, callback) ->

    verifyQueue = async.queue(verifySha1, 100)

    listPackage packagePath, (err,listing)->
        return callback(err) if err

        result = listing
        result.valid = true
        result.extraFiles = []
    
        zip = fs.createReadStream(packagePath)
          .pipe(unzip.Parse())
          .on 'entry', (entry) ->
            
            if entry.path is '.q.listing'
                entry.autodrain()
            else
                listEntry = _.find listing.files, (f)->f.name is entry.path

                if not listEntry
                    result.extraFiles.push( entry.path )
                    entry.autodrain()
                else
                    verifyQueue.push result:result, listEntry:listEntry, stream:entry

        zip.on 'close', ()->
            if verifyQueue.length() == 0
                callback(null,result)
            else
                verifyQueue.drain = ()->
                    callback(null,result)

verifySha1 = (job, callback)->

    sha1.calculate job.stream, (err,hash)->
        if job.listEntry.sha1 isnt hash
            job.result.valid = false
            job.listEntry.valid = false
        else
            job.listEntry.valid = true

        callback(null)

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
