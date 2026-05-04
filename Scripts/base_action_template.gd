extends Resource
class_name ActionTemplate

enum ActionType { OFFENSE, DEFENSE }
enum ActionIntensity { STRENUOUS, MODERATE, LIGHT }

# Who receives the status effect?
enum TargetScope { NONE, SELF, SINGLE_TARGET, ARMY, ROW, COLUMN, ADJACENT }

@export var action_name: String
@export var action_type: ActionType
@export var action_intensity: ActionIntensity

# Forces the Godot editor slider to stay strictly between 0.00 and 2.00
@export_range(0.0, 2.0) var power_scale: float = 1.0 

@export_group("Status Effects")
# For now, we will just type the name of the buff/debuff (e.g., "Shielded", "Poisoned").
# Later, we can change this into a dedicated StatusEffect Resource if needed.
@export var status_to_apply: String 
@export var status_target: TargetScope = TargetScope.NONE
