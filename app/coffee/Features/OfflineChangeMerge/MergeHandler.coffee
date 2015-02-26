###### VERALTET

######ProjectEntityHandler = require('../Project/ProjectEntityHandler')
#
######module.exports = MergeHandler =
#	
######	merge: (project_id, doc_id, fromVersion, ops, callback = (project_id, doc_id, docLines) ->)-> 
#		ProjectEntityHandler.getDoc project_id, doc_id, (error, lines, rev) -> 
#			if err?
#				logger.err err:error, doc_id:doc_id, project_id:project_id, "error finding document with #{doc_id} for merge"
#			else	
#				#TODO merge 
#				callback(project_id, doc_id, lines)
#
#
#
