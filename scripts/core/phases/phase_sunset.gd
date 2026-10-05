class_name PhaseSunset extends Phase
## Закат: «ставка заката» — пока только сигнал, механика в задаче 5.

var _time_left: float = 0.0


func _init() -> void:
	id = &"sunset"


func enter(config: RunConfig) -> void:
	_time_left = config.sunset_duration
	EventBus.sunset_started.emit(RunState.day_number)


func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		machine.transition_to(&"night")
