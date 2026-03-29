class_name UnsubscribeMessage extends Resource

enum UnsubscribeFlags {Default, SendDroppedRows}

## Client request ID used during the original subscription.
@export var request_id: int # u32

## Identifier of the query being unsubscribed from.
@export var query_id: int
@export var flags : UnsubscribeFlags = UnsubscribeFlags.Default

func _init(p_request_id: int = -1, p_query_id:int = -1):
	request_id = p_request_id
	query_id = p_query_id
	set_meta("bsatn_type_request_id", &"U32")
	set_meta("bsatn_type_query_id", &"U32")
