@tool
class_name ReducerOutcomeEnum extends RustEnum

enum Options {
	ok,
	okEmpty,
	err,
	internalError,
}

func _init() -> void:
	_reset_metadata()

func _reset_metadata() -> void:
	# Clear old metadata
	for key : StringName in get_meta_list():
		set_meta(key, null)

	set_meta('enum_options', [&'ReducerResultOk', &'', &'vec_U8', &'String'])
	set_meta('bsatn_enum_type', &'ReducerOutcomeEnum')

static func parse_enum_name(i: int) -> String:
	match i:
		0: return &'ok'
		1: return &'okEmpty'
		2: return &'err'
		3: return &'internalError'
		_:
			printerr("Enum does not have value for %d. This is out of bounds." % i)
			return &'Unknown'

func get_ok() -> ReducerResultOk:
	if value != 0:
		printerr("ReducerOutcomeEnum Value is not 'ok' but get_err() got called")
		return null
	return data

func get_err() -> String:
	if value != 2:
		printerr("ReducerOutcomeEnum Value is not 'err' but get_err() got called")
		return ""
	var raw_err : PackedByteArray = data as PackedByteArray
	### for some reason the frist 3 are ")  " and thus get removed
	### TODO: Review after V10 schema codegen changes. it should be the Reducer return specified in the schema
	return raw_err.slice(4).get_string_from_utf8()

func get_internal_error() -> String:
	return data

static func create(p_type: int, p_data: Variant = null) -> ReducerOutcomeEnum:
	var result : ReducerOutcomeEnum = ReducerOutcomeEnum.new()
	result.value = p_type
	result.data = p_data
	return result

static func create_ok(_data: ReducerResultOk) -> ReducerOutcomeEnum:
	return create(Options.ok, _data)

static func create_ok_empty() -> ReducerOutcomeEnum:
	return create(Options.okEmpty)

static func create_err(_data: PackedByteArray) -> ReducerOutcomeEnum:
	return create(Options.err, _data)

static func create_internal_error(_data: String) -> ReducerOutcomeEnum:
	return create(Options.internalError, _data)
