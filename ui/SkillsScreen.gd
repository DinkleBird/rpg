extends Panel

func _ready():
	hide() # Hidden by default

func toggle():
	if visible:
		hide()
	else:
		show()
