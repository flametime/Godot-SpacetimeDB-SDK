class_name BSATNSerializer extends RefCounted

# --- Constants ---
const IDENTITY_SIZE := 32
const CONNECTION_ID_SIZE := 16
const U128_SIZE := 16

# Native type handling
const NATIVE_ARRAYLIKE_TYPES := [
	TYPE_VECTOR2,
	TYPE_VECTOR2I,
	TYPE_VECTOR3,
	TYPE_VECTOR3I,
	TYPE_VECTOR4,
	TYPE_VECTOR4I,
	TYPE_QUATERNION,
	TYPE_COLOR
]

# --- Properties ---
var _last_error: String = ""
var _serialization_plan_cache: Dictionary = {}
var _spb: StreamPeerBuffer # Internal buffer used by writing functions
var _native_arraylike_regex := RegEx.new()

var debug_mode := false # Controls verbose debug printing

# --- Initialization ---
func _init(p_debug_mode: bool = false) -> void:
	debug_mode = p_debug_mode
	_spb = StreamPeerBuffer.new()
	_spb.big_endian = false # Use Little-Endian
	
	_native_arraylike_regex.compile("^(?<struct>.+)\\[(?<components>.*)\\]$")

# --- Error Handling ---
func has_error() -> bool: return _last_error != ""
func get_last_error() -> String: var e = _last_error; _last_error = ""; return e
func clear_error() -> void: _last_error = ""
# Sets the error message if not already set. Internal use.
func _set_error(msg: String) -> void:
	if _last_error == "": # Prevent overwriting
		_last_error = "BSATNSerializer Error: %s" % msg
		printerr(_last_error) # Always print errors

# --- Primitive Value Writers ---
# These directly write basic types to the internal StreamPeerBuffer.

func write_i8(v: int) -> void:
	#print("write_i8(%s)" % v)
	if v < -128 or v > 127: _set_error("Value %d out of range for i8" % v); v = 0
	_spb.put_u8(v if v >= 0 else v + 256)

func write_i16_le(v: int) -> void:
	#print("write_i16_le(%s)" % v)
	if v < -32768 or v > 32767: _set_error("Value %d out of range for i16" % v); v = 0
	_spb.put_u16(v if v >= 0 else v + 65536)

func write_i32_le(v: int) -> void:
	#print("write_i32_le(%s)" % v)
	if v < -2147483648 or v > 2147483647: _set_error("Value %d out of range for i32" % v); v = 0
	_spb.put_u32(v) # put_u32 handles negative i32 correctly via two's complement

func write_i64_le(v: int) -> void:
	#print("write_i64_le(%s)" % v)
	_spb.put_u64(v) # put_u64 handles negative i64 correctly via two's complement

func write_u8(v: int) -> void:
	#print("write_u8(%s)" % v)
	if v < 0 or v > 255: _set_error("Value %d out of range for u8" % v); v = 0
	_spb.put_u8(v)

func write_u16_le(v: int) -> void:
	#print("write_u16_le(%s)" % v)
	if v < 0 or v > 65535: _set_error("Value %d out of range for u16" % v); v = 0
	_spb.put_u16(v)

func write_u32_le(v: int) -> void:
	#print("write_u32_le(%s)" % v)
	if v < 0 or v > 4294967295: _set_error("Value %d out of range for u32" % v); v = 0
	_spb.put_u32(v)

func write_u64_le(v: int) -> void:
	#print("write_u64_le(%s)" % v)
	if v < 0: _set_error("Value %d out of range for u64" % v); v = 0
	_spb.put_u64(v)

func write_f32_le(v: float) -> void:
	#print("write_f32_le(%s)" % v)
	_spb.put_float(v)

func write_f64_le(v: float) -> void:
	#print("write_f64_le(%s)" % v)
	_spb.put_double(v)

func write_u128(v: PackedByteArray) -> void:
	if v == null or v.size() != U128_SIZE:
		_set_error("Invalid U128 value (null or size != %d)" % U128_SIZE)
		var default_bytes = PackedByteArray(); default_bytes.resize(U128_SIZE)
		write_bytes(default_bytes) # Write default value to avoid stopping serialization
		return
	var v_copy := v.duplicate()
	v_copy.reverse()
	write_bytes(v_copy)

func write_bool(v: bool) -> void:
	#print("write_bool(%s)" % v)
	_spb.put_u8(1 if v else 0)

func write_bytes(v: PackedByteArray) -> void:
	#print("write_bytes(%s)" % v)
	if v == null: v = PackedByteArray() # Avoid error on null
	var result = _spb.put_data(v)
	if result != OK: _set_error("StreamPeerBuffer.put_data failed with code %d" % result)

func write_string_with_u32_len(v: String) -> void:
	#print("write_string_with_u32_len(%s)" % v)
	if v == null: v = ""
	var str_bytes := v.to_utf8_buffer()
	write_u32_le(str_bytes.size())
	if str_bytes.size() > 0: write_bytes(str_bytes)

func write_identity(v: PackedByteArray) -> void:
	#print("write_identity(%s)" % v)
	if v == null or v.size() != IDENTITY_SIZE:
		_set_error("Invalid Identity value (null or size != %d)" % IDENTITY_SIZE)
		var default_bytes = PackedByteArray(); default_bytes.resize(IDENTITY_SIZE)
		write_bytes(default_bytes) # Write default value to avoid stopping serialization
		return
	var v_copy := v.duplicate()
	v_copy.reverse()
	write_bytes(v_copy)

func write_connection_id(v: PackedByteArray) -> void:
	#print("write_connection_id(%s)" % v)
	if v == null or v.size() != CONNECTION_ID_SIZE:
		_set_error("Invalid ConnectionId value (null or size != %d)" % CONNECTION_ID_SIZE)
		var default_bytes = PackedByteArray(); default_bytes.resize(CONNECTION_ID_SIZE)
		write_bytes(default_bytes) # Write default value
		return
	var v_copy := v.duplicate()
	v_copy.reverse()
	write_bytes(v_copy)

func write_timestamp(v: int) -> void:
	#print("write_timestamp(%s)" % v)
	write_i64_le(v) # Timestamps are typically i64

# Writes a PackedByteArray prefixed with its u32 length (Vec<u8> format)
func write_vec_u8(v: PackedByteArray) -> void:
	#print("write_vec_u8(%s)" % v)
	if v == null: v = PackedByteArray()
	write_u32_le(v.size())
	if v.size() > 0: write_bytes(v) # Avoid calling put_data with empty array if possible

# --- Special Writers ---

## Writes a Rust sumtype enum
func write_rust_enum(rust_enum: RustEnum) -> void:
	#print("write_rust_enum(%s)" % rust_enum)
	write_u8(rust_enum.value)
	var sub_class: String = str(rust_enum.get_meta("enum_options")[rust_enum.value]).to_lower()
	var data = rust_enum.data
	if sub_class.begins_with("vec"):
		if data is not Array:
			_set_error("Sum type of rust enum is Vec<T> but the godot type is not an array.")
			return
		var vec_type = sub_class.right(-4)
		# If it's an Option type, we need to remove the opt prefix for the serializer
		# This is a special case, the enum needs more info for the deserializer
		if vec_type.begins_with("opt"):
			vec_type = vec_type.right(-4)
		_write_value_from_bsatn_type(data, vec_type, &"")
		return
	if sub_class.begins_with("opt"):
		if data is not Option:
			_set_error("Sum type of rust enum is Option<T> but the godot type is not an Option.")
			return
		var opt_type = sub_class.right(-4)
		# If it's a Vec type, we need to remove the vec prefix for the serializer
		# This is a special case, the enum needs more info for the deserializer
		if opt_type.begins_with("vec"):
			opt_type = opt_type.right(-4)
		_write_value_from_bsatn_type(data, opt_type, &"")
		return
	if not sub_class.is_empty():
		if not data:
			data = _generate_default_type(sub_class)
		_write_value_from_bsatn_type(data, sub_class, &"")

## Writes an option value
func write_option(option_value: Option, bsatn_type: String, prop: Dictionary) -> bool:
	#print("write_option(%s)" % option_value)
	var prop_name: StringName = prop.name
	
	if not option_value is Option:
		_set_error("Value provided to write_option is not an Option instance (type: %s) for property '%s'." % [typeof(option_value), prop_name])
		return false
	if option_value.is_none():
		write_u8(1) # Tag for None
		if has_error():
			_set_error("Failed to write None tag for Option property '%s'." % prop_name)
			return false
		return true
	else: # is_some()
		write_u8(0) # Tag for Some
		if has_error():
			_set_error("Failed to write Some tag for Option property '%s'." % prop_name)
			return false
		if bsatn_type.begins_with("vec"):
			if option_value.unwrap() is not Array:
				_set_error("Option type is Vec<T> but the godot type is not an array.")
				return false
			var vec_type = bsatn_type.right(-4)
			_write_value_from_bsatn_type(option_value.unwrap(), vec_type, prop_name + "[inner]")
		else:
			_write_value_from_bsatn_type(option_value.unwrap(), bsatn_type, prop_name + "[inner]")
		return true

## Writes an array type
func write_array(v: Array, bsatn_type: String, prop: Dictionary) -> void:
	#print("write_array(%s)" % str(v))
	var prop_name: StringName = prop.name
	
	# 1. Write array length (u32)
	write_u32_le(v.size())
	if has_error(): return
	if v.size() == 0: return
	
	# 2. Determine element prototype info (Variant.Type, class_name)
	var hint: int = prop.hint
	var hint_string: String = prop.hint_string
	var element_type_code: Variant.Type = TYPE_MAX
	var element_class_name: StringName = &""
	
	if hint == PROPERTY_HINT_TYPE_STRING and ":" in hint_string: # Godot 3: "Type:TypeName"
		var hint_parts = hint_string.split(":", true, 1)
		if hint_parts.size() == 2:
			var hint_type = hint_parts[0].split("/", true, 1) if "/" in hint_parts[0] else [hint_parts[0]]
			element_type_code = int(hint_type[0])
			if element_type_code == TYPE_OBJECT: element_class_name = hint_parts[1]
	elif hint == PROPERTY_HINT_ARRAY_TYPE: # Godot 4: "VariantType/ClassName:VariantType" or "VariantType:VariantType"
		var main_type_str = hint_string.split(":", true, 1)[0]
		if "/" in main_type_str:
			var parts = main_type_str.split("/", true, 1)
			element_type_code = int(parts[0])
			element_class_name = parts[1]
		else:
			element_type_code = int(main_type_str)
	
	if element_type_code == TYPE_MAX and not v.is_empty():
		var first_element = v[0]
		element_type_code = typeof(first_element)
		if element_type_code == TYPE_OBJECT:
			element_class_name = _get_value_class_name(first_element)
	
	if element_type_code == TYPE_MAX and bsatn_type.is_empty():
		_set_error("Array '%s' needs a typed hint or must not be empty for serialization. Hint: %d, HintString: '%s'" % [prop_name, hint, hint_string])
		return
	
	# 3. Create a temporary "prototype" dictionary for the element
	var element_prop_sim = {
		"name": prop_name + "[element]",
		"type": element_type_code,
		"class_name": element_class_name,
		"usage": PROPERTY_USAGE_STORAGE,
		"hint": 0,
		"hint_string": ""
	}
	
	# 4. Determine the writer function for the ELEMENTS
	var element_writer_callable : Callable
	if element_class_name == &"Option":
		element_writer_callable = Callable(self, "write_option")
		if bsatn_type.is_empty():
			_set_error("Array '%s' of Options has empty 'bsatn_type' metadata. Inner type T for Option<T> cannot be determined." % prop_name)
			return
	else:
		if not bsatn_type.is_empty() and element_type_code != TYPE_ARRAY:
			element_writer_callable = _get_primitive_writer_from_bsatn_type(bsatn_type)
			if not element_writer_callable.is_valid() and debug_mode:
				push_warning("Array '%s' has 'bsatn_type' metadata ('%s'), but it doesn't map to a primitive reader. Falling back to element type hint." % [prop_name, bsatn_type])
				
		element_writer_callable = _get_writer_callable_for_property(element_prop_sim, bsatn_type)
	
	if not element_writer_callable.is_valid():
		_set_error("Cannot determine writer for elements of array '%s' (element type code %d, class '%s')." % [prop_name, element_type_code, element_class_name])
		return
		
	for i in range(v.size()):
		if has_error(): return # Stop on error
		var element_value = v[i]
		
		if element_writer_callable.get_object() == self:
			_call_writer_callable(element_writer_callable, element_value, bsatn_type, element_prop_sim)
		else: 
			_set_error("Internal error: Invalid element writer callable for array '%s'." % prop_name)
			return
		
		if has_error():
			if not _last_error.contains("element %d" % i) and not _last_error.contains(str(prop_name)): # Avoid redundant context
				var existing_error = get_last_error()
				_set_error("Failed writing element %d for array '%s'. Cause: %s" % [i, prop_name, existing_error])
			return

## Writes a native array-like value
func write_native_arraylike(v: Variant, bsatn_type: String, prop: Dictionary) -> void:
	#print("write_native_arraylike(%s)" % v)
	var prop_name: StringName = prop.name
	
	if bsatn_type.is_empty():
		_set_error("Array-like gd type '%' has empty 'bsatn_type' metadata. Inner component types cannot be determined." % prop_name)
		return
	
	var result = _native_arraylike_regex.search(bsatn_type)
	var bsatn_struct_type := result.get_string("struct")
	if bsatn_struct_type.is_empty():
		_set_error("Cannot determine struct type for array-like gd type '%s' from 'bsatn_type' metadata ('%s')" % [prop_name, bsatn_type])
		return
		
	if v == null: v = _generate_default_type(bsatn_struct_type)
	var value_type := typeof(v)
	
	var components: Array
	match value_type:
		TYPE_VECTOR2: components = [v.x, v.y]
		TYPE_VECTOR2I: components = [v.x, v.y]
		TYPE_VECTOR3: components = [v.x, v.y, v.z]
		TYPE_VECTOR3I: components = [v.x, v.y, v.z]
		TYPE_VECTOR4: components = [v.x, v.y, v.z, v.w]
		TYPE_VECTOR4I: components = [v.x, v.y, v.z, v.w]
		TYPE_QUATERNION: components = [v.x, v.y, v.z, v.w]
		TYPE_COLOR: components = [v.r, v.g, v.b, v.a]
		_:
			_set_error("Unsupported array-like gd type '%s' ('%s'). Could not assign components array." % [prop_name, type_string(value_type)])
			return
	
	var bsatn_types_for_components := result.get_string("components")
	if bsatn_types_for_components.is_empty():
		_set_error("Cannot determine inner component types for array-like gd type '%s' from 'bsatn_type' metadata ('%s')" % [prop_name, bsatn_type])
		return
	
	var bsatn_component_types := bsatn_types_for_components.split(",")
	if bsatn_component_types.size() != components.size():
		_set_error("Array-like gd type '%s' expected 'bsatn_type' to have %d component types but has %d" % \
			[prop_name, components.size(), bsatn_component_types.size()])
		return
	
	for i in range(components.size()):
		var value = components[i]
		var bsatn_component_type = bsatn_component_types[i]
		_write_value_from_bsatn_type(value, bsatn_component_type, prop_name + "[%s]" % i)

func write_nested_resource(resource: Resource, bsatn_type: String, prop: Dictionary) -> void:
	#print("write_nested_resource(%s)" % _get_value_class_name(resource))
	if resource is not Resource:
		_set_error("Cannot serialize non-Resource Object argument.")
		return
	
	var prop_name: StringName = prop.name
	var nested_class_name: StringName = prop.class_name
	
	# Serialize resource fields directly inline (recursive)
	if not _serialize_resource_fields(resource):
		if not has_error(): _set_error("Failed to serialize nested resource '%s' of '%s'." % [prop_name, nested_class_name])

# --- Core Serialization Logic ---

func _get_value_class_name(value: Variant) -> String:
	if value is Resource:
		var script = value.get_script()
		return script.get_global_name() if script and script.get_global_name() else value.resource_path
	
	if typeof(value) == TYPE_OBJECT: return value.get_class()
	return type_string(typeof(value))

# Helper to get the specific BSATN writer METHOD NAME based on metadata value.
func _get_primitive_writer_from_bsatn_type(bsatn_type_str: String) -> Callable:
	match bsatn_type_str:
		&'u128': return Callable(self, "write_u128")
		&"u64": return Callable(self, "write_u64_le")
		&"i64": return Callable(self, "write_i64_le")
		&"f64": return Callable(self, "write_f64_le")
		&"u32": return Callable(self, "write_u32_le")
		&"i32": return Callable(self, "write_i32_le")
		&"f32": return Callable(self, "write_f32_le")
		&"u16": return Callable(self, "write_u16_le")
		&"i16": return Callable(self, "write_i16_le")
		&"u8": return Callable(self, "write_u8")
		&"i8": return Callable(self, "write_i8")
		&"identity": return Callable(self, "write_identity")
		&"connection_id": return Callable(self, "write_connection_id")
		&"timestamp": return Callable(self, "write_timestamp")
		&"vec_u8": return Callable(self, "write_vec_u8")
		&"bool": return Callable(self, "write_bool")
		&"string": return Callable(self, "write_string_with_u32_len")
		# Add other specific types mapped to writer methods if needed
		_: return Callable() # Unknown or non-primitive type

func _get_writer_callable_for_property(prop: Dictionary, bsatn_type_str: String) -> Callable:
	var prop_name: StringName = prop.name
	var prop_type: Variant.Type = prop.type
	
	var writer_callable := Callable() # Initialize with invalid Callable
	
	# --- Special Cases First ---
	# Add other special cases here if needed (e.g., Option<T> fields if handled generically later)
	if prop.class_name == &"Option":
		writer_callable = Callable(self, "write_option")
	elif prop.class_name == &"RustEnum":
		writer_callable = Callable(self, "write_rust_enum")
	
	# --- Generic Type Handling (if not a special case) ---
	elif prop_type == TYPE_ARRAY:
		# Handle arrays
		writer_callable = Callable(self, "write_array")
	elif NATIVE_ARRAYLIKE_TYPES.has(prop_type):
		# Handle array-like native types e.g. Vector2, Vector4i, Quaternion, Color
		writer_callable = Callable(self, "write_native_arraylike")
	else:
		# Handle non-array, non-special-case properties
		# 1. Check for primitive writer with BSATN type
		if not bsatn_type_str.is_empty():
			writer_callable = _get_primitive_writer_from_bsatn_type(bsatn_type_str)
			if not writer_callable.is_valid() and debug_mode:
				# BSATN type exists but doesn't map to a primitive reader
				push_warning("Unknown 'bsatn_type' metadata value: '%s' for property '%s'. Falling back to default type." % [bsatn_type_str, prop_name])

		# 2. Fallback to default reader based on property's Variant.Type if metadata didn't provide a valid reader
		if not writer_callable.is_valid():
			match prop_type:
				TYPE_NIL: _set_error("Cannot serialize null argument.")
				TYPE_BOOL: writer_callable = Callable(self, "write_bool")
				TYPE_INT: 
					match bsatn_type_str:
						&"u8": writer_callable = Callable(self, "write_u8")
						&"u16": writer_callable = Callable(self, "write_u16_le")
						&"u32": writer_callable = Callable(self, "write_u32_le")
						&"u64": writer_callable = Callable(self, "write_u64_le")
						&"i8": writer_callable = Callable(self, "write_i8")
						&"i16": writer_callable = Callable(self, "write_i16_le")
						&"i32": writer_callable = Callable(self, "write_i32_le")
						_: writer_callable = Callable(self, "write_i64_le") #Default i64
				TYPE_FLOAT: 
					match bsatn_type_str:
						&"f64": writer_callable = Callable(self, "write_f64_le")
						_: writer_callable = Callable(self, "write_f32_le") # Default f32
				TYPE_STRING: writer_callable = Callable(self, "write_string_with_u32_len")
				TYPE_PACKED_BYTE_ARRAY: writer_callable = Callable(self, "write_vec_u8") # Default Vec<u8> for arguments
				TYPE_OBJECT:
					writer_callable = Callable(self, "write_nested_resource") # Handle nested resources
				# TYPE_ARRAY, and native array-like types (TYPE_VECTOR2, TYPE_QUATERNION, etc.) are handled above
				_:
					# Writer remains invalid for unsupported types
					pass
	
	# --- Debug Print (Optional) ---
	if debug_mode:
		var type_name = prop.class_name if prop.class_name != &"" else (type_string(prop.type) if prop.type != TYPE_MAX else "Unknown")
		print("DEBUG: _get_writer_callable: For '%s' of type '%s', returning: %s" % [prop.name, type_name, writer_callable.get_method() if writer_callable.is_valid() else "INVALID"])
	# --- End Debug ---
	
	return writer_callable

func _call_writer_callable(writer_callable: Callable, value: Variant, bsatn_type: String, prop: Dictionary) -> void:
	var method_name = writer_callable.get_method()
	# Check if the method requires the bsatn type
	# Typically needed for recursive or context-aware writers.
	match method_name:
		"write_array", "write_option", "write_native_arraylike", "write_nested_resource":
			writer_callable.call(value, bsatn_type, prop) # Pass full context
		_:
			# Standard primitive/simple writers usually only need the value.
			writer_callable.call(value)

#Helper to generate a zero struct from a bsatn type
func _generate_default_type(bsatn_type_name: String) -> Variant:
	var bsatn_type_str := str(bsatn_type_name).to_lower()
	match bsatn_type_str:
		&"i8", &"i16", &"i32", &"i64", &"u8", &"u16", &"u32", &"u64":
			return int(0)
		&"f32", &"f64":
			return float(0)
		&"bool": return false
		&"string": return ""
		&"vector2": return Vector2.ZERO
		&"vector2i": return Vector2i.ZERO
		&"vector3": return Vector3.ZERO
		&"vector3i": return Vector3i.ZERO
		&"vector4": return Vector4.ZERO
		&"vector4i": return Vector4i.ZERO
		&"color": return Color.BLACK
		&"quaternion": return Quaternion.IDENTITY
		_: return null

## Helper function to serialize a value based on BSATN type string.
## Assumes bsatn_type_str is already to_lower() if it's from metadata.
func _write_value_from_bsatn_type(value: Variant, bsatn_type_str: String, context_prop_name_for_prototype: StringName) -> bool:
	var value_type = typeof(value)
	
	# 1. Try primitive writer (expects lowercase bsatn_type_str) if not an array
	if value_type != TYPE_ARRAY:
		var primitive_writer := _get_primitive_writer_from_bsatn_type(bsatn_type_str)
		if primitive_writer.is_valid():
			primitive_writer.call(value)
			if has_error(): return false
			return true
	
	# 2. Create a temporary "prototype" dictionary for the value
	var value_class_name = _get_value_class_name(value)
	var prop_sim = {
		"name": context_prop_name_for_prototype,
		"type": value_type,
		"class_name": value_class_name,
		"usage": PROPERTY_USAGE_STORAGE,
		"hint": 0,
		"hint_string": ""
	}
	
	# 3. Determine from value type and bsatn type string
	var writer_callable := _get_writer_callable_for_property(prop_sim, bsatn_type_str)
	
	if not writer_callable.is_valid() and not has_error():
		_set_error("Unsupported BSATN type '%s' or missing writer for value '%s'" % [bsatn_type_str, prop_sim.class_name])
	
	if has_error(): return false
	
	# Call the determined writer function.
	if writer_callable.get_object() == self:
		_call_writer_callable(writer_callable, value, bsatn_type_str, prop_sim)
	else:
		# Should not happen with Callables created above, but handle defensively
		_set_error("Internal error: Invalid writer callable.")
	
	return not has_error()

func _create_serialization_plan(script: Script, resource: Resource) -> Array:
	if debug_mode: print("DEBUG: Creating serialization plan for script: %s" % script.resource_path)
	
	var plan = []
	var properties: Array = script.get_script_property_list()
	for prop in properties:
		if not (prop.usage & PROPERTY_USAGE_STORAGE):
			continue

		var prop_name: StringName = prop.name
		var bsatn_type_str: StringName = &""
		var meta_key := "bsatn_type_" + prop_name
		if resource.has_meta(meta_key):
			# This metadata applies to the field itself, or to the *elements* if it's an array.
			bsatn_type_str = str(resource.get_meta(meta_key)).to_lower()
		
		var writer_callable: Callable = _get_writer_callable_for_property(prop, bsatn_type_str)
		
		if not writer_callable.is_valid():
			_set_error("Unsupported property or missing writer for '%s' in script '%s'" % [prop_name, script.resource_path])
			_serialization_plan_cache[script] = []
			return []
			
		plan.append({
			"name": prop_name,
			"type": prop.type,
			"writer": writer_callable,
			"bsatn_type": bsatn_type_str,
			"prop_dict": prop
		})
	
	_serialization_plan_cache[script] = plan
	return plan

# Serializes the fields of a Resource instance sequentially.
func _serialize_resource_fields(resource: Resource) -> bool:
	var script := resource.get_script()
	if not resource or not script:
		_set_error("Cannot serialize fields of null or scriptless resource"); return false
	
	if resource is RustEnum:
		write_rust_enum(resource)
		return true
	
	var plan = _serialization_plan_cache.get(script)
	if plan == null:
		plan = _create_serialization_plan(script, resource)
		if has_error(): return false
	
	for instruction in plan:
		var value = resource.get(instruction.name) # Get the actual value from the resource instance
		
		if instruction.writer.get_object() == self:
			_call_writer_callable(instruction.writer, value, instruction.bsatn_type, instruction.prop_dict)
		else: 
			_set_error("Internal error: Invalid writer callable for property '%s' in '%s'." % [instruction.name, resource.get_script().get_global_name() if resource else "Unknown"])
			return false
		
		if has_error():
			if not _last_error.contains(str(instruction.name)):
				var existing_error = get_last_error()
				_set_error("Failed writing value for property '%s' in '%s'. Cause: %s" % [instruction.name, resource.get_script().get_global_name() if resource else "Unknown", existing_error])
			return false
	
	return true # All fields serialized successfully

# --- Argument Serialization Helpers ---

## Serializes an array of arguments into a single PackedByteArray block.
func _serialize_arguments(args_array: Array, bsatn_types: Array) -> PackedByteArray:
	var args_spb := StreamPeerBuffer.new(); args_spb.big_endian = false
	var original_main_spb := _spb; _spb = args_spb # Temporarily redirect writes
	
	for i in range(args_array.size()):
		var arg_value = args_array[i]
		var bsatn_type = ""
		if i < bsatn_types.size():
			bsatn_type = bsatn_types[i]
			
		if debug_mode:
			var arg_type_name: String = _get_value_class_name(arg_value)
			print("DEBUG: _serialize_arguments: Serializing argument at %d from '%s' to bsatn type '%s'" % [i, arg_type_name, bsatn_type])
		
		if not _write_argument_value(arg_value, bsatn_type, "arg[%s]" % i): # Use dedicated argument writer
			# Error should be set by _write_argument_value
			push_error("Failed to serialize argument %d." % i) # Add context
			_spb = original_main_spb # Restore main buffer
			return PackedByteArray() # Return empty on error

	_spb = original_main_spb # Restore main buffer
	return args_spb.data_array if not has_error() else PackedByteArray()

## Helper to write a single *argument* value.
func _write_argument_value(value, bsatn_type: String = "", context_prop_name_for_error: StringName = &"") -> bool:
	# 1. Create a temporary "prototype" dictionary for the argument
	var value_type = typeof(value)
	var value_class_name = _get_value_class_name(value)
	var prop_sim = {
		"name": context_prop_name_for_error,
		"type": value_type,
		"class_name": value_class_name,
		"usage": PROPERTY_USAGE_STORAGE,
		"hint": 0,
		"hint_string": ""
	}
	
	var writer_callable := _get_writer_callable_for_property(prop_sim, bsatn_type)
	
	if not writer_callable.is_valid() and not has_error():
		_set_error("Unsupported argument type '%s' or missing writer for '%s' with 'bsatn_type' metadata ('%s')" % [prop_sim.class_name, prop_sim.name, bsatn_type])
	
	if has_error(): return false
	
	# Call the determined writer function.
	if writer_callable.get_object() == self:
		_call_writer_callable(writer_callable, value, bsatn_type, prop_sim)
	else:
		# Should not happen with Callables created above, but handle defensively
		_set_error("Internal error: Invalid writer callable for '%s'" % prop_sim.name)
	
	return not has_error()

# --- Public API ---

# Serializes a complete ClientMessage (variant tag + payload resource fields).
func serialize_client_message(variant_tag: int, payload_resource: Resource) -> PackedByteArray:
	# Reset state
	clear_error()
	_spb.data_array = PackedByteArray()
	_spb.seek(0)

	# 1. Write the message variant tag (u8)
	write_u8(variant_tag)
	if has_error(): return PackedByteArray()

	# 2. Serialize payload resource fields inline after the tag
	if payload_resource != null: # Allow null payload for messages without one
		if not _serialize_resource_fields(payload_resource):
			if not has_error(): _set_error("Failed to serialize payload resource for tag %d" % variant_tag)
			return PackedByteArray()
	else:
		# No payload to serialize
		_set_error("Cannot serialize a null payload resource for tag %d" % variant_tag)

	return _spb.data_array if not has_error() else PackedByteArray()
