async = require('async')
yaml = require('js-yaml')
semver = require('semver')

errors = require('./errors')

module.exports = (directoryPath, manifestName, callback)->
    reader = new ManifestReader(directoryPath, manifestName)
    reader.readManifest(callback)

class ManifestReader

    constructor: (@directoryPath, @manifestName)->        
        @manifestPath = path.normalize path.join(@directoryPath, @manifestName)
    
    readManifest: (callback)->

        fs.exists @manifestPath, (exists)=>
            return callback() if not exists

            async.waterfall [
                     (cb)=>
                         @_readManifestFile(@manifestPath,cb)
                    ,(data, cb)=>
                        @_parseManifest(data,cb)
                  
                ],
                (err, manifest)=>
                    callback(err, manifest)

    _readManifestFile: (manifestPath, callback)->
        fs.readFile manifestPath, encoding:'utf8', callback
    
    _parseManifest: (data, callback)->
        try
            manifest = yaml.load(data)

            if manifest==null
                callback(new errors.InvalidManifestError("Could not parse manifest"))
            else
                callback(null, manifest)            
        catch e
            callback(new errors.InvalidManifestError(e))

    _processManifest: (manifest, callback)->
        
        @name = manifest.name
        @version = manifest.version
        @description = manifest.description

        if not @name 
            return callback(new errors.InvalidManifestError("missing package name"))
        if not semver.valid(@version)
            return callback(new errors.InvalidManifestError("invalid version in package => #{@name}/version = '#{@version}'"))
        if not @description
            return callback(new errors.InvalidManifestError("package must have a description"))

        callback(null)
