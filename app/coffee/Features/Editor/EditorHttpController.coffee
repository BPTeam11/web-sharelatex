ProjectEntityHandler = require "../Project/ProjectEntityHandler"
ProjectDeleter = require "../Project/ProjectDeleter"
logger = require "logger-sharelatex"
EditorRealTimeController = require "./EditorRealTimeController"
EditorController = require "./EditorController"
Metrics = require('../../infrastructure/Metrics')

module.exports = EditorHttpController =
	joinProject: (req, res, next) ->
		project_id = req.params.Project_id
		user_id = req.query.user_id
		logger.log {user_id, project_id}, "join project request"
		Metrics.inc "editor.join-project"
		EditorController.buildJoinProjectView project_id, user_id, (error, project, privilegeLevel) ->
			return next(error) if error?
			res.json {
				project: project
				privilegeLevel: privilegeLevel
			}
			# Only show the 'renamed or deleted' message once
			if project?.deletedByExternalDataSource
				ProjectDeleter.unmarkAsDeletedByExternalSource project_id

	restoreDoc: (req, res, next) ->
		project_id = req.params.Project_id
		doc_id = req.params.doc_id
		name = req.body.name

		if !name?
			return res.send 400 # Malformed request

		logger.log project_id: project_id, doc_id: doc_id, "restoring doc"
		ProjectEntityHandler.restoreDoc project_id, doc_id, name, (err, doc, folder_id) =>
			return next(error) if error?
			EditorRealTimeController.emitToRoom(project_id, 'reciveNewDoc', folder_id, doc)
			res.json {
				doc_id: doc._id
			}


	addDoc: (req, res, next) ->
		project_id = req.params.Project_id
		name = req.body.name
		parent_folder_id = req.body.parent_folder_id
		EditorController.addDoc project_id, parent_folder_id, name, [], "editor", (error, doc) ->
			return next(error) if error?
			res.json doc

	mergeDoc: (req, res, next) ->
		project_id = req.params.Project_id
		doc_id = req.params.doc_id
		fromVersion = req.body.fromVersion
		ops = req.body.ops
		EditorController.mergeDoc project_id, doc_id, fromVersion, ops, (error) ->
			return next(error) if error?

	addFolder: (req, res, next) ->
		project_id = req.params.Project_id
		name = req.body.name
		parent_folder_id = req.body.parent_folder_id
		EditorController.addFolder project_id, parent_folder_id, name, "editor", (error, doc) ->
			return next(error) if error?
			res.json doc

	renameEntity: (req, res, next) ->
		project_id  = req.params.Project_id
		entity_id   = req.params.entity_id
		entity_type = req.params.entity_type
		name = req.body.name
		if name.length > 150
			return res.send 400
		EditorController.renameEntity project_id, entity_id, entity_type, name, (error) ->
			return next(error) if error?
			res.send 204

	moveEntity: (req, res, next) ->
		project_id  = req.params.Project_id
		entity_id   = req.params.entity_id
		entity_type = req.params.entity_type
		folder_id = req.body.folder_id
		EditorController.moveEntity project_id, entity_id, folder_id, entity_type, (error) ->
			return next(error) if error?
			res.send 204

	deleteDoc: (req, res, next)->
		req.params.entity_type  = "doc"
		EditorHttpController.deleteEntity(req, res, next)

	deleteFile: (req, res, next)->
		req.params.entity_type = "file"
		EditorHttpController.deleteEntity(req, res, next)

	deleteFolder: (req, res, next)->
		req.params.entity_type = "folder"
		EditorHttpController.deleteEntity(req, res, next)

	deleteEntity: (req, res, next) ->
		project_id  = req.params.Project_id
		entity_id   = req.params.entity_id
		entity_type = req.params.entity_type
		EditorController.deleteEntity project_id, entity_id, entity_type, "editor", (error) ->
			return next(error) if error?
			res.send 204


