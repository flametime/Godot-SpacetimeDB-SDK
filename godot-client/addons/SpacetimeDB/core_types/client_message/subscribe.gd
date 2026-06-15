class_name SubscribeMessage extends Resource

@export var request_id: int
@export var query_id: int
@export var queries: Array[String]

const bsatn_type_request_id: StringName = &"U32"
const bsatn_type_query_id: StringName = &"U32"

func _init(p_request_id: int = -1, p_query_id: int = -1, p_queries: Array[String] = []):
	request_id = p_request_id
	query_id = p_query_id
	queries = p_queries
