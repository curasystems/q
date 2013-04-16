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
        
        it 'returns an EventEmitter object to track progress', (done)->
            bundle = q.bundle "#{__dirname}/test-folder-a/q.manifest", ->
                expect(bundle).to.not.be.undefined
                expect(bundle).to.respondTo('on')
                done()

        it 'when its finished it emits an "end" event', (done)->
            endEventHandler = sinon.spy()

            bundle = q.bundle "#{__dirname}/test-folder-a/q.manifest", ->
                endEventHandler.should.have.been.calledOnce
                done()            

            bundle.on 'end', endEventHandler

        it 'emits an "file" event for each file added', (done)->
            addedEventHandler = sinon.spy()

            bundle = q.bundle "#{__dirname}/test-folder-a/q.manifest", ->
                addedEventHandler.should.have.been.called
                done()            

            bundle.on 'file', addedEventHandler

        it 'returns the bundle also via the callback', (done)->
            bundleReturned = q.bundle "#{__dirname}/test-folder-a/q.manifest", (err,bundle)->
                bundleReturned.should.equal(bundle)
                done()            

        describe 'files in bundle', ->

            bundle = null

            beforeEach (done)->
                bundle = q.bundle "#{__dirname}/test-folder-a/q.manifest", (err)->
                    done()
                
            it 'stored in files property', ()->
                bundle.files.should.not.be.empty

            it 'contains files from subfolders too ', ()->
                atLeastOneFileInSubdirectory = no
                
                bundle.files.forEach (file)->
                    if file.name.indexOf('/')>0 
                        atLeastOneFileInSubdirectory = yes
                
                atLeastOneFileInSubdirectory.should.be.true
        
            it 'has some properties describing the file', ()->                
                bundle.files.forEach (file)->
                    file.should.have.keys ['name','sha1','path']

            it 'path is directly resolvable', ()->                
                bundle.files.forEach (file)->
                    file.should.have.keys ['name','sha1','path']    

            it 'contains the hex digest sha1 of the file', ()->
                
                bundle.files.forEach (file)->
                    content = fs.readFileSync file.path
                    file.sha1.should.equal(sha1.calculate(content))



            



            

