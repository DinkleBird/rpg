extends Control

signal size_changed(new_size)

var resizing = false

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		resizing = event.pressed
	elif event is InputEventMouseMotion and resizing:
		var new_size = get_parent().size + event.relative
		emit_signal("size_changed", new_size)
