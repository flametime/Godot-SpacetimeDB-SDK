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

	set_meta('enum_options', [&'TransactionUpdateMessage', &'', &'vec_u8', &'string'])
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

func get_ok() -> TransactionUpdateMessage:
	return data

func get_err() -> PackedByteArray:
	return data

func get_internal_error() -> String:
	return data

static func create(p_type: int, p_data: Variant = null) -> ReducerOutcomeEnum:
	var result : ReducerOutcomeEnum = ReducerOutcomeEnum.new()
	result.value = p_type
	result.data = p_data
	return result

static func create_ok(_data: TransactionUpdateMessage) -> ReducerOutcomeEnum:
	return create(Options.ok, _data)

static func create_ok_empty() -> ReducerOutcomeEnum:
	return create(Options.okEmpty)

static func create_err(_data: PackedByteArray) -> ReducerOutcomeEnum:
	return create(Options.err, _data)

static func create_internal_error(_data: String) -> ReducerOutcomeEnum:
	return create(Options.internalError, _data)
