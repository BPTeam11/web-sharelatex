define () ->
  class CacheUpdater
    constructor: (@ide) ->
      @ide.socket.on "connect", () =>
        @ide.$http.get "/project/#{@ide.project_id}/cache", {timeout: 20000}
          .success (data)=>
            project = data.projectCache
            @ide.indexedDbManager.put(
              "project"
                id: project._id
                info: project
                permissionsLevel: @ide.$scope.permissionsLevel
                protocolVersion: @ide.$scope.protocolVersion
              (res, err) -> if(err?) then console.log "Error caching data: #{err}")
            for doc in data.docsCache
              @ide.indexedDbManager.put(
                "doc"
                  doc
                (res, err) -> if(err?) then console.log "Error putting document in cache: #{err}")
          .error (data, status, headers, config )->
            console.log "Error getting cache-dump:\n#{data}\n#{status}\n#{headers}\n#{config}"
