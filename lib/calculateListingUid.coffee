sha1 = require('./sha1')

module.exports = (listing)->
    listing.uid = undefined
    sha1.calculate new Buffer(JSON.stringify(listing))
        
