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
@export var attack_distance: float = 30.0

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var perception_component = $PerceptionComponent
@onready var search_timer = $SearchTimer
@onready var patrol_wait_timer = $PatrolWaitTimer
@onready var ignore_player_timer = $IgnorePlayerTimer
@onready var collision_shape = $CollisionShape2D

var attack_cooldown_timer: Timer
var _lost_player_timer: Timer
var _attack_timeout_timer: Timer

enum State {
	IDLE,
	PATROL,
	PATROL_WAITING,
	ATTACK,
	HURT,
	DEATH,
	SEARCHING,
	LOOKING_AROUND,
	ALERT,
	ALERT_LOST_PLAYER
}

var current_state = State.IDLE
var player_in_attack_range = false
var player_detected = false
var _current_target: CharacterBody2D = null
var last_movement_direction = Vector2.RIGHT
var last_known_position: Vector2
var patrol_index = 0
var start_position: Vector2
var can_attack = true
var is_attacking = false

func _set_state(new_state):
	if current_state != new_state:
		
		if new_state == State.ATTACK:
			_attack_timeout_timer.start(attack_cooldown * 3.0)
		elif current_state == State.ATTACK and new_state != State.ATTACK:
			_attack_timeout_timer.stop()
		
		current_state = new_state

var hitbox_positions = {
	"down": Vector2(0, 20),
	"up": Vector2(0, -20),
	"left": Vector2(-20, 0),
	"right": Vector2(20, 0)
}

func _ready():
	start_position = global_position

	attack_cooldown_timer = Timer.new()
	add_child(attack_cooldown_timer)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)

	_lost_player_timer = Timer.new()
	add_child(_lost_player_timer)
	_lost_player_timer.timeout.connect(_on_lost_player_timer_timeout)

	_attack_timeout_timer = Timer.new()
	add_child(_attack_timeout_timer)
	_attack_timeout_timer.timeout.connect(_on_attack_timeout_timer_timeout)


	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	perception_component.player_detected.connect(_on_player_detected)
	perception_component.sound_heard.connect(_on_sound_heard)
	search_timer.timeout.connect(_on_search_timer_timeout)
	patrol_wait_timer.timeout.connect(_on_patrol_wait_timer_timeout)
	
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		for player in players:
			if not player.made_sound.is_connected(perception_component.hear_sound):
				print("Sound made by", player)
				player.made_sound.connect(perception_component.hear_sound)

	if generate_patrol_points:
		_generate_patrol_points()
	
	var fov = perception_component.get_node("FieldOfView")
	if not fov.body_entered.is_connected(_on_fov_body_entered):
		fov.body_entered.connect(_on_fov_body_entered)
	if not fov.body_exited.is_connected(_on_fov_body_exited):
		fov.body_exited.connect(_on_fov_body_exited)
	
	perception_component.base_perception = base_perception
	perception_component.line_of_sight_bonus = line_of_sight_bonus
	perception_component.detection_rate = detection_rate
	perception_component.reduction_rate = reduction_rate
	perception_component.max_sound_perception = max_sound_perception
	
	attack_range.get_node("CollisionShape2D").shape.radius = attack_range_radius
	
	# Connect attack range signals
	if not attack_range.body_entered.is_connected(_on_attack_range_body_entered):
		attack_range.body_entered.connect(_on_attack_range_body_entered)
	if not attack_range.body_exited.is_connected(_on_attack_range_body_exited):
		attack_range.body_exited.connect(_on_attack_range_body_exited)

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
			patrol_points.append(result.position - random_direction * 20)
		else:
			patrol_points.append(ray_end)


func _physics_process(_delta):
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			if player_detected:
				_set_state(State.ALERT)
			elif not patrol_points.is_empty():
				_set_state(State.PATROL)
		State.PATROL:
			if not patrol_points.is_empty():
				var target_point = patrol_points[patrol_index]
				var direction_to_target = (target_point - global_position).normalized()
				velocity = direction_to_target * speed
				move_and_slide()
				
				if global_position.distance_to(target_point) < 10:
					velocity = Vector2.ZERO
					_set_state(State.PATROL_WAITING)
					patrol_wait_timer.wait_time = randf_range(min_patrol_wait_time, max_patrol_wait_time)
					patrol_wait_timer.start()
			else:
				velocity = Vector2.ZERO
				_set_state(State.IDLE)
		State.PATROL_WAITING:
			velocity = Vector2.ZERO
		State.ALERT:
			if _current_target and is_instance_valid(_current_target):
				var distance_to_player = global_position.distance_to(_current_target.global_position)

				if player_in_attack_range and can_attack:
					_set_state(State.ATTACK)
					print("Attack State!")
				elif can_attack:
					if distance_to_player > attack_distance + 5:
						last_known_position = _current_target.global_position
						var direction_to_player = (_current_target.global_position - global_position).normalized()
						velocity = direction_to_player * speed
						move_and_slide()
						_lost_player_timer.stop()
					elif distance_to_player < attack_distance - 5:
						last_known_position = _current_target.global_position
						var direction_away_from_player = (global_position - _current_target.global_position).normalized()
						velocity = direction_away_from_player * speed
						move_and_slide()
						_lost_player_timer.stop()
					else:
						velocity = Vector2.ZERO
						_lost_player_timer.stop()
				else:
					velocity = Vector2.ZERO
			else:
				_set_state(State.ALERT_LOST_PLAYER)
				if _lost_player_timer.is_stopped():
					_lost_player_timer.start(2.0)
				velocity = Vector2.ZERO
		State.ALERT_LOST_PLAYER:
			velocity = Vector2.ZERO
		State.SEARCHING:
			var direction_to_last_known = (last_known_position - global_position).normalized()
			velocity = direction_to_last_known * speed
			move_and_slide()
			if global_position.distance_to(last_known_position) < 10:
				velocity = Vector2.ZERO
				_set_state(State.LOOKING_AROUND)
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
			if not is_attacking:
				is_attacking = true
				can_attack = false
				update_animation()
		State.HURT:
			pass
		State.DEATH:
			velocity = Vector2.ZERO
			
	if velocity != Vector2.ZERO:
		last_movement_direction = velocity.normalized()
	
	if current_state != State.LOOKING_AROUND:
		perception_component.rotation = last_movement_direction.angle()
	
	if current_state != State.ATTACK and current_state != State.DEATH and attack_cooldown_timer.is_stopped():
		update_animation()

func _on_player_detected():
	if not ignore_player_timer.is_stopped():
		return
	player_detected = true
	search_timer.stop()
	_lost_player_timer.stop()
	
	_current_target = perception_component.get_closest_player()

	if _current_target and is_instance_valid(_current_target):
		if not _current_target.player_died.is_connected(_on_player_died):
			_current_target.player_died.connect(_on_player_died)
		last_known_position = _current_target.global_position
		_set_state(State.ALERT)

func _on_player_died():
	if _current_target and _current_target.player_died.is_connected(_on_player_died):
		_current_target.player_died.disconnect(_on_player_died)
	_current_target = null
	player_detected = false
	_set_state(State.SEARCHING)
	ignore_player_timer.start(5.0)
	_lost_player_timer.stop()

func _on_sound_heard(sound_position: Vector2):
	if current_state == State.ALERT or current_state == State.ATTACK:
		return
	
	last_known_position = sound_position
	_set_state(State.SEARCHING)
	var direction_to_sound = (sound_position - global_position).normalized()
	if direction_to_sound.x > 0:
		animated_sprite.flip_h = false
	elif direction_to_sound.x < 0:
		animated_sprite.flip_h = true


func _on_fov_body_entered(body):
	if body.is_in_group("player"):
		perception_component.set_player_in_fov(true)
		_current_target = body
		player_detected = true
		_set_state(State.ALERT)
		search_timer.stop()
		_lost_player_timer.stop()
			
func _on_fov_body_exited(body):
	if body.is_in_group("player"):
		perception_component.set_player_in_fov(false)
		if player_detected and current_state == State.ALERT:
			_set_state(State.ALERT_LOST_PLAYER)
			if _lost_player_timer.is_stopped():
				_lost_player_timer.start(2.0)

func _on_search_timer_timeout():
	_set_state(State.IDLE)
	player_detected = false

func _on_patrol_wait_timer_timeout():
	patrol_index = (patrol_index + 1) % patrol_points.size()
	_set_state(State.PATROL)

func update_animation():
	var anim_name = "Idle"
	if current_state == State.ALERT or current_state == State.SEARCHING or current_state == State.PATROL:
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
		if not (current_state == State.ATTACK and animated_sprite.animation.begins_with("Attack") and animated_sprite.is_playing()):
			animated_sprite.play(anim_name)

func _on_died():
	_set_state(State.DEATH)
	animated_sprite.play("Death")
	set_physics_process(false)

func _on_animation_finished():
	if animated_sprite.animation == "Death":
		queue_free()
	elif animated_sprite.animation.begins_with("Attack"):
		is_attacking = false
		if player_in_attack_range and _current_target and _current_target.has_node("HealthComponent"):
			_current_target.get_node("HealthComponent").take_damage(10)
		attack_cooldown_timer.start(attack_cooldown)
		_set_state(State.ALERT)

func _on_attack_range_body_entered(body):
	if body.is_in_group("player"):
		player_in_attack_range = true

func _on_attack_range_body_exited(body):
	if body.is_in_group("player"):
		player_in_attack_range = false

func _on_attacked_from_direction(attacker_position: Vector2):
	print("--- Enemy _on_attacked_from_direction ---")
	print("attacker_position: ", attacker_position)
	if current_state == State.DEATH:
		return

	var direction_to_attacker = (attacker_position - global_position).normalized()
	last_movement_direction = direction_to_attacker
	perception_component.rotation = last_movement_direction.angle()

	if direction_to_attacker.x > 0:
		animated_sprite.flip_h = false
	elif direction_to_attacker.x < 0:
		animated_sprite.flip_h = true

	last_known_position = attacker_position
	_set_state(State.SEARCHING)
	player_detected = true

func _on_player_made_sound(sound_level, sound_position):
	perception_component.hear_sound(sound_level, sound_position)

func _on_lost_player_timer_timeout():
	_set_state(State.SEARCHING)
	player_detected = false
	_lost_player_timer.stop()

func _on_attack_timeout_timer_timeout():
	_set_state(State.ALERT)

func _on_attack_cooldown_timer_timeout():
	can_attack = true
