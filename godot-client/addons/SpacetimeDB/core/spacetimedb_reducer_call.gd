class_name SpacetimeDBReducerCall extends Resource

var request_id: int = -1
var error: Error = OK
var reducer_name: String = ""

var _client: SpacetimeDBClient

static func create(
	p_client: SpacetimeDBClient,
	p_request_id: int,
	p_reducer_name: String
) -> SpacetimeDBReducerCall:
	var reducer_call := SpacetimeDBReducerCall.new()
	reducer_call._client = p_client
	reducer_call.request_id = p_request_id
	reducer_call.reducer_name = p_reducer_name

	return reducer_call

static func fail(error: Error) -> SpacetimeDBReducerCall:
	var reducer_call := SpacetimeDBReducerCall.new()
	reducer_call.error = error
	return reducer_call

func wait_for_response(timeout_sec: float = 10) -> TransactionUpdateMessage:
	if error:
		return null

	return await _client.wait_for_reducer_response(request_id, timeout_sec)
