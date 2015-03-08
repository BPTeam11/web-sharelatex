DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()
strInject= (s1, pos, s2) -> s1[...pos] + s2 + s1[pos..]
strDel = (s1, pos, length) -> s1[...pos] + s1[(pos+length)..]

module.exports = OfflineChangeHandler =
  
  computeChange: (project_id, user_id, sessionId, doc, callback = (project_id, doc_id, change) ->)->

    console.log "MergeHandler here :)  Old version"
    console.log doc.version

    @getDocumentText project_id, doc.doc_id, doc.version, (oldDocText, onlineDocText, onlineVersion) =>
      @merge oldDocText, doc.doclines.join('\n'), onlineDocText, (mergingOps) ->
        #TODO test if anything breaks if mergingOps == []
        change = {
          doc: doc.doc_id
          op: mergingOps
          v : onlineVersion
          meta : {
            source: sessionId
            user_id: user_id
          }
        }
        console.log user_id
        callback(project_id, doc.doc_id, change)

  # generates a given document at a previous version
  # this version of the document should be common to all participating clients,
  # thus it will usually be the version *before* a client went offline.
  # It is the clients responsibility to provide this version number when coming back.
  getDocumentText: (project_id, doc_id, version, callback = (oldDocText, onlineDocText, onlineVersion) -> ) ->
    @getPreviousOps project_id, doc_id, version, (onlineDocLines, previousOps, onlineVersion) =>
      oldDocText = onlineDocLines.join('\n')
      onlineDocText = onlineDocLines.join('\n')

      # go through the array from back to front and reverse ops
      if previousOps.length != 0
        for i in [(previousOps.length-1)..0]
          for op in previousOps[i].op
            oldDocText = @reverseOp(oldDocText, op)

      callback(oldDocText,onlineDocText, onlineVersion)

  # getPreviousOps returns the list of operations from 'version' to current,
  #   as well as the current document
  # arguments:
  #   project_id, doc_id: as always
  #   version: previously common document version
  # output:
  #   onlineDocLines: lines of the current online document
  #   previousOps: Operations that transformed the document from version 'version' to
  #     the current version
  #   onlineVersion: the current document version (TODO: delete if unneeded)
  getPreviousOps: (project_id, doc_id, version, callback = (onlineDocLines, previousOps, onlineVersion) -> ) ->
    DocumentUpdaterHandler.getDocument project_id, doc_id, version, (err, temp, version1, previousOps)->
      DocumentUpdaterHandler.getDocument project_id, doc_id, -1, (err, onlineDocLines, onlineVersion, opsNew)->
        callback(onlineDocLines, previousOps, onlineVersion)

  merge: (oldDocText, offlineDocText, onlineDocText, callback = (mergingOps) ->) ->
    # if this is smaller then the algorithm is more careful.
    # For high Threshold it will override even if there's a confilct.
    dmp.Match_Threshold = 0.1

    patch = dmp.patch_make(oldDocText, offlineDocText)
    # patch: start1 and start2 are the respective positions of changes in the two texts
    result = dmp.patch_apply(patch, onlineDocText)

    #To get the changes from the onlineDocText to the merged Text
    #patchedDocument = result[0]
    #result2 = dmp.patch_make(patchedDocument, onlineDocText)

    #The results[1] list is only useful if it is as long as the patch list
    @convertPatchToOps patch, (mergingOps) -> callback(mergingOps)

  convertPatchToOps: (patch, callback = (ops, err) -> ) -> 
    ops = []
    for change in patch
      offset = 0
      for diff in change.diffs
        switch diff[0]
          when 0 # context
            offset += diff[1].length

          when 1 # insert
            ops.push { p: change.start2 + offset, i: diff[1] }
            offset += diff[1].length

          when -1 # delete
            ops.push { p: change.start2 + offset, d: diff[1] }

    callback(ops, null)


  reverseOp: (docText, op) ->
    changedDoc = docText
    if(op.i?)
      changedDoc = strDel docText, op.p, op.i.length
    else if(op.d?)
      changedDoc = strInject docText, op.p, op.d
    changedDoc

