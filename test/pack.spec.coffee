Q = require '..'
qStore = require 'q-fs-store'

fs = require 'fs'
path = require 'path'
wrench = require 'wrench'
unzip = require 'unzip'

{expect, sinon} = require './testing'
sha1 = require '../lib/sha1'


describe 'packing folders into packages', ->

    q = null
    store = null
    Q_CACHE_FOLDER = "#{__dirname}/.cache"

    beforeEach ->
        store = new qStore(path:Q_CACHE_FOLDER)
        q = new Q(store:store)        

    it 'requires a path to a folder and a callback', ->
        expect( ()->q.pack() ).to.throw()

    it 'requires a folder path with a parsable q.manifest or package.json', (done)->
        q.pack "#{__dirname}/test-folder-b-invalid", (err)->
            expect(err).to.be.instanceof(q.errors.InvalidManifestError)
            done()

    describe 'packing folders with a package.json', ->

        it 'works and takes name,version,description from the package.json', (done)->
            q.pack "#{__dirname}/test-folder-node", (err, p)->
                expect(err).to.be.null
                p.name.should.equal('test-folder-node')
                done()

        it 'the manifestPath is still q.manifest if its present', (done)->
            q.pack "#{__dirname}/test-folder-node", (err, p)->
                p.manifestPath.should.contain('q.manifest')
                done()

        it 'the manifestPath is package.json when no q.manifest present', (done)->
            q.pack "#{__dirname}/test-folder-node-pure", (err, p)->
                p.manifestPath.should.contain('package.json')
                done()

    describe 'packing test-folder-a', ->
        
        TEST_FOLDER = "#{__dirname}/test-folder-a"
        

        beforeEach ()->
            wrench.rmdirSyncRecursive Q_CACHE_FOLDER if fs.existsSync Q_CACHE_FOLDER

        describe 'call to pack', ->

            it 'returns the package directly', (done)->
                p = q.pack TEST_FOLDER, ->
                    expect(p).to.not.be.undefined
                    done()

            it 'returns the package also via the callback', (done)->
                p = q.pack TEST_FOLDER, (err,pkg)->
                    pkg.should.equal(p)
                    done()                            

            it 'is an event emitter', (done)->
                p = q.pack TEST_FOLDER, ()->
                    expect(p).to.respondTo('on')                   
                    done()

        describe 'package events', ->
            
            it 'when its finished it emits an "end" event', (done)->                    
                shouldEmitEvent 'end', done 

            shouldEmitEvent = (name, done)->
                eventHandler = sinon.spy()
                
                p = q.pack TEST_FOLDER, ->
                    eventHandler.should.have.been.called
                    done()            

                p.on name, eventHandler

        describe 'after pack is completed', ->

            p = null

            beforeEach (done)->
                p = q.pack TEST_FOLDER, (err)->
                    done()

            describe 'package has properties', ->
                
                it 'knows the name of the package', -> p.name.should.equal 'my-package'
                it 'knows the version of the package', -> p.version.should.equal '0.1.0'
                it 'knows the description of the package', -> p.description.should.equal 'My Description'
                it 'has a path where the directory root is', -> p.path.should.equal path.normalize("#{__dirname}/test-folder-a")
                it 'has a manifestPath where the manifest was found', ->
                    p.manifestPath.should.equal path.normalize path.join(TEST_FOLDER, 'q.manifest')
                it 'is not signed by default', -> p.signed.should.be.false
                
                it 'has a package uid which identifies the package and its contents', -> p.uid.should.equal('b74ed98ef279f61233bad0d4b34c1488f8525f27')

                describe 'and listing', ->

                    it 'which also has the name', -> p.listing.name.should.equal p.name
                    it 'which also has the version', -> p.listing.version.should.equal p.version
                

                describe 'files in package', ->
        
                    it 'stored in listing.files property', ()->
                        p.listing.files.should.not.be.empty

                    it 'contains files from subfolders too', ()->
                        atLeastOneFileInSubdirectory = no
                        
                        p.listing.files.forEach (file)->
                            if file.name.indexOf('/')>0 
                                atLeastOneFileInSubdirectory = yes
                        
                        atLeastOneFileInSubdirectory.should.be.true
                
                    it 'has some properties describing the file', ()->                
                        p.files.forEach (file)->
                            file.should.have.keys ['name','sha1','path']

                    it 'path is directly resolvable', ()->                
                        p.files.forEach (file)->
                            file.should.have.keys ['name','sha1','path']    

                    it 'contains the hex digest sha1 of the file', ()->                
                        p.files.forEach (file)->
                            content = fs.readFileSync file.path
                            file.sha1.should.equal(sha1.calculate(content))

            describe 'the content saved in it', ->

                file = null

                beforeEach (done)->
                    store.readPackage p.uid, (err,storedPackageStream)->
                        file = storedPackageStream.pipe(unzip.Parse())
                        done()

                it 'the package content file is a zip file', (done)->

                    onEntryHandler = sinon.spy()

                    file.on 'entry', onEntryHandler
                    file.on 'close', ()->
                        onEntryHandler.should.have.been.called.once
                        done()      

                it 'contains a .q.listing file', (done)->
                    foundListing = no

                    file.on 'entry', (entry)->
                        foundListing = true if entry.path is '.q.listing'

                    file.on 'close', ()->
                        foundListing.should.be.true
                        done()                    

                it 'contains all three files + listing', (done)->
                    fileCount = 0

                    file.on 'entry', (entry)->
                        fileCount++

                    file.on 'close', ()->
                        fileCount.should.equal(4)
                        done()                    
               
        describe 'signing a package', ->

            it 'with a private key', (done) ->

                # key as generated by 'ssh-keygen -t rsa -C "your_email@example.com"'
                options = 
                    store: store
                    signedBy: 'your_email@example.com'
                    key: fs.readFileSync("#{__dirname}/id_rsa")

                q = new Q(options)        
                p = q.pack TEST_FOLDER, (err)->
                    done()

                    p.signed.should.be.true
                    p.signedBy.should.equal 'your_email@example.com'
                    p.signature.should.equal 'yUk4A9/pvYBpc/bhKoP5O3wNFGHXBxnGTNPwtTkb5T7M+U3EIo3yv+tJq6mM4i5sh5DSfFUrf3rhUAQ6y3KBmZgG65ZI90yhf5kodptTcUZaZu3n2VGqRQ12BfwPfccTn4kTqPrAVJJN3qm5ojR5iUyobjJ6I1LfT63tToHowvGm3/NdtXmtpE131En9dvFqyHkEcQYGRaesRRQsyoS7NaZQn/ULns6qHwOnDBE9/lyxl0LEp80jZEMe9UHiF1Ax79eWcLq4Pq5RIv0GqJGH1/i9GvQVyYSH8++uutrqS2nQC5SnQR5gw0OK2GuZGIDV0G45Nd3plAlXwSnV5hO53w=='

                    

        describe 'exclusions', ->
        
            it 'excludes .q folder', (done)->

                createQCacheFolderWithContent ->

                    q.pack TEST_FOLDER, (err, p)->            
                        includesAFileFromQCacheFolder = no
                        
                        p.files.forEach (file)->
                            if file.name.indexOf('.q')==0 
                                includesAFileFromQCacheFolder = yes
                        
                        includesAFileFromQCacheFolder.should.be.false
                        done()

            createQCacheFolderWithContent = (done)->
                tempFile = path.join Q_CACHE_FOLDER, 'temp.txt'
                fs.mkdirSync Q_CACHE_FOLDER
                fs.writeFileSync tempFile, "dummy"    
                setTimeout done,50


    describe 'packing test-folder-a-new', ->
        
        TEST_FOLDER = "#{__dirname}/test-folder-a-new"
        
        beforeEach ()->
            wrench.rmdirSyncRecursive Q_CACHE_FOLDER if fs.existsSync Q_CACHE_FOLDER

        describe 'call to pack', ->

            it 'returns the package directly', (done)->
                p = q.pack TEST_FOLDER, ->
                    expect(p).to.not.be.undefined
                    done()