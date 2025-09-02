extends Panel

signal item_swapped(from_slot, to_slot)
signal item_equipped(item_data, slot_type)

signal item_unequipped(slot_type)

@export var slot_type = "inventory"

var item_name = null
var item_data = null

func _get_drag_data(at_position):
	if item_data:
		var preview = TextureRect.new()
		preview.texture = item_data.texture
		preview.size = Vector2(64, 64)
		set_drag_preview(preview)
		return {"item_name": item_name, "item": item_data, "from_slot": get_index(), "from_slot_type": slot_type}
	return null

func _can_drop_data(at_position, data):
	return data is Dictionary and "item" in data

func _drop_data(at_position, data):
	if slot_type == "inventory":
		if data.from_slot_type == "inventory":
			# Swapping within inventory
			var from_slot_index = data.from_slot
			var to_slot_index = get_index()
			emit_signal("item_swapped", from_slot_index, to_slot_index)
		else:
			# Unequipping from an equipment slot
			emit_signal("item_unequipped", data.from_slot_type)
	else:
		# Equipping to an equipment slot
		if data.from_slot_type == "inventory":
			emit_signal("item_equipped", data.item_name, slot_type)

# Logic to update the item icon and count
func update_slot(new_item_name, new_item_data):
	item_name = new_item_name
	item_data = new_item_data
	if item_data:
		$Icon.texture = item_data.texture
		if item_data.has("stackable") and item_data.stackable:
			$Count.text = str(item_data.count)
		else:
			$Count.text = ""
	else:
		$Icon.texture = null
		$Count.text = ""
