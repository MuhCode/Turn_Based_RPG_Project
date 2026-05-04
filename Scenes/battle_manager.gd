extends Node

enum BattleState { SETUP, ROUND_INIT, COMMANDER_PHASE, TROOP_TURNS, RESOLUTION }
var current_state: BattleState

@export var player_grid: Node3D
@export var enemy_grid: Node3D
@export var battle_ui: CanvasLayer 

var turn_order: Array = []
var current_acting_index: int = 0

func _ready() -> void:
	# Connect to the UI so we can hear what the Commander decides!
	SignalBus.commander_order_issued.connect(_on_commander_order_issued)
	
	# We wait a brief moment to ensure all grid slots and autoloads are fully loaded
	await get_tree().create_timer(0.1).timeout
	change_state(BattleState.SETUP)

func change_state(new_state: BattleState) -> void:
	current_state = new_state
	match current_state:
		BattleState.SETUP: 
			_run_setup()
		BattleState.ROUND_INIT: 
			_run_round_init()
		BattleState.COMMANDER_PHASE: 
			_run_commander_phase()
		BattleState.TROOP_TURNS: 
			_run_troop_turns()
		BattleState.RESOLUTION: 
			_run_resolution()

# ==========================================
# SETUP PHASE LOGIC
# ==========================================

func _run_setup() -> void:
	print("STATE: --- BATTLE START ---")
	
	# 1. Tell the global bus we are in combat (hides empty slots)
	SignalBus.battle_phase_started.emit()
	
	# 2. Build the Player's Army
	# We iterate through the dictionary of saved coordinates in the Autoload
	for coord in PlayerData.active_formation:
		var troop_data = PlayerData.active_formation[coord]
		
		# Find the physical grid slot that matches this Vector2 coordinate
		var target_slot = _find_grid_slot_at(coord, player_grid)
		
		if target_slot != null:
			# Spawn the 3D visual model attached to the blueprint
			if troop_data.template.visual_scene != null:
				var visual_instance = troop_data.template.visual_scene.instantiate()
				target_slot.add_child(visual_instance)
				
			# Initialize the live stats
			target_slot.initialize_combat_stats(troop_data)
			
			# Connect the Manager to the new HP vs Morale signals
			target_slot.unit_incapacitated.connect(_on_unit_incapacitated)
			target_slot.unit_permadead.connect(_on_unit_permadead)
			
	# (Enemy Army generation will be injected right here later)
	
	change_state(BattleState.ROUND_INIT)

# --- Helper Function for Setup ---
func _find_grid_slot_at(coord: Vector2, grid_parent: Node3D) -> Node3D:
	for child in grid_parent.get_children():
		if child is GridSlot and child.grid_coordinate == coord:
			return child
	return null

# --- Signal Receivers for later phases ---
func _on_unit_incapacitated(slot: GridSlot) -> void:
	# Fixed the path to grab the name from the template!
	print(slot.assigned_troop.template.troop_name, " is incapacitated for this battle!")
	# Logic to remove them from turn_order goes here later

func _on_unit_permadead(slot: GridSlot) -> void:
	print(slot.assigned_troop.template.troop_name, " HAS PERMANENTLY DIED!")
	# Logic to delete them from PlayerData goes here later

# ==========================================
# PHASE 3: ROUND INITIALIZATION
# ==========================================

func _run_round_init() -> void:
	print("\n--- NEW ROUND ---")
	
	turn_order.clear()
	var initiative_tracker: Array = []
	
	# 1. Check both grids for living troops
	var all_grids = [player_grid, enemy_grid]
	
	for grid in all_grids:
		# If you haven't assigned an enemy_grid yet in the inspector, this prevents a crash
		if grid == null: 
			continue
			
		for child in grid.get_children():
			if child is GridSlot and child.assigned_troop != null:
				
				# Only include troops that are currently conscious and alive
				if child.current_health > 0 and child.current_morale > 0:
					
					# 2. Calculate Initiative: Speed + 1d4 + Modifiers
					var roll = child.assigned_troop.troop_speed + randi_range(1, 4) + child.next_round_speed_modifier
					
					# Reset the modifier for the next round
					child.next_round_speed_modifier = 0 
					
					# Store the math temporarily
					initiative_tracker.append({
						"slot": child,
						"roll": roll
					})
					
	# 3. Sort the array from highest roll to lowest roll
	initiative_tracker.sort_custom(func(a, b): return a["roll"] > b["roll"])
	
	# 4. Lock in the official turn order
	print("Turn Order:")
	for i in range(initiative_tracker.size()):
		var slot = initiative_tracker[i]["slot"]
		var roll = initiative_tracker[i]["roll"]
		turn_order.append(slot)
		print(str(i + 1) + ". " + slot.assigned_troop.template.troop_name + " (Init Roll: " + str(roll) + ")")
		
	# 5. Reset the acting index
	current_acting_index = 0
	
	# 6. Move straight to the Commander Phase
	change_state(BattleState.COMMANDER_PHASE)


# ==========================================
# PHASE 4: COMMANDER PHASE
# ==========================================

func _run_commander_phase() -> void:
	print("\n--- COMMANDER PHASE ---")
	
	# This shouts out to the UI to slide the buttons onto the screen
	SignalBus.commander_phase_started.emit()
	
	# THE MAGIC TRICK: The manager now STOPS. It will wait indefinitely 
	# until the UI sends the 'commander_order_issued' signal back.

func _on_commander_order_issued(order: CommanderOrder, target_coord: Vector2) -> void:
	# If the target coordinate is (-1, -1), it means they hit the Skip button!
	if order != null and target_coord != Vector2(-1, -1):
		# Find the physical GridSlot based on the coordinate the UI sent us
		var target_slot = player_grid.physical_grid[target_coord]
		
		print("Commander used ", order.order_name, " on ", target_slot.assigned_troop.template.troop_name)
		
		match order.effect_type:
			CommanderOrder.EffectType.ATTACK_BUFF:
				target_slot.add_status_effect("attack_buff", order.effect_value)
			CommanderOrder.EffectType.DEFENSE_BUFF:
				target_slot.add_status_effect("defense_buff", order.effect_value)
			CommanderOrder.EffectType.SPEED_BUFF:
				target_slot.next_round_speed_modifier += int(order.effect_value)
				_resort_initiative() # Re-sort the timeline!
	else:
		print("Commander skipped their order.")
		
	# Move to the actual fighting!
	change_state(BattleState.TROOP_TURNS)

func _resort_initiative() -> void:
	print("Re-sorting Initiative due to Speed Buff...")
	
	# Sort the existing turn order based on their new adjusted speed
	turn_order.sort_custom(func(a, b): 
		var speed_a = a.assigned_troop.troop_speed + a.next_round_speed_modifier
		var speed_b = b.assigned_troop.troop_speed + b.next_round_speed_modifier
		return speed_a > speed_b
	)
	
	# Print the new timeline so you can verify it worked!
	print("New Turn Order:")
	for i in range(turn_order.size()):
		var slot = turn_order[i]
		var total_speed = slot.assigned_troop.troop_speed + slot.next_round_speed_modifier
		print(str(i + 1) + ". " + slot.assigned_troop.template.troop_name + " (Adjusted Speed: " + str(total_speed) + ")")


# ==========================================
# STUBS FOR FUTURE PHASES
# ==========================================

func _run_troop_turns() -> void:
	print("\n--- TROOP TURNS PHASE ---")
	# We will build Phase 5 here next!

func _run_resolution() -> void:
	pass
