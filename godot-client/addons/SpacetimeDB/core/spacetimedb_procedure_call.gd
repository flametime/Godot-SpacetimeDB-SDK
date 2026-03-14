class_name SpacetimeDBProcedureCall extends Resource

var request_id: int = -1
var error: Error = OK
var procedure_name: String = ""

var _client: SpacetimeDBClient

static func create(
	p_client: SpacetimeDBClient,
	p_request_id: int,
	p_procedure_name: String
) -> SpacetimeDBProcedureCall:
	var procedure_call := SpacetimeDBProcedureCall.new()
	procedure_call._client = p_client
	procedure_call.request_id = p_request_id
	procedure_call.procedure_name = p_procedure_name

	return procedure_call

static func fail(error: Error) -> SpacetimeDBProcedureCall:
	var procedure_call := SpacetimeDBProcedureCall.new()
	procedure_call.error = error
	return procedure_call

func wait_for_response(timeout_sec: float = 10) -> TransactionUpdateMessage:
	if error:
		return null

	return await _client.wait_for_procedure_response(request_id, timeout_sec)
