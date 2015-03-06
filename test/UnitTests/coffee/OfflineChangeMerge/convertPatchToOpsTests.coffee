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
    @patch = [{
      diffs: [
        [ 0, 'abc' ],
        [ -1, 'z' ],
        [ 0, 'def' ],
        [ 1, 'g' ],
        [ 0, 'hij' ]
        ],
      start1: 666,
      start2: 666,
      length1: 42,
      length2: 41
      }]

  describe "when the patch is empty", ->
    beforeEach ->
      @patch = []
      @OfflineChangeHandler.convertPatchToOps(@patch, @callback)

    it "should return no ops", ->
      @callback.calledWithExactly([], null).should.equal true

  describe "when the patch contains no changes", ->
    beforeEach ->
      @patch = [{
        diffs: [
          [ 0, 'abc' ],
          [ 0, 'def' ]
          ],
        start1: 666,
        start2: 666,
        length1: 42,
        length2: 41
        }]
      @OfflineChangeHandler.convertPatchToOps(@patch, @callback)
  
    it "should return no ops", ->
      @callback.calledWithExactly([], null).should.equal true
  
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
          length1: 10,
          length2: 10
          }]
        #console.log @patch
        @OfflineChangeHandler.convertPatchToOps(@patch, @callback)
    
      it "should return the right insert ops", ->
        @callback.calledWithExactly([ { p: 3, i: 'z' }, { p: 7, i: 'g' } ], null)
          .should.equal true

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
          length1: 10,
          length2: 10
          }]
        #console.log @patch
        @OfflineChangeHandler.convertPatchToOps(@patch, @callback)
    
      it "should return the right delete ops", ->
        @callback.calledWithExactly([ { p: 3, d: 'z' }, { p: 6, d: 'g' } ], null)
          .should.equal true

  describe "when the patch contains two interconnected changes", ->
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
          length1: 10,
          length2: 10
          }, {
          diffs: [
            [ 0, 'abcz' ],
            [ 1, 'y' ],
            [ 0, 'def' ],
            [ -1, 'g' ],
            [ 0, 'hij' ]
            ],
          start1: 0,
          start2: 0,
          length1: 10,
          length2: 10
          }]
        #console.log @patch
        @OfflineChangeHandler.convertPatchToOps(@patch, @callback)
    
      it "should return all operations from both changes", ->
        @callback.calledWithExactly([
          { p: 3, i: 'z' },
          { p: 7, i: 'g' },
          { p: 4, i: 'y' },
          { p: 8, d: 'g' }], null)
          .should.equal true
          
