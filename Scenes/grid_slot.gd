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
var next_round_speed_modifier: int = 0
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
	is_interactable = true 
	visible = true 
	if assigned_troop == null and default_mesh != null:
		default_mesh.visible = true 

func initialize_combat_stats(troop_data: PlayerTroopData) -> void: 
	assigned_troop = troop_data
	# Pull the live stats from the specific generated soldier, NOT the blueprint
	current_health = troop_data.current_troop_health
	current_morale = troop_data.troop_morale 
	active_statuses.clear()
	next_round_speed_modifier = 0

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

# ==========================================
# 7. STATUS EFFECTS & BUFFS
# ==========================================
func add_status_effect(effect_name: String, value: float) -> void:
	active_statuses[effect_name] = value
	print(assigned_troop.template.troop_name, " gained status: ", effect_name, " (", value, ")")

func calculate_modified_damage(base_damage: int) -> int:
	var multiplier: float = 1.0
	if active_statuses.has("attack_buff"):
		multiplier += active_statuses["attack_buff"]
		
	# roundi() rounds to the nearest whole integer!
	return roundi(base_damage * multiplier) 

func calculate_incoming_damage(incoming_damage: int) -> int:
	var multiplier: float = 1.0
	if active_statuses.has("defense_buff"):
		# If they have a 10% defense buff (0.1), they only take 90% of the damage
		multiplier -= active_statuses["defense_buff"]
		
	return roundi(incoming_damage * multiplier)
