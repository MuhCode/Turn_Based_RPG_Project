extends Resource
class_name StatusEffectData

enum TargetScope { NONE, SELF, SINGLE_TARGET, ARMY, ROW, COLUMN, ADJACENT }
# Add our new timing enum
enum TickTiming { TURN_START, TURN_END, ROUND_START }

@export var effect_name: String
@export var target: TargetScope = TargetScope.SELF
@export var value: float
@export var duration: int = 1

# Give it a default of ticking at the start of the unit's turn
@export var tick_when: TickTiming = TickTiming.TURN_START
