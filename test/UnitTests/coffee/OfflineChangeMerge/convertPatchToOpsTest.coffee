sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/OfflineChangeMerge/OfflineChangeHandler.js"
SandboxedModule = require('sandboxed-module')
Errors = require "../../../../app/js/errors"

describe "OfflineChangeHandler", ->
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

	describe "convertPatchToOps", ->
		
		describe "when the patch is empty", ->
			beforeEach ->
				@patch = []
				@OfflineChangeHandler.convertPatchToOps(@patch, @callback)

			it "should return no ops", ->
				@callback.calledWith([]).should.equal true
		
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
				@callback.calledWith([]).should.equal true
		
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
				console.log @patch
				@OfflineChangeHandler.convertPatchToOps(@patch, @callback)
		
			it "should return the right insert ops", ->
				@callback.calledWith([ { p: 669, i: 'z' }, { p: 673, i: 'g' } ])
					.should.equal true
				
				
				
				
				
				