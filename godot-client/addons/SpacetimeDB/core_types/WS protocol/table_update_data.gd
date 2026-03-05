@tool
class_name TableUpdateData extends Resource

enum TableTypeEnum{
	persistent,
	event,        ## only insert
	subscription  ## only insert and table name
	}
@export var table_id: int # u32
@export var table_name: String
@export var num_rows: int # u64
@export var TableType: TableTypeEnum
@export var deletes: Array[Resource] # Array of specific table row resources (e.g., Message, User)
@export var inserts: Array[Resource] # Array of specific table row resources
