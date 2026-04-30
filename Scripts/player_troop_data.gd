class_name PlayerTroopData
extends Resource

var template: BaseTroopTemplate
var troop_health: int
var current_troop_health: int
var troop_damage: int
var troop_morale: int
var troop_level: int = 1

func setup_new_troop(base_blueprint: BaseTroopTemplate) -> void:
	template = base_blueprint
	troop_health = randi_range(template.min_health, template.max_health)
	current_troop_health = troop_health
	troop_damage = randi_range(template.min_damage, template.max_damage)
	troop_morale = template.base_morale
	
