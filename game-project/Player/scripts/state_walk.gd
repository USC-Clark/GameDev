class_name State_Walk
extends State

@export var idle_state: State
@export var attack_state: State


func Enter() -> void:
	player.state = "walk"


func Exit() -> void:
	pass


func Process(_delta: float) -> State:
	return null


func Physics(_delta: float) -> State:
	player.velocity = player.direction * player.move_speed
	player.move_and_slide()

	if player.direction == Vector2.ZERO:
		return idle_state

	return null


func HandleInput(event: InputEvent) -> State:
	if event.is_action_pressed("attack"):
		return attack_state
	return null
