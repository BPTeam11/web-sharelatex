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
				#check if ops are empty. We do not want to upload no changes. (may even cause confusion, terror and error)
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


	getDocumentText: (project_id, doc_id, version, callback = (oldDocText, onlineDocText, onlinVersion) -> ) ->
		@fetchDocuments project_id, doc_id, version, (onlineDocLines, opsOld, onlineVersion) => 
			oldDocText = onlineDocLines.join('\n')
			onlineDocText = onlineDocLines.join('\n')

			# go through the array from back to front and reverse ops
			for i in [(opsOld.length-1)..0] 
				for op in opsOld[i].op
					oldDocText = @reverseOp(oldDocText, op)

			callback(oldDocText,onlineDocText, onlineVersion)


	fetchDocuments: (project_id, doc_id, version, callback = (onlineDocLines, opsOld, onlineVersion) -> ) ->
		DocumentUpdaterHandler.getDocument project_id, doc_id, version, (err, temp, version1, opsOld)->
			DocumentUpdaterHandler.getDocument project_id, doc_id, -1, (err, onlineDocLines, onlineVersion, opsNew)->
				console.log "This should be new version:"
				console.log version
				console.log "ops of old versionen"
				console.log ops1
				for diff in ops1
					console.log diff.op
				console.log "ops of new versionen"
				console.log ops2
				callback(onlineDocLines, opsOld, onlineVersion)

	merge: (oldDocText, offlineDocText, onlineDocText, callback = (mergingOps) ->) ->
		dmp.Match_Threshold = 0.1  #if this is smaller then the algorithm is more careful. For high Threshold it will also merge/override on its own even if there is a confilct.
		patch = dmp.patch_make(oldDocText, offlineDocText)
		result = dmp.patch_apply(patch, onlineDocText)

		#To get the changes from the onlineDocText to the merged Text
		#patchedDocument = result[0]
		#result2 = dmp.patch_make(patchedDocument, onlineDocText)

		console.log "Infos to understand dmp. To be deleted."
		console.log "Old Doc"
		console.log oldDocText
		console.log "Offline Doc"
		console.log offlineDocText
		console.log "Online Doc"
		console.log onlineDocText
		console.log "patches generated from old Doc and offline Changes"
		console.log patch
		console.log "List which tells patches were applied true for applied false for not applied. If the list is longer than patch (which is also a list) then curse the dmp API. (maybe setting the Match_Treshold helps..."
		console.log result[1]
		console.log "Online Doc with changes"
		console.log result[0]

		for thingy in patch
			console.log thingy
			

		#The results[1] list is only useful if it is as long as the patch list
		@convertPatchToOps result[0], patch, result[1], onlineDocText, offlineDocText, (mergingOps) -> 
			callback(mergingOps)



	convertPatchToOps: (newDoc, patch, patchIndicator, onlineDoc, offlineDoc, callback = (meineOps) -> ) -> 
		console.log "TODO findDifferences and generate ops"
		console.log "TODO generate OPS"
		callback(meineOps)



	reverseOp: (docText, op) ->
		changedDoc = docText 
		if(op.i?)
			changedDoc = strDel docText, op.p, op.i.length
		else if(op.d?)
			changedDoc = strInject docText, op.p, op.d
		changedDoc




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

