extends ProgressBar

# This script assumes that its parent node has a HealthComponent sibling.

@onready var health_component = get_parent().get_node("HealthComponent")

func _ready():
	# Make sure the health component is valid before connecting
	if !health_component:
		print("HealthBar: HealthComponent not found on parent.")
		return
	visible = true
	
	# Set the max value of the progress bar from the HealthComponent
	max_value = health_component._max_health
	# Set the initial value of the progress bar
	value = health_component._current_health

	# Connect to the signals from the HealthComponent
	health_component.damage_taken.connect(_on_health_changed)
	health_component.healed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

func _on_health_changed(_amount):
	value = health_component._current_health

func _on_died():
	# Hide the health bar when the owner dies
	visible = false