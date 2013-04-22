util = require('util')
path = require('path')

Q_Store = require('q-fs-store')
program = require('commander')

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
    q.pack options.root, (err,p)=>
        if(err)
            console.log "Error packing", err

onRemoteAdd = (name,url)->
    config.save "remote.#{name}", url

#
# Parse command line via commander
#

program.version('0.0.1')

program.command('pack')
    .description('bundle the current folder into a package')
    .option('-r, --root [path]', 'root path of package. defaults to current working directory', process.cwd())
    .action onPackCommand

program.command('remote-add <name> <url>')
    .description('add a remote to the local config')
    .action onRemoteAdd


program.parse(process.argv);




