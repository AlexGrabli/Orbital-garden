class_name RunConfig extends Resource
## Параметры забега. Единственный источник чисел — .tres в resources/.

@export var day_duration: float = 120.0
@export var sunset_duration: float = 10.0
@export var night_duration: float = 90.0
@export var run_days: int = 12
@export var hand_draw_size: int = 3  # добор утром (docs/01, «утро»)
@export var hand_limit: int = 5
