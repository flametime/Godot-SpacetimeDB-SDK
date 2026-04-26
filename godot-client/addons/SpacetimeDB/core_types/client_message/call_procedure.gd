@tool
class_name CallProcedureMessage
extends Resource

enum CallProcedureFlags {
	Default
}

@export var request_id: int
@export var flags: CallProcedureFlags
@export var procedure_name: String
@export var args: PackedByteArray

func _init(p_reducer_name: String = "", p_args: PackedByteArray = PackedByteArray(), p_request_id: int = -1, p_flags: CallProcedureFlags = CallProcedureFlags.Default):
	procedure_name = p_reducer_name
	args = p_args
	request_id = p_request_id
	flags = p_flags
	set_meta("bsatn_type_request_id", &"U32")
	set_meta("bsatn_type_flags", &"U8")
	set_meta("bsatn_type_procedure_name", &"String")
