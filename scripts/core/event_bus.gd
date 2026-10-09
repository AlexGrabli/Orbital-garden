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

# Ввод (единственный производитель — InputRouter)
signal input_cursor_moved(direction: Vector2i)
signal input_confirmed
signal input_cancelled
signal input_place_card(screen_pos: Vector2)
signal input_active_ability
signal input_tapped(screen_pos: Vector2)  # тач-тап с позицией (для сетки/UI)

# Сетка станции (производители — GridManager, GridCursor, GridView)
signal grid_occupant_placed(cell: Vector2i, occupant: Node)
signal grid_occupant_moved(from: Vector2i, to: Vector2i, occupant: Node)
signal grid_occupant_removed(cell: Vector2i, occupant: Node)
signal grid_cell_confirmed(cell: Vector2i)
signal grid_selection_cancelled
