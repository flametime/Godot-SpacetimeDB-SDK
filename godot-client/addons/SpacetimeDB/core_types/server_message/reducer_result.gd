@tool
class_name ReducerResultMessage extends Resource



@export var request_id: int # u32
@export var timestamp: int # i64
@export var reducer_result: ReducerOutcomeEnum # Nested Resource

func _init():
	set_meta("bsatn_type_timestamp", &"timestamp")
	set_meta("bsatn_type_request_id", &"u32")
	set_meta("bsatn_type_reducer_result", &"ReducerOutcomeEnum")
