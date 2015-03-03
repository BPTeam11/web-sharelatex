ProjectEntityHandler = require('../Project/ProjectEntityHandler')

module.exports = MergeHandler =
	
	computeChange: (project_id, user_id, sessionId, doc, callback = (project_id, doc_id, change) ->)->

		console.log "MergeHandler here :)"
		console.log doc
	
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
#


		#TODO merge -> generate changes ? 

		ops = [] 
		#check if ops are empty. We do not want to upload no changes. (may even cause confusion, terror and error)
		change = {
			doc: doc.doc_id
			op: ops 
			v : doc.version
			meta : {
				source: sessionId
				user_id: user_id
			}
		}
		console.log user_id
		callback(project_id, doc.doc_id, change)

#This is how change must look:
#{ doc: '54ef10d2218548d723fd9a08',
#  op: [ { p: 485, i: '\n' } ],
#  v: 148,
#  meta: 
#   { source: 'Gmo5h_AadrjwiNtU8ihv',  
#     user_id: '5470ec2a44da473009b5d6df' } }

