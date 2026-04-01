class_name OneOffQueryMessage extends Resource

@export var request_id: int
## The query string to execute once on the server.
@export var query: String

func _init(p_request_id: int = -1, p_query: String = ""):
	request_id = p_request_id
	query = p_query
	set_meta("bsatn_type_request_id", &"U32")
	set_meta("bsatn_type_query", &"String")
