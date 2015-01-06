define () ->
	# This class does just serves as a placeholder
	# unitl document caching is implemented

	class OfflineStoreManager
		@joinNewDoc: (id, callback = (error, doclines, version) ->) ->
			console.log "Requested new doc #{id} offline"
			console.log "id: #{typeof id}}"
			callback(null, ["this document was not cached"], 1)

		@joinUpdatedDoc: (id, version, callback = (error, doclines, version, updates) ->) ->
			console.log "Requested updated doc #{id} version #{version} offline"
			console.log "id: #{typeof id}, version: #{typeof version}"
			callback(null, ["this document was not cached"], version, [])
