# Filename: PerceptionComponent.gd
extends Node2D

@export var grace_period: float = 2.0

var base_perception: float = 50.0
var line_of_sight_bonus: float = 20.0
var detection_rate: float = 10.0
var reduction_rate: float = 5.0
var max_sound_perception: float = 50.0

var detection_meter: float = 0.0
var current_sound_modifier: float = 0.0
@onready var grace_timer = $GraceTimer
var players_in_range = []
var player_in_fov: bool = false

signal player_detected
signal player_detection_state_changed(is_detected)
signal sound_heard(sound_position)

func _ready():
	grace_timer.wait_time = grace_period
	grace_timer.one_shot = true
	#$PlayerDetectionRange.body_entered.connect(_on_player_detection_range_body_entered)
	#$PlayerDetectionRange.body_exited.connect(_on_player_detection_range_body_exited)

func _process(delta: float):
	if players_in_range.is_empty():
		return

	var closest_player = null
	var closest_distance = 100000.0

	for player in players_in_range:
		if not is_instance_valid(player):
			continue
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player
	
	if not is_instance_valid(closest_player):
		return

	var player_stealth_rating: float = 0.0
	if closest_player.has_node("StealthComponent"):
		player_stealth_rating = closest_player.get_node("StealthComponent").get_stealth_rating()

	var perception_rating: float = 0.0 # Start with 0 perception
	var has_sensory_input = false

	if player_in_fov:
		has_sensory_input = true
		perception_rating += base_perception
		perception_rating += line_of_sight_bonus
		
		var distance_factor: float = 1.0 - clamp(closest_distance / 400.0, 0.0, 1.0)
		perception_rating += distance_factor * (100.0 - base_perception - line_of_sight_bonus)

	if current_sound_modifier > 0:
		has_sensory_input = true
		perception_rating += current_sound_modifier

	var was_detected = detection_meter >= 100.0
	if has_sensory_input and perception_rating > player_stealth_rating:
		detection_meter += (perception_rating - player_stealth_rating) * detection_rate * delta
		grace_timer.stop()
	elif grace_timer.is_stopped():
		detection_meter -= reduction_rate * delta

	detection_meter = clamp(detection_meter, 0.0, 100.0)

	var is_detected = detection_meter >= 100.0
	if was_detected != is_detected:
		emit_signal("player_detection_state_changed", is_detected)

	if is_detected:
		emit_signal("player_detected")

	# Decay sound modifier over time
	current_sound_modifier = lerp(current_sound_modifier, 0.0, delta * 5.0) # Decay rate of 5.0

# Corrected function to handle multiple sound sources
func hear_sound(sound_level: float, sound_position: Vector2):
	var max_modifier = 0.0
	var sound_source_position = Vector2.ZERO
	for player in players_in_range:
		var distance: float = global_position.distance_to(player.global_position)
		if distance < sound_level:
			var modifier = (1.0 - (distance / sound_level)) * max_sound_perception
			if modifier > max_modifier:
				max_modifier = modifier
				sound_source_position = player.global_position
	
	current_sound_modifier = max_modifier
	if current_sound_modifier > 0:
		emit_signal("sound_heard", sound_source_position)

func set_player_in_fov(in_fov: bool):
	player_in_fov = in_fov
	if not in_fov:
		grace_timer.start()

func _on_fov_body_entered(body):
	if body.is_in_group("player"):
		set_player_in_fov(true)

func _on_fov_body_exited(body):
	print("--- PerceptionComponent _on_fov_body_exited ---")
	print("body: ", body.name)
	if body.is_in_group("player"):
		set_player_in_fov(false)

func get_closest_player():
	var closest_player = null
	var closest_distance = 100000.0

	for player in players_in_range:
		if not is_instance_valid(player):
			continue
		var distance = global_position.distance_to(player.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_player = player
	
	return closest_player

func _on_player_detection_range_body_entered(body):
	print("--- PerceptionComponent _on_player_detection_range_body_entered ---")
	print("body: ", body.name)
	if body.is_in_group("player"):
		if not players_in_range.has(body):
			players_in_range.append(body)

func _on_player_detection_range_body_exited(body):
	if body.is_in_group("player"):
		if players_in_range.has(body):
			players_in_range.erase(body)
