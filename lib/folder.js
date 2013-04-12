var async = require('async');
var path = require('path');
var fs = require("fs");

module.exports.mapAllFiles = mapAllFiles;

/**
 * Mapping function on all files in a folder and it's subfolders
 * @param dir {string} Source directory
 * @param action {Function} Mapping function in the form of (path, stats, callback), where callback is Function(result)
 * @param callback {Function} Callback fired after all files have been processed with (err, aggregatedResults)
 */
function mapAllFiles(dir, action, callback) {
    var output = [];
    var concurrency = 1;
    
    var q = async.queue(function (filename, next) {
        fs.stat(filename, function (err, stats) {
            if (err) return next(err);
            
            if (stats.isDirectory()) {
                readFolder(filename, next);
            }
            else {
                action(filename, stats, function (res) {
                    if (res) {
                        output.push(res);
                    }
                    
                    next();
                });                
            }
        });
    }, concurrency);
    
    function readFolder (dir, next) {
        fs.readdir(dir, function (err, files) {
            if (err) return next(err);
            
            q.push(files.map(function (file) {
                return path.join(dir, file);
            }));
            
            next();
        });
    };
    
    readFolder(dir, function () {
        q.drain = function (err) {
            callback(err, output);
        };
    });
};
