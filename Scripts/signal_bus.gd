extends Node

# This script holds NO variables and NO logic. 
# It's just a list of global radio frequencies.


# Makes empty grid slots visible again so the player can 
# place their troops on the board.
# Used in: shop UI scripts, grid_slot.gd
signal troop_selection_started

# Clears the hand text and refreshes the reserve UI 
# whenever a unit is dropped onto the board.
# Used in: grid_slot.gd, reserve_troop.gd
signal troop_placed

# Refreshes the inventory visually whenever a troop 
# is either bought from the shop or placed on the grid.
# Used in: grid_slot.gd, reserve_troop.gd
signal reserve_updated


# Tells the board that combat has officially begun, 
# which hides all the empty, unused grid slots.
# Used in: battle_manager.gd, grid_slot.gd
signal battle_phase_started


# Triggers the UI to slide in and show the player's 
# available commander buff cards.
# Used in: battle_manager.gd, battle_ui.gd
signal commander_phase_started

# Passes the chosen buff card and its target coordinate 
# back to the engine to apply the actual math.
# Used in: battle_ui.gd, battle_manager.gd
signal commander_order_issued(order_data: CommanderOrder, target_coordinate: Vector2)


# Tells the UI whether to show the attack menu, 
# the target selection, or the defensive stances.
# Used in: battle_manager.gd, battle_ui.gd
signal player_turn_started(phase_step: String)

# Sends the player's specific combat choice (like "Charge") 
# back to the engine to execute the turn.
# Used in: battle_ui.gd, battle_manager.gd
signal player_turn_choice_made(choice_type: String, choice_value: Variant)

# Broadcasts when a player clicks a generic action button 
# during the battle phase.
# Used in: battle_ui.gd, battle_manager.gd
signal player_action_selected(action_type: String)
