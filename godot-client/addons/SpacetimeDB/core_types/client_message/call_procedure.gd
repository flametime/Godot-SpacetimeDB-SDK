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

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"request_id": &"U32",
	&"flags": &"U8",
	&"procedure_name": &"String",
	&"args": &"vec_U8",
}

func _init(p_reducer_name: String = "", p_args: PackedByteArray = PackedByteArray(), p_request_id: int = -1, p_flags: CallProcedureFlags = CallProcedureFlags.Default):
	procedure_name = p_reducer_name
	args = p_args
	request_id = p_request_id
	flags = p_flags
