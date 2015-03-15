DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()
strInject= (s1, pos, s2) -> s1[...pos] + s2 + s1[pos..]
strDel = (s1, pos, length) -> s1[...pos] + s1[(pos+length)..]

###
  For the vocabulary:
  of = offline  (opposite to on)
  on = online   (opposite to of)
  p  = patch
  c  = conflict (opposite to m)
  m  = merged   (opposite to c)
  
  Therefore,
  ofp  = offline patches
  onp  = online patches
  mp   = merged patches
  ofc  = offline conflicts
  onc  = online conflicts
  etc...
  
  Without these abbreviations, the code would have become extremely verbose.
  We can Search/Replace them later if needed
  
###


module.exports = OfflineChangeHandler =
  
  # let the "old document" be the document before a client went offline
  # doc: offline Document after the client made changes to it

  # computeChange generates a list of changes that will try to apply
  #   changes which were made to the old document offline
  #   to the current document retroactively.
  computeChange: (project_id, user_id, sessionId, doc, callback = (project_id, doc_id, change) ->)->

    console.log "MergeHandler here :)  Old version:"
    console.log doc.version

    @getDocumentText project_id, doc.doc_id, doc.version, (oldDocText, onlineDocText, onlineVersion) =>
      @getPatches oldDocText, doc.doclines.join('\n'), onlineDocText, (ofp, onp) =>
        @mergeAndIntegrate ofp, onp, (mp, ofc, onc) =>
          ops = @convertPatchesToOps mp
          # ignore conflicts for now
          # this may be splitted up into single ops:
          change = {
            doc: doc.doc_id
            op: ops
            v : onlineVersion
            meta : {
              source: sessionId
              user_id: user_id
            }
          }
        console.log user_id
        callback(project_id, doc.doc_id, change)
  
  ###
    offline- and online-Patch need to be sorted
    ofc and onc do not necessarily have the same length
   
    merging the patches and adding up offsets ("integrating"), then splitting
    the results into dedicated arrays. These things are best done in one loop.
  ###
  mergeAndIntegrate: (ofp, onp, callback = (mp, ofc, onc) -> ) ->
    # utilizing heavy iterative style here for efficiency
    # Assuming that the DMP context length is always 4 characters!
    cl = 4
    i = 0 # ofp iterator
    j = 0 # onp iterator
    
    mp = []
    ofc = []
    onc = []
    patchOffset = 0
    
    # these values say whether
    # 1.) the current off/online index did not change since last iteration
    # 2.) the according patch conflicted with a previous patch, which means
    #     that we want to add it to the ofc/onc array at a later point.
    currentOfflineConflict = false
    currentOnlineConflict  = false

    while (i < ofp.length || j < onp.length)
    
      # TODO: use the main logger for this
      if currentOfflineConflict && currentOnlineConflict
        console.log "ERROR: offline and online conflict! This should not happen!"
      
      # update offline patch bounds
      if (i < ofp.length && !currentOfflineConflict)
        currentOfflinePatchStart = ofp[i].start1 + cl
        currentOfflinePatchEnd   = currentOfflinePatchStart + ofp[i].length1 - 1 - cl
      
      # update online patch bounds
      if (j < onp.length && !currentOnlineConflict)
        currentOnlinePatchStart  = onp[j].start1 + cl
        currentOnlinePatchEnd    = currentOnlinePatchStart + onp[j].length1 - 1 - cl

      # --- Checking for conflicts
      ###
        The general idea is that we operate on the patch with the lower position first.
        If there is a conflict, we keep the patch with a higher position in mind to check if
        there are are any later conflicting changes coming. Because the patches
        from DMP are sorted by default, once we find that the next higher patch
        does *not* conflict, we can be sure that none of the later patches will
        conflict.
      ###
      
      # offlinePatch first, no conflict
      if (currentOfflinePatchEnd < currentOnlinePatchStart) && (i < ofp.length)
        # no conflict with upcoming online patch, but we need to clean up the old conflict first
        if currentOfflineConflict
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
        else
          # integrate offlinePatch
          ofp[i].start1 += patchOffset
          ofp[i].start2 += patchOffset
          patchOffset += ofp[i].length2 - ofp[i].length1
          mp.push ofp[i]
          i++
      
      # onlinePatch first, no conflict
      else if (currentOnlinePatchEnd < currentOfflinePatchStart) && (j < onp.length)
        # no conflict with upcoming offline patch, but we need to clean up the old conflict first
        if currentOnlineConflict
          onc.push onp[j]
          j++
          currentOnlineConflict = false
        else
          # integrate onlinePatch
          onp[j].start1 += patchOffset
          onp[j].start2 += patchOffset
          patchOffset += onp[j].length2 - onp[j].length1
          mp.push onp[j]
          j++

      # otherwise, it's a conflict
      else
        # the new patch offset depends on which action will be taken to resolve
        # the conflict! For now, no action is taken.
        # patchOffset += ???
        
        # there may later be an overlap with online
        if (currentOfflinePatchEnd < currentOnlinePatchEnd)
          ofp[i].start1 += patchOffset
          ofp[i].start2 += patchOffset
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
          currentOnlineConflict = true
        # there may later be an overlap with offline
        else if (currentOnlinePatchEnd < currentOfflinePatchEnd)
          onp[j].start1 += patchOffset
          onp[j].start2 += patchOffset
          onc.push onp[j]
          j++
          currentOnlineConflict = false
          currentOfflineConflict = true
        # they have equal ends, no overlap with later patches possible
        else
          ofp[i].start1 += patchOffset
          ofp[i].start2 += patchOffset
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
          onp[j].start1 += patchOffset
          onp[j].start2 += patchOffset
          onc.push onp[j]
          j++
          currentOnlineConflict = false
    
    callback(mp, ofc, onc)

  # this function relies on the fact that the patches have already been updated
  # to respect previous changes inside the patch, thus shifting the position
  # forward or backward. (as done by mergeAndIntegrate)
  convertPatchesToOps: (patches) ->
    ops = []
    for patch in patches
      # offset inside the patch
      offset = 0
      for diff in patch.diffs
        switch diff[0]
          when 0 # context; this should be 4
            offset += diff[1].length

          when 1 # insert
            ops.push { p: patch.start2 + offset, i: diff[1] }
            offset += diff[1].length

          when -1 # delete
            ops.push { p: patch.start2 + offset, d: diff[1] }
            # offset inside of the patch does not change. E.g. delete pos 5-8
            # then we want to continue at pos 5

    #console.log "Calculated Ops:"
    #console.log ops
    ops

  getPatches: (oldDocText, offlineDocText, onlineDocText, callback = (ofp, onp) -> ) ->
    #if this is smaller then the algorithm is more careful.
    #For high Threshold it will override even if there's a confilct.
    dmp.Match_Threshold = 0.1

    ofp = dmp.patch_make(oldDocText, offlineDocText)
    onp = dmp.patch_make(oldDocText, onlineDocText)
    callback(ofp, onp)

  # getDocumentText generates a given document at a previous version
  # this version of the document should be common to all participating clients,
  # thus it will usually be the version *before* a client went offline.
  # It is the clients responsibility to provide this version number when coming back.  # arguments:
  #   project_id, doc_id: as always
  #   version: previously common document version
  getDocumentText: (project_id, doc_id, version, callback = (oldDocText, onlineDocText, onlineVersion) -> ) ->
    @getPreviousOps project_id, doc_id, version, (onlineDocLines, previousOps, onlineVersion) =>
      oldDocText = onlineDocLines.join('\n')
      onlineDocText = onlineDocLines.join('\n')

      # go through the array from back to front and reverse ops
      if previousOps.length != 0
        for i in [(previousOps.length-1)..0]
          for op in previousOps[i].op
            oldDocText = @reverseOp(oldDocText, op)

      callback(oldDocText, onlineDocText, onlineVersion)

  # getPreviousOps returns the list of operations from 'version' to current,
  #   as well as the current document
  # arguments:
  #   project_id, doc_id: as always
  #   version:        previously common document version
  # output:
  #   onlineDocLines: lines of the current online document
  #   previousOps:    Operations that transformed the document from version
  #                   'version' to the current version
  #   onlineVersion:  the current document version (TODO: delete if unneeded)
  getPreviousOps: (project_id, doc_id, version, callback = (onlineDocLines, previousOps, onlineVersion) -> ) ->
    DocumentUpdaterHandler.getDocument project_id, doc_id, version, (err, temp, version1, previousOps)->
      DocumentUpdaterHandler.getDocument project_id, doc_id, -1, (err, onlineDocLines, onlineVersion, opsNew)->
        #console.log "This should be the new version:"
        #console.log version
        #console.log "ops of old versions"
        #console.log previousOps
        #for diff in previousOps
        #  console.log diff.op
        callback(onlineDocLines, previousOps, onlineVersion)

  reverseOp: (docText, op) ->
    changedDoc = docText
    if(op.i?)
      changedDoc = strDel docText, op.p, op.i.length
    else if(op.d?)
      changedDoc = strInject docText, op.p, op.d
    changedDoc

