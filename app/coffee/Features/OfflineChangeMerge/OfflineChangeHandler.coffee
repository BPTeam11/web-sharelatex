DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()
strInject= (s1, pos, s2) -> s1[...pos] + s2 + s1[pos..]
strDel = (s1, pos, length) -> s1[...pos] + s1[(pos+length)..]
util = require('util');

onlineConflictBegin  = "\n\n%%%%% BEGIN MERGE\n%%% original:\n"
onlineConflictEnd    = "\n"
offlineConflictBegin = "%%% local:\n"
offlineConflictEnd   = "\n%%%%% END MERGE\n\n"

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
    callback = (mergedChange, clientMergeOps, newVersion) ->)->

      console.log "MergeHandler here :)  Old version:"
      console.log doc.version
      
      offlineDocText = doc.doclines.join('\n')
      @getDocumentText project_id, doc.doc_id, doc.version,
        (oldDocText, onlineDocText, onlineVersion) =>
          @getPatches oldDocText, offlineDocText, onlineDocText,
            (ofp, onp) =>
              @mergeAndIntegrate offlineDocText, onlineDocText, ofp, onp,
                (opsForOnline, opsForOffline) =>

                  # ignore conflicts for now
                  # this may be splitted up into single ops:
                  mergedChange = {
                    doc: doc.doc_id
                    op: opsForOnline
                    v : onlineVersion
                    meta : {
                      source: sessionId
                      user_id: user_id
                    }
                  }
                  console.log "onlineVersion", onlineVersion
                  console.log "opsForOnline.length", opsForOnline.length
                  
                  @logFull "mergedChange", mergedChange
                  callback mergedChange, opsForOffline,
                    onlineVersion + 1
    
  ###
    offline- and online-Patch need to be sorted
    ofc and onc do not necessarily have the same length
   
    merging the patches and adding up offsets ("integrating"), then splitting
    the results into dedicated arrays. These things are best done in one loop.
  ###
  mergeAndIntegrate: (offlineDocText, onlineDocText, ofp, onp,
    callback = (opsForOnline, opsForOffline) -> ) ->

      console.log "PARAMETER DUMP: mergeAndIntegrate"
      console.log "offlineDocText", offlineDocText
      console.log "onlineDocText", onlineDocText
      @logFull "ofp", ofp
      @logFull "onp", onp
      
      # utilizing heavy iterative style here for efficiency

      i = 0 # ofp iterator
      j = 0 # onp iterator
      
      # merged online patches
      opsForOffline = []
      
      # merged offline patches
      opsForOnline = []
      
      # current offsets from the old doc. These will be added to start2 when
      # finally applying a patch
      offset = 0
      
      # if both ofp and onp are empty, there are no merges and no conflicts
      if (ofp.length == onp.length == 0)
        console.log "mergeAndIntegrate: Got two empty patches"
        return callback([], [])

      # from now on, ofp and onp are non-empty

      # the 'end' is always the end of the current patch
      
      # the invariant here is that all patches <i and <j have been successfully
      # merged.
      while (i < ofp.length || j < onp.length)
        #console.log "BEGIN mergeAndIntegrate loop:"
        #console.log "i", i
        #console.log "j", j
        
        # checking for abbreviation
        
        # add remaining online patches
        if (i == ofp.length)
          for patch, index in onp when index >= j
            patch.start2 += offset
            offset += patch.offset
            opsForOffline.push @patch2ops(patch)...
          break # quit while loop
        
        # add remaining offline patches
        if (j == onp.length)
          for patch, index in ofp when index >= i
            patch.start2 += offset
            offset += patch.offset
            opsForOnline.push @patch2ops(patch)...
          break # quit while loop
          
        # from now on, (i < ofp.length) and (j < onp.length)
        # which means that there can be no invalid array indexing

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
        if (ofp[i].end1 < onp[j].start1)
            # integrate offlinePatch
            ofp[i].start2 += offset
            offset += ofp[i].offset
            opsForOnline.push @patch2ops(ofp[i])...
            i++
        
        # onlinePatch first, no conflict
        else if (onp[j].end1 < ofp[i].start1)
            # integrate onlinePatch
            onp[j].start2 += offset
            offset += onp[j].offset
            opsForOffline.push @patch2ops(onp[j])...
            j++

        # otherwise, it's a conflict
        # Imagine a conflict is a conflict is a conflict ... then this code works.
        # There are no overlapping conflicts handled here. Go look somewhere else.
        
        else
          
          ###
            To resolve a conflict, we'll do the following:
            1. fetch the conflicting text area from both sides
            2. delete the conflicting text area on both sides
            3. generate a merge form consisting of both versions
            4. insert the merge form in place of the previous conflict
          ###
          
          # calculate conflict area
          
          # patch bounds that respect "words"
          offlinePatchStart = ofp[i].start1 + ofp[i].startWordDiff
          offlinePatchEnd   = ofp[i].end1   - ofp[i].endWordDiff
          onlinePatchStart  = onp[j].start1 + onp[j].startWordDiff
          onlinePatchEnd    = onp[j].end1   - onp[j].endWordDiff
          
          # use the area that includes both patches
          minPatchStart = @min(offlinePatchStart, onlinePatchStart)
          maxPatchEnd   = @max(offlinePatchEnd, onlinePatchEnd)
          
          # map to current text
          offlineAreaStart = minPatchStart - ofp[i].start1 + ofp[i].start2
          offlineAreaEnd   = maxPatchEnd   - ofp[i].end1   + ofp[i].end2
          onlineAreaStart  = minPatchStart - onp[j].start1 + onp[j].start2
          onlineAreaEnd    = maxPatchEnd   - onp[j].end1   + onp[j].end2
          
          console.log "offlineAreaStart", offlineAreaStart
          console.log "offlineAreaEnd", offlineAreaEnd
          console.log "onlineAreaStart", onlineAreaStart
          console.log "onlineAreaEnd", onlineAreaEnd
          
          # fetch the conflicting text area from both sides
          offlineText = offlineDocText[offlineAreaStart .. offlineAreaEnd]
          onlineText  = onlineDocText[onlineAreaStart .. onlineAreaEnd]
          console.log "offlineText", offlineText
          console.log "onlineText", onlineText
          
          conflictPos = minPatchStart + offset
          
          # delete the conflicting text area on both sides
          opsForOffline.push {
            p: conflictPos
            d: offlineText
            }
          opsForOnline.push {
            p: conflictPos
            d: onlineText
            }
          
          # generate a merge form consisting of both versions
          mergeText = onlineConflictBegin + onlineText + onlineConflictEnd +
            offlineConflictBegin + offlineText + offlineConflictEnd
          
          mergeInsert = { p: conflictPos, i: mergeText }
          
          opsForOffline.push mergeInsert
          opsForOnline.push mergeInsert
          
          offset += mergeText.length
          
          i++
          j++
          

      console.log "OUTPUT DUMP: mergeAndIntegrate"
      @logFull "opsForOffline", opsForOffline
      @logFull "opsForOnline", opsForOnline
      callback(opsForOnline, opsForOffline)

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

  # this is a wrapper for dmp.patch_make that will set correct start1 values
  # as well as context markers that specify the length of the context around
  # a patch, as well as end tags
  patchMake: (oldText, newText) ->
    # If this is smaller then the algorithm is more careful.
    # For high Threshold it will override even if there's a confilct.
    dmp.Match_Threshold = 0.1
    patches = dmp.patch_make(oldText, newText)
    # extended patches
    extPatches = []
    @logFull "DMP patches", patches
    offset = 0
    for patch in patches

      # extract context length, AND
      
      # extract nearest words offset from context
      # these are relative to start and end positions, e.g.:
      # given the context "aa bc" starting at pos 0,
      # startWordDiff = 3
      # given the context "ee fg" ending at pos 10,
      # endWordDiff = 3
      startWordDiff = 0
      endWordDiff   = 0
      
      # start context
      firstPatchEntry = patch.diffs[0]
      if (firstPatchEntry[0] == 0)
        contextString = firstPatchEntry[1]
        context1 = contextString.length
        for char, pos in contextString[0 .. context1 - 1]
          if char == '\n' or char == ' '
            startWordDiff = pos + 1
      else
        context1 = 0
      
      # end context
      lastPatchEntry = patch.diffs[patch.diffs.length - 1]
      if (lastPatchEntry[0] == 0)
        contextString = lastPatchEntry[1]
        context2 = contextString.length
        for char, pos in contextString[0 .. context2 - 1]
          if char == '\n' or char == ' '
            endWordDiff = context2 - pos + 1
            break
      else
        context2 = 0
      
      extPatch = {
        diffs:  patch.diffs
        start1: patch.start1 - offset
        start2: patch.start2
        length1: patch.length1
        length2: patch.length2
        end1: patch.start1 - offset + patch.length1 - 1
        end2: patch.start2 + patch.length2 - 1
        offset: patch.length2 - patch.length1
        context1: context1
        context2: context2
        startWordDiff: startWordDiff
        endWordDiff: endWordDiff
        }
      #extPatch.end2 -= 1 unless (extPatch.length2 == 0)
      offset += extPatch.offset
      extPatches.push extPatch
    
    @logFull "calculated patches", extPatches
    return extPatches

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
  
  min: (a, b) ->
    if (a < b)
      return a
    else
      return b
  
  max: (a, b) ->
    if (a > b)
      return a
    else
      return b
  
  logFull: (description, myObject) ->
    console.log description, "=", util.inspect(myObject, {showHidden: false, depth: null})

