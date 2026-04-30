extends Node

enum BattleState { SETUP, ROUND_INIT, TROOP_TURNS, RESOLUTION }
var current_state: BattleState

@export var player_grid: Node3D
@export var enemy_grid: Node3D
@export var battle_ui: CanvasLayer

var defending_units: Array = []
var enemy_demo_health: int = 30 # A simple health pool for tomorrow's demo

func _ready() -> void:
	change_state(BattleState.SETUP)

func change_state(new_state: BattleState) -> void:
	current_state = new_state
	match current_state:
		BattleState.SETUP: _run_setup()
		BattleState.ROUND_INIT: _run_round_init()
		BattleState.TROOP_TURNS: _run_troop_turns()
		BattleState.RESOLUTION: _run_resolution()

func _run_setup() -> void:
	print("STATE: --- BATTLE START ---")
	
	# 1. Spawn Player Army (Blue)
	for coord in player_grid.physical_grid.keys():
		var slot = player_grid.physical_grid[coord]
		if PlayerData.active_formation.has(coord):
			slot.get_node("Area3D/MeshInstance3D").visible = true
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color.BLUE
			slot.get_node("Area3D/MeshInstance3D").set_surface_override_material(0, mat)
			
	# 2. Spawn Demo Enemy (Red)
	var enemy_slot = enemy_grid.physical_grid[Vector2(2, 1)] # Front Middle
	enemy_slot.get_node("Area3D/MeshInstance3D").visible = true
	var mat_red = StandardMaterial3D.new()
	mat_red.albedo_color = Color.RED
	enemy_slot.get_node("Area3D/MeshInstance3D").set_surface_override_material(0, mat_red)
	
	change_state(BattleState.ROUND_INIT)

func _run_round_init() -> void:
	print("STATE: --- NEW ROUND ---")
	# For the demo, we just clear defending statuses at the start of a round
	defending_units.clear() 
	change_state(BattleState.TROOP_TURNS)

func _run_troop_turns() -> void:
	print("STATE: --- PLAYER TURN ---")
	
	# 1. Show the UI buttons
	battle_ui.visible = true
	
	# 2. MAGIC AWAIT: The code completely stops here until you click a UI button!
	var chosen_action = await SignalBus.player_action_selected
	
	# 3. Hide the UI while the action plays out
	battle_ui.visible = false 
	
	# 4. Process the action
	if chosen_action == "attack":
		print("Player attacks!")
		enemy_demo_health -= 15
		print("Enemy health is now: ", enemy_demo_health)
		
	elif chosen_action == "defend":
		print("Player takes a defensive stance! Damage halved next turn.")
		defending_units.append("Player") # Tagging them as defending
		
	elif chosen_action == "rally":
		print("Player rallies! Gained +10 temporary health.")
		
	# 5. Check for Win Condition
	if enemy_demo_health <= 0:
		print("ENEMY DEFEATED!")
		var enemy_slot = enemy_grid.physical_grid[Vector2(2, 1)]
		enemy_slot.get_node("Area3D/MeshInstance3D").visible = false # Hide the dead body
		change_state(BattleState.RESOLUTION)
		return
		
	# 6. For the demo, loop back to the start of the turn
	# (In the full game, this is where the Enemy AI would take its turn!)
	await get_tree().create_timer(1.0).timeout # Pause for 1 second so it feels like a real game
	change_state(BattleState.TROOP_TURNS)

func _run_resolution() -> void:
	print("STATE: --- VICTORY ---")
	print("You earned 100 Gold!")
	PlayerData.player_currency += 100
	
	# Wait 2 seconds to let the player celebrate, then kick them back to the Shop
	await get_tree().create_timer(2.0).timeout 
	get_tree().change_scene_to_file("res://Scenes/troop_shop_ui.tscn")
