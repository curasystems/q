q = require '..'
{expect, sinon} = require './testing'

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

        it 'the bundle is also returned to the callback', (done)->
            q.bundle "#{__dirname}/test-folder-a/q.manifest", (err,bundle)->
                bundle.files.should.not.be.empty
                done()            

        it 'the bundle is also returned to the callback', (done)->
            bundleReturned = q.bundle "#{__dirname}/test-folder-a/q.manifest", (err,bundle)->
                bundleReturned.should.equal(bundle)
                done()            





            

