@tool
class_name ReducerCallInfoData extends Resource

@export var reducer_name: String
@export var reducer_id: int # u32
@export var args: PackedByteArray # Raw BSATN bytes for arguments
@export var request_id: int # u32

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"reducer_id": &"U32",
	&"request_id": &"U32",
	&"execution_time": &"I64",
}
