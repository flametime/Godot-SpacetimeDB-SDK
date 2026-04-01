class_name SpacetimeDBServerMessage extends RefCounted

# Server Message Tags (ensure these match protocol)
const INITIAL_CONNECTION        := 0x00 #type file done,
const SUBSCRIBE_APPLIED         := 0x01
const UNSUBSCRIBE_APPLIED       := 0x02
const SUBSCRIPTION_ERROR        := 0x03
const TRANSACTION_UPDATE        := 0x04
const ONE_OFF_QUERY_RESPONSE    := 0x05
const REDUCER_RESULT            := 0x06
const PROCEDURE_RESULT          := 0x07

static func get_core_type(msg_type: int) -> String:
	match msg_type:
		INITIAL_CONNECTION:        return "IdentityTokenMessage"
		SUBSCRIBE_APPLIED:         return "SubscribeAppliedMessage"
		UNSUBSCRIBE_APPLIED:       return "UnsubscribeAppliedMessage"
		SUBSCRIPTION_ERROR:        return "SubscriptionErrorMessage"
		TRANSACTION_UPDATE:        return "TransactionUpdateMessage"
		ONE_OFF_QUERY_RESPONSE:    return "OneOffQueryResponseMessage"
		REDUCER_RESULT:            return "ReducerResultMessage"
		PROCEDURE_RESULT:          return "ProcedureResultMessage"
		_:
			return ""
