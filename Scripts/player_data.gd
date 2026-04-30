extends Node

var reserve_troop_inventory: Array[PlayerTroopData] = []
var player_currency: int = 500
var active_formation: Dictionary = {}

# This holds the troop the player clicked in the UI, waiting to be placed.
var troop_to_place: PlayerTroopData = null

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
		
