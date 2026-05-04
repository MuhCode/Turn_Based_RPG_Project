class_name CommanderOrder
extends Resource

enum EffectType { ATTACK_BUFF, DEFENSE_BUFF, SPEED_BUFF }

@export var order_name: String = "Order Name"
@export var effect_type: EffectType
@export var effect_value: float = 0.0
