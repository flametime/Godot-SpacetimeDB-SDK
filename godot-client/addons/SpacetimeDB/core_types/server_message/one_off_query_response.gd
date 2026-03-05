@tool
class_name OneOffQueryResponseMessage
extends Resource

@export var request_id: int
@export var result_ok: Array[TableUpdateData] ## Inserts only
@export var result_err: String
