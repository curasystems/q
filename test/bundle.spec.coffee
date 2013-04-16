q = require '..'
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
        
        describe 'call to bundle', ->

            it 'returns an the package directly', (done)->
                p = q.bundle "#{__dirname}/test-folder-a/q.manifest", ->
                    expect(p).to.not.be.undefined
                    done()

            it 'returns the package also via the callback', (done)->
                p = q.bundle "#{__dirname}/test-folder-a/q.manifest", (err,pkg)->
                    pkg.should.equal(p)
                    done()                            

            it 'is an event emitter', ()->
                p = q.bundle "#{__dirname}/test-folder-a/q.manifest", ()->
                    expect(p).to.respondTo('on')                   

        describe 'package events', ->
            
            it 'when its finished it emits an "end" event', (done)->                    
                shouldEmitEvent 'end', done 

            it 'emits an "file" event for each file added', (done)->
                shouldEmitEvent 'file', done 

            shouldEmitEvent = (name, done)->
                eventHandler = sinon.spy()
                
                p = q.bundle "#{__dirname}/test-folder-a/q.manifest", ->
                    eventHandler.should.have.been.called
                    done()            

                p.on name, eventHandler

        describe 'package properties', ->

            p = null

            beforeEach (done)->
                p = q.bundle "#{__dirname}/test-folder-a/q.manifest", (err)->
                    done()
            
            it 'knows the name of the package', -> p.name.should.equal 'my-package'
            it 'knows the version of the package', -> p.version.should.equal '0.1.0'
            it 'knows the description of the package', -> p.description.should.equal 'My Description'

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








                



                

