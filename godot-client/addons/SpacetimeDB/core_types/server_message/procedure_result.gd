extends Resource
class_name ProcedureResultMessage


@export var result_ok: Variant
@export var result_err: Variant
@export var timestamp: int
@export var total_host_execution_duration: int
@export var request_id: int

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"request_id": &"U32",
	&"timestamp": &"__timestamp_micros_since_unix_epoch__",
}
