extends Node3D

@export var receiver: RowReceiver
@export var player_scene: PackedScene
var players: Dictionary[PackedByteArray, Node3D]

func _ready() -> void:
	receiver.insert.connect(receive_user)
	receiver.delete.connect(on_user_offline)

func on_user_offline(user_row: MainUserData):
	var player = players.get(user_row.identity)
	if player == null:
		return
	print("Remove player: ", user_row.name)
	player.queue_free()
	players[user_row.identity] = null

func receive_user(user_row: MainUserData):
	print("Spawn player: ", user_row.identity.hex_encode())

	var new_player := player_scene.instantiate()
	new_player.set_meta("id", user_row.identity)

	if user_row.identity == SpacetimeDB.Main.get_local_identity():
		new_player.set_meta("is_local", true)
	else:
		new_player.set_meta("is_local", false)

	add_child(new_player)

	new_player.global_position.y = 1
	players[user_row.identity] = new_player
