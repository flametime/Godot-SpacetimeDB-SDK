class_name SpacetimeDBClient extends Node

# --- Configuration ---
@export var base_url: String = "http://127.0.0.1:3000"
@export var database_name: String = "quickstart-chat" # Example
@export var schema_path: String = "res://spacetime_data/schema/"
@export var auto_connect: bool = false
@export var auto_request_token: bool = true
@export var token_save_path: String = "user://spacetimedb_token.dat" # Use a more specific name
@export var one_time_token:bool = false
@export var compression:SpacetimeDBConnection.CompressionPreference;
@export var debug_mode:bool = true;
@export var current_subscriptions:Dictionary[int, PackedStringArray]

var connection_options: SpacetimeDBConnectionOptions
var pending_subscriptions:Dictionary[int, PackedStringArray]

# --- Components ---
var _connection: SpacetimeDBConnection
var _deserializer: BSATNDeserializer
var _serializer: BSATNSerializer
var _local_db: LocalDatabase
var _rest_api: SpacetimeDBRestAPI # Optional, for token/REST calls
var _local_identity:IdentityTokenData
# --- State ---
var _token: String
var _is_initialized := false

# --- Signals ---
# Re-emit signals from components for easier use
signal connected
signal disconnected
signal connection_error(code: int, reason: String)
signal identity_received(identity_token: IdentityTokenData)
signal database_initialized # Emitted after InitialSubscription is processed
signal database_updated(table_update: TableUpdateData) # Emitted for each table update
signal row_inserted(table_name: String, row: Resource) # From LocalDatabase
signal row_updated(table_name: String, previous: Resource, row: Resource) # From LocalDatabase
signal row_deleted(table_name: String, row: Resource)
signal row_deleted_key(table_name: String, primary_key) # From LocalDatabase
signal reducer_call_response(response: Resource) # TODO: Define response resource
signal reducer_call_timeout(request_id: int) # TODO: Implement timeout logic
signal transaction_update_received(update: TransactionUpdateData)

func _ready():
	# Defer initialization until explicitly called or via auto_connect
	if auto_connect:
		initialize_and_connect()

func print_log(log_message:String):
	if debug_mode:
		print(log_message)
	pass;
	
func initialize_and_connect():
	if _is_initialized: return

	print_log("SpacetimeDBClient: Initializing...")

	# 1. Initialize Parser
	_deserializer = BSATNDeserializer.new(schema_path, debug_mode)
	_serializer = BSATNSerializer.new()

	# 2. Initialize Local Database
	_local_db = LocalDatabase.new(_deserializer._possible_row_schemas) # Pass loaded schemas
	# Connect to LocalDatabase signals to re-emit them
	_local_db.row_inserted.connect(func(tn, r) -> void: row_inserted.emit(tn, r))
	_local_db.row_updated.connect(func(tn, p, r) -> void: row_updated.emit(tn, p, r))
	_local_db.row_deleted.connect(func(tn, r) -> void: row_deleted.emit(tn, r))
	_local_db.row_deleted_key.connect(func(tn, pk) -> void: row_deleted_key.emit(tn, pk))
	add_child(_local_db) # Add as child if it needs signals

	# 3. Initialize REST API Handler (optional, mainly for token)
	_rest_api = SpacetimeDBRestAPI.new(base_url, debug_mode)
	_rest_api.token_received.connect(_on_token_received)
	_rest_api.token_request_failed.connect(_on_token_request_failed)
	# Connect other REST signals if needed
	add_child(_rest_api)

	# 4. Initialize Connection Handler
	_connection = SpacetimeDBConnection.new(connection_options)
	_connection.connected.connect(func(): connected.emit())
	_connection.disconnected.connect(func(): disconnected.emit())
	_connection.connection_error.connect(func(c, r): connection_error.emit(c, r))
	_connection.message_received.connect(_on_websocket_message_received)
	add_child(_connection)

	_is_initialized = true
	print_log("SpacetimeDBClient: Initialization complete.")

	# 5. Get Token and Connect
	_load_token_or_request()

func _load_token_or_request():
	if one_time_token == false:
	# Try loading saved token
		if FileAccess.file_exists(token_save_path):
			var file := FileAccess.open(token_save_path, FileAccess.READ)
			if file:
				var saved_token := file.get_as_text().strip_edges()
				file.close()
				if not saved_token.is_empty():
					print_log("SpacetimeDBClient: Using saved token.")
					_on_token_received(saved_token) # Directly use the saved token
					return

	# If no valid saved token, request a new one if auto-request is enabled
	if auto_request_token:
		print_log("SpacetimeDBClient: No valid saved token found, requesting new one.")
		_rest_api.request_new_token()
	else:
		printerr("SpacetimeDBClient: No token available and auto_request_token is false.")
		emit_signal("connection_error", -1, "Authentication token unavailable")

func _generate_connection_id() -> String:
	var random_bytes := PackedByteArray()
	random_bytes.resize(16)
	var rng := RandomNumberGenerator.new()
	for i in 16:
		random_bytes[i] = rng.randi_range(0, 255)
	return random_bytes.hex_encode() # Return as hex string
	
func _on_token_received(received_token: String):
	print_log("SpacetimeDBClient: Token acquired.")
	self._token = received_token
	_save_token(received_token)
	var conn_id = _generate_connection_id()
	# Pass token to components that need it
	_connection.set_token(self._token)
	_rest_api.set_token(self._token) # REST API might also need it

	# Now attempt to connect WebSocket
	_connection.connect_to_database(base_url, database_name, conn_id)

func _on_token_request_failed(error_code: int, response_body: String):
	printerr("SpacetimeDBClient: Failed to acquire token. Cannot connect.")
	emit_signal("connection_error", error_code, "Failed to acquire authentication token")

func _save_token(token_to_save: String):
	var file := FileAccess.open(token_save_path, FileAccess.WRITE)
	if file:
		file.store_string(token_to_save)
		file.close()
	else:
		printerr("SpacetimeDBClient: Failed to save token to path: ", token_save_path)


# --- WebSocket Message Handling ---

func _on_websocket_message_received(bsatn_bytes: PackedByteArray):
	if not _deserializer: return # Should not happen if initialized

	var message_resource: Resource = _deserializer.parse_packet(bsatn_bytes)
	
	if _deserializer.has_error():
		printerr("SpacetimeDBClient: Failed to parse BSATN packet: ", _deserializer.get_last_error())
		return

	if message_resource == null:
		# Parsing might have returned null without setting error (e.g., unknown type)
		# Parser should ideally always set an error in this case.
		printerr("SpacetimeDBClient: Parser returned null message resource.")
		return
	# Handle known message types
	if message_resource is InitialSubscriptionData:
		var initial_sub: InitialSubscriptionData = message_resource
		print_log("SpacetimeDBClient: Processing Initial Subscription (Req ID: %d)" % initial_sub.request_id)
		_local_db.apply_database_update(initial_sub.database_update)
		emit_signal("database_initialized")
		
	elif message_resource is SubscribeMultiAppliedData:
		var initial_sub: SubscribeMultiAppliedData = message_resource
		print_log("SpacetimeDBClient: Processing Initial Subscription (Req ID: %d)" % initial_sub.request_id)
		_local_db.apply_database_update(initial_sub.database_update)
		if pending_subscriptions.has(initial_sub.query_id.id):
			current_subscriptions[initial_sub.query_id.id] = pending_subscriptions[initial_sub.query_id.id]
			pending_subscriptions.erase(initial_sub.query_id.id)
		emit_signal("database_initialized")
		
	elif message_resource is UnsubscribeMultiAppliedData:
		var unsub: UnsubscribeMultiAppliedData = message_resource
		_local_db.apply_database_update(unsub.database_update)
		print_log("Unsubscribe: " + str(current_subscriptions[unsub.query_id.id]))
		if current_subscriptions.has(unsub.query_id.id):
			current_subscriptions.erase(unsub.query_id.id)
		
	elif message_resource is IdentityTokenData:
		var identity_token: IdentityTokenData = message_resource
		print_log("SpacetimeDBClient: Received Identity Token.")
		_local_identity = identity_token
		emit_signal("identity_received", identity_token)

	elif message_resource is TransactionUpdateData: 
		var tx_update: TransactionUpdateData = message_resource
		#print_log("SpacetimeDBClient: Processing Transaction Update (Reducer: %s, Req ID: %d)" % [tx_update.reducer_call.reducer_name, tx_update.reducer_call.request_id])
		# Apply changes to local DB only if committed
		if tx_update.status.status_type == UpdateStatusData.StatusType.COMMITTED:
			if tx_update.status.committed_update: # Check if update data exists
				_local_db.apply_database_update(tx_update.status.committed_update)
			else:
				# This might happen if a transaction committed but affected 0 rows relevant to the client
				print_log("SpacetimeDBClient: Committed transaction had no relevant row updates.")
		elif tx_update.status.status_type == UpdateStatusData.StatusType.FAILED:
			printerr("SpacetimeDBClient: Reducer call failed: ", tx_update.status.failure_message)
		elif tx_update.status.status_type == UpdateStatusData.StatusType.OUT_OF_ENERGY:
			printerr("SpacetimeDBClient: Reducer call ran out of energy.")

		# Emit the full transaction update signal regardless of status
		emit_signal("transaction_update_received", tx_update)

	else:
		print_log("SpacetimeDBClient: Received unhandled message resource type: " + message_resource.get_class())


# --- Public API ---

func connect_db(host_url:String, database_name:String, options: SpacetimeDBConnectionOptions = null):
	if not options:
		options = SpacetimeDBConnectionOptions.new()
	connection_options = options
	self.base_url = host_url;
	self.database_name = database_name;
	self.compression = options.compression
	self.one_time_token = options.one_time_token
	self.debug_mode = options.debug_mode
	self.schema_path = options.schema_path
	if not _is_initialized:
		initialize_and_connect()
	elif not _connection.is_connected_db():
		# Already initialized, just need token and connect
		_load_token_or_request()

func disconnect_db():
	if _connection:
		_connection.disconnect_from_server()

func is_connected_db() -> bool:
	return _connection and _connection.is_connected_db()

# Gets the local database instance for querying
func get_local_database() -> LocalDatabase:
	return _local_db
	
func get_local_identity() -> IdentityTokenData:
	return _local_identity
	
func subscribe(queries: PackedStringArray) -> int:
	if not is_connected_db():
		printerr("SpacetimeDBClient: Cannot subscribe_bin, not connected.")
		return -1 # Indicate error

	# 1. Generate a request ID
	var request_id := randi() & 0xFFFFFFFF # Ensure positive u32 range
	# 2. Create the correct payload Resource
	var payload_data := SubscribeMultiData.new(queries, request_id)
	
	#print("! ",payload_data.query_id.id)

	# 3. Serialize the complete ClientMessage using the universal function
	var message_bytes := _serializer.serialize_client_message(
		BSATNSerializer.CLIENT_MSG_VARIANT_TAG_SUBSCRIBE_MULTI,
		payload_data 
	)

	if _serializer.has_error():
		printerr("SpacetimeDBClient: Failed to serialize SubscribeMulti message: %s" % _serializer.get_last_error())
		return -1

	# 4. Send the binary message via WebSocket
	if _connection and _connection._websocket:
		var err := _connection.send_bytes(message_bytes)
		if err != OK:
			printerr("SpacetimeDBClient: Error sending SubscribeMulti BSATN message: %s" % error_string(err))
			return -1 # Indicate error
		else:
			print_log("SpacetimeDBClient: SubscribeMulti request sent successfully (BSATN), Req ID: %d" % request_id)
			pending_subscriptions[request_id] = queries
			return request_id # Return the ID on success
	else:
		printerr("SpacetimeDBClient: Internal error - WebSocket peer not available in connection.")
		return -1

#WARNING Doesnt work for now
func unsubscribe(id:int) -> bool:
	if not is_connected_db():
		printerr("SpacetimeDBClient: Cannot subscribe_bin, not connected.")
		return false # Indicate error
		
	
	var payload_data := UnsubscribeMultiData.new(id)
	
	var message_bytes := _serializer.serialize_client_message(
		BSATNSerializer.CLIENT_MSG_VARIANT_TAG_UNSUBSCRIBE_MULTI,
		payload_data 
	)

	if _serializer.has_error():
		printerr("SpacetimeDBClient: Failed to serialize SubscribeMulti message: %s" % _serializer.get_last_error())
		return false

	# 4. Send the binary message via WebSocket
	if _connection and _connection._websocket:
		var err := _connection.send_bytes(message_bytes)
		if err != OK:
			printerr("SpacetimeDBClient: Error sending SubscribeMulti BSATN message: %s" % error_string(err))
			return false # Indicate error
		else:
			print_log("SpacetimeDBClient: UnsubscribeMulti request sent successfully (BSATN), Req ID: %d" % id)
			#current_subscriptions.erase(id)
			return true # Return the ID on success
	else:
		printerr("SpacetimeDBClient: Internal error - WebSocket peer not available in connection.")
		return false
	pass
	
func call_reducer(reducer_name: String, args: Array = [], types: Array = []) -> int:
	if not is_connected_db():
		#print_logerr("SpacetimeDBClient: Cannot call reducer, not connected.")
		return -1 # Indicate error
		
	# Generate a request ID (ensure it's u32 range if needed, but randi is fine for now)
	var request_id := randi() & 0xFFFFFFFF # Ensure positive u32 range
	
	var args_bytes = _serializer._serialize_arguments(args, types)

	if _serializer.has_error():
		printerr("Failed to serialize args for %s: %s" % [reducer_name, _serializer.get_last_error()])
		return -1
	
	var call_data := CallReducerData.new(reducer_name, args_bytes, request_id, 0)
	var message_bytes = _serializer.serialize_client_message(
		BSATNSerializer.CLIENT_MSG_VARIANT_TAG_CALL_REDUCER,
		call_data
		)
	
	# Access the internal _websocket peer directly (might need adjustment if _connection API changes)
	if _connection and _connection._websocket: # Basic check
		var err = _connection.send_bytes(message_bytes)
		if err != OK:
			print("SpacetimeDBClient: Error sending CallReducer JSON message: ", err)
			return -1 # Indicate error
		else:
			return request_id
	else:
		print("SpacetimeDBClient: Internal error - WebSocket peer not available in connection.")
		return -1

func wait_for_reducer_response(request_id_to_match: int, timeout_seconds: float = 10.0) -> TransactionUpdateData:
	if request_id_to_match < 0:
		return null

	var signal_result: TransactionUpdateData = null
	var timeout_ms: float = timeout_seconds * 1000.0
	var start_time: float = Time.get_ticks_msec()

	while Time.get_ticks_msec() - start_time < timeout_ms:
		var received_signal = await transaction_update_received
		if _check_reducer_response(received_signal, request_id_to_match):
			signal_result = received_signal
			break

	if signal_result == null:
		printerr("SpacetimeDBClient: Timeout waiting for response for Req ID: %d" % request_id_to_match)
		reducer_call_timeout.emit(request_id_to_match)
		return null
	else:
		var tx_update: TransactionUpdateData = signal_result
		print_log("SpacetimeDBClient: Received matching response for Req ID: %d" % request_id_to_match)
		reducer_call_response.emit(tx_update.reducer_call)
		return tx_update

func _check_reducer_response(update: TransactionUpdateData, request_id_to_match: int) -> bool:
	return update != null and update.reducer_call != null and update.reducer_call.request_id == request_id_to_match
