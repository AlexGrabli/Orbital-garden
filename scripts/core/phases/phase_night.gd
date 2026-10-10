class_name PhaseNight extends Phase
## Ночь: таймер волны. Прорыв Ядра обрабатывает машина (core_destroyed).

var _time_left: float = 0.0


func _init() -> void:
	id = &"night"


func enter(config: RunConfig) -> void:
	_time_left = config.night_duration
	RunState.night_active = true  # источник истины для врагов (спавн во время эмиссии)
	EventBus.night_started.emit(RunState.day_number)


func exit() -> void:
	RunState.night_active = false


func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		EventBus.night_ended.emit(RunState.day_number, false)
		machine.transition_to(&"dawn")
