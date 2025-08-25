extends CharacterBody2D



@export var speed = 100

@export var sprint_speed_multiplier = 1.5

@export var zoom_speed = 0.1

@export var min_zoom = 0.5

@export var max_zoom = 3.0



@onready var camera = $Camera2D



var target_zoom = 2.0



func _unhandled_input(event):

if event is InputEventMouseButton:

if event.button_index == MOUSE_BUTTON_WHEEL_UP:

target_zoom += zoom_speed

if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:

target_zoom -= zoom_speed

target_zoom = clamp(target_zoom, min_zoom, max_zoom)



func _physics_process(delta):

# Movement

var current_speed = speed

if Input.is_action_pressed("sprint"):

current_speed *= sprint_speed_multiplier



var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

velocity = direction * current_speed

move_and_slide()



# Camera Zoom

camera.zoom = lerp(camera.zoom, Vector2(target_zoom, target_zoom), 10.0 * delta)
