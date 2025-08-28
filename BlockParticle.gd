extends CPUParticles2D

func _ready():
	# Connect the finished signal to a function that will be called when the particles are done emitting.
	finished.connect(_on_finished)

func _on_finished():
	# When the particles are done, free the scene.
	queue_free()
