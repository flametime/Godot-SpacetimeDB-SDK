class_name SpacetimeDBConnectionOptions extends Resource
## helper class for the Websocket connection builder.

## Brotli not supported yet
const CompressionPreference = SpacetimeDBConnection.CompressionPreference

## Brotli not supported yet
var compression: CompressionPreference = CompressionPreference.NONE
## Use a thread for the BSATN parsing. Adds 1-2 frames delay.
var threading: bool = true
## Get a new token for the connection.
var one_time_token: bool = true
## Save the token to the user:// folder
var save_token: bool = true
## Overwrite the used token
var token: String = ""
## Tells the server to wait for Persistance. Adds around 20ms to 50ms server latency.
var confirmed_reads: bool = false
## Write debug prints to Output. Can be quite spammy on fast redcer calls.
var debug_mode: bool = false
## Adds Websocket monitors to the Debugger/Monitors tab
var monitor_mode: bool = false
## max websocket message buffer size
var inbound_buffer_size: int = 1024 * 1024 * 2 # 2MB
## max websocket message buffer size
var outbound_buffer_size: int = 1024 * 1024 * 2 # 2MB

func set_all_buffer_size(size: int):
	inbound_buffer_size = size
	outbound_buffer_size = size
