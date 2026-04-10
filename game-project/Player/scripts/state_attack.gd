extends State
class_name State_Attack

@export var attack_sound : AudioStream

@export var idle_state: State
@export var walk_state: State

@export var attack_duration: float = 0.3

@onready var audio: AudioStreamPlayer2D = $"../../Audio/AudioStreamPlayer2D"
@onready var hurt_box: HurtBox = $"../../HurtBox"

var timer: float = 0.0
var attacking: bool = false


func Enter() -> void:
	attacking = true
	timer = attack_duration

	player.velocity = Vector2.ZERO
	player.state = "attack"
	hurt_box.monitoring = true
	audio.stream = attack_sound
	audio.pitch_scale = randf_range( 0.9, 1.1)
	audio.play()


func Exit() -> void:
	attacking = false
	hurt_box.monitoring = false


func Process(delta: float) -> State:
	return null


func Physics(delta: float) -> State:
	player.velocity = Vector2.ZERO
	player.move_and_slide()

	timer -= delta

	if timer <= 0:
		# return based on input after attack ends
		if player.direction == Vector2.ZERO:
			return idle_state
		else:
			return walk_state

	return null


func HandleInput(event: InputEvent) -> State:
	return null
