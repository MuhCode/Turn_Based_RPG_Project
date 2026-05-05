extends CanvasLayer

@export var battle_manager: Node 

@onready var action_container = %ActionContainer
@onready var target_container = %TargetContainer

var selected_commander_order: CommanderOrder = null

func _ready() -> void:
	_clear_ui()
	SignalBus.commander_phase_started.connect(_on_commander_phase_started)
	SignalBus.player_turn_started.connect(_on_player_turn_started)

func _clear_ui() -> void:
	for child in action_container.get_children():
		child.queue_free()
	for child in target_container.get_children():
		child.queue_free()

# ==========================================
# COMMANDER PHASE
# ==========================================
func _on_commander_phase_started() -> void:
	_clear_ui()
	selected_commander_order = null
	
	for order in PlayerData.unlocked_orders:
		var btn = Button.new()
		btn.text = order.order_name
		btn.pressed.connect(_on_order_chosen.bind(order)) 
		action_container.add_child(btn)
		
	var skip_btn = Button.new()
	skip_btn.text = "Skip Phase"
	skip_btn.pressed.connect(func(): 
		_clear_ui() # Clear first!
		SignalBus.commander_order_issued.emit(null, Vector2(-1, -1))
	)
	action_container.add_child(skip_btn)

func _on_order_chosen(order: CommanderOrder) -> void:
	selected_commander_order = order
	for child in action_container.get_children(): 
		child.queue_free()
		
	for coord in PlayerData.active_formation:
		var troop_data = PlayerData.active_formation[coord]
		var btn = Button.new()
		btn.text = troop_data.template.troop_name
		btn.pressed.connect(func(): 
			_clear_ui() # Clear first!
			SignalBus.commander_order_issued.emit(selected_commander_order, coord)
		)
		target_container.add_child(btn)

# ==========================================
# TROOP TURNS PHASE
# ==========================================
func _on_player_turn_started(phase_step: String) -> void:
	_clear_ui()
	
	var acting_troop = battle_manager.current_acting_troop
	var troop_template = acting_troop.assigned_troop.template
	
	if phase_step == "attack":
		if troop_template.offensive_moves.size() > 0:
			for move in troop_template.offensive_moves:
				_create_action_button(move, "attack")
		else:
			var skip_btn = Button.new()
			skip_btn.text = "No Attacks (Skip)"
			skip_btn.pressed.connect(func(): 
				_clear_ui() # Clear first!
				SignalBus.player_turn_choice_made.emit("attack", null)
			)
			action_container.add_child(skip_btn)
			
	elif phase_step == "target":
		var enemies_found = false
		for slot in battle_manager.enemy_grid.get_children():
			if slot is GridSlot and slot.assigned_troop != null and slot.current_health > 0:
				enemies_found = true
				var btn = Button.new()
				btn.text = slot.assigned_troop.template.troop_name + " (" + str(slot.current_health) + " HP)"
				var coord = slot.grid_coordinate
				btn.pressed.connect(func(): 
					_clear_ui() # Clear first!
					SignalBus.player_turn_choice_made.emit("target", coord)
				)
				target_container.add_child(btn)
				
		if not enemies_found:
			var skip_btn = Button.new()
			skip_btn.text = "No Targets!"
			skip_btn.pressed.connect(func(): 
				_clear_ui() # Clear first!
				SignalBus.player_turn_choice_made.emit("target", Vector2(-1, -1))
			)
			target_container.add_child(skip_btn)
				
	elif phase_step == "defense":
		if troop_template.defensive_moves.size() > 0:
			for move in troop_template.defensive_moves:
				_create_action_button(move, "defense")
		else:
			var skip_btn = Button.new()
			skip_btn.text = "No Defenses (Skip)"
			skip_btn.pressed.connect(func(): 
				_clear_ui() # Clear first!
				SignalBus.player_turn_choice_made.emit("defense", null)
			)
			action_container.add_child(skip_btn)

func _create_action_button(action: ActionTemplate, action_type: String) -> void:
	var btn = Button.new()
	btn.text = action.action_name
	
	btn.pressed.connect(func(): 
		_clear_ui() # Clear first!
		SignalBus.player_turn_choice_made.emit(action_type, action)
	)
	action_container.add_child(btn)
