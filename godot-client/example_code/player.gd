extends CharacterBody3D

@export var receiver: RowReceiver

var last_position: Vector3
var last_local_input: Vector2
var remote_input: Vector2
var remote_speed: float

func _ready() -> void:
	receiver.insert.connect(_initialize_player_on_insert)
	receiver.update.connect(_update_player_on_row_update)

	set_process(get_meta("is_local"))
	set_process_input(get_meta("is_local"))

func test_struct():
	var test_damage = MainDamage.create(16, SpacetimeDB.Main.get_local_identity(), [1,2,3])
	var test_one := MainMessage.new()
	test_one.int_value = 55
	test_one.string_value = "Hello from Godot"
	test_one.int_vec = [1,2,3]
	test_one.string_vec = ["one", "two", "three"]
	var option = Option.new()
	option.set_some(["pip", "pop"])
	test_one.test_option_vec = option

	var test_option = Option.new()
	test_option.set_some("Single string")
	test_one.test_option = test_option
	var option_inner = Option.new()
	option_inner.set_some(test_damage)
	test_one.test_inner = option_inner

	var res = await SpacetimeDB.Main.reducers.test_struct(test_one, func(_t):
		print("Result:", _t)
	)

func test_option_vec(text):
	var opt = Option.new()
	opt.set_some(text)
	SpacetimeDB.Main.reducers.test_option_vec(opt)

func test_option_single(text):
	var opt = Option.new()
	opt.set_some(text)
	SpacetimeDB.Main.reducers.test_option_single(opt)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SpacetimeDB.Main.reducers.change_color_random()

	if event.is_action_pressed("ui_accept"):
		test_struct()
		test_option_vec(["Hello","World"])
		test_option_single("Welcome")

func _initialize_player_on_insert(user_data: MainUserData):
	#Need to receive only THIS entity/table updates
	if get_meta("id") != user_data.identity:
		return

	$MeshInstance3D.get_surface_override_material(0).albedo_color = user_data.color
	$Label3D.text = str(user_data.name)
	last_position = user_data.last_position
	remote_input = user_data.direction
	remote_speed = user_data.player_speed

func _update_player_on_row_update(prev_value: MainUserData, user_data: MainUserData):
	#Need to receive only THIS entity/table updates
	if get_meta("id") != user_data.identity:
		return

	$MeshInstance3D.get_surface_override_material(0).albedo_color = user_data.color
	last_position = user_data.last_position
	remote_input = user_data.direction
	remote_speed = user_data.player_speed

func _process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if last_local_input == input_dir:
		return

	last_local_input = input_dir
	SpacetimeDB.Main.reducers.move_user(input_dir, global_position)

func _physics_process(delta: float) -> void:
	if remote_input == Vector2.ZERO:
		global_position = global_position.lerp(last_position, 10 * delta)
	var direction := Vector3(remote_input.x, 0, remote_input.y)
	if direction:
		velocity.x = direction.x * remote_speed
		velocity.z = direction.z * remote_speed
	move_and_slide()
