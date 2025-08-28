# Enemy.gd
extends CharacterBody2D

@export var speed = 75.0
@export var attack_cooldown = 1.0
@export var search_duration = 5.0
@export var search_angle_range = 60.0
@export var search_speed = 2.0

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var perception_component = $PerceptionComponent
@onready var search_timer = $SearchTimer

enum State {
	IDLE,
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

var hitbox_positions = {
	"right": Vector2(20, 0),
	"left": Vector2(-20, 0)
}

func _ready():
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	perception_component.player_detected.connect(_on_player_detected)
	search_timer.timeout.connect(_on_search_timer_timeout)
	
	var fov = perception_component.get_node("FieldOfView")
	fov.body_entered.connect(_on_fov_body_entered)
	fov.body_exited.connect(_on_fov_body_exited)
	
func _physics_process(_delta):
	match current_state:
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

		State.IDLE:
			velocity = Vector2.ZERO
			if player_detected and not player_in_attack_range:
				current_state = State.WALK
			elif player_detected and player_in_attack_range and attack_cooldown_timer.is_stopped():
				current_state = State.ATTACK
				update_animation()
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
	player_detected = true
	search_timer.stop()
	var players_in_group = get_tree().get_nodes_in_group("player")
	if not players_in_group.is_empty():
		_current_target = players_in_group[0]
		last_known_position = _current_target.global_position

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

func update_animation():
	var anim_name = "Idle"
	if current_state == State.WALK or current_state == State.SEARCHING:
		anim_name = "Walk"
		if velocity.x > 0:
			animated_sprite.flip_h = false
			attack_range.position = hitbox_positions["right"]
		elif velocity.x < 0:
			animated_sprite.flip_h = true
			attack_range.position = hitbox_positions["left"]
	elif current_state == State.LOOKING_AROUND:
		anim_name = "Idle"
	elif current_state == State.ATTACK:
		var attack_animations = ["Attack01", "Attack02"]
		anim_name = attack_animations[randi() % attack_animations.size()]
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

func _on_animation_finished():
	if animated_sprite.animation == "Death":
		queue_free()
	elif animated_sprite.animation.begins_with("Attack"):
		if player_in_attack_range and _current_target and _current_target.has_node("HealthComponent"):
			var direction_to_player = (_current_target.global_position - global_position).normalized()
			var dot_product = direction_to_player.dot(Vector2(1, 0) if not animated_sprite.flip_h else Vector2(-1, 0))
			if dot_product > 0.5:
				_current_target.get_node("HealthComponent").take_damage(10)
		attack_cooldown_timer.start(attack_cooldown)
		current_state = State.IDLE

func _on_attack_range_body_entered(body):
	if body.is_in_group("player"):
		var direction_to_player = (body.global_position - global_position).normalized()
		var dot_product = direction_to_player.dot(Vector2(1, 0) if not animated_sprite.flip_h else Vector2(-1, 0))
		if dot_product > 0.5:
			player_in_attack_range = true
		else:
			player_in_attack_range = false

func _on_attack_range_body_exited(body):
	if body.is_in_group("player"):
		player_in_attack_range = false

func _on_attacked_from_direction(attacker_position: Vector2):
	var direction_to_attacker = (attacker_position - global_position).normalized()

	if direction_to_attacker.x > 0:
		animated_sprite.flip_h = false
	elif direction_to_attacker.x < 0:
		animated_sprite.flip_h = true
	
	if current_state != State.DEATH:
		current_state = State.IDLE
