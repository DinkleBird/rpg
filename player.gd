extends CharacterBody2D

@export var speed = 100
@export var sprint_speed_multiplier = 1.7
@export var zoom_speed = 0.1
@export var min_zoom = 0.5
@export var max_zoom = 3.0
@export var attack_cooldown = 0.5

@onready var camera = $Camera2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var attack_timer = $AttackTimer
@onready var attack_hitbox_shape = $AttackHitbox/CollisionShape2D
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var health_component = $HealthComponent

enum State {
	IDLE,
	RUN,
	ATTACK,
	BLOCK,
	CROUCH,
	DEATH
}

var current_state = State.IDLE
var facing_direction = "down"
var target_zoom = 2.0
var start_position: Vector2
var is_blocking = false
var is_crouching = false
var is_undetected = true # Assume undetected by default
var _damage_to_deal_on_attack = 0 # Stores damage to be dealt on attack

var hitbox_positions = {
	"down": Vector2(0, 20),
	"up": Vector2(0, -20),
	"left": Vector2(-20, 0),
	"right": Vector2(20, 0)
}

func _ready():
	add_to_group("player") # Ensure player is in the "player" group
	start_position = global_position
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	health_component.died.connect(_on_died)


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += zoom_speed
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= zoom_speed
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)

func _physics_process(delta):
	match current_state:
		State.DEATH:
			velocity = Vector2.ZERO
		State.ATTACK:
			velocity = Vector2.ZERO
		State.BLOCK:
			velocity = Vector2.ZERO
		State.CROUCH:
			# Allow movement while crouching, but at reduced speed
			handle_movement()
			velocity *= 0.5 # Adjust as needed
		_:
			handle_movement()
	
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer.is_stopped():
		current_state = State.ATTACK
		attack()
	
	if Input.is_action_pressed("block"):
		current_state = State.BLOCK
		is_blocking = true
		health_component.is_blocking = true
	elif Input.is_action_just_released("block"):
		current_state = State.IDLE
		is_blocking = false
		health_component.is_blocking = false

	if Input.is_action_pressed("crouch"):
		current_state = State.CROUCH
		is_crouching = true
	elif Input.is_action_just_released("crouch"):
		current_state = State.IDLE
		is_crouching = false

	update_animation()
	move_and_slide()

	# Camera Zoom
	camera.zoom = lerp(camera.zoom, Vector2(target_zoom, target_zoom), 10.0 * delta)

func handle_movement():
	var direction_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction_input != Vector2.ZERO:
		current_state = State.RUN
		var current_speed = speed
		if Input.is_action_pressed("sprint"):
			current_speed *= sprint_speed_multiplier
		velocity = direction_input.normalized() * current_speed
		update_facing_direction(direction_input)
	else:
		current_state = State.IDLE
		velocity = Vector2.ZERO


func update_facing_direction(direction):
	if direction.y > 0:
		facing_direction = "down"
	elif direction.y < 0:
		facing_direction = "up"
	elif direction.x < 0:
		facing_direction = "left"
	elif direction.x > 0:
		facing_direction = "right"

func update_animation():
	var anim_name = ""
	match current_state:
		State.IDLE:
			anim_name = "idle_" + facing_direction
		State.RUN:
			anim_name = "run_" + facing_direction
		State.ATTACK:
			if facing_direction == "down":
				anim_name = "attack"
			else:
				anim_name = "attack_" + facing_direction
		State.BLOCK:
			anim_name = "idle_" + facing_direction # Replace with block animation
		State.CROUCH:
			anim_name = "idle_" + facing_direction # Replace with crouch animation
	
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func attack():
	print("Attack!")
	var calculated_damage = 10 # Base damage
	if is_undetected:
		calculated_damage *= 3 # Sneak attack bonus
		print("Sneak Attack!")
	
	_damage_to_deal_on_attack = calculated_damage # Store the calculated damage
	
	attack_hitbox.position = hitbox_positions[facing_direction]
	attack_cooldown_timer.start(attack_cooldown)
	attack_hitbox_shape.disabled = false
	attack_timer.start() 

func _on_attack_timer_timeout():
	attack_hitbox_shape.disabled = true

func _on_animation_finished():
	if animated_sprite.animation.begins_with("attack"):
		current_state = State.IDLE
	else:
		pass

func _on_attack_hitbox_body_entered(body):
	print("Player attack hitbox entered body: ", body.name)
	if body.is_in_group("enemy"):
		body.get_node("HealthComponent").take_damage(_damage_to_deal_on_attack)
		# Call the new function on the enemy to make it turn and re-check
		if body.has_method("_on_attacked_from_direction"):
			body._on_attacked_from_direction(global_position)

func _on_died():
	current_state = State.DEATH
	# After a 1 second delay, call the respawn function
	get_tree().create_timer(1.0).timeout.connect(respawn)

func respawn():
	health_component.reset()
	global_position = start_position
	current_state = State.IDLE
	$HealthBar.visible = true

func set_undetected(value):
	is_undetected = value
