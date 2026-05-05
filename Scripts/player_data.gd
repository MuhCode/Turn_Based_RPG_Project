extends Node

var reserve_troop_inventory: Array[PlayerTroopData] = []
var player_currency: int = 500
var active_formation: Dictionary = {}
var troop_to_place: PlayerTroopData = null

# The master list of orders
var unlocked_orders: Array[CommanderOrder] = []

func _ready() -> void:
	# Add the starting cards to the deck the moment the game boots!
	# (NOTE: Double-check these file paths to make sure they match where you saved them!)
	unlocked_orders.append(preload("res://Resources/Moves/CA_Attack!.tres"))
	unlocked_orders.append(preload("res://Resources/Moves/CA_Stand_Strong!.tres"))
	unlocked_orders.append(preload("res://Resources/Moves/CA_Press_the_Advantage!.tres"))

signal currency_change(new_currency: int)

func attempt_purchase_recruit(template: BaseTroopTemplate) -> bool:
	
	if (player_currency < template.base_cost):
		print("Not enough funds...")
		return false
		
	else:
		player_currency -= template.base_cost
		currency_change.emit(player_currency)
		var pending_recruit = PlayerTroopData.new()
		pending_recruit.setup_new_troop(template)
		reserve_troop_inventory.append(pending_recruit)
		print("Troop bought and currency subtracted ", template.base_cost, " ", template.troop_name)
		return true
		
