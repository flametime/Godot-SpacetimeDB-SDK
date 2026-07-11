extends Control

@onready var label: Label = $GridContainer/Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	#connect
	var options :SpacetimeDBConnectionOptions = SpacetimeDBConnectionOptions.new()
	#options.one_time_token = true # <--- anonymous-like. set to false to persist
	options.debug_mode = true # <--- enables lots of additional debug prints and warnings
	options.compression = SpacetimeDBConnection.CompressionPreference.GZIP
	options.threading = false
	options.monitor_mode = true
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

func _on_spacetimedb_connected(_identity: PackedByteArray, _token: String) -> void:
	label.text = "Connected"

func _on_spacetimedb_disconnected() -> void:
	label.text = "Disonnected"

func _on_spacetimedb_connection_error(code: int, reason: String) -> void:
	label.text = "Connection Error: "+ reason+ " Code: "+ str(code)

func _on_button_2_pressed() -> void:
	#reconnect
	SpacetimeDB.Main.reconnect_db(true)
	label.text = "Reconnecting"

func _on_button_3_pressed() -> void:
	# disconnect
	SpacetimeDB.Main.disconnect_db()
	label.text = "Disconnecting"


func _on_button_4_pressed() -> void:
	SpacetimeDB.Main.disconnect_db()
	await SpacetimeDB.Main.disconnected
	get_tree().quit()
	# Replace with function body.
