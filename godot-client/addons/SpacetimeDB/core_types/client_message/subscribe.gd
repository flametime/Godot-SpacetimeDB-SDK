class_name SubscribeMessage extends Resource

@export var request_id: int
@export var query_id: int
@export var queries: Array[String]

func _init(p_request_id: int = -1, p_query_id: int = -1, p_queries: Array[String] = []):
	request_id = p_request_id
	query_id = p_query_id
	queries = p_queries
	set_meta("bsatn_type_request_id", "U32")
	set_meta("bsatn_type_query_id", "U32")
