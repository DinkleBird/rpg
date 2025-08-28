# PerceptionComponent.gd
extends Node2D

@export var base_perception: float = 50.0
@export var line_of_sight_bonus: float = 20.0
@export var detection_rate: float = 10.0
@export var reduction_rate: float = 5.0
@export var max_sound_perception: float = 50.0

var detection_meter: float = 0.0
var current_sound_modifier: float = 0.0
@onready var player = get_tree().get_first_node_in_group("player")
var player_in_fov: bool = false # Add this line

signal player_detected

func _process(delta: float):
	if not is_instance_valid(player):
		return

	# 1. Get player's stealth rating
	var player_stealth_rating: float = 0.0
	if player.has_node("StealthComponent"):
		player_stealth_rating = player.get_node("StealthComponent").get_stealth_rating()

	# 2. Calculate enemy's perception rating
	var perception_rating: float = base_perception + current_sound_modifier

	# Add bonus for being in the field of view
	if player_in_fov:
		perception_rating += line_of_sight_bonus

	# Add bonus for proximity
	var distance: float = global_position.distance_to(player.global_position)
	var distance_factor: float = 1.0 - clamp(distance / 400.0, 0.0, 1.0) # Using a hardcoded max distance for this example
	perception_rating += distance_factor * (100.0 - base_perception - line_of_sight_bonus)

	# 3. Update the detection meter
	if perception_rating > player_stealth_rating:
		detection_meter += (perception_rating - player_stealth_rating) * detection_rate * delta
	else:
		detection_meter -= reduction_rate * delta

	detection_meter = clamp(detection_meter, 0.0, 100.0)

	if detection_meter >= 100.0:
		emit_signal("player_detected")

	# Reset the sound modifier for the next frame
	current_sound_modifier = 0.0

# Call this from a player's sound-generating action
func hear_sound(sound_level: float, sound_position: Vector2):
	var distance: float = global_position.distance_to(sound_position)
	if distance < sound_level:
		current_sound_modifier += (1.0 - (distance / sound_level)) * max_sound_perception

# Connect these two functions to your CollisionPolygon2D's body_entered and body_exited signals
func _on_fov_body_entered(body):
	if body.is_in_group("player"):
		player_in_fov = true

func _on_fov_body_exited(body):
	if body.is_in_group("player"):
		player_in_fov = false
