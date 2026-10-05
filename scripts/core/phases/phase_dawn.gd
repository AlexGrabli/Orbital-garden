class_name PhaseDawn extends Phase
## Рассвет: подсчёт итогов, инкремент дня, победа или следующий день.


func _init() -> void:
	id = &"dawn"


func enter(config: RunConfig) -> void:
	RunState.day_number += 1
	EventBus.dawn_started.emit(RunState.day_number)
	if RunState.day_number > config.run_days:
		machine.transition_to(&"run_end", true)
	else:
		machine.transition_to(&"day")
