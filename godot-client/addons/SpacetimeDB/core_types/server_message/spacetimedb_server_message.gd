class_name SpacetimeDBServerMessage

# Server Message Tags (ensure these match protocol)
const INITIAL_CONNECTION        := 0x00 #type file done,
const SUBSCRIBE_APPLIED         := 0x01
const UNSUBSCRIBE_APPLIED       := 0x02
const SUBSCRIPTION_ERROR        := 0x03
const TRANSACTION_UPDATE        := 0x04
const ONE_OFF_QUERY_RESPONSE    := 0x05
const REDUCER_RESULT            := 0x06
const PROCEDURE_RESULT          := 0x07

static func get_resource_path(msg_type: int) -> String:
	match msg_type:
		INITIAL_CONNECTION:        return "res://addons/SpacetimeDB/core_types/server_message/initial_connection.gd"
		SUBSCRIBE_APPLIED:         return "res://addons/SpacetimeDB/core_types/server_message/subscribe_applied.gd"
		UNSUBSCRIBE_APPLIED:       return "res://addons/SpacetimeDB/core_types/server_message/unsubscribe_applied.gd"
		SUBSCRIPTION_ERROR:        return "res://addons/SpacetimeDB/core_types/server_message/subscription_error.gd" # Uses manual reader
		TRANSACTION_UPDATE:        return "res://addons/SpacetimeDB/core_types/server_message/transaction_update.gd"
		ONE_OFF_QUERY_RESPONSE:    return "res://addons/SpacetimeDB/core_types/server_message/one_off_query_response.gd" # IMPLEMENT READER
		REDUCER_RESULT:             return "res://addons/SpacetimeDB/core_types/server_message/reducer_result.gd"
		#PROCEDURE_RESULT
		_:
			return ""
