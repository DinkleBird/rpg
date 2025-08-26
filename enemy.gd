# Filename: Enemy.gd
extends CharacterBody2D

@export var speed = 75.0
@export var player_node: Node2D
@export var attack_cooldown = 1.0

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_range = $AttackRange
@onready var attack_cooldown_timer = $AttackCooldownTimer

enum State {
	IDLE,
	WALK,
	ATTACK,
	HURT,
	DEATH
}

var current_state = State.IDLE

func _ready():
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	attack_range.body_entered.connect(_on_attack_range_body_entered)


func _physics_process(_delta):
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			if player_node:
				current_state = State.WALK
		State.WALK:
			if player_node:
				var direction_to_player = (player_node.global_position - global_position).normalized()
				velocity = direction_to_player * speed
				move_and_slide()

				var bodies_in_range = attack_range.get_overlapping_bodies()
				for body in bodies_in_range:
					if body.is_in_group("player") and attack_cooldown_timer.is_stopped():
						current_state = State.ATTACK
						# Deal damage to player
						body.get_node("HealthComponent").take_damage(10)
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
		attack_cooldown_timer.start(attack_cooldown)


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
	if body.is_in_group("player") and attack_cooldown_timer.is_stopped():
		current_state = State.ATTACK
		attack_cooldown_timer.start(attack_cooldown)
		# A simple way to deal damage is to do it when the attack starts.
		# A better way would be to use a signal on a specific frame of the animation.
		body.get_node("HealthComponent").take_damage(10)
