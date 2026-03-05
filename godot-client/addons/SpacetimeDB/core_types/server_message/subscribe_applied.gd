@tool
class_name SubscribeAppliedMessage extends Resource

@export var request_id: int # u32
@export var query_id: QueryIdData # Nested Resource
@export var tables: Array[TableUpdateData] # Nested Resource

func _init():
	query_id = QueryIdData.new()
