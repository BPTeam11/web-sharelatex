DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()
strInject= (s1, pos, s2) -> s1[...pos] + s2 + s1[pos..]
strDel = (s1, pos, length) -> s1[...pos] + s1[(pos+length)..]
util = require('util');
ConflictHandler = require("../OfflineChangeMerge/ConflictHandler")

conflictBegin = "(("
conflictEnd   = "))"

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
  
  DMP output contains a number of patches.
  Each patch contains:
    diffs: Array of diff
    diff[0]: 0=context, 1=insert, -1=delete
    diff[1]: the according text
    start1: start of the patch in oldDoc
    start2: start of the patch in current online/offline doc
            This needs to be fixed because in default DMP, start1==start2
  
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
  mergeWhenPossible: (project_id, user_id, sessionId, doc,
    callback = (mergedChange, clientMergeOps, newVersion, ofc, onc) ->)->

      console.log "MergeHandler here :)  Old version:"
      console.log doc.version

      @getDocumentText project_id, doc.doc_id, doc.version,
        (oldDocText, onlineDocText, onlineVersion) =>
          @getPatches oldDocText, doc.doclines.join('\n'), onlineDocText,
            (ofp, onp) =>
              @mergeAndIntegrate ofp, onp, (opsForOnline, opsForOffline, ofc, onc) =>
              
                # conflicts are still relative to oldDoc
                ###
                opsForOffline = [] # unbalanced
                opsForOnline  = [] # unbalanced
                
                for conflict in onp
                  opsForOnline.push {
                    p: conflict.start1
                    i: "((" }
                  opsForOnline.push {
                    p: conflict.start1 + conflict.length
                    i: "))"

                  # insert the result of the conflicting patch into offline doc
                  opsForOffline.push {
                    p: conflict.start1, # before the offline change
                    i: "((" + onlineDocText[conflict.start2..
                      conflict.start2 + conflict.length2 - 1] + "))"
                
                for conflict in ofc
                  opsForOffline.push {
                    p: conflict.start1
                    i: "((" }
                  opsForOffline.push {
                    p: conflict.start1 + conflict.length
                    i: "))"
                    
                  # insert the result of the conflicting patch into online doc
                  opsForOnline.push [
                    p: ?? # after the online change
                
                ###
                ConflictHandler.instantMerge oldDocText, opsForOnline, opsForOffline, ofc, onc,
                  (opsForOnline, opsForOffline) =>
              
              
              
            
                  # operations that can be used on the client side to transform 
                  # the onlineDoc into the merged version
                  clientMergeOps  = @convertPatchesToOps opsForOffline
                  # operations that can be used on the server side to transform 
                  # the offlineDoc into the merged version
                  serverMergeOps = @convertPatchesToOps opsForOnline
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
  
  ###
    offline- and online-Patch need to be sorted
    ofc and onc do not necessarily have the same length
   
    merging the patches and adding up offsets ("integrating"), then splitting
    the results into dedicated arrays. These things are best done in one loop.
  ###
  mergeAndIntegrate: (ofp, onp, callback = (opsForOnline, opsForOffline, ofc, onc) -> ) ->
    # parameter dump
    console.log "PARAMETER DUMP: mergeAndIntegrate"
    @logFull "ofp", ofp
    @logFull "onp", onp
    
    # utilizing heavy iterative style here for efficiency

    i = 0 # ofp iterator
    j = 0 # onp iterator
    
    # merged online patches
    opsForOffline = []
    
    # merged offline patches
    opsForOnline = []
    
    # offline conflicts
    #ofc = []
    
    # online conflicts
    #onc = []
    
    # current offsets from the original online/offline document, either by
    # successful merging inserts or by conflict inserts "((..))"
    # Because start1 always refers to oldDoc, these offsets can only be applied
    # to start2. Also note that start2 already reflects offsets from oldDoc
    # to the original online/offline document
    offlineOffset = 0
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
    # The scenario these are for could be called "multi-conflict", like
    ###
      offline: --- ---
      online:    --- ---
      conflict:  ^ ^ ^
    ###
    # In this case, both sides will be interpreted as one long conflict.
    currentOfflineConflict = false
    currentOnlineConflict  = false
    # these positions point to the start of the current multi-conflict
    currentOfflineConflictStart = 0
    currentOnlineConflictStart  = 0
    # the 'end' is always the end of the current patch
    
    # the invariant here is that all patches <i and <j have been successfully
    # merged.
    while (i < ofp.length || j < onp.length)
      console.log "BEGIN mergeAndIntegrate loop:"
      console.log "i", i
      console.log "j", j
      
      # checking for abbreviation
      
      # add remaining online patches
      if (i == ofp.length)
        for patch, index in onp when index >= j
          patch.start2 += offlineOffset
          opsForOffline.push @patch2ops(patch)...
        break # quit while loop
      
      # add remaining offline patches
      if (j == onp.length)
        for patch, index in ofp when index >= i
          patch.start2 += onlineOffset
          opsForOnline.push @patch2ops(patch)...
        break # quit while loop
        
      # from now on, (i < ofp.length) and (j < onp.length)
      # which means that there can be no invalid array indexing
      
      # update offline patch bounds
      originalOfflinePatchStart = ofp[i].start1
      originalOfflinePatchEnd   = ofp[i].start1 + ofp[i].length1 - 1
      currentOfflinePatchStart  = ofp[i].start2
      currentOfflinePatchEnd    = ofp[i].start2 + ofp[i].length2 - 1
      
      # update online patch bounds
      originalOnlinePatchStart = onp[j].start1
      originalOnlinePatchEnd   = onp[j].start1 + onp[j].length1 - 1
      currentOnlinePatchStart  = onp[j].start2
      currentOnlinePatchEnd    = onp[j].start2 + onp[j].length2 - 1

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
      if (originalOfflinePatchEnd < originalOnlinePatchStart)
        # no conflict with upcoming online patch, but we need to clean up the old conflict first
        if currentOfflineConflict
          ofc.push ofp[i]
          i++
          currentOfflineConflict = false
        else
          # integrate offlinePatch
          ofp[i].start2 += onlineOffset
          onlineOffset  += ofp[i].length2 - ofp[i].length1
          opsForOnline.push @patch2ops(ofp[i])...
          i++
      
      # onlinePatch first, no conflict
      else if (originalOnlinePatchEnd < originalOfflinePatchStart)
        # no conflict with upcoming offline patch, but we need to clean up the old conflict first
        if currentOnlineConflict
          onc.push onp[j]
          j++
          currentOnlineConflict = false
        else
          # integrate onlinePatch
          onp[j].start2 += offlineOffset
          offlineOffset += onp[j].length2 - onp[j].length1
          opsForOffline.push @patch2ops(onp[j])...
          j++

      # otherwise, it's a conflict
        
      # offline: ----- ???
      # online:    -----
      # --> There may be a conflict with online later
      else if (originalOfflinePatchEnd < originalOnlinePatchEnd)
      
        # insert online alternative
        # insert begin tag
        opsForOffline.push {p: currentOfflinePatchStart, i: conflictBegin}
        offlineOffset += conflictBegin.length
        
        onlineAlternative = 
          onlineDocText[currentOnlinePatchStart .. currentOnlinePatchEnd]
        opsForOffline.push {
          p: currentOfflinePatchStart + conflictBegin.length,
          i: onlineAlternative }
        offlineOffset += onlineAlternative.length
        
        # insert end tag
        opsForOffline.push {p: currentOfflinePatchEnd + 1, i: conflictEnd}
        offlineOffset += conflictEnd.length
        
        # insert braces around offline conflict
        
        ofp[i].start2 += onlineOffset
        ofc.push ofp[i]
        i++
        currentOfflineConflict = false
        currentOnlineConflict = true
    
      # offline:   -----
      # online:  ----- ???
      # --> There may be a conflict with offline later
      else if (originalOnlinePatchEnd < originalOfflinePatchEnd)
        onp[j].start1 += offlineOffset
        #onp[j].start2 += offlineOffset
        onc.push onp[j]
        j++
        currentOnlineConflict = false
        currentOfflineConflict = true
      
      # offline: -------- ???
      # online:     ----- ???
      # --> They have equal ends, no overlap with later patches possible
      else
        ofp[i].start1 += onlineOffset
        #ofp[i].start2 += onlineOffset
        ofc.push ofp[i]
        i++
        currentOfflineConflict = false
        onp[j].start1 += offlineOffset
        #onp[j].start2 += offlineOffset
        onc.push onp[j]
        j++
        currentOnlineConflict = false
  
    console.log "OUTPUT DUMP: mergeAndIntegrate"
    @logFull "opsForOnline", opsForOnline
    @logFull "opsForOffline", opsForOffline
    @logFull "ofc",  ofc
    @logFull "onc",  onc
    callback(opsForOnline, opsForOffline, ofc, onc)

  patch2ops: (patch) ->
    ops = []
    # offset inside the patch
    offset = 0
    for diff in patch.diffs
      switch diff[0]
        when 0 # context
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
    ofp = @patchMake(oldDocText, offlineDocText)
    onp = @patchMake(oldDocText, onlineDocText)
    callback(ofp, onp)

  # this is a wrapper for dmp.patch_make that ...
  #   1. sets a correct start2 value
  #   2. strips the beginning and end context away because we don't need it
  patchMake: (oldText, newText) ->
    # If this is smaller then the algorithm is more careful.
    # For high Threshold it will override even if there's a confilct.
    dmp.Match_Threshold = 0.1
    patches = dmp.patch_make(oldText, newText)
    @logFull "DMP patches", patches
    offset = 0
    for patch in patches
      
      # save context lengths
      startContext = patch.diffs[0][1].length
      endContext   = patch.diffs[patch.diffs.length - 1][1].length
      
      # strip start context
      patch.diffs.splice(0, 1)
      # update start values
      patch.start1 += startContext
      patch.start2 += startContext
      
      # strip end context
      patch.diffs.splice(patch.diffs.length - 1, 1)
      
      # update length values
      patch.length1 -= startContext + endContext
      patch.length2 -= startContext + endContext
      
      # make start2 respect previous patches
      patch.start2 += offset
      offset += patch.length2 - patch.length1
    
    @logFull "calculated patches", patches
    return patches

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

