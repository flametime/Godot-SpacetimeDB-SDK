class_name DataDecompressor extends RefCounted

# Upper bound on the decompressed size of a single Brotli packet.
# PackedByteArray.decompress_dynamic requires a hard cap. 64 MiB is
# large enough to cover any reasonable single-frame BSATN payload from
# a SpacetimeDB server; bigger payloads would already be refused by
# the WebSocket layer's inbound_buffer_size on the way in.
const BROTLI_MAX_DECOMPRESSED_BYTES: int = 64 * 1024 * 1024

static func decompress_packet(compressed_bytes: PackedByteArray) -> PackedByteArray:
	if compressed_bytes.is_empty():
		return PackedByteArray()

	var gzip_stream := StreamPeerGZIP.new()
	if gzip_stream.start_decompression() != OK:
		printerr("DataDecompressor Error: Failed to start Gzip decompression.")
		return []

	var last_slice_position: int = 0
	var decompressed_data: PackedByteArray = PackedByteArray()
	var chunk_size: int = 4096

	while true:
		var input_result = gzip_stream.put_partial_data(compressed_bytes.slice(last_slice_position, last_slice_position+ chunk_size-1))
		#print("data decompressor input size: %s with last slice pos %s with arr size %s" % [input_result[1], last_slice_position, compressed_bytes.size()])
		if input_result[0] != OK:
			printerr("DataDecompressor Error: Failed to input partial data: " + error_string(input_result[0]))
			break
		last_slice_position += input_result[1]
		var result: Array = gzip_stream.get_partial_data(chunk_size)
		var status: Error = result[0]
		var chunk: PackedByteArray = result[1]
		if status == OK:
			if chunk.is_empty():
				break
			decompressed_data.append_array(chunk)
		elif status == ERR_UNAVAILABLE:
			break
		else:
			printerr("DataDecompressor Error: Failed while getting partial data.")
			return []
	return decompressed_data

# Decompresses a Brotli-encoded payload using Godot's built-in
# PackedByteArray.decompress_dynamic with FileAccess.COMPRESSION_BROTLI.
# Godot doesn't ship a StreamPeerBrotli, so this is a one-shot non-streaming
# call capped at BROTLI_MAX_DECOMPRESSED_BYTES.
# Returns an empty PackedByteArray on failure (matches decompress_packet).
static func decompress_brotli_packet(compressed_bytes: PackedByteArray) -> PackedByteArray:
	if compressed_bytes.is_empty():
		return PackedByteArray()
	var decompressed: PackedByteArray = compressed_bytes.decompress_dynamic(
		BROTLI_MAX_DECOMPRESSED_BYTES, FileAccess.COMPRESSION_BROTLI)
	if decompressed.is_empty():
		printerr("DataDecompressor Error: Brotli decompression returned empty payload (input %d bytes)." % compressed_bytes.size())
	return decompressed
