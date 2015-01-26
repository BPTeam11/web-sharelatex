define () ->
	# This class does just serves as a placeholder
	# unitl document caching is implemented

	
  # This class does just serves as a placeholder
  # unitl document caching is implemented

  class OfflineStoreManager
    @ide = null
    @cache = []

    @initdb: () ->
      openRequest = window.indexedDB.open "sharelatex", 1

      openRequest.onsuccess = (event) ->
        db = event.target.result

      openRequest.onerror = (event) ->
        console.log "Error opening IndexedDB: #{event.target.errorCode}"

      openRequest.onupgradeneeded = (event) ->
        db = event.target.result

        store = db.createObjectStore "doc", keyPath: "doc_id"
        docLinesIndex = store.createIndex "docLines", "docLines", unique: false
        versionIndex = store.createIndex "version", "version", unique: false

    @cacheDocument: (doc) ->
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

    @joinNewDoc: (id, callback = (error, doclines, version) ->) ->
      console.log "Requested new doc #{id} offline"
      console.log "id: #{typeof id}}"
      callback(
        null
        if @cache[id]? then @cache[id].getSnapshot() else ["this document was not cached"]
        if @cache[id]? then @cache[id].doc.getVersion() else 0)

    @joinUpdatedDoc: (id, version, callback = (error, doclines, version, updates) ->) ->
      console.log "Requested updated doc #{id} version #{version} offline"
      console.log "id: #{typeof id}, version: #{typeof version}"

      openRequest = window.indexedDB.open "sharelatex", 1

      openRequest.onsuccess = (event) ->
        db = event.target.result
        tx = db.transaction "doc", "readonly"
        store = tx.objectStore "doc"
        request = store.get id
        request.onsuccess = () ->
          cachedDoc = request.result

        tx.onabort = () ->
          console.log "Error caching document: #{tx.error}"

      openRequest.onerror = (event) ->
        console.log "Error opening IndexedDB: #{event.target.errorCode}"

      callback(
        null
        if cachedDoc? then cachedDoc.docLines else ["this document was not cached"]
        if cachedDoc? then cachedDoc.version else version
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



    @createDoc : (name, id, csrfToken) ->
      if id?
        console.log("OfflineManager: " + name + " " + " id: " + id + " csrfToken: " + csrfToken)



    @applyOtUpdate: (docId, update) =>
      @cache[docId] ||= new Document @ide docId
      @cache[docId]._onUpdateApplied update

