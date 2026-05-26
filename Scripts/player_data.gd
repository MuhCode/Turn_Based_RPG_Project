extends Node

# --- SIGNALS ---
# Standard Godot naming convention uses past tense for events
signal currency_changed(new_amount: int)
signal formation_changed()

# --- STATE VARIABLES ---
var reserve_troop_inventory: Array[PlayerTroopData] = []
var unlocked_orders: Array[CommanderOrder] = []

# Dictionary mapping [Vector2 -> PlayerTroopData]
var active_formation: Dictionary = {}
var troop_to_place: PlayerTroopData = null

# ENCAPSULATION: We add an underscore to mark this variable as "Private".
# Other scripts should NEVER touch this directly. They must use add_currency().
var _player_currency: int = 500

func _ready() -> void:
	_initialize_starting_orders()

# Isolating setup logic makes _ready() much cleaner
func _initialize_starting_orders() -> void:
	# (NOTE: Double-check these file paths to make sure they match where you saved them!)
	unlocked_orders.append(preload("res://Resources/Moves/CA_Attack!.tres"))
	unlocked_orders.append(preload("res://Resources/Moves/CA_Stand_Strong!.tres"))
	unlocked_orders.append(preload("res://Resources/Moves/CA_Press_the_Advantage!.tres"))

# ==========================================
# CURRENCY MANAGEMENT (Encapsulation)
# ==========================================

func get_currency() -> int:
	return _player_currency

func add_currency(amount: int) -> void:
	if amount > 0:
		_player_currency += amount
		currency_changed.emit(_player_currency)
		print("PlayerData: Added ", amount, " gold. Total: ", _player_currency)

func remove_currency(amount: int) -> bool:
	if _player_currency >= amount:
		_player_currency -= amount
		currency_changed.emit(_player_currency)
		return true
	return false

func attempt_purchase_recruit(template: BaseTroopTemplate) -> bool:
	# We use our new encapsulated remove_currency() function here!
	if remove_currency(template.base_cost):
		var pending_recruit = PlayerTroopData.new()
		pending_recruit.setup_new_troop(template)
		reserve_troop_inventory.append(pending_recruit)
		print("PlayerData: Recruited ", template.troop_name, " for ", template.base_cost, " gold.")
		return true
	else:
		print("PlayerData: Insufficient funds for ", template.troop_name)
		return false

# ==========================================
# PERSISTENCE PAPERWORK (The PDA Stack)
# ==========================================

func save_troop_to_formation(coord: Vector2, troop: PlayerTroopData) -> void:
	active_formation[coord] = troop
	formation_changed.emit()

func remove_troop_from_formation(coord: Vector2) -> void:
	if active_formation.has(coord):
		active_formation.erase(coord)
		formation_changed.emit()

# --- THE GHOST FIX ---
# Call this right before returning to the shop to erase dead bodies from memory!
func cleanup_post_battle() -> void:
	var dead_coords: Array[Vector2] = []
	
	for coord in active_formation:
		var troop: PlayerTroopData = active_formation[coord]
		if troop.current_troop_health <= 0:
			dead_coords.append(coord)
			
	# Erase the dead bodies so they don't spawn next battle
	for coord in dead_coords:
		active_formation.erase(coord)
		print("PlayerData: Cleared dead troop at ", coord)
