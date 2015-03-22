define () ->
  class OfflineStoreManager
    constructor: (@ide) ->


      @ide.$scope.$on "offline:doc:change", (event, doc) =>
        console.log "ide event: offline:doc:change"
        doc.deletePendingOps()
        doc.deleteInflightOp()

        @cacheDocument doc, true

      @ide.socket.on "connect", () =>
        console.log "connect"
        @uploadOfflineChanges()

    uploadOfflineChanges: () =>
      @ide.indexedDbManager.openCursor "changedOffline", (cursor, err) =>
        if err?
          console.log "Error looking up offline changes: #{err}"
        else
          console.log "Uploading offline changes:"
          if cursor
            doc_id = cursor.value.doc_id

            console.log "uploading doc #{doc_id}"

            @ide.indexedDbManager.get "doc", doc_id, (doc, error) =>
              upload = {
                sessionId: @ide.socket.socket.sessionid,
                doc: doc,  #upload the whole document (version, Snapshot, doc_id)
                _csrf: window.csrfToken #for security/authentication reasons
              }
              @ide.$http.post "/project/#{@ide.project_id}/merge/#{doc_id}", upload
                .success (data) =>
                  console.log "merge of doc #{doc_id} complete"
                  console.log "ops:"
                  console.log data

                  if doc_id == @ide.editorManager.getCurrentDocId()
                    console.log "merged doc is currently open, applying updates..."
                    doc = @ide.editorManager.getCurrentDoc()
                    sjsDoc = doc.doc
                    version = sjsDoc._doc.version
                    console.log "applying", data.ops
                    msg =
                      op: data.ops
                      v: version
                      doc: sjsDoc._doc.name
                      meta: {}
                      
                    # fixme: this is *not* an usual update from server
                    sjsDoc.processUpdateFromServer msg
                    version++
                      
                    console.log "updates done"
                    console.log "setting version to #{data.newVersion}"
                    sjsDoc._doc.version = data.newVersion
                    console.log "unpausing document"
                    doc.unpause()

                .error (data, status) ->
                  console.log "merge error: #{status}"
                  console.log data
       
            cursor.continue()

          else # processed all updates
            @ide.indexedDbManager.clear "changedOffline", (err) ->
              if err?
                console.log err


    cacheDocument: (doc, changed) =>
      @ide.indexedDbManager.put(
        "doc"
          doclines: doc.getSnapshot().split("\n")
          version: doc.doc.getVersion()
          doc_id: doc.doc_id
        (res, err) -> if(err?) then console.log "Error caching document: #{err}")

      if changed
        @ide.indexedDbManager.put "changedOffline", { doc_id: doc.doc_id }, (res, err) ->
          if err?
            console.log "Error marking doc #{doc.doc_id} changed:"
            console.log err

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


