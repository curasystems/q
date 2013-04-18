yaml = require('js-yaml')
semver = require('semver')
_ = require('underscore')

errors = require('./errors')


module.exports = (directoryPath, manifestName, callback)->
    reader = new ManifestReader(directoryPath, manifestName)
    reader.readManifest(callback)

class ManifestReader

    constructor: (@directoryPath, @manifestName)->        
        @manifestPath = path.normalize path.join(@directoryPath, @manifestName)
    
    readManifest: (callback)->

        fs.exists @manifestPath, (exists)=>
            if not exists
                @_attemptToLoadPackageJson(callback) 
            else
                @_readManifestFile @manifestPath, (err,manifest)=>
                    callback(err, @manifestPath, manifest)

    _attemptToLoadPackageJson: (callback)->
        packageJsonPath = path.normalize path.join(@directoryPath, 'package.json')    
        fs.readFile packageJsonPath, encoding:'utf8', (err,content)->
            return callback(err) if err

            packageInfo = JSON.parse(content)
            
            manifest = {}
            manifest.name = packageInfo.name
            manifest.version = packageInfo.version
            manifest.description = packageInfo.description

            callback(null, packageJsonPath, manifest)

    _readManifestFile: (manifestPath, callback)->
        fs.readFile manifestPath, encoding:'utf8', (err,content)=>
            return callback(err) if err
            @_parseManifest(content,callback)
    
    _parseManifest: (data, callback)->
        try
            manifest = yaml.load(data)

            if manifest==null
                callback(new errors.InvalidManifestError("Could not parse manifest"))
            else
                callback(null, manifest)            
        catch e
            callback(new errors.InvalidManifestError(e))