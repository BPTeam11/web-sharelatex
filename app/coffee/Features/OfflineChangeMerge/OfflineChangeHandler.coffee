ProjectEntityHandler = require('../Project/ProjectEntityHandler')

module.exports = MergeHandler =
	
	computeChange: (project_id, doc_id, fromVersion, sessionId, user_id, ops, callback = (project_id, doc_id, change) ->)->
		#Right now the uploaded offline changes are just added as normal changes,
		#TODO merge -> generate changes ? 
		change = {
			doc: doc_id
			op: ops 
			v : fromVersion
			meta : {
				source: sessionId
				user_id: user_id
			}
		}
		console.log user_id
		callback(project_id, doc_id, change)



#This is how change must look:
#{ doc: '54ef10d2218548d723fd9a08',
#  op: [ { p: 485, i: '\n' } ],
#  v: 148,
#  meta: 
#   { source: 'Gmo5h_AadrjwiNtU8ihv',  
#     user_id: '5470ec2a44da473009b5d6df' } }

