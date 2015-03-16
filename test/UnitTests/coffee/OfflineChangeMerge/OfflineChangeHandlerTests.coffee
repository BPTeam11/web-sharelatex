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
    @version = 42
    @callback = sinon.spy()


  describe "merge", ->
    beforeEach ->
      @OfflineChangeHandler.convertPatchesToOps = sinon.spy()

    describe "when the document only changed offline", ->
      beforeEach ->
        @oldText     = "Text not changed."
        @onlineText  = "Text not changed."
        @offlineText = "Text changed offline."
        @patch = [ {
          diffs: [
            [ 0, 'ext ' ],
            [ -1, 'not ' ],
            [ 0, 'changed' ],
            [ 1, ' offline' ],
            [ 0, '.' ] ],
          start1: 1,
          start2: 1,
          length1: 16,
          length2: 20 } ]
    
        @patchIndicator = [ true ]
        @OfflineChangeHandler.merge(@oldText, @offlineText, @onlineText, @callback)
    
      it "should apply all offline changes", ->
        # FIXME: This is a workaround for comparing two arrays. There should be
        # a canonical way for doing this.
        JSON.stringify(@OfflineChangeHandler.convertPatchesToOps.getCall(0).args[0])
          .should.equal JSON.stringify(@patch)

    describe "when the document only changed online", ->
      beforeEach ->
        @oldText     = "Text not changed."
        @onlineText  = "Text changed online."
        @offlineText = "Text not changed."

        @OfflineChangeHandler.merge(@oldText,@offlineText,@onlineText, @callback)

      it "should make no changes", ->
        @OfflineChangeHandler.convertPatchesToOps
          .calledWith([]).should.equal true
    ###
    describe "when the document was changed both offline and online", ->
      describe "when offline a line was deleted in which online text was inserted", ->
        beforeEach ->
          @oldText = """
          line1
          line2
          line3
          """
          @onlineText = """
          line1
          line2 hello
          line3
          """
          @offlineText = """
          line1
          line3
          """
          @OfflineChangeHandler.merge(@oldText,@offlineText,@onlineText, @callback)
        
        it "should do something", ->
          for patch in @OfflineChangeHandler.convertPatchesToOps.getCall(0).args[0]
            console.log patch
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
