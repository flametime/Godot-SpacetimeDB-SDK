@tool
class_name ReducerResultMessage extends Resource



@export var request_id: int # u32
@export var timestamp: int # i64
@export var reducer_result: ReducerOutcomeEnum # Nested Resource


const bsatn_type_request_id: StringName = &"U32"
const bsatn_type_timestamp: StringName = &"__timestamp_micros_since_unix_epoch__"
const bsatn_type_reducer_result: StringName = &"ReducerOutcomeEnum"
