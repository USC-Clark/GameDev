extends CharacterBody2D

@export var move_speed: float = 260.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1100.0
@export var burst_duration: float = 0.16
@export var step_distance_px: float = 64.0
@export var drop_through_seconds: float = 0.18

const ONE_WAY_PLATFORM_LAYER: int = 5

var _recorded_frames: Array[Dictionary] = []
var _step_index: int = 0
var _move_direction: float = 0.0
var _move_timer: float = 0.0
var _step_target_x: float = 0.0
var _is_stepping: bool = false
var _drop_timer: float = 0.0

@onready var visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group("time_actor")
	visual.color = Color(0.55, 0.7, 1.0, 0.65)


func setup(spawn_position: Vector2, recorded_frames: Array[Dictionary]) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_recorded_frames = recorded_frames.duplicate(true)
	_step_index = 0
	_is_stepping = false
	_step_target_x = global_position.x


func _physics_process(delta: float) -> void:
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
	# jump is triggered only by consume_action()

	move_and_slide()


func consume_action() -> void:
	if _step_index >= _recorded_frames.size():
		return

	var frame: Dictionary = _recorded_frames[_step_index]
	_step_index += 1

	var left_pressed: bool = frame.get("left_pressed", false)
	var right_pressed: bool = frame.get("right_pressed", false)
	var jump_pressed: bool = frame.get("jump_pressed", false)
	var down_pressed: bool = frame.get("down_pressed", false)

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

	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity

	if down_pressed and is_on_floor():
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
