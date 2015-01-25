define () ->
	# This class does just serves as a placeholder
	# unitl document caching is implemented

	class OfflineStoreManager
		@ide = null
		@cache = {}
		@CreatedDocCache = {}
		@MapOnlineIdToOfflineId = {}

		@cacheDocument: (doc) ->
			@cache[doc.doc_id] = doc

		@joinNewDoc: (id, callback = (error, doclines, version) ->) ->
			console.log "Requested new doc #{id} offline"
			console.log "id: #{typeof id}}"
			callback(
				null
				if @cache[id]? then @cache[id].getSnapshot() else [""]
				if @cache[id]? then @cache[id].doc.getVersion() else 0)

		@joinUpdatedDoc: (id, version, callback = (error, doclines, version, updates) ->) ->
			console.log "Requested updated doc #{id} version #{version} offline"
			console.log "id: #{typeof id}, version: #{typeof version}"
			callback(
				null
				if @cache[id]? then @cache[id].getSnapshot() else [""]
				if @cache[id]? then @cache[id].doc.getVersion() else version
				[]) # There can not be updates

		@joinProject: (project_id, callback = (err, project, permissionsLevel, protocolVersion) ->) ->
			console.log "Requested project project #{project_id} version offline"
			project = 
				_id : "54a3eb428738a0fb421300ec"
				compiler : "pdflatex"
				deletedByExternalDataSource : false
				deletedDocs: []
				description: ""
				dropboxEnabled: false
				features : 
					collaborators: -1
					compileGroup: "standard"
					compileTimeout: 60
					dropbox: true
					versioning: true
				members : []
				name: "Project 1"
				owner : 
					_id: "5470ec2a44da473009b5d6df"
					email: "a@a.de"
					first_name: "a"
					last_name: ""
					privileges: "owner"
					signUpDate: "2014-11-22T20:03:54.169Z"
				publicAccesLevel: "private"
				rootDoc_id: "54a3eb428738a0fb421300ed"
				rootFolder: [
					{
						_id: "54a3eb428738a0fb421300eb"
						docs: [
							{								
								_id: "54a3eb428738a0fb421300ed"
								name: "main.tex"
							},
							{
								_id: "54a3eb428738a0fb421300ee"
								name: "references.bib"
							}
						]
						fileRefs : [
							{
								_id: "54a3eb428738a0fb421300ef"
								name: "universe.jpg"
							}
						],
						folders : []
						name: "rootFolder"
					}
				]
				spellCheckLanguage: "en"
			callback(null, project, null, null) #permissionlevel is a string = "readOnly" or "readAndWrite" or "owner". We should save that in the index.db too


		@createDoc : (project_id, name, parent_folder_id, offline_doc_id, csrfToken, ide) ->
			offline_information = {offline_doc_id : offline_doc_id, creator : ide.$scope.user.id}
			@CreatedDocCache[offline_doc_id] = {project_id: project_id, name: name, parent_folder_id: parent_folder_id,  _csrf : csrfToken, offline_information : offline_information}   
			console.log("OfflineManager: " + " project ID: " + project_id + "  name: " + name + " " + " id: " + offline_doc_id + " csrfToken: " + csrfToken)
			
		@upload : (ide) -> 
			for offline_doc_id, document of @CreatedDocCache #cant upload multiple documents (well -> probably needs a timeout)
				ide.$http.post "/project/#{document.project_id}/doc", document
				delete @CreatedDocCache[offline_doc_id]
		
		@bindId : (offline_doc_id, online_do_id, ide) ->	
			@MapOnlineIdToOfflineId[online_do_id] = offline_doc_id
			#@removeFromOfflineCache(offline_doc_id)
			console.log("The offline Doc Id is: " + offline_doc_id + "  and the online Doc Id is " +  online_do_id)

		@removeFromOfflineCache : (offline_doc_id) ->
			delete @CreatedDocCache[offline_doc_id]

		@applyPendingUpdates : (doc) ->
			doc_id = doc.doc_id
			offline_doc_id = @MapOnlineIdToOfflineId[doc_id]
			if(offline_doc_id? )
				if(@cache[offline_doc_id]?)
					doc._doc.insert 0, @cache[offline_doc_id].doc._doc.snapshot, (error) -> #TODO there is a big problem, because if you only apply updates on join, someone else may already have written something in your offline created document which was still empty because you didn join
						if error?
							console.log "There was an error with updating the offline created Document"
						else
							console.log "The offline created Document was updated succesfully"
					delete @cache[offline_doc_id]
				delete @MapOnlineIdToOfflineId[doc_id]
				

		@applyOtUpdate: (docId, update) =>
			@cache[docId] ||= new Document @ide docId
			@cache[docId]._onUpdateApplied update

