class_name Player3DController
extends CharacterBody3D

@export var move_speed: float = 6.5
@export var acceleration: float = 18.0
@export var deceleration: float = 20.0
@export var max_hp: int = 5

@export var attack_duration: float = 0.18
@export var attack_cooldown: float = 0.35

var hp: int = 5
var _attack_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _hit_registry: Dictionary = {}

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var attack_area: Area3D = $AttackArea
var _body_base_scale: Vector3 = Vector3.ONE


func _ready() -> void:
	hp = max_hp
	add_to_group("player3d")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	attack_area.monitoring = false
	_body_base_scale = body_mesh.scale
	attack_area.area_entered.connect(_on_attack_area_entered)
	attack_area.body_entered.connect(_on_attack_body_entered)


func _physics_process(delta: float) -> void:
	_update_move(delta)
	_update_attack(delta)


func _update_move(delta: float) -> void:
	var input_vec: Vector2 = _get_move_input_vector()
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	var desired := Vector3(input_vec.x, 0.0, input_vec.y) * move_speed
	var blend := acceleration if input_vec != Vector2.ZERO else deceleration
	velocity.x = move_toward(velocity.x, desired.x, blend * delta)
	velocity.z = move_toward(velocity.z, desired.z, blend * delta)
	velocity.y = 0.0
	move_and_slide()

	if input_vec != Vector2.ZERO:
		var yaw := atan2(-velocity.x, -velocity.z)
		body_mesh.rotation.y = yaw
		attack_area.rotation.y = yaw


func _update_attack(delta: float) -> void:
	_cooldown_timer = max(_cooldown_timer - delta, 0.0)
	_attack_timer = max(_attack_timer - delta, 0.0)
	attack_area.monitoring = _attack_timer > 0.0

	if Input.is_action_just_pressed("attack") and _cooldown_timer <= 0.0:
		_attack_timer = attack_duration
		_cooldown_timer = attack_cooldown
		_hit_registry.clear()
		attack_area.monitoring = true
		call_deferred("_hit_attack_targets")
		_play_attack_feedback()


func _hit_attack_targets() -> void:
	if not attack_area.monitoring:
		return
	for area in attack_area.get_overlapping_areas():
		_try_damage_target(area)
	for body in attack_area.get_overlapping_bodies():
		_try_damage_target(body)


func _play_attack_feedback() -> void:
	var t := create_tween()
	t.tween_property(body_mesh, "scale", _body_base_scale * Vector3(1.1, 0.9, 1.1), 0.06)
	t.tween_property(body_mesh, "scale", _body_base_scale, 0.1)


func _on_attack_area_entered(area: Area3D) -> void:
	if _attack_timer <= 0.0:
		return
	_try_damage_target(area)


func _on_attack_body_entered(body: Node3D) -> void:
	if _attack_timer <= 0.0:
		return
	_try_damage_target(body)


func _try_damage_target(target: Node) -> void:
	if target == null:
		return
	var id := target.get_instance_id()
	if _hit_registry.has(id):
		return
	if target.has_method("take_damage"):
		target.call("take_damage", 1)
		_hit_registry[id] = true


func take_damage(damage: int) -> void:
	hp = max(hp - damage, 0)
	if hp == 0:
		hp = max_hp
		global_position = Vector3(0.0, 1.0, 0.0)


func _get_move_input_vector() -> Vector2:
	# Supports both project actions (arrow keys) and WASD for convenience.
	var x := Input.get_action_strength("right") - Input.get_action_strength("left")
	var y := Input.get_action_strength("down") - Input.get_action_strength("up")

	# Fallback for raw key input so movement works even if actions are not remapped.
	if Input.is_physical_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		y += 1.0

	return Vector2(clampf(x, -1.0, 1.0), clampf(y, -1.0, 1.0))
