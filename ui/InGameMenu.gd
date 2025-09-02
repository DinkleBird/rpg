extends Panel

@onready var resize_handle = $ResizeHandle

var dragging = false

func _ready():
	hide()
	$NinePatchRect/VBoxContainer/ExitButton.pressed.connect(_on_exit_button_pressed)
	mouse_filter = MOUSE_FILTER_PASS
	resize_handle.resized.connect(_on_resized)

func _on_exit_button_pressed():
	get_tree().quit()

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
