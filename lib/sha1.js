var crypto = require('crypto');
var Buffer = require('buffer').Buffer;

module.exports.calculate = function(inStream, callback){
    
    var hash = crypto.createHash('sha1');
    
    if( Buffer.isBuffer(inStream) )
    {
        hash.update(inStream);
        return hash.digest('hex');
    }
    else
    {
        inStream.on('data',function(data){
            hash.update(data);
        });

        inStream.on('error',function(err){
            callback(err);
        });

        inStream.on('end',function(){
          callback( null, hash.digest('hex') );
        });

        inStream.resume();
    }
}

