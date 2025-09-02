extends Panel

@onready var grid_container = $GridContainer
@onready var resize_handle = $ResizeHandle

var dragging = false

func _ready():
	hide() # Hidden by default
	mouse_filter = MOUSE_FILTER_PASS
	resize_handle.resized.connect(_on_resized)

func toggle():
	if visible:
		hide()
	else:
		show()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not resize_handle.get_rect().has_point(event.position):
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		position += event.relative
		position.x = clamp(position.x, 0, get_viewport_rect().size.x - size.x)
		position.y = clamp(position.y, 0, get_viewport_rect().size.y - size.y)

func _on_resized(new_size):
	size = new_size
	size.x = clamp(size.x, 200, get_viewport_rect().size.x)
	size.y = clamp(size.y, 150, get_viewport_rect().size.y)
	position.x = clamp(position.x, 0, get_viewport_rect().size.x - size.x)
	position.y = clamp(position.y, 0, get_viewport_rect().size.y - size.y)

func update_inventory(inventory_data, items_data):
	var slots = grid_container.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		var item_name = inventory_data[i]
		if item_name:
			var item_info = items_data[item_name]
			slot.update_slot(item_name, item_info)
		else:
			slot.update_slot(null, null)