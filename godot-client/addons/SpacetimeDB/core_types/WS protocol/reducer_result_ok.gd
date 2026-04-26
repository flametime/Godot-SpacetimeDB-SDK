@tool
class_name ReducerResultOk extends Resource

@export var ret_value: Array[int] # vec_U8
@export var tx_update: TransactionUpdateMessage

func _init():
	set_meta("bsatn_type_ret_value", &"vec_U8")
	set_meta("bsatn_type_tx_update", &"TransactionUpdateMessage")
