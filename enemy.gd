# Filename: Enemy.gd
extends CharacterBody2D

@export var speed = 75.0
#@export var player_node: Node2D
@export var attack_cooldown = 1.0

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var attack_cooldown_timer = $AttackCooldownTimer

var player_node: Node2D

enum State {
	IDLE,
	WALK,
	ATTACK,
	HURT,
	DEATH
}

var current_state = State.IDLE
var player_in_range = false

func _ready():
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)
	player_node = get_tree().get_root().get_node("Main/Player")


func _physics_process(delta):
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			if player_node:
				current_state = State.WALK
		State.WALK:
			if player_node:
				if player_in_range and attack_cooldown_timer.is_stopped():
					print("Enemy attacking")
					current_state = State.ATTACK
					# Deal damage to player
					if player_node and player_node.has_node("HealthComponent"):
						player_node.get_node("HealthComponent").take_damage(10)
					attack_cooldown_timer.start(attack_cooldown)
				else:
					var direction_to_player = (player_node.global_position - global_position).normalized()
					velocity = direction_to_player * speed
					move_and_slide()
			else:
				current_state = State.IDLE
		State.ATTACK:
			velocity = Vector2.ZERO
		State.HURT:
			# Add hurt logic here
			pass
		State.DEATH:
			# The death animation is handled by the _on_died function
			return

	update_animation()

func update_animation():
	var anim_name = "idle_down"
	if current_state == State.WALK:
		if velocity.x > 0:
			anim_name = "walk_right"
			animated_sprite.flip_h = false
		elif velocity.x < 0:
			anim_name = "walk_right"
			animated_sprite.flip_h = true
	
	if current_state == State.ATTACK:
		var attack_animations = ["attack_1", "attack_2"]
		anim_name = attack_animations[randi() % attack_animations.size()]


	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func _on_died():
	current_state = State.DEATH
	animated_sprite.play("death")
	set_physics_process(false)
	$CollisionShape2D.disabled = true

func _on_animation_finished():
	if animated_sprite.animation == "death":
		queue_free()
	elif animated_sprite.animation.begins_with("attack"):
		current_state = State.WALK

func _on_attack_range_body_entered(body):
	print("Body entered attack range: ", body.name)
	if body.is_in_group("player"):
		player_in_range = true

func _on_attack_range_body_exited(body):
	print("Body exited attack range: ", body.name)
	if body.is_in_group("player"):
		player_in_range = false
