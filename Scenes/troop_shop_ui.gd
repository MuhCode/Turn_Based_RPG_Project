extends Control

@export var shop_inventory: Array[BaseTroopTemplate]

@onready var shelf = %TroopShelf
@onready var gold_label = %GoldLabel
@onready var edit_troop_formation_button = %TroopEditorButton

func _ready() -> void:
	PlayerData.currency_change.connect(update_gold_ui)
	update_gold_ui(PlayerData.player_currency)
	populate_shop()

func update_gold_ui(new_gold_amount: int) -> void:
	gold_label.text = "Gold: " + str(new_gold_amount)

func _on_buy_button_pressed(template: BaseTroopTemplate) -> void:
	PlayerData.attempt_purchase_recruit(template)

func populate_shop() -> void:
	for template in shop_inventory:
		var btn = Button.new()
		btn.text = template.troop_name + " - " + str(template.base_cost) + "G"
		btn.pressed.connect(_on_buy_button_pressed.bind(template))
		shelf.add_child(btn)

func _on_troop_editor_button_pressed() -> void:
	# Just change the scene. Let the next scene announce its own arrival!
	get_tree().change_scene_to_file("res://Scenes/troop_selection.tscn")
