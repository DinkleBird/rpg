extends Node

# Enum for player's state
enum PlayerState { STANDING, WALKING, SPRINTING, SNEAKING }

# --- Stealth Properties ---
@export var base_stealth: float = 50.0
@export var sneak_skill: float = 10.0 # Example value
@export var equipment_modifier: float = 0.0
@export var crouch_bonus: float = 20.0
@export var light_modifier: float = 0.0

var current_state: PlayerState = PlayerState.WALKING
var stealth_rating: float = 0.0

func _ready():
	calculate_stealth_rating()

func calculate_stealth_rating():
	var state_bonus = 0.0
	match current_state:
		PlayerState.SNEAKING:
			state_bonus = crouch_bonus
		PlayerState.SPRINTING:
			state_bonus = -30.0 # Sprinting makes you much easier to detect

	stealth_rating = base_stealth + sneak_skill + equipment_modifier + state_bonus - light_modifier
	# Ensure stealth rating doesn't go below a certain threshold
	stealth_rating = max(0, stealth_rating)
	print("Stealth Rating updated: ", stealth_rating)

func set_player_state(new_state: PlayerState):
	if current_state != new_state:
		current_state = new_state
		calculate_stealth_rating()

func update_light_modifier(light_level: float):
	# Assuming light_level is from 0 (dark) to 1 (bright)
	# This will be a penalty, so we multiply by a factor
	light_modifier = light_level * 20.0 # Example factor
	calculate_stealth_rating()

func get_stealth_rating() -> float:
	return stealth_rating
