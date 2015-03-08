sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/OfflineChangeMerge/OfflineChangeHandler.js"
SandboxedModule = require('sandboxed-module')
Errors = require "../../../../app/js/errors"

describe "convertPatchToOps", ->
  beforeEach ->
    @OfflineChangeHandler = SandboxedModule.require modulePath, requires:  
      "../Project/ProjectEntityHandler": @ProjectEntityHandler = {},
      "../DocumentUpdater/DocumentUpdaterHandler": @DocumentUpdaterHandler = {}
    @callback = sinon.spy()

  describe "when the patch is empty", ->
    beforeEach ->
      @patch = []
      @ops = @OfflineChangeHandler.convertPatchToOps(@patch)

    it "should return no ops", ->
      JSON.stringify(@ops).should.equal JSON.stringify([])

  describe "when the patch contains one change", ->
    describe "when the change contains two inserts", ->
      beforeEach ->
        @patch = [{
          diffs: [
            [ 0, 'abc' ],
            [ 1, 'z' ],
            [ 0, 'def' ],
            [ 1, 'g' ],
            [ 0, 'hij' ]
            ],
          start1: 0,
          start2: 0,
          length1: 9,
          length2: 11
          }]
        #console.log @patch
        @ops = @OfflineChangeHandler.convertPatchToOps(@patch)
    
      it "should return the right insert ops", ->
        JSON.stringify(@ops).should.equal JSON.stringify([
          { p: 3, i: 'z' }, { p: 7, i: 'g' } ])

    describe "when the change contains two deletes", ->
      beforeEach ->
        @patch = [{
          diffs: [
            [ 0, 'abc' ],
            [ -1, 'z' ],
            [ 0, 'def' ],
            [ -1, 'g' ],
            [ 0, 'hij' ]
            ],
          start1: 0,
          start2: 0,
          length1: 11,
          length2: 9
          }]
        #console.log @patch
        @ops = @OfflineChangeHandler.convertPatchToOps(@patch)
    
      it "should return the right delete ops", ->
        JSON.stringify(@ops).should.equal JSON.stringify([
          { p: 3, d: 'z' }, { p: 6, d: 'g' } ])

  describe "when the patch contains two interconnected changes", ->
    #oldDocText = "Once there was a ship, on which it was very freezy, so that is why this boat was being called 'goat'"
    #offlineDocText = "Once there was a boat, on which it was quite cold, so was this boat called 'goat'"
    #onlineDocText = "I love pizza!"
    beforeEach ->
        @patch = [{
          diffs: [
            [ 0, 's a ' ],
            [ -1, 'ship' ],
            [ 1, 'boat' ],
            [ 0, ', on' ]
            ],
          start1: 13,
          start2: 13,
          length1: 12,
          length2: 12
          }, {
          diffs: [
            [ 0, 'was ' ],
            [ -1, 'very freezy, so that is why this boat was being' ],
            [ 1, 'quite cold, so was this boat' ],
            [ 0, ' cal' ]
            ],
          start1: 35,
          start2: 35,
          length1: 55,
          length2: 36
          }]
        #console.log @patch
        @ops = @OfflineChangeHandler.convertPatchToOps(@patch)
    
      it "should return the right operations from both changes", ->
        JSON.stringify(@ops).should.equal JSON.stringify([
          { p: 17, d: 'ship' },
          { p: 17, i: 'boat' },
          { p: 39, d: 'very freezy, so that is why this boat was being' },
          { p: 39, i: 'quite cold, so was this boat' }
          ])
          
