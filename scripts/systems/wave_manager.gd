class_name WaveManager extends Node
## Волна по сценарию из данных: разворачивает тайминги в плоскую очередь
## и спавнит врагов у края сетки по direction. Без RNG (генератор — Фаза 2).
## Движение, бой и HP Ядра — задача 7.

@export var schedule: WaveSchedule
@export var layout: GridLayout
@export var grid: GridManager  # для рукопашки врагов
@export var core: StationCore  # цель движения врагов

var _queue: Array = []  # [{time, enemy, serial}]
var _elapsed: float = 0.0
var _day: int = 0
var _direction: WaveScenario.Direction = WaveScenario.Direction.EAST
var _active: bool = false

var _enemy_scene: PackedScene = preload("res://scenes/entities/enemy_entity.tscn")


func _ready() -> void:
	EventBus.night_started.connect(_on_night_started)
	EventBus.dawn_started.connect(_on_dawn_started)
	EventBus.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	while not _queue.is_empty() and _queue[0].time <= _elapsed:
		var entry: Dictionary = _queue.pop_front()
		_spawn(entry.enemy, entry.serial)
	if _queue.is_empty():
		_active = false
		EventBus.wave_spawns_finished.emit(_day)


func _on_night_started(day: int) -> void:
	var scenario := schedule.for_day(day)
	_day = day
	_elapsed = 0.0
	_queue.clear()
	_direction = scenario.direction if scenario != null else WaveScenario.Direction.EAST
	var serial := 0
	if scenario != null:
		for spawn: SpawnEntry in scenario.spawns:
			for i in spawn.count:
				_queue.append({
					"time": spawn.delay + i * spawn.spacing,
					"enemy": spawn.enemy,
					"serial": serial,
				})
				serial += 1
		_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	_active = not _queue.is_empty()
	EventBus.wave_started.emit(day, scenario)
	if _queue.is_empty():
		EventBus.wave_spawns_finished.emit(_day)


func _on_dawn_started(_day: int) -> void:
	_clear_wave()


func _on_run_ended(_victory: bool, _day: int) -> void:
	_clear_wave()


func _clear_wave() -> void:
	_active = false
	_queue.clear()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.queue_free()


# Точка за краем сетки; пачка раскладывается вдоль края порядково.
func _spawn_point(serial: int) -> Vector2:
	var cell := float(layout.cell_size)
	var half := cell / 2.0
	var left := layout.origin.x
	var top := layout.origin.y
	var right := left + layout.grid_size.x * cell
	var bottom := top + layout.grid_size.y * cell
	match _direction:
		WaveScenario.Direction.WEST:
			return Vector2(left - half, top + half + _edge_offset(serial, layout.grid_size.y))
		WaveScenario.Direction.NORTH:
			return Vector2(left + half + _edge_offset(serial, layout.grid_size.x), top - half)
		WaveScenario.Direction.SOUTH:
			return Vector2(left + half + _edge_offset(serial, layout.grid_size.x), bottom + half)
	return Vector2(right + half, top + half + _edge_offset(serial, layout.grid_size.y))


func _edge_offset(serial: int, cells: int) -> float:
	return float(serial % cells) * layout.cell_size


func _spawn(enemy_res: EnemyResource, serial: int) -> void:
	var entity: EnemyEntity = _enemy_scene.instantiate()
	entity.setup(enemy_res)
	entity.bind(layout, grid, core)
	add_child(entity)
	entity.position = _spawn_point(serial)
	EventBus.enemy_spawned.emit(entity)
