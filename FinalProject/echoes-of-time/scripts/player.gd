extends CharacterBody2D

signal action_used(current_actions: int, limit: int)
signal action_limit_exceeded
signal recording_toggled(is_recording: bool)
signal recording_finished(recorded_frames: Array[Dictionary])

@export var move_speed: float = 260.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1100.0
@export var burst_duration: float = 0.16
@export var step_distance_px: float = 64.0
@export var drop_through_seconds: float = 0.18

const ONE_WAY_PLATFORM_LAYER: int = 5

var spawn_position: Vector2 = Vector2.ZERO
var action_limit: int = 8
var actions_used: int = 0

var _is_recording: bool = false
var _recorded_frames: Array[Dictionary] = []
var _move_direction: float = 0.0
var _move_timer: float = 0.0
var _step_target_x: float = 0.0
var _is_stepping: bool = false
var _drop_timer: float = 0.0

@onready var visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group("time_actor")
	_update_visual()


func setup(spawn: Vector2, limit: int) -> void:
	spawn_position = spawn
	action_limit = limit
	actions_used = 0
	global_position = spawn_position
	velocity = Vector2.ZERO
	emit_signal("action_used", actions_used, action_limit)


func _physics_process(delta: float) -> void:
	var left_pressed := Input.is_action_just_pressed("move_left")
	var right_pressed := Input.is_action_just_pressed("move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var down_pressed := Input.is_action_just_pressed("move_down")

	_process_move_press(left_pressed, right_pressed)
	_consume_action_inputs(left_pressed, right_pressed, jump_pressed)
	_try_drop_through(down_pressed)
	_apply_motion(delta, jump_pressed)
	_refresh_actions_if_at_spawn()

	if _is_recording and (left_pressed or right_pressed or jump_pressed or down_pressed):
		_recorded_frames.append({
			"left_pressed": left_pressed,
			"right_pressed": right_pressed,
			"jump_pressed": jump_pressed,
			"down_pressed": down_pressed
		})


func _process_move_press(left_pressed: bool, right_pressed: bool) -> void:
	if left_pressed:
		_move_direction = -1.0
		_move_timer = burst_duration
		_step_target_x = global_position.x - step_distance_px
		_is_stepping = true
	elif right_pressed:
		_move_direction = 1.0
		_move_timer = burst_duration
		_step_target_x = global_position.x + step_distance_px
		_is_stepping = true


func _consume_action_inputs(left_pressed: bool, right_pressed: bool, jump_pressed: bool) -> void:
	if left_pressed:
		_use_action()
	if right_pressed:
		_use_action()
	if jump_pressed:
		_use_action()


func _apply_motion(delta: float, jump_pressed: bool) -> void:
	_update_drop_through(delta)

	if _is_stepping:
		var remaining := _step_target_x - global_position.x
		var dur := maxf(0.001, burst_duration)
		var step_speed := step_distance_px / dur
		var dir := signf(remaining)
		velocity.x = dir * step_speed
		if absf(remaining) <= step_speed * delta:
			global_position.x = _step_target_x
			velocity.x = 0.0
			_is_stepping = false
			_move_timer = 0.0
	else:
		velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
	elif jump_pressed:
		velocity.y = jump_velocity

	move_and_slide()


func _try_drop_through(down_pressed: bool) -> void:
	if not down_pressed:
		return
	if not is_on_floor():
		return
	_drop_timer = drop_through_seconds
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
	global_position.y += 2.0


func _update_drop_through(delta: float) -> void:
	if _drop_timer <= 0.0:
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)
		return
	_drop_timer = maxf(0.0, _drop_timer - delta)
	if _drop_timer == 0.0:
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)


func start_recording() -> void:
	reset_to_spawn()
	_is_recording = true
	_recorded_frames.clear()
	_update_visual()
	emit_signal("recording_toggled", true)


func stop_recording() -> Array[Dictionary]:
	if not _is_recording:
		return []
	_is_recording = false
	_update_visual()
	emit_signal("recording_toggled", false)
	emit_signal("recording_finished", _recorded_frames.duplicate(true))
	return _recorded_frames.duplicate(true)


func cancel_recording() -> void:
	_is_recording = false
	_recorded_frames.clear()
	_update_visual()
	emit_signal("recording_toggled", false)


func is_recording() -> bool:
	return _is_recording


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	actions_used = 0
	_move_direction = 0.0
	_move_timer = 0.0
	_is_stepping = false
	_step_target_x = global_position.x
	emit_signal("action_used", actions_used, action_limit)


func _use_action() -> void:
	actions_used += 1
	emit_signal("action_used", actions_used, action_limit)
	if actions_used > action_limit:
		emit_signal("action_limit_exceeded")


func _refresh_actions_if_at_spawn() -> void:
	if global_position.distance_to(spawn_position) <= 6.0 and actions_used != 0:
		actions_used = 0
		emit_signal("action_used", actions_used, action_limit)


func _update_visual() -> void:
	visual.color = Color(0.2, 0.9, 1.0, 1.0) if _is_recording else Color(0.95, 0.95, 1.0, 1.0)
