class_name OneOffQueryMessage extends Resource

@export var request_id: int
## The query string to execute once on the server.
@export var query: String

const bsatn_type_request_id: StringName = &"U32"
const bsatn_type_query: StringName = &"String"

func _init(p_request_id: int = -1, p_query: String = ""):
	request_id = p_request_id
	query = p_query
