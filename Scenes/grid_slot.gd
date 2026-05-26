extends Area3D 
class_name GridSlot


# ==========================================
# 1. BASE DATA & NODE REFERENCES
# ==========================================
@export var grid_coordinate: Vector2
var assigned_troop: PlayerTroopData = null # Now strictly expects the Instance wrapper
var is_interactable: bool = true 

@onready var default_mesh: MeshInstance3D = $MeshInstance3D 

# ==========================================
# 2. LIVE COMBAT DATA
# ==========================================
var current_health: float = 0.0
var current_morale: int = 0
var active_statuses: Dictionary = {}

# ==========================================
# 3. SIGNALS
# ==========================================
signal health_changed(new_health, max_health)
signal morale_changed(new_morale)
signal unit_incapacitated(slot_reference)
signal unit_permadead(slot_reference)

# ==========================================
# 4. INITIALIZATION & PHASE LISTENING
# ==========================================
func _ready() -> void:
	SignalBus.battle_phase_started.connect(_on_battle_phase_started)
	SignalBus.troop_selection_started.connect(_on_troop_selection_started)

func _on_battle_phase_started() -> void:
	is_interactable = false 
	if assigned_troop == null:
		visible = false 

func _on_troop_selection_started() -> void:
	# Make sure the whole slot is visible
	visible = true 
	
	# If no troop is assigned yet, show the grey cylinder!
	if assigned_troop == null and default_mesh != null:
		default_mesh.visible = true

func initialize_combat_stats(troop_data: PlayerTroopData) -> void: 
	assigned_troop = troop_data
	
	# Pull the live stats from the specific generated soldier, NOT the blueprint
	current_health = troop_data.current_troop_health
	current_morale = troop_data.troop_morale 
	
	# Wipe any old statuses so they don't carry over between battles
	active_statuses.clear()

# ==========================================
# 5. MOUSE INPUT (SETUP PHASE LOGIC)
# ==========================================
func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_interactable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if PlayerData.troop_to_place != null and assigned_troop == null:
			_place_troop(PlayerData.troop_to_place)
		elif PlayerData.troop_to_place == null and assigned_troop != null:
			_remove_troop()

func _place_troop(troop_data: PlayerTroopData) -> void: 
	assigned_troop = troop_data
	
	if default_mesh != null:
		default_mesh.visible = false
		
	if troop_data.template.visual_scene != null:
		var visual_instance = troop_data.template.visual_scene.instantiate()
		add_child(visual_instance)
		
	PlayerData.active_formation[grid_coordinate] = troop_data
	
	# THE FIX: Using your exact array name here
	PlayerData.reserve_troop_inventory.erase(troop_data) 
	
	PlayerData.troop_to_place = null 
	
	SignalBus.troop_placed.emit() 
	SignalBus.reserve_updated.emit() 
	
	print("Placed ", troop_data.template.troop_name, " at ", grid_coordinate)

func _remove_troop() -> void:
	# THE FIX: Using your exact array name here
	PlayerData.reserve_troop_inventory.append(assigned_troop)
	assigned_troop = null
	
	if default_mesh != null:
		default_mesh.visible = true
	for child in get_children():
		if child != default_mesh and child is not CollisionShape3D:
			child.queue_free()
			
	PlayerData.active_formation.erase(grid_coordinate)
	SignalBus.reserve_updated.emit() 
	print("Slot ", grid_coordinate, " cleared. Troop returned to reserves.")

# ==========================================
# 6. COMBAT LOGIC (CALLED BY BATTLE MANAGER)
# ==========================================
func take_damage(amount: float) -> void:
	current_health -= amount
	assigned_troop.current_troop_health = current_health # Sync to permanent record
	health_changed.emit(current_health, assigned_troop.troop_health)
	
	if current_health <= 0:
		unit_incapacitated.emit(self)

func change_morale(amount: int) -> void:
	current_morale += amount
	assigned_troop.troop_morale = current_morale # Sync to permanent record
	morale_changed.emit(current_morale)
	
	if current_morale <= 0:
		unit_permadead.emit(self)

func handle_death() -> void:
	current_health = 0
	unit_permadead.emit(self) # Alert the timeline
	
	# Clean up visuals
	for child in get_children():
		if child.is_in_group("troop_model"):
			child.queue_free()
			
	if default_mesh != null:
		default_mesh.visible = true
		
	# Clean up data
	assigned_troop = null
	active_statuses.clear()

# ==========================================
# 7. STATUS EFFECTS & BUFFS
# ==========================================

func add_status_effect(effect_name: String, value: float, duration: int, tick_when: int) -> void:
	active_statuses[effect_name] = {
		"value": value,
		"duration": duration,
		"tick_when": tick_when
	}
	print(assigned_troop.template.troop_name, " gained ", effect_name, " for ", duration, " turns.")

func process_statuses(current_tick_event: String) -> void:
	# Convert the string from the Manager into our integer Enum so they match
	var event_enum_value = -1
	if current_tick_event == "turn_start": event_enum_value = 0
	elif current_tick_event == "turn_end": event_enum_value = 1
	elif current_tick_event == "round_start": event_enum_value = 2

	# Loop through all active buffs and see if it's their time to tick
	var keys_to_remove = []
	
	for effect_name in active_statuses.keys():
		var status_data = active_statuses[effect_name]
		
		# If the current event matches when this specific buff is supposed to tick...
		if status_data["tick_when"] == event_enum_value:
			status_data["duration"] -= 1
			
			if status_data["duration"] <= 0:
				keys_to_remove.append(effect_name)
				
	# Erase the expired ones cleanly
	for key in keys_to_remove:
		active_statuses.erase(key)
		print(assigned_troop.template.troop_name, "'s ", key, " wore off.")

# --- 3. The Math (With Strict Integer Rounding) ---
func calculate_modified_damage(base_attack_stat: int, power_scale: float) -> int:
	var output: float = float(base_attack_stat) * power_scale
	
	if active_statuses.has("attack_buff"):
		output *= (1.0 + active_statuses["attack_buff"]["value"])
		
	# NEW: Apply Hunker Down's outgoing damage penalty!
	if active_statuses.has("damage_output_reduction"):
		var penalty_multiplier = 1.0 - active_statuses["damage_output_reduction"]["value"]
		output *= penalty_multiplier
		
	return int(round(output))

func calculate_incoming_damage(incoming_raw_damage: int) -> int:
	var final_damage: float = float(incoming_raw_damage)
	
	# Apply modular damage reduction (e.g., Hunker Down)
	if active_statuses.has("damage_reduction"):
		# If the resource value is 0.5, we multiply damage by 0.5 (reducing it by half)
		var reduction_multiplier = 1.0 - active_statuses["damage_reduction"]["value"]
		final_damage *= reduction_multiplier
		
	# Enforce the strict integer rule using round()
	return int(round(final_damage))

func get_modified_speed() -> int:
	# Start with the troop's base speed
	var current_speed = assigned_troop.troop_speed
	
	# Check our smart dictionary for speed modifiers!
	if active_statuses.has("speed_buff"):
		current_speed += int(active_statuses["speed_buff"]["value"])
		
	if active_statuses.has("speed_debuff"):
		current_speed -= int(active_statuses["speed_debuff"]["value"])
		
	# Ensure speed never drops below 1 so the game doesn't break
	return max(1, current_speed)
