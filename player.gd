# player.gd
extends CharacterBody2D

# --- Export Variables ---
@export_group("Movement")
@export var speed = 100
@export var sprint_speed_multiplier = 1.7
@export var zoom_speed = 0.1
@export var min_zoom = 0.5
@export var max_zoom = 3.0

@export_group("Combat")
@export var attack_cooldown = 0.5
@export_group("Aiming")
@export var joystick_deadzone = 0.25 # Deadzone to prevent unintended aiming
@export_group("Stealth")
@export var sprint_sound_level = 200.0
@export var walk_sound_level = 100.0
@export var crouch_sound_level = 5.0

# --- Signals ---
signal made_sound(sound_level, sound_position)
signal player_died
signal inventory_changed(inventory)
signal equipment_changed(equipped_weapon, equipped_shield)

# --- Node References ---
@onready var camera = $Camera2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var attack_timer = $AttackTimer
@onready var attack_hitbox_shape = $AttackHitbox/CollisionShape2D
@onready var attack_cooldown_timer = $AttackCooldownTimer
@onready var health_component = $HealthComponent
@onready var stealth_component = $StealthComponent
@onready var multiplayer_synchronizer = $MultiplayerSynchronizer

# --- State Management ---
enum State {
	IDLE,
	RUN,
	ATTACK,
	BLOCK,
	CROUCH,
	DEATH,
	READY # New state for tactical aiming
}

var current_state = State.IDLE
var facing_direction = "down"
var target_zoom = 2.0
var start_position: Vector2
var is_blocking = false
var is_crouching = false
var _last_sound_level = 0.0

# --- Inventory ---
var inventory_size = 20
var items = {
	"sword": {"type": "weapon", "damage": 15, "cooldown": 0.6, "texture": preload("res://downloads/Kenney/kenney_game-icons/PNG/Black/1x/cross.png")},
	"health_potion": {"type": "consumable", "heal_amount": 25, "texture": null}
}
var inventory = []
var equipped_item_index = 0
var equipped_weapon = null
var equipped_shield = null


var hitbox_positions = {
	"down": Vector2(0, 20),
	"up": Vector2(0, -20),
	"left": Vector2(-20, 0),
	"right": Vector2(20, 0)
}

func _ready():
	multiplayer_synchronizer.set_multiplayer_authority(str(name).to_int())
	add_to_group("player")
	start_position = global_position
	
	# Connect signals in code for clarity and portability
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	health_component.died.connect(_on_died)
#	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

	# Initialize inventory
	inventory.resize(inventory_size)
	inventory.fill(null)

	# Add sample items for testing
	add_item("sword")
	add_item("health_potion")


func _unhandled_input(event):
	if multiplayer.get_unique_id() != multiplayer_synchronizer.get_multiplayer_authority():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_next_item()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_previous_item()

func select_next_item():
	if inventory.is_empty():
		return
	var original_index = equipped_item_index
	equipped_item_index = (equipped_item_index + 1) % inventory.size()
	while inventory[equipped_item_index] == null and equipped_item_index != original_index:
		equipped_item_index = (equipped_item_index + 1) % inventory.size()
	print("Equipped: ", inventory[equipped_item_index])

func select_previous_item():
	if inventory.is_empty():
		return
	var original_index = equipped_item_index
	equipped_item_index = (equipped_item_index - 1 + inventory.size()) % inventory.size()
	while inventory[equipped_item_index] == null and equipped_item_index != original_index:
		equipped_item_index = (equipped_item_index - 1 + inventory.size()) % inventory.size()
	print("Equipped: ", inventory[equipped_item_index])


func _physics_process(delta):
	if multiplayer.get_unique_id() != multiplayer_synchronizer.get_multiplayer_authority():
		return

	# Handle input for state transitions
	if Input.is_action_just_pressed("attack"): # "attack" is now our "use" action
		if current_state != State.DEATH:
			use_item()

	if current_state != State.ATTACK:
		if Input.is_action_pressed("block"):
			current_state = State.BLOCK
		elif Input.is_action_just_released("block"):
			current_state = State.IDLE

		if Input.is_action_pressed("crouch"):
			current_state = State.CROUCH
		elif Input.is_action_just_released("crouch"):
			current_state = State.IDLE
		
		if Input.is_action_pressed("ready_self"):
			current_state = State.READY
		elif Input.is_action_just_released("ready_self"):
			current_state = State.IDLE
	
	# State-specific logic that affects movement and actions
	match current_state:
		State.DEATH:
			velocity = Vector2.ZERO
			return
		State.BLOCK:
			velocity = Vector2.ZERO
		State.READY:
			handle_aiming()
			handle_movement()
		State.ATTACK:
			# If the player is in the attack state, they can still move.
			handle_movement()
			if attack_cooldown_timer.is_stopped():
				attack()
		State.CROUCH:
			handle_movement()
			velocity *= 0.5
		_: # For IDLE, RUN
			handle_movement()
	
	move_and_slide()
	update_animation()

	# Camera Zoom
	camera.zoom = lerp(camera.zoom, Vector2(target_zoom, target_zoom), 10.0 * delta)

func handle_movement():
	var direction_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var new_sound_level = 0.0

	if direction_input != Vector2.ZERO:
		if current_state != State.READY and current_state != State.ATTACK: # Don't change state if we're aiming or attacking
			current_state = State.RUN
		
		var current_speed = speed
		new_sound_level = walk_sound_level
		if Input.is_action_pressed("sprint"):
			current_speed *= sprint_speed_multiplier
			stealth_component.set_player_state(stealth_component.PlayerState.SPRINTING)
			new_sound_level = sprint_sound_level
		elif is_crouching:
			stealth_component.set_player_state(stealth_component.PlayerState.SNEAKING)
			new_sound_level = crouch_sound_level
		else:
			stealth_component.set_player_state(stealth_component.PlayerState.WALKING)

		velocity = direction_input.normalized() * current_speed
		
		if current_state != State.READY and current_state != State.ATTACK:
			update_facing_direction(direction_input)
	else:
		if current_state != State.READY and current_state != State.ATTACK:
			current_state = State.IDLE
		if not is_crouching:
			stealth_component.set_player_state(stealth_component.PlayerState.STANDING)
		velocity = Vector2.ZERO
		new_sound_level = 0.0
	
	if new_sound_level != _last_sound_level:
		emit_signal("made_sound", new_sound_level, global_position)
		_last_sound_level = new_sound_level

func handle_aiming():
	var aim_vector = Vector2.ZERO
	# Check for controller input first
	var joystick_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var joystick_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone to prevent stick drift
	if Vector2(joystick_x, joystick_y).length() > joystick_deadzone:
		aim_vector = Vector2(joystick_x, joystick_y).normalized()
	else:
		# Fallback to mouse aiming if no joystick input is detected
		aim_vector = (get_global_mouse_position() - global_position).normalized()
	
	if aim_vector.length() > 0:
		update_facing_direction(aim_vector)


func update_facing_direction(direction):
	# Determine facing direction based on the primary axis of the input vector
	if abs(direction.x) > abs(direction.y):
		# Horizontal direction is dominant
		if direction.x > 0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		# Vertical direction is dominant
		if direction.y > 0:
			facing_direction = "down"
		else:
			facing_direction = "up"

func use_item():
	if equipped_weapon:
		if attack_cooldown_timer.is_stopped():
			current_state = State.ATTACK
	else:
		var equipped_item_name = inventory[equipped_item_index]
		if equipped_item_name:
			var item_data = items[equipped_item_name]
			if item_data["type"] == "consumable":
				if health_component.get_health() < health_component.get_max_health():
					health_component.heal(item_data["heal_amount"])
					remove_item_at(equipped_item_index)

func add_item(item_name):
	var empty_slot = inventory.find(null)
	if empty_slot != -1:
		inventory[empty_slot] = item_name
		inventory_changed.emit(inventory)

func remove_item_at(index):
	if index >= 0 and index < inventory.size():
		inventory[index] = null
		inventory_changed.emit(inventory)

func swap_inventory_items(from_index, to_index):
	if from_index >= 0 and from_index < inventory.size() and \
	   to_index >= 0 and to_index < inventory.size():
		var item1 = inventory[from_index]
		var item2 = inventory[to_index]
		inventory[from_index] = item2
		inventory[to_index] = item1
		inventory_changed.emit(inventory)

func equip_item(item_name, slot_type):
	var item_index = inventory.find(item_name)
	if item_index != -1:
		remove_item_at(item_index)

	if slot_type == "equipment_weapon":
		if equipped_weapon:
			add_item(equipped_weapon)
		equipped_weapon = item_name
	elif slot_type == "equipment_shield":
		if equipped_shield:
			add_item(equipped_shield)
		equipped_shield = item_name
	
	equipment_changed.emit(equipped_weapon, equipped_shield)

func unequip_item(slot_type):
	if slot_type == "equipment_weapon":
		if equipped_weapon:
			add_item(equipped_weapon)
			equipped_weapon = null
	elif slot_type == "equipment_shield":
		if equipped_shield:
			add_item(equipped_shield)
			equipped_shield = null
	
	equipment_changed.emit(equipped_weapon, equipped_shield)

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
			anim_name = "idle_" + facing_direction
		State.CROUCH:
			anim_name = "idle_" + facing_direction
		State.READY:
			anim_name = "ready_" + facing_direction
		State.DEATH:
			anim_name = "death"

	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

func attack():
	rpc("rpc_attack")

@rpc("any_peer", "call_local")
func rpc_attack():
	if not equipped_weapon:
		return

	var item_data = items[equipped_weapon]

	attack_hitbox.position = hitbox_positions[facing_direction]
	attack_cooldown_timer.start(item_data["cooldown"])
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
	if not multiplayer.is_server():
		return
	if body.is_in_group("enemy"):
		if not equipped_weapon:
			return
		var item_data = items[equipped_weapon]
		var calculated_damage = item_data["damage"]
		
		if body.has_node("PerceptionComponent"):
			if not body.player_detected:
				calculated_damage *= 3
		
		body.get_node("HealthComponent").take_damage(calculated_damage)
		if body.has_method("_on_attacked_from_direction"):
			body._on_attacked_from_direction(global_position)

func _on_died():
	current_state = State.DEATH
	emit_signal("player_died")
	get_tree().create_timer(1.0).timeout.connect(respawn)

func respawn():
	health_component.reset()
	global_position = start_position
	current_state = State.IDLE
	$HealthBar.visible = true
