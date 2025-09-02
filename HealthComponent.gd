# Filename: HealthComponent.gd
extends Node

# Signals are a very important Godot feature. They allow us to notify other nodes
# when something happens without needing to know who they are.
signal died
signal damage_taken(damage_amount)
signal healed(heal_amount)

# Export variables to set the max health in the editor.
@export var _max_health = 100.0

# Public variable to check if the character is blocking.
var is_blocking = false

# Preload the particle scene
var block_particle_scene = preload("res://BlockParticle.tscn")

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

	if is_blocking:
		damage_amount *= 0.5 # Reduce damage by 50% when blocking
		# Instantiate the particle effect
		var particles = block_particle_scene.instantiate()
		# Add the particles to the scene tree
		get_tree().root.add_child(particles)
		# Set the particles' position to the owner's position
		particles.global_position = get_parent().global_position
		# Start emitting particles
		particles.emitting = true

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

func reset():
	_current_health = _max_health
	emit_signal("healed", _max_health) # Notify listeners (like the health bar) that health has been restored

func get_health():
	return _current_health

func get_max_health():
	return _max_health
