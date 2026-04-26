extends Resource
class_name SpacetimeDBPendingOneOffQuery

@export var request_id: int
@export var callback: Callable
@export var save: bool

func _init(p_request_id: int = -1, p_callback:Callable = Callable(), p_save:bool = false) -> void:
	request_id = request_id
	callback = p_callback
	save = p_save
