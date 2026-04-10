class_name Plant3D
extends Area3D

signal destroyed

@export var tall_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var cut_scale: Vector3 = Vector3(1.0, 0.35, 1.0)
@export var cut_tint: Color = Color(0.62, 0.82, 0.44, 1.0)

var _is_cut: bool = false

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collider: CollisionShape3D = $CollisionShape3D
var _mesh_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("level1_plants_3d")
	_mesh.scale = tall_scale
	var mat := _mesh.get_active_material(0)
	if mat is StandardMaterial3D:
		_mesh_mat = (mat as StandardMaterial3D).duplicate()
		_mesh.set_surface_override_material(0, _mesh_mat)


func take_damage(_amount: int) -> void:
	if _is_cut:
		return
	_is_cut = true
	_cut_grass()
	destroyed.emit()


func _cut_grass() -> void:
	var tween := create_tween()
	tween.tween_property(_mesh, "scale", cut_scale, 0.12)
	if _mesh_mat != null:
		_mesh_mat.albedo_color = cut_tint
	# Prevent repeated hits after being cut.
	monitoring = false
	monitorable = false
	if _collider:
		_collider.disabled = true
