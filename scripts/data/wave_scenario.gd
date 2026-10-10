class_name WaveScenario extends Resource
## Рукописный сценарий волны: направление и расписание спавнов.
## Генератор волн и кривая сложности — Фаза 2.

enum Direction { EAST, WEST, NORTH, SOUTH }

@export var id: StringName
@export var direction: Direction = Direction.EAST  # «Рой придёт с востока»
@export var spawns: Array[SpawnEntry] = []
