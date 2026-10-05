class_name PhaseRunEnd extends Phase
## Конец забега: терминальное состояние.


func _init() -> void:
	id = &"run_end"


func enter(_config: RunConfig) -> void:
	RunState.run_active = false
	EventBus.run_ended.emit(machine.last_victory, RunState.day_number)
