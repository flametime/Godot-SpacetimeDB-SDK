class_name SpacetimeDBReducerCall extends Resource

var request_id: int = -1
var error: Error = OK

var _client: SpacetimeDBClient

signal response(call_response: ReducerResultMessage)
signal on_ok(call_response: ReducerResultMessage)
signal on_ok_empty(call_response: ReducerResultMessage)
signal on_error(err: String)
signal on_internal_error(err: String)

static func create(
	p_client: SpacetimeDBClient,
	p_request_id: int,
) -> SpacetimeDBReducerCall:
	var reducer_call := SpacetimeDBReducerCall.new()
	reducer_call._client = p_client
	reducer_call.request_id = p_request_id
	reducer_call.response.connect(reducer_call._on_response)
	return reducer_call

static func fail(error: Error) -> SpacetimeDBReducerCall:
	var reducer_call := SpacetimeDBReducerCall.new()
	reducer_call.error = error
	return reducer_call

func _on_response(_response: ReducerResultMessage) -> void:
	match _response.reducer_result.value:
		ReducerOutcomeEnum.Options.ok:
			on_ok.emit(_response)
		ReducerOutcomeEnum.Options.okEmpty:
			on_ok_empty.emit(_response)
		ReducerOutcomeEnum.Options.err:
			on_error.emit(_response.reducer_result.get_err())
		ReducerOutcomeEnum.Options.internalError:
			on_internal_error.emit(_response.reducer_result.get_internal_error())
