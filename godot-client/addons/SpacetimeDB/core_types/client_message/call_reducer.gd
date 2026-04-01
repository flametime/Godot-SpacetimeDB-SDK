@tool
class_name CallReducerMessage extends Resource

enum CallReducerFlags {
	Default
}

@export var request_id: int
@export var flags: CallReducerFlags
@export var reducer_name: String
@export var args: PackedByteArray

func _init(p_reducer_name: String = "", p_args: PackedByteArray = PackedByteArray(), p_request_id: int = -1, p_flags: CallReducerFlags = CallReducerFlags.Default):
	reducer_name = p_reducer_name
	args = p_args
	request_id = p_request_id
	flags = p_flags
	set_meta("bsatn_type_request_id", &"U32")
	set_meta("bsatn_type_flags", &"U8")
