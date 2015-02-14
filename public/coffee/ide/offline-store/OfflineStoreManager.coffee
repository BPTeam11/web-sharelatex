define () ->
  class OfflineStoreManager
    constructor: (@ide) ->
      @lastPendingOp = -1
      @ide.$scope.$on "offline:doc:change", (event, doc) =>
        console.log "ide event: offline:doc:change"
        pendingOps = doc.getPendingOp()
        console.log pendingOps

        if @lastPendingOp == -1
          @lastPendingOp = 0

        # pendingOps[0...@lastPendingOp] are already stored

        for i in [@lastPendingOp ... pendingOps.length]
          @ide.indexedDbManager.put "offlineChanges", {id: i, op: pendingOps[i]}, (res, err) ->
            if(err?) then console.log err

        @lastPendingOp = pendingOps.length - 1

      @ide.socket.on "connect", () =>
        console.log "connect"
        if @lastPendingOp >= 0
          @uploadOfflineChanges()

    uploadOfflineChanges: () =>
      # TODO
      @ide.indexedDbManager.openCursor "offlineChanges", (cursor, err) =>
        if err?
          console.log "Error looking up offline changes: #{err}"
        else
          console.log "\"Uploading\" offline changes:"
          if cursor
            console.log cursor.value
            cursor.continue()
          else
            @lastPendingOp = -1
            @ide.indexedDbManager.clear "offlineChanges", (err) ->
              if err? then console.log "Failed to clear offlineChanges: #{err}"

    cacheDocument: (doc) =>
      @ide.indexedDbManager.put(
        "doc"
          doclines: doc.getSnapshot()
          version: doc.doc.getVersion()
          doc_id: doc.doc_id
        (res, err) -> if(err?) then console.log "Error caching document: #{err}")

    joinNewDoc: (id, callback = (error, doclines, version) ->) =>
      console.log "Requested new doc #{id} offline"
      console.log "id: #{typeof id}}"
      callback(
        null
        if @cache[id]? then @cache[id].getSnapshot() else ["this document was not cached"]
        if @cache[id]? then @cache[id].doc.getVersion() else 0)

    joinUpdatedDoc: (id, version, callback = (error, doclines, version, updates) ->) =>
      console.log "Requested updated doc #{id} version #{version} offline"
      console.log "id: #{typeof id}, version: #{typeof version}"

      @ide.indexedDbManager.get "doc", id, (res, err) ->
        if(err?)
          console.log "Error caching document: #{err}"
        else
          callback(
            null
            if res? then res.docLines else ["this document was not cached"]
            if res? then res.version else version
            []) # There can not be updates

    cacheProject: (doc) ->
      console.log "Caching project #{@ide.$scope.project._id}"
      @ide.indexedDbManager.put(
        "project"
          id: @ide.$scope.project._id
          info: @ide.$scope.project
        (res, err) -> if(err?) then console.log "Error caching project: #{err}")

    joinProject: (project_id, callback = (err, project, permissionsLevel, protocolVersion) ->) ->
      console.log "Requested project project #{project_id} version offline"

      @ide.indexedDbManager.get "project", project_id, (project, error) ->
        if error?
          console.log "Error getting project from IndexedDB: #{error}"
        else
          console.log "Got cached project:"
          console.log project.info
          callback(null, project.info, null, null)

    createDoc : (name, id, csrfToken) ->
      if id?
        console.log("OfflineManager: " + name + " " + " id: " + id + " csrfToken: " + csrfToken)



    applyOtUpdate: (docId, update) =>
      #@cache[docId] ||= new Document @ide docId
      #@cache[docId]._onUpdateApplied update

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
