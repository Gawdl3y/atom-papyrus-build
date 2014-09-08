child_process = require 'child_process'
qs = require 'querystring'
_ = require 'underscore'

BuildView = require './build-view'

module.exports =
	configDefaults:
		compiler: 'C:\\Program Files (x86)\\Steam\\SteamApps\\common\\Skyrim\\Papyrus Compiler\\PapyrusCompiler.exe'
		imports: 'C:\\Program Files (x86)\\Steam\\SteamApps\\common\\Skyrim\\Data\\Scripts\\Source;C:\\Program Files (x86)\\Steam\\SteamApps\\common\\Skyrim\\Data\\Scripts\\Source\\Dawnguard;C:\\Program Files (x86)\\Steam\\SteamApps\\common\\Skyrim\\Data\\Scripts\\Source\\Dragonborn;C:\\Program Files (x86)\\Steam\\SteamApps\\common\\Skyrim\\Data\\Scripts\\Source\\Hearthfire'
		output: 'C:\\Program Files (x86)\\Steam\\SteamApps\\common\\Skyrim\\Data\\Scripts'

	activate: (state) ->
		@buildView = new BuildView
		atom.workspaceView.command 'papyrus-build:trigger', => @build()
		atom.workspaceView.command 'papyrus-build:stop', => @stop()

	deactivate: ->
		@child.kill('SIGKILL') if @child

	buildCommand: ->
		return {
			exec: atom.config.get 'papyrus-build.compiler'
			args: [
				atom.workspace.getActiveEditor().getUri()
				'-import=' + atom.config.get('papyrus-build.imports')
				'-output=' + atom.config.get('papyrus-build.output')
				'-flags=TESV_Papyrus_Flags.flg'
			]
			env: {}
		}

	startNewBuild: ->
		cmd = @buildCommand()
		return if not cmd.exec

		@child = child_process.spawn(cmd.exec, cmd.args, { cwd: @root })
		@child.stdout.on 'data', @buildView.append
		@child.stderr.on 'data', @buildView.append
		@child.on 'error', (err) =>
			@buildView.append 'Unable to execute: ' + cmd.exec
			@buildView.append 'Check your compiler path.'

		@child.on 'close', (exitCode) =>
			@buildView.buildFinished(0 == exitCode)
			@finishedTimer = (setTimeout (=> @buildView.detach()), 1000) if (0 == exitCode)
			@child = null

		@buildView.buildStarted()
		@buildView.append 'Executing: ' + cmd.exec + [' '].concat(cmd.args).join(' ')

	abort: (callback) ->
		@child.removeAllListeners 'close'
		@child.on 'close', =>
			@child = null
			callback?()
		@child.kill()

	build: ->
		clearTimeout @finishedTimer
		if @child then @abort(=> @startNewBuild()) else @startNewBuild()

	stop: ->
		if @child
			@abort()
			@buildView.buildAborted()
		else
			@buildView.reset()
