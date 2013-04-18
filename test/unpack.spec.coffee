q = require '..'

fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
unzip = require 'unzip'

{expect} = require './testing'

describe 'unpacking packages', ->
  
    TARGET_FOLDER = "#{__dirname}/test-folder-a-unpacked/"

    beforeEach ->
        wrench.rmdirSyncRecursive TARGET_FOLDER if fs.existsSync TARGET_FOLDER

    it 'needs a path to package', ->
        expect( ()->q.unpack() ).to.throw(q.ArgumentError, /package/)

    it 'needs a path to the target directory', ->
        expect( ()->q.unpack('package-path') ).to.throw(q.ArgumentError, /target/)

    it 'extract requires the target path argument to not exist', ->
        q.unpack 'test',"#{__dirname}", (err)->
            err.should.not.be.null
            
    describe 'given a package', ->
    
        p = null
        TEST_FOLDER = "#{__dirname}/test-folder-a"
        PACKAGE_PATH = null

        beforeEach (done)->
            p = q.pack TEST_FOLDER, ()->
                PACKAGE_PATH = p.cachePath
                done()

        describe 'when unpacking it', ->

            beforeEach (done)->
                q.unpack PACKAGE_PATH, TARGET_FOLDER, ()->
                    done()               

            it 'should create the target folder', ->
                stat = fs.statSync TARGET_FOLDER
                stat.isDirectory().should.be.true

            it 'should contain all the files in the package', (done)->

                zip = fs.createReadStream(PACKAGE_PATH)
                  .pipe(unzip.Parse())
                  .on 'entry', (entry) ->
                    
                    unpackedPath = path.join(TARGET_FOLDER, entry.path)
                    fs.existsSync(unpackedPath).should.be.true

                    entry.autodrain()

                zip.on 'close', ()->done()
               