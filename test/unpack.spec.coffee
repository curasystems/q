Q = require '..'
qStore = require 'q-fs-store'

fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
AdmZip = require 'adm-zip'
streamBuffers = require('stream-buffers')

{expect} = require './testing'

describe 'unpacking', ->
  
    q = null
    store = null

    Q_CACHE_FOLDER = "#{__dirname}/.cache"
    TARGET_FOLDER = "#{__dirname}/test-folder-a-unpacked/"
    
    MANIPULATED_PACKAGE = "#{__dirname}/packages/manipulatedPackage.zip"
    MANIPULATED_UID_PACKAGE = "#{__dirname}/packages/manipulatedUid.zip"
    MISSING_LISTING_PACKAGE = "#{__dirname}/packages/missingListing.zip"
    EXTRA_FILES_PACKAGE = "#{__dirname}/packages/extraFiles.zip"
    SIGNED_PACKAGE = "#{__dirname}/packages/signed.zip"
    MANIPULATED_SIGNATURE_PACKAGE = "#{__dirname}/packages/manipulatedSignature.zip"
    
    beforeEach ->
        wrench.rmdirSyncRecursive TARGET_FOLDER if fs.existsSync TARGET_FOLDER
        store = new qStore(path:Q_CACHE_FOLDER)

        options =
            store: store
            signedBy: 'your_email@example.com'
            key: fs.readFileSync("#{__dirname}/id_rsa")
            verifyRequiresSignature: no

        q = new Q(options)   

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

                    zipBufferStream = new streamBuffers.WritableStreamBuffer()
                    packageStream.pipe(zipBufferStream)
                    
                    zipBufferStream.on 'close', ()->
                        zip = new AdmZip(zipBufferStream.getContents())   
                        entries = zip.getEntries()

                        entries.forEach (entry) ->
                            unpackedPath = path.join(TARGET_FOLDER, entry.entryName)
                            fs.existsSync(unpackedPath).should.be.true

                        done()

            it 'can be verified against a sha1 value', (done)->

                q.verifyDirectory TARGET_FOLDER, (err,result)->
                    expect(err).to.be.null
                    result.verified.should.be.true
                    result.uid.should.equal '898a0ad816c517f8c888fa00c1a84dce73fed656'
                    done()

        describe 'while still packed in store', ->
        
            it 'can be listed using uid', (done)->
                q.listPackageContent p.uid, (err,listing)->
                    expect(err).to.be.null
                    listing.name.should.equal('my-package')
                    done()
            
            it 'can be verified using uid', (done)->

                q.verifyPackage p.uid, (err,result)->
                    result.verified.should.be.true
                    done()
                
    describe 'verifying invalid packages where content files are manipulated', ->

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
                
    describe 'verify listing signatures', ->

        beforeEach ()->
            options =
                store: store
                keys:
                    'key_a': fs.readFileSync("#{__dirname}/id_rsa.pub", encoding:'utf8')
                verifyRequiresSignature: true

            q = new Q(options)

        it 'looks up signing user from q options', (done) ->
            q.verifyPackage SIGNED_PACKAGE, (err,result)->
                expect(err).to.be.null

                result.verified.should.be.true
                result.signed.should.equal('key_a')
                done()

    describe 'verifying invalid packages where the listing uid has been manipulated', ->
    
        it 'fails verification for directory', (done)->
            
            q.unpack MANIPULATED_UID_PACKAGE, TARGET_FOLDER, ()->
                
                q.verifyDirectory TARGET_FOLDER, (err,result)->
                    expect(err).to.be.null

                    result.verified.should.be.false
                    done()

        it 'fails verification for package', (done)->
            
            q.verifyPackage MANIPULATED_UID_PACKAGE, (err,result)->
                expect(err).to.be.null

                result.verified.should.be.false
                done()

    describe 'verifying invalid signatures when told to (but is default)', ->

        beforeEach ()->
            options =
                store: store
                verifyRequiresSignature: yes
                keys:
                    'key_a': fs.readFileSync("#{__dirname}/id_rsa.pub", encoding:'utf8')

            q = new Q(options)

        it 'fails verification for directory', (done)->
            
            q.unpack MANIPULATED_SIGNATURE_PACKAGE, TARGET_FOLDER, ()->
                
                q.verifyDirectory TARGET_FOLDER, (err,result)->
                    expect(err).to.be.null

                    result.verified.should.be.false
                    done()

        it 'fails verification for package', (done)->
            
            q.verifyPackage MANIPULATED_SIGNATURE_PACKAGE, (err,result)->
                expect(err).to.be.null

                result.verified.should.be.false
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

        it 'fails when no .q.listing in it', (done)->
            q.listPackageContent MISSING_LISTING_PACKAGE, (err,listing)->
                err.should.be.instanceof( q.errors.NoListingError )
                done()

        it 'contains the signature when signed', (done)->
            q.listPackageContent SIGNED_PACKAGE, (err,listing)->
                listing.signedBy.should.equal('your_email@example.com')
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