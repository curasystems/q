sha1 = require('./sha1')

module.exports = (listing)->
    sha1.calculate new Buffer(JSON.stringify(listing))
        
