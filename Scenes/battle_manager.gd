extends Node
class_name BattleManager

enum BattleState { SETUP, ROUND_INIT, COMMANDER_PHASE, TROOP_TURNS, RESOLUTION }
var current_state: BattleState

@export var player_grid: Node3D
@export var enemy_grid: Node3D
@export var battle_ui: CanvasLayer 

var turn_order: Array[Node3D] = []
var current_acting_index: int = 0

# Turn execution variables
var current_acting_troop: Node3D = null
var queued_attack: ActionTemplate = null
var queued_target: Node3D = null
var queued_defense: ActionTemplate = null

var player_won: bool = false

func _ready() -> void:
	SignalBus.commander_order_issued.connect(_on_commander_order_issued)
	SignalBus.player_turn_choice_made.connect(_on_player_turn_choice_made)
	
	await get_tree().create_timer(0.1).timeout
	change_state(BattleState.SETUP)

func change_state(new_state: BattleState) -> void:
	current_state = new_state
	match current_state:
		BattleState.SETUP: _run_setup()
		BattleState.ROUND_INIT: _run_round_init()
		BattleState.COMMANDER_PHASE: _run_commander_phase()
		BattleState.TROOP_TURNS: _run_troop_turns()
		BattleState.RESOLUTION: _run_resolution()

# ==========================================
# SETUP PHASE
# ==========================================

func _run_setup() -> void:
	print("STATE: --- BATTLE START ---")
	
	# 1. Player Spawner
	var player_troop_count: int = 0
	for coord in PlayerData.active_formation:
		var troop_data: PlayerTroopData = PlayerData.active_formation[coord]
		var target_slot: Node3D = _find_grid_slot_at(coord, player_grid)
		
		if target_slot != null:
			player_troop_count += 1
			_assign_and_spawn_troop(target_slot, troop_data)
			
	# 2. Enemy Spawner
	var vagabond_template: BaseTroopTemplate = preload("res://Resources/Troops/vagabonds_melee.tres") 
	var enemy_slots: Array[Node3D] = []
	
	for child in enemy_grid.get_children():
		if child is GridSlot:
			enemy_slots.append(child)
	enemy_slots.sort_custom(func(a, b): return a.grid_coordinate.x < b.grid_coordinate.x)
	
	for i in range(player_troop_count):
		if i < enemy_slots.size():
			var slot: Node3D = enemy_slots[i]
			var enemy_data: PlayerTroopData = PlayerTroopData.new()
			enemy_data.setup_new_troop(vagabond_template)
			_assign_and_spawn_troop(slot, enemy_data)
	
	SignalBus.battle_phase_started.emit()
	change_state(BattleState.ROUND_INIT)

# Helper function to DRY (Don't Repeat Yourself) the spawning logic
func _assign_and_spawn_troop(slot: Node3D, troop_data: PlayerTroopData) -> void:
	slot.assigned_troop = troop_data 
	
	if slot.default_mesh != null:
		slot.default_mesh.visible = false
	
	if troop_data.template.visual_scene != null:
		var visual_instance: Node3D = troop_data.template.visual_scene.instantiate()
		visual_instance.add_to_group("troop_model")
		slot.add_child(visual_instance)
		
	slot.initialize_combat_stats(troop_data)
	
	# Only connect if not already connected (prevents memory leaks)
	if not slot.unit_incapacitated.is_connected(_on_unit_incapacitated):
		slot.unit_incapacitated.connect(_on_unit_incapacitated)
	if not slot.unit_permadead.is_connected(_on_unit_permadead):
		slot.unit_permadead.connect(_on_unit_permadead)

func _find_grid_slot_at(coord: Vector2, grid_parent: Node3D) -> Node3D:
	for child in grid_parent.get_children():
		if child is GridSlot and child.grid_coordinate == coord:
			return child
	return null

# ==========================================
# DEATH & TIMELINE MANAGEMENT
# ==========================================

func _on_unit_incapacitated(slot: Node3D) -> void:
	print(slot.assigned_troop.template.troop_name, " is down!")
	_remove_troop_from_timeline(slot)

func _on_unit_permadead(slot: Node3D) -> void:
	print(slot.assigned_troop.template.troop_name, " is gone for good!")
	_remove_troop_from_timeline(slot)

func _remove_troop_from_timeline(dead_slot: Node3D) -> void:
	var index_in_timeline: int = turn_order.find(dead_slot)
	
	if index_in_timeline != -1:
		turn_order.remove_at(index_in_timeline)
		if index_in_timeline <= current_acting_index:
			current_acting_index -= 1
	
	_check_battle_status()

func _check_battle_status() -> void:
	var players_alive: bool = false
	var enemies_alive: bool = false
	
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
	if current_state == BattleState.RESOLUTION: return
	
	print("\n--- NEW ROUND ---")
	turn_order.clear()
	var initiative_tracker: Array[Dictionary] = []
	var all_grids: Array[Node3D] = [player_grid, enemy_grid]
	
	for grid in all_grids:
		if grid == null: continue
		for child in grid.get_children():
			if child is GridSlot and child.assigned_troop != null:
				if child.has_method("process_statuses"):
					child.process_statuses("round_start")
				
				if child.current_health > 0:
					var roll: int = child.get_modified_speed() + randi_range(1, 4)
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
		var target_slot: Node3D = player_grid.physical_grid[target_coord]
		print("Commander used ", order.order_name, " on ", target_slot.assigned_troop.template.troop_name)
		
		var requires_timeline_resort: bool = false
		
		for status in order.statuses_to_apply:
			if status == null or status.effect_name == "": continue
				
			target_slot.add_status_effect(status.effect_name, status.value, status.duration, status.tick_when)
			if "speed" in status.effect_name:
				requires_timeline_resort = true
				
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

# Note: In the future, this AI block should be extracted to an "EnemyAIController" script!
func _run_enemy_ai() -> void:
	var valid_targets: Array[Node3D] = []
	for child in player_grid.get_children():
		if child is GridSlot and child.assigned_troop != null and child.current_health > 0:
			valid_targets.append(child)
			
	if valid_targets.is_empty():
		_end_current_turn()
		return
		
	valid_targets.sort_custom(func(a, b): return a.current_health < b.current_health)
	
	var roll: float = randf()
	var chosen_target: Node3D = valid_targets[0] 
	if valid_targets.size() > 1:
		if roll > 0.55:
			chosen_target = valid_targets[1]
		else:
			var idx: int = randi_range(2, valid_targets.size() - 1) if valid_targets.size() > 2 else 1
			chosen_target = valid_targets[idx]
			
	var ai_template: BaseTroopTemplate = current_acting_troop.assigned_troop.template
	
	queued_attack = ai_template.offensive_moves.pick_random() if ai_template.offensive_moves.size() > 0 else null
	queued_defense = ai_template.defensive_moves.pick_random() if ai_template.defensive_moves.size() > 0 else null
	queued_target = chosen_target
	
	await get_tree().create_timer(1.0).timeout 
	_execute_combat_math()

# ==========================================
# COMBAT MATH & ROUTING
# ==========================================

func _execute_combat_math() -> void:
	if queued_target == null or queued_target.current_health <= 0:
		_end_current_turn()
		return

	var total_damage_output: int = 0
	
	if queued_defense != null and queued_defense is ActionTemplate:
		_route_status_effect(queued_defense, current_acting_troop, queued_target)
			
	if queued_attack != null and queued_attack is ActionTemplate:
		var troop_attack_stat: int = current_acting_troop.assigned_troop.troop_damage 
		total_damage_output = current_acting_troop.calculate_modified_damage(troop_attack_stat, queued_attack.power_scale)
		_route_status_effect(queued_attack, current_acting_troop, queued_target)

	var final_dmg: int = queued_target.calculate_incoming_damage(total_damage_output)
	queued_target.current_health -= final_dmg
	print(current_acting_troop.assigned_troop.template.troop_name, " hits for ", final_dmg, " damage!")
	
	# --- ENCAPSULATION: We let the GridSlot clean itself up! ---
	if queued_target.current_health <= 0:
		if queued_target.has_method("handle_death"):
			queued_target.handle_death()
	
	_end_current_turn()

func _end_current_turn() -> void:
	if current_acting_troop.has_method("process_statuses"):
		current_acting_troop.process_statuses("turn_end")
		
	current_acting_index += 1
	await get_tree().create_timer(0.8).timeout 
	_run_troop_turns()

func _route_status_effect(action: ActionTemplate, user_slot: Node3D, target_slot: Node3D) -> void:
	for status in action.statuses_to_apply:
		if status == null or status.effect_name == "": continue
			
		match status.target:
			StatusEffectData.TargetScope.SELF:
				user_slot.add_status_effect(status.effect_name, status.value, status.duration, status.tick_when)
			StatusEffectData.TargetScope.SINGLE_TARGET:
				if target_slot != null:
					target_slot.add_status_effect(status.effect_name, status.value, status.duration, status.tick_when)
			StatusEffectData.TargetScope.ROW:
				print("Row targeting tag recognized")
			StatusEffectData.TargetScope.ARMY:
				print("Army targeting tag recognized")

# ==========================================
# RESOLUTION PHASE
# ==========================================

func _run_resolution() -> void:
	if player_won:
		print("VICTORY! Awarding 100 gold.")
		PlayerData.add_currency(100)
		PlayerData.cleanup_post_battle()
	else:
		print("DEFEAT! Better luck next time.")
	
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://Scenes/troop_shop_ui.tscn")
