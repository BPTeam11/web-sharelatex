module.exports = ConflictHandler =

  ###
    "this is like instant coffee, but worse. And much more complicated."
    We are going to convert conflicts into inserts of the following form:
    ((onlineVersion))((offlineVersion))
    For the offline client and the server this means different transformations,
    because their current state is different. Specifically, the server has
    monp and onc already applied, the client has mofp and ofc already applied.
  ###
  instantMerge: (oldDocText, mofp, monp, ofc, onc, callback = (mofp, monp)->)->
    ###
      What already happened:
      1. We merged conflict-free offline changes into the online doc (mofp)
          We did not calculate any extra offsets for these inserts!
      2. We merged conflict-free online changes into the offline doc (monp)
          We did not calculate any extra offsets for these inserts!
      
      There are two steps:
      1. We need to merge offline conflicts into the online doc
        For this, we need to respect
          - all original online offsets
      2. We need to merge online conflicts into the offline doc
    ###
  
  
  
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
  
