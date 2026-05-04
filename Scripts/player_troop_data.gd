class_name PlayerTroopData
extends Resource

@export var template: BaseTroopTemplate
@export var troop_health: int
@export var current_troop_health: int
@export var troop_damage: int
@export var troop_speed: int # Added this so your battle manager initiative works later!
@export var troop_morale: int
@export var troop_level: int = 1

func setup_new_troop(base_blueprint: BaseTroopTemplate) -> void:
	template = base_blueprint
	
	# Roll the stats based on the blueprint's min/max ranges
	troop_health = randi_range(template.min_health, template.max_health)
	current_troop_health = troop_health
	troop_damage = randi_range(template.min_damage, template.max_damage)
	troop_speed = randi_range(template.min_speed, template.max_speed)
	troop_morale = template.base_morale
