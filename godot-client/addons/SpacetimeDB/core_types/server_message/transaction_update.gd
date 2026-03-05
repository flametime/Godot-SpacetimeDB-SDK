@tool
class_name TransactionUpdateMessage extends Resource

@export var query_sets: Array[DatabaseUpdateData]

## When set (>= 0), this update is a reducer result for that request_id. Set by the addon when handling ReducerResultMessage.
@export var reducer_request_id: int = -1
## When set, indicates reducer outcome (COMMITTED, FAILED, etc.). Set by the addon when handling ReducerResultMessage.
@export var reducer_status: UpdateStatusData = null

#func _init() -> void:
	#set_meta("bsatn_type_query_sets", &"DatabaseUpdateData")
