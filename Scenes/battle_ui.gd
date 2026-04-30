extends CanvasLayer

@onready var attack_btn = %AttackButton
@onready var defend_btn = %DefendButton
@onready var rally_btn = %RallyButton

func _ready():
	# Connects the buttons to the global radio
	attack_btn.pressed.connect(func(): SignalBus.player_action_selected.emit("attack"))
	defend_btn.pressed.connect(func(): SignalBus.player_action_selected.emit("defend"))
	rally_btn.pressed.connect(func(): SignalBus.player_action_selected.emit("rally"))
	
