class_name Player
extends CharacterBody2D

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 100.0
var state: String = "idle"
@export var is_local_player: bool = true

@export var max_hp: int = 5
var hp: int = 5

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var state_machine: PlayerStateMachine = $StateMachine
var _name_label: Label


func _ready():
	hp = max_hp
	_ensure_name_label()
	if is_local_player:
		add_to_group("player")
		set_player_tag("Player 1", Color(1.0, 1.0, 1.0, 1.0))
		state_machine.Initialize(self)
		if has_node("HitBox"):
			$HitBox.Damaged.connect(_on_damaged)
	else:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
		collision_layer = 0
		collision_mask = 0
		if has_node("CollisionShape2D"):
			$CollisionShape2D.disabled = true
		if has_node("HurtBox"):
			$HurtBox.monitoring = false
		if has_node("HitBox"):
			$HitBox.monitoring = false
		# Tint remote player so it is easy to distinguish from local player.
		sprite_2d.modulate = Color(0.65, 0.85, 1.0, 0.9)
		set_player_tag("Player 2", Color(0.75, 0.9, 1.0, 1.0))


func _physics_process(delta):
	if not is_local_player:
		UpdateAnimation()
		return

	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	direction = direction.normalized()

	SetDirection()
	UpdateAnimation()


func SetDirection() -> bool:
	if direction == Vector2.ZERO:
		return false

	if abs(direction.x) > abs(direction.y):
		cardinal_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if direction.y > 0 else Vector2.UP

	return true


func UpdateAnimation() -> void:
	var anim_name := state + "_" + AnimDirection()
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

	if cardinal_direction == Vector2.LEFT:
		sprite_2d.flip_h = true
	elif cardinal_direction == Vector2.RIGHT:
		sprite_2d.flip_h = false


func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"


func _on_damaged(damage: int) -> void:
	TakeDamage(damage)


func TakeDamage(damage: int) -> void:
	hp = max(hp - damage, 0)
	print("Player HP:", hp)


func apply_network_state(net_pos: Vector2, net_dir: Vector2, net_state: String, net_facing: Vector2) -> void:
	global_position = net_pos
	direction = net_dir
	state = net_state
	if net_facing != Vector2.ZERO:
		cardinal_direction = net_facing


func set_player_tag(tag_text: String, tag_color: Color = Color(1, 1, 1, 1)) -> void:
	_ensure_name_label()
	_name_label.text = tag_text
	_name_label.modulate = tag_color


func _ensure_name_label() -> void:
	if _name_label != null:
		return
	_name_label = Label.new()
	_name_label.name = "NameTag"
	_name_label.text = ""
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-40, -56)
	_name_label.size = Vector2(80, 20)
	_name_label.z_index = 50
	add_child(_name_label)
