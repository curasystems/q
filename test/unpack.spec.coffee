q = require '..'
wrench = require 'wrench'

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

        beforeEach (done)->
            p = q.pack TEST_FOLDER, done
            




                
            