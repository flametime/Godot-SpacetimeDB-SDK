class_name BSATNDeserializer extends RefCounted

# --- Constants ---
const MAX_STRING_LEN := 4 * 1024 * 1024 # 4 MiB limit for strings
const MAX_VEC_LEN := 131072            # Limit for vector elements (used by read_vec_u8 and _read_array)
const MAX_BYTE_ARRAY_LEN := 16 * 1024 * 1024 # Limit for Vec<u8> style byte arrays
const IDENTITY_SIZE := 32
const CONNECTION_ID_SIZE := 16
const U128_SIZE := 16

const COMPRESSION_NONE := 0x00
const COMPRESSION_BROTLI := 0x01
const COMPRESSION_GZIP := 0x02

# Row List Format Tags
const ROW_LIST_FIXED_SIZE := 0
const ROW_LIST_ROW_OFFSETS := 1

# Native type handling
const NATIVE_ARRAYLIKE := [
	"Vector2",
	"Vector2i",
	"Vector3",
	"Vector3i",
	"Vector4",
	"Vector4i",
	"Quaternion",
	"Color"
]

# --- Properties ---
var _last_error: String = ""
var _deserialization_plan_cache: Dictionary = {}
var _schema: SpacetimeDBSchema
var _client: SpacetimeDBClient

var debug_mode := false # Controls verbose debug printing

# --- Initialization ---
func _init(p_schema: SpacetimeDBSchema, p_client: SpacetimeDBClient, p_debug_mode: bool = false) -> void:
	debug_mode = p_debug_mode
	_schema = p_schema
	_client = p_client


#region --- Error Handling ---
func print_log(...text):
	if debug_mode:
		prints(", ".join(text))

func has_error() -> bool: return _last_error != ""
func get_last_error() -> String: var err := _last_error; _last_error = ""; return err
func clear_error() -> void: _last_error = ""
func _set_error(msg: String, position: int = -1) -> void:
	if _last_error == "": # Prevent overwriting the first error
		var pos_str := " (at approx. position %d)" % position if position >= 0 else ""
		_last_error = "BSATNDeserializer Error: %s%s" % [msg, pos_str]
		printerr(_last_error) # Always print errors
func _check_read(spb: StreamPeerBuffer, bytes_needed: int) -> bool:
	if has_error(): return false
	if spb.get_position() + bytes_needed > spb.get_size():
		_set_error("Attempted to read %d bytes past end of buffer (size: %d)." % [bytes_needed, spb.get_size()], spb.get_position())
		return false
	return true
#endregion

#region --- Primitive Value Readers ---
# These directly read basic types from the internal StreamPeerBuffer.

func read_i8(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 1): return 0
	return spb.get_8()

func read_i16_le(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 2): return 0
	spb.big_endian = false
	return spb.get_16()

func read_i32_le(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 4): return 0
	spb.big_endian = false
	return spb.get_32()

func read_i64_le(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 8): return 0
	spb.big_endian = false
	return spb.get_64()

func read_u8(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 1): return 0
	return spb.get_u8()

func read_u16_le(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 2): return 0
	spb.big_endian = false
	return spb.get_u16()

func read_u32_le(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 4): return 0
	spb.big_endian = false
	return spb.get_u32()

func read_u64_le(spb: StreamPeerBuffer) -> int:
	if not _check_read(spb, 8): return 0
	spb.big_endian = false
	return spb.get_u64()

func read_u128(spb: StreamPeerBuffer) -> PackedByteArray:
	var num := read_bytes(spb, U128_SIZE)
	num.reverse() # We receive the bytes in reverse
	return num

func read_f32_le(spb: StreamPeerBuffer) -> float:
	if not _check_read(spb, 4): return 0.0
	spb.big_endian = false
	return spb.get_float()

func read_f64_le(spb: StreamPeerBuffer) -> float:
	if not _check_read(spb, 8): return 0.0
	spb.big_endian = false
	return spb.get_double()

func read_bool(spb: StreamPeerBuffer) -> bool:
	var byte := read_u8(spb)
	if has_error(): return false
	if byte != 0 and byte != 1:
		_set_error("Invalid boolean value: %d (expected 0 or 1)" % byte, spb.get_position() - 1)
		return false
	return byte == 1

func read_bytes(spb: StreamPeerBuffer, num_bytes: int) -> PackedByteArray:
	if num_bytes < 0:
		_set_error("Attempted to read negative bytes: %d" % num_bytes, spb.get_position())
		return PackedByteArray()
	if num_bytes == 0: return PackedByteArray()
	if not _check_read(spb, num_bytes): return PackedByteArray()
	var result: Array = spb.get_data(num_bytes)
	if result[0] != OK:
		_set_error("StreamPeerBuffer.get_data failed: %d" % result[0], spb.get_position() - num_bytes)
		return PackedByteArray()
	return result[1]

func read_string_with_u32_len(spb: StreamPeerBuffer) -> String:
	var start_pos := spb.get_position()
	var length := read_u32_le(spb)
	if has_error() or length == 0: return ""
	if length > MAX_STRING_LEN:
		_set_error("String length %d exceeds limit %d" % [length, MAX_STRING_LEN], start_pos)
		return ""
	var str_bytes := read_bytes(spb, length)
	if has_error(): return ""
	var str_result := str_bytes.get_string_from_utf8()
	# More robust check for UTF-8 decoding errors
	if str_result == "" and length > 0 and (str_bytes.get_string_from_ascii() == "" or str_bytes.find(0) != -1):
		_set_error("Failed to decode UTF-8 string length %d" % length, start_pos)
		return ""
	return str_result

func read_identity(spb: StreamPeerBuffer) -> PackedByteArray:
	var identity := read_bytes(spb, IDENTITY_SIZE)
	identity.reverse() # We receive the identity bytes in reverse
	return identity

func read_connection_id(spb: StreamPeerBuffer) -> PackedByteArray:
	return read_bytes(spb, CONNECTION_ID_SIZE)

func read_timestamp(spb: StreamPeerBuffer) -> int:
	return read_i64_le(spb) # Timestamps are i64

func read_scheduled_at(spb: StreamPeerBuffer) -> int:
	read_i8(spb) # skipping the scheduled_at enum int
	return read_timestamp(spb)

func read_query_id_data(spb: StreamPeerBuffer):
	var query_id_data := QueryIdData.new()
	query_id_data.id = read_u32_le(spb)
	return query_id_data

func read_vec_u8(spb: StreamPeerBuffer) -> PackedByteArray:
	var start_pos := spb.get_position()
	var length := read_u32_le(spb)
	if has_error(): return PackedByteArray()
	if length > MAX_BYTE_ARRAY_LEN:
		_set_error("Vec<u8> length %d exceeds limit %d" % [length, MAX_BYTE_ARRAY_LEN], start_pos)
		return PackedByteArray()
	if length == 0: return PackedByteArray()
	return read_bytes(spb, length)
#endregion


#region --- Special Readers ---

### Reads an option property.
func _read_option(spb: StreamPeerBuffer, bsatn_type_str: StringName) -> Option:
	var option_instance := Option.new()
	# Wire format: u8 tag (0 for Some, 1 for None)
	# If Some (0): followed by T value
	var tag_pos := spb.get_position()
	var is_present_tag := read_u8(spb)
	if has_error(): return null # Error reading tag
	if is_present_tag == 1: # It's None
		option_instance.set_none()
		return option_instance
	elif is_present_tag == 0: # It's Some
		option_instance.set_some(_parse_generic_type(spb,bsatn_type_str))
		return option_instance
	else:
		_set_error("Invalid tag %d for Option bsatn_type '%s' (expected 0 for Some, 1 for None)." % [is_present_tag, bsatn_type_str])
		return null

func _read_result(spb:StreamPeerBuffer,bsatn_type_str:StringName) -> Variant:
	var type_strs:Array = bsatn_type_str.split("_")
	var tag := read_u8(spb)
	match tag:
		0: ## Result Ok type_strs[0]
			return _parse_generic_type(spb, type_strs[0])
		1: ## Result Err type_strs[1]
			return _parse_generic_type(spb, type_strs[1])
		_: ## unreachable
			_set_error("_read_result tag %s is not 0 or 1" % tag)
			return null
	return null

func _read_native_arraylike(spb: StreamPeerBuffer, bsatn_type: StringName) -> Variant:
	var bsatn_types_for_components: String = ""
	match bsatn_type:
		"Vector2": bsatn_types_for_components = "F32,F32"
		"Vector2i": bsatn_types_for_components = "I32,I32"
		"Vector3": bsatn_types_for_components = "F32,F32,F32"
		"Vector3i": bsatn_types_for_components = "I32,I32,I32"
		"Vector4": bsatn_types_for_components = "F32,F32,F32,F32"
		"Vector4i": bsatn_types_for_components = "I32,I32,I32,I32"
		"Quaternion": bsatn_types_for_components = "F32,F32,F32,F32"
		"Color": bsatn_types_for_components = "F32,F32,F32,F32"
		_:
			return null
	var components := []
	for bsatn_component_type_str in bsatn_types_for_components.split(","):
		var component_value = _parse_generic_type(spb, bsatn_component_type_str)
		if has_error():
			printerr("failed to read native_arraylike with error: %s" % get_last_error())
			clear_error()
			return null
		components.append(component_value)
	match bsatn_type:
		"Vector2": return Vector2.ZERO if has_error() else Vector2(components[0], components[1])
		"Vector2i": return Vector2i.ZERO if has_error() else Vector2i(components[0], components[1])
		"Vector3": return Vector3.ZERO if has_error() else Vector3(components[0], components[1], components[2])
		"Vector3i": return Vector3i.ZERO if has_error() else Vector3i(components[0], components[1], components[2])
		"Vector4": return Vector4.ZERO if has_error() else Vector4(components[0], components[1], components[2], components[3])
		"Vector4i": return Vector4i.ZERO if has_error() else Vector4i(components[0], components[1], components[2], components[3])
		"Quaternion": return Quaternion.IDENTITY if has_error() else Quaternion(components[0], components[1], components[2], components[3])
		"Color": return Color.BLACK if has_error() else Color(components[0], components[1], components[2], components[3])
	_set_error("Cannot determine native gd type for property '%s'" % bsatn_type)
	return null


# --- BsatnRowList Reader ---
func read_bsatn_row_list(spb: StreamPeerBuffer) -> Array[PackedByteArray]:
	var start_pos := spb.get_position()
	var size_hint_type := read_u8(spb)
	if has_error(): return []
	var rows: Array[PackedByteArray] = []
	match size_hint_type:
		ROW_LIST_FIXED_SIZE:
			var row_size := read_u16_le(spb);
			var data_len := read_u32_le(spb)
			if has_error(): return []
			if row_size == 0:
				if data_len != 0:
					_set_error("FixedSize row_size 0 but data_len %d" % data_len, start_pos);
					read_bytes(spb, data_len);
					return []
				return []
			var data := read_bytes(spb, data_len)
			if has_error(): return []
			if data_len % row_size != 0: _set_error("FixedSize data_len %d not divisible by row_size %d" % [data_len, row_size], start_pos); return []
			var num_rows := data_len / row_size
			rows.resize(num_rows)
			for i in range(num_rows):
				rows[i] = data.slice(i * row_size, (i + 1) * row_size)
		ROW_LIST_ROW_OFFSETS:
			var num_offsets := read_u32_le(spb)
			if has_error(): return []
			var offsets: Array[int] = []; offsets.resize(num_offsets)
			for i in range(num_offsets): offsets[i] = read_u64_le(spb); if has_error(): return []
			var data_len := read_u32_le(spb)
			if has_error(): return []
			var data := read_bytes(spb, data_len)
			if has_error(): return []
			rows.resize(num_offsets)
			for i in range(num_offsets):
				var start_offset : int = offsets[i]
				var end_offset : int = data_len if (i + 1 == num_offsets) else offsets[i+1]
				if start_offset < 0 or end_offset < start_offset or end_offset > data_len: _set_error("Invalid row offsets: start=%d, end=%d, data_len=%d row %d" % [start_offset, end_offset, data_len, i], start_pos); return []
				rows[i] = data.slice(start_offset, end_offset)
		_: _set_error("Unknown RowSizeHint type: %d" % size_hint_type, start_pos); return []
	return rows
#endregion


#region --- Core Deserialization Logic ---

# Helper to get a primitive reader Callable based on a BSATN type string.
func _get_primitive_reader_from_bsatn_type(bsatn_type_str: String) -> Callable:
	match bsatn_type_str:
		&"U64": return Callable(self, "read_u64_le")
		&"I64": return Callable(self, "read_i64_le")
		&"F64": return Callable(self, "read_f64_le")
		&"U32": return Callable(self, "read_u32_le")
		&"I32": return Callable(self, "read_i32_le")
		&"F32": return Callable(self, "read_f32_le")
		&"U16": return Callable(self, "read_u16_le")
		&"I16": return Callable(self, "read_i16_le")
		&"U8": return Callable(self, "read_u8")
		&"I8": return Callable(self, "read_i8")
		&"U128": return Callable(self, "read_u128")
		&"__identity__": return Callable(self, "read_identity")
		&"__connection_id__": return Callable(self, "read_connection_id")
		&"__timestamp_micros_since_unix_epoch__": return Callable(self, "read_timestamp")
		&"__time_duration_micros__": return Callable(self, "read_timestamp")
		&"scheduled_at": return Callable(self, "read_scheduled_at")
		&"Bool": return Callable(self, "read_bool")
		&"String": return Callable(self, "read_string_with_u32_len")
		&"SubscribeAppliedMessage": return Callable(self, "_read_subscripton_applied_message")
		&"UnsubscribeAppliedMessage": return Callable(self, "_read_unsubscription_applied_message")
		&"SubscriptionErrorMessage": return Callable(self, "_read_subscription_error_message")
		&"TransactionUpdateMessage": return Callable(self, "_read_transaction_update_message")
		&"OneOffQueryResponseMessage": return Callable(self, "_read_one_off_query_message")
		#&"ReducerResultMessage": return Callable(self, "_read_reducer_result_message")
		&"ProcedureResultMessage": return Callable(self, "_read_procedure_result_message")
		_: return Callable() # Return invalid Callable if type is not primitive/known


## Populates the value property of a sumtype enum
func _populate_enum_from_bytes(spb: StreamPeerBuffer, resource: Resource) -> void:
	var enum_types: Array = resource.get_meta("enum_options")
	var pos = spb.get_position()
	var enum_variant: int = spb.get_u8()
	resource.value = enum_variant
	var bsatn_type = enum_types[enum_variant]
	if bsatn_type.is_empty():
		return
	var data = _parse_generic_type(spb, bsatn_type)
	if has_error():
		printerr("enum failed with error: %s" % get_last_error())
		clear_error()
	if data:
		resource.data = data


#endregion


#region --- Specific Message/Structure Readers ---


# Reads the Vec<TableUpdate> structure specifically
func _read_array_of_table_updates(spb: StreamPeerBuffer, resource: Resource, prop: Dictionary) -> Array:
	var start_pos := spb.get_position()
	var length := read_u32_le(spb)
	print_log("DEBUG: _read_array_of_table_updates: Called for '%s' at pos %d. Read length: %d. New pos: %d" % [prop.name, start_pos, length, spb.get_position()])
	if has_error(): return []
	if length == 0: return []
	if length > MAX_VEC_LEN: _set_error("DatabaseUpdate tables length %d exceeds limit %d" % [length, MAX_VEC_LEN], start_pos); return []

	var result_array := []; result_array.resize(length)

	for i in range(length):
		if has_error(): return []
		var element_start_pos = spb.get_position()
		var table_update_instance = TableUpdateData.new()
		# Use the specialized instance reader for TableUpdateData's complex structure
		if not _read_table_update_instance(spb):
			if not has_error(): _set_error("Failed reading TableUpdate element %d" % i, element_start_pos)
			return []
		result_array[i] = table_update_instance

	return result_array

# Reads the query_sets structure (v2: u32 count, then for each: query_set_id, table_count, TableUpdate[]).
# Each TableUpdate in v2 is: table_name (string), rows (array of TableUpdateRows).
# TableUpdateRows enum: 0 = PersistentTable(inserts, deletes), 1 = EventTable(events).
# Used for TransactionUpdateMessage.query_sets (generic populate path and shared with _read_transaction_update_message).
func _read_query_sets(spb: StreamPeerBuffer, _resource: Resource, _prop: Dictionary) -> Array:
	var count := read_u32_le(spb)
	if has_error(): return []
	var result: Array = []
	for i in range(count):
		var dataset := DatabaseUpdateData.new()
		if dataset.query_id == null:
			dataset.query_id = QueryIdData.new()
		dataset.query_id.id = read_u32_le(spb)
		if has_error(): return result
		var table_count := read_u32_le(spb)
		if has_error(): return result
		for j in range(table_count):
			var table :TableUpdateData = _read_table_update_instance(spb)
			dataset.tables.append(table)
		result.append(dataset)
	return result

 #V2 TableUpdate: table_name (string), rows (array of TableUpdateRows).
 #TableUpdateRows: 0 = PersistentTable(inserts BsatnRowList, deletes BsatnRowList), 1 = EventTable(events BsatnRowList).
 #No compression, no table_id/num_rows/updates_count.
func _read_table_update_instance(spb: StreamPeerBuffer) -> TableUpdateData:
	var resource := TableUpdateData.new()
	resource.table_id = 0
	resource.table_name = read_string_with_u32_len(spb)
	if has_error(): return null
	var rows_count := read_u32_le(spb)
	if has_error(): return null

	var all_parsed_inserts: Array[Resource] = []
	var all_parsed_deletes: Array[Resource] = []
	var table_type: StringName = _schema.get_type_of_table_name(resource.table_name)
	var row_spb := StreamPeerBuffer.new()

	for k in range(rows_count):
		if has_error(): break
		var tag := read_u8(spb)
		if has_error(): break
		var raw_inserts: Array[PackedByteArray] = []
		var raw_deletes: Array[PackedByteArray] = []
		if tag == 0:  # PersistentTableRows
			raw_inserts = read_bsatn_row_list(spb)
			if has_error(): break
			raw_deletes = read_bsatn_row_list(spb)
			if has_error(): break
		elif tag == 1:  # EventTableRows
			var raw_events := read_bsatn_row_list(spb)
			if has_error(): break
			raw_inserts = raw_events  # Treat events as inserts for client
		else:
			_set_error("Unknown TableUpdateRows tag %d for table '%s'" % [tag, resource.table_name], spb.get_position() - 1)
			return null

		for raw_row_bytes in raw_inserts:
			row_spb.data_array = raw_row_bytes
			var row_resource = _parse_generic_type(row_spb, table_type)
			if has_error():
				printerr("row skipped with error: %s" % get_last_error())
				clear_error()
				continue
			if row_resource:
				all_parsed_inserts.append(row_resource)
			else:
				push_error("Stopping v2 table update for table '%s' due to delete row parsing failure." % resource.table_name)
				break
		if has_error(): break
		#if not row_schema_script: ????
			#continue  # Already consumed bytes above
		for raw_row_bytes in raw_deletes:
			row_spb.data_array = raw_row_bytes
			var row_resource = _parse_generic_type(row_spb, table_type)
			if has_error():
				printerr("row skipped with error: %s" % get_last_error())
				clear_error()
				continue
			if row_resource:
				all_parsed_deletes.append(row_resource)
			else:
				push_error("Stopping v2 table update for table '%s' due to delete row parsing failure." % resource.table_name)
				break


		if has_error(): break

	if has_error(): return null
	resource.num_rows = all_parsed_inserts.size() + all_parsed_deletes.size()
	resource.inserts.assign(all_parsed_inserts)
	resource.deletes.assign(all_parsed_deletes)
	return resource

# Manual reader specifically for SubscriptionErrorMessage due to Option<T> fields
# Keep this manual until Option<T> is handled generically (if ever needed)
func _read_subscription_error_message(spb: StreamPeerBuffer) -> SubscriptionErrorMessage:
	var resource := SubscriptionErrorMessage.new()

	# Read Option<u32> request_id (0 = Some, 1 = None)
	var req_id_tag = read_u8(spb); if has_error(): return null
	if req_id_tag == 0: resource.request_id = read_u32_le(spb)
	elif req_id_tag == 1: resource.request_id = -1 # Using -1 to represent None
	else: _set_error("Invalid tag %d for Option<u32> request_id" % req_id_tag, spb.get_position() - 1); return null
	if has_error(): return null

	# Read query_id
	resource.query_id = read_query_id_data(spb)
	if has_error(): return null

	resource.error_message = read_string_with_u32_len(spb)
	return null if has_error() else resource


func _read_procedure_result_message(spb: StreamPeerBuffer)-> ProcedureResultMessage:
	# v2 ProcedureResult wire format (fields in declaration order):
	#   status: ProcedureStatus (tag u8 + payload)
	#   timestamp: i64 nanoseconds (8 bytes)
	#   total_host_execution_duration: i64 microseconds (8 bytes)
	#   request_id: u32 (last)
	var resource := ProcedureResultMessage.new()
	var tag := read_u8(spb); if has_error(): return null
	var return_bytes : PackedByteArray = []
	match tag:
		0:  # Returned(Bytes) — length-prefixed return value bytes
			var byte_count := read_u32_le(spb); if has_error(): return null
			if byte_count > 0:
				return_bytes = spb.get_partial_data(byte_count)[1]

		1:  # InternalError(String)

			resource.result_err = read_string_with_u32_len(spb); if has_error(): return null
			prints("internal error procedure:",resource.result_err)
		_:
			_set_error("Unknown ProcedureStatus tag: %d" % tag)
			return null
	resource.timestamp = read_timestamp(spb)
	resource.total_host_execution_duration = read_timestamp(spb)
	if has_error(): return null
	resource.request_id = read_u32_le(spb); if has_error(): return null
	if resource.result_err or return_bytes.size() == 0:
		return resource
	## parsing of the return data
	var call: SpacetimeDBProcedureCall = _client._pending_procedure_call.get(resource.request_id)
	var return_type = call.return_type_bsatn
	var spb2 := StreamPeerBuffer.new()
	spb2.data_array = return_bytes
	## not sure about this. might have edge cases
	if has_error(): return null
	resource.result_ok = _parse_generic_type(spb2, return_type)
	if has_error():
		resource.result_err = _last_error
		clear_error()
	return resource

func _read_transaction_update_message(spb: StreamPeerBuffer) -> TransactionUpdateMessage:
	var tx_update_resource: TransactionUpdateMessage = TransactionUpdateMessage.new()
	var query_sets_array := _read_query_sets(spb, tx_update_resource, {})
	if has_error(): return null
	tx_update_resource.query_sets.assign(query_sets_array)
	return tx_update_resource

# V2 SubscribeApplied: request_id, query_set_id, rows (QueryRows = tables: [SingleTableRows]).
# Each SingleTableRows = table (RawIdentifier string), rows (BsatnRowList) — no compression tag.
func _read_subscripton_applied_message(spb: StreamPeerBuffer) -> SubscribeAppliedMessage:
	var sub_app_resource: SubscribeAppliedMessage = SubscribeAppliedMessage.new()
	sub_app_resource.request_id = read_u32_le(spb)
	if sub_app_resource.query_id == null:
		sub_app_resource.query_id = QueryIdData.new()
	sub_app_resource.query_id.id = read_u32_le(spb)  # query_set_id in v2
	if has_error(): return null
	# QueryRows.tables: array of SingleTableRows
	var tables_count := read_u32_le(spb)
	if has_error(): return null
	var row_spb := StreamPeerBuffer.new()
	for i in range(tables_count):
		var table_name := read_string_with_u32_len(spb)
		if has_error(): return null
		# BsatnRowList directly (no CompressableQueryUpdate / compression tag)
		var raw_inserts: Array[PackedByteArray] = read_bsatn_row_list(spb)
		if has_error(): return null
		var table_data: TableUpdateData = TableUpdateData.new()
		table_data.table_id = i
		table_data.table_name = table_name
		table_data.num_rows = raw_inserts.size()
		table_data.deletes.assign([])
		var table_type = _schema.get_type_of_table_name(table_name)
		var parsed_inserts: Array[Resource] = []
		if table_type:
			for raw_row_bytes in raw_inserts:
				row_spb.data_array = raw_row_bytes
				row_spb.seek(0)
				var row_resource: Resource = _parse_generic_type(row_spb, table_type)
				if has_error():
					printerr("row skipped with error: %s" % get_last_error())
					clear_error()
					continue
				if row_resource:
					parsed_inserts.append(row_resource)
				else:
					push_error("SubscribeApplied: failed to parse row for table '%s'" % table_name)
		else:
			if debug_mode: push_warning("SubscribeApplied: No schema for table '%s', skipping row parse." % table_name)
		table_data.inserts.assign(parsed_inserts)
		sub_app_resource.tables.append(table_data)
	return sub_app_resource

# V2 SubscribeApplied: request_id, query_set_id, rows (QueryRows = tables: [SingleTableRows]).
# Each SingleTableRows = table (RawIdentifier string), rows (BsatnRowList) — no compression tag.
func _read_unsubscription_applied_message(spb: StreamPeerBuffer) -> UnsubscribeAppliedMessage:
	print("Unsubscription_Applied_message parse begin")
	var sub_app_resource: UnsubscribeAppliedMessage = UnsubscribeAppliedMessage.new()
	sub_app_resource.request_id = read_u32_le(spb)
	if sub_app_resource.query_id == null:
		sub_app_resource.query_id = QueryIdData.new()
	sub_app_resource.query_id.id = read_u32_le(spb)  # query_set_id in v2
	if has_error(): return null
	# QueryRows.tables: array of SingleTableRows
	var option_tag = read_u8(spb)
	if option_tag == 0:
		var tables_count := read_u32_le(spb)
		if has_error(): return null
		var row_spb := StreamPeerBuffer.new()
		for i in range(tables_count):
			var table_name := read_string_with_u32_len(spb)
			if has_error(): return null
			# BsatnRowList directly (no CompressableQueryUpdate / compression tag)
			var raw_deletes: Array[PackedByteArray] = read_bsatn_row_list(spb)
			if has_error(): return null
			var table_data: TableUpdateData = TableUpdateData.new()
			table_data.table_id = i
			table_data.table_name = table_name
			table_data.num_rows = raw_deletes.size()
			table_data.inserts.assign([])
			var table_type = _schema.get_type_of_table_name(table_name)
			var parsed_deletes: Array[Resource] = []
			if table_type:
				for raw_row_bytes in raw_deletes:
					row_spb.data_array = raw_row_bytes
					row_spb.seek(0)
					var row_resource: Resource = _parse_generic_type(row_spb, table_type)
					if has_error():
						printerr("row skipped with error: %s" % get_last_error())
						clear_error()
						continue
					if row_resource:
						parsed_deletes.append(row_resource)
					else:
						push_error("SubscribeApplied: failed to parse row for table '%s'" % table_name)
			else:
				push_warning("SubscribeApplied: No schema for table '%s', skipping row parse." % table_name)
			table_data.deletes.assign(parsed_deletes)
			sub_app_resource.tables.append(table_data)
	else:
		print("unsub option None")
	return sub_app_resource

func _read_one_off_query_message(spb: StreamPeerBuffer)-> OneOffQueryResponseMessage:
	var response_res :OneOffQueryResponseMessage = OneOffQueryResponseMessage.new()
	response_res.request_id = read_u32_le(spb)
	if has_error(): return null
	var result_tag := read_u8(spb)
	if result_tag == 0:
		var tables_count := read_u32_le(spb)
		if has_error(): return null
		var row_spb := StreamPeerBuffer.new()
		for i in range(tables_count):
			var table_name := read_string_with_u32_len(spb)
			if has_error(): return null
			# BsatnRowList directly (no CompressableQueryUpdate / compression tag)
			var raw_inserts: Array[PackedByteArray] = read_bsatn_row_list(spb)
			if has_error(): return null
			var table_data: TableUpdateData = TableUpdateData.new()
			table_data.table_id = i
			table_data.table_name = table_name
			table_data.num_rows = raw_inserts.size()
			table_data.deletes.assign([])
			var table_type = _schema.get_type_of_table_name(table_name)
			var parsed_inserts: Array[Resource] = []
			if table_type:
				for raw_row_bytes in raw_inserts:
					row_spb.data_array = raw_row_bytes
					row_spb.seek(0)
					var row_resource: Resource = _parse_generic_type(row_spb, table_type)
					if has_error():
						printerr("row skipped with error: %s" % get_last_error())
						clear_error()
						continue
					if row_resource:
						parsed_inserts.append(row_resource)
					else:
						push_error("SubscribeApplied: failed to parse row for table '%s'" % table_name)
			else:
				if debug_mode: push_warning("SubscribeApplied: No schema for table '%s', skipping row parse." % table_name)
			table_data.inserts.assign(parsed_inserts)
			response_res.result_ok.append(table_data)
	else:
		response_res.result_err = read_string_with_u32_len(spb)
		if has_error(): return null

	return response_res

func _parse_generic_type(spb:StreamPeerBuffer, bsatn_type:StringName)-> Variant:
	if bsatn_type.begins_with("opt_"):
		return _read_option(spb, bsatn_type.trim_prefix("opt_"))
	elif bsatn_type.begins_with("vec_"):
		var result_type_array: Array = []
		var count = read_u32_le(spb)
		for i in count:
			result_type_array.append(_parse_generic_type(spb, bsatn_type.trim_prefix("vec_")))
		return result_type_array
	elif bsatn_type.begins_with("ret_"):
		return _read_result(spb, bsatn_type.trim_prefix("ret_"))
	elif NATIVE_ARRAYLIKE.has(bsatn_type):
		return _read_native_arraylike(spb, bsatn_type)
	var script: GDScript
	if _schema.core_types.has(bsatn_type):
		var reader_callablce := _get_primitive_reader_from_bsatn_type(bsatn_type)
		## directly handle server messages
		if reader_callablce.is_valid():
			return reader_callablce.call(spb)
		else:
			script = _schema.get_core_type_script(bsatn_type)
	elif _schema.module_types.has(bsatn_type):
		script = _schema.get_type_script(bsatn_type)
	else:
		var primitive_reader = _get_primitive_reader_from_bsatn_type(bsatn_type)
		if primitive_reader.is_valid():
			return primitive_reader.call(spb)

		_set_error("unknown bsatn_type: %s" % bsatn_type )
	if not script or not script.can_instantiate():
		_set_error("script: %s is empty or can't instantiate" % script)

	var result_resource := script.new()
	if result_resource is RustEnum:
		# error handling?
		_populate_enum_from_bytes(spb,result_resource)
		return result_resource
	var properties: Array = script.get_script_property_list()
	for prop in properties:
		if not (prop.usage & PROPERTY_USAGE_STORAGE):
			continue
		var bsatn_type_str: StringName = result_resource.get_meta("bsatn_type_"+prop.name)
		var reader_callablce := _get_primitive_reader_from_bsatn_type(bsatn_type_str)
		if reader_callablce.is_valid():
			result_resource[prop.name] = reader_callablce.call(spb)
		elif _schema.module_types.has(bsatn_type_str) or _schema.core_types.has(bsatn_type_str) or bsatn_type_str.begins_with("opt_") or bsatn_type_str.begins_with("ret_") or NATIVE_ARRAYLIKE.has(bsatn_type_str):
			result_resource[prop.name] = _parse_generic_type(spb, bsatn_type_str)
		elif bsatn_type_str.begins_with("vec_"):
			var result_type_array = _parse_generic_type(spb, bsatn_type_str)
			var temp_arr = result_resource[prop.name]
			temp_arr.append_array(result_type_array)
			result_resource[prop.name] = temp_arr
		else:
			_set_error("unknown bsatn_type: %s for prop %s in %s" % [bsatn_type_str, prop.name, bsatn_type])
			return null
	return result_resource

##endregion


#region --- Top-Level Message Parsing ---

func _parse_message_from_stream(spb: StreamPeerBuffer) -> Resource:
	clear_error()
	#if spb.get_available_bytes().is_empty(): _set_error("Input buffer is empty", 0); return null

	var start_pos = spb.get_position()
	if not _check_read(spb, 1):
		return null

	var msg_type := read_u8(spb)
	if has_error(): return null

	var result_resource: Resource = null
	# Path to the GDScript file for the message type
	var message_type := SpacetimeDBServerMessage.get_core_type(msg_type)

	if message_type.is_empty():
		_set_error("Unknown server message type: 0x%02X" % msg_type, 1)
		return null

	result_resource = _parse_generic_type(spb, message_type)
	# Optional: Check if all bytes were consumed after parsing the message body
	var remaining_bytes := spb.get_size() - spb.get_position()
	if remaining_bytes > 0:
		# This might indicate a parsing error or extra data. Warning is appropriate.
		push_error("Bytes remaining after parsing message type 0x%02X: %d" % [msg_type, remaining_bytes])
		spb.clear()
	return result_resource

func process_bytes_and_extract_messages(raw_data: PackedByteArray) -> Array[Resource]:
	if raw_data.is_empty():
		return []

	var parsed_messages: Array[Resource] = []
	var spb := StreamPeerBuffer.new()
	var count := 0
	while not raw_data.is_empty():
		count += 1

		clear_error()
		spb.data_array = raw_data

		var message_resource = _parse_message_from_stream(spb)

		if has_error():
			if _last_error.contains("past end of buffer"):
				clear_error()
				break
			else:
				printerr("BSATNDeserializer: Unrecoverable parsing error: %s. Clearing buffer to prevent infinite loop." % get_last_error())
				raw_data.clear()
				spb.clear()
				break

		if message_resource:
			parsed_messages.append(message_resource)
			var bytes_consumed = spb.get_position()

			if bytes_consumed == 0:
				printerr("BSATNDeserializer: Parser consumed 0 bytes. Clearing buffer to prevent infinite loop.")
				raw_data.clear()
				spb.clear()
				break
			raw_data = raw_data.slice(bytes_consumed)
		else:
			break
	if count > 1:
		prints("process_bytes_and_extract_messages ran %s times" % count)
	return parsed_messages
#endregion
