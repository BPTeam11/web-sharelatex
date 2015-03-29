mongojs = require("../../infrastructure/mongojs")
db = mongojs.db
ObjectId = mongojs.ObjectId
async    = require "async"
ProjectEntityHandler = require "../Project/ProjectEntityHandler"
ProjectGetter = require "../Project/ProjectGetter"

module.exports = ProjectCacheManager =

  createCacheForProject: (project, callback = (error, cache) ->) ->
    async.parallel {
      projectCache: (callback) ->
        ProjectCacheManager.createProjectCacheEntry project._id, callback
      docsCache: (callback) ->
        ProjectCacheManager.addAllDocsToCache project._id, callback
    }, (error, results) ->
      return callback(error, null) if error?
      callback(null, results)

  addAllDocsToCache: (project_id, callback = (error, cache) ->) ->
    ProjectEntityHandler.getAllDocs project_id, (error, docs) ->
      return callback(error, null) if error?
      cache = []
      for name, doc of docs
        cache.push {
          doc_id: doc._id
          doclines: doc.lines
          version: doc.rev
        }
      callback(null, cache)

  createProjectCacheEntry: (project_id, callback = (error, cache) ->) ->
    ProjectGetter.getProject project_id, (error, project) ->
      return callback(error, null) if error?
      project = project[0]

      getUser = (user_id, callback=(error, user) ->) ->
        unless user_id instanceof ObjectId
          user_id = ObjectId(user_id)
        db.users.find _id: user_id, (error, users = []) ->
          callback error, users[0]

      getUser project.owner_ref, (error, user) ->
        return callback(error, null) if error?
        if user?
          project.owner = user
        callback(null, project)

