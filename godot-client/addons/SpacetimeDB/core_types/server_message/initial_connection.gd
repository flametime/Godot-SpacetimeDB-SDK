@tool
class_name IdentityTokenMessage extends Resource

@export var identity: PackedByteArray
@export var connection_id: PackedByteArray # 16 bytes
@export var token: String

const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"identity": &"__identity__",
	&"connection_id": &"__connection_id__",
	&"token": &"String",
}
