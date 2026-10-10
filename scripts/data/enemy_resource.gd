class_name EnemyResource extends Resource
## Данные врага Роя. Числа — только в .tres (resources/enemies/).
## Архетипы Фазы 2 расширят схему, не ломая её.

@export var id: StringName
@export var name: String
@export var hp: int
@export var speed: float  # px/сек (движение — задача 7)
@export var core_damage: int  # урон Ядру при прорыве (задача 7)
@export var tags: Array[StringName] = []  # рой, бегун, танк...
