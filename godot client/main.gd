extends Node3D

func _ready():
	SpacetimeDB.connect_db(
		"http://localhost:3000", #WARNING <--- replace it with your url
		"godot-client", #WARNING <--- replace it with your database
		SpacetimeDBConnection.CompressionPreference.NONE,
		true, #WARNING <--- one time token. New window = new token
		false #WARNING <--- debug mode, print logs
		)

	SpacetimeDB.connected.connect(_on_spacetimedb_connected)
	SpacetimeDB.disconnected.connect(_on_spacetimedb_disconnected)
	SpacetimeDB.connection_error.connect(_on_spacetimedb_connection_error)
	SpacetimeDB.identity_received.connect(_on_spacetimedb_identity_received)

func _on_spacetimedb_connected():
	print("Game: Connected to SpacetimeDB!")
	
func subsribe_self_updates():
	var id = SpacetimeDB.get_local_identity().identity.duplicate()
	id.reverse()
	var query_string = [
		"SELECT * FROM user WHERE identity == '0x%s'" % id.hex_encode()
		]
	var sub_req_id = SpacetimeDB.subscribe(query_string)
	if sub_req_id < 0:
		printerr("Game: Failed to send subscription request.")
	else:
		print("Game: Subscription request sent (Req ID: %d)." % sub_req_id)
	pass;
	
func _on_spacetimedb_disconnected():
	print("Game: Disconnected from SpacetimeDB.")

func _on_spacetimedb_connection_error(code, reason):
	printerr("Game: SpacetimeDB Connection Error: ", reason, " Code: ", code)

func _on_spacetimedb_identity_received(identity_token: IdentityTokenData):
	print("Game: My Identity: 0x", identity_token.identity.hex_encode())
	subsribe_self_updates()

func _on_spacetimedb_database_initialized():
	print("Game: Local database initialized.")
