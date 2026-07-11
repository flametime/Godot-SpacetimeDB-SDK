class_name UnsubscribeMessage extends Resource

enum UnsubscribeFlags {Default, SendDroppedRows}

## Client request ID used during the original subscription.
@export var request_id: int # u32

## Identifier of the query being unsubscribed from.
@export var query_id: int
@export var flags : UnsubscribeFlags = UnsubscribeFlags.Default

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"request_id": &"U32",
	&"query_id": &"U32",
	&"flags": &"U8",
}


func _init(p_request_id: int = -1, p_query_id:int = -1):
	request_id = p_request_id
	query_id = p_query_id
