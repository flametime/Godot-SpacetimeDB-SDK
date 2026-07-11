extends Control

@onready var header_row: TableRowUI = $VBoxContainer/ScrollContainer/TableContainer/HeaderRow
@onready var table_container: VBoxContainer = $VBoxContainer/ScrollContainer/TableContainer
@export var row_receiver: RowReceiver
@export var row_nodes:Dictionary[Variant, TableRowUI]
const TABLE_ROW_UI = preload("uid://dp3rr1360qvna")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not row_receiver:
		return
	if row_receiver.selected_table_name.is_empty():
		return
	header_row.create_header_row(row_receiver.table_to_receive)
	row_receiver.insert.connect(row_insert)
	row_receiver.update.connect(row_update)
	row_receiver.delete.connect(row_delete)
	SpacetimeDB.Main.connected.connect(_on_spacetimedb_connected)

func _on_spacetimedb_connected(_identity: PackedByteArray, _token: String) -> void:
	var query_string := [
		"SELECT * FROM %s" % row_receiver.selected_table_name
	]
	var sub := SpacetimeDB.Main.subscribe(query_string)
	if sub.error:
		printerr("Game: Failed to send subscription request.")
		return

	sub.applied.connect(func() -> void: print("subsciption '%s' applied" % query_string))
	print("Game: Subscription request '%s' sent (Query ID: %d)." % [query_string, sub.query_id])

func row_insert(new_row:_ModuleTableType) -> void:
	var row_ui:TableRowUI = TABLE_ROW_UI.instantiate()
	row_ui.create_row(new_row)
	table_container.add_child(row_ui)
	var key :String = new_row["primary_key"]
	if not key.is_empty():
		row_nodes[new_row[key]] = row_ui
	else:
		printerr("UI row insert skipped for table: %s" % row_receiver.selected_table_name)

func row_update(prev_row: _ModuleTableType, new_row: _ModuleTableType) -> void:
	var pk :String = new_row["primary_key"]
	var row_ui: TableRowUI = row_nodes.get(new_row[pk])
	if row_ui:
		row_ui.update_row(new_row)
	else:
		printerr("UI row update skipped for table: %s" % row_receiver.selected_table_name)
	pass


func row_delete(old_row:_ModuleTableType) -> void:
	var key :String = old_row["primary_key"]
	if not key.is_empty():
		var row_ui: TableRowUI = row_nodes.get(old_row[key])
		if row_ui:
			row_nodes.erase(old_row[key])
			row_ui.queue_free()
		else:
			printerr("UI row delete skipped for table: %s" % row_receiver.selected_table_name)
	else:
		for row_ui :TableRowUI in table_container.get_children():
			var is_same_row:bool = true
			for property: String in row_ui.get_exported_variable_names(row_ui.row):
				if old_row.get(property) != row_ui.row.get(property):
					is_same_row = false
					break
			if is_same_row:
				row_ui.queue_free()
