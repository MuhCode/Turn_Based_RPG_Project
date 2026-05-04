extends CanvasLayer

@onready var bench = %ReserveBench
@onready var holding_label = %SelectedTroopLabel

func _ready() -> void:
	# 1. Wait a split second for the 3D grid slots to load completely
	await get_tree().create_timer(0.1).timeout
	
	# 2. Tell the GridSlots to unlock and show their grey cylinders!
	SignalBus.troop_selection_started.emit()
	
	# 3. Connect our UI refresh signals
	SignalBus.troop_placed.connect(_on_troop_placed_on_grid)
	SignalBus.reserve_updated.connect(refresh_bench) # <-- ADDED: Listens for removed troops!
	
	# 4. Draw the bench
	refresh_bench()

func refresh_bench() -> void:
	# Clear out any old buttons
	for child in bench.get_children():
		child.queue_free()
		
	# Look at the vault and build a button for every troop in reserve
	for troop in PlayerData.reserve_troop_inventory:
		var btn = Button.new()
		
		# Show the name and current health of the specific unit
		btn.text = troop.template.troop_name + " (HP: " + str(troop.current_troop_health) + ")"
		
		# Connect the click, binding THIS SPECIFIC troop data sheet to it
		btn.pressed.connect(_on_troop_button_pressed.bind(troop))
		
		# Put it on the screen
		bench.add_child(btn)

func _on_troop_button_pressed(selected_troop: PlayerTroopData) -> void:
	# Tell the global vault that this is the unit currently in our "hand"
	PlayerData.troop_to_place = selected_troop
	
	# Update the UI text so the player knows who they are holding
	holding_label.text = "Holding: " + selected_troop.template.troop_name

func _on_troop_placed_on_grid() -> void:
	# We just clear the text here. 
	# The actual bench refresh is handled by the reserve_updated signal now!
	holding_label.text = "Holding: Nothing"

func _on_start_battle_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/battle_scene.tscn")
