async                   = require "async"
Project                 = require("../../models/Project").Project
ProjectCacheManager     = require "./ProjectCacheManager"

module.exports = ProjectCacheController =

  cacheByUser: (req, res, next) ->
    cache = []
    user_id = req.session.user._id
    Project.findAllUsersProjects user_id, (error, projects)->
      async.map projects, ProjectCacheManager.createCacheForProject,
        (err, results) ->
          res.type "json"
          res.send JSON.stringify results

  cacheProject: (req, res, next) ->
    cache = []
    project = {_id: req.params.Project_id}
    ProjectCacheManager.createCacheForProject project, (error, cache)->
      res.type "json"
      res.send JSON.stringify cache
