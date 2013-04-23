sha1 = require('./sha1')

module.exports = (listing)->
    
    copyOfListing = JSON.parse(JSON.stringify(listing))
    copyOfListing.uid = undefined
    copyOfListing.signature = undefined

    sha1.calculate new Buffer(JSON.stringify(copyOfListing))
        
