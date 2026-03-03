class_name OneOffQueryMessage extends Resource

@export var request_id: int
## The query string to execute once on the server.
@export var query: String

func _init(p_request_id: int = 0, p_query: String = ""):
	query = p_query
	set_meta("bsatn_type_request_id", &"u32")
	set_meta("bsatn_type_query", &"string")
