class_name Slime
extends CharacterBody2D

@export var move_speed: float = 55.0
@export var stop_distance: float = 12.0

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemy")


func _physics_process(_delta: float) -> void:
	var player := _get_player()
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation("idle")
		return

	var to_player := (player.global_position - global_position)
	if to_player.length() <= stop_distance:
		direction = Vector2.ZERO
		velocity = Vector2.ZERO
	else:
		direction = to_player.normalized()
		velocity = direction * move_speed

	_set_direction()
	move_and_slide()

	_update_animation("idle" if direction == Vector2.ZERO else "walk")


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	var p := players[0]
	return p as Node2D


func _set_direction() -> void:
	if direction == Vector2.ZERO:
		return

	if abs(direction.x) > abs(direction.y):
		cardinal_direction = Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if direction.y > 0 else Vector2.UP


func _update_animation(state: String) -> void:
	var anim_name := state + "_" + _anim_direction()
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

	if cardinal_direction == Vector2.LEFT:
		sprite_2d.flip_h = true
	elif cardinal_direction == Vector2.RIGHT:
		sprite_2d.flip_h = false


func _anim_direction() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"
