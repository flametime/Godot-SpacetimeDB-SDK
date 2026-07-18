class_name JwtHelper

# Tiny JWT payload decoder. JWT = base64url(header).base64url(payload).signature.
#
# Handy for reading claims out of a SpacetimeAuth id_token client-side, e.g. to
# key a per-identity token cache off the JWT's `login_method` claim so tokens
# from different login providers don't overwrite each other.
#
# SECURITY: the payload is NOT signature-verified here. Do NOT use this for any
# authorization decision on the client — the SpacetimeDB server verifies the
# signature on connect. This is purely for reading claims for local bookkeeping
# and diagnostics.


static func decode_payload(jwt: String) -> Dictionary:
	var parts: PackedStringArray = jwt.split(".")
	if parts.size() < 2:
		return {}
	var payload_b64url: String = parts[1]
	# base64url -> base64: the URL-safe alphabet uses `-_` instead of `+/` and drops padding.
	var padded: String = payload_b64url.replace("-", "+").replace("_", "/")
	while padded.length() % 4 != 0:
		padded += "="
	var bytes: PackedByteArray = Marshalls.base64_to_raw(padded)
	if bytes.is_empty():
		return {}
	# A JWT payload that decodes to a JSON array / scalar / null would fail a
	# direct typed-Dictionary assignment, so parse to Variant and guard.
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}
	return parsed


# `login_method` is set by SpacetimeAuth (e.g. "anonymous" or a provider name).
# Returns "" for an empty / malformed JWT.
static func login_method(jwt: String) -> String:
	if jwt.is_empty():
		return ""
	return String(decode_payload(jwt).get("login_method", ""))


# Human-readable dump of common claims for diagnostic logging. Returns
# "<empty>" / "<malformed>" or a multi-line string of the claims that are present.
static func summarize(jwt: String) -> String:
	if jwt.is_empty():
		return "<empty>"
	var payload: Dictionary = decode_payload(jwt)
	if payload.is_empty():
		return "<malformed jwt or non-json payload>"
	var lines: PackedStringArray = PackedStringArray()
	for key: String in ["iss", "sub", "aud", "login_method", "provider_id", "preferred_username", "exp", "iat"]:
		if payload.has(key):
			lines.append("    %s = %s" % [key, payload[key]])
	return "\n".join(lines)
