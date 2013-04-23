Q = require '..'
qStore = require 'q-fs-store'

fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
unzip = require 'unzip'

{expect} = require './testing'

describe 'unpacking', ->
  
    q = null
    store = null

    Q_CACHE_FOLDER = "#{__dirname}/.cache"
    TARGET_FOLDER = "#{__dirname}/test-folder-a-unpacked/"
    
    MANIPULATED_PACKAGE = "#{__dirname}/packages/manipulatedPackage.zip"
    MISSING_LISTING_PACKAGE = "#{__dirname}/packages/missingListing.zip"
    EXTRA_FILES_PACKAGE = "#{__dirname}/packages/extraFiles.zip"

    beforeEach ->
        wrench.rmdirSyncRecursive TARGET_FOLDER if fs.existsSync TARGET_FOLDER
        store = new qStore(path:Q_CACHE_FOLDER)
        q = new Q(store:store)   

    it 'needs a path to package', ->
        expect( ()->q.unpack() ).to.throw(q.errors.ArgumentError, /package/)

    it 'needs a path to the target directory', ->
        expect( ()->q.unpack('package-path') ).to.throw(q.errors.ArgumentError, /target/)

    it 'extract requires the target path argument to not exist', ->
        q.unpack EXTRA_FILES_PACKAGE, "#{__dirname}", (err)->
            err.should.not.be.null
            
    describe 'a valid package', ->
    
        p = null
        TEST_FOLDER = "#{__dirname}/test-folder-a"

        beforeEach (done)->
            p = q.pack TEST_FOLDER, ()->
                done()

        describe 'after unpacking it', ->

            beforeEach (done)->
                q.unpack p.uid, TARGET_FOLDER, ()->
                    done()               

            it 'should create the target folder', ->
                stat = fs.statSync TARGET_FOLDER
                stat.isDirectory().should.be.true

            it 'should contain all the files in the package', (done)->

                store.readPackage p.uid, (err,packageStream)->

                    zip = packageStream.pipe(unzip.Parse())
                    zip.on 'entry', (entry) ->
                        unpackedPath = path.join(TARGET_FOLDER, entry.path)
                        fs.existsSync(unpackedPath).should.be.true
                        entry.autodrain()

                    zip.on 'close', ()->done()

            it 'can be verified against a sha1 value', (done)->

                q.verifyDirectory TARGET_FOLDER, (err,result)->
                    expect(err).to.be.null
                    result.verified.should.be.true
                    result.uid.should.equal 'b74ed98ef279f61233bad0d4b34c1488f8525f27'
                    done()

        describe 'while still packed', ->
        
            it 'can be listed', (done)->
                q.listPackageContent p.uid, (err,listing)->
                    expect(err).to.be.null
                    listing.name.should.equal('my-package')
                    done()
            
            it 'can be verified', (done)->
                q.verifyPackage p.uid, (err,result)->
                    result.verified.should.be.true
                    done()
                
    describe 'verifying invalid extracted packages', ->

        beforeEach (done)->
            q.unpack MANIPULATED_PACKAGE, TARGET_FOLDER, ()->
                done()

        it 'can be extracted but fails validation', (done)->

            q.verifyDirectory TARGET_FOLDER, (err,result)->
                expect(err).to.be.null
                result.verified.should.be.false
                result.uid.should.not.equal 'b74ed98ef279f61233bad0d4b34c1488f8525f27'
                done()

        it 'marks the invalid file', (done)->

            q.verifyDirectory TARGET_FOLDER, (err,result)->
                expect(err).to.be.null
                
                result.filesManipulated.should.be.true
                
                invalidFile = f for f in result.files when f.verified is false
                invalidFile.name.should.equal 'content/deep.txt'
                invalidFile.verified.should.be.false
                
                done()

    describe 'verifying extracted packages with additional files in directory', ->

        beforeEach (done)->
            q.unpack EXTRA_FILES_PACKAGE, TARGET_FOLDER, ()->
                done()

        it 'marks any files no contained in the listing as extra', (done)->
            q.verifyDirectory TARGET_FOLDER, (err,result)->
                result.verified.should.be.false
                
                extraFile = f for f in result.files when f.extra
                extraFile.name.should.equal 'extra.txt'
                expect(extraFile.verified).to.be.undefined
                
                done()

        it 'the result is not valid but the property filesManipulated is false', (done)->
            q.verifyDirectory TARGET_FOLDER, (err,result)->
                result.verified.should.be.false
                result.filesManipulated.should.be.false
                
                done()


    describe 'packages can be inspected when still packed', ->

        it 'a package can be listed but fails when no .q.listing in it', (done)->
            q.listPackageContent MISSING_LISTING_PACKAGE, (err,listing)->
                err.should.be.instanceof( q.errors.NoListingError )
                done()

        it 'invalid packets lists the manipulated files', (done)->
            q.verifyPackage MANIPULATED_PACKAGE, (err,result)->
                result.verified.should.be.false
                
                invalidFile = f for f in result.files when f.verified is false
                invalidFile.name.should.equal 'content/deep.txt'
                invalidFile.verified.should.be.false
                
                done()

        it 'collects files in the zip that are not part of the listing in an extra property', (done)->

            q.verifyPackage EXTRA_FILES_PACKAGE, (err,result)->
                result.verified.should.be.true
                result.extraFiles.should.not.be.empty
                
                done()                