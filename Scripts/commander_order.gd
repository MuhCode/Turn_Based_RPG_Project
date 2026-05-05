class_name CommanderOrder
extends Resource

@export var order_name: String = "Order Name"

@export_group("Status Effects")
# The Commander now uses the exact same modular system as the troops!
@export var statuses_to_apply: Array[StatusEffectData] = []
