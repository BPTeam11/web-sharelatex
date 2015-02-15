define [
	"base"
	"ide/file-tree/FileTreeManager"
	"ide/connection/ConnectionManager"
	"ide/editor/EditorManager"
	"ide/online-users/OnlineUsersManager"
	"ide/track-changes/TrackChangesManager"
	"ide/permissions/PermissionsManager"
	"ide/pdf/PdfManager"
	"ide/binary-files/BinaryFilesManager"
	"ide/offline-store/OfflineStoreManager"
	"ide/offline-store/IndexedDbManager"
	"ide/settings/index"
	"ide/share/index"
	"ide/chat/index"
	"ide/clone/index"
	"ide/templates/index"
	"ide/dropbox/index"
	"ide/hotkeys/index"
	"ide/directives/layout"
	"ide/services/ide"
	"__IDE_CLIENTSIDE_INCLUDES__"
	"analytics/AbTestingManager"
	"directives/focus"
	"directives/fineUpload"
	"directives/scroll"
	"directives/onEnter"
	"directives/stopPropagation"
	"directives/rightClick"
	"filters/formatDate"
	"main/event-tracking"
	"main/account-upgrade"
], (
	App
	FileTreeManager
	ConnectionManager
	EditorManager
	OnlineUsersManager
	TrackChangesManager
	PermissionsManager
	PdfManager
	BinaryFilesManager
	OfflineStoreManager
	IndexedDbManager
) ->

	App.controller "IdeController", ($scope, $timeout, ide) ->
		# Don't freak out if we're already in an apply callback
		$scope.$originalApply = $scope.$apply
		$scope.$apply = (fn = () ->) ->
			phase = @$root.$$phase
			if (phase == '$apply' || phase == '$digest')
				fn()
			else
				this.$originalApply(fn);

		$scope.state = {
			loading: true
			load_progress: 40
		}
		$scope.ui = {
			leftMenuShown: false
			view: "editor"
			chatOpen: false
			pdfLayout: 'sideBySide'
		}
		$scope.user = window.user
		$scope.settings = window.userSettings
		$scope.anonymous = window.anonymous

		$scope.chat = {}

		
		window._ide = ide

		ide.project_id = $scope.project_id = window.project_id
		ide.$scope = $scope



		ide.connectionManager = new ConnectionManager(ide, $scope)			
		ide.indexedDbManager = new IndexedDbManager
		ide.offlineStoreManager = new OfflineStoreManager ide


		setTimeout(
			() ->
				#the condition $scope.project? ensures that if we are connected and then disconnect before the time runs out we don't load the project from IndexDB
				if(!(ide.socket.connected?) && $scope.project?) 
					#dummy project:
			
					ide.offlineStoreManager.joinProject ide.project_id, (error, project, permissionsLevel, protocolVersion) =>		
						$scope.project = project

					#tell everybody that we joined a project:
					#I assume (havent tested anything) the timeout is necessary because the other constructors have to be called first.
					setTimeout(() =>
						$scope.state.load_progress = 100
						$scope.state.loading = false
						$scope.$broadcast "project:joined"
						, 100)
					setTimeout(
						() =>
							console.log "DEBUG: countdown begin"	
							ide.connectionManager.startAutoReconnectCountdown()
						, 10000)
			,7000)

		ide.fileTreeManager = new FileTreeManager(ide, $scope)
		ide.editorManager = new EditorManager(ide, $scope)
		ide.onlineUsersManager = new OnlineUsersManager(ide, $scope)
		ide.trackChangesManager = new TrackChangesManager(ide, $scope)
		ide.pdfManager = new PdfManager(ide, $scope)
		ide.permissionsManager = new PermissionsManager(ide, $scope)
		ide.binaryFilesManager = new BinaryFilesManager(ide, $scope)
		
		inited = false
		$scope.$on "project:joined", () ->
			return if inited
			inited = true
			if $scope.project.deletedByExternalDataSource
				ide.showGenericMessageModal("Project Renamed or Deleted", """
					This project has either been renamed or deleted by an external data source such as Dropbox.
					We don't want to delete your data on ShareLaTeX, so this project still contains your history and collaborators.
					If the project has been renamed please look in your project list for a new project under the new name.
				""")
				
		DARK_THEMES = [
			"ambiance", "chaos", "clouds_midnight", "cobalt", "idle_fingers",
			"merbivore", "merbivore_soft", "mono_industrial", "monokai",
			"pastel_on_dark", "solarized_dark", "terminal", "tomorrow_night",
			"tomorrow_night_blue", "tomorrow_night_bright", "tomorrow_night_eighties",
			"twilight", "vibrant_ink"
		]
		$scope.darkTheme = false
		$scope.$watch "settings.theme", (theme) ->
			if theme in DARK_THEMES
				$scope.darkTheme = true
			else
				$scope.darkTheme = false

	angular.bootstrap(document.body, ["SharelatexApp"])
