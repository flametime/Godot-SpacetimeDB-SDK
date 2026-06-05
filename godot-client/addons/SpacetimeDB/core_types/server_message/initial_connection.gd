@tool
class_name IdentityTokenMessage extends Resource

@export var identity: PackedByteArray
@export var connection_id: PackedByteArray # 16 bytes
@export var token: String


const bsatn_type_identity: StringName = &"__identity__"
const bsatn_type_connection_id: StringName = &"__connection_id__"
const bsatn_type_token: StringName = &"String"
