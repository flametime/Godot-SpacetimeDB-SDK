class_name OneOffQueryMessage extends Resource

@export var request_id: int
## The query string to execute once on the server.
@export var query: String

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"request_id": &"U32",
	&"query": &"String",
}

func _init(p_request_id: int = -1, p_query: String = ""):
	request_id = p_request_id
	query = p_query
