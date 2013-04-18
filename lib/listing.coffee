gatherFiles = require('./gatherFiles')
calculateListingUid = require('./calculateListingUid')

module.exports.createFromDirectory = (directoryPath, info, callback)->

    gatherFiles directoryPath, '**/*', (err,files)=>
        return callback(err) if err
        
        createListingFromFiles info, files, callback

createListingFromFiles = (info, files,callback)->

    listing = 
        name: info.name
        version: info.version
        files: ({name:f.name,sha1:f.sha1} for f in files)

    listing.uid = calculateListingUid(listing)
    callback(null, listing)        
