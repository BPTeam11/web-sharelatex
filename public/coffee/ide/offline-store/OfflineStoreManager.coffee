define () ->
  class OfflineStoreManager
    constructor: (@ide) ->
      @lastCache = 0
      @mergeListeners = []

      @ide.$scope.$on "doc:change", (event, doc) =>
        if @timeout?
          clearTimeout @timeout

        if @isOffline() || Date.now() - @lastCache >= 5000
          @timeout = null
          @cacheDocument doc, true
          if @isOffline()
            doc.deletePendingOps()
            doc.deleteInflightOp()
          
        else
          @timeout = setTimeout ()=>
            @timeout = null
            @cacheDocument doc, true
            if @isOffline()
              doc.deletePendingOps()
              doc.deleteInflightOp()
          , 2000

      @ide.socket.on "connect", () =>
        console.log "connect"
        @uploadOfflineChanges()

      @ide.socket.on "disconnect", () ->
        console.log "disconnect"

    uploadOfflineChanges: () =>
      console.log "Uploading offline changes:"
      currentDoc = @ide.editorManager.getCurrentDoc()
      console.log "current doc:", currentDoc
      curDocChanged = false

      @ide.indexedDbManager.openCursor "changedOffline", (cursor, err) =>
        if err?
          console.log "Error looking up offline changes: #{err}"
        else
          if cursor
            doc_id = cursor.value.doc_id

            console.log "uploading doc #{doc_id}"

            @ide.indexedDbManager.get "doc", doc_id, (doc, error) =>
              upload = {
                sessionId: @ide.socket.socket.sessionid,
                doc: doc,  #upload the whole document (version, Snapshot, doc_id)
                _csrf: window.csrfToken #for security/authentication reasons
              }

              mergingCurrentDoc = doc_id == @ide.editorManager.getCurrentDocId() && currentDoc?

              if mergingCurrentDoc
                console.log "curDocChanged"
                console.log doc_id
                curDocChanged = true

              @ide.$http.post "/project/#{@ide.project_id}/merge/#{doc_id}", upload
                .success (data) =>
                  #console.log "merge of doc #{doc_id} complete"
                  #console.log "ops:"
                  #console.log data
                  

                  if mergingCurrentDoc
                    console.log currentDoc
                    #@ide.editorManager.openDoc currentDoc, true
                    ###
                    console.log "merged doc is currently open, applying updates..."
                    doc = @ide.editorManager.getCurrentDoc()
                    sjsDoc = doc.doc
                    console.log "applying", data.ops
                    msg =
                      op: data.ops
                      v: sjsDoc._doc.version
                      doc: sjsDoc._doc.name
                      meta: {}
                      
                    # fixme: this is *not* an usual update from server
                    sjsDoc.processUpdateFromServer msg
                      
                    console.log "updates done"
                    console.log "setting version to #{data.newVersion}"
                    sjsDoc._doc.version = data.newVersion
                    doc.unpause()###

                .error (data, status) ->
                  console.log "merge error: #{status}"
                  console.log data
       
            cursor.continue()

          else # processed all updates
            

            console.log "curDocChanged:", curDocChanged

            if !curDocChanged
              currentDoc?.unpause()

            for listener in @mergeListeners
              listener()

            @ide.indexedDbManager.clear "changedOffline", (err) ->
              if err?
                console.log err

              if curDocChanged
                window.location.reload()
            

    cacheDocument: (doc, changed) =>
      @lastCache = Date.now()
      @ide.indexedDbManager.put(
        "doc"
          doclines: doc.getSnapshot().split("\n")
          version: doc.doc.getVersion()
          doc_id: doc.doc_id
        (res, err) -> if(err?) then console.log "Error caching document: #{err}")

      if changed && @isOffline()
        @ide.indexedDbManager.put "changedOffline", { doc_id: doc.doc_id }, (res, err) ->
          if err?
            console.log "Error marking doc #{doc.doc_id} changed:"
            console.log err


    cacheRecivedDocument: (doc) =>
      console.log "================DEBUG================", doc.lines
      @ide.indexedDbManager.put(
        "doc"
          doclines: doc.lines
          version: doc.rev
          doc_id: doc._id
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


    updateProject : (newRootFolder) -> 
      updated_project = @ide.$scope.project
      updated_project.rootFolder[0] = newRootFolder
      @ide.indexedDbManager.put(
        "project"
          id: updated_project._id
          info: updated_project
          protocolVersion: @ide.$scope.protocolVersion
          permissionsLevel: @ide.$scope.permissionsLevel
        (res, err) -> if(err?) then console.log "Error caching project: #{err}")

    addMergeListener: (listener) =>
      @mergeListeners.push listener

    isOffline: () =>
      !@ide.$scope.connection.connected
