extends Resource
class_name ProcedureResultMessage


@export var result_ok: Variant
@export var result_err: Variant
@export var timestamp: int
@export var total_host_execution_duration: int
@export var request_id: int

func _init():
	set_meta("bsatn_type_timestamp", &"__timestamp_micros_since_unix_epoch__")
	set_meta("bsatn_type_request_id", &"U32")
