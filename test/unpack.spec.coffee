q = require '..'

fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
unzip = require 'unzip'

{expect} = require './testing'

describe 'unpacking', ->
  
    TARGET_FOLDER = "#{__dirname}/test-folder-a-unpacked/"
    
    MANIPULATED_PACKAGE = "#{__dirname}/packages/manipulatedPackage.zip"
    MISSING_LISTING_PACKAGE = "#{__dirname}/packages/missingListing.zip"
    EXTRA_FILES_PACKAGE = "#{__dirname}/packages/extraFiles.zip"

    beforeEach ->
        wrench.rmdirSyncRecursive TARGET_FOLDER if fs.existsSync TARGET_FOLDER

    it 'needs a path to package', ->
        expect( ()->q.unpack() ).to.throw(q.ArgumentError, /package/)

    it 'needs a path to the target directory', ->
        expect( ()->q.unpack('package-path') ).to.throw(q.ArgumentError, /target/)

    it 'extract requires the target path argument to not exist', ->
        q.unpack 'test',"#{__dirname}", (err)->
            err.should.not.be.null
            
    describe 'a valid package', ->
    
        p = null
        TEST_FOLDER = "#{__dirname}/test-folder-a"
        PACKAGE_PATH = null

        beforeEach (done)->
            p = q.pack TEST_FOLDER, ()->
                PACKAGE_PATH = p.cachePath
                done()

        describe 'after unpacking it', ->

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

            it 'can be verified against a sha1 value', (done)->

                q.verifyDirectory TARGET_FOLDER, (err,result)->
                    expect(err).to.be.null
                    result.valid.should.be.true
                    result.uid.should.equal 'b74ed98ef279f61233bad0d4b34c1488f8525f27'
                    done()

        describe 'while still packed', ->
        
            it 'can be listed', (done)->
                q.listPackage PACKAGE_PATH, (err,listing)->
                    expect(err).to.be.null
                    listing.name.should.equal('my-package')
                    done()
            
            it 'can be verified against the package', (done)->
                q.verifyPackage PACKAGE_PATH, (err,result)->
                    result.valid.should.be.true
                    done()
                
    describe 'verifying invalid extracted packages', ->

        beforeEach (done)->
            q.unpack MANIPULATED_PACKAGE, TARGET_FOLDER, ()->
                done()

        it 'can be extracted but fails validation', (done)->

            q.verifyDirectory TARGET_FOLDER, (err,result)->
                expect(err).to.be.null
                result.valid.should.be.false
                result.uid.should.not.equal 'b74ed98ef279f61233bad0d4b34c1488f8525f27'
                done()

        it 'marks the invalid file', (done)->

            q.verifyDirectory TARGET_FOLDER, (err,result)->
                expect(err).to.be.null
                
                result.filesManipulated.should.be.true
                
                invalidFile = f for f in result.files when f.valid is false
                invalidFile.name.should.equal 'content/deep.txt'
                invalidFile.valid.should.be.false
                
                done()

    describe 'verifying extracted packages with additional files in directory', ->

        beforeEach (done)->
            q.unpack EXTRA_FILES_PACKAGE, TARGET_FOLDER, ()->
                done()

        it 'marks any files no contained in the listing as extra', (done)->
            q.verifyDirectory TARGET_FOLDER, (err,result)->
                result.valid.should.be.false
                
                extraFile = f for f in result.files when f.extra
                extraFile.name.should.equal 'extra.txt'
                expect(extraFile.valid).to.be.undefined
                
                done()

        it 'the result is not valid but the property filesManipulated is false', (done)->
            q.verifyDirectory TARGET_FOLDER, (err,result)->
                result.valid.should.be.false
                result.filesManipulated.should.be.false
                
                done()


    describe 'packages can be inspected when still packed', ->

        it 'a package can be listed but fails when no .q.listing in it', (done)->
            q.listPackage MISSING_LISTING_PACKAGE, (err,listing)->
                err.should.be.instanceof( q.NoListingError )
                done()

        it 'invalid packets lists the manipulated files', (done)->
            q.verifyPackage MANIPULATED_PACKAGE, (err,result)->
                result.valid.should.be.false
                
                invalidFile = f for f in result.files when f.valid is false
                invalidFile.name.should.equal 'content/deep.txt'
                invalidFile.valid.should.be.false
                
                done()

        it 'collects files in the zip that are not part of the listing in an extra property', (done)->

            q.verifyPackage EXTRA_FILES_PACKAGE, (err,result)->
                result.valid.should.be.true
                result.extraFiles.should.not.be.empty
                
                done()                