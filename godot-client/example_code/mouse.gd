extends Sprite2D

@export var receiver: RowReceiver

var last_position: Vector2

func _ready() -> void:
	receiver.insert.connect(_initialize_player_on_insert)
	receiver.update.connect(_update_player_on_row_update)

func _initialize_player_on_insert(user_data: MainUserData) -> void:
	if get_meta("id") != user_data.identity:
		return
	last_position = Vector2(user_data.last_position.x, user_data.last_position.y)
	$RichTextLabel.text = "[wave]"+ user_data.name

func _update_player_on_row_update(_prev_value: MainUserData, user_data: MainUserData) -> void:
	if get_meta("id") != user_data.identity:
		return
	last_position = Vector2(user_data.last_position.x, user_data.last_position.y)

func _process(delta: float) -> void:
	if not SpacetimeDB.Main.is_connected_db():
		return

	if get_meta("local") == true:
		if last_position != get_global_mouse_position():
			last_position = get_global_mouse_position()
			var vec_to2d := Vector3(last_position.x, last_position.y, 0)
			SpacetimeDB.Main.reducers.move_user(Vector2(0,0), vec_to2d)

	global_position = global_position.lerp(last_position, 10 * delta)
