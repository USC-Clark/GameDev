extends Node2D

@export var completion_message: String = "Welcome to Level 2"
@export var float_distance: float = 48.0
@export var float_duration: float = 2.5
@export var fade_in_duration: float = 0.35
@export var hold_after_float: float = 0.6
@export var fade_out_duration: float = 0.65

@export var slime_scene: PackedScene
@export var slime_spawn_positions: PackedVector2Array = PackedVector2Array([
	Vector2(120, 60),
	Vector2(360, 180),
])
@export var slime_spawn_after_message: bool = false
@export var net_send_interval: float = 0.08

var _plants_total: int = 0
var _plants_destroyed: int = 0
var _message_shown: bool = false
var _level2_started: bool = false
var _remote_players: Dictionary = {}
var _send_cooldown: float = 0.0

@onready var _banner: Label = $HUD/LevelBanner
@onready var _local_player: Player = $Player
@onready var _player_scene: PackedScene = preload("res://Player/player.tscn")


func _ready() -> void:
	_local_player.set_player_tag("Player 1", Color(1.0, 1.0, 1.0, 1.0))
	_hook_plants()
	_setup_networking()


func _physics_process(delta: float) -> void:
	if Network.match_id == "":
		return
	_send_cooldown -= delta
	if _send_cooldown > 0.0:
		return
	_send_cooldown = net_send_interval
	Network.send_state({
		"x": _local_player.global_position.x,
		"y": _local_player.global_position.y,
		"dir_x": _local_player.direction.x,
		"dir_y": _local_player.direction.y,
		"state": _local_player.state,
		"face_x": _local_player.cardinal_direction.x,
		"face_y": _local_player.cardinal_direction.y
	})


func _hook_plants() -> void:
	var plants := get_tree().get_nodes_in_group("level1_plants")
	_plants_total = plants.size()
	if _plants_total == 0:
		push_warning("Playground: no nodes in group 'level1_plants'. Plants should call add_to_group in _ready.")
		return
	for p in plants:
		if p.has_signal("destroyed"):
			p.destroyed.connect(_on_plant_destroyed)


func _on_plant_destroyed() -> void:
	if _message_shown:
		return
	_plants_destroyed += 1
	if _plants_destroyed >= _plants_total:
		if not slime_spawn_after_message:
			_start_level2()
		_show_floating_welcome()


func _show_floating_welcome() -> void:
	_message_shown = true
	var lbl := _banner
	lbl.text = completion_message
	lbl.visible = true
	lbl.modulate.a = 0.0
	var y0 := lbl.position.y
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "modulate:a", 1.0, fade_in_duration)
	t.tween_property(lbl, "position:y", y0 - float_distance, float_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished

	if slime_spawn_after_message:
		_start_level2()

	await get_tree().create_timer(hold_after_float).timeout
	t = create_tween()
	t.tween_property(lbl, "modulate:a", 0.0, fade_out_duration)


func _start_level2() -> void:
	if _level2_started:
		return
	_level2_started = true

	if slime_scene == null:
		push_warning("Playground: slime_scene not set; level 2 has nothing to spawn.")
		return

	for p in slime_spawn_positions:
		var slime := slime_scene.instantiate()
		if slime is Node2D:
			(slime as Node2D).position = p
		add_child(slime)


func _setup_networking() -> void:
	if Network.match_id == "":
		return
	if not Network.player_state_received.is_connected(_on_player_state_received):
		Network.player_state_received.connect(_on_player_state_received)


func _on_player_state_received(user_id: String, state_data: Dictionary) -> void:
	var remote: Player = _remote_players.get(user_id, null)
	if remote == null:
		remote = _spawn_remote_player()
		_remote_players[user_id] = remote

	var pos := Vector2(float(state_data.get("x", remote.global_position.x)), float(state_data.get("y", remote.global_position.y)))
	var dir := Vector2(float(state_data.get("dir_x", 0.0)), float(state_data.get("dir_y", 0.0)))
	var facing := Vector2(float(state_data.get("face_x", 0.0)), float(state_data.get("face_y", 0.0)))
	var state_name := str(state_data.get("state", "idle"))
	remote.apply_network_state(pos, dir, state_name, facing)


func _spawn_remote_player() -> Player:
	var p := _player_scene.instantiate() as Player
	p.is_local_player = false
	p.name = "RemotePlayer_%d" % (_remote_players.size() + 1)
	p.set_player_tag("Player 2", Color(0.75, 0.9, 1.0, 1.0))
	add_child(p)
	return p
