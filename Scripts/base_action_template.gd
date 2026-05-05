extends Resource
class_name ActionTemplate

enum ActionType { OFFENSE, DEFENSE }
enum ActionIntensity { STRENUOUS, MODERATE, LIGHT }
enum TargetScope { NONE, SELF, SINGLE_TARGET, ARMY, ROW, COLUMN, ADJACENT }

@export var action_name: String
@export var action_type: ActionType
@export var action_intensity: ActionIntensity

@export_range(0.0, 2.0) var power_scale: float = 1.0 

@export_group("Status Effects")
# Now a single move can hold 0, 1, or 100 status effects!
@export var statuses_to_apply: Array[StatusEffectData] = []
