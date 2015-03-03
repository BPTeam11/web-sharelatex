ProjectEntityHandler = require('../Project/ProjectEntityHandler')
DocumentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
diff_match_patch = require("../../../lib/diff_match_patch").diff_match_patch
dmp = new diff_match_patch()

module.exports = MergeHandler =
	
	computeChange: (project_id, user_id, sessionId, doc, callback = (project_id, doc_id, change) ->)->

		console.log "MergeHandler here :)  Old version"
		console.log doc.version

		DocumentUpdaterHandler.getDocument project_id, doc.doc_id, doc.version, (err, oldDocLines, version, ops1)=>
			DocumentUpdaterHandler.getDocument project_id, doc.doc_id, -1, (err, onlineDocLines, version, ops2)=>
				console.log "This should be new version:"
				console.log version
				@merge oldDocLines, doc.doclines, onlineDocLines, (mergingOps, err) -> 
					#check if ops are empty. We do not want to upload no changes. (may even cause confusion, terror and error)
					change = {
						doc: doc.doc_id
						op: mergingOps 
						v : doc.version
						meta : {
							source: sessionId
							user_id: user_id
						}
					}
					console.log user_id
					callback(project_id, doc.doc_id, change)

	merge: (oldDocLines, offlineDocLines, onlineDocLines, callback = (mergingOps, err) ->) ->
		oldDoc = oldDocLines.join('\n')
		offlineDoc = offlineDocLines.join('\n')
		onlineDoc = onlineDocLines.join('\n')
		dmp.Match_Threshold = 0.1  #if this is smaller then the algorithm is more careful. For high Threshold it will also merge/override on its own even if there is a confilct.
		patch = dmp.patch_make(oldDoc, offlineDoc)
		result = dmp.patch_apply(patch, onlineDoc)

		console.log "Infos to understand dmp. To be deleted."
		console.log "Old Doc"
		console.log oldDoc
		console.log "Offline Doc"
		console.log offlineDoc
		console.log "Online Doc"
		console.log onlineDoc
		console.log "patches generated from old Doc and offline Changes"
		console.log patch
		console.log "List which tells patches were applied true for applied false for not applied. If the list is longer than patch (which is also a list) then curse the dmp API. (maybe setting the Match_Treshold helps..."
		console.log result[1]
		console.log "Online Doc with changes"
		console.log result[0]

		for thingy in patch
			console.log thingy
			

		#The results[1] list is only useful if it is as long as the patch list
		@convertPatchToOps result[0], patch, result[1], onlineDoc, offlineDoc, (Ops, err) -> 
			callback(mergingOps)



	convertPatchToOps: (newDoc, patch, patchIndicator, onlineDoc, offlineDoc, callback = (Ops, err) -> ) -> 
		console.log "TODO findDifferences and generate ops"
		console.log "TODO generate OPS"





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
#  op: [ { p: 485, i: '\n' } ],
#  v: 148,
#  meta: 
#   { source: 'Gmo5h_AadrjwiNtU8ihv',  
#     user_id: '5470ec2a44da473009b5d6df' } }

