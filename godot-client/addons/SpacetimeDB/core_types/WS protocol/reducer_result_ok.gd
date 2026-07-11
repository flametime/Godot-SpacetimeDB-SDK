@tool
class_name ReducerResultOk extends Resource

@export var ret_value: Array[int] # vec_U8
@export var tx_update: TransactionUpdateMessage


const BSATN_TYPES: Dictionary[StringName, StringName] = {
	&"ret_value": &"vec_U8",
	&"tx_update": &"TransactionUpdateMessage"
}
