# Filename: HealthComponent.gd
extends Node

# Signals are a very important Godot feature. They allow us to notify other nodes
# when something happens without needing to know who they are.
signal died
signal damage_taken(damage_amount)
signal healed(heal_amount)

# Export variables to set the max health in the editor.
@export var _max_health = 100.0

# Private variable to store the current health.
var _current_health = 0.0

# The _ready function is called when the node and its children are ready.
func _ready():
	# Initialize current health to the max health.
	_current_health = _max_health

# A function to deal damage.
func take_damage(damage_amount):
	# If we're already dead, don't take more damage
	if _current_health <= 0:
		return

	_current_health -= damage_amount
	emit_signal("damage_taken", damage_amount)

	if _current_health <= 0:
		_current_health = 0
		emit_signal("died")

# A function to heal the character.
func heal(heal_amount):
	if _current_health == _max_health:
		return # Already at full health.
	
	# Increase health by the heal amount.
	_current_health += heal_amount
	
	# Clamp the value to ensure it never goes above max health.
	_current_health = clamp(_current_health, 0, _max_health)
	
	# Emit the healed signal.
	emit_signal("healed", heal_amount)
