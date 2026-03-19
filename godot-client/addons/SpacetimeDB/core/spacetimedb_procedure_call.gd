class_name SpacetimeDBProcedureCall extends Resource

var request_id: int = -1
var error: Error = OK
var result: ProcedureResultMessage

var _client: SpacetimeDBClient
var return_type_bsatn: StringName

signal response(call_response: ProcedureResultMessage)
signal on_ok(data)
signal on_error(data)

static func create(
	p_client: SpacetimeDBClient,
	p_request_id: int,
	p_return_type_bsatn,
) -> SpacetimeDBProcedureCall:
	var procedure_call := SpacetimeDBProcedureCall.new()
	procedure_call._client = p_client
	procedure_call.request_id = p_request_id
	procedure_call.return_type_bsatn = p_return_type_bsatn
	return procedure_call

static func fail(error: Error) -> SpacetimeDBProcedureCall:
	var procedure_call := SpacetimeDBProcedureCall.new()
	procedure_call.error = error
	return procedure_call

func on_response(p_response: ProcedureResultMessage):
	result = p_response
	response.emit(p_response)
