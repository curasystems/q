yaml = require('js-yaml')
semver = require('semver')
path = require('path')
fs = require('fs')
_ = require('underscore')

errors = require('./errors')


module.exports = (directoryPath, manifestName, callback)->
    reader = new ManifestReader(directoryPath, manifestName)
    reader.readManifest(callback)

class ManifestReader

    constructor: (@directoryPath, @manifestName)->  
        
        @manifest = {}
        @manifestPath = null
        @qManifestPath = path.normalize path.join(@directoryPath, @manifestName)
        @packageJsonPath = path.normalize path.join(@directoryPath, 'package.json')
        @componentJsonPath = path.normalize path.join(@directoryPath, 'component.json')

    readManifest: (callback)->

        fs.exists @packageJsonPath, (exists)=>
            if exists
                @_attemptToLoadJson @packageJsonPath, (err)=>
                    return callback(err) if err
                    @_loadManifest (err)=>
                        callback(err, @manifestPath, @manifest)    
            else
                fs.exists @componentJsonPath, (exists)=>
                    if exists
                        @_attemptToLoadJson @componentJsonPath, (err)=>
                            return callback(err) if err
                            @_loadManifest (err)=>
                                callback(err, @manifestPath, @manifest)
                    else
                        @_loadManifest (err)=>
                            callback(err, @manifestPath, @manifest)

    _attemptToLoadJson: (jsonPath, callback)->

        fs.readFile jsonPath, encoding:'utf8', (err,content)=>

            return callback(err) if err

            packageInfo = JSON.parse(content)
            
            @manifestPath = @packageJsonPath
            @manifest.name = packageInfo.name
            @manifest.version = packageInfo.version
            @manifest.description = packageInfo.description

            callback(null)

    _loadManifest: (callback)=>
        fs.exists @qManifestPath, (exists)=>
            return callback(null) if not exists
            @_readManifestFile(callback)

    _readManifestFile: (callback)->
        fs.readFile @qManifestPath, encoding:'utf8', (err,content)=>
            return callback(err) if err
            @manifestPath = @qManifestPath            
            @_parseManifest(content,callback)
    
    _parseManifest: (data, callback)->
        try
            qManifest = yaml.load(data)

            if qManifest==null
                callback(new errors.InvalidManifestError("Could not parse manifest"))
            else
                @manifest = _.defaults @manifest, qManifest
                callback(null)            
        catch e
            callback(new errors.InvalidManifestError(e))