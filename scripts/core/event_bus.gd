extends Node
## Глобальная шина сигналов. Единственный канал между системами.

# Уведомления о фазах
signal phase_changed(new_phase: StringName, day_number: int)
signal day_started(day_number: int)
signal sunset_started(day_number: int)
signal night_started(day_number: int)
signal night_ended(day_number: int, core_breached: bool)
signal dawn_started(day_number: int)
signal run_ended(victory: bool, day_number: int)

# Триггеры от будущих систем (UI, колода, бой)
signal run_start_requested
signal day_completed
signal core_destroyed
