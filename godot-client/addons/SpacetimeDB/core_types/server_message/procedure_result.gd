extends Resource
class_name ProcedureResult


@export var status: Variant
@export var timestamp: int
@export var total_host_execution_duration: int
@export var request_id: int

func _init():
	set_meta("bsatn_type_timestamp", &"timestamp")
	set_meta("bsatn_type_request_id", &"u32")
	set_meta("bsatn_type_status", &"ReducerOutcomeEnum")

#pub status: ProcedureStatus,
#/// The time when the reducer started.
#///
#/// Note that [`Timestamp`] serializes as `i64` nanoseconds since the Unix epoch.
#pub timestamp: Timestamp,
#/// The time the procedure took to run.
#pub total_host_execution_duration: TimeDuration,
#/// The same same client-provided identifier as in the original [`ProcedureCall`] request.
#///
#/// Clients use this to correlate the response with the original request.
#pub request_id: u32,
