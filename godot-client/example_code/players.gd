extends Node2D

@export var player_prefab: PackedScene

func _ready() -> void:
	$"../lobby_holder".user_join.connect(spawn)
	$"../lobby_holder".user_leave.connect(despawn)

func spawn(user: MainUser) -> void:
	var player := player_prefab.instantiate()
	player.set_meta("id", user.identity)
	player.set_meta("local", user.identity == SpacetimeDB.Main.get_local_identity())
	player.name = user.identity.hex_encode()
	add_child(player)

func despawn(user: MainUser) -> void:
	var player := get_node_or_null(str(user.identity.hex_encode()))
	if player != null:
		player.queue_free()
