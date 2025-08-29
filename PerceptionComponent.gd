# PerceptionComponent.gd
extends Node2D

var base_perception: float = 50.0
var line_of_sight_bonus: float = 20.0
var detection_rate: float = 10.0
var reduction_rate: float = 5.0
var max_sound_perception: float = 50.0

var detection_meter: float = 0.0
var current_sound_modifier: float = 0.0
@onready var player = get_tree().get_first_node_in_group("player")
var player_in_fov: bool = false # Add this line

signal player_detected
signal sound_heard(sound_position)

func _process(delta: float):
	if not is_instance_valid(player):
		return

	var player_stealth_rating: float = 0.0
	if player.has_node("StealthComponent"):
		player_stealth_rating = player.get_node("StealthComponent").get_stealth_rating()

	var perception_rating: float = 0.0 # Start with 0 perception
	var has_sensory_input = false

	if player_in_fov:
		has_sensory_input = true
		perception_rating += base_perception
		perception_rating += line_of_sight_bonus
		
		var distance: float = global_position.distance_to(player.global_position)
		var distance_factor: float = 1.0 - clamp(distance / 400.0, 0.0, 1.0)
		perception_rating += distance_factor * (100.0 - base_perception - line_of_sight_bonus)

	if current_sound_modifier > 0:
		has_sensory_input = true
		perception_rating += current_sound_modifier

	if has_sensory_input and perception_rating > player_stealth_rating:
		detection_meter += (perception_rating - player_stealth_rating) * detection_rate * delta
	else:
		detection_meter -= reduction_rate * delta

	detection_meter = clamp(detection_meter, 0.0, 100.0)

	if detection_meter >= 100.0:
		emit_signal("player_detected")

	current_sound_modifier = 0.0

# Call this from a player's sound-generating action
func hear_sound(sound_level: float, sound_position: Vector2):
	var distance: float = global_position.distance_to(sound_position)
	if distance < sound_level:
		current_sound_modifier += (1.0 - (distance / sound_level)) * max_sound_perception
		emit_signal("sound_heard", sound_position)

# Connect these two functions to your CollisionPolygon2D's body_entered and body_exited signals
func _on_fov_body_entered(body):
	if body.is_in_group("player"):
		player_in_fov = true

func _on_fov_body_exited(body):
	if body.is_in_group("player"):
		player_in_fov = false
