class_name Slime3D
extends CharacterBody3D

@export var move_speed: float = 3.8
@export var damage: int = 1
@export var damage_interval: float = 1.0
@export var stop_distance: float = 1.0

var _damage_cd: float = 0.0
var _target: Player3DController

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var hit_area: Area3D = $HitArea


func _ready() -> void:
	var players: Array = get_tree().get_nodes_in_group("player3d")
	if not players.is_empty():
		_target = players[0] as Player3DController
	hit_area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_damage_cd = max(_damage_cd - delta, 0.0)
	if _target == null:
		return

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= stop_distance:
		velocity = Vector3.ZERO
	else:
		var dir := to_target.normalized()
		velocity = dir * move_speed
		var yaw := atan2(-dir.x, -dir.z)
		body_mesh.rotation.y = yaw

	move_and_slide()


func _on_body_entered(body: Node) -> void:
	if _damage_cd > 0.0:
		return
	if body is Player3DController:
		(body as Player3DController).take_damage(damage)
		_damage_cd = damage_interval
