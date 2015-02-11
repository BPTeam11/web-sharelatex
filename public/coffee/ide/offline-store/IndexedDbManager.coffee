define [], () ->
	class IndexedDbManager
		constructor: () ->
			@ready = false
			@initDb()
			@pendingOps = []
			
		initDb: () ->
			openRequest = window.indexedDB.open "testDb", 1

			openRequest.onsuccess = (event) =>
				@db = event.target.result
				@ready = true
				@flushPendingOps()

			openRequest.onerror = (event) ->
				console.log "Error opening IndexedDB: #{event.target.errorCode}"

			openRequest.onupgradeneeded = (event) =>
				@db = event.target.result

				store = @db.createObjectStore "doc", keyPath: "doc_id"
				docLinesIndex = store.createIndex "docLines", "docLines", unique: false
				versionIndex = store.createIndex "version", "version", unique: false
					
		flushPendingOps: () =>
			for f in @pendingOps
				f()
				
			@pendingOps = []
				
		# Stalls f() if the database is not ready yet.
		
		# Due to the asynchronous nature of IndexedDB,
		# it cannot be guaranteed that @db is set after
		# the constructor (and initDb()) is finished.
		readyHandler: (f) =>
			if(@ready)
				f()
			else
				@pendingOps.push f
				
		get: (store, key, callback = (result, error)->) =>
			@readyHandler () =>
				req = @db.transaction([store], "readonly").objectStore(store).get(key)
				req.onerror = (event) -> callback null, event.target.errorCode
				req.onsuccess = (event) -> callback event.target.result
			
		add: (store, data, callback = (key, error)-> ) =>
			@readyHandler () =>
				trans = @db.transaction([store], "readwrite")
				trans.onerror = (event) -> callback null, event.target.errorCode
				
				trans.objectStore(store).add(data).onsuccess = (event) =>
					trans.oncomplete = (e) -> callback event.target.result
					
		put: (store, data, callback = (key, error)-> ) =>
			@readyHandler () =>
				trans = @db.transaction([store], "readwrite")
				trans.onerror = (event) -> callback null, event.target.errorCode
				
				trans.objectStore(store).put(data).onsuccess = (event) =>
					trans.oncomplete = (e) -> callback event.target.result
					
		delete: (store, key, callback = (error)->) =>
			@readyHandler () =>
				trans = @db.transaction([store], "readwrite")
				trans.onerror = (event) -> callback event.target.errorCode
				trans.oncomplete = (event) -> callback null
				
				trans.objectStore(store).delete(key)
