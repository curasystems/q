fs = require('fs');
path = require('path');

// Allow arguments for this test script
var argv = require('optimist')
  .default('reporter', 'spec')
  .argv;

// Support coffee script and source maps for stack traces
// NOTE: don't handle uncaught exceptions in order not to interfere with mocha.
require('coffee-script');
require('source-map-support').install( {handleUncaughtExceptions:false} );

// put out growl notifications when there is at least one error
growl = require('growl');

// enable chai should as default for all tests
require('chai').should();

// Run Tests using mocha
mocha = buildMochaRunner(argv.reporter);
runMochaTests(mocha);

function buildMochaRunner(reporter) {

  Mocha = require('mocha');

  var mocha = new Mocha({
      ui: 'bdd',
      reporter: reporter
  });

  addAllFilesInFolderToMocha( mocha, 'test', '.spec.coffee')
  addAllFilesInFolderToMocha( mocha, 'test', '.spec.js')
 
  return mocha;
}

function addAllFilesInFolderToMocha( mocha, folderPath, extension ) {
  fs.readdirSync(folderPath).filter(function(file){
      return file.substr(file.length - extension.length) === extension;
  }).forEach(function(file){
      
      filePath = path.join(folderPath, file);
      mocha.addFile(filePath);

      console.log(filePath);
  });
}

function runMochaTests(mocha){
  mocha.run(function(failures){
    if( failures>0 ){
      showGrowlMessage(failures);
    };
    process.exit(failures);
  });
}

function showGrowlMessage(errorCount) {
   
    var message = '#' + errorCount + ' Errors while testing.';
    var options = {
      title : "Mocha Tests"      
    };

    growl( message, options );
}