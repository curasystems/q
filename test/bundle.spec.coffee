q = require '..'
fs = require 'fs'
path = require 'path'

{expect, sinon} = require './testing'
sha1 = require '../lib/sha1'


describe 'bundling packages', ->

    it 'requires a path to a manifest and a callback', ->
        expect( ()->q.bundle() ).to.throw()

    it 'requires the manifest path to be parsable yaml', (done)->
        q.bundle "#{__dirname}/test-folder-a/q.invalid-manifest", (err)->
            expect(err).to.be.instanceof(q.InvalidManifestError)
            done()

    describe 'bundling test-folder-a', ->
        
        TEST_FOLDER_A_MANIFEST = "#{__dirname}/test-folder-a/q.manifest"
        TEST_FOLDER_A = path.dirname( TEST_FOLDER_A_MANIFEST )

        Q_CACHE_FOLDER = "#{TEST_FOLDER_A}/.q"

        beforeEach (done)->
            fs.rmdir Q_CACHE_FOLDER, ()->done()

        describe 'call to bundle', ->

            it 'returns the package directly', (done)->
                p = q.bundle TEST_FOLDER_A_MANIFEST, ->
                    expect(p).to.not.be.undefined
                    done()

            it 'returns the package also via the callback', (done)->
                p = q.bundle TEST_FOLDER_A_MANIFEST, (err,pkg)->
                    pkg.should.equal(p)
                    done()                            

            it 'is an event emitter', ()->
                p = q.bundle TEST_FOLDER_A_MANIFEST, ()->
                    expect(p).to.respondTo('on')                   

        describe 'package events', ->
            
            it 'when its finished it emits an "end" event', (done)->                    
                shouldEmitEvent 'end', done 

            it 'emits an "file" event for each file added', (done)->
                shouldEmitEvent 'file', done 

            shouldEmitEvent = (name, done)->
                eventHandler = sinon.spy()
                
                p = q.bundle TEST_FOLDER_A_MANIFEST, ->
                    eventHandler.should.have.been.called
                    done()            

                p.on name, eventHandler

        describe 'after bundle is completed', ->

            p = null

            beforeEach (done)->
                p = q.bundle TEST_FOLDER_A_MANIFEST, (err)->
                    done()

            describe 'package has properties', ->
                
                it 'knows the name of the package', -> p.name.should.equal 'my-package'
                it 'knows the version of the package', -> p.version.should.equal '0.1.0'
                it 'knows the description of the package', -> p.description.should.equal 'My Description'
                it 'has a path where the directory root is', -> p.path.should.equal path.normalize("#{__dirname}/test-folder-a")
                it 'has a manifestPath where the manifest was found', -> p.manifestPath.should.equal path.normalize(TEST_FOLDER_A_MANIFEST)
                it 'has a cachePath where the package is cached', -> p.cachePath.should.not.be.empty
                it 'has a package uid which identifies the package', -> p.uid.should.not.be.empty

                describe 'files in package', ->
        
                    it 'stored in files property', ()->
                        p.files.should.not.be.empty

                    it 'contains files from subfolders too ', ()->
                        atLeastOneFileInSubdirectory = no
                        
                        p.files.forEach (file)->
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


            describe 'package saved', ->

                it 'saves the package in a folder called .q next to the q.manifest', ->
                    stats = fs.statSync Q_CACHE_FOLDER
                    stats.isDirectory().should.be.true

                it 'the package content is stored in the cache folder in git like structure', ->

                    firstDir = 'objects'
                    secondDir = p.uid.substr 0,2
                    filename = p.uid.substr(2) + '.pkg'

                    (p.uid + '.pkg').should.equal( secondDir + filename )

                    packageFilePath = path.join Q_CACHE_FOLDER, firstDir, secondDir, filename

                    stats = fs.statSync packageFilePath
                    stats.isFile().should.be.true
                    
        describe 'exclusions', ->
        
            it 'excludes .q folder', (done)->

                createQCacheFolderWithContent ->

                    q.bundle TEST_FOLDER_A_MANIFEST, (err, p)->            
                        includesAFileFromQCacheFolder = no
                        
                        p.files.forEach (file)->
                            if file.name.indexOf('.q')==0 
                                includesAFileFromQCacheFolder = yes
                        
                        includesAFileFromQCacheFolder.should.be.false
                        done()

            createQCacheFolderWithContent = (done)->
                tempFile = path.join Q_CACHE_FOLDER, 'temp.txt'
                fs.writeFileSync tempFile, "dummy"    
                setTimeout done,50

