@tool
class_name IdentityTokenMessage extends Resource

@export var identity: PackedByteArray
@export var connection_id: PackedByteArray # 16 bytes
@export var token: String

func _init():
	set_meta("bsatn_type_identity", &"identity")
	set_meta("bsatn_type_connection_id", &"connection_id")
	set_meta("bsatn_type_token", &"string")
