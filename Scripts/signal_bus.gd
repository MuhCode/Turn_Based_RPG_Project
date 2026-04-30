extends Node

# This script holds NO variables and NO logic. 
# It is just a list of global radio frequencies.

# Used to clear hand text and refresh reserve from grid_slot.gd to reserve_troop.gd
signal troop_placed

# Used to signal any action issue via buttons in the battle, used in battle_manager.gd
signal player_action_selected(action_type: String)
