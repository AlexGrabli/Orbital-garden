class_name SpawnEntry extends Resource
## Одна пачка спавна внутри сценария волны.

@export var delay: float = 0.0  # секунд от начала ночи
@export var enemy: EnemyResource
@export var count: int = 1
@export var spacing: float = 1.0  # интервал между особями в пачке
