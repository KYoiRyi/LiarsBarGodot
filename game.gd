extends Node

# --- Game State Enums ---
enum GameState { WAITING, DEALING, PLAYER_TURN, CHALLENGE_REVEAL, ROULETTE, GAME_OVER }
enum CardRank { Q, K, A, JOKER }

var state = GameState.WAITING

# --- Data ---
var players_state = {} # peer_id: { "name": str, "is_alive": bool, "hand": [CardRank], "bullets": int, "chamber": int }
var player_order = []
var current_turn_idx = 0

var current_target_rank = CardRank.Q
var table_cards = [] 
var last_played_cards = [] 
var last_player_id = 0

# --- UI Elements ---
var ui_layer: CanvasLayer
var status_label: Label
var hand_container: HBoxContainer
var table_label: Label
var action_panel: PanelContainer
var play_btn: Button
var challenge_btn: Button
var pull_trigger_btn: Button
var selected_cards_idx = [] 

# Assets
var tex_bg: Texture2D
var tex_card_back: Texture2D
var tex_card_q: Texture2D
var tex_card_k: Texture2D
var tex_card_a: Texture2D
var tex_card_joker: Texture2D
var tex_revolver: Texture2D

func _ready():
	_load_assets()
	_setup_ui()
	
	if multiplayer.is_server():
		_init_server_state()
		_start_round()

func _load_assets():
	var dir = DirAccess.open("res://assets")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("table_bg") and file_name.ends_with(".jpg"):
				tex_bg = load("res://assets/" + file_name)
			elif file_name.begins_with("card_back") and file_name.ends_with(".jpg"):
				tex_card_back = load("res://assets/" + file_name)
			elif file_name.begins_with("card_queen") and file_name.ends_with(".jpg"):
				tex_card_q = load("res://assets/" + file_name)
			elif file_name.begins_with("card_king") and file_name.ends_with(".jpg"):
				tex_card_k = load("res://assets/" + file_name)
			elif file_name.begins_with("card_ace") and file_name.ends_with(".jpg"):
				tex_card_a = load("res://assets/" + file_name)
			elif file_name.begins_with("card_joker") and file_name.ends_with(".jpg"):
				tex_card_joker = load("res://assets/" + file_name)
			elif file_name.begins_with("revolver") and file_name.ends_with(".jpg"):
				tex_revolver = load("res://assets/" + file_name)
			file_name = dir.get_next()

func get_card_texture(rank):
	match rank:
		CardRank.Q: return tex_card_q
		CardRank.K: return tex_card_k
		CardRank.A: return tex_card_a
		CardRank.JOKER: return tex_card_joker
	return tex_card_back

func _setup_ui():
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Background
	if tex_bg:
		var bg_rect = TextureRect.new()
		bg_rect.texture = tex_bg
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui_layer.add_child(bg_rect)
	
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	ui_layer.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	status_label = Label.new()
	status_label.text = "Waiting..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(status_label)
	
	table_label = Label.new()
	table_label.text = "Table is empty"
	table_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_label.add_theme_color_override("font_color", Color.WHITE)
	table_label.add_theme_color_override("font_outline_color", Color.BLACK)
	table_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(table_label)
	
	action_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0,0,0, 0.5)
	action_panel.add_theme_stylebox_override("panel", style)
	vbox.add_child(action_panel)
	
	var action_hbox = HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_panel.add_child(action_hbox)
	
	play_btn = Button.new()
	play_btn.text = "Play Selected Cards"
	play_btn.pressed.connect(_on_play_btn_pressed)
	action_hbox.add_child(play_btn)
	
	challenge_btn = Button.new()
	challenge_btn.text = "Liar! (Challenge)"
	challenge_btn.pressed.connect(_on_challenge_btn_pressed)
	action_hbox.add_child(challenge_btn)
	
	pull_trigger_btn = Button.new()
	pull_trigger_btn.text = "Pull Trigger!"
	pull_trigger_btn.pressed.connect(_on_pull_trigger_pressed)
	# If we have revolver texture, make it an icon
	if tex_revolver:
		pull_trigger_btn.icon = tex_revolver
		pull_trigger_btn.expand_icon = true
		pull_trigger_btn.custom_minimum_size = Vector2(150, 150)
	action_hbox.add_child(pull_trigger_btn)
	pull_trigger_btn.hide()
	
	hand_container = HBoxContainer.new()
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(hand_container)
	
	_update_action_buttons()

func get_rank_name(rank):
	match rank:
		CardRank.Q: return "Queen"
		CardRank.K: return "King"
		CardRank.A: return "Ace"
		CardRank.JOKER: return "Joker"
	return "Unknown"

# --- SERVER LOGIC ---

func _init_server_state():
	for id in Global.players:
		player_order.append(id)
		players_state[id] = {
			"name": Global.players[id],
			"is_alive": true,
			"hand": [],
			"bullets": 1,
			"chamber": randi() % 6
		}

func _start_round():
	state = GameState.DEALING
	table_cards.clear()
	last_played_cards.clear()
	last_player_id = 0
	selected_cards_idx.clear()
	
	current_target_rank = [CardRank.Q, CardRank.K, CardRank.A][randi() % 3]
	
	var deck = []
	for i in range(6):
		deck.append(CardRank.Q)
		deck.append(CardRank.K)
		deck.append(CardRank.A)
	deck.append(CardRank.JOKER)
	deck.append(CardRank.JOKER)
	deck.shuffle()
	
	var alive_players = []
	for id in player_order:
		if players_state[id]["is_alive"]:
			alive_players.append(id)
			players_state[id]["hand"].clear()
	
	if alive_players.size() <= 1:
		_end_game()
		return
	
	for i in range(5):
		for id in alive_players:
			if deck.size() > 0:
				players_state[id]["hand"].append(deck.pop_back())
	
	for id in players_state:
		rpc_id(id, "sync_round_start", current_target_rank, players_state[id]["hand"])
		
	if not players_state[player_order[current_turn_idx]]["is_alive"]:
		_next_turn()
	else:
		state = GameState.PLAYER_TURN
		rpc("sync_turn", player_order[current_turn_idx])

func _next_turn():
	var start_idx = current_turn_idx
	while true:
		current_turn_idx = (current_turn_idx + 1) % player_order.size()
		if players_state[player_order[current_turn_idx]]["is_alive"]:
			break
		if current_turn_idx == start_idx:
			_end_game()
			return
			
	state = GameState.PLAYER_TURN
	rpc("sync_turn", player_order[current_turn_idx])

func _end_game():
	state = GameState.GAME_OVER
	var winner = "No one"
	for id in players_state:
		if players_state[id]["is_alive"]:
			winner = players_state[id]["name"]
	rpc("sync_game_over", winner)

@rpc("any_peer", "call_local", "reliable")
func server_play_cards(card_indices):
	if not multiplayer.is_server() or state != GameState.PLAYER_TURN: return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_order[current_turn_idx]: return
	
	if card_indices.size() < 1 or card_indices.size() > 3: return
	
	card_indices.sort()
	card_indices.reverse()
	
	var played_cards = []
	var hand = players_state[sender_id]["hand"]
	for idx in card_indices:
		if idx >= 0 and idx < hand.size():
			played_cards.append(hand[idx])
			hand.remove_at(idx)
			
	if played_cards.is_empty(): return
	
	table_cards.append({"peer_id": sender_id, "count": played_cards.size()})
	last_played_cards = played_cards
	last_player_id = sender_id
	
	rpc("sync_table", table_cards)
	_next_turn()

@rpc("any_peer", "call_local", "reliable")
func server_challenge():
	if not multiplayer.is_server() or state != GameState.PLAYER_TURN: return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != player_order[current_turn_idx]: return
	if last_player_id == 0: return 
	
	state = GameState.CHALLENGE_REVEAL
	
	var is_liar = false
	for card in last_played_cards:
		if card != current_target_rank and card != CardRank.JOKER:
			is_liar = true
			break
			
	var victim_id = last_player_id if is_liar else sender_id
	
	rpc("sync_challenge_result", sender_id, last_player_id, last_played_cards, is_liar, victim_id)
	
	await get_tree().create_timer(3.0).timeout
	
	state = GameState.ROULETTE
	rpc("sync_roulette_phase", victim_id)

@rpc("any_peer", "call_local", "reliable")
func server_pull_trigger():
	if not multiplayer.is_server() or state != GameState.ROULETTE: return
	var sender_id = multiplayer.get_remote_sender_id()
	
	var victim = players_state[sender_id]
	var chamber = victim["chamber"]
	var bullet_pos = victim["bullet_pos"]
	
	var died = (chamber == bullet_pos)
	
	if died:
		victim["is_alive"] = false
	else:
		victim["chamber"] = (chamber + 1) % 6
		
	rpc("sync_trigger_result", sender_id, died)
	
	await get_tree().create_timer(3.0).timeout
	
	_start_round()

# --- CLIENT RPCs ---

@rpc("authority", "call_local", "reliable")
func sync_round_start(target_rank, hand):
	current_target_rank = target_rank
	selected_cards_idx.clear()
	table_cards.clear()
	
	_render_hand(hand)
	table_label.text = "Target Card: " + get_rank_name(current_target_rank) + "\nTable is empty."

@rpc("authority", "call_local", "reliable")
func sync_turn(active_peer_id):
	var active_name = Global.players[active_peer_id]
	if active_peer_id == multiplayer.get_unique_id():
		status_label.text = "It's YOUR turn!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "Turn: " + active_name
		status_label.add_theme_color_override("font_color", Color.WHITE)
	
	_update_action_buttons(active_peer_id == multiplayer.get_unique_id())

@rpc("authority", "call_local", "reliable")
func sync_table(table):
	var text = "Target Card: " + get_rank_name(current_target_rank) + "\n\nTable:\n"
	for play in table:
		text += Global.players[play["peer_id"]] + " played " + str(play["count"]) + " cards.\n"
	table_label.text = text

@rpc("authority", "call_local", "reliable")
func sync_challenge_result(challenger_id, challenged_id, cards, is_liar, victim_id):
	var challenger_name = Global.players[challenger_id]
	var challenged_name = Global.players[challenged_id]
	
	var text = challenger_name + " challenged " + challenged_name + "!\n"
	text += challenged_name + " played: "
	for c in cards:
		text += get_rank_name(c) + " "
	text += "\n\n"
	
	if is_liar:
		text += challenged_name + " WAS LYING!"
	else:
		text += challenged_name + " told the truth!"
		
	table_label.text = text
	_update_action_buttons(false)

@rpc("authority", "call_local", "reliable")
func sync_roulette_phase(victim_id):
	var victim_name = Global.players[victim_id]
	status_label.text = victim_name + " is playing Russian Roulette..."
	status_label.add_theme_color_override("font_color", Color.RED)
	
	if victim_id == multiplayer.get_unique_id():
		_update_action_buttons(false, true)
	else:
		_update_action_buttons(false)

@rpc("authority", "call_local", "reliable")
func sync_trigger_result(victim_id, died):
	var victim_name = Global.players[victim_id]
	_update_action_buttons(false)
	if died:
		status_label.text = "BANG! " + victim_name + " died!"
	else:
		status_label.text = "*click* " + victim_name + " survived!"

@rpc("authority", "call_local", "reliable")
func sync_game_over(winner_name):
	status_label.text = "Game Over! Winner: " + winner_name
	_update_action_buttons(false)
	table_label.text = ""

# --- UI Interactions ---

func _render_hand(hand):
	for child in hand_container.get_children():
		child.queue_free()
		
	for i in range(hand.size()):
		var rank = hand[i]
		var tex = get_card_texture(rank)
		
		var btn = TextureButton.new()
		if tex:
			btn.texture_normal = tex
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(120, 180)
		btn.toggle_mode = true
		btn.pressed.connect(_on_card_toggled.bind(i, btn))
		hand_container.add_child(btn)

func _on_card_toggled(idx, btn):
	if btn.button_pressed:
		if selected_cards_idx.size() >= 3:
			btn.button_pressed = false
			return
		selected_cards_idx.append(idx)
		btn.modulate = Color(1.5, 1.5, 1.5) # highlight
	else:
		selected_cards_idx.erase(idx)
		btn.modulate = Color(1, 1, 1)

func _update_action_buttons(is_my_turn = false, is_roulette = false):
	play_btn.hide()
	challenge_btn.hide()
	pull_trigger_btn.hide()
	
	if is_my_turn:
		play_btn.show()
		if table_label.text.find("played") != -1:
			challenge_btn.show()
	elif is_roulette:
		pull_trigger_btn.show()

func _on_play_btn_pressed():
	if selected_cards_idx.is_empty():
		return
	server_play_cards.rpc_id(1, selected_cards_idx)
	_update_action_buttons(false)

func _on_challenge_btn_pressed():
	server_challenge.rpc_id(1)
	_update_action_buttons(false)

func _on_pull_trigger_pressed():
	server_pull_trigger.rpc_id(1)
	_update_action_buttons(false)
