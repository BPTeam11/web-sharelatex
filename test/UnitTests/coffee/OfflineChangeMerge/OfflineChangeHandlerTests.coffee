sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/OfflineChangeMerge/OfflineChangeHandler.js"
SandboxedModule = require('sandboxed-module')


createOp = (pos, operation, text) ->
  new_op =
    p:pos
  new_op[operation] = text
  result =
    doc: @doc_id
    op: [ new_op ]
    v:  @version
    meta: 'mock_meta'


describe "OfflineChangeHandler", ->
  beforeEach ->
    @OfflineChangeHandler = SandboxedModule.require modulePath, requires:
      "../DocumentUpdater/DocumentUpdaterHandler": @DocumentUpdaterHandler = {}

    @project_id = "project-id-123"
    @doc_id = "doc-id-123"
    @user_id = "1234"
    @sessionId = "1234"
    @version = 42
    @callback = sinon.spy()
  
  describe "patchMake", ->
    it "should", ->
      console.log "offline patch"
      @OfflineChangeHandler.patchMake("es war einmal ein kleiner zaun zzaaaa", "es war einmal ein kleiner zaun zzaabbaa")
      console.log "online patch"
      @OfflineChangeHandler.patchMake("es war einmal ein kleiner zaun zzaaaa", "es einmal ein kleiner zaun zz")
      
  
  
  describe "mergeAndIntegrate", ->
    beforeEach ->
    
    describe "when there is a conflict", ->
      beforeEach ->
        
        @OfflineChangeHandler.getDocumentText =
          sinon.stub().callsArgWith(@oldDocText, @onlineDocText, @version)
        
    
    it "should insert merge braces", ->
      #console.log @oldDocText
      #@OfflineChangeHandler
      #  .mergeWhenPossible @project_id, @user_id, @sessionId, @doc,
      #    @callback
      #true.should.equal true
      @oldDocText     = "es war einmal ein kleiner zaun zzaaaa"
      @offlineDocText = "es war einmal ein kleiner zaun zzaabbaa"
      @onlineDocText  = "es einmal ein kleiner zaun zz"
      @doc = {
        version: 42
        doc_id: "doc-id-123"
        doclines: @offlineDocText
        }
      @ofp = [ {
        diffs: [ [ 0, 'aun zzaa' ], [ 1, 'bb' ], [ 0, 'aa' ] ],
        start1: 27,
        start2: 27,
        length1: 10,
        length2: 12,
        end1: 36,
        end2: 38,
        offset: 2,
        context1: 8,
        context2: 2 } ]
      @onp = [
        {
          diffs: [ [ 0, 'es ' ], [ -1, 'war ' ], [ 0, 'einm' ] ],
          start1: 0,
          start2: 0,
          length1: 11,
          length2: 7,
          end1: 10,
          end2: 6,
          offset: -4,
          context1: 3,
          context2: 4 },
        {
          diffs: [ [ 0, 'n zz' ], [ -1, 'aaaa' ] ],
          start1: 29,
          start2: 25,
          length1: 8,
          length2: 4,
          end1: 36,
          end2: 28,
          offset: -4,
          context1: 4,
          context2: 0 } ]
      @OfflineChangeHandler.mergeAndIntegrate @offlineDocText, @onlineDocText, @ofp, @onp,
        @callback
  
  ###
  describe "getDocumentText", ->
    beforeEach ->

      @oldDocLines    = ["n",       "n+del" , "del" ,"n++n"  , "cc"     ]
      @onlineDocLines = ["n", "in", "n+"            ,"n+in+n", "hh" , ""]
  
      @ops = []
      @ops[0] = createOp(2, 'i', "in\n") #"n\nin\nn+del\ndel\nn++n\ncc"
      @ops[1] = createOp(11, 'd', "del\n") #"n\nin\nn+del\nn++n\ncc"
      @ops[2] = createOp(18, 'i', "\n") #"n\nin\nn+del\nn++n\ncc\n"
      @ops[3] = createOp(16, 'd', "cc") #"n\nin\nn+del\nn++n\n\n"
      @ops[4] = createOp(13, 'i', "in") #"n\nin\nn+del\nn+in+n\n\n"
      @ops[5] = createOp(7, 'd', "del") #"n\nin\nn+\nn+in+n\n\n"
      @ops[6] = createOp(15, 'i', "hh") #"n\nin\nn+\nn+in+n\nhh\n"



    describe "when the document exists", ->
      beforeEach ->
        @OfflineChangeHandler.getPreviousOps =
          sinon.stub().callsArgWith(3, @onlineDocLines, @ops, @version)
        @OfflineChangeHandler
          .getDocumentText(@project_id, @doc_id, @version, @callback)



      it "should return the document before the changes from ops were applied", ->
        @callback
          .calledWithExactly(@oldDocLines.join("\n"),@onlineDocLines.join("\n"), @version)
          .should.equal true


    #TODO describe "when the document doesn't exist", ->
    

  describe "reverseOp", ->
    describe "when the operation is an insert", ->
      beforeEach ->
        @docTextbeforeOp = "insert and nothing else"
        @docTextafterOp  = "insert <this> and nothing else"

      it "should return the document before the changes from ops were applied", ->
        result = @OfflineChangeHandler.reverseOp(@docTextafterOp, {p:7, 'i':"<this> "})
        #console.log result
        result.should.equal @docTextbeforeOp

    describe "when the operation is a delete", ->
      beforeEach ->
        @docTextbeforeOp = "delete <this> and nothing else"
        @docTextafterOp  = "delete and nothing else"

      it "should return the document before the changes from ops were applied", ->
        result = @OfflineChangeHandler.reverseOp(@docTextafterOp, {p:7, 'd': "<this> "})
        #console.log result
        result.should.equal @docTextbeforeOp
  ###
