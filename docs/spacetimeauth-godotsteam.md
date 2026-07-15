# SpacetimeAuth + GodotSteam: Steam sign-in for SpacetimeDB

How to turn a **Steam** login into a **SpacetimeDB** connection using the SDK's
`SpacetimeAuth` node ([`addons/SpacetimeDB/nodes/spacetime_auth/spacetime_auth.gd`](../godot-client/addons/SpacetimeDB/nodes/spacetime_auth/spacetime_auth.gd))
and [GodotSteam](https://godotsteam.com/).

The flow is provider-agnostic — Steam is one grant type. The same node handles
Google Play, Epic, Apple, Discord, etc.; only the `grant_type` string and the
credential fields change.

```
GodotSteam                     SpacetimeAuth node                SpacetimeDB
──────────                     ─────────────────                ───────────
getAuthTicketForWebApi   ─▶  exchange(grant_type, fields)  ─▶  POST /oidc/token
   (Steam WebAPI ticket)         │                                 │
                                 ▼                                 ▼
                            ExchangeResult.id_token  ─────▶  connect with token
                            (a SpacetimeAuth JWT)            (SpacetimeDBConnectionOptions.token)
```

---

## Prerequisites

1. **SDK addon enabled** (`addons/SpacetimeDB`) — gives you `SpacetimeAuth`,
   `SpacetimeDBClient`, `SpacetimeDBConnectionOptions`, and `JwtHelper`.
2. **GodotSteam** installed and `Steam.steamInitEx()` succeeded, with your
   Steam **App ID** set (`steam_appid.txt` during dev, or the launched app).
3. A **SpacetimeAuth `client_id`** for your game, and your Steam app registered
   with SpacetimeAuth for the `steam-ticket` grant. Store the `client_id` in a
   project setting or config — never hard-code it in a shipped scene you can't
   rotate.

---

## The `SpacetimeAuth` node API

```gdscript
class_name SpacetimeAuth extends Node

# await this; also emitted as `exchange_completed(result)`
func exchange(grant_type: String, extra_fields: Dictionary, client_id: String) -> ExchangeResult

class ExchangeResult extends RefCounted:
    var id_token: String   # the JWT to connect with (empty on failure)
    var expires_in: int    # seconds until the id_token expires
    var error: String      # non-empty on failure
    func is_successful() -> bool
```

Exported knobs (all optional, sensible defaults):

| export | default | purpose |
|---|---|---|
| `token_url` | `https://auth.spacetimedb.com/oidc/token` | override for a self-hosted SpacetimeAuth |
| `request_timeout_seconds` | `15.0` | bounds a network hang (DNS/TLS stall) |
| `max_attempts` | `4` | transient failures (transport error / 5xx) retry with exponential backoff; a 2xx/4xx is authoritative and never retried |
| `base_retry_delay_seconds` / `max_retry_delay_seconds` | `0.5` / `4.0` | backoff bounds |
| `redact_fields` | `["id_token","access_token","refresh_token","token","code","ticket","client_secret"]` | field **values** scrubbed from any error body echoed to the log |
| `debug_mode` | `false` | set `true` to log the request/response summary |

**The node owns its own `HTTPRequest`** — you just add it to the tree and
`await`. It must be inside the scene tree before you call `exchange()`.

> **Redaction gotcha (Steam):** the default `redact_fields` has `"ticket"`, but
> the Steam credential field is named `steam_ticket`, and matching is by exact
> field name. **Append `"steam_ticket"`** (shown below) so the hex ticket never
> lands in a log verbatim.

---

## Minimal example

The happy path, no error handling, to show the shape:

```gdscript
# Assumes Steam is initialized and a WebAPI ticket has been obtained (see below).
var auth := SpacetimeAuth.new()
add_child(auth)                                  # must be in the tree
auth.redact_fields.append("steam_ticket")        # keep the ticket out of logs

var result := await auth.exchange(
    "urn:spacetimeauth:steam-ticket",            # Steam grant type
    {
        "steam_ticket": ticket_bytes.hex_encode(),
        "steam_app_id": str(app_id),
    },
    client_id,                                   # your SpacetimeAuth client_id
)
auth.queue_free()

if result.is_successful():
    print("id_token: %d chars, expires_in=%d" % [result.id_token.length(), result.expires_in])
    # -> hand result.id_token to your SpacetimeDB connect (see "Connecting" below)
else:
    push_error("SpacetimeAuth exchange failed: %s" % result.error)
```

---

## Full example — Steam ticket to SpacetimeDB connection

A complete, self-contained node. Drop it in a scene, set `client_id`, call
`login()`. It requests a Steam WebAPI ticket, races it against a timeout,
exchanges it, and connects SpacetimeDB with the resulting JWT.

```gdscript
extends Node
class_name SteamSpacetimeLogin

# --- config -------------------------------------------------------------
## SpacetimeAuth client_id for this game. Pull from ProjectSettings/config.
@export var client_id: String = ""
## The Steam grant type + the identity string the WebAPI ticket must be bound to.
const GRANT_TYPE: String = "urn:spacetimeauth:steam-ticket"
const TICKET_IDENTITY: String = "spacetimeauth"   # required exact value
const TICKET_TIMEOUT_SECONDS: float = 10.0
const STEAM_RESULT_OK: int = 1                    # k_EResultOK

signal login_succeeded(id_token: String)
signal login_failed(reason: String)


func login() -> void:
    if not Engine.has_singleton(&"Steam"):
        _fail("Steam singleton missing"); return
    if not Steam.loggedOn():
        _fail("Steam not logged on (is the client running?)"); return
    if client_id.is_empty():
        _fail("client_id not set"); return

    var app_id: int = Steam.getAppID()
    if app_id <= 0:
        _fail("Steam app id unavailable"); return

    # 1. Request a WebAPI-scoped ticket bound to the "spacetimeauth" identity.
    var handle: int = Steam.getAuthTicketForWebApi(TICKET_IDENTITY)
    if handle == 0:
        _fail("getAuthTicketForWebApi returned 0"); return

    # 2. Await the ticket callback (with a timeout + handle filtering).
    var ticket: PackedByteArray = await _await_ticket(handle)
    if ticket.is_empty():
        Steam.cancelAuthTicket(handle)
        _fail("Steam ticket timed out / failed"); return

    # 3. Exchange the ticket for a SpacetimeAuth id_token.
    var auth := SpacetimeAuth.new()
    auth.redact_fields.append("steam_ticket")
    # auth.debug_mode = true            # uncomment for request/response logging
    add_child(auth)
    var result := await auth.exchange(
        GRANT_TYPE,
        {
            "steam_ticket": ticket.hex_encode(),
            "steam_app_id": str(app_id),
        },
        client_id,
    )
    auth.queue_free()
    Steam.cancelAuthTicket(handle)      # one-time ticket; always cancel it

    if not result.is_successful():
        _fail("OIDC exchange failed: %s" % result.error); return

    # 4. (Optional) sanity-check the JWT client-side. NOT a security check —
    #    the server verifies the signature on connect. Handy for diagnostics.
    print("JWT claims:\n%s" % JwtHelper.summarize(result.id_token))
    var jwt_provider_id := String(JwtHelper.decode_payload(result.id_token).get("provider_id", ""))
    if jwt_provider_id != "" and jwt_provider_id != str(Steam.getSteamID()):
        push_warning("JWT provider_id (%s) != current SteamID (%s)" % [jwt_provider_id, Steam.getSteamID()])

    login_succeeded.emit(result.id_token)


func _fail(reason: String) -> void:
    push_error("[SteamSpacetimeLogin] %s" % reason)
    login_failed.emit(reason)


# Race Steam's `get_ticket_for_web_api` signal against a deadline. Returns the
# ticket bytes, or an empty array on timeout / non-OK result. Filters by handle
# because concurrent ticket requests (Lobbies/Friends flows) share this signal.
func _await_ticket(requested_handle: int) -> PackedByteArray:
    var tree := get_tree()
    if tree == null:
        return PackedByteArray()
    var state := {"done": false, "bytes": PackedByteArray()}

    # payload: (auth_ticket:int, result:int, ticket_size:int, ticket_buffer:PackedByteArray)
    var on_ticket := func(handle: int, code: int, _size: int, buf: PackedByteArray) -> void:
        if state.done or handle != requested_handle:
            return
        state.done = true
        if code == STEAM_RESULT_OK:
            state.bytes = buf

    Steam.get_ticket_for_web_api.connect(on_ticket)
    tree.create_timer(TICKET_TIMEOUT_SECONDS).timeout.connect(func() -> void: state.done = true)
    while not state.done:
        await tree.process_frame
    if Steam.get_ticket_for_web_api.is_connected(on_ticket):
        Steam.get_ticket_for_web_api.disconnect(on_ticket)
    return state.bytes
```

### Connecting to SpacetimeDB with the id_token

Hand the JWT to the SDK as the connection token:

```gdscript
func _ready() -> void:
    var login := SteamSpacetimeLogin.new()
    login.client_id = ProjectSettings.get_setting("spacetimeauth/client_id", "")
    login.login_succeeded.connect(_on_login_ok)
    login.login_failed.connect(func(reason: String) -> void: push_error(reason))
    add_child(login)
    login.login()


func _on_login_ok(id_token: String) -> void:
    var opts := SpacetimeDBConnectionOptions.new()
    opts.token = id_token                  # <-- the SpacetimeAuth JWT
    # opts.compression / opts.threading / opts.one_time_token as needed

    # SpacetimeDBClient.connect_db(host_url, database_name, options)
    var client: SpacetimeDBClient = $SpacetimeDBClient
    client.connect_db("http://127.0.0.1:3000", "my_module", opts)
```

> If your project uses the generated module wrapper (e.g. `SpacetimeDB.MyModule`),
> route the same `opts` through however it exposes `connect_db`. The only
> contract that matters here: **set `SpacetimeDBConnectionOptions.token` to
> `result.id_token`**. A non-empty `token` is used as-is; leave it empty and the
> SDK falls back to its anonymous token-request path.

---

## Signal-based variant

Prefer signals over `await`? `exchange()` also emits `exchange_completed`:

```gdscript
var auth := SpacetimeAuth.new()
auth.redact_fields.append("steam_ticket")
add_child(auth)
auth.exchange_completed.connect(func(result: SpacetimeAuth.ExchangeResult) -> void:
    auth.queue_free()
    if result.is_successful():
        _on_login_ok(result.id_token)
    else:
        push_error(result.error)
)
auth.exchange(GRANT_TYPE, {"steam_ticket": ticket.hex_encode(), "steam_app_id": str(app_id)}, client_id)
```

---

## Reading claims with `JwtHelper`

`JwtHelper` (`addons/SpacetimeDB/util/jwt_helper.gd`) decodes the JWT **payload**
for local bookkeeping/diagnostics. It does **not** verify the signature — never
gate authorization on it client-side; the server verifies on connect.

```gdscript
JwtHelper.decode_payload(id_token)   # -> Dictionary of claims
JwtHelper.login_method(id_token)     # -> "steam" / "anonymous" / provider name
JwtHelper.summarize(id_token)        # -> short multi-line dump for logs
```

A useful pattern: key your on-disk token cache off `JwtHelper.login_method()` so
a Steam-issued token can't clobber a different provider's cached token.

---

## Other providers

Same node, different `grant_type` + fields (per the SpacetimeAuth docs):

```gdscript
# Google Play
await auth.exchange("urn:spacetimeauth:google-play", {"gpg_authcode": code}, client_id)
# Epic
await auth.exchange("urn:spacetimeauth:epic", {"epic_id_token": jwt}, client_id)
```

Remember to append the credential field name to `redact_fields` if it should be
kept out of logs.

---

## Troubleshooting

| symptom | cause / fix |
|---|---|
| `client_id empty` | `client_id` arg was blank — load it from settings before calling. |
| `SpacetimeAuth node must be inside the scene tree` | call `add_child(auth)` **before** `exchange()`. |
| `transport error: CANT_RESOLVE / CANT_CONNECT` | no network / DNS to `auth.spacetimedb.com`; the node already retried `max_attempts`. |
| `HTTP 400/401` with `allowed_app_ids` / grant errors | Steam app not registered with SpacetimeAuth for the grant, or wrong `steam_app_id` / `client_id`. Body is logged (credentials redacted). |
| `response missing id_token` | endpoint returned 200 but no `id_token` — check the grant config server-side. |
| ticket never arrives | `getAuthTicketForWebApi` identity must be exactly `"spacetimeauth"`; ensure Steam is running and `loggedOn()`. |
| token in logs | append your credential field (e.g. `"steam_ticket"`) to `auth.redact_fields`. |

---

## Key rules recap

- Add the node to the tree **before** `exchange()`; `queue_free()` it after.
- `cancelAuthTicket(handle)` — the WebAPI ticket is single-use.
- Ticket identity string is exactly `"spacetimeauth"`.
- Append provider credential fields to `redact_fields` for log hygiene.
- `id_token` → `SpacetimeDBConnectionOptions.token`. Empty token = anonymous.
- `JwtHelper` is for diagnostics only — the server verifies the signature.
