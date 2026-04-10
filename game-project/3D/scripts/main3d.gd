extends Node3D

@export var slime_scene: PackedScene
@export var slime_spawn_positions: PackedVector3Array = PackedVector3Array([
	Vector3(6, 0.6, 6),
	Vector3(-6, 0.6, 6),
	Vector3(6, 0.6, -6),
	Vector3(-6, 0.6, -6),
])

@onready var info_label: Label = $HUD/InfoLabel
@onready var perf_label: Label = $HUD/PerfLabel
@onready var player: Player3DController = $Player

var _plants_total: int = 0
var _plants_destroyed: int = 0
var _level2_started: bool = false


func _ready() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_setup_level1()
	_apply_optimization_defaults()
	info_label.visible = false
	perf_label.visible = false


func _process(_delta: float) -> void:
	pass


func _setup_level1() -> void:
	var plants: Array = get_tree().get_nodes_in_group("level1_plants_3d")
	_plants_total = plants.size()
	for p in plants:
		if p is Plant3D:
			(p as Plant3D).destroyed.connect(_on_plant_destroyed)


func _on_plant_destroyed() -> void:
	_plants_destroyed += 1
	var left: int = maxi(_plants_total - _plants_destroyed, 0)
	if left > 0:
		return

	if not _level2_started:
		_start_level2()


func _start_level2() -> void:
	_level2_started = true
	if slime_scene == null:
		return
	for p in slime_spawn_positions:
		var slime: Node = slime_scene.instantiate()
		if slime is Node3D:
			(slime as Node3D).position = p
		add_child(slime)


func _apply_optimization_defaults() -> void:
	# Keep shadows and effects conservative for stable 60 FPS on low/mid hardware.
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 0)
