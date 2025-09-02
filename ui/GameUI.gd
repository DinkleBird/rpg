extends CanvasLayer

# This script will manage the UI, including showing/hiding different panels
# like inventory, character sheet, and skills.

var inventory_screen_scene = preload("res://ui/InventoryScreen.tscn")
var inventory_screen

var equipped_items_screen_scene = preload("res://ui/EquippedItemsScreen.tscn")
var equipped_items_screen

var skills_screen_scene = preload("res://ui/SkillsScreen.tscn")
var skills_screen

var in_game_menu_scene = preload("res://ui/InGameMenu.tscn")
var in_game_menu

var player

func _ready():
	inventory_screen = inventory_screen_scene.instantiate()
	add_child(inventory_screen)
	var inventory_slots = inventory_screen.grid_container.get_children()
	for slot in inventory_slots:
		slot.item_swapped.connect(_on_item_swapped)
		slot.item_unequipped.connect(_on_item_unequipped)

	equipped_items_screen = equipped_items_screen_scene.instantiate()
	add_child(equipped_items_screen)
	equipped_items_screen.weapon_slot.item_equipped.connect(_on_item_equipped)
	equipped_items_screen.shield_slot.item_equipped.connect(_on_item_equipped)

	skills_screen = skills_screen_scene.instantiate()
	add_child(skills_screen)

	in_game_menu = in_game_menu_scene.instantiate()
	add_child(in_game_menu)

	# Wait for the player to be ready before connecting signals
	await get_tree().create_timer(0.1).timeout
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.inventory_changed.connect(_on_player_inventory_changed)
		player.equipment_changed.connect(_on_player_equipment_changed)
		# Initial update
		_on_player_inventory_changed(player.inventory)
		_on_player_equipment_changed(player.equipped_weapon, player.equipped_shield)


	$NetworkUI/CreateServerButton.pressed.connect(NetworkManager.create_server)
	$NetworkUI/JoinServerButton.pressed.connect(func(): NetworkManager.join_server($NetworkUI/IPAddressLineEdit.text))
	NetworkManager.connected_to_server.connect(_on_player_connected)
	NetworkManager.player_connected.connect(_on_player_connected)

func _on_player_connected(_id = 0):
	$NetworkUI.hide()

func _on_player_inventory_changed(inventory):
	if player:
		inventory_screen.update_inventory(inventory, player.items)

func _on_player_equipment_changed(equipped_weapon, equipped_shield):
	if player:
		equipped_items_screen.update_equipment(equipped_weapon, equipped_shield, player.items)

func _on_item_swapped(from_index, to_index):
	if player:
		player.swap_inventory_items(from_index, to_index)

func _on_item_equipped(item_name, slot_type):
	if player:
		player.equip_item(item_name, slot_type)

func _on_item_unequipped(slot_type):
	if player:
		player.unequip_item(slot_type)

func _input(event):
	if Input.is_action_just_pressed("ui_cancel"):
		if inventory_screen.visible:
			inventory_screen.hide()
		elif equipped_items_screen.visible:
			equipped_items_screen.hide()
		elif skills_screen.visible:
			skills_screen.hide()
		elif in_game_menu.visible:
			in_game_menu.hide()
		else:
			in_game_menu.show()

	# Example: Toggle inventory with "i" key
	if Input.is_action_pressed("ui_inventory"):
		inventory_screen.toggle()
		if inventory_screen.visible and player:
			inventory_screen.update_inventory(player.inventory, player.items)


	# Example: Toggle character/equipment screen with "c" key
	if Input.is_action_pressed("ui_character"):
		equipped_items_screen.toggle()
		if equipped_items_screen.visible and player:
			equipped_items_screen.update_equipment(player.equipped_weapon, player.equipped_shield, player.items)

	# Example: Toggle skills screen with "k" key
	if Input.is_action_pressed("ui_skills"):
		skills_screen.toggle()
