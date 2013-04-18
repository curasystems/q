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
            
            it 'a package can be listed but fails when no .q.listing in it', (done)->
                q.listPackage "#{__dirname}/packages/missingListing.zip", (err,listing)->
                    err.should.be.instanceof( q.NoListingError )
                    done()
            
            it 'the unpacked contents can be listed', (done)->
                q.listPackage PACKAGE_PATH, (err,listing)->
                    expect(err).to.be.null
                    listing.name.should.equal('my-package')
                    done()
            
            it 'the unpacked contents can be verified against the package', (done)->
                q.verifyPackage PACKAGE_PATH, (err,result)->
                    result.valid.should.be.true
                    done()

            it 'invalid packets list the errors', (done)->
                q.verifyPackage "#{__dirname}/packages/manipulatedPackage.zip", (err,result)->
                    result.valid.should.be.false
                    
                    invalidFile = f for f in result.files when f.valid is false
                    invalidFile.name.should.equal 'content/deep.txt'
                    invalidFile.valid.should.be.false
                    
                    done()

            it 'collects files in the zip that are not part of the listing in an extra property', (done)->

                q.verifyPackage "#{__dirname}/packages/extraFiles.zip", (err,result)->
                    result.valid.should.be.true
                    result.extraFiles.should.not.be.empty
                    
                    done()                