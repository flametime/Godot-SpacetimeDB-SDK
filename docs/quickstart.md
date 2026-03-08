# SpacetimeDB SDK Quick Start Guide

## Prerequisites

> Last tested with: `Godot 4.4.1-stable` and `SpacetimeDB 1.2.0`

-   A SpacetimeDB server running atleast version `1.0.0`
-   A Godot 4.0+ project
-   [Install the SpacetimeDB SDK addon](installation.md)
-   [Generate module bindings](codegen.md)

## Configure and Connect to SpacetimeDB

All of your generated modules can be accessed via the `SpacetimeDB` singleton. The following is a basic example of connecting to a SpacetimeDB server and subscribing to data using a module called `MyModule`:

```gdscript
# In your main scene script or another Autoload

func _ready():
    # Connect to signals BEFORE connecting to the DB
    SpacetimeDB.MyModule.connected.connect(_on_spacetimedb_connected)
    SpacetimeDB.MyModule.disconnected.connect(_on_spacetimedb_disconnected)
    SpacetimeDB.MyModule.connection_error.connect(_on_spacetimedb_connection_error)
    SpacetimeDB.MyModule.transaction_update_received.connect(_on_transaction_update) # For reducer results

    var options = SpacetimeDBConnectionOptions.new()

    options.compression = SpacetimeDBConnection.CompressionPreference.NONE # Default
    # OR
    # options.compression = SpacetimeDBConnection.CompressionPreference.GZIP

    options.one_time_token = true # <--- anonymous-like. set to false to persist
    options.debug_mode = false # Default, set to true for verbose logging
    # Increase buffer size. In general, you don't need this.
    # options.set_all_buffer_size(1024 * 1024 * 2) # Defaults to 2MB

    # Disable threading (e.g., for web builds)
    # options.threading = false

    SpacetimeDB.MyModule.connect_db(
        "http://127.0.0.1:3000", # Base HTTP URL
        "my_module",             # Module Name
        options
    )

func _on_spacetimedb_connected(identity: PackedByteArray, token: String):
    print("Game: Connected to SpacetimeDB!")
    # Good place to subscribe to initial data
    var queries = ["SELECT * FROM PlayerData", "SELECT * FROM GameState"]
    var subscription = SpacetimeDB.MyModule.subscribe(queries)
    if subscription.error:
        printerr("Subscription failed!")
        return

    subscription.applied.connect(_on_subscription_applied)

func _on_subscription_applied():
    print("Game: Initial subscription applied.")
    # Safe to query the local DB for initially subscribed data
    var initial_players = SpacetimeDB.MyModule.PlayerData.iter()
    print("Initial players found: %d" % initial_players.size())
    var identity = SpacetimeDB.MyModule.get_local_identity()
    var current_player = SpacetimeDB.MyModule.PlayerData.identity.find(identity)
    # ... setup initial game state ...

func _on_spacetimedb_disconnected():
    print("Game: Disconnected.")

func _on_spacetimedb_connection_error(code, reason):
    printerr("Game: Connection Error (Code: %d): %s" % [code, reason])

func _on_transaction_update(update: TransactionUpdateData):
    # Handle results/errors from reducer calls
    if update.status.status_type == UpdateStatusData.StatusType.FAILED:
        printerr("Reducer call (ReqID: %d) failed: %s" % [update.reducer_call.request_id, update.status.failure_message])
    elif update.status.status_type == UpdateStatusData.StatusType.COMMITTED:
        print("Reducer call (ReqID: %d) committed." % update.reducer_call.request_id)
        # Optionally inspect update.status.committed_update for DB changes

# listening for the game closing/crashing to disconnect cleanly from the server.
func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_CRASH:
        SpacetimeDB.MyModule.disconnect_db()
```

## Listen for Data Changes

There are three ways to listen for data changes:

### Using the `RowReceiver` node (Recommended for specific tables)

1.  Add a `RowReceiver` node to your scene.
2.  In the Inspector, set `Table To Receive` to your schema resource via the dropdown menu (e.g., `PlayerData`).
3.  Connect to the node's `insert(row)`, `update(previous_row, new_row)` and `delete(row)` signals.

```gdscript
# Script needing player updates
@export var player_receiver: RowReceiver # Assign in editor

func _ready():
    if player_receiver:
        player_receiver.insert.connect(_on_player_receiver_insert)
        player_receiver.update.connect(_on_player_receiver_update)
        player_receiver.delete.connect(_on_player_receiver_delete)
    else:
        printerr("Player receiver not set!")

func _on_player_receiver_insert(player: PlayerData):
    # Player inserted
    print("Receiver Insert: Player %s ; Health: %d" % [player.name, player.health])
    # ... spawn player visual ...

func _on_player_receiver_update(previous_row: PlayerData, player: PlayerData):
    # Player updated
    print("Receiver Update: Player %s ; Health: %d" % [player.name, player.health])
    print("Receiver Previous Value: Player %s ; Health: %d" % [previous_row.name, previous_row.health])
    # ... update player visual ...

func _on_player_receiver_delete(player: PlayerData):
    # Player deleted
    print("Receiver Delete: Player %s" % player.name)
    # ... despawn player visual ...
```

### Using generated table on_xxx methods (Alternative to `RowReceiver` node)

Add listeners to a table via the `on_insert`, `on_update` and `on_delete` methods.

```gdscript
# Script needing player updates

# Somewhere in your script
SpacetimeDB.MyModule.db.player_data.on_insert(_on_player_receiver_insert)
SpacetimeDB.MyModule.db.player_data.on_update(_on_player_receiver_update)
SpacetimeDB.MyModule.db.player_data.on_delete(_on_player_receiver_delete)

func _on_player_receiver_insert(player: PlayerData):
    # Player inserted
    print("Receiver Insert: Player %s ; Health: %d" % [player.name, player.health])
    # ... spawn player visual ...

func _on_player_receiver_update(previous_row: PlayerData, player: PlayerData):
    # Player updated
    print("Receiver Update: Player %s ; Health: %d" % [player.name, player.health])
    print("Receiver Previous Value: Player %s ; Health: %d" % [previous_row.name, previous_row.health])
    # ... update player visual ...

func _on_player_receiver_delete(player: PlayerData):
    # Player deleted
    print("Receiver Delete: Player %s" % player.name)
    # ... despawn player visual ...
```

### Using Global signals

Connect directly to the module's signals for broader updates across all tables.

```gdscript
# In your main script's _ready() or where signals are connected:
SpacetimeDB.MyModule.row_inserted.connect(_on_global_row_inserted)
SpacetimeDB.MyModule.row_updated.connect(_on_global_row_updated)
SpacetimeDB.MyModule.row_deleted.connect(_on_global_row_deleted)

func _on_global_row_inserted(table_name: String, row: Resource):
    if row is PlayerData: # Check the type of the inserted row
        print("Global Insert: New PlayerData row!")
        _spawn_player(row) # Your function
    elif row is GameState:
        print("Global Insert: GameState updated!")
        # ... update game state UI ...

func _on_global_row_updated(table_name: String, old_row: Resource, new_row: Resource):
    if new_row is PlayerData:
        print("Global Update: PlayerData updated!")
        _update_player(row) # Your function

func _on_global_row_deleted(table_name: String, row: Resource):
    # Note: This signal provides the primary key, not the full row data
    if row is PlayerData:
        print("Global Delete: PlayerData deleted!")
        _despawn_player(row)
```

## Call Reducers

Use the generated module bindings to trigger server-side logic.

```gdscript
func move_player(direction: Vector2):
    if not SpacetimeDB.MyModule.is_connected_db(): return
    
    # Reducer call returns a call object that the response will use to send out it's callback signals
    var call : SpacetimeDBReducerCall = SpacetimeDB.MyModule.reducers.example_reducer()
    
    # checking if the reducer call was send out successfully
    if call.error:
        # handle reducer call error
        pass
    
    # general callback signal
    call.response.connect(func(update:ReducerResultMessage) -> void: pass)
    
    # reducer successfully ran and returned with data (general subscription data)
    call.on_ok.connect(func(update:ReducerResultMessage) -> void: pass)
    
    # reducer successfully ran and returned without data
    call.on_ok_empty.connect(func(update:ReducerResultMessage) -> void: pass)
    
    # reducer failed to run and returned with the error string
    call.on_error.conect(func(err: String) -> void: pass)
    
    # reducer failed with internal error. not expected to be ever called.
    call.on_internal_error.conect(func(err: String) -> void: pass)
    
    # waiting for the reducer response
    await call1.response

```

## Query Local Database

Access the cached data synchronously at any time.

```gdscript
func get_player_health(identity: PackedByteArray) -> int:
    if SpacetimeDB.MyModule.db:
        # Get a row via any unique index in a table
        var player := SpacetimeDB.MyModule.db.player_data.identity.find(identity)
        if player:
            return player.health
    return -1 # Indicate not found or error

func get_all_cached_players() -> Array[PlayerData]:
    if SpacetimeDB.MyModule.db:
        return SpacetimeDB.MyModule.db.player_data.iter()
    return []
```

---

### Continue reading

-   [API Reference](api.md)
