extends CanvasLayer

# This script will manage the UI, including showing/hiding different panels
# like inventory, character sheet, and skills.

var inventory_screen_scene = preload("res://ui/InventoryScreen.tscn")
var inventory_screen

var equipped_items_screen_scene = preload("res://ui/EquippedItemsScreen.tscn")
var equipped_items_screen

var skills_screen_scene = preload("res://ui/SkillsScreen.tscn")
var skills_screen

func _ready():
	inventory_screen = inventory_screen_scene.instantiate()
	add_child(inventory_screen)

	equipped_items_screen = equipped_items_screen_scene.instantiate()
	add_child(equipped_items_screen)

	skills_screen = skills_screen_scene.instantiate()
	add_child(skills_screen)

func _input(event):
	# Example: Toggle inventory with "i" key
	if event.is_action_pressed("ui_inventory"):
		inventory_screen.toggle()

	# Example: Toggle character/equipment screen with "c" key
	if event.is_action_pressed("ui_character"):
		equipped_items_screen.toggle()

	# Example: Toggle skills screen with "k" key
	if event.is_action_pressed("ui_skills"):
		skills_screen.toggle()
