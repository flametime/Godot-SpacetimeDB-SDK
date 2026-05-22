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
	"Nil": "null",
}

const GDNATIVE_ARRAYLIKE_TYPES: Dictionary[String, String] = {
	"Vector4": "Vector4",
	"Vector4I": "Vector4i",
	"Vector4i": "Vector4i",
	"Vector3": "Vector3",
	"Vector3I": "Vector3i",
	"Vector3i": "Vector3i",
	"Vector2": "Vector2",
	"Vector2I": "Vector2i",
	"Vector2i": "Vector2i",
	"Quaternion": "Quaternion",
	"Color": "Color",
}

const GDNATIVE_DICTLIKE_TYPES: Dictionary[String, String] = {
	"Plane": "Plane",
}

const BUILTIN_TYPE_NAMES: Dictionary[String, bool] = {
	"__identity__": true,
	"__connection_id__": true,
	"__timestamp_micros_since_unix_epoch__": true,
	"__time_duration_micros__": true,
	"U128": true,
}

static func parse_schema(p_schema: Dictionary, module_name: String) -> SpacetimeParsedSchema:
	var module_pascal := module_name.to_pascal_case()

	var sections: Dictionary = _collect_sections(p_schema.get("sections", []))
	var schema_typespace: Array = _section_typespace(sections)
	var schema_types_raw: Array = sections.get("Types", [])
	var schema_tables: Array = sections.get("Tables", [])
	var schema_reducers: Array = sections.get("Reducers", [])
	var schema_procedures: Array = sections.get("Procedures", [])
	var schema_views: Array = sections.get("Views", [])

	var parsed_schema := SpacetimeParsedSchema.new()
	parsed_schema.module = module_pascal

	if schema_types_raw.is_empty():
		return parsed_schema

	schema_types_raw.sort_custom(
		func(a, b): return int(a.get("ty", -1)) < int(b.get("ty", -1))
	)

	var parsed_types_list: Array[Dictionary] = []
	for type_info in schema_types_raw:
		var type_name := module_pascal+ _source_name(type_info)
		if type_name.is_empty():
			SpacetimePlugin.print_err(
				"Invalid schema: Type name not found for type: %s" % type_info
			)
			return parsed_schema

		var type_data: Dictionary = {
			"name": _resolve_godot_type_hint(type_name, module_pascal),
			"godot_type_hint": _resolve_godot_type_hint(type_name, module_pascal),
		}
		if _is_gd_native(type_name):
			_set_gd_native(type_name, type_data)

		var ty_idx := int(type_info.get("ty", -1))
		if ty_idx < 0:
			SpacetimePlugin.print_err(
				"Invalid schema: Type 'ty' not found for type: %s" % type_info
			)
			return parsed_schema
		if ty_idx >= schema_typespace.size():
			SpacetimePlugin.print_err(
				"Invalid schema: Type index %d out of bounds for typespace (size %d) for type %s"
				% [ty_idx, schema_typespace.size(), type_name]
			)
			return parsed_schema

		var current_type_definition: Dictionary = schema_typespace[ty_idx]
		var struct_def: Dictionary = current_type_definition.get("Product", {})
		var sum_type_def: Dictionary = current_type_definition.get("Sum", {})

		if not struct_def.is_empty():
			type_data["struct"] = _parse_named_elements(
				struct_def.get("elements", []),
				schema_types_raw,
				module_pascal
			)

			if not type_data.has("gd_native") and not _validate_struct_fields(
				type_data.get("struct", []),
				type_name
			):
				return parsed_schema

			parsed_types_list.append(type_data)
		elif not sum_type_def.is_empty():
			type_data["is_sum_type"] = _is_sum_type(sum_type_def)
			type_data["enum"] = _parse_sum_variants(
				sum_type_def.get("variants", []),
				schema_types_raw,
				module_pascal,
				type_data["is_sum_type"]
			)
			parsed_types_list.append(type_data)
		else:
			SpacetimePlugin.print_log(
				"Type '%s' has no Product/Sum definition in typespace. Skipping."
				% type_name
			)

	var type_idx_by_name: Dictionary[String, int] = {}
	for i in range(parsed_types_list.size()):
		type_idx_by_name[parsed_types_list[i].get("name", "")] = i

	for parsed_type in parsed_types_list:
		if not parsed_type.has("struct"):
			continue

		for field_type in parsed_type.get("struct", []):
			var field_type_name: String = field_type.get("type", "")
			if field_type_name.is_empty():
				continue

			var base_type_name := _strip_type_prefixes(field_type_name)
			if _is_known_builtin(base_type_name):
				continue

			if type_idx_by_name.has(base_type_name):
				field_type["type_idx"] = type_idx_by_name[base_type_name]

	var parsed_tables_list: Array[Dictionary] = []
	for table_info in schema_tables:
		var table_name :String= table_info.get("source_name", "").to_snake_case()
		var ref_idx := int(table_info.get("product_type_ref", -1))
		if ref_idx < 0 or table_name.is_empty():
			SpacetimePlugin.print_err("Skipped table with: ref_idx_raw, table_name_str")
			continue

		var original_type_name := ""
		if ref_idx < schema_types_raw.size():
			original_type_name = module_pascal + _source_name(schema_types_raw[ref_idx])

		var target_type_idx := type_idx_by_name.get(original_type_name, -1)
		var target_type_def: Dictionary = (
			parsed_types_list[target_type_idx] if target_type_idx >= 0 else {}
		)

		if target_type_def.is_empty() or not target_type_def.has("struct"):
			SpacetimePlugin.print_err(
				"Table '%s' refers to an invalid or non-struct type (index %s in original schema, name %s)."
				% [
					table_name,
					str(ref_idx),
					original_type_name if not original_type_name.is_empty() else "N/A",
				]
			)
			SpacetimePlugin.print_err(target_type_def)
			continue

		var table_data: Dictionary = {
			"name": module_name + "_"+ table_name,
			"type_idx": target_type_idx,
		}

		if not target_type_def.has("table_names"):
			target_type_def["table_names"] = []
		target_type_def["table_names"].append(table_name)
		target_type_def["table_name"] = table_name

		var primary_key_indices: Array = table_info.get("primary_key", [])
		if primary_key_indices.size() == 1:
			var pk_field_idx := int(primary_key_indices[0])
			if pk_field_idx < target_type_def.struct.size():
				var pk_field_name: String = target_type_def.struct[pk_field_idx].get(
					"name",
					""
				)
				table_data["primary_key"] = pk_field_idx
				table_data["primary_key_name"] = pk_field_name
				target_type_def["primary_key"] = pk_field_idx
				target_type_def["primary_key_name"] = pk_field_name
			else:
				SpacetimePlugin.print_err(
					"Primary key index %d out of bounds for table %s (struct size %d)"
					% [pk_field_idx, table_name, target_type_def.struct.size()]
				)

		var parsed_unique_indexes: Array[Dictionary] = []
		for constraint_def in table_info.get("constraints", []):
			var constraint_name: String = constraint_def.get("source_name", {}).get(
				"some",
				null
			)
			var column_indices: Array = constraint_def.get("data", {}).get(
				"Unique",
				{}
			).get("columns", [])
			if column_indices.size() != 1 or constraint_name == null:
				continue

			var unique_field_idx := int(column_indices[0])
			if unique_field_idx < target_type_def.struct.size():
				var unique_index: Dictionary = target_type_def.struct[unique_field_idx].duplicate()
				unique_index["constraint_name"] = constraint_name
				parsed_unique_indexes.append(unique_index)
			else:
				SpacetimePlugin.print_err(
					"Unique field index %d out of bounds for table %s (struct size %d)"
					% [unique_field_idx, table_name, target_type_def.struct.size()]
				)

		table_data["unique_indexes"] = parsed_unique_indexes

		var is_public: bool = not table_info.get("table_access", {}).has("Private")
		if not target_type_def.has("is_public"):
			target_type_def["is_public"] = []
		target_type_def["is_public"].append(is_public)

		table_data["is_public"] = is_public
		table_data["is_event"] = table_info.get("is_event", false)
		parsed_tables_list.append(table_data)

	var parsed_reducers_list: Array[Dictionary] = _parse_callables(
		schema_reducers,
		schema_types_raw,
		parsed_types_list,
		module_pascal,
		false
	)
	var parsed_procedure_list: Array[Dictionary] = _parse_callables(
		schema_procedures,
		schema_types_raw,
		parsed_types_list,
		module_pascal,
		true
	)

	for view: Dictionary in schema_views:
		var name :String= view.get("source_name", "").to_snake_case()
		var return_type_dict: Dictionary = view.get("return_type", {})
		var type_index :int = 0
		if return_type_dict.has("Product"):
			type_index = return_type_dict.get("Product").get("elements").get(0).get("algebraic_type").get("Ref")
		else:
			type_index = _unwrap_ref_index(return_type_dict)
		if type_index < 0 or type_index >= parsed_types_list.size():
			SpacetimePlugin.print_err("view return type out of range: %s" % [return_type_dict])
			continue

		var return_type: Dictionary = parsed_types_list[type_index]
		if return_type.is_empty():
			SpacetimePlugin.print_err("view return type not found: %s" % [return_type_dict])
			continue

		if return_type.get("table_names", []).is_empty():
			return_type = {
				"name": return_type.get("name", ""),
				"godot_type_hint": return_type.get("godot_type_hint", ""),
				"struct": return_type.get("struct", []),
				"table_names": [name],
				"table_name": name,
				"primary_key": 0,
				"primary_key_name": "",
				"is_public": [true],
			}
		else:
			var type_table_list: Array = return_type["table_names"]
			type_table_list.append(name)
			return_type["table_names"] = type_table_list

			var is_public_list: Array = return_type["is_public"]
			is_public_list.append(true)
			return_type["is_public"] = is_public_list

		parsed_types_list[type_index] = return_type

		var tables_of_same_type: Array = parsed_tables_list.filter(
			func(table: Dictionary) -> bool:
				return int(table.get("type_idx", -1)) == type_index
		)

		var new_table_dict: Dictionary
		if tables_of_same_type.is_empty():
			new_table_dict = {
				"name": module_name + "_"+ name,
				"type_idx": type_index,
				"primary_key": 0,
				"primary_key_name": "",
				"unique_indexes": [],
				"is_public": true,
			}
		else:
			new_table_dict = tables_of_same_type[0].duplicate()
			new_table_dict["name"] = module_name + "_"+ name
			new_table_dict["is_public"] = true

		parsed_tables_list.append(new_table_dict)

	SpacetimePlugin.print_log("Schema parser finished")
	parsed_schema.types = parsed_types_list
	parsed_schema.tables = parsed_tables_list
	parsed_schema.reducers = parsed_reducers_list
	parsed_schema.procedures = parsed_procedure_list
	return parsed_schema

static func _collect_sections(sections: Array) -> Dictionary:
	var out: Dictionary = {}
	for section in sections:
		if section is Dictionary:
			out.merge(section, true)
	return out

static func _section_typespace(sections: Dictionary) -> Array:
	var typespace_section: Variant = sections.get("Typespace", {})
	if typespace_section is Dictionary:
		return typespace_section.get("types", [])
	return []

static func _source_name(value: Variant) -> String:
	if value is Dictionary:
		if value.has("source_name"):
			var source_name = value.get("source_name")
			if source_name is Dictionary:
				return str(source_name.get("source_name", ""))
			return str(source_name)
		if value.has("some"):
			return str(value.get("some", ""))
	return "" if value == null else str(value)

static func _snake_name(value: Variant, module_pascal: StringName) -> String:
	return (module_pascal+ "_"+_source_name(value)).to_snake_case()

static func _variant_name(variant: Dictionary) -> String:
	return str(variant.get("name", {}).get("some", ""))

static func _unwrap_ref_index(node: Dictionary) -> int:
	if node.has("Ref"):
		return int(node["Ref"])
	if node.has("Array"):
		return _unwrap_ref_index(node["Array"])
	if node.has("Sum"):
		for v in node.get("Sum", {}).get("variants", []):
			var idx := _unwrap_ref_index(v.get("algebraic_type", {}))
			if idx >= 0:
				return idx
	return -1

static func _is_known_builtin(type_name: String) -> bool:
	return GDNATIVE_PRIMITIVE_TYPES.has(type_name) \
		or GDNATIVE_ARRAYLIKE_TYPES.has(type_name) \
		or GDNATIVE_DICTLIKE_TYPES.has(type_name) \
		or BUILTIN_TYPE_NAMES.has(type_name)

static func _strip_type_prefixes(type_name: String) -> String:
	var out := type_name
	var changed := true
	while changed:
		changed = false
		for prefix in ["vec_", "opt_", "ret_"]:
			if out.begins_with(prefix):
				out = out.substr(prefix.length())
				changed = true
	return out

static func _resolve_godot_type_hint(type_name: String,module_name: String) -> String:
	if GDNATIVE_PRIMITIVE_TYPES.has(type_name.trim_prefix(module_name)):
		return GDNATIVE_PRIMITIVE_TYPES[type_name.trim_prefix(module_name)]
	if GDNATIVE_ARRAYLIKE_TYPES.has(type_name.trim_prefix(module_name)):
		return GDNATIVE_ARRAYLIKE_TYPES[type_name.trim_prefix(module_name)]
	if GDNATIVE_DICTLIKE_TYPES.has(type_name.trim_prefix(module_name)):
		return GDNATIVE_DICTLIKE_TYPES[type_name.trim_prefix(module_name)]

	match type_name:
		"__identity__":
			return "PackedByteArray"
		"__connection_id__":
			return "PackedByteArray"
		"__timestamp_micros_since_unix_epoch__":
			return "int"
		"__time_duration_micros__":
			return "int"
		"U128":
			return "PackedByteArray"
		_:
			pass
	return "%s" % [type_name.to_pascal_case()]

static func _parse_type_info(
	node: Dictionary,
	schema_types: Array,
	module_pascal: String,
	collect_all := false
) -> Dictionary:
	if node.has("Array"):
		var inner := _parse_type_info(node["Array"], schema_types, module_pascal, collect_all)
		if inner.is_empty():
			return {}

		var inner_type: String = inner.get("type", "")
		var inner_hint: String = inner.get("godot_type_hint", "Variant")
		if inner_type == "U8":
			return {
			"type": "vec_%s" % inner_type,
			"godot_type_hint": "PackedByteArray",
		}
		return {
			"type": "vec_%s" % inner_type,
			"godot_type_hint": "Array[%s]" % inner_hint,
		}

	if node.has("Sum"):
		var sum_def: Dictionary = node["Sum"]

		if _is_sum_option(sum_def):
			var some_variant: Dictionary = sum_def.get("variants", [])[0].get(
				"algebraic_type",
				{}
			)
			var some_info := _parse_type_info(
				some_variant,
				schema_types,
				module_pascal,
				collect_all
			)
			if some_info.is_empty():
				return {}

			return {
				"type": "opt_%s" % some_info.get("type", ""),
				"godot_type_hint": "Option",
			}

		if collect_all and _is_sum_result(sum_def):
			var type_parts: Array[String] = []
			for v in sum_def.get("variants", []):
				var variant_info := _parse_type_info(
					v.get("algebraic_type", {}),
					schema_types,
					module_pascal,
					collect_all
				)
				if variant_info.is_empty():
					continue
				type_parts.append(variant_info.get("type", ""))

			if type_parts.is_empty():
				return {}

			return {
				"type": "ret_%s" % "_".join(type_parts),
				"godot_type_hint": "Variant",
			}

		var first_variant: Dictionary = sum_def.get("variants", [])[0].get(
			"algebraic_type",
			{}
		)
		return _parse_type_info(first_variant, schema_types, module_pascal, collect_all)

	if node.has("Product"):
		var elements: Array = node["Product"].get("elements", [])
		if elements.is_empty():
			return {}

		var element_name := str(elements[0].get("name", {}).get("some", ""))
		if element_name.is_empty():
			return {}

		return {
			"type": element_name,
			"godot_type_hint": _resolve_godot_type_hint(element_name, module_pascal),
		}

	if node.has("Ref"):
		var idx := int(node["Ref"])
		if idx >= 0 and idx < schema_types.size():
			var ref_name := module_pascal + _source_name(schema_types[idx])
			if ref_name.is_empty():
				return {}

			return {
				"type": _resolve_godot_type_hint(ref_name,module_pascal),
				"godot_type_hint": _resolve_godot_type_hint(ref_name,module_pascal),
			}
		return {}

	if node.is_empty():
		return {}

	var keys: Array = node.keys()
	if keys.is_empty():
		return {}

	var fallback_name := str(keys[0])
	return {
		"type": fallback_name,
		"godot_type_hint": _resolve_godot_type_hint(fallback_name,module_pascal),
	}

static func _parse_type_name(
	field_type: Dictionary,
	schema_types: Array,
	module_pascal: String
) -> Dictionary:
	return _parse_type_info(field_type, schema_types, module_pascal, false)

static func _parse_return_data(
	field_type: Dictionary,
	schema_types: Array,
	module_pascal: String
) -> Dictionary:
	var data: Dictionary = _parse_type_info(field_type, schema_types, module_pascal, true)
	if data.is_empty():
		data["type"] = ""
		data["godot_type_hint"] = "Variant"
	return data

static func _parse_named_elements(
	elements: Array,
	schema_types: Array,
	module_pascal: String
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for el in elements:
		var data: Dictionary = {
			"name": el.get("name", {}).get("some", null),
		}
		var type_info := _parse_type_name(
			el.get("algebraic_type", {}),
			schema_types,
			module_pascal
		)
		if not type_info.is_empty():
			data["type"] = type_info.get("type", "")
			data["godot_type_hint"] = type_info.get("godot_type_hint", "")
		out.append(data)
	return out

static func _parse_sum_variants(
	variants: Array,
	schema_types: Array,
	module_pascal: String,
	is_sum_type: bool
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for variant in variants:
		var data: Dictionary = {
			"name": _variant_name(variant),
		}
		var variant_info := _parse_type_info(
			variant.get("algebraic_type", {}),
			schema_types,
			module_pascal,
			is_sum_type
		)
		if not variant_info.is_empty():
			data["type"] = variant_info.get("type", "")
			data["godot_type_hint"] = variant_info.get("godot_type_hint", "")
		out.append(data)
	return out

static func _parse_callables(
	entries: Array,
	schema_types: Array,
	parsed_types: Array,
	module_pascal: String,
	include_return := false
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var type_idx_by_name: Dictionary[String, int] = {}
	for i in range(parsed_types.size()):
		type_idx_by_name[parsed_types[i].get("name", "")] = i

	for info in entries:
		if info.get("visibility", {}).has("Private"):
			continue

		var source_name: String = info.get("source_name", "")
		var name: String = source_name.to_snake_case()
		if name.is_empty():
			SpacetimePlugin.print_err("Callable found with no name: %s" % [info])
			continue

		var callable_data: Dictionary = {"name": name, "source_name": source_name}
		callable_data["params"] = _parse_named_elements(
			info.get("params", {}).get("elements", []),
			schema_types,
			module_pascal
		)

		for param in callable_data["params"]:
			var type_name: String = param.get("type", "")
			if type_name.is_empty():
				continue

			var base_type_name := _strip_type_prefixes(type_name)
			if _is_known_builtin(base_type_name):
				continue

			if type_idx_by_name.has(base_type_name):
				param["type_idx"] = type_idx_by_name[base_type_name]

		if include_return:
			var return_data := _parse_return_data(
				info.get("return_type", {}),
				schema_types,
				module_pascal
			)
			if not return_data.is_empty():
				callable_data["return_type"] = return_data

		out.append(callable_data)

	return out

static func _validate_struct_fields(fields: Array, type_name: String) -> bool:
	if type_name == "Vector4":
		return _validate_vector_like(fields, type_name, 4, "float")
	if type_name == "Vector4I":
		return _validate_vector_like(fields, type_name, 4, "int")
	if type_name == "Vector3":
		return _validate_vector_like(fields, type_name, 3, "float")
	if type_name == "Vector3I":
		return _validate_vector_like(fields, type_name, 3, "int")
	if type_name == "Vector2":
		return _validate_vector_like(fields, type_name, 2, "float")
	if type_name == "Vector2I":
		return _validate_vector_like(fields, type_name, 2, "int")
	if type_name == "Quaternion":
		return _validate_vector_like(fields, type_name, 4, "float")
	if type_name == "Color":
		return _validate_vector_like(fields, type_name, 4, "float")
	return true

static func _validate_vector_like(
	fields: Array,
	type_name: String,
	expected_size: int,
	expected_primitive_type: String
) -> bool:
	if fields.size() != expected_size:
		SpacetimePlugin.print_err(
			"Array-like GD native type '%s' expected length of %d but is %d"
			% [type_name, expected_size, fields.size()]
		)
		return false

	for element in fields:
		var primitive_type := GDNATIVE_PRIMITIVE_TYPES.get(element.get("type", ""), null)
		if not primitive_type:
			SpacetimePlugin.print_err(
				"Property '%s' in array-like GD native type '%s' must be a primitive type"
				% [element.get("name", ""), type_name]
			)
			return false

		if primitive_type != expected_primitive_type:
			SpacetimePlugin.print_err(
				"Property '%s' in array-like GD native type '%s' should map to a '%s' primitive type"
				% [element.get("name", ""), type_name, expected_primitive_type]
			)
			return false

	return true

static func _is_gd_native(type_name: String) -> bool:
	return GDNATIVE_PRIMITIVE_TYPES.has(type_name) \
		or GDNATIVE_ARRAYLIKE_TYPES.has(type_name) \
		or GDNATIVE_DICTLIKE_TYPES.has(type_name)

static func _set_gd_native(type_name: String, type_data) -> void:
	type_data["gd_native"] = true

	if GDNATIVE_PRIMITIVE_TYPES.has(type_name):
		type_data["gd_primitive"] = true
	elif GDNATIVE_ARRAYLIKE_TYPES.has(type_name):
		type_data["gd_arraylike"] = true
	elif GDNATIVE_DICTLIKE_TYPES.has(type_name):
		type_data["gd_dictlike"] = true

static func _is_sum_type(sum_def) -> bool:
	for variant in sum_def.get("variants", []):
		var type = variant.get("algebraic_type", {})
		if not type.has("Product"):
			return true
		if type.Product.get("elements", []).size() > 0:
			return true
	return false

static func _is_sum_option(sum_def) -> bool:
	var variants = sum_def.get("variants", [])
	if variants.size() != 2:
		return false

	var found_some := false
	var found_none := false
	var none_is_unit := false

	for v in variants:
		var v_name = v.get("name", {}).get("some", "")
		if v_name == "some":
			found_some = true
		elif v_name == "none":
			found_none = true
			var none_variant_type = v.get("algebraic_type", {})
			if none_variant_type.has("Product") and none_variant_type.Product.get(
				"elements",
				[]
			).is_empty():
				none_is_unit = true
			elif none_variant_type.is_empty():
				none_is_unit = true

	return found_some and found_none and none_is_unit

static func _is_sum_result(sum_def) -> bool:
	var variants = sum_def.get("variants", [])
	if variants.size() != 2:
		return false
	return variants[0].get("name", {}).get("some", "") == "ok" \
		and variants[1].get("name", {}).get("some", "") == "err"
