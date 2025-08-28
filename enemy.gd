# Enemy.gd
extends CharacterBody2D

@export var speed = 75.0
@export var attack_cooldown = 1.0
@export var sneak_detection_chance = 0.1 # 10% chance to detect sneaking player from behind

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var aggro_range = $AggroRange

enum State                                 {
	IDLE,
	WALK,
	ATTACK,
	HURT,
	DEATH
}

var current_state = State.IDLE
var player_in_range = false
var player_in_aggro_range = false
var player_in_aggro_area = false # New variable to track if player is in the AggroRange Area2D
var crouch_detection_modifier = 0.5 # 50% reduction in aggro range when crouching
var _current_target: CharacterBody2D = null # Stores the currently detected target

var hitbox_positions = {
	"right": Vector2(20, 0),
	"left": Vector2(-20, 0)
}

func _ready():
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
func _physics_process(_delta):

	var target_player_node = null
	var players_in_group = get_tree().get_nodes_in_group("player")
	if not players_in_group.is_empty():
		target_player_node = players_in_group[0] # Assuming one player for now

	# Only perform detailed detection if player is in the AggroRange Area2D
	if target_player_node and player_in_aggro_area:
		var player_script_instance = target_player_node as CharacterBody2D

		if player_script_instance:
			var distance_to_player = global_position.distance_to(player_script_instance.global_position)
			var base_aggro_radius = 150.0 # Assuming 100 is the base radius from the scene
			var current_aggro_radius = base_aggro_radius

			var is_player_behind = false
			var enemy_forward_vector = Vector2(1, 0) # Assuming right is forward
			if animated_sprite.flip_h: # If flipped, facing left
				enemy_forward_vector = Vector2(-1, 0)
			
			var direction_to_player_normalized = (player_script_instance.global_position - global_position).normalized()
			var dot_product = direction_to_player_normalized.dot(enemy_forward_vector)

			# A dot product close to -1 means they are directly behind
			if dot_product < -0.7: # Player is behind the enemy (adjust threshold as needed)
				is_player_behind = true

			var detected_this_frame = false

			if distance_to_player <= current_aggro_radius:
				if player_script_instance.is_crouching and is_player_behind:
					# Player is crouching AND behind, apply random chance
					if randf() < sneak_detection_chance:
						detected_this_frame = true
				else:
					# Not crouching, or not behind, so always detect if in range
					detected_this_frame = true
			
			# Update the actual Area2D's shape radius
			if aggro_range.get_node("CollisionShape2D").shape is CircleShape2D:
				(aggro_range.get_node("CollisionShape2D").shape as CircleShape2D).radius = current_aggro_radius

			if detected_this_frame:
				if not player_in_aggro_range: # Only set if it just became detected
					player_script_instance.set_undetected(false) # Player is now detected
				player_in_aggro_range = true # Player is detected (within effective range)
				_current_target = player_script_instance # Set current target
			else:
				if player_in_aggro_range: # Only set if it just became undetected
					player_script_instance.set_undetected(true) # Player is now undetected
				player_in_aggro_range = false # Player is not detected (outside effective range due to crouching or distance)
				_current_target = null # Clear current target
		else:
			if player_in_aggro_range: # Only set if it just became undetected (invalid instance)
				player_script_instance.set_undetected(true) # Player is now undetected
			player_in_aggro_range = false # Not a valid player script instance
			_current_target = null # Clear current target
	else:
		# This case is tricky because target_player_node is null.
		# The player_in_aggro_range will be false, so the player is effectively undetected.
		# The player's is_undetected flag should already be true if they were never detected.
		# If they were detected and then left the aggro area, _on_aggro_range_body_exited handles it.
		pass # No action needed here, _on_aggro_range_body_exited handles the transition to undetected
		player_in_aggro_range = false # No player found or player not in aggro area
		_current_target = null # Clear current target

	match current_state:
		State.WALK:
			if target_player_node and player_in_aggro_range:
				if player_in_range:
					current_state = State.IDLE
				else:
					var direction_to_player = (target_player_node.global_position - global_position).normalized()
					velocity = direction_to_player * speed
					move_and_slide()
			else:
				velocity = Vector2.ZERO
				current_state = State.IDLE
		State.IDLE:
			velocity = Vector2.ZERO
			if player_in_aggro_range and not player_in_range:
				current_state = State.WALK
			elif player_in_aggro_range and player_in_range and attack_cooldown_timer.is_stopped():
				current_state = State.ATTACK
				update_animation()
		State.ATTACK:
			velocity = Vector2.ZERO
		State.HURT:
			pass
		State.DEATH:
			velocity = Vector2.ZERO
	
	if current_state != State.ATTACK and current_state != State.DEATH:
		update_animation()

func _on_aggro_range_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_aggro_area = true

func _on_aggro_range_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_aggro_area = false
		player_in_aggro_range = false # Ensure detection is reset when player leaves the area
		var player_script_instance = body as CharacterBody2D
		if player_script_instance:
			player_script_instance.set_undetected(true) # Player is now undetected

func update_animation():
	var anim_name = "Idle"
	if current_state == State.WALK:
		anim_name = "Walk"
		if velocity.x > 0:
			animated_sprite.flip_h = false
			attack_range.position = hitbox_positions["right"]
			aggro_range.position = Vector2(20, 0) # Adjust as needed
		elif velocity.x < 0:
			animated_sprite.flip_h = true
			attack_range.position = hitbox_positions["left"]
			aggro_range.position = Vector2(-20, 0) # Adjust as needed
	elif current_state == State.ATTACK:
		var attack_animations = ["Attack01", "Attack02"]
		anim_name = attack_animations[randi() % attack_animations.size()]
		# Ensure attack_range is positioned correctly for attack animation
		if animated_sprite.flip_h == false: # Facing right
			attack_range.position = hitbox_positions["right"]
		else: # Facing left
			attack_range.position = hitbox_positions["left"]
	elif current_state == State.DEATH:
		anim_name = "Death"
	
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _on_died():
	current_state = State.DEATH
	animated_sprite.play("Death")
	set_physics_process(false)
#	$CollisionShape2D.disabled = true

func _on_animation_finished():
	if animated_sprite.animation == "Death":
		queue_free()
	elif animated_sprite.animation.begins_with("Attack"):
		# Deal damage and start cooldown after the attack animation finishes
		# Only deal damage if player is still in range AND in front of the enemy
		if player_in_range and _current_target and _current_target.has_node("HealthComponent"):
			var direction_to_player = (_current_target.global_position - global_position).normalized()
			var dot_product = direction_to_player.dot(Vector2(1, 0) if not animated_sprite.flip_h else Vector2(-1, 0))
			if dot_product > 0.5: # Player is generally in front (adjust threshold as needed)
				_current_target.get_node("HealthComponent").take_damage(10)
		attack_cooldown_timer.start(attack_cooldown)
		current_state = State.IDLE

func _on_attack_range_body_entered(body):
	if body.is_in_group("player"):
		# Check if player is in front of the enemy
		var direction_to_player = (body.global_position - global_position).normalized()
		var dot_product = direction_to_player.dot(Vector2(1, 0) if not animated_sprite.flip_h else Vector2(-1, 0))
		if dot_product > 0.5: # Player is generally in front (adjust threshold as needed)
			player_in_range = true
		else:
			player_in_range = false # Player is behind

func _on_attack_range_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false

func _on_attacked_from_direction(attacker_position: Vector2):
	# Calculate direction to attacker
	var direction_to_attacker = (attacker_position - global_position).normalized()

	# Determine facing direction
	if direction_to_attacker.x > 0:
		animated_sprite.flip_h = false # Face right
	elif direction_to_attacker.x < 0:
		animated_sprite.flip_h = true # Face left
	
	# Force re-check for player and potential attack
	if current_state != State.DEATH:
		current_state = State.IDLE # Reset to IDLE to force re-evaluation
