#@tool
class_name SpacetimeDBConnection extends Node

var _websocket := WebSocketPeer.new()
var _target_url: String
var _token: String
var _is_connected: bool = false
var _connection_requested: bool = false
var _debug_mode: bool = false
var version: String = "v1"
# Protocol constants
const BSATN_PROTOCOL = "v2.bsatn.spacetimedb"

enum CompressionPreference { NONE = 0, BROTLI = 1, GZIP = 2 }
var preferred_compression: CompressionPreference = CompressionPreference.NONE # Default to None

var _total_bytes_send := 0
var _second_bytes_send := 0
var _total_bytes_received := 0
var _second_bytes_received := 0

var _total_messages_send := 0
var _second_messages_send := 0
var _total_messages_received := 0
var _second_messages_received := 0

signal connected
signal disconnected
signal connection_error(code: int, reason: String)
signal message_received(data: PackedByteArray)
signal total_messages(sent: int, received: int)
signal total_bytes(sent: int, received: int)


func _init(options: SpacetimeDBConnectionOptions,db_name:String):
	if options.monitor_mode:
		Performance.add_custom_monitor("spacetime/"+db_name+"_second_received_packets", get_second_received_packets)
		Performance.add_custom_monitor("spacetime/"+db_name+"_second_received_bytes", get_second_received_bytes)
		Performance.add_custom_monitor("spacetime/"+db_name+"_total_received_packets", get_received_packets)
		Performance.add_custom_monitor("spacetime/"+db_name+"_total_received_kbytes", get_received_kbytes)
		Performance.add_custom_monitor("spacetime/"+db_name+"_second_sent_packets", get_second_sent_packets)
		Performance.add_custom_monitor("spacetime/"+db_name+"_second_sent_bytes", get_second_sent_bytes)
		Performance.add_custom_monitor("spacetime/"+db_name+"_total_sent_packets", get_sent_packets)
		Performance.add_custom_monitor("spacetime/"+db_name+"_total_sent_kbytes", get_sent_kbytes)

	_websocket.inbound_buffer_size = options.inbound_buffer_size
	_websocket.outbound_buffer_size = options.outbound_buffer_size
	set_compression_preference(options.compression)
	self._debug_mode = options.debug_mode
	set_physics_process(false) # Don't process until connect is called

func _print_log(log_message:String):
	if _debug_mode:
		print(log_message)

func get_second_sent_bytes():
	var amount = _second_bytes_send
	_second_bytes_send = 0
	return amount

func get_second_received_bytes():
	var amount = _second_bytes_received
	_second_bytes_received = 0
	return amount

func get_second_sent_packets():
	var amount = _second_messages_send
	_second_messages_send = 0
	return amount

func get_second_received_packets():
	var amount = _second_messages_received
	_second_messages_received = 0
	return amount

func get_sent_kbytes() -> float:
	return float(float(_total_bytes_send)/1000.0)

func get_received_kbytes() -> float:
	return float(float(_total_bytes_received)/1000.0)

func get_sent_packets():
	return _total_messages_send

func get_received_packets():
	return _total_messages_received

func set_token(token: String):
	self._token = token

func set_compression_preference(preference: CompressionPreference):
	self.preferred_compression = preference

func send_bytes(bytes: PackedByteArray) -> Error:
	var err := _websocket.send(bytes)
	if err == OK:
		_second_bytes_send += bytes.size()
		_total_bytes_send += bytes.size()
		_second_messages_send += 1
		_total_messages_send += 1
		total_messages.emit(_total_messages_send, _total_messages_received)
		total_bytes.emit(_total_bytes_send, _total_bytes_received)
	return err

func connect_to_database(base_url: String, database_name: String, connection_id: String, confirmed_reads:bool): # Added connection_id
	if _is_connected or _connection_requested:
		_print_log("SpacetimeDBConnection: Already connected or connecting.")
		return

	if _token.is_empty():
		_print_log("SpacetimeDBConnection: Cannot connect without auth token.")
		return

	if connection_id.is_empty():
		printerr("SpacetimeDBConnection: Cannot connect without Connection ID.")
		return

	# Construct WebSocket URL base
	var ws_url_base := base_url.replace("http", "ws").replace("https", "wss")
	ws_url_base = ws_url_base.path_join("/"+version+"/database").path_join(database_name).path_join("subscribe")

	# --- Add Query Parameters ---
	# Start with connection_id
	var query_params := "?connection_id=" + connection_id
	# Add compression preference
	# Convert enum value to string for the URL parameter
	var compression_str : String

	match preferred_compression:
		CompressionPreference.NONE: compression_str = "None" # Use string "None" as seen in C# enum
		CompressionPreference.BROTLI: compression_str = "Brotli"
		CompressionPreference.GZIP: compression_str = "Gzip"
		_: compression_str = "None" # Fallback


	query_params += "&compression=" + compression_str
	query_params += "&confirmed=%s" % confirmed_reads

	if OS.get_name() == "Web":
		query_params += "&token=" + _token
	else:
		var auth_header := "Authorization: Bearer " + _token
		_websocket.handshake_headers = [auth_header]

	_target_url = ws_url_base + query_params
	_print_log("SpacetimeDBConnection: Attempting to connect to: " + _target_url)

	_websocket.supported_protocols = [BSATN_PROTOCOL]

	var err := _websocket.connect_to_url(_target_url)
	if err != OK:
		printerr("SpacetimeDBConnection: Error initiating connection: ", err)
		emit_signal("connection_error", err, "Failed to initiate connection")
	else:
		_print_log("SpacetimeDBConnection: Connection initiated.")
		_connection_requested = true
		set_physics_process(true)

func disconnect_from_server(code: int = 1000, reason: String = "Client initiated disconnect"):
	if _websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED and _websocket.get_ready_state() != WebSocketPeer.STATE_CLOSING:
		_print_log("SpacetimeDBConnection: Closing connection...")
		_websocket.close(code, reason)
		get_tree().auto_accept_quit = false

func is_connected_db() -> bool:
	return _is_connected

func _physics_process(delta: float) -> void:
	if _websocket == null: return

	_websocket.poll()
	var state := _websocket.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _is_connected:
				_print_log("SpacetimeDBConnection: Connection established.")
				_is_connected = true
				_connection_requested = false
				connected.emit()

			# Process incoming packets
			while _websocket.get_available_packet_count() > 0:
				var packet_bytes := _websocket.get_packet()
				if packet_bytes.is_empty(): continue

				_total_bytes_received += packet_bytes.size()
				_second_bytes_received += packet_bytes.size()
				_total_messages_received += 1
				_second_messages_received += 1

				message_received.emit(packet_bytes)
				total_messages.emit(_total_messages_send, _total_messages_received)
				total_bytes.emit(_total_bytes_send, _total_bytes_received)

		WebSocketPeer.STATE_CONNECTING:
			# Still trying to connect
			pass

		WebSocketPeer.STATE_CLOSING:
			# Connection is closing
			_print_log("SpacetimeDBConnection: connection closing")
			pass

		WebSocketPeer.STATE_CLOSED:
			var code := _websocket.get_close_code()
			var reason := _websocket.get_close_reason()
			if _is_connected or _connection_requested: # Only report if we were connected or trying
				if code == -1: # Abnormal closure
					printerr("SpacetimeDBConnection: connection_error ", code, " Abnormal closure with reason:")
					emit_signal("connection_error", code, "Abnormal closure")
					emit_signal("disconnected")
				else:
					_print_log("SpacetimeDBConnection: Connection closed (Code: %d, Reason: %s)" % [code, reason])
					emit_signal("disconnected") # Normal closure signal
			_is_connected = false
			_connection_requested = false
			get_tree().auto_accept_quit = true
			set_physics_process(false) # Stop polling


func _handle_game_closing():
	disconnect_from_server()
	if _websocket.get_ready_state() == WebSocketPeer.STATE_CLOSING:
		_print_log("SpacetimeDBConnection: WS closing")
		if is_connected_db():
			await disconnected
	_print_log("game closed")
	get_tree().quit()

func _exit_tree() -> void:
	_print_log("SpacetimeDBConnection: Exit Tree")
	_handle_game_closing()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_CRASH:
			printerr("the game crashed")
			if _websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
				_handle_game_closing()
		NOTIFICATION_WM_CLOSE_REQUEST:
			print("WM_CLOSE_REQUEST")
			if _websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
				_handle_game_closing()
