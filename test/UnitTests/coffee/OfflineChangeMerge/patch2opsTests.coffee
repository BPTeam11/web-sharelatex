sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/OfflineChangeMerge/OfflineChangeHandler.js"
SandboxedModule = require('sandboxed-module')
Errors = require "../../../../app/js/errors"

describe "patch2ops", ->
  beforeEach ->
    @OfflineChangeHandler = SandboxedModule.require modulePath, requires:  
      "../Project/ProjectEntityHandler": @ProjectEntityHandler = {},
      "../DocumentUpdater/DocumentUpdaterHandler": @DocumentUpdaterHandler = {}
    @callback = sinon.spy()

  describe "when the patch contains one change", ->
    describe "when the change contains two inserts", ->
      beforeEach ->
        @patch = {
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
          }
        #console.log @patch
        @ops = @OfflineChangeHandler.patch2ops(@patch)
    
      it "should return the right insert ops", ->
        JSON.stringify(@ops).should.equal JSON.stringify([
          { p: 3, i: 'z' }, { p: 7, i: 'g' } ])

    describe "when the change contains two deletes", ->
      beforeEach ->
        @patch = {
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
          }
        #console.log @patch
        @ops = @OfflineChangeHandler.patch2ops(@patch)
    
      it "should return the right delete ops", ->
        JSON.stringify(@ops).should.equal JSON.stringify([
          { p: 3, d: 'z' }, { p: 6, d: 'g' } ])

