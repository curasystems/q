path = require('path')
glob = require('glob')
fs = require('fs')
async = require('async')
sha1 = require('./sha1')

module.exports = (directory, globFilter, callback)->

    collectAllFilesUsingGlob directory, globFilter, (err,files)->
        processAllFiles directory, files, (err,files)->
            callback(err,files)

collectAllFilesUsingGlob = (directory,globFilter,callback)->

    glober = new glob.Glob globFilter, cwd:directory, dot:no, debug:no

    glober.on 'error', callback
    glober.on 'end', (files)->
        callback(null,files)
                
processAllFiles = (directory, files, callback)->

    processedFileEntries = []

    async.eachSeries files, (file,cb)->
            processFile directory, file, (err, entry)->
                return cb(err) if err
                processedFileEntries.push(entry) if entry
                cb(null)
        , (err)->
            callback(err, processedFileEntries)

processFile = (directory, filePath, callback)->

    fullPath = path.join(directory, filePath)

    fs.stat fullPath, (err,stats)=>

        return callback(err) if err
        if stats.isDirectory()
            return callback(null) 

        entry = 
            name: filePath
            path: fullPath
            sha1: null

        sha1.calculate fs.createReadStream(fullPath), (err,hash)->

            entry.sha1 = hash
            callback(null, entry)