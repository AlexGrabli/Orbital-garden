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
signal input_confirmed(source: StringName)  # &"cursor" (клава/геймпад)
signal input_cancelled
signal input_place_card(screen_pos: Vector2)  # press — задел под драг
signal input_pointer_released(screen_pos: Vector2)  # ЛКМ release — выбор
signal input_active_ability
signal input_tapped(screen_pos: Vector2)  # тач-тап с позицией

# Рука и колода (производители — DeckManager, HandView, GridCursor)
signal hand_changed(hand: Array[CardResource])
signal hand_card_selected(card: CardResource)
signal hand_index_selected(index: int)  # курсор в строке руки
signal deck_count_changed(count: int)
signal draft_offered(options: Array[CardResource])
signal draft_picked(card: CardResource)
signal card_played(card: CardResource, cell: Vector2i)

# Экономика дня (производители — EconomyManager, PlayController, SunsetView)
signal resources_changed(energy: int, water: int, biomass: int)
signal placement_denied(reason: StringName)
signal sunset_bet_made(mode: StringName, water_spent: int)
signal card_entity_selected(entity: Node)  # выбор размещённой карты для перемещения

# Сетка станции (производители — GridManager, GridCursor, GridView)
signal grid_occupant_placed(cell: Vector2i, occupant: Node)
signal grid_occupant_moved(from: Vector2i, to: Vector2i, occupant: Node)
signal grid_occupant_removed(cell: Vector2i, occupant: Node)
signal grid_cell_confirmed(cell: Vector2i)
signal grid_selection_cancelled
