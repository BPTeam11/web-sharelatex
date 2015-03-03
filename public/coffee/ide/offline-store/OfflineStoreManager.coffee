define () ->
  class OfflineStoreManager
    constructor: (@ide) ->


      @ide.$scope.$on "offline:doc:change", (event, doc) =>
        console.log "ide event: offline:doc:change"
        doc.deletePendingOps()
        @cacheDocument doc  

      @ide.socket.on "connect", () =>
        console.log "connect"
        @uploadOfflineChanges()

    uploadOfflineChanges: () =>
      @ide.indexedDbManager.openCursor "doc", (cursor, err) =>
        if err?
          console.log "Error looking up offline changes: #{err}"
        else
          console.log "\"Uploading\" offline changes:"
          if cursor
            upload = {
              sessionId: @ide.socket.socket.sessionid,
              doc: cursor.value,  #upload the whole document (version, Snapshot, doc_id)
              _csrf: window.csrfToken #for security/authentication reasons
            }
            @ide.$http.post "/project/#{@ide.project_id}/merge/#{cursor.value.doc_id}", upload
       
            cursor.continue()


    cacheDocument: (doc) =>
      @ide.indexedDbManager.put(
        "doc"
          doclines: doc.getSnapshot().split("\n")
          version: doc.doc.getVersion()
          doc_id: doc.doc_id
        (res, err) -> if(err?) then console.log "Error caching document: #{err}")

    joinNewDoc: (id, callback = (error, doclines, version) ->) ->
      @ide.indexedDbManager.get "doc", id, (res, err) ->
        if err?
          console.log "[ERROR] Could not retrieve document from local Cache: #{err}"
        else
          callback(
            null
            if res? then res.doclines else ["Sorry, this document was not cached :(\nPlease connect to the internet."]
            if res? then res.version else 0)

    joinUpdatedDoc: (id, version, callback = (error, doclines, version, updates) ->) =>
      @ide.indexedDbManager.get "doc", id, (res, err) ->
        if(err?)
          console.log "Error caching document: #{err}"
        else
          callback(
            null
            if res? then res.doclines else ["this document was not cached"]
            if res? then res.version else version
            []) # There can not be updates

    cacheProject: (doc) ->
      @ide.indexedDbManager.put(
        "project"
          id: @ide.$scope.project._id
          info: @ide.$scope.project
          protocolVersion: @ide.$scope.protocolVersion
          permissionsLevel: @ide.$scope.permissionsLevel
        (res, err) -> if(err?) then console.log "Error caching project: #{err}")

    joinProject: (project_id, callback = (err, project, permissionsLevel, protocolVersion) ->) ->
      @ide.indexedDbManager.get "project", project_id, (project, error) ->
        if error?
          console.log "Error getting project from IndexedDB: #{error}"
        else
          console.log "Got cached project:"
          console.log project.info
          callback(null, project.info, project.permissionsLevel, project.protocolVersion)

    createDoc : (name, id, csrfToken) ->
      if id?
        console.log("OfflineManager: " + name + " " + " id: " + id + " csrfToken: " + csrfToken)


