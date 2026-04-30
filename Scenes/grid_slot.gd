class_name GridSlot
extends Node3D

@export var grid_coordinate: Vector2 

var visual_model: Node3D 

# Grab the Area3D so we can listen for clicks
@onready var click_area: Area3D = $Area3D

func _ready() -> void:
	# Turn on the radio to listen for mouse clicks on this specific Area3D
	click_area.input_event.connect(_on_click_area_input_event)

# This function triggers anytime the mouse interacts with the collision shape
func _on_click_area_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# 1. Check if the player is currently "holding" a troop
		if PlayerData.troop_to_place != null:
			
			# 2. Save this troop into the active formation at this specific coordinate
			PlayerData.active_formation[grid_coordinate] = PlayerData.troop_to_place
			
			# 3. Remove the troop from the reserve inventory (so they can't place the same guy twice!)
			PlayerData.reserve_troop_inventory.erase(PlayerData.troop_to_place)
			
			print("Successfully placed ", PlayerData.troop_to_place.template.troop_name, " at ", grid_coordinate)
			
			# 4. Empty the player's hand so they can click something else
			PlayerData.troop_to_place = null
			SignalBus.troop_placed.emit()
			
		else:
			print("Slot Clicked, but hand is empty! Select a troop from the Barracks UI first.")
