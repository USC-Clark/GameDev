extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo.tscn")
const ROOM_W := 1280.0
const ROOM_H := 720.0
const ONE_WAY_PLATFORM_LAYER: int = 5

@onready var world: Node2D = $World
@onready var actors: Node2D = $Actors
@onready var ui_steps: Label = $CanvasLayer/UI/StepsLabel
@onready var ui_record: Label = $CanvasLayer/UI/RecordLabel
@onready var ui_level: Label = $CanvasLayer/UI/LevelLabel
@onready var ui_info: Label = $CanvasLayer/UI/InfoLabel
@onready var ui_complete: Label = $CanvasLayer/UI/CompleteLabel
@onready var reset_button: Button = $CanvasLayer/UI/ResetButton
@onready var pause_panel: Panel = $CanvasLayer/UI/PausePanel

var _player: CharacterBody2D
var _echoes: Array[Node] = []
var _buttons: Array[Dictionary] = []
var _doors: Array[Dictionary] = []
var _hazards: Array[Rect2] = []
var _lifts: Array[Dictionary] = []

var _tutorial_levels: Array[Dictionary] = []
var _main_levels: Array[Dictionary] = []
var _active_levels: Array[Dictionary] = []
var _is_tutorial_mode: bool = true
var _level_index: int = 0
var _paused: bool = false
var _is_complete: bool = false
var _last_actions: int = 0
var _free_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(_on_reset_button_pressed)
	_build_level_data()
	_active_levels = _tutorial_levels
	_is_tutorial_mode = true
	_load_level(0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"):
		_reset_level_state("Manual reset.")
		return
	if event.is_action_pressed("toggle_free_mode"):
		_free_mode = not _free_mode
		ui_info.text = ("Free Mode: ON (limits ignored)" if _free_mode else "Free Mode: OFF")
		return
	if event.is_action_pressed("toggle_record") and not _paused and not _is_complete:
		_toggle_recording()
		return
	if _is_complete and event.is_action_pressed("jump"):
		_load_level(_level_index + 1)
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _physics_process(_delta: float) -> void:
	if _paused or _is_complete or _player == null:
		return
	_update_button_states()
	_update_doors()
	_check_hazards()
	_check_exit()


func _process(delta: float) -> void:
	if _paused:
		return
	for lift in _lifts:
		var body: AnimatableBody2D = lift["body"]
		var pressed: bool = _is_button_pressed(lift["button_id"])
		var target: Vector2 = lift["end"] if pressed else lift["start"]
		body.position = body.position.move_toward(target, 120.0 * delta)


func _toggle_recording() -> void:
	if _player.is_recording():
		var recorded_frames: Array[Dictionary] = _player.stop_recording()
		if not recorded_frames.is_empty():
			var echo := ECHO_SCENE.instantiate()
			actors.add_child(echo)
			echo.setup(_current_level()["spawn"], recorded_frames)
			_echoes.append(echo)
		_player.reset_to_spawn()
		ui_info.text = "Echo created. Cooperate with your past self."
	else:
		_player.reset_to_spawn()
		_player.start_recording()
		ui_info.text = "Recording started from spawn."


func _on_actions_changed(current: int, limit: int) -> void:
	ui_steps.text = "Actions: %d / %d" % [current, limit]
	if current > _last_actions:
		var delta_actions := current - _last_actions
		for _i in range(delta_actions):
			for echo in _echoes:
				if echo.has_method("consume_action"):
					echo.consume_action()
	_last_actions = current


func _on_record_state_changed(is_on: bool) -> void:
	ui_record.text = "Record: %s" % ("ON" if is_on else "OFF")


func _on_action_limit_exceeded() -> void:
	if _free_mode:
		return
	_reset_level_state("Action limit exceeded.")


func _on_reset_button_pressed() -> void:
	_reset_level_state("Manual reset.")


func _reset_level_state(reason: String) -> void:
	for echo in _echoes:
		echo.queue_free()
	_echoes.clear()
	_player.cancel_recording()
	_player.reset_to_spawn()
	_last_actions = 0
	_reset_mechanisms()
	ui_info.text = reason
	ui_record.text = "Record: OFF"


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_panel.visible = _paused


func _check_exit() -> void:
	var exit_rect: Rect2 = _current_level()["exit"]
	if exit_rect.has_point(_player.global_position):
		_is_complete = true
		ui_complete.visible = true
		ui_complete.text = "Level Complete!\nPress W to continue."


func _check_hazards() -> void:
	for hz in _hazards:
		if hz.has_point(_player.global_position):
			_reset_level_state("Hazard hit. Reset.")
			return


func _update_button_states() -> void:
	for button_data in _buttons:
		var area: Area2D = button_data["area"]
		var is_pressed := false
		for body in area.get_overlapping_bodies():
			if body == _player or _echoes.has(body):
				is_pressed = true
				break
		button_data["pressed"] = is_pressed
		var visual: ColorRect = button_data["visual"]
		visual.color = Color(0.35, 0.95, 0.4, 1.0) if is_pressed else Color(0.88, 0.45, 0.25, 1.0)


func _update_doors() -> void:
	for door in _doors:
		var should_open := true
		for id in door["button_ids"]:
			if not _is_button_pressed(id):
				should_open = false
				break
		if should_open and door["hold_turns"] > 0:
			door["remaining"] = door["hold_turns"]
		elif not should_open and door["remaining"] > 0:
			door["remaining"] -= 1
			should_open = true
		door["open"] = should_open
		var collider: CollisionShape2D = door["collision"]
		var visual: ColorRect = door["visual"]
		collider.disabled = should_open
		visual.modulate.a = 0.4 if should_open else 1.0
		visual.color = Color(0.15, 0.95, 0.25, 1.0) if should_open else Color(0.8, 0.18, 0.22, 1.0)


func _is_button_pressed(button_id: String) -> bool:
	for button_data in _buttons:
		if button_data["id"] == button_id:
			return button_data["pressed"]
	return false


func _load_level(index: int) -> void:
	if index >= _active_levels.size():
		if _is_tutorial_mode and not _main_levels.is_empty():
			_is_tutorial_mode = false
			_active_levels = _main_levels
			_load_level(0)
			return
		ui_complete.visible = true
		ui_complete.text = "Tutorial complete.\nMain levels will be added next."
		return

	_level_index = index
	_is_complete = false
	ui_complete.visible = false
	get_tree().paused = false
	_paused = false
	pause_panel.visible = false

	for child in world.get_children():
		child.queue_free()
	for child in actors.get_children():
		child.queue_free()

	_echoes.clear()
	_buttons.clear()
	_doors.clear()
	_hazards.clear()
	_lifts.clear()
	_last_actions = 0

	_build_room_shell()
	_build_level_geometry(_current_level())
	_spawn_player(_current_level())
	_reset_mechanisms()

	ui_level.text = "Tutorial %d" % (_level_index + 1) if _is_tutorial_mode else "Level %d" % (_level_index + 1)
	ui_record.text = "Record: OFF"
	ui_info.text = _current_level().get("hint", "Use echoes to solve the chamber.")


func _spawn_player(data: Dictionary) -> void:
	_player = PLAYER_SCENE.instantiate()
	actors.add_child(_player)
	_player.setup(data["spawn"], data["action_limit"])
	_player.action_used.connect(_on_actions_changed)
	_player.recording_toggled.connect(_on_record_state_changed)
	_player.action_limit_exceeded.connect(_on_action_limit_exceeded)


func _build_room_shell() -> void:
	_add_platform(Rect2(0.0, ROOM_H - 28.0, ROOM_W, 28.0), Color(0.2, 0.24, 0.31, 1.0), false)
	_add_platform(Rect2(-12.0, 0.0, 12.0, ROOM_H), Color(0.2, 0.24, 0.31, 1.0), false)
	_add_platform(Rect2(ROOM_W, 0.0, 12.0, ROOM_H), Color(0.2, 0.24, 0.31, 1.0), false)
	_add_platform(Rect2(0.0, -12.0, ROOM_W, 12.0), Color(0.2, 0.24, 0.31, 1.0), false)


func _build_level_geometry(data: Dictionary) -> void:
	for p in data.get("platforms", []):
		_add_platform(p, Color(0.24, 0.3, 0.42, 1.0), true)
	for hz in data.get("hazards", []):
		_add_hazard(hz)
	for b in data.get("buttons", []):
		_add_button(b["id"], b["rect"])
	for d in data.get("doors", []):
		_add_door(d["rect"], d["buttons"], d.get("timer_turns", 0))
	for lift in data.get("lifts", []):
		_add_lift(lift)
	_build_exit(data["exit"])


func _add_platform(rect: Rect2, color: Color, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = (1 << (ONE_WAY_PLATFORM_LAYER - 1)) if one_way else 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 6.0
	body.position = rect.position
	body.add_child(shape)
	world.add_child(body)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = color
	world.add_child(vis)


func _add_hazard(rect: Rect2) -> void:
	_hazards.append(rect)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.9, 0.15, 0.2, 1.0)
	world.add_child(vis)


func _add_button(button_id: String, rect: Rect2) -> void:
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 1 | 2
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	area.position = rect.position
	area.add_child(shape)
	area.monitoring = true
	area.monitorable = true
	world.add_child(area)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.88, 0.45, 0.25, 1.0)
	world.add_child(vis)
	_buttons.append({"id": button_id, "area": area, "visual": vis, "pressed": false})


func _add_door(rect: Rect2, button_ids: Array, timer_turns: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	body.position = rect.position
	body.add_child(shape)
	world.add_child(body)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.8, 0.18, 0.22, 1.0)
	world.add_child(vis)
	_doors.append({"collision": shape, "visual": vis, "button_ids": button_ids, "hold_turns": timer_turns, "remaining": 0, "open": false})


func _add_lift(data: Dictionary) -> void:
	var body := AnimatableBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = data["size"]
	shape.shape = rect_shape
	shape.position = data["size"] * 0.5
	body.position = data["start"]
	body.add_child(shape)
	world.add_child(body)
	var vis := ColorRect.new()
	vis.position = Vector2.ZERO
	vis.size = data["size"]
	vis.color = Color(0.3, 0.65, 0.9, 1.0)
	body.add_child(vis)
	_lifts.append({"body": body, "start": data["start"], "end": data["end"], "button_id": data["button_id"]})


func _build_exit(rect: Rect2) -> void:
	var exit_vis := ColorRect.new()
	exit_vis.position = rect.position
	exit_vis.size = rect.size
	exit_vis.color = Color(0.95, 0.88, 0.2, 1.0)
	world.add_child(exit_vis)


func _reset_mechanisms() -> void:
	for door in _doors:
		door["remaining"] = 0
		door["open"] = false
	for button_data in _buttons:
		button_data["pressed"] = false
	for lift in _lifts:
		var body: AnimatableBody2D = lift["body"]
		body.position = lift["start"]


func _current_level() -> Dictionary:
	return _active_levels[_level_index]


func _build_level_data() -> void:
	_tutorial_levels = [
		{"spawn": Vector2(90, 620), "action_limit": 16, "hint": "Tutorial 1: First Partner", "platforms": [], "buttons": [{"id": "B1", "rect": Rect2(700, 672, 56, 20)}], "doors": [{"rect": Rect2(900, 624, 34, 68), "buttons": ["B1"]}], "exit": Rect2(950, 637, 50, 55)},
		{"spawn": Vector2(90, 620), "action_limit": 10, "hint": "Tutorial 2: Split Paths", "platforms": [Rect2(180, 560, 280, 24), Rect2(560, 470, 240, 24), Rect2(840, 560, 250, 24)], "buttons": [{"id": "B1", "rect": Rect2(220, 528, 56, 20)}], "doors": [{"rect": Rect2(940, 492, 34, 68), "buttons": ["B1"]}], "exit": Rect2(990, 505, 55, 55)},
		{"spawn": Vector2(120, 620), "action_limit": 12, "hint": "Tutorial 3: Elevator Helper", "platforms": [Rect2(860, 350, 250, 24), Rect2(500, 260, 220, 24)], "buttons": [{"id": "B1", "rect": Rect2(140, 660, 56, 20)}], "doors": [{"rect": Rect2(980, 282, 34, 68), "buttons": ["B1"]}], "lifts": [{"start": Vector2(520, 600), "end": Vector2(520, 370), "size": Vector2(120, 20), "button_id": "B1"}], "exit": Rect2(1040, 295, 50, 55)},
		{"spawn": Vector2(100, 620), "action_limit": 12, "hint": "Tutorial 4: Timed Gate", "platforms": [Rect2(300, 560, 250, 24), Rect2(660, 500, 220, 24), Rect2(950, 440, 180, 24)], "buttons": [{"id": "B1", "rect": Rect2(340, 528, 56, 20)}], "doors": [{"rect": Rect2(740, 432, 34, 68), "buttons": ["B1"], "timer_turns": 3}], "exit": Rect2(1040, 385, 50, 55)},
		{"spawn": Vector2(90, 620), "action_limit": 14, "hint": "Tutorial 5: Two Buttons", "platforms": [Rect2(240, 560, 220, 24), Rect2(560, 500, 220, 24), Rect2(880, 560, 220, 24)], "buttons": [{"id": "B1", "rect": Rect2(270, 528, 56, 20)}, {"id": "B2", "rect": Rect2(920, 528, 56, 20)}], "doors": [{"rect": Rect2(700, 432, 34, 68), "buttons": ["B1", "B2"]}], "exit": Rect2(740, 445, 50, 55)},
		{"spawn": Vector2(620, 620), "action_limit": 18, "hint": "Tutorial 6: Two Echoes", "platforms": [Rect2(140, 520, 180, 24), Rect2(960, 520, 180, 24), Rect2(560, 360, 200, 24)], "buttons": [{"id": "B1", "rect": Rect2(170, 488, 56, 20)}, {"id": "B2", "rect": Rect2(990, 488, 56, 20)}], "doors": [{"rect": Rect2(640, 292, 34, 68), "buttons": ["B1", "B2"]}], "exit": Rect2(690, 305, 50, 55)},
		{"spawn": Vector2(90, 620), "action_limit": 16, "hint": "Tutorial 7: Falling Platform", "platforms": [Rect2(240, 560, 170, 24), Rect2(460, 520, 120, 18), Rect2(620, 500, 120, 18), Rect2(860, 560, 220, 24)], "buttons": [{"id": "B1", "rect": Rect2(260, 528, 56, 20)}], "doors": [{"rect": Rect2(950, 492, 34, 68), "buttons": ["B1"]}], "exit": Rect2(1000, 505, 50, 55)},
		{"spawn": Vector2(100, 620), "action_limit": 22, "hint": "Tutorial 8: Lift Chain Puzzle", "platforms": [Rect2(320, 540, 180, 24), Rect2(840, 360, 220, 24)], "buttons": [{"id": "B1", "rect": Rect2(140, 660, 56, 20)}, {"id": "B2", "rect": Rect2(520, 508, 56, 20)}], "doors": [{"rect": Rect2(930, 292, 34, 68), "buttons": ["B1", "B2"]}], "lifts": [{"start": Vector2(260, 620), "end": Vector2(260, 460), "size": Vector2(120, 20), "button_id": "B1"}, {"start": Vector2(620, 500), "end": Vector2(620, 320), "size": Vector2(120, 20), "button_id": "B2"}], "exit": Rect2(980, 305, 50, 55)},
		{"spawn": Vector2(90, 620), "action_limit": 24, "hint": "Tutorial 9: Hazard Room", "platforms": [Rect2(200, 520, 200, 24), Rect2(520, 460, 200, 24), Rect2(860, 520, 220, 24)], "hazards": [Rect2(400, 692, 460, 26)], "buttons": [{"id": "B1", "rect": Rect2(240, 488, 56, 20)}], "doors": [{"rect": Rect2(960, 452, 34, 68), "buttons": ["B1"]}], "lifts": [{"start": Vector2(640, 620), "end": Vector2(640, 420), "size": Vector2(120, 20), "button_id": "B1"}], "exit": Rect2(1010, 465, 50, 55)},
		{"spawn": Vector2(620, 620), "action_limit": 30, "hint": "Tutorial 10: Master Chamber", "platforms": [Rect2(120, 520, 180, 24), Rect2(960, 520, 180, 24), Rect2(560, 420, 180, 24), Rect2(560, 300, 200, 24)], "hazards": [Rect2(320, 692, 640, 26)], "buttons": [{"id": "B1", "rect": Rect2(150, 488, 56, 20)}, {"id": "B2", "rect": Rect2(990, 488, 56, 20)}], "doors": [{"rect": Rect2(640, 232, 34, 68), "buttons": ["B1", "B2"], "timer_turns": 3}], "lifts": [{"start": Vector2(620, 620), "end": Vector2(620, 360), "size": Vector2(120, 20), "button_id": "B1"}], "exit": Rect2(700, 245, 50, 55)}
	]
	_main_levels = []
