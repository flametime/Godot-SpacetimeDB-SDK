extends SceneTree

func _initialize() -> void:
	if not ResourceLoader.exists(SpacetimePlugin.SAVE_PATH, "SpacetimeDBPluginConfig"):
		printerr("Module configs not found at %s" % [SpacetimePlugin.SAVE_PATH])
		quit(1)

	var plugin_config: SpacetimeDBPluginConfig = ResourceLoader.load(SpacetimePlugin.SAVE_PATH)

	var http_request := HTTPRequest.new()
	http_request.set_timeout(4);
	change_scene_to_node(http_request)
	await scene_changed

	SpacetimePlugin.instance.ui_logging = false
	await SpacetimePlugin.generate_schema(http_request, plugin_config)

	print("OK!")
	quit(0)
