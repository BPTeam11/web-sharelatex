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
  

  describe "when the patch contains one insert", ->
    beforeEach ->
      @patch = [ {
        diffs: [
          [ 0, 'abcd' ],
          [ 1, '  ' ],
          [ 0, 'efgh' ]],
        start1: 0,
        start2: 0,
        length1: 8,
        length2: 10 } ]
      @OfflineChangeHandler.convertPatchToOps(@patch, @callback)

    it "should return the right insert op", ->
      #console.log @callback.lastCall
      @callback.calledWithExactly([{p:4 , i:'  '}], null).should.equal true

  describe "when the patch contains two inserts", ->
    beforeEach ->
      @patch = [{
        diffs: [
          [ 0, 'abc' ],
          [ 1, 'z' ],
          [ 0, 'def' ],
          [ 1, 'g' ],
          [ 0, 'hij' ]
          ],
        start1: 666,
        start2: 666,
        length1: 42,
        length2: 41
        }]
      #console.log @patch
      @OfflineChangeHandler.convertPatchToOps(@patch, @callback)
  
    it "should return the right insert ops", ->
      @callback.calledWithExactly([ { p: 669, i: 'z' }, { p: 673, i: 'g' } ], null)
        .should.equal true

  describe "when one delete patch is applied", ->
    beforeEach ->
      @patch = [ {
        diffs: [
          [ 0, 'abcd' ],
          [ -1, '  ' ],
          [ 0, 'efgh' ]
          ],
        start1: 0,
        start2: 0,
        length1: 10,
        length2: 8 } ]
      @OfflineChangeHandler.convertPatchToOps(@patch, @callback)

    it "should return the right delete op", ->
      #console.log @callback.lastCall
      @callback.calledWithExactly([{p:4 , d:'  '}], null).should.equal true

  describe "TODO: when two delete patches are applied", ->
    beforeEach ->
      @patch = [{
        diffs: [
          [ 0, 'abc' ],
          [ -1, 'z' ],
          [ 0, 'def' ],
          [ -1, 'g' ],
          [ 0, 'hij' ]
          ],
        start1: 666,
        start2: 666,
        length1: 42,
        length2: 41
        }]
      #console.log @patch
      @OfflineChangeHandler.convertPatchToOps(@patch, @callback)
  
    it "should return the right delete ops", ->
      @callback.calledWithExactly([ { p: 669, d: 'z' }, { p: 672, d: 'g' } ], null)
        .should.equal true
