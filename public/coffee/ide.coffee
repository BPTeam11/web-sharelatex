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
		#Com1: set a breakpoint here to set isOnline = false with the debugger when you go offline
		#later we probably can detect isOnline
		isOnline = true;
		if(isOnline)
			$scope.state = {
				loading: true
				load_progress: 40
			}
		else 
			$scope.state = {
				loading: false
				load_progress: 100
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

		#Com2: if we're online do what you always do
		if(isOnline) 
			ide.connectionManager = new ConnectionManager(ide, $scope)
		#if we're offline create a 'dummy' ide.connectionManager and ide.socket and a dummy project
		else
			#dummy connectionManager:
			ide.connectionManager = 
				disconnect : () -> console("Testbranch: connectionManager disconnect()")
				reconnectImmediately : () -> console("Testbranch: connectionManager reconnectImmediately()")
			#dummy socket:
			ide.socket = 
				on : (EventName, func = (a...) -> ) -> 
					console.log("Testbranch: The event: " + EventName + "was registered by socket.on")
				emit :  (EventName, args..., callback) -> 
					console.log("Testbranch: The event: " + EventName + "was send with socket.emit")
					#return the 'dummy' DocLines if the event is joinDoc
					if(EventName == "joinDoc")
						callback null, ["I always thought something was fundamentally wrong with the universe", "another line"],0, []
				socket : {connected : true}
			#dummy project:
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
						
			$scope.project = project

			#tell everybody that we joined a project:
			#I assume (havent tested anything) the timeout is necessary because the other constructors have to be called first.
			setTimeout(() =>
				$scope.$broadcast "project:joined"
				, 100)

		#other constructors:
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
