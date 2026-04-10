extends Control

@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var players_label: Label = $CenterContainer/VBoxContainer/PlayersLabel
@onready var enter_game_button: Button = $CenterContainer/VBoxContainer/EnterGameButton

var _changing_scene: bool = false


func _ready() -> void:
	enter_game_button.disabled = true
	enter_game_button.pressed.connect(_on_enter_game_pressed)
	_start_flow()


func _start_flow() -> void:
	status_label.text = "Connecting to Nakama..."
	players_label.text = "Players connected: 0 / 2"

	if not Network.login_failed.is_connected(_on_login_failed):
		Network.login_failed.connect(_on_login_failed)
	if not Network.login_succeeded.is_connected(_on_login_succeeded):
		Network.login_succeeded.connect(_on_login_succeeded)
	if not Network.match_joined.is_connected(_on_match_joined):
		Network.match_joined.connect(_on_match_joined)
	if not Network.players_in_match_changed.is_connected(_on_players_in_match_changed):
		Network.players_in_match_changed.connect(_on_players_in_match_changed)
	if not Network.enter_game_requested.is_connected(_on_enter_game_requested):
		Network.enter_game_requested.connect(_on_enter_game_requested)

	await Network.login_device()
	if Network.session == null or Network.socket == null:
		return

	status_label.text = "Searching for a match (2 players)..."
	await Network.start_matchmaking()


func _on_login_failed(message: String) -> void:
	status_label.text = "Login failed.\n%s" % message


func _on_login_succeeded() -> void:
	players_label.text = "Players connected: 1 / 2"


func _on_match_joined(_id: String) -> void:
	status_label.text = "Match joined. Waiting for players..."
	_on_players_in_match_changed(Network.get_connected_players_count())


func _on_players_in_match_changed(count: int) -> void:
	players_label.text = "Players connected: %d / 2" % count
	enter_game_button.disabled = count < 2
	if count >= 2:
		status_label.text = "Both players connected. Press Enter Game."


func _on_enter_game_pressed() -> void:
	if _changing_scene:
		return
	if Network.get_connected_players_count() < 2:
		return
	status_label.text = "Starting match..."
	await Network.request_enter_game()
	_go_to_game()


func _on_enter_game_requested() -> void:
	_go_to_game()


func _go_to_game() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	status_label.text = "Loading game..."
	get_tree().change_scene_to_file("res://playground.tscn")
