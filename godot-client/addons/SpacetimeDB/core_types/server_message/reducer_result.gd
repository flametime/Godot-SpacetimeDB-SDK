@tool
class_name ReducerResultMessage extends Resource



@export var request_id: int # u32
@export var timestamp: int # i64
@export var reducer_result: ReducerOutcomeEnum # Nested Resource

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"request_id": &"U32",
	&"timestamp": &"__timestamp_micros_since_unix_epoch__",
	&"reducer_result": &"ReducerOutcomeEnum",
}
