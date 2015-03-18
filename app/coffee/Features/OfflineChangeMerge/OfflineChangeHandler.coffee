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

  # mergedChange: A 'change' object that contains all offline changes that don't
  #               produce a conflict. The server can immediately apply these.
  #
  # newVersion: Because the offline client has already applied his own changes,
  #             this variable is here to tell the client up to which doc version
  #             he should ignore incoming updates.
  #
  # clientMergeOps: Operations that are supplied to the previously offline
  #                 client to reflect online changes
  #
  # ofc: DMP-patches from offline changes that conflict with online changes.
  #      Updated positions to correspond to newVersion
  #
  # onc: DMP-patches from online changes that conflict with offline changes.
  #      Updated positions to correspond to newVersion
  #
  mergeWhenPossible: (project_id, user_id, sessionId, doc, callback =
    (mergedChange, clientMergeOps, newVersion, ofc, onc) ->)->

      console.log "MergeHandler here :)  Old version:"
      console.log doc.version

      @getDocumentText project_id, doc.doc_id, doc.version,
        (oldDocText, onlineDocText, onlineVersion) =>
          @getPatches oldDocText, doc.doclines.join('\n'), onlineDocText,
            (ofp, onp) =>
              @mergeAndIntegrate ofp, onp, (mofp, monp, ofc, onc) =>
                # operations that can be used on the client side to transform 
                # the onlineDoc into the merged version
                clientMergeOps  = @convertPatchesToOps monp
                # operations that can be used on the server side to transform 
                # the offlineDoc into the merged version
                serverMergeOps = @convertPatchesToOps mofp
                # ignore conflicts for now
                # this may be splitted up into single ops:
                mergedChange = {
                  doc: doc.doc_id
                  op: serverMergeOps
                  v : onlineVersion
                  meta : {
                    source: sessionId
                    user_id: user_id
                  }
                }
                
                callback mergedChange, clientMergeOps,
                  onlineVersion + serverMergeOps.length,
                  ofc, onc
  
  # 
  
  # this function should maybe moved to a different place ...?
  # good location may be a "ConflictHandler" module.
  #
  # This function inserts braces ((...)) around conflicting changes.
  # It is a proof-of-concept instead of real conflict resolution
  insertConflictBraces: (conflictPatches) ->
    for patch in conflictPatches

      # push "((" as the first insert before the first original change
      patch.diffs.splice(1, 0, [ 1, "((" ])
      
      # push "))" as the last insert after the last original change
      l = patch.diffs.length
      patch.diffs.splice(l-1, 0, [ 1, "))" ])
      
      patch.length2 += 4
    
    return conflictPatches
  
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
    
    # these values say, when true, that:
    # 1.) the current off/online index did not change since last iteration
    # 2.) the according patch conflicted with a previous patch, which means
    #     that we want to add it to the ofc/onc array at a later point.
    currentOfflineConflict = false
    currentOnlineConflict  = false

    while (i < ofp.length || j < onp.length)
      console.log "BEGIN mergeAndIntegrate loop:"
      console.log "i", i
      console.log "j", j
      
      # checking for abbreviation
      
      # add remaining online patches
      if (i == ofp.length)
        for patch, index in onp when index >= j
          patch.start1 += offlineOffset
          patch.start2 += offlineOffset
          monp.push patch
        break # quit while loop
      
      # add remaining offline patches
      if (j == onp.length)
        for patch, index in ofp when index >= i
          patch.start1 += onlineOffset
          patch.start2 += onlineOffset
          mofp.push patch
        break # quit while loop
        
      # from now on this is true: (i < ofp.length && j < onp.length)
      # which means that there can be no invalid array indexing
    
      # TODO: use the main logger for this
      if currentOfflineConflict && currentOnlineConflict
        console.log "ERROR: offline and online conflict! This should not happen!"
      
      # TODO: maybe add +-1 environment bounds for contextual conflict detection
      
      # update offline patch bounds
      # if currentOfflineConflict, i did not change
      if !currentOfflineConflict
        currentOfflinePatchStart = ofp[i].start1 + ofp[i].diffs[0][1].length
        console.log "currentOfflinePatchStart", currentOfflinePatchStart
        currentOfflinePatchEnd =
          ofp[i].start1 +
          ofp[i].length1 -
          ofp[i].diffs[ofp[i].diffs.length - 1][1].length
        console.log "currentOfflinePatchEnd", currentOfflinePatchEnd
      
      # update online patch bounds
      # if currentOnlineConflict, j did not change
      if !currentOnlineConflict
        currentOnlinePatchStart  = onp[j].start1 + onp[j].diffs[0][1].length
        console.log "currentOnlinePatchStart", currentOnlinePatchStart
        currentOnlinePatchEnd =
          onp[j].start1 +
          onp[j].length1 -
          onp[j].diffs[onp[j].diffs.length - 1][1].length
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
      if (currentOfflinePatchEnd < currentOnlinePatchStart)
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
      else if (currentOnlinePatchEnd < currentOfflinePatchStart)
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
      # NOTE: You'll need to take care of offsets when merging later
        
      # offline: ----- ???
      # online:    -----
      # --> There may be a conflict with offline later
      else if (currentOfflinePatchEnd < currentOnlinePatchEnd)
        ofp[i].start1 += onlineOffset
        ofp[i].start2 += onlineOffset
        ofc.push ofp[i]
        i++
        currentOfflineConflict = false
        currentOnlineConflict = true
    
      # offline:   -----
      # online:  ----- ???
      # --> There may be a conflict with online later
      else if (currentOnlinePatchEnd < currentOfflinePatchEnd)
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
  
    console.log "OUTPUT DUMP: mergeAndIntegrate"
    @logFull "mofp", mofp
    @logFull "monp", monp
    @logFull "ofc",  ofc
    @logFull "onc",  onc
    callback(mofp, monp, ofc, onc)

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

