extends CharacterBody2D

@onready var area = $Area2D
@onready var player = null

func _ready():
	pass
	
func _physics_process(_delta: float) -> void:
	pass
	



func _on_area_2d_body_entered(body: Node2D) -> void:
	print("You're here!")
	if body.is_in_group("player"):
		print("It's the player!")
	pass # Replace with function body.
