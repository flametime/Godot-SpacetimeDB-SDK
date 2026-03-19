extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var options :SpacetimeDBConnectionOptions = SpacetimeDBConnectionOptions.new()
	options.one_time_token = true # <--- anonymous-like. set to false to persist
	options.debug_mode = false # <--- enables lots of additional debug prints and warnings
	options.compression = SpacetimeDBConnection.CompressionPreference.GZIP
	options.threading = false
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
	#var id := SpacetimeDB.Main.get_local_identity()
	var query_string := [
		"SELECT * FROM user"
	]
	var sub := SpacetimeDB.Main.subscribe(query_string)
	sub.applied.connect(func() -> void:
		print("User Subscription Applied")
		await get_tree().create_timer(3).timeout
		sub.unsubscribe()
		)
	sub.end.connect(func() -> void:
		print("User Subscription ended")
		var osub := SpacetimeDB.Main.one_off_query("SELECT * FROM user_data", func(ctx: OneOffQueryResponseMessage)->void: print("OneOffQuery callback: %s" % str(ctx.result_ok)),true)
		if not osub == OK:
			pass
		)
	if sub.error:
		printerr("Game: Failed to send subscription request.")
		return
	#print("Game: Subscription request sent (Query ID: %d)." % sub.query_id)

func _on_spacetimedb_disconnected() -> void:
	print("Game: Disconnected from SpacetimeDB.")

func _on_spacetimedb_connection_error(code: int, reason: String) -> void:
	printerr("Game: SpacetimeDB Connection Error: ", reason, " Code: ", code)

func _on_spacetimedb_database_init() -> void:
	print("Game: Database initialised")


func _on_button_pressed() -> void:
	var call1 : SpacetimeDBReducerCall = SpacetimeDB.Main.reducers.start_integration_tests()
	call1.on_ok.connect(func(update:ReducerResultMessage) -> void: print("Reducer call1 returned Ok with %s" % update))
	var time := Time.get_ticks_usec()
	await call1.response
	prints("call1 response took:",Time.get_ticks_usec() - time, "usec")
	var main_test_type: MainTestType = MainTestType.create("hello world",8,MainTestNestedEnum.create_ok_empty())
	var main_test_type_Option: Option = Option.some(main_test_type)
	var u128 := [8]
	u128.resize(16)
	var main_test_datatypes: MainTestTableDatatypes = MainTestTableDatatypes.create(64,8,16,32,PackedByteArray(u128),32.0,64.0,8,16,32,64,"hello world",["hello world","hello world2"],[8,8],Option.some("hello world"),Option.some(64),SpacetimeDB.Main.Types.TestEnum.A,[SpacetimeDB.Main.Types.TestEnum.A],Option.some(SpacetimeDB.Main.Types.TestEnum.A),main_test_type,[main_test_type],main_test_type_Option )

	var call2 : SpacetimeDBReducerCall = SpacetimeDB.Main.reducers.reducer_test_parameters(main_test_datatypes, 32,64,"hello world",SpacetimeDB.Main.Types.TestEnum.A,MainTestNestedEnum.create_ok_empty(),[32,32])
	call2.on_ok.connect(func(update: ReducerResultMessage) -> void: print("Reducer call2 returned Ok with %s" % update))
	call2.on_error.connect(func(err: String) -> void: print("Reducer call2 returned err with %s" % err))
	var time2 := Time.get_ticks_usec()
	await call2.response
	prints("call2 response took:",Time.get_ticks_usec() - time2, "usec")
	SpacetimeDB.Main.reducers.trigger_event()
	var procedure_call := SpacetimeDB.Main.procedures.procedure_test_type_return(1)
	procedure_call.response.connect(func(response: ProcedureResultMessage)-> void: prints("procedure response",response))

func _on_button_2_pressed() -> void:
	SpacetimeDB.Main.reducers.clear_integration_tests() # Replace with function body.
