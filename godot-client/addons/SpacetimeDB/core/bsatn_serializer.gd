class_name BSATNSerializer extends RefCounted

const IDENTITY_SIZE := 32
const CONNECTION_ID_SIZE := 16
const U128_SIZE := 16

var _last_error: String = ""
var _spb: StreamPeerBuffer
var _schema: SpacetimeDBSchema
var debug_mode := false


func _init(p_schema: SpacetimeDBSchema, p_debug_mode: bool = false) -> void:
	_schema = p_schema
	debug_mode = p_debug_mode
	_spb = StreamPeerBuffer.new()
	_spb.big_endian = false


func has_error() -> bool:
	return _last_error != ""


func get_last_error() -> String:
	var err := _last_error
	_last_error = ""
	return err


func clear_error() -> void:
	_last_error = ""


func _set_error(msg: String) -> void:
	if _last_error == "":
		_last_error = "BSATNSerializer Error: %s" % msg
		printerr(_last_error)


func _reset_buffer() -> void:
	_spb.data_array = PackedByteArray()
	_spb.seek(0)
	_spb.big_endian = false


func _log(msg: String) -> void:
	if debug_mode:
		print(msg)


func _generate_default_type(bsatn_type_name: String) -> Variant:
	match String(bsatn_type_name):
		"I8", "I16", "I32", "I64", "U8", "U16", "U32", "U64":
			return 0
		"F32", "F64":
			return 0.0
		"Bool":
			return false
		"String":
			return ""
		"Vector2":
			return Vector2.ZERO
		"Vector2i":
			return Vector2i.ZERO
		"Vector3":
			return Vector3.ZERO
		"Vector3i":
			return Vector3i.ZERO
		"Vector4":
			return Vector4.ZERO
		"Vector4i":
			return Vector4i.ZERO
		"Color":
			return Color.BLACK
		"Quaternion":
			return Quaternion.IDENTITY
		_:
			return null


func write_i8(v: int) -> void:
	if v < -128 or v > 127:
		_set_error("Value %d out of range for i8" % v)
		v = 0
	_spb.put_u8(v if v >= 0 else v + 256)


func write_i16_le(v: int) -> void:
	if v < -32768 or v > 32767:
		_set_error("Value %d out of range for i16" % v)
		v = 0
	_spb.put_u16(v if v >= 0 else v + 65536)


func write_i32_le(v: int) -> void:
	if v < -2147483648 or v > 2147483647:
		_set_error("Value %d out of range for i32" % v)
		v = 0
	_spb.put_u32(v)


func write_i64_le(v: int) -> void:
	_spb.put_u64(v)


func write_u8(v: int) -> void:
	if v < 0 or v > 255:
		_set_error("Value %d out of range for u8" % v)
		v = 0
	_spb.put_u8(v)


func write_u16_le(v: int) -> void:
	if v < 0 or v > 65535:
		_set_error("Value %d out of range for u16" % v)
		v = 0
	_spb.put_u16(v)


func write_u32_le(v: int) -> void:
	if v < 0 or v > 4294967295:
		_set_error("Value %d out of range for u32" % v)
		v = 0
	_spb.put_u32(v)


func write_u64_le(v: int) -> void:
	if v < 0:
		_set_error("Value %d out of range for u64" % v)
		v = 0
	_spb.put_u64(v)


func write_f32_le(v: float) -> void:
	_spb.put_float(v)


func write_f64_le(v: float) -> void:
	_spb.put_double(v)


func write_bool(v: bool) -> void:
	_spb.put_u8(1 if v else 0)


func write_bytes(v: PackedByteArray) -> void:
	if v == null:
		v = PackedByteArray()
	var result := _spb.put_data(v)
	if result != OK:
		_set_error("StreamPeerBuffer.put_data failed with code %d" % result)


func write_hex_string(v: String) -> void:
	if v.is_empty():
		return
	var v2 := v.hex_decode()
	v2.reverse()
	var result := _spb.put_data(v2)
	if result != OK:
		_set_error("StreamPeerBuffer.put_data failed with code %d" % result)


func write_u128(v: PackedByteArray) -> void:
	if v == null or v.size() != U128_SIZE:
		_set_error("Invalid U128 value (null or size != %d)" % U128_SIZE)
		var default_bytes := PackedByteArray()
		default_bytes.resize(U128_SIZE)
		write_bytes(default_bytes)
		return
	var copy := v.duplicate()
	copy.reverse()
	write_bytes(copy)


func write_identity(v: PackedByteArray) -> void:
	if v == null or v.size() != IDENTITY_SIZE:
		_set_error("Invalid Identity value (null or size != %d)" % IDENTITY_SIZE)
		var default_bytes := PackedByteArray()
		default_bytes.resize(IDENTITY_SIZE)
		write_bytes(default_bytes)
		return
	var copy := v.duplicate()
	copy.reverse()
	write_bytes(copy)


func write_connection_id(v: PackedByteArray) -> void:
	if v == null or v.size() != CONNECTION_ID_SIZE:
		_set_error("Invalid ConnectionId value (null or size != %d)" % CONNECTION_ID_SIZE)
		var default_bytes := PackedByteArray()
		default_bytes.resize(CONNECTION_ID_SIZE)
		write_bytes(default_bytes)
		return
	var copy := v.duplicate()
	copy.reverse()
	write_bytes(copy)


func write_timestamp(v: int) -> void:
	write_i64_le(v)


func write_string_with_u32_len(v: StringName) -> void:
	if v == null:
		v = ""
	var bytes := String(v).to_utf8_buffer()
	write_u32_le(bytes.size())
	if bytes.size() > 0:
		write_bytes(bytes)


func write_vec_u8(v: PackedByteArray) -> void:
	if v == null:
		v = PackedByteArray()
	write_u32_le(v.size())
	if v.size() > 0:
		write_bytes(v)


func write_option(option_value: Option, bsatn_type: String, prop: StringName) -> void:
	if not option_value is Option:
		_set_error("Value for '%s' is not an Option." % prop)
		return

	if option_value.is_none():
		write_u8(1)
		return

	write_u8(0)
	if has_error():
		return

	var inner := bsatn_type
	if inner.begins_with("opt_"):
		inner = inner.trim_prefix("opt_")

	_write_value_from_bsatn_type(option_value.unwrap(), inner, prop + "[inner]")


func write_rust_enum(rust_enum: RustEnum) -> void:
	write_u8(rust_enum.value)
	var options = rust_enum["enum_options"]
	var sub_class := String(options[rust_enum.value]).to_lower()
	var data = rust_enum.data

	if sub_class.begins_with("vec"):
		if data is not Array:
			_set_error(
				"Rust enum variant expects Array but got %s"
				% type_string(typeof(data))
			)
			return
		var vec_type := sub_class.right(-4)
		if vec_type.begins_with("opt"):
			vec_type = vec_type.right(-4)
		_write_value_from_bsatn_type(data, vec_type, &"")
		return

	if sub_class.begins_with("opt"):
		if not data is Option:
			_set_error(
				"Rust enum variant expects Option but got %s"
				% type_string(typeof(data))
			)
			return
		var opt_type := sub_class.right(-4)
		if opt_type.begins_with("vec"):
			opt_type = opt_type.right(-4)
		_write_value_from_bsatn_type(data, opt_type, &"")
		return

	if not sub_class.is_empty():
		if not data:
			data = _generate_default_type(sub_class)
		_write_value_from_bsatn_type(data, sub_class, &"")


func write_native_arraylike(v: Variant, bsatn_type: String, prop_name: StringName) -> void:
	var components: Array = []
	match typeof(v):
		TYPE_VECTOR2:
			components = [v.x, v.y]
		TYPE_VECTOR2I:
			components = [v.x, v.y]
		TYPE_VECTOR3:
			components = [v.x, v.y, v.z]
		TYPE_VECTOR3I:
			components = [v.x, v.y, v.z]
		TYPE_VECTOR4:
			components = [v.x, v.y, v.z, v.w]
		TYPE_VECTOR4I:
			components = [v.x, v.y, v.z, v.w]
		TYPE_QUATERNION:
			components = [v.x, v.y, v.z, v.w]
		TYPE_COLOR:
			components = [v.r, v.g, v.b, v.a]
		_:
			_set_error(
				"Unsupported native arraylike type '%s' for '%s'"
				% [type_string(typeof(v)), prop_name]
			)
			return

	var component_types: Array[String] = []
	if bsatn_type.contains("[") and bsatn_type.contains("]"):
		var inside := bsatn_type.get_slice("[", 1).get_slice("]", 0)
		component_types = inside.split(",")
	else:
		match typeof(v):
			TYPE_VECTOR2:
				component_types = ["F32", "F32"]
			TYPE_VECTOR2I:
				component_types = ["I32", "I32"]
			TYPE_VECTOR3:
				component_types = ["F32", "F32", "F32"]
			TYPE_VECTOR3I:
				component_types = ["I32", "I32", "I32"]
			TYPE_VECTOR4:
				component_types = ["F32", "F32", "F32", "F32"]
			TYPE_VECTOR4I:
				component_types = ["I32", "I32", "I32", "I32"]
			TYPE_QUATERNION:
				component_types = ["F32", "F32", "F32", "F32"]
			TYPE_COLOR:
				component_types = ["F32", "F32", "F32", "F32"]

	if component_types.size() != components.size():
		_set_error("Invalid component count for '%s'" % prop_name)
		return

	for i in range(components.size()):
		_write_value_from_bsatn_type(
			components[i],
			component_types[i],
			"%s[%d]" % [prop_name, i]
		)


func write_array(v: Array, bsatn_type: String, prop_name: StringName) -> void:
	write_u32_le(v.size())
	if has_error() or v.is_empty():
		return

	var element_type := ""
	if bsatn_type.begins_with("vec_"):
		element_type = bsatn_type.trim_prefix("vec_")
	else:
		element_type = bsatn_type

	for i in range(v.size()):
		_write_value_from_bsatn_type(v[i], element_type, "%s[%d]" % [prop_name, i])


func write_nested_resource(resource: Resource) -> void:
	if resource == null:
		_set_error("Cannot serialize null resource")
		return
	_serialize_resource_fields(resource)


func _write_value_from_bsatn_type(
	value: Variant,
	bsatn_type_str: String,
	context_name: StringName
) -> bool:
	if bsatn_type_str.begins_with("opt_"):
		if value is not Option:
			_set_error("Expected Option for '%s'" % context_name)
			return false
		write_option(value, bsatn_type_str.trim_prefix("opt_"), context_name)
		return not has_error()

	if bsatn_type_str.begins_with("vec_") and typeof(value) == TYPE_ARRAY:
		write_array(value, bsatn_type_str, context_name)
		return not has_error()

	match bsatn_type_str:
		"U128":
			write_u128(value)
			return not has_error()
		"U64":
			write_u64_le(value)
			return not has_error()
		"I64":
			write_i64_le(value)
			return not has_error()
		"F64":
			write_f64_le(value)
			return not has_error()
		"U32":
			write_u32_le(value)
			return not has_error()
		"I32":
			write_i32_le(value)
			return not has_error()
		"F32":
			write_f32_le(value)
			return not has_error()
		"U16":
			write_u16_le(value)
			return not has_error()
		"I16":
			write_i16_le(value)
			return not has_error()
		"U8":
			write_u8(value)
			return not has_error()
		"I8":
			write_i8(value)
			return not has_error()
		"__identity__":
			write_identity(value)
			return not has_error()
		"__connection_id__":
			write_connection_id(value)
			return not has_error()
		"__timestamp_micros_since_unix_epoch__", "scheduled_at":
			write_timestamp(value)
			return not has_error()
		"__uuid__":
			write_hex_string(value)
			return not has_error()
		"Bool":
			write_bool(value)
			return not has_error()
		"String":
			write_string_with_u32_len(value)
			return not has_error()
		"vec_U8":
			write_vec_u8(value)
			return not has_error()

	var value_type := typeof(value)
	match value_type:
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION, TYPE_COLOR:
			write_native_arraylike(value, bsatn_type_str, context_name)
			return not has_error()
		TYPE_ARRAY:
			write_array(value, bsatn_type_str, context_name)
			return not has_error()
		TYPE_BOOL:
			write_bool(value)
			return not has_error()
		TYPE_INT:
			write_i64_le(value)
			return not has_error()
		TYPE_FLOAT:
			write_f32_le(value)
			return not has_error()
		TYPE_STRING, TYPE_STRING_NAME:
			write_string_with_u32_len(value)
			return not has_error()
		TYPE_PACKED_BYTE_ARRAY:
			write_vec_u8(value)
			return not has_error()
		TYPE_OBJECT:
			if value is Option:
				write_option(value, bsatn_type_str, context_name)
				return not has_error()
			if value is Resource:
				write_nested_resource(value)
				return not has_error()
			_set_error(
				"Unsupported object type '%s' for '%s'"
				% [type_string(value_type), context_name]
			)
			return false
		_:
			_set_error(
				"Unsupported BSATN type '%s' for '%s'"
				% [bsatn_type_str, context_name]
			)
			return false


func _serialize_resource_fields(resource: Resource) -> bool:
	if resource == null:
		_set_error("Cannot serialize null resource")
		return false

	if resource is RustEnum:
		write_rust_enum(resource)
		return not has_error()

	for key: StringName in resource.BSATN_TYPES.keys():
		var value = resource.get(key)
		var bsatn_type: StringName = resource.BSATN_TYPES.get(key)

		if value is Option:
			write_option(value, bsatn_type, key)
		elif value is Resource:
			write_nested_resource(value)
		else:
			_write_value_from_bsatn_type(value, bsatn_type, key)

		if has_error():
			return false

	return true


func _serialize_arguments(
	args_array: Array,
	bsatn_types: Array
) -> PackedByteArray:
	clear_error()

	var args_spb := StreamPeerBuffer.new()
	args_spb.big_endian = false
	var original_spb := _spb
	_spb = args_spb

	for i in range(args_array.size()):
		var arg_value = args_array[i]
		var bsatn_type := ""
		if i < bsatn_types.size():
			bsatn_type = String(bsatn_types[i])

		if not _write_value_from_bsatn_type(arg_value, bsatn_type, "arg[%d]" % i):
			_spb = original_spb
			return PackedByteArray()

	_spb = original_spb
	return args_spb.data_array if not has_error() else PackedByteArray()


func serialize_client_message(
	variant_tag: int,
	payload_resource: Resource
) -> PackedByteArray:
	clear_error()
	_reset_buffer()

	write_u8(variant_tag)
	if has_error():
		return PackedByteArray()

	if payload_resource == null:
		_set_error("Cannot serialize null payload resource")
		return PackedByteArray()

	if not _serialize_resource_fields(payload_resource):
		return PackedByteArray()

	return _spb.data_array
