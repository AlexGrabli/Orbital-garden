class_name WaveSchedule extends Resource
## Расписание волн по дням. Дни за пределами списка — кламп на последнюю
## волну (процедурная кривая сложности — Фаза 2).

@export var waves: Array[WaveScenario] = []


func for_day(day: int) -> WaveScenario:
	if waves.is_empty():
		return null
	return waves[clampi(day - 1, 0, waves.size() - 1)]
