util = require('util')
path = require('path')
fs = require('fs')

path_extra = require('path-extra')
colors = require('colors')

Q_Store = require('q-fs-store')
program = require('commander')

#require('longjohn') only for debugging, very resource intensive
#require('graphdat')

#
# Prepare q to store in current directories .q folder
#
Q_CACHE_FOLDER = "#{process.cwd()}/.q"
store = new Q_Store(path:Q_CACHE_FOLDER)

Q = require('./q')
q = new Q(store:store)      

#
# Config
#
Q_Config = require('./config')

localConfigPath = path.join(Q_CACHE_FOLDER, 'config.json')
globalConfigPath = path.join(path_extra.homedir(), '.q', 'config.json')

config = Q_Config.open( localConfigPath, globalConfigPath )

#
# Allow self-signed server certs
#
require('https').globalAgent.options.rejectUnauthorized = false
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"
        
#
# Commands
#
onPackCommand = (options)->

    userEmail = config.load "user.email"
    userKeyPath = config.load "user.keyPath"

    if not userEmail
        return printError('set ' + "'user.email'".red + " first. Use " + "'set user.email'".green + ' first.' )

    if not userKeyPath
        userKeyPath = path.join( path_extra.homedir(), '.ssh', 'id_rsa' )

    if not fs.existsSync(userKeyPath)
        return printError('cannot find signer key at: ' + "'#{userKeyPath}'".red)

    userKey = fs.readFileSync(userKeyPath, encoding:'utf8')

    q = new Q(store:store, signedBy:userEmail, key:userKey)

    q.pack options.root, (err,p)=>
        if(err)
            printError err
        else
            console.log 'Packed: ' + p.name.green + "@" + p.version.white.green + " (#{p.uid})"

onRemoteAdd = (name,url,options)->
    key = "remote.#{name}"
    onConfigSet(key,url,options)

onConfigSet = (key,value, options)->
    if options.global
        config.saveGlobal key, value
    else
        config.saveLocal key, value

onConfigRemove = (key, options)->
    if options.global
        config.saveGlobal key, null
    else
        config.saveLocal key, null


onConfigGet = (key)->
    console.log "#{key} = " + config.load(key)

onPublishCommand = (target, version, options)->
 
    version ?= '*'

    lookupServerUrl target, (err,targetServerUrl)->
        return printError(err) if err

        findDefaultPackageName (err,packageName)->
            return printError(err) if err

            store.findHighest packageName, version, (err,versionToPublish)->
                return printError(err) if err

                packageIdentifier = "#{packageName}@#{versionToPublish}"
                
                q.publish packageIdentifier, targetServerUrl, (err)=>
                    return printError(err) if err                    

lookupServerUrl = (target, callback)->

    targetServerUrl = config.load("remote.#{target}")

    if not targetServerUrl
        callback('target ' + "'#{target}'".red + ' unknown. Use ' + "'remote-add'".green + ' first.')
    else
        callback(null, targetServerUrl)

findDefaultPackageName = (callback)->

    store.listAll (err, packages)->
        return callback(err) if err

        if packages.length == 0
            return callback('no packages')

        packageName = packages[0].name
        ambiguousPackages = (p.name for p in packages when p.name is not packageName)
        
        if ambiguousPackages.length > 0
            return callback('ambiguous packages found')

        callback(null, packageName)

onDownloadCommand = (source, identifier, targetPath, options)->

    if options.store
        storePath = path.resolve(options.store)
        store = new Q_Store(path:storePath)
        q = new Q(store:store)
        console.log "INFO: Using store '#{storePath}' to optimize download "

    lookupServerUrl source, (err,sourceServerUrl)->
        return printError(err) if err

        downloadPath = identifier+'.download'
        targetStream = fs.createWriteStream(downloadPath)
        
        q.download identifier, sourceServerUrl, targetStream, (err, info)->
            if err
                fs.unlinkSync(downloadPath)
                printError(err)
            else
                finalPath = "#{info.name}@#{info.version}.pkg"
                fs.renameSync(downloadPath, finalPath)
                console.log 'downloaded to ' + "#{finalPath}".green
                

printError = (err)->
    console.error("ERR ".red.inverse, err)

#
# Parse command line via commander
#

program.version('0.0.1')

program.command('pack')
    .description('pack the current folder into a package in .q folder')
    .option('-r, --root [path]', 'root path of package. defaults to current working directory', process.cwd())
    .action onPackCommand

program.command('remote-add <name> <url>')
    .description('add a remote to the local config')
    .option('-g, --global', 'store in global config')
    .action onRemoteAdd

program.command('set <key> <value>')
    .description('set the config key')
    .option('-g, --global', 'store in global config')
    .action onConfigSet

program.command('remove <key>')
    .description('remove the config key')
    .option('-g, --global', 'change global config')
    .action onConfigRemove

program.command('get <key>')
    .description('get the config key')
    .action onConfigGet

program.command('publish <target> [version]')
    .description('publish version of package to target server')
    .action onPublishCommand

program.command('download <source> <identifier> [targetPath]')
    .description('download latest package matching identifier to path')
    .option('-s, --store [storepath]', 'use store to optimize download')    
    .action onDownloadCommand

program.parse(process.argv);
