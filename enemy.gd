# Enemy.gd
extends CharacterBody2D

@export var speed = 75.0
@export var attack_cooldown = 1.0
@export var search_duration = 5.0
@export var search_angle_range = 60.0
@export var search_speed = 2.0

@export_group("Perception")
@export var base_perception: float = 70.0
@export var line_of_sight_bonus: float = 20.0
@export var detection_rate: float = 10.0
@export var reduction_rate: float = 5.0
@export var max_sound_perception: float = 50.0

@export_group("Patrol")
@export var patrol_points: Array[Vector2] = []
@export var generate_patrol_points = false
@export var patrol_generation_radius = 200.0
@export var patrol_points_to_generate = 4
@export var min_patrol_wait_time = 3.0
@export var max_patrol_wait_time = 15.0

@export_group("Attack")
@export var attack_range_radius: float = 24.7027

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var perception_component = $PerceptionComponent
@onready var search_timer = $SearchTimer
@onready var patrol_wait_timer = $PatrolWaitTimer
@onready var ignore_player_timer = $IgnorePlayerTimer
@onready var collision_shape = $CollisionShape2D

enum State {
	IDLE,
	PATROL,
	PATROL_WAITING,
	WALK,
	ATTACK,
	HURT,
	DEATH,
	SEARCHING,
	LOOKING_AROUND
}

var current_state = State.IDLE
var player_in_attack_range = false
var player_detected = false
var _current_target: CharacterBody2D = null
var last_movement_direction = Vector2.RIGHT
var last_known_position: Vector2
var patrol_index = 0
var start_position: Vector2

var hitbox_positions = {
	"down": Vector2(0, 20),
	"up": Vector2(0, -20),
	"left": Vector2(-20, 0),
	"right": Vector2(20, 0)
}

func _ready():
	start_position = global_position
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	perception_component.player_detected.connect(_on_player_detected)
	perception_component.sound_heard.connect(_on_sound_heard)
	search_timer.timeout.connect(_on_search_timer_timeout)
	patrol_wait_timer.timeout.connect(_on_patrol_wait_timer_timeout)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.made_sound.connect(perception_component.hear_sound)
	
	if generate_patrol_points:
		_generate_patrol_points()
	
	var fov = perception_component.get_node("FieldOfView")
	fov.body_entered.connect(_on_fov_body_entered)
	fov.body_exited.connect(_on_fov_body_exited)
	
	# Pass exported perception values to the PerceptionComponent
	perception_component.base_perception = base_perception
	perception_component.line_of_sight_bonus = line_of_sight_bonus
	perception_component.detection_rate = detection_rate
	perception_component.reduction_rate = reduction_rate
	perception_component.max_sound_perception = max_sound_perception
	
	# Set attack range radius
	attack_range.get_node("CollisionShape2D").shape.radius = attack_range_radius

func _generate_patrol_points():
	patrol_points.clear()
	var space_state = get_world_2d().direct_space_state
	for i in range(patrol_points_to_generate):
		var random_direction = Vector2.RIGHT.rotated(randf_range(0, 2 * PI))
		var ray_origin = start_position
		var ray_end = ray_origin + random_direction * patrol_generation_radius
		var query = PhysicsRayQueryParameters2D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		
		if result:
			# Add a point slightly before the collision point
			patrol_points.append(result.position - random_direction * 20)
		else:
			# Add the point at the full length of the ray
			patrol_points.append(ray_end)


func _physics_process(_delta):
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			if player_detected and not player_in_attack_range:
				current_state = State.WALK
			elif player_detected and player_in_attack_range and attack_cooldown_timer.is_stopped():
				current_state = State.ATTACK
				update_animation()
			elif not player_detected and not patrol_points.is_empty():
				current_state = State.PATROL
		State.PATROL:
			if not patrol_points.is_empty():
				var target_point = patrol_points[patrol_index]
				# Patrol points are now global, no need to add start_position
				var direction_to_target = (target_point - global_position).normalized()
				velocity = direction_to_target * speed
				move_and_slide()
				
				if global_position.distance_to(target_point) < 10:
					velocity = Vector2.ZERO
					current_state = State.PATROL_WAITING
					patrol_wait_timer.wait_time = randf_range(min_patrol_wait_time, max_patrol_wait_time)
					patrol_wait_timer.start()
			else:
				velocity = Vector2.ZERO
				current_state = State.IDLE
		State.PATROL_WAITING:
			velocity = Vector2.ZERO

		State.WALK:
			if _current_target:
				if player_in_attack_range:
					current_state = State.IDLE
				else:
					last_known_position = _current_target.global_position
					var direction_to_player = (_current_target.global_position - global_position).normalized()
					velocity = direction_to_player * speed
					move_and_slide()
			else:
				velocity = Vector2.ZERO
				current_state = State.IDLE
		State.SEARCHING:
			var direction_to_last_known = (last_known_position - global_position).normalized()
			velocity = direction_to_last_known * speed
			move_and_slide()
			if global_position.distance_to(last_known_position) < 10:
				velocity = Vector2.ZERO
				current_state = State.LOOKING_AROUND
				search_timer.start(search_duration)
		State.LOOKING_AROUND:
			velocity = Vector2.ZERO
			var base_angle = last_movement_direction.angle()
			var offset = sin(Time.get_ticks_msec() * 0.001 * search_speed) * deg_to_rad(search_angle_range / 2.0)
			perception_component.rotation = base_angle + offset
			if perception_component.rotation_degrees > base_angle + 1:
				animated_sprite.flip_h = false
			elif perception_component.rotation_degrees < base_angle - 1:
				animated_sprite.flip_h = true

		State.ATTACK:
			velocity = Vector2.ZERO
		State.HURT:
			pass
		State.DEATH:
			velocity = Vector2.ZERO
			
	if velocity != Vector2.ZERO:
		last_movement_direction = velocity.normalized()
	
	if current_state != State.LOOKING_AROUND:
		perception_component.rotation = last_movement_direction.angle()
	
	if current_state != State.ATTACK and current_state != State.DEATH:
		update_animation()

func _on_player_detected():
	if not ignore_player_timer.is_stopped():
		return
	player_detected = true
	search_timer.stop()
	var players_in_group = get_tree().get_nodes_in_group("player")
	if not players_in_group.is_empty():
		_current_target = players_in_group[0]
		if not _current_target.player_died.is_connected(_on_player_died):
			_current_target.player_died.connect(_on_player_died)
		last_known_position = _current_target.global_position

func _on_player_died():
	if _current_target and _current_target.player_died.is_connected(_on_player_died):
		_current_target.player_died.disconnect(_on_player_died)
	_current_target = null
	player_detected = false
	current_state = State.SEARCHING
	ignore_player_timer.start(5.0)

func _on_sound_heard(sound_position: Vector2):
	if not player_detected: # Only react to sound if not already chasing the player
		last_known_position = sound_position
		current_state = State.SEARCHING
		var direction_to_sound = (sound_position - global_position).normalized()
		if direction_to_sound.x > 0:
			animated_sprite.flip_h = false
		elif direction_to_sound.x < 0:
			animated_sprite.flip_h = true


func _on_fov_body_entered(body):
	if body.is_in_group("player"):
		perception_component.player_in_fov = true
		if current_state == State.SEARCHING or current_state == State.LOOKING_AROUND:
			current_state = State.WALK
			search_timer.stop()


func _on_fov_body_exited(body):
	if body.is_in_group("player"):
		perception_component.player_in_fov = false
		if player_detected:
			current_state = State.SEARCHING

func _on_search_timer_timeout():
	current_state = State.IDLE
	player_detected = false

func _on_patrol_wait_timer_timeout():
	patrol_index = (patrol_index + 1) % patrol_points.size()
	current_state = State.PATROL

func update_animation():
	var anim_name = "Idle"
	if current_state == State.WALK or current_state == State.SEARCHING or current_state == State.PATROL:
		anim_name = "Walk"
		if abs(last_movement_direction.y) > abs(last_movement_direction.x):
			if last_movement_direction.y > 0:
				attack_range.position = hitbox_positions["down"]
			else:
				attack_range.position = hitbox_positions["up"]
		else:
			if last_movement_direction.x > 0:
				animated_sprite.flip_h = false
				attack_range.position = hitbox_positions["right"]
			else:
				animated_sprite.flip_h = true
				attack_range.position = hitbox_positions["left"]
	elif current_state == State.LOOKING_AROUND:
		anim_name = "Idle"
	elif current_state == State.ATTACK:
		var attack_animations = ["Attack01", "Attack02"]
		anim_name = attack_animations[randi() % attack_animations.size()]
		if abs(last_movement_direction.y) > abs(last_movement_direction.x):
			if last_movement_direction.y > 0:
				attack_range.position = hitbox_positions["down"]
			else:
				attack_range.position = hitbox_positions["up"]
		else:
			if last_movement_direction.x > 0:
				animated_sprite.flip_h = false
				attack_range.position = hitbox_positions["right"]
			else:
				animated_sprite.flip_h = true
				attack_range.position = hitbox_positions["left"]
	elif current_state == State.DEATH:
		anim_name = "Death"
	
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _on_died():
	current_state = State.DEATH
	animated_sprite.play("Death")
	set_physics_process(false)

func _on_animation_finished():
	if animated_sprite.animation == "Death":
		queue_free()
	elif animated_sprite.animation.begins_with("Attack"):
		if player_in_attack_range and _current_target and _current_target.has_node("HealthComponent"):
			_current_target.get_node("HealthComponent").take_damage(10)
		attack_cooldown_timer.start(attack_cooldown)
		current_state = State.IDLE

func _on_attack_range_body_entered(body):
	if body.is_in_group("player"):
		player_in_attack_range = true

func _on_attack_range_body_exited(body):
	if body.is_in_group("player"):
		player_in_attack_range = false

func _on_aggro_range_body_entered(body):
	if body.is_in_group("player"):
		_on_player_detected()

func _on_aggro_range_body_exited(_body):
	pass # Add logic here if needed

func _on_attacked_from_direction(attacker_position: Vector2):
	var direction_to_attacker = (attacker_position - global_position).normalized()
	last_movement_direction = direction_to_attacker
	perception_component.rotation = last_movement_direction.angle()

	if direction_to_attacker.x > 0:
		animated_sprite.flip_h = false
	elif direction_to_attacker.x < 0:
		animated_sprite.flip_h = true
	
	if current_state != State.DEATH:
		current_state = State.IDLE

func _on_player_made_sound(sound_level, sound_position):
	perception_component.hear_sound(sound_level, sound_position)
