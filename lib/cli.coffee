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
config = Q_Config.open( path.join(Q_CACHE_FOLDER, "config.json") )

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
            printError "Error:".red + err.toString()

onRemoteAdd = (name,url)->
    config.save "remote.#{name}", url

onConfigSet = (key,value)->
    config.save key, value

onConfigGet = (key)->
    console.log "#{key} = " + config.read key


onPublishCommand = (target, version, options)->
 
    version ?= '*'
    targetServerUrl = config.load("remote.#{target}")


    if not targetServerUrl
        return printError('target ' + "'#{target}'".red + ' unknown. Use ' + "'remote-add'".green + ' first.')

    findDefaultPackageName (err,packageName)->
        return printError(err) if err

        store.findHighest packageName, version, (err,versionToPublish)->
            return printError("err") if err

            packageIdentifier = "#{packageName}@#{versionToPublish}"

            console.log  "#{packageIdentifier} => #{targetServerUrl}"
            q.publish packageIdentifier, targetServerUrl, (err)=>
                return printError(err.toString()) if err                    

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


printError = (err)->
    console.error("ERROR", err)

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
    .action onRemoteAdd

program.command('set <key> <value>')
    .description('set the config key')
    .action onConfigSet

program.command('get <key> <value>')
    .description('get the config key')
    .action onConfigGet

program.command('publish <target> [version]')
    .description('publish version of package to server.\ntarget is a remote server previously added with remote-add. the package is signed with the
        current users public key from $HOME/.ssh/id_rsa')
    .action onPublishCommand


program.parse(process.argv);




