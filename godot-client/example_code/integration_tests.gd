extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var options :SpacetimeDBConnectionOptions = SpacetimeDBConnectionOptions.new()

	options.one_time_token = true # <--- anonymous-like. set to false to persist
	options.debug_mode = true # <--- enables lots of additional debug prints and warnings
	options.compression = SpacetimeDBConnection.CompressionPreference.GZIP
	options.threading = true
	# Increase buffer size. In general, you don't need this.
	# options.set_all_buffer_size(1024 * 1024 * 2)

	# Disable threading (e.g., for web builds)
	# options.threading = false

	SpacetimeDB.Main.connect_db( # WARNING <--- replace 'Main' with your module name
		"http://127.0.0.1:3000", # WARNING <--- replace it with your url
		"main", # WARNING <--- replace it with your database name
		options
	)

	SpacetimeDB.Main.connected.connect(_on_spacetimedb_connected)
	SpacetimeDB.Main.disconnected.connect(_on_spacetimedb_disconnected)
	SpacetimeDB.Main.connection_error.connect(_on_spacetimedb_connection_error)
	SpacetimeDB.Main.database_initialized.connect(_on_spacetimedb_database_init)

func _on_spacetimedb_connected(identity: PackedByteArray, _token: String) -> void:
	print("Game: Connected to SpacetimeDB!")
	print("Game: My Identity: 0x%s" % [identity.hex_encode()])

func _on_spacetimedb_disconnected() -> void:
	print("Game: Disconnected from SpacetimeDB.")

func _on_spacetimedb_connection_error(code: int, reason: String) -> void:
	printerr("Game: SpacetimeDB Connection Error: ", reason, " Code: ", code)

func _on_spacetimedb_database_init() -> void:
	print("Game: Database initialised")


func _on_button_pressed() -> void:
	SpacetimeDB.Main.reducers.start_integration_tests()



func _on_button_2_pressed() -> void:
	SpacetimeDB.Main.reducers.clear_integration_tests() # Replace with function body.
