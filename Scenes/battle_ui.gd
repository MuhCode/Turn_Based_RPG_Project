extends CanvasLayer

@onready var action_container = %ActionContainer
@onready var target_container = %TargetContainer

var selected_commander_order: CommanderOrder = null

func _ready() -> void:
	_clear_ui()
	SignalBus.commander_phase_started.connect(_on_commander_phase_started)

func _clear_ui() -> void:
	# This wipes the menu clean instantly
	for child in action_container.get_children():
		child.queue_free()
	for child in target_container.get_children():
		child.queue_free()

func _on_commander_phase_started() -> void:
	_clear_ui()
	selected_commander_order = null
	
	# 1. Generate Commander Order Buttons
	for order in PlayerData.unlocked_orders:
		var btn = Button.new()
		btn.text = order.order_name
		
		# Bind the specific order file to the button click!
		btn.pressed.connect(_on_order_chosen.bind(order)) 
		action_container.add_child(btn)
		
	# 2. Always add a Skip Button
	var skip_btn = Button.new()
	skip_btn.text = "Skip Phase"
	skip_btn.pressed.connect(func(): SignalBus.commander_order_issued.emit(null, Vector2(-1, -1)))
	action_container.add_child(skip_btn)

func _on_order_chosen(order: CommanderOrder) -> void:
	selected_commander_order = order
	
	# Clear the order buttons, it's time to show the targets!
	for child in action_container.get_children(): 
		child.queue_free()
	
	# Generate a button for every Player unit currently on the board
	for coord in PlayerData.active_formation:
		var troop_data = PlayerData.active_formation[coord]
		var btn = Button.new()
		
		btn.text = troop_data.template.troop_name + " (HP: " + str(troop_data.current_troop_health) + ")"
		
		# We pass the GRID COORDINATE to the manager so it knows exactly which slot to buff
		btn.pressed.connect(_on_target_chosen.bind(coord))
		target_container.add_child(btn)

func _on_target_chosen(target_coord: Vector2) -> void:
	_clear_ui()
	# Tell the Battle Manager what order we picked, and exactly which grid tile to apply it to!
	SignalBus.commander_order_issued.emit(selected_commander_order, target_coord)
