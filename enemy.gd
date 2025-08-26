# Filename: Enemy.gd
extends CharacterBody2D

# The speed at which the enemy moves.
@export var speed = 75.0

# A reference to the player node. We will set this in the Godot editor.
@export var player_node: Node2D

@onready var health_component = $HealthComponent
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	health_component.died.connect(_on_died)
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	# Make sure the player_node has been assigned in the editor.
	if player_node:
		# Calculate the direction to the player.
		var direction_to_player = (player_node.global_position - global_position).normalized()
		
		# Set the velocity to move towards the player.
		velocity = direction_to_player * speed
		
		# Move the character and handle collisions.
		move_and_slide()

func _on_died():
	animated_sprite.play("death")
	set_physics_process(false)
	$CollisionShape2D.disabled = true

func _on_animation_finished():
	if animated_sprite.animation == "death":
		queue_free()
