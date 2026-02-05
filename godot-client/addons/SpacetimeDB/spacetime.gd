@tool
class_name SpacetimePlugin extends EditorPlugin

const LEGACY_DATA_PATH := "res://spacetime_data"
const BINDINGS_PATH := "res://spacetime_bindings"
const BINDINGS_SCHEMA_PATH := BINDINGS_PATH + "/schema"
const AUTOLOAD_NAME := "SpacetimeDB"
const AUTOLOAD_FILE_NAME := "spacetime_autoload.gd"
const AUTOLOAD_PATH := BINDINGS_SCHEMA_PATH + "/" + AUTOLOAD_FILE_NAME
const SAVE_PATH := BINDINGS_PATH + "/plugin_config.tres"
const CONFIG_PATH := "res://addons/SpacetimeDB/plugin.cfg"
const UI_PANEL_NAME := "SpacetimeDB"
const UI_PATH := "res://addons/SpacetimeDB/ui/ui.tscn"

var http_request := HTTPRequest.new()
var plugin_config: SpacetimeDBPluginConfig
var ui: SpacetimePluginUI
var dock : EditorDock

static var instance: SpacetimePlugin

func _enter_tree():
	instance = self

	if not is_instance_valid(dock):
		var scene = load(UI_PATH)
		if scene:
			if not is_instance_valid(ui):
				ui = scene.instantiate() as SpacetimePluginUI
			dock = EditorDock.new()
			dock.title = "SpacetimeDB"
			dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
			dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
			dock.add_child(ui)
			add_dock(dock)
		else:
			printerr("SpacetimePlugin: Failed to load UI scene: ", UI_PATH)
			return
	else:
		printerr("SpacetimePlugin: UI panel is not valid after instantiation")
		return

	ui.plugin_config_changed.connect(_on_plugin_config_changed)
	ui.check_uri.connect(_on_check_uri)
	ui.generate_schema.connect(_on_generate_schema)
	ui.clear_logs()

	http_request.timeout = 4;
	add_child(http_request)

	var config_file = ConfigFile.new()
	config_file.load(CONFIG_PATH)

	var version: String = config_file.get_value("plugin", "version", "0.0.0")
	var author: String = config_file.get_value("plugin", "author", "??")

	print_log("SpacetimeDB SDK v%s (c) 2025-present %s & Contributors" % [version, author])
	print_log("""New modules:
[ul]
Name: Required
Alias: Optional
Hide scheduled reducer: Hides the scheduled reducer from the client.
Hide private tables: Hides private tables from the client.
[/ul]

After generating schema files, please restart Godot.
""")
	load_codegen_data()


func load_codegen_data() -> void:
	if ResourceLoader.exists(SAVE_PATH, "SpacetimeDBPluginConfig"):
		plugin_config = ResourceLoader.load(SAVE_PATH)
		print_log("Loaded module configs from %s" % [SAVE_PATH])
	if plugin_config == null or plugin_config.module_configs.is_empty():
		plugin_config = SpacetimeDBPluginConfig.new()
	ui._plugin_config = plugin_config
	ui.update_module_ui()

func save_codegen_data() -> void:
	if not FileAccess.file_exists(BINDINGS_PATH):
		DirAccess.make_dir_absolute(BINDINGS_PATH)
		get_editor_interface().get_resource_filesystem().scan()
	if not plugin_config:
		ui.add_err("Somehow the plugin_config variable is empty")
		plugin_config = SpacetimeDBPluginConfig.new()
		ui._plugin_config = plugin_config
		ui.update_module_ui()
	ResourceSaver.save(plugin_config, SAVE_PATH)

func _on_plugin_config_changed() -> void:
	save_codegen_data()

func _on_check_uri():
	if plugin_config.uri.ends_with("/"):
		plugin_config.uri = plugin_config.uri.left(-1)
		save_codegen_data()
	var uri = plugin_config.uri
	uri += "/v1/ping"
	print_log("Pinging... " + uri)
	http_request.request(uri)
	var result = await http_request.request_completed
	if result[1] == 0:
		print_err("Request timeout - " + uri)
	else:
		print_log("Response code: " + str(result[1]))

func _on_generate_schema():
	if plugin_config.uri.ends_with("/"):
		plugin_config.uri = plugin_config.uri.left(-1)

	print_log("Starting code generation...")
	print_log("Fetching module schemas...")
	var failed = false
	for module_alias: String in plugin_config.module_configs:
		var module_config: SpacetimeDBModuleConfig = plugin_config.module_configs[module_alias]
		var schema_uri := "%s/v1/database/%s/schema?version=9" % [plugin_config.uri, module_config.name]
		http_request.request(schema_uri)
		var result = await http_request.request_completed
		if result[1] == 200:
			var json: String= PackedByteArray(result[3]).get_string_from_utf8()
			var snake_module_name = module_config.alias.replace("-", "_")
			module_config.unparsed_module_schema = json
			print_log("Fetched schema for module: %s with alias: %s" % [module_config.name, module_config.alias])
			continue

		if result[1] == 404:
			print_err("Module not found - %s" % [schema_uri])
		elif result[1] == 0:
			print_err("Request timeout - %s" % [schema_uri])
		else:
			print_err("Failed to fetch module schema: %s - Response code %s" % [module_config.name, result[1]])
		failed = true

	if failed:
		print_err("Code generation failed!")
		return

	var codegen := SpacetimeCodegen.new(BINDINGS_SCHEMA_PATH)
	codegen._plugin_config = plugin_config
	var generated_files := codegen.generate_bindings()

	_cleanup_unused_classes(BINDINGS_SCHEMA_PATH, generated_files)

	if DirAccess.dir_exists_absolute(LEGACY_DATA_PATH):
		print_log("Removing legacy data directory: %s" % LEGACY_DATA_PATH)
		DirAccess.remove_absolute(LEGACY_DATA_PATH)

	var setting_name := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting_name):
		var current_autoload: String = ProjectSettings.get_setting(setting_name)
		if current_autoload != "*%s" % AUTOLOAD_PATH:
			print_log("Removing old autoload path: %s" % current_autoload)
			ProjectSettings.set_setting(setting_name, null)

	if not ProjectSettings.has_setting(setting_name):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	while get_editor_interface().get_resource_filesystem().is_scanning():
		print_log("Waiting for auto scan to finish")
		continue
	get_editor_interface().get_resource_filesystem().scan()
	print_log("Code generation complete!")


func _cleanup_unused_classes(dir_path: String = "res://schema", files: Array[String] = []) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir: return
	print_log("File Cleanup: Scanning folder: " + dir_path)
	for file in dir.get_files():
		if not file.ends_with(".gd"): continue
		var full_path = "%s/%s" % [dir_path, file]
		if not full_path in files:
			print_log("Removing file: %s" % [full_path])
			DirAccess.remove_absolute(full_path)
			if FileAccess.file_exists("%s.uid" % [full_path]):
				DirAccess.remove_absolute("%s.uid" % [full_path])
	var subfolders = dir.get_directories()
	for folder in subfolders:
		_cleanup_unused_classes(dir_path + "/" + folder, files)

static func clear_logs():
	instance.ui.clear_logs()

static func print_log(text: Variant) -> void:
	instance.ui.add_log(text)

static func print_err(text: Variant) -> void:
	instance.ui.add_err(text)

func _exit_tree():
	ui.destroy()
	ui = null
	remove_dock(dock)
	dock.queue_free()
	dock = null
	http_request.queue_free()
	http_request = null

	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
