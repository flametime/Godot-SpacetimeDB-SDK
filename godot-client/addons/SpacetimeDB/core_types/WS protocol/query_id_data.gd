@tool
class_name QueryIdData extends Resource

## The actual ID value.
@export var id: int # u32

func _init(p_id: int = 0):
	id = p_id


const bsatn_type_id: StringName = &"U32"
