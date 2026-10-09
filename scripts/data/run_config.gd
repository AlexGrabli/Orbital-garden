class_name RunConfig extends Resource
## Параметры забега. Единственный источник чисел — .tres в resources/.

@export var day_duration: float = 120.0
@export var sunset_duration: float = 10.0
@export var night_duration: float = 90.0
@export var run_days: int = 12
@export var hand_draw_size: int = 3  # добор утром (docs/01, «утро»)
@export var hand_limit: int = 5

# Экономика дня (docs/01 §5: ровно 3 ресурса).
@export var start_energy: int = 5
@export var start_water: int = 4
@export var start_biomass: int = 0
@export var move_cost_energy: int = 1  # обычная цена перемещения карты
@export var sunset_heal_per_water: int = 2  # РОСТ: HP ремонта за 1 воду
@export var sunset_ammo_per_water: int = 2  # БОЕПРИПАСЫ: зарядов за 1 воду
@export var dawn_biomass_reward: int = 1  # награда рассвета
