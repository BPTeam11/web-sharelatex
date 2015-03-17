DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()
strInject= (s1, pos, s2) -> s1[...pos] + s2 + s1[pos..]
strDel = (s1, pos, length) -> s1[...pos] + s1[(pos+length)..]
util = require('util');

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

  # TODO: what if that was not successful?
  computeChange: (project_id, user_id, sessionId, doc, callback = (project_id, doc_id, change, clientMergeOps, newVersion) ->)->

    console.log "MergeHandler here :)  Old version:"
    console.log doc.version

    @getDocumentText project_id, doc.doc_id, doc.version, (oldDocText, onlineDocText, onlineVersion) =>
      @getPatches oldDocText, doc.doclines.join('\n'), onlineDocText, (ofp, onp) =>
        @mergeAndIntegrate ofp, onp, (mofp, monp, ofc, onc) =>
          # operations that can be used on the client side to transform the 
          # onlineDoc into the merged version
          clientMergeOps  = @convertPatchesToOps monp
          # operations that can be used on the server side to transform the
          # offlineDoc into the merged version
          serverMergeOps = @convertPatchesToOps mofp
          # ignore conflicts for now
          # this may be splitted up into single ops:
          change = {
            doc: doc.doc_id
            op: serverMergeOps
            v : onlineVersion
            meta : {
              source: sessionId
              user_id: user_id
            }
          }
          
          callback project_id, doc.doc_id, change, clientMergeOps, onlineVersion + serverMergeOps.length
  
  ###
    offline- and online-Patch need to be sorted
    ofc and onc do not necessarily have the same length
   
    merging the patches and adding up offsets ("integrating"), then splitting
    the results into dedicated arrays. These things are best done in one loop.
  ###
  mergeAndIntegrate: (ofp, onp, callback = (mofp, monp, ofc, onc) -> ) ->
    # parameter dump
    console.log "PARAMETER DUMP: mergeAndIntegrate"
    @logFull "ofp", ofp
    @logFull "onp", onp
    
    # utilizing heavy iterative style here for efficiency
    # Assuming that the DMP context length is always 4 characters!
    cl = 4
    i = 0 # ofp iterator
    j = 0 # onp iterator
    
    # merged online patches
    monp = []
    # merged offline patches
    mofp = []
    # offline conflicts
    ofc = []
    # online conflicts
    onc = []
    #patchOffset = 0
    # offset caused by applying offline patches at the server side
    offlineOffset = 0
    # offset caused by applying online patches at the offline-client side
    onlineOffset  = 0
    
    # if both ofp and onp are empty, there are no merges and no conflicts
    if (ofp.length == onp.length == 0)
      console.log "mergeAndIntegrate: Got two empty patches"
      return callback([], [], [], [])
    
    # if ofp is empty (but not onp), merges are simply the onp, no conflicts
    else if (ofp.length == 0)
      console.log "mergeAndIntegrate: offlinePatches is empty"
      return callback([], onp, [], [])
    
    # if onp is empty (but not ofp), merges are simply the ofp, no conflicts
    else if (onp.length == 0)
      console.log "mergeAndIntegrate: onlinePatches is empty"
      return callback(ofp, [], [], [])
    
    # from now on, ofp and onp are non-empty
    
    # these values say whether
    # 1.) the current off/online index did not change since last iteration
    # 2.) the according patch conflicted with a previous patch, which means
    #     that we want to add it to the ofc/onc array at a later point.
    currentOfflineConflict = false
    currentOnlineConflict  = false

    while (i < ofp.length || j < onp.length)
      console.log "BEGIN mergeAndIntegrate loop:"
      @logFull "i", i
      @logFull "j", j
    
      # TODO: use the main logger for this
      if currentOfflineConflict && currentOnlineConflict
        console.log "ERROR: offline and online conflict! This should not happen!"
      
      # update offline patch bounds
      # if currentOfflineConflict, i did not change
      if (i < ofp.length && !currentOfflineConflict)
        currentOfflinePatchStart = ofp[i].start1 + cl
        console.log "currentOfflinePatchStart", currentOfflinePatchStart
        currentOfflinePatchEnd   = currentOfflinePatchStart + ofp[i].length1 - 1 - cl
        console.log "currentOfflinePatchEnd", currentOfflinePatchEnd
      
      # update online patch bounds
      # if currentOnlineConflict, j did not change
      if (j < onp.length && !currentOnlineConflict)
        currentOnlinePatchStart  = onp[j].start1 + cl
        console.log "currentOnlinePatchStart", currentOnlinePatchStart
        currentOnlinePatchEnd    = currentOnlinePatchStart + onp[j].length1 - 1 - cl
        console.log "currentOnlinePatchEnd", currentOnlinePatchEnd

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
      # if we already merged all offline patches, this is not relevant
      if (currentOfflinePatchEnd < currentOnlinePatchStart) && (i < ofp.length)
        # no conflict with upcoming online patch, but we need to clean up the old conflict first
        if currentOfflineConflict
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
        else
          # integrate offlinePatch
          ofp[i].start1 += onlineOffset
          ofp[i].start2 += onlineOffset
          offlineOffset += ofp[i].length2 - ofp[i].length1
          mofp.push ofp[i]
          i++
      
      # onlinePatch first, no conflict
      # if we already merged all online patches, this is not relevant
      else if (currentOnlinePatchEnd < currentOfflinePatchStart) && (j < onp.length)
        # no conflict with upcoming offline patch, but we need to clean up the old conflict first
        if currentOnlineConflict
          onc.push onp[j]
          j++
          currentOnlineConflict = false
        else
          # integrate onlinePatch
          onp[j].start1 += offlineOffset
          onp[j].start2 += offlineOffset
          onlineOffset += onp[j].length2 - onp[j].length1
          monp.push onp[j]
          j++

      # otherwise, it's a conflict
      else
        console.log "There is a conflict"
        # NOTE: You'll need to take care of offsets when merging later
        
        # offline: ----- ???
        # online:    -----
        # --> There may be a conflict with offline later
        if (currentOfflinePatchEnd < currentOnlinePatchEnd) && (i < ofp.length)
          ofp[i].start1 += onlineOffset
          ofp[i].start2 += onlineOffset
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
          currentOnlineConflict = true
        
        # offline:   -----
        # online:  ----- ???
        # --> There may be a conflict with online later
        else if (currentOnlinePatchEnd < currentOfflinePatchEnd) && (j < onp.length)
          onp[j].start1 += offlineOffset
          onp[j].start2 += offlineOffset
          onc.push onp[j]
          j++
          currentOnlineConflict = false
          currentOfflineConflict = true
        
        # offline: -------- ???
        # online:     ----- ???
        # --> They have equal ends, no overlap with later patches possible
        else
          ofp[i].start1 += onlineOffset
          ofp[i].start2 += onlineOffset
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
          onp[j].start1 += offlineOffset
          onp[j].start2 += offlineOffset
          onc.push onp[j]
          j++
          currentOnlineConflict = false
        ###
        else
          # TODO: Use logger
          console.log "Err ... Something somewhere went terribly wrong in mergeAndIntegrate. Contact a developer."
          console.log "onp.length", onp.length
          console.log "i", i
          console.log "ofp.length", ofp.length
          console.log "j", j
        ###
    
    console.log "OUTPUT DUMP: mergeAndIntegrate"
    @logFull "mofp", mofp
    @logFull "monp", monp
    @logFull "ofc",  ofc
    @logFull "onc",  onc
    callback(mofp, monp, ofc, onc)

  # TODO fix the offset
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
  
  logFull: (description, myObject) ->
    console.log description, "=", util.inspect(myObject, {showHidden: false, depth: null})

