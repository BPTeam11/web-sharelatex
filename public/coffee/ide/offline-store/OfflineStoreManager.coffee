define () ->
  class OfflineStoreManager
    constructor: (@ide) ->
      @lastPendingOp = -1
      @ide.$scope.$on "offline:doc:change", (event, doc) =>
        console.log "ide event: offline:doc:change"
        pendingOps = doc.getAndDeletePendingOp()
        console.log pendingOps

	#TODO: on reload this counter will be wrong. It should be saved, too. 
        @lastPendingOp += 1 

        for i in [0 ... pendingOps.length]
          @ide.indexedDbManager.put "offlineChanges", {id: @lastPendingOp, op: pendingOps[i]}, (res, err) ->
            if(err?) then console.log err



      @ide.socket.on "connect", () =>
        console.log "connect"
        if @lastPendingOp >= 0
          @uploadOfflineChanges()

    uploadOfflineChanges: () =>
      opList = [];
      @ide.indexedDbManager.openCursor "offlineChanges", (cursor, err) =>
        if err?
          console.log "Error looking up offline changes: #{err}"
        else
          console.log "\"Uploading\" offline changes:"
          if cursor
            opList.push cursor.value.op
            console.log cursor.value.op
            cursor.continue()
          else
            upload = {
              fromVersion: @ide.$scope.editor.sharejs_doc.doc._doc.version #TODO load the doc version from IndexDB according to the document,
              sessionId: @ide.socket.socket.sessionid,
              ops: opList,
              _csrf: window.csrfToken #for security/authentication reasons
            }
            #TODO load the document the changes belong to and use it in the merge adress below
            @ide.$http.post "/project/#{@ide.project_id}/merge/#{@ide.$scope.editor.sharejs_doc.doc_id}", upload
            
            @lastPendingOp = -1
            @ide.indexedDbManager.clear "offlineChanges", (err) ->
              if err? then console.log "Failed to clear offlineChanges: #{err}"
     

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

    applyOtUpdate: (docId, update) =>
      console.log "applyOtUpdate"
      console.log docId
      console.log update
      ###
      openRequest = window.indexedDB.open "sharelatex", 1

      openRequest.onsuccess = (event) ->
        db = event.target.result
        tx = db.transaction "doc", "readwrite"

        store = tx.objectStore "doc"
        store.put doclines: doc.getSnapshot(), version: doc.doc.getVersion(), doc_id: doc.doc_id

        tx.onabort = () ->
          console.log "Error caching document: #{tx.error}"

      openRequest.onerror = (event) ->
        console.log "Error opening IndexedDB: #{event.target.errorCode}"
      ###
