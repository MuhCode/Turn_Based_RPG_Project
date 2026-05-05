extends Node

enum BattleState { SETUP, ROUND_INIT, COMMANDER_PHASE, TROOP_TURNS, RESOLUTION }
var current_state: BattleState

@export var player_grid: Node3D
@export var enemy_grid: Node3D
@export var battle_ui: CanvasLayer 

var turn_order: Array = []
var current_acting_index: int = 0

# Turn execution variables
var current_acting_troop: Node3D = null
var queued_attack: ActionTemplate = null
var queued_target: Node3D = null
var queued_defense: ActionTemplate = null

# Track the outcome for the resolution phase
var player_won: bool = false

func _ready() -> void:
	SignalBus.commander_order_issued.connect(_on_commander_order_issued)
	SignalBus.player_turn_choice_made.connect(_on_player_turn_choice_made)
	
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
# SETUP PHASE
# ==========================================

func _run_setup() -> void:
	print("STATE: --- BATTLE START ---")
	
	var player_troop_count = 0
	for coord in PlayerData.active_formation:
		var troop_data = PlayerData.active_formation[coord]
		var target_slot = _find_grid_slot_at(coord, player_grid)
		
		if target_slot != null:
			player_troop_count += 1
			target_slot.assigned_troop = troop_data 
			
			if target_slot.default_mesh != null:
				target_slot.default_mesh.visible = false
			
			if troop_data.template.visual_scene != null:
				var visual_instance = troop_data.template.visual_scene.instantiate()
				visual_instance.add_to_group("troop_model") # <--- ADD THIS LINE
				target_slot.add_child(visual_instance)
				
			target_slot.initialize_combat_stats(troop_data)
			target_slot.unit_incapacitated.connect(_on_unit_incapacitated)
			target_slot.unit_permadead.connect(_on_unit_permadead)
			
	# Enemy Spawner logic
	var vagabond_template = preload("res://Resources/Troops/vagabonds_melee.tres") 
	
	var enemy_slots = []
	for child in enemy_grid.get_children():
		if child is GridSlot:
			enemy_slots.append(child)
	enemy_slots.sort_custom(func(a, b): return a.grid_coordinate.x < b.grid_coordinate.x)
	
	for i in range(player_troop_count):
		if i < enemy_slots.size():
			var slot = enemy_slots[i]
			var enemy_data = PlayerTroopData.new()
			
			# --- NEW: Let the PlayerTroopData roll its own permanent stats! ---
			enemy_data.setup_new_troop(vagabond_template)
			
			slot.assigned_troop = enemy_data
			
			if slot.default_mesh != null:
				slot.default_mesh.visible = false
				
			if vagabond_template.visual_scene != null:
				var visual_instance = vagabond_template.visual_scene.instantiate()
				visual_instance.add_to_group("troop_model") # <--- ADD THIS LINE
				slot.add_child(visual_instance)
				
			slot.initialize_combat_stats(enemy_data)
			slot.unit_incapacitated.connect(_on_unit_incapacitated)
			slot.unit_permadead.connect(_on_unit_permadead)
	
	SignalBus.battle_phase_started.emit()
	change_state(BattleState.ROUND_INIT)

func _find_grid_slot_at(coord: Vector2, grid_parent: Node3D) -> Node3D:
	for child in grid_parent.get_children():
		if child is GridSlot and child.grid_coordinate == coord:
			return child
	return null

func _on_unit_incapacitated(slot: Node3D) -> void:
	print(slot.assigned_troop.template.troop_name, " is down!")
	_remove_troop_from_timeline(slot)

func _on_unit_permadead(slot: Node3D) -> void:
	print(slot.assigned_troop.template.troop_name, " is gone for good!")
	_remove_troop_from_timeline(slot)

func _remove_troop_from_timeline(dead_slot: Node3D) -> void:
	var index_in_timeline = turn_order.find(dead_slot)
	
	if index_in_timeline != -1:
		turn_order.remove_at(index_in_timeline)
		
		if index_in_timeline <= current_acting_index:
			current_acting_index -= 1
	
	# Check if the fight is over every time someone is removed
	_check_battle_status()

func _check_battle_status() -> void:
	var players_alive = false
	var enemies_alive = false
	
	for slot in player_grid.get_children():
		if slot is GridSlot and slot.assigned_troop != null and slot.current_health > 0:
			players_alive = true
			break
			
	for slot in enemy_grid.get_children():
		if slot is GridSlot and slot.assigned_troop != null and slot.current_health > 0:
			enemies_alive = true
			break
			
	if not enemies_alive:
		player_won = true
		change_state(BattleState.RESOLUTION)
	elif not players_alive:
		player_won = false
		change_state(BattleState.RESOLUTION)

# ==========================================
# ROUND INITIALIZATION
# ==========================================

func _run_round_init() -> void:
	# Don't start a new round if we just triggered resolution
	if current_state == BattleState.RESOLUTION: return
	
	print("\n--- NEW ROUND ---")
	turn_order.clear()
	var initiative_tracker: Array = []
	var all_grids = [player_grid, enemy_grid]
	
	for grid in all_grids:
		if grid == null: continue
		for child in grid.get_children():
			if child is GridSlot and child.assigned_troop != null:
				if child.has_method("process_statuses"):
					child.process_statuses("round_start")
				
				# Ask the GridSlot for its modified speed instead of doing the math here
				if child.current_health > 0:
					var roll = child.get_modified_speed() + randi_range(1, 4)
					initiative_tracker.append({"slot": child, "roll": roll})
					
	initiative_tracker.sort_custom(func(a, b): return a["roll"] > b["roll"])
	
	for i in range(initiative_tracker.size()):
		turn_order.append(initiative_tracker[i]["slot"])
		
	current_acting_index = 0
	change_state(BattleState.COMMANDER_PHASE)

# ==========================================
# COMMANDER PHASE
# ==========================================

func _run_commander_phase() -> void:
	print("\n--- COMMANDER PHASE ---")
	SignalBus.commander_phase_started.emit()

func _on_commander_order_issued(order: CommanderOrder, target_coord: Vector2) -> void:
	if order != null and target_coord != Vector2(-1, -1):
		var target_slot = player_grid.physical_grid[target_coord]
		print("Commander used ", order.order_name, " on ", target_slot.assigned_troop.template.troop_name)
		
		var requires_timeline_resort = false
		
		# Apply statuses normally
		for status in order.statuses_to_apply:
			if status == null or status.effect_name == "":
				continue
				
			target_slot.add_status_effect(status.effect_name, status.value, status.duration, status.tick_when)
			
			# If the effect name contains the word "speed", flag the timeline for a resort
			if "speed" in status.effect_name:
				requires_timeline_resort = true
				
		# If a speed buff was applied mid-round, update the turn order immediately!
		if requires_timeline_resort:
			_resort_initiative()
	else:
		print("Commander phase skipped.")
		
	change_state(BattleState.TROOP_TURNS)

func _resort_initiative() -> void:
	print("Re-sorting Initiative due to speed change...")
	turn_order.sort_custom(func(a, b): 
		return a.get_modified_speed() > b.get_modified_speed()
	)

# ==========================================
# TROOP TURNS
# ==========================================

func _run_troop_turns() -> void:
	if current_state == BattleState.RESOLUTION: return
	
	if current_acting_index >= turn_order.size():
		change_state(BattleState.ROUND_INIT)
		return
		
	current_acting_troop = turn_order[current_acting_index]
	
	if current_acting_troop.current_health <= 0:
		_end_current_turn()
		return
		
	if current_acting_troop.has_method("process_statuses"):
		current_acting_troop.process_statuses("turn_start")
		
	if current_acting_troop.has_method("process_statuses"):
		current_acting_troop.process_statuses("turn_start")
		
	# Add this line back in so you know who is waiting for orders!
	print("\n--- TURN: ", current_acting_troop.assigned_troop.template.troop_name, " ---")
		
	if current_acting_troop.get_parent() == player_grid:
		queued_attack = null
		queued_target = null
		queued_defense = null
		SignalBus.player_turn_started.emit("attack")
	else:
		_run_enemy_ai()

func _on_player_turn_choice_made(choice_type: String, choice_value: Variant) -> void:
	if choice_type == "attack":
		queued_attack = choice_value
		SignalBus.player_turn_started.emit("target") 
	elif choice_type == "target":
		queued_target = enemy_grid.physical_grid[choice_value]
		SignalBus.player_turn_started.emit("defense") 
	elif choice_type == "defense":
		queued_defense = choice_value
		_execute_combat_math()

func _run_enemy_ai() -> void:
	var valid_targets = []
	for child in player_grid.get_children():
		if child is GridSlot and child.assigned_troop != null and child.current_health > 0:
			valid_targets.append(child)
			
	if valid_targets.is_empty():
		_end_current_turn()
		return
		
	valid_targets.sort_custom(func(a, b): return a.current_health < b.current_health)
	
	var roll = randf()
	var chosen_target = valid_targets[0] 
	if valid_targets.size() > 1:
		if roll > 0.60 and roll <= 0.90:
			chosen_target = valid_targets[1]
		elif roll > 0.90:
			var idx = randi_range(2, valid_targets.size() - 1) if valid_targets.size() > 2 else 1
			chosen_target = valid_targets[idx]
			
	# Dynamically pull moves from the acting enemy's template
	var ai_template = current_acting_troop.assigned_troop.template
	
	if ai_template.offensive_moves.size() > 0:
		queued_attack = ai_template.offensive_moves.pick_random()
	else:
		queued_attack = null
		
	if ai_template.defensive_moves.size() > 0:
		queued_defense = ai_template.defensive_moves.pick_random()
	else:
		queued_defense = null
		
	queued_target = chosen_target
	
	await get_tree().create_timer(1.0).timeout 
	_execute_combat_math()

func _execute_combat_math() -> void:
	if queued_target == null or queued_target.current_health <= 0:
		_end_current_turn()
		return

	var total_damage_output: int = 0
	
	# 1. Process Defense Choice
	if queued_defense != null and queued_defense is ActionTemplate:
		_route_status_effect(queued_defense, current_acting_troop, queued_target)
			
	# 2. Process Attack Choice
	if queued_attack != null and queued_attack is ActionTemplate:
		
		# --- NEW: Read the permanent, locked-in stat from the generated soldier ---
		var troop_attack_stat = current_acting_troop.assigned_troop.troop_damage 
		
		total_damage_output = current_acting_troop.calculate_modified_damage(
			troop_attack_stat, 
			queued_attack.power_scale
		)
		
		_route_status_effect(queued_attack, current_acting_troop, queued_target)

	# 3. Target attempts to defend
	var final_dmg = queued_target.calculate_incoming_damage(total_damage_output)
	
	queued_target.current_health -= final_dmg
	print(current_acting_troop.assigned_troop.template.troop_name, " hits for ", final_dmg, " damage!")
	
	# --- NEW: THE DEATH CHECK ---
	if queued_target.current_health <= 0:
		queued_target.current_health = 0
		
		# 1. Emit the signal BEFORE clearing data so the manager can print the name
		queued_target.unit_permadead.emit(queued_target)
		
		# 2. Delete the 3D visual model using our safe group tag
		for child in queued_target.get_children():
			if child.is_in_group("troop_model"):
				child.queue_free()
				
		# 3. Turn the default grid tile back on
		if queued_target.default_mesh != null:
			queued_target.default_mesh.visible = true
			
		# 4. Wipe the slot completely clean
		queued_target.assigned_troop = null
		if queued_target.has_method("active_statuses"):
			queued_target.active_statuses.clear()
	
	_end_current_turn()

func _end_current_turn() -> void:
	if current_acting_troop.has_method("process_statuses"):
		current_acting_troop.process_statuses("turn_end")
		
	current_acting_index += 1
	await get_tree().create_timer(0.8).timeout 
	_run_troop_turns()


# ==========================================
# RESOLUTION PHASE
# ==========================================

func _run_resolution() -> void:
	if player_won:
		print("VICTORY! Awarding 100 gold.")
		PlayerData.player_currency += 100
	else:
		print("DEFEAT! Better luck next time.")
	
	# Small delay so player can see the logs/final state
	await get_tree().create_timer(2.5).timeout
	
	# Transition back to shop
	# Make sure this path matches your shop scene location!
	get_tree().change_scene_to_file("res://Scenes/troop_shop_ui.tscn")

# --- Modular Status Router ---
func _route_status_effect(action: ActionTemplate, user_slot: Node3D, target_slot: Node3D) -> void:
	# Loop through every status attached to this move
	for status in action.statuses_to_apply:
		if status == null or status.effect_name == "":
			continue
			
		# Look at the tag inside the StatusEffectData to figure out WHERE this effect goes
		match status.target:
			StatusEffectData.TargetScope.SELF:
				user_slot.add_status_effect(status.effect_name, status.value, status.duration, status.tick_when)
				
			StatusEffectData.TargetScope.SINGLE_TARGET:
				if target_slot != null:
					target_slot.add_status_effect(status.effect_name, status.value, status.duration, status.tick_when)
				
			StatusEffectData.TargetScope.SINGLE_TARGET:
				if target_slot != null:
					target_slot.add_status_effect(status.effect_name, status.value, status.duration)
					
			StatusEffectData.TargetScope.ROW:
				print("Row targeting tag recognized (Logic for grabbing row slots goes here later)")
				
			StatusEffectData.TargetScope.ARMY:
				print("Army targeting tag recognized (Logic for grabbing all allies goes here later)")
