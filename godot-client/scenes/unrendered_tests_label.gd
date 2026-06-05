extends RichTextLabel

@onready var receiver__main_test_table_datatypes_: RowReceiver = $"Receiver [MainTestTableDatatypes]"
var new_tx: bool = true
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SpacetimeDB.Main.connected.connect(_on_spacetimedb_connected) # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_spacetimedb_connected(identity: PackedByteArray, _token: String) -> void:
	append_text("connected to the db")
	var query_string := [
		"SELECT * FROM %s" % receiver__main_test_table_datatypes_.selected_table_name
	]
	var sub := SpacetimeDB.Main.subscribe(query_string)
	if sub.error:
		printerr("Game: Failed to send subscription request.")
		return

	sub.applied.connect(func() -> void: print("subsciption '%s' applied" % query_string))
	print("Game: Subscription request '%s' sent (Query ID: %d)." % [query_string, sub.query_id])


func _on_receiver_main_test_table_datatypes_transactions_completed() -> void:
	#clear()
	add_text("transaction finished\n") # Replace with function body.
	prints("transaction finished:", Time.get_ticks_usec())
	new_tx = true

func _on_receiver_main_test_table_datatypes_insert(_row: _ModuleTableType) -> void:
	#if new_tx:
		#new_tx = false
		#clear()
	#add_text("row inserted\n") # Replace with function body.
	pass


func _on_receiver_main_test_table_datatypes_update(_prev: _ModuleTableType, _row: _ModuleTableType) -> void:
	#if new_tx:
		#new_tx = false
		#clear()
	#add_text("row updated\n") # Replace with function body.
	pass

func _on_receiver_main_test_table_datatypes_delete(_row: _ModuleTableType) -> void:
	#if new_tx:
		#new_tx = false
		#clear()
	#add_text("row deleted\n") # Replace with function body.
	pass
