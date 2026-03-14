@tool
class_name SpacetimeSchemaParser

const GDNATIVE_PRIMITIVE_TYPES: Dictionary[String, String] = {
	"I8": "int",
	"I16": "int",
	"I32": "int",
	"I64": "int",
	"U8": "int",
	"U16": "int",
	"U32": "int",
	"U64": "int",
	"F32": "float",
	"F64": "float",
	"String": "String",
	"Bool": "bool",
	"Nil": "null", # For Option<()>
}

const GDNATIVE_ARRAYLIKE_TYPES: Dictionary[String, String] = {
	"Vector4": "Vector4",
	"Vector4I": "Vector4i",
	"Vector3": "Vector3",
	"Vector3I": "Vector3i",
	"Vector2": "Vector2",
	"Vector2I": "Vector2i",
	"Quaternion": "Quaternion",
	"Color": "Color",
}

const GDNATIVE_DICTLIKE_TYPES: Dictionary[String, String] = {
	"Plane": "Plane",
}

const DEFAULT_TYPE_MAP: Dictionary[String, String] = {
	"__identity__": "PackedByteArray",
	"__connection_id__": "PackedByteArray",
	"__timestamp_micros_since_unix_epoch__": "int",
	"__time_duration_micros__": "int",
	"U128": "PackedByteArray",
}

const DEFAULT_META_TYPE_MAP: Dictionary[String, String] = {
	"I8": "i8",
	"I16": "i16",
	"I32": "i32",
	"I64": "i64",
	"U8": "u8",
	"U16": "u16",
	"U32": "u32",
	"U64": "u64",
	"U128": "u128",
	"F32": "f32",
	"F64": "f64",
	"String": "string",         # For BSATN, e.g. option_string or vec_String (if Option<Array<String>>)
	"Bool": "bool",             # For BSATN, e.g. option_bool
	"Nil": "nil",               # For BSATN Option<()>
	"Vector4": "vector4",       # For BSATN, e.g. vector4[f32,f32,f32,f32]
	"Vector4I": "vector4i",     # For BSATN, e.g. vector4i[i32,i32,i32,i32]
	"Vector3": "vector3",       # For BSATN, e.g. vector3[f32,f32,f32]
	"Vector3I": "vector3i",     # For BSATN, e.g. vector3i[i32,i32,i32]
	"Vector2": "vector2",       # For BSATN, e.g. vector2[f32,f32]
	"Vector2I": "vector2i",     # For BSATN, e.g. vector2i[i32,i32]
	"Quaternion": "quaternion", # For BSATN, e.g. quaternion[f32,f32,f32,f32]
	"Color": "color",           # For BSATN, e.g. color[f32,f32,f32,f32]
	"__identity__": "identity",
	"__connection_id__": "connection_id",
	"__timestamp_micros_since_unix_epoch__": "i64",
	"__time_duration_micros__": "i64",
}

static func parse_schema(p_schema: Dictionary, module_name: String) -> SpacetimeParsedSchema:
	var type_map: Dictionary[String, String] = DEFAULT_TYPE_MAP.duplicate() as Dictionary[String, String]
	type_map.merge(GDNATIVE_PRIMITIVE_TYPES); type_map.merge(GDNATIVE_ARRAYLIKE_TYPES); type_map.merge(GDNATIVE_DICTLIKE_TYPES)
	var meta_type_map = DEFAULT_META_TYPE_MAP.duplicate()


	var sections: Array = p_schema.get("sections",{})
	var schema_typespace: Array
	var schema_types_raw: Array
	var schema_tables: Array
	var schema_reducers: Array
	var schema_procedures: Array
	var schema_views: Array
	var schema_shedules: Array
	var schema_life_cycle_reducers: Array
	var schema_explicit_names: Array

	for section: Dictionary in sections:
		if section.has("Typespace"):
			schema_typespace = section.get("Typespace").get("types",[])
		elif section.has("Types"):
			schema_types_raw = section.get("Types")
		elif section.has("Tables"):
			schema_tables = section.get("Tables")
		elif section.has("Reducers"):
			schema_reducers = section.get("Reducers")
		elif section.has("Procedures"):
			schema_procedures = section.get("Procedures")
		elif section.has("Views"):
			schema_views = section.get("Views")
		elif section.has("Schedules"):
			schema_shedules = section.get("Schedules")
		elif section.has("LifeCycleReducers"):
			schema_life_cycle_reducers = section.get("LifeCycleReducers")
		elif section.has("ExplicitNames"):
			schema_explicit_names = section.get("ExplicitNames").get("entries")

	var parsed_schema := SpacetimeParsedSchema.new()
	parsed_schema.module = module_name.to_pascal_case()

	schema_types_raw.sort_custom(func(a, b): return a.get("ty", -1) < b.get("ty", -1))

	var parsed_types_list: Array[Dictionary] = []
	for type_info in schema_types_raw:
		var type_name: String = type_info.get("source_name", {}).get("source_name", null)
		if not type_name:
			SpacetimePlugin.print_err("Invalid schema: Type name not found for type: %s" % type_info)
			return parsed_schema
		var type_data := {"name": type_name}
		if _is_gd_native(type_name):
			_set_gd_native(type_name, type_data)

		var ty_idx := int(type_info.get("ty", -1))
		if ty_idx == -1:
			SpacetimePlugin.print_err("Invalid schema: Type 'ty' not found for type: %s" % type_info)
			return parsed_schema
		if ty_idx >= schema_typespace.size():
			SpacetimePlugin.print_err("Invalid schema: Type index %d out of bounds for typespace (size %d) for type %s" % [ty_idx, schema_typespace.size(), type_name])
			return parsed_schema

		var current_type_definition = schema_typespace[ty_idx]
		var struct_def: Dictionary = current_type_definition.get("Product", {})
		var sum_type_def: Dictionary = current_type_definition.get("Sum", {})
		if struct_def:
			var struct_elements: Array[Dictionary] = []
			for el in struct_def.get("elements", []):
				var data = {
					"name": el.get("name", {}).get("some", null),
				}

				var type = _parse_field_type(el.get("algebraic_type", {}), data, schema_types_raw)
				if not type.is_empty():
					data["type"] = type
				struct_elements.append(data)
			type_data["struct"] = struct_elements
			if not type_data.has("gd_native"):
				type_map[type_name] = module_name.to_pascal_case() + type_name.to_pascal_case()
				meta_type_map[type_name] = module_name.to_pascal_case() + type_name.to_pascal_case()
			elif not _validate_gd_native(type_name, type_data):
				# Error should be printed in _validate_gd_native
				return parsed_schema
			parsed_types_list.append(type_data)
		elif sum_type_def:
			var parsed_variants := []
			type_data["is_sum_type"] = _is_sum_type(sum_type_def)
			for v in sum_type_def.get("variants", []):
				var variant_data := { "name": v.get("name",{}).get("some", null) }
				var type = _parse_sum_type(v.get("algebraic_type", {}), variant_data, schema_types_raw)
				if not type.is_empty():
					variant_data["type"] = type
				parsed_variants.append(variant_data)
			type_data["enum"] = parsed_variants
			parsed_types_list.append(type_data)

			if not type_data.get("is_sum_type"):
				meta_type_map[type_name] = "u8"
				type_map[type_name] = "%sModuleClient.Types.%s" % [module_name.to_pascal_case(), type_name.to_pascal_case()]
			else:
				type_map[type_name] = module_name.to_pascal_case() + type_name.to_pascal_case()
				meta_type_map[type_name] = module_name.to_pascal_case() + type_name.to_pascal_case()
		else:
			if not type_data.has("gd_native"):
				if type_map.has(type_name) and not _is_gd_native(type_name):
					type_data["struct"] = []
					parsed_types_list.append(type_data)
				else:
					SpacetimePlugin.print_log("Type '%s' has no Product/Sum definition in typespace and is not GDNative. Skipping." % type_name)

	for parsed_type in parsed_types_list:
		if not parsed_type.has("struct"):
			continue
		for field_type in parsed_type.get("struct", []):
			var type_name = field_type.get("type", null)
			if not type_name or GDNATIVE_PRIMITIVE_TYPES.has(type_name) or DEFAULT_TYPE_MAP.has(type_name):
				continue

			var type_idx = 0
			var type_found = false
			for pt in parsed_types_list:
				if pt.name == type_name:
					type_found = true
					break
				type_idx += 1

			if type_found:
				field_type["type_idx"] = type_idx

	var parsed_tables_list: Array[Dictionary] = []

	for table_info in schema_tables:
		var table_name_str: String = table_info.get("source_name", null)
		var ref_idx_raw = table_info.get("product_type_ref", null)
		if ref_idx_raw == null or table_name_str == null:
			SpacetimePlugin.print_err("Skipped table with: ref_idx_raw, table_name_str")
			continue
		var ref_idx = int(ref_idx_raw)

		var target_type_def = null
		var target_type_idx = 0
		var original_type_name_for_table = "UNKNOWN_TYPE_FOR_TABLE"
		if ref_idx < schema_types_raw.size():
			original_type_name_for_table = schema_types_raw[ref_idx].get("source_name", {}).get("source_name")
			for pt in parsed_types_list:
				if pt.name == original_type_name_for_table:
					target_type_def = pt
					break
				target_type_idx += 1

		if target_type_def == null or not target_type_def.has("struct"):
			SpacetimePlugin.print_err("Table '%s' refers to an invalid or non-struct type (index %s in original schema, name %s)." % [table_name_str, str(ref_idx), original_type_name_for_table if original_type_name_for_table else "N/A"])
			continue

		var table_data := {
			"name": table_name_str,
			"type_idx": target_type_idx
		}

		if not target_type_def.has("source_name"):
			target_type_def.table_names = []
		target_type_def.table_names.append(table_name_str)
		target_type_def.table_name = table_name_str

		var primary_key_indices: Array = table_info.get("primary_key", [])
		if primary_key_indices.size() == 1:
			var pk_field_idx = int(primary_key_indices[0])
			if pk_field_idx < target_type_def.struct.size():
				var pk_field_name: String = target_type_def.struct[pk_field_idx].name
				table_data.primary_key = pk_field_idx
				table_data.primary_key_name = pk_field_name
				target_type_def.primary_key = pk_field_idx
				target_type_def.primary_key_name = pk_field_name
			else:
				SpacetimePlugin.print_err("Primary key index %d out of bounds for table %s (struct size %d)" % [pk_field_idx, table_name_str, target_type_def.struct.size()])

		var parsed_unique_indexes: Array[Dictionary] = []
		var constraints_def = table_info.get("constraints", [])
		for constraint_def in constraints_def:
			var constraint_name_str: String = constraint_def.get("source_name", {}).get("some", null)
			var column_indices: Array = constraint_def.get("data", {}).get("Unique", {}).get("columns", [])
			if column_indices.size() != 1 or constraint_name_str == null: continue

			var unique_field_idx = int(column_indices[0])
			if unique_field_idx < target_type_def.struct.size():
				var unique_index: Dictionary = target_type_def.struct[unique_field_idx].duplicate()
				unique_index.constraint_name = constraint_name_str
				parsed_unique_indexes.append(unique_index)
			else:
				SpacetimePlugin.print_err("Unique field index %d out of bounds for table %s (struct size %d)" % [unique_field_idx, table_name_str, target_type_def.struct.size()])

		table_data.unique_indexes = parsed_unique_indexes

		var is_public = true
		if not target_type_def.has("is_public"):
			target_type_def.is_public = []
		if table_info.get("table_access", {}).has("Private"):
			is_public = false

		table_data.is_public = is_public
		target_type_def.is_public.append(is_public)

		table_data.is_event = table_info.get("is_event", false)

		parsed_tables_list.append(table_data)

	var parsed_reducers_list: Array[Dictionary] = []
	for reducer_info in schema_reducers:
		if reducer_info.visibility.has("Private"): continue
		var r_name = reducer_info.get("source_name", null)
		if r_name == null:
			SpacetimePlugin.print_err("Reducer found with no name: %s" % [reducer_info])
			continue
		var reducer_data: Dictionary = {"name": r_name}

		var reducer_raw_params = reducer_info.get("params", {}).get("elements", [])
		var reducer_params = []
		for raw_param in reducer_raw_params:
			var data = {"name": raw_param.get("name", {}).get("some", null)}
			var type = _parse_field_type(raw_param.get("algebraic_type", {}), data, schema_types_raw)
			data["type"] = type

			var type_idx = 0
			var type_found = false
			if type and not (GDNATIVE_PRIMITIVE_TYPES.has(type) or DEFAULT_TYPE_MAP.has(type)):
				for pt in parsed_types_list:
					if pt.name == type:
						type_found = true
						break
					type_idx += 1

			if type_found:
				data["type_idx"] = type_idx
			reducer_params.append(data)
		reducer_data["params"] = reducer_params
		prints("reducer:", reducer_data,"\n","\n")
		parsed_reducers_list.append(reducer_data)

	var parsed_procedure_list:Array[Dictionary] = []
	for procedure_info in schema_procedures:
		if procedure_info.visibility.has("Private"): continue
		var r_name = procedure_info.get("source_name", null)
		if r_name == null:
			SpacetimePlugin.print_err("Reducer found with no name: %s" % [procedure_info])
			continue
		var procedure_data: Dictionary = {"name": r_name}

		var procedure_raw_params = procedure_info.get("params", {}).get("elements", [])
		var procedure_params = []
		for raw_param in procedure_raw_params:
			var data = {"name": raw_param.get("name", {}).get("some", null)}
			var type = _parse_field_type(raw_param.get("algebraic_type", {}), data, schema_types_raw)
			data["type"] = type

			var type_idx = 0
			var type_found = false
			if type and not (GDNATIVE_PRIMITIVE_TYPES.has(type) or DEFAULT_TYPE_MAP.has(type)):
				for pt in parsed_types_list:
					if pt.name == type:
						type_found = true
						break
					type_idx += 1
			if type_found:
				data["type_idx"] = type_idx
			procedure_params.append(data)
		procedure_data["params"] = procedure_params
		var procedure_raw_return = procedure_info.get("return_type")
		var data := {}
		var type = _parse_field_type(procedure_raw_return, data,schema_types_raw)
		prints(type,"\n", data,"\n", procedure_raw_return,"\n",procedure_data,"\n\n")

		parsed_procedure_list.append(procedure_data)


	for view :Dictionary in schema_views:
		var name :String = view["source_name"]
		var return_type_dict = view["return_type"]
		var type_index:int
		var return_type:Dictionary
		SpacetimePlugin.print_log("parsing return type for view: %s"% name)
		if return_type_dict.get("Array", {}).is_empty():
			if not return_type_dict.get("Sum",{}).is_empty():
				if return_type_dict.get("Sum").get("variants").size() == 2:
					var option = return_type_dict.get("Sum").get("variants")
					if not option[0].get("name",{}).is_empty():
						if option[0].get("name").get("some") == "some":
							type_index = int(option[0].get("algebraic_type").get("Ref"))
							return_type = parsed_types_list[type_index]
			else:
				SpacetimePlugin.print_err("view return type not yet supported in the parser: %s" % [return_type_dict])
				continue
		else:
			type_index = int(return_type_dict["Array"]["Ref"])
			return_type = parsed_types_list[type_index]
		if return_type.is_empty():
			SpacetimePlugin.print_err("view return type not found: %s" % [return_type_dict])
			continue
		if return_type.get("table_names", []).is_empty():
			return_type = {
				"name": return_type["name"],
				"struct": return_type["struct"],
				&"table_names": [
					"%s" % name
				],
				&"table_name": "%s"% name,
				&"primary_key": 0,
				&"primary_key_name": "",
				&"is_public": [
					true
				]
			}
		else:
			var type_table_list = return_type["table_names"]
			type_table_list.append(name)
			return_type["table_names"] = type_table_list
			var is_public_list = return_type["is_public"]
			is_public_list.append(true)
			return_type["is_public"] = is_public_list
		parsed_types_list[type_index] = return_type

		var tables_of_same_type : Array = parsed_tables_list.filter(func(table:Dictionary): return table.get("type_idx", -1) == type_index)
		var new_table_dict : Dictionary
		if tables_of_same_type.is_empty():
			new_table_dict = {
			"name": name,
			"type_idx": type_index,
			"primary_key": 0,
			"primary_key_name": "",
			"unique_indexes": [],
			"is_public": true
			}
		else:
			new_table_dict = tables_of_same_type[0].duplicate()
			new_table_dict["name"] = name
			new_table_dict["is_public"] = true
		parsed_tables_list.append(new_table_dict)

	SpacetimePlugin.print_log("Schema parser finished")
	parsed_schema.types = parsed_types_list
	parsed_schema.tables = parsed_tables_list
	parsed_schema.reducers = parsed_reducers_list
	parsed_schema.procedures = parsed_procedure_list
	parsed_schema.type_map = type_map
	parsed_schema.meta_type_map = meta_type_map
	parsed_schema.typespace = schema_typespace
	return parsed_schema

static func _is_gd_native(type_name: String) -> bool:
	return GDNATIVE_PRIMITIVE_TYPES.has(type_name) or GDNATIVE_ARRAYLIKE_TYPES.has(type_name) or GDNATIVE_DICTLIKE_TYPES.has(type_name)

static func _set_gd_native(type_name: String, type_data) -> void:
	type_data["gd_native"] = true

	if GDNATIVE_PRIMITIVE_TYPES.has(type_name):
		type_data["gd_primitive"] = true
	elif GDNATIVE_ARRAYLIKE_TYPES.has(type_name):
		type_data["gd_arraylike"] = true
	elif GDNATIVE_DICTLIKE_TYPES.has(type_name):
		type_data["gd_dictlike"] = true

static func _validate_gd_native(type_name: String, type_data) -> bool:
	if type_data.has("gd_primitive"):
		return true

	if type_data.has("gd_arraylike"):
		var expected_struct_size = 0
		var expected_primitive_type = "float"
		match type_name:
			"Vector4": expected_struct_size = 4
			"Vector4I": expected_struct_size = 4; expected_primitive_type = "int"
			"Vector3": expected_struct_size = 3
			"Vector3I": expected_struct_size = 3; expected_primitive_type = "int"
			"Vector2": expected_struct_size = 2
			"Vector2I": expected_struct_size = 2; expected_primitive_type = "int"
			"Quaternion": expected_struct_size = 4
			"Color": expected_struct_size = 4
			_:
				SpacetimePlugin.print_err("Unsupported array-like GD native type: %s" % [type_name])
				return false

		if type_data.struct.size() != expected_struct_size:
			SpacetimePlugin.print_err("Array-like GD native type '%s' expected length of %d but is %d" % [type_name, expected_struct_size, type_data.struct.size()])
			return false

		for element in type_data.struct:
			var primitive_type = GDNATIVE_PRIMITIVE_TYPES.get(element.type, null)
			if not primitive_type:
				SpacetimePlugin.print_err("Property '%s' in array-like GD native type '%s' must be a primitive type" % [element.name, type_name])
				return false

			if primitive_type != expected_primitive_type:
				SpacetimePlugin.print_err("Property '%s' in array-like GD native type '%s' should map to a '%s' primitive type" % [element.name, type_name, expected_primitive_type])
				return false

	if type_data.has("gd_dictlike"):
		# TODO: Validate Plane type
		pass

	return true

static func _is_sum_type(sum_def) -> bool:
	var variants = sum_def.get("variants", [])
	for variant in variants:
		var type = variant.get("algebraic_type", {})
		if not type.has("Product"):
			return true
		var elements = type.Product.get("elements", [])
		if elements.size() > 0:
			return true
	return false

static func _is_sum_option(sum_def) -> bool:
	var variants = sum_def.get("variants", [])
	if variants.size() != 2:
		return false

	var name1 = variants[0].get("name", {}).get("some", "")
	var name2 = variants[1].get("name", {}).get("some", "")

	var found_some = false
	var found_none = false
	var none_is_unit = false

	for v_idx in range(variants.size()):
		var v_name = variants[v_idx].get("name", {}).get("some", "")
		if v_name == "some":
			found_some = true
		elif v_name == "none":
			found_none = true
			var none_variant_type = variants[v_idx].get("algebraic_type", {})
			if none_variant_type.has("Product") and none_variant_type.Product.get("elements", []).is_empty():
				none_is_unit = true
			elif none_variant_type.is_empty():
				none_is_unit = true


	return found_some and found_none and none_is_unit

# Recursively parse a field type
static func _parse_field_type(field_type: Dictionary, data: Dictionary, schema_types: Array) -> String:
	if field_type.has("Array"):
		var nested_type = data.get("nested_type", [])
		nested_type.append(&"Array")
		data["nested_type"] = nested_type
		if data.has("is_option"):
			data["is_array_inside_option"] = true
		else:
			data["is_array"] = true
		field_type = field_type.Array
		return _parse_field_type(field_type, data, schema_types)
	elif field_type.has("Product"):
		return field_type.Product.get("elements", [])[0].get('name', {}).get('some', null)
	elif field_type.has("Sum"):
		if _is_sum_option(field_type.Sum):
			var nested_type = data.get("nested_type", [])
			nested_type.append(&"Option")
			data["nested_type"] = nested_type
			if data.has("is_array"):
				data["is_option_inside_array"] = true
			else:
				data["is_option"] = true
		field_type = field_type.Sum.variants[0].get('algebraic_type', {})
		return _parse_field_type(field_type, data, schema_types)
	elif field_type.has("Ref"):
		return schema_types[field_type.Ref].get("source_name", {}).get("source_name", null)
	else:
		return field_type.keys()[0]

# Recursively parse a sum type
static func _parse_sum_type(variant_type: Dictionary, data: Dictionary, schema_types: Array) -> String:
	if variant_type.has("Array"):
		var nested_type = data.get("nested_type", [])
		nested_type.append(&"Array")
		data["nested_type"] = nested_type
		if data.has("is_option"):
			data["is_array_inside_option"] = true
		else:
			data["is_array"] = true
		variant_type = variant_type.Array
		return _parse_sum_type(variant_type, data, schema_types)
	elif variant_type.has("Product"):
		var variant_type_array = variant_type.Product.get("elements", [])
		if variant_type_array.size() >= 1:
			return variant_type_array[0].get('name', {}).get('some', null)
		else:
			return ""
	elif variant_type.has("Sum"):
		if _is_sum_option(variant_type.Sum):
			var nested_type = data.get("nested_type", [])
			nested_type.append(&"Option")
			data["nested_type"] = nested_type
			if data.has("is_array"):
				data["is_option_inside_array"] = true
			else:
				data["is_option"] = true
		variant_type = variant_type.Sum.variants[0].get('algebraic_type', {})
		return _parse_sum_type(variant_type, data, schema_types)
	elif variant_type.has("Ref"):
		return schema_types[variant_type.Ref].get("source_name", {}).get("source_name", null)
	else:
		return variant_type.keys()[0]
