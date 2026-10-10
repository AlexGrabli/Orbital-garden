extends Node
## Состояние текущего забега. Экономика — задача 5.

var day_number: int = 1
var run_active: bool = false
var night_active: bool = false  # источник истины: фаза night (см. PhaseNight)


func reset() -> void:
	day_number = 1
	run_active = false
	night_active = false
