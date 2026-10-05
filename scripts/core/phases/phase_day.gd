class_name PhaseDay extends Phase
## День: таймер или сигнал day_completed (появится с колодой) → закат.

var _time_left: float = 0.0


func _init() -> void:
	id = &"day"


func enter(config: RunConfig) -> void:
	RunState.run_active = true
	_time_left = config.day_duration
	EventBus.day_started.emit(RunState.day_number)


func update(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		machine.transition_to(&"sunset")
