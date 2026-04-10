extends Node

const NAKAMA := preload("res://addons/nakama/Nakama.gd")

var client
var session
var socket
var match_id := ""
var my_presence = null
var presences := {} # user_id -> presence
var _nakama: Node

const SERVER_KEY := "defaultkey"
const HOST := "127.0.0.1"
const HTTP_PORT := 7350
const USE_SSL := false
const USE_UNIQUE_DEBUG_DEVICE_ID := true

signal match_joined(match_id)
signal player_state_received(user_id: String, state: Dictionary)
signal player_action_received(user_id: String, action: Dictionary)
signal login_succeeded
signal login_failed(message: String)
signal players_in_match_changed(count: int)
signal enter_game_requested

func _ready() -> void:
	_nakama = NAKAMA.new()
	add_child(_nakama)

	var scheme := "https" if USE_SSL else "http"
	client = _nakama.create_client(SERVER_KEY, HOST, HTTP_PORT, scheme)

func login_device() -> void:
	print("[Network] Logging in with device ID...")
	var device_id := _get_device_id_for_login()
	session = await client.authenticate_device_async(device_id, null, true)
	if session == null:
		var msg := "[Network] Device authentication failed: session is null."
		push_error(msg)
		login_failed.emit(msg)
		return

	socket = _nakama.create_socket_from(client)
	if not socket.received_matchmaker_matched.is_connected(_on_matched):
		socket.received_matchmaker_matched.connect(_on_matched)
	if not socket.received_match_presence.is_connected(_on_match_presence):
		socket.received_match_presence.connect(_on_match_presence)
	if not socket.received_match_state.is_connected(_on_match_state):
		socket.received_match_state.connect(_on_match_state)
	if not socket.received_error.is_connected(_on_socket_error):
		socket.received_error.connect(_on_socket_error)

	var connect_result = await socket.connect_async(session)
	if connect_result.is_exception():
		var msg := "[Network] Socket connection failed: %s" % connect_result.get_exception().message
		push_error(msg)
		login_failed.emit(msg)
		return

	print("[Network] Login and socket connection successful.")
	login_succeeded.emit()

func start_matchmaking() -> void:
	if socket == null:
		push_error("[Network] Cannot start matchmaking: socket is null. Call login_device() first.")
		return
	print("[Network] Searching for match...")
	# Simple 2-player queue.
	var ticket = await socket.add_matchmaker_async("*", 2, 2)
	if ticket.is_exception():
		push_error("[Network] Matchmaking failed: %s" % ticket.get_exception().message)
		return
	print("[Network] Matchmaker ticket created.")

func _on_matched(matched) -> void:
	print("[Network] Match found. Joining...")
	var match = await socket.join_matched_async(matched)
	if match.is_exception():
		push_error("[Network] Failed to join matched game: %s" % match.get_exception().message)
		return
	match_id = match.match_id
	my_presence = match.self_user
	presences.clear()
	for p in match.presences:
		var uid := str(p.user_id)
		if session != null and uid == session.user_id:
			continue
		presences[uid] = p
	print("[Network] Joined match: %s" % match_id)
	emit_signal("match_joined", match_id)
	players_in_match_changed.emit(get_connected_players_count())

func _on_match_presence(presence_event) -> void:
	for p in presence_event.joins:
		presences[p.user_id] = p
	for p in presence_event.leaves:
		presences.erase(p.user_id)
	players_in_match_changed.emit(get_connected_players_count())

func send_state(state: Dictionary) -> void:
	if match_id == "" or socket == null:
		return
	# op_code 1 = movement state
	await socket.send_match_state_async(match_id, 1, JSON.stringify(state))

func send_action(action: Dictionary) -> void:
	if match_id == "" or socket == null:
		return
	# op_code 2 = actions (attack/jump/shoot)
	await socket.send_match_state_async(match_id, 2, JSON.stringify(action))

func _on_match_state(match_state) -> void:
	var parsed: Variant = JSON.parse_string(str(match_state.data))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed

	var from_user: String = str(match_state.presence.user_id)
	if session != null and from_user == session.user_id:
		return

	if match_state.op_code == 1:
		emit_signal("player_state_received", from_user, data)
	elif match_state.op_code == 2:
		emit_signal("player_action_received", from_user, data)
		if str(data.get("type", "")) == "enter_game":
			enter_game_requested.emit()


func _on_socket_error(err) -> void:
	push_warning("[Network] Socket error: %s" % err)


func get_connected_players_count() -> int:
	if match_id == "" or session == null:
		return 0
	# presences only tracks "other users", so include self.
	return presences.size() + 1


func _get_device_id_for_login() -> String:
	var base_id := str(OS.get_unique_id())
	if USE_UNIQUE_DEBUG_DEVICE_ID and OS.is_debug_build():
		# In local multi-instance testing on one machine, force a unique ID per process.
		return "%s_%d" % [base_id, OS.get_process_id()]
	return base_id


func request_enter_game() -> void:
	if match_id == "" or socket == null:
		return
	await send_action({"type": "enter_game"})
