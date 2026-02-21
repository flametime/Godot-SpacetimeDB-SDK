@tool
class_name TransactionUpdateMessageLightmode extends Resource

@export var request_id: int #u32
@export var committed_update: DatabaseUpdateData

func _init():
	set_meta("bsatn_type_request_id", "u32")
