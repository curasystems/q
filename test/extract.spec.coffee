q = require '..'
wrench = require 'wrench'

{expect} = require './testing'

describe 'extracting packages', ->
  
    TARGET_FOLDER = "#{__dirname}/test-folder-a-extracted/"

    beforeEach ->
        wrench.rmdirSyncRecursive TARGET_FOLDER if fs.existsSync TARGET_FOLDER

    it 'extract requires a manifest path', ->
        expect( q.extract ).to.throw(q.ArgumentError)

    it 'extract requires the target path to not exist', ->
        q.extract 'test',"#{__dirname}", (err)->
            err.should.not.be.null
            
    describe 'given a package', ->
    
        p = null
        TEST_FOLDER_MANIFEST = "#{__dirname}/test-folder-a/q.manifest"

        beforeEach (done)->
            p = q.bundle TEST_FOLDER_MANIFEST, done
            




                
            