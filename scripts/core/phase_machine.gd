class_name PhaseMachine extends Node
## Конечный автомат фаз забега: main_menu → day → sunset → night → dawn → run_end.

@export var config: RunConfig

var current_id: StringName = &""
var last_victory: bool = false

var _phases: Dictionary = {}
var _current: Phase

# Таблица допустимых переходов; run_end (поражение) доступен из любой фазы.
const _ALLOWED: Dictionary = {
	&"main_menu": [&"day"],
	&"day": [&"sunset"],
	&"sunset": [&"night"],
	&"night": [&"dawn"],
	&"dawn": [&"day"],
}


func _ready() -> void:
	for phase: Phase in [
		PhaseMainMenu.new(),
		PhaseDay.new(),
		PhaseSunset.new(),
		PhaseNight.new(),
		PhaseDawn.new(),
		PhaseRunEnd.new(),
	]:
		phase.machine = self
		_phases[phase.id] = phase
	EventBus.run_start_requested.connect(_on_run_start_requested)
	EventBus.day_completed.connect(_on_day_completed)
	EventBus.core_destroyed.connect(_on_core_destroyed)
	_enter(&"main_menu")


func _process(delta: float) -> void:
	if _current != null:
		_current.update(delta)


func transition_to(id: StringName, victory: bool = false) -> void:
	if id != &"run_end" and not _ALLOWED.get(current_id, [] as Array).has(id):
		push_warning("PhaseMachine: запрещённый переход %s → %s" % [current_id, id])
		return
	_enter(id, victory)


func _enter(id: StringName, victory: bool = false) -> void:
	if _current != null:
		_current.exit()
	last_victory = victory
	_current = _phases[id]
	current_id = id
	EventBus.phase_changed.emit(id, RunState.day_number)
	_current.enter(config)


func _on_run_start_requested() -> void:
	if current_id == &"main_menu":
		transition_to(&"day")


func _on_day_completed() -> void:
	if current_id == &"day":
		transition_to(&"sunset")


func _on_core_destroyed() -> void:
	if current_id == &"main_menu" or current_id == &"run_end":
		return
	if current_id == &"night":
		EventBus.night_ended.emit(RunState.day_number, true)
	transition_to(&"run_end", false)
