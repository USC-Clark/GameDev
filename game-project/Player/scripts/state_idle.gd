class_name State_Idle
extends State

@export var walk_state: State
@export var attack_state: State


func Enter() -> void:
	player.state = "idle"
	player.velocity = Vector2.ZERO


func Exit() -> void:
	pass


func Process(_delta: float) -> State:
	return null


func Physics(_delta: float) -> State:
	player.velocity = Vector2.ZERO
	player.move_and_slide()

	if player.direction != Vector2.ZERO:
		return walk_state

	return null


func HandleInput(event: InputEvent) -> State:
	if event.is_action_pressed("attack"):
		return attack_state
	return null
