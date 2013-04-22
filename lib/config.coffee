fs = require('fs')
path = require('path')
mkdirp = require('mkdirp')

module.exports.open = (configPath)->
    return new Config(configPath)


class Config
    constructor: (@configPath)->
        mkdirp.sync path.dirname(@configPath)

        if not fs.existsSync @configPath
            fs.writeFileSync @configPath, JSON.stringify({}), {encoding:'utf8'}

    save: (key, value)->
        config = @_readSync()
        config[key] = value
        @_writeSync(config)

    _readSync: ->
        if fs.existsSync @configPath
            config = fs.readFileSync @configPath, encoding:'utf8'
            return JSON.parse(config)
        else
            return {}

        

    _writeSync: (config) ->
        text = JSON.stringify(config, null, ' ')
        fs.writeFileSync @configPath, text,  encoding:'utf8'
        