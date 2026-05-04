class_name BaseTroopTemplate
extends Resource

enum Faction {
	UNAFFILIATED,
	IMPERIAL,
	VIKING,
	MERCENARY,
	COMMONFOLK,
	RAPSCALLION
}

enum AttackRange {
	MELEE,
	RANGED,
	MAGIC
}

@export_group("Core")
@export var faction: Faction = Faction.UNAFFILIATED
@export var attack_range: AttackRange = AttackRange.MELEE
@export var troop_name: String = "NA"
@export var base_cost: int = 100
@export var visual_scene: PackedScene

@export_group("Stats")
@export var max_health: int = 200
@export var min_health: int = 100
@export var base_morale: int = 100
@export var max_damage: int = 50
@export var min_damage: int = 25
@export var max_speed: int = 2
@export var min_speed: int = 1

@export_group("Moves")
@export var offensive_moves: Array[ActionTemplate] = []
@export var defensive_moves: Array[ActionTemplate] = []
