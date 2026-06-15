extends Control

var host_btn: Button
var join_btn: Button
var start_btn: Button
var name_input: LineEdit
var ip_input: LineEdit
var player_list: ItemList

func _ready():
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_CENTER)
	add_child(vbox)

	var title = Label.new()
	title.text = "Liar's Bar - Godot Edition"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter your name"
	name_input.text = "Player" + str(randi() % 1000)
	vbox.add_child(name_input)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	host_btn = Button.new()
	host_btn.text = "Host Game"
	host_btn.pressed.connect(_on_host_pressed)
	hbox.add_child(host_btn)

	join_btn = Button.new()
	join_btn.text = "Join Game"
	join_btn.pressed.connect(_on_join_pressed)
	hbox.add_child(join_btn)

	ip_input = LineEdit.new()
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.text = "127.0.0.1"
	hbox.add_child(ip_input)

	player_list = ItemList.new()
	player_list.custom_minimum_size = Vector2(300, 200)
	vbox.add_child(player_list)

	start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.disabled = true
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	Global.player_connected.connect(_on_player_updated)
	Global.player_disconnected.connect(_on_player_updated)

func _on_host_pressed():
	Global.my_name = name_input.text
	if Global.host_game(8910) == OK:
		host_btn.disabled = true
		join_btn.disabled = true
		start_btn.disabled = false
		_update_player_list()

func _on_join_pressed():
	Global.my_name = name_input.text
	if Global.join_game(ip_input.text, 8910) == OK:
		host_btn.disabled = true
		join_btn.disabled = true
		start_btn.disabled = true

func _on_player_updated(id = 0, info = ""):
	_update_player_list()

func _update_player_list():
	player_list.clear()
	for id in Global.players:
		player_list.add_item(Global.players[id] + (" (Host)" if id == 1 else ""))

func _on_start_pressed():
	Global.start_game_rpc.rpc()
