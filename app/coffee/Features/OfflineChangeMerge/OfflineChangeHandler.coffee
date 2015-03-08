DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()
strInject= (s1, pos, s2) -> s1[...pos] + s2 + s1[pos..]
strDel = (s1, pos, length) -> s1[...pos] + s1[(pos+length)..]

module.exports = OfflineChangeHandler =
  
  # let the "old document" be the document before a client went offline
  # doc: offline Document after the client made changes to it

  # computeChange generates a list of changes that will try to apply
  #   changes which were made to the old document offline
  #   to the current document retroactively.
  # TODO: what if that was not successful?
  computeChange: (project_id, user_id, sessionId, doc, callback = (project_id, doc_id, change) ->)->

    console.log "MergeHandler here :)  Old version:"
    console.log doc.version

    @getDocumentText project_id, doc.doc_id, doc.version, (oldDocText, onlineDocText, onlineVersion) =>
      @merge oldDocText, doc.doclines.join('\n'), onlineDocText, (mergingOps, conflicts) ->
        # TODO add exception handling for the case that mergingOps == []
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

  # getDocumentText generates a given document at a previous version
  # this version of the document should be common to all participating clients,
  # thus it will usually be the version *before* a client went offline.
  # It is the clients responsibility to provide this version number when coming back.
  # arguments:
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

  # merge tries to "merge" the offline "branch" of a document into the current
  # document.
  # arguments:
  #   oldDocText:     document at a previous version
  #   offlineDocText: document with offline changes based on oldDocText
  #   onlineDocText:  document at the current version
  # output:
  #   mergingOps:     Operations that will try to apply offline changes to
  #                   onlineDocText
  merge: (oldDocText, offlineDocText, onlineDocText, callback = (mergingOps, conflicts) ->) ->
    #console.log "MERGE HERE! ----------------"
    #console.log onlineDocText
    #if this is smaller then the algorithm is more careful.
    #For high Threshold it will override even if there's a confilct.
    dmp.Match_Threshold = 0.1

    patch = dmp.patch_make(oldDocText, offlineDocText)
    # patch: start1 and start2 are the respective positions of changes in the two texts
    result = dmp.patch_apply(patch, onlineDocText)

    #To get the changes from the onlineDocText to the merged Text
    #patchedDocument = result[0]
    #result2 = dmp.patch_make(patchedDocument, onlineDocText)
    
    ###
    console.log "merge patch:"
    for change in patch
      console.log change
    console.log "\nresult[0]:"
    console.log result[0]
    console.log "\nresult[1]:"
    console.log result[1]
    console.log "END merge patch"
    ###
    
    # extract conflicts
    # WARNING: patch and result[1] may not always have the same length.
    # That is a bug in DMP. If that happens, ... well ... *look at the watch*
    conflicts = (patch[index] for entry, index in result[1] when entry is false)
    
    ###
    console.log "Conflicts:"
    for conflict in conflicts
      console.log conflict
    console.log "End Conflicts"
    ###
    
    #console.log "calling patch2ops"
    mergeOps = @convertPatchToOps patch
    #console.log mergeOps
    
    callback(mergeOps, conflicts)

  # patch is generated by Diff-Match-Patch (dmp)
  # this function returns a list of operations that reflect the patch
  convertPatchToOps: (patch) -> 
    #console.log "[patch2ops] Got patch:"
    #for thingy in patch
    #  console.log thingy
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

    #console.log "Calculated Ops:"
    #console.log ops
    ops


  reverseOp: (docText, op) ->
    changedDoc = docText
    if(op.i?)
      changedDoc = strDel docText, op.p, op.i.length
    else if(op.d?)
      changedDoc = strInject docText, op.p, op.d
    changedDoc

# Felix' version, this should have been moved to its own branch!!!
###
#  convertPatchToOps: (newDoc, patch, patchIndicator, onlineDoc, offlineDoc, callback = (Ops) -> ) ->
#    console.log "Converting patch to operations"
#    mergingOps = []
#    offsetOperations = 0
#    for change in patch
#      offsetContexts = 0
#      for diff in change.diffs
#        console.log diff
#        console.log offsetContexts
#        switch diff[0]
#          when 0
#            offsetContexts += diff[1].length
#            console.log diff[1].length
#            console.log offsetContexts
#          when 1 # insert
#            mergingOps.push { p: change.start2 + offsetContexts + offsetOperations, i: diff[1] }
#            offsetOperations += diff[1].length
#          when -1 # delete
#            mergingOps.push { p: change.start2 + offsetContexts + offsetOperations, d: diff[1] }
#            offsetOperations -= diff[1].length
#
#    console.log mergingOps
#    callback(mergingOps)


# Random notes, these belong to each authors local branch and must not be commited!!
###
#[ { doc: '54f6289e51df280c2caf92c8',
#    op: [ [Object] ],
#    v: 83,
#    meta:
#     { source: 'H8cKp20smpG7DBERDwo9',
#       user_id: '5469bc419b63cd9c090867e3',
#       ts: 1425460410532 } },
#  { doc: '54f6289e51df280c2caf92c8',
#    op: [ [Object] ],
#    v: 84,
#    meta:
#     { source: 'H8cKp20smpG7DBERDwo9',
#       user_id: '5469bc419b63cd9c090867e3',
#       ts: 1425460410652 } },

# doc has only the following attributes:
# doc.doclines
# doc.version
# doc.doc_id
#example:

#{ doclines:
#   [ '\\documentclass{article}',
#     '\\usepackage[utf8]{inputenc}',
#     '',
#     '\\title{a40}',
#     '\\author{a }',
#    '\\date{February 2015}',
#    '',
#     '\\usepackage{natbib}',
#     '\\usepackage{graphicx}',
#     '',
#     '\\begin{document}',
#     '',
#     '\\maketitle',
#     '',
#     '\\section{Introduction}',
#     '',
#     '',
#     'This should be saved as snapshot',
#     '',
#     '\\begin{figure}[h!]',
#     '\\centering',
#     '\\includegraphics[scale=1.7]{universe.jpg}',
#     '\\caption{The Universe}',
#     '\\label{fig:univerise}',
#     '\\end{figure}',
#     '',
#     '\\section{Conclusion}',
#     '``I always thought something was fundamentally wrong with the universe\'\' \\citep{adams1995hitchhiker}',
#     '',
#     '\\bibliographystyle{plain}',
#     '\\bibliography{references}',
#     '\\end{document}',
#     '' ],
#  version: 324,
#  doc_id: '54ef3c8d0d19f3820f152a94' }


#This is how change must look:
#{ doc: '54ef10d2218548d723fd9a08',
#  op: [ { p: 485, i: '\n' }, {....}, {...} ],
#  v: 148,
#  meta:
#   { source: 'Gmo5h_AadrjwiNtU8ihv',
#     user_id: '5470ec2a44da473009b5d6df' } }
