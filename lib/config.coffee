fs = require('fs')
path = require('path')
mkdirp = require('mkdirp')

module.exports.open = (configPath, globalPath)->
    return new Config(configPath, globalPath)


class Config
    constructor: (@localPath, @globalPath)->
        @_makeSureFileExists(@localPath)
        @_makeSureFileExists(@globalPath)
        
    _makeSureFileExists: (filePath)->
        mkdirp.sync path.dirname(filePath)
        if not fs.existsSync filePath
            fs.writeFileSync filePath, JSON.stringify({}), {encoding:'utf8'}

    saveGlobal: (key, value)->
        loader = ()=>@_readGlobalSync()
        saver = (config)=>@_writeGlobalSync(config)

        @_save key, value, loader,saver

    saveLocal: (key, value)->
        loader = ()=>@_readLocalSync()
        saver = (config)=>@_writeLocalSync(config)

        @_save key, value, loader,saver

    _save: (key, value, loader, saver)->
        config = loader()

        if value == null
            delete config[key]
        else
            config[key] = value

        saver(config)

    load: (key)->
        localConfig = @_readLocalSync()
        globalConfig = @_readGlobalSync()

        localConfig[key] ? globalConfig[key]

    _readLocalSync: ()->
        return @_readSync(@localPath)
    
    _readGlobalSync: ()->
        return @_readSync(@globalPath)
        
    _readSync: (configPath)->

        if fs.existsSync configPath
            config = fs.readFileSync configPath, encoding:'utf8'
            return JSON.parse(config)
        else
            return {}

    _writeLocalSync: (config)->
        return @_writeSync(config, @localPath)
    
    _writeGlobalSync: (config)->
        return @_writeSync(config, @globalPath)
    
    _writeSync: (config,configPath) ->
        text = JSON.stringify(config, null, ' ')
        fs.writeFileSync configPath, text,  encoding:'utf8'
       