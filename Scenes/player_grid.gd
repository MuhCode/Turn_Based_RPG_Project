extends Node3D

# This will map a Vector2 coordinate to the actual 3D slot on the map
# Example: physical_grid[Vector2(0, 0)] = The top-left slot (back column)
var physical_grid: Dictionary = {}

func _ready() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	# get_children() looks at every node attached directly under PlayerGrid
	for child in get_children():
		
		# We check if the child is specifically one of our GridSlots
		if child is GridSlot:
			
			# Add it to the dictionary! The key is the X/Y coordinate, the value is the node.
			physical_grid[child.grid_coordinate] = child
			
	print("Grid successfully initialized! Found ", physical_grid.size(), " slots.")
