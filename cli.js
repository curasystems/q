/**
 * Module dependencies.
 */
require('coffee-script');
require('source-map-support').install();

var q = require('./lib/q');
var program = require('commander');

program.version('0.0.1')

program.command('bundle')
    .description('bundle the current folder into a package')
    .option('-r, --root [path]', 'root path of package. defaults to current working directory', process.cwd())
    .action( function(options){
        q.bundle(options.root)
    } );

program.parse(process.argv);