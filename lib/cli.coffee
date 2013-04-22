util = require('util')

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
# Commands
#
onPackCommand = (options)->
    q.pack options.root, (err,p)=>
        if(err)
            console.log "Error packing", err



#
# Parse command line via commander
#

program.version('0.0.1')

program.command('pack')
    .description('bundle the current folder into a package')
    .option('-r, --root [path]', 'root path of package. defaults to current working directory', process.cwd())
    .action onPackCommand

program.parse(process.argv);



