# Enemy.gd
extends CharacterBody2D

@export var speed = 75.0
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

var current_state = State.WALK
var player_in_range = false

func _ready():
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)
#	attack_range.body_entered.connect(_on_attack_range_body_entered)
#	attack_range.body_exited.connect(_on_attack_range_body_exited)
	
	player_node = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	match current_state:
		State.WALK:
			if player_node:
				if player_in_range:
					current_state = State.IDLE
				else:
					var direction_to_player = (player_node.global_position - global_position).normalized()
					velocity = direction_to_player * speed
					move_and_slide()
			else:
				velocity = Vector2.ZERO
		State.IDLE:
			velocity = Vector2.ZERO
			if not player_in_range:
				current_state = State.WALK
			elif attack_cooldown_timer.is_stopped():
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

func update_animation():
	var anim_name = "Idle"
	if current_state == State.WALK:
		anim_name = "Walk"
		if velocity.x > 0:
			animated_sprite.flip_h = false
		elif velocity.x < 0:
			animated_sprite.flip_h = true
	elif current_state == State.ATTACK:
		var attack_animations = ["Attack01", "Attack02"]
		anim_name = attack_animations[randi() % attack_animations.size()]
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
		if player_in_range and player_node.has_node("HealthComponent"):
			player_node.get_node("HealthComponent").take_damage(10)
		attack_cooldown_timer.start(attack_cooldown)
		current_state = State.IDLE

func _on_attack_range_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_attack_range_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
