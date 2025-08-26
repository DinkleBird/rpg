# Filename: HealthComponent.gd
extends Node

# Signals are a very important Godot feature. They allow us to notify other nodes
# when something happens without needing to know who they are.
signal died
signal damage_taken(damage_amount)
signal healed(heal_amount)

# Export variables to set the max health in the editor.
@export var max_health = 100.0

# Private variable to store the current health.
var _current_health = 0.0

# The _ready function is called when the node and its children are ready.
func _ready():
	# Initialize current health to the max health.
	_current_health = max_health

# A function to deal damage.
func take_damage(damage_amount):
	if _current_health <= 0:
		return # Already dead, do nothing.
	
	# Decrease health by the damage amount.
	_current_health -= damage_amount
	
	# Clamp the value to ensure it never goes below zero.
	_current_health = clamp(_current_health, 0, max_health)
	
	# Emit the damage_taken signal, notifying any connected nodes.
	emit_signal("damage_taken", damage_amount)
	
	# If health drops to zero, emit the died signal.
	if _current_health == 0:
		emit_signal("died")

# A function to heal the character.
func heal(heal_amount):
	if _current_health == max_health:
		return # Already at full health.
	
	# Increase health by the heal amount.
	_current_health += heal_amount
	
	# Clamp the value to ensure it never goes above max health.
	_current_health = clamp(_current_health, 0, max_health)
	
	# Emit the healed signal.
	emit_signal("healed", heal_amount)
