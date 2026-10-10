extends SceneTree
## Тест боевой математики (правило 9): движение к Ядру, выстрелы турели
## (1 заряд = value урона, приоритет «ближайший к Ядру»), блокировка картами,
## прорыв и HP Ядра, ранняя зачистка ночи, heal конденсатора.
## Запуск: godot --headless -s res://tests/battle_test.gd

var _failures: int = 0
var _bus: Node
var _runstate: Node  # RunState (autoload): флаг night_active — без машины фаз
var _layout: Resource  # GridLayout
var _grid: Node  # GridManager
var _config: Resource  # RunConfig
var _registry: Resource  # CardRegistry
var _core: Node  # StationCore
var _economy: Node  # EconomyManager


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("BATTLE_FAIL: " + message)


# Ночь без машины фаз: флаг в RunState + сигнал (порядок важен — враги,
# появившиеся во время эмиссии, читают флаг).
func _start_night(day: int) -> void:
	_runstate.night_active = true
	_bus.emit_signal("night_started", day)


func _wait_for(cond: Callable, max_frames: int = 20000) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return false


# Первая buildable-клетка (Ядро занимает свою клетку).
func _next_buildable(skip: Array) -> Vector2i:
	for y in _layout.grid_size.y:
		for x in _layout.grid_size.x:
			var cell := Vector2i(x, y)
			if _grid.is_buildable(cell) and not skip.has(cell):
				return cell
	return Vector2i(-1, -1)


func _spawn_enemy(enemy_res: Resource, pos: Vector2) -> Node:
	var scene: PackedScene = load("res://scenes/entities/enemy_entity.tscn")
	var e: Node = scene.instantiate()
	e.setup(enemy_res)
	e.bind(_layout, _grid, _core)
	root.add_child(e)
	e.position = pos
	return e


func _place_card(card: Resource, cell: Vector2i) -> Node:
	var scene: PackedScene = load("res://scenes/entities/card_entity.tscn")
	var e: Node = scene.instantiate()
	e.setup(card)
	root.add_child(e)
	e.position = _layout.cell_rect(cell).get_center()
	_grid.place(cell, e)
	return e


func _east_spawn() -> Vector2:
	return Vector2(
		_layout.origin.x + _layout.grid_size.x * _layout.cell_size + _layout.cell_size / 2.0,
		_layout.origin.y + _layout.cell_size / 2.0)


func _free_cell_near(cell: Vector2i, dx: int, dy: int) -> Vector2i:
	return Vector2i(cell.x + dx, cell.y + dy)


# Часть A: механики без машины фаз (ночь включается сигналом напрямую).
func _setup_world(schedule_res: Resource) -> void:
	_bus = root.get_node("EventBus")
	_runstate = root.get_node("RunState")
	_layout = load("res://resources/grid_layout_default.tres")
	_config = load("res://resources/run_config_default.tres")
	_registry = load("res://resources/cards/card_registry.tres")

	_grid = load("res://scripts/systems/grid_manager.gd").new()
	_grid.layout = _layout
	root.add_child(_grid)

	_core = load("res://scripts/entities/station_core.gd").new()
	_core.grid = _grid
	_core.layout = _layout
	_core.config = _config
	root.add_child(_core)

	_economy = load("res://scripts/systems/economy_manager.gd").new()
	_economy.config = _config
	root.add_child(_economy)

	var night_fx: Node = load("res://scripts/systems/night_effects.gd").new()
	night_fx.economy = _economy
	night_fx.layout = _layout
	root.add_child(night_fx)

	var waves: Node = load("res://scripts/systems/wave_manager.gd").new()
	waves.schedule = schedule_res
	waves.layout = _layout
	waves.grid = _grid
	waves.core = _core
	root.add_child(waves)
	await process_frame


# Расписание без спавнов: волна «пустая», night_completed не мешает
# (враги в тестах ставятся напрямую и живут, пока не убиты).
func _empty_schedule() -> Resource:
	var scenario: Resource = load("res://scripts/data/wave_scenario.gd").new()
	scenario.id = &"empty"
	scenario.direction = 0
	var schedule: Resource = load("res://scripts/data/wave_schedule.gd").new()
	schedule.waves.append(scenario)
	return schedule


func _run() -> void:
	# 1. Враг движется к Ядру: дистанция монотонно убывает.
	await _setup_world(_empty_schedule())
	var runner: Resource = load("res://resources/enemies/swarm_runner.tres")
	var enemy := _spawn_enemy(runner, _east_spawn())
	_start_night(1)
	var prev: float = enemy.position.distance_to(_core.position)
	var monotonic := true
	for i in 30:
		await process_frame
		var d: float = enemy.position.distance_to(_core.position)
		if d > prev + 0.001:
			monotonic = false
		prev = d
	_check(monotonic, "дистанция до Ядра не убывает")
	enemy.queue_free()
	await process_frame

	# 2. Турель: 1 заряд = 1 выстрел = value урона; бегун HP 10 падает ровно
	#    от 2 выстрелов; без заряда — ни одного выстрела.
	var turret_card: Resource = _registry.find(&"turret_laser")
	var cell_t: Vector2i = _next_buildable([])
	var turret := _place_card(turret_card, cell_t)
	turret.charge = 2.0
	var target := _spawn_enemy(runner, _east_spawn())
	_start_night(2)
	var killed: bool = await _wait_for(func() -> bool: return not is_instance_valid(target) or target.current_hp <= 0)
	_check(killed, "турель не убила бегуна (HP 10, 2 выстрела по 5)")
	_check(turret.charge == 0.0, "заряд турели не израсходован: %s" % [turret.charge])

	var idle_target := _spawn_enemy(runner, _east_spawn())
	await process_frame
	_start_night(3)
	var idle_frames := 0
	for i in 60:
		await process_frame
		if idle_target.current_hp < runner.hp:
			break
		idle_frames += 1
	_check(idle_frames == 60, "турель стреляет без заряда")
	idle_target.queue_free()
	await process_frame

	# 3. Приоритет «ближайший к Ядру»: ближний (HP 5) умирает первым.
	turret.charge = 10.0
	var core_pos: Vector2 = _core.position
	var near_e := _spawn_enemy(runner, core_pos + Vector2(_layout.cell_size * 2.0, 0))
	near_e.current_hp = 5
	# Дальний тоже в радиусе турели (3 клетки), но дальше от Ядра.
	var far_e := _spawn_enemy(runner, core_pos + Vector2(_layout.cell_size * 2.5, 0))
	far_e.current_hp = 5
	_start_night(4)
	var near_died: bool = await _wait_for(func() -> bool: return not is_instance_valid(near_e) or near_e.current_hp <= 0)
	_check(near_died, "ближний враг не убит первым")
	_check(is_instance_valid(far_e) and far_e.current_hp == 5,
		"дальний враг получил урон до ближнего: HP %s" % [far_e.current_hp if is_instance_valid(far_e) else "freed"])
	far_e.queue_free()
	turret.charge = 0.0  # дальше турель не мешает: проверяем рукопашку и heal
	await process_frame

	# 4. Блокировка: враг упирается в стену, бьёт по attack_damage,
	#    разрушение → card_destroyed, клетка свободна, враг идёт дальше.
	var wall_card: Resource = _registry.find(&"wall_barrier")
	var wall_cell := _free_cell_near(_layout.core_cell, 1, 0)  # (2, 1) — на пути с востока
	var wall := _place_card(wall_card, wall_cell)
	wall.current_hp = runner.attack_damage * 2  # два удара до разрушения
	var destroyed_log: Array = []
	_bus.connect("card_destroyed",
		func(entity: Node, cell: Vector2i) -> void: destroyed_log.append([entity, cell]), CONNECT_ONE_SHOT)
	var blocker_e := _spawn_enemy(runner, _east_spawn())
	_start_night(5)
	# Стена выставлена в runner.attack_damage * 2: ждём ПЕРВОГО удара (4 → 2).
	var hp_dropped: bool = await _wait_for(func() -> bool: return wall.current_hp < runner.attack_damage * 2)
	_check(wall.current_hp == runner.attack_damage * 2 - runner.attack_damage,
		"урон по карте != attack_damage: %d" % [wall.current_hp])
	var destroyed: bool = await _wait_for(func() -> bool:
		return not is_instance_valid(wall) or _grid.occupant_at(wall_cell) == null)
	_check(destroyed, "стена не разрушена")
	_check(_grid.occupant_at(wall_cell) == null, "клетка стены не свободна")
	_check(destroyed_log.size() == 1 and destroyed_log[0][1] == wall_cell,
		"card_destroyed неверен: %s" % [destroyed_log])
	# Враг пошёл дальше: дистанция до Ядра снова убывает.
	prev = blocker_e.position.distance_to(_core.position)
	monotonic = true
	for i in 30:
		await process_frame
		var d2: float = blocker_e.position.distance_to(_core.position)
		if d2 > prev + 0.001:
			monotonic = false
		prev = d2
	_check(monotonic, "враг не пошёл дальше после разрушения стены")
	blocker_e.queue_free()
	turret.queue_free()
	await process_frame

	# 5. Heal конденсатора: раненое растение в радиусе восстанавливается
	#    ровно на value, не выше потолка card.hp.
	# Страж: стена на пути врага держит ночь активной (без врагов ночь
	# завершилась бы night_completed раньше второго импульса лечения).
	var guard_wall := _place_card(wall_card, _free_cell_near(_layout.core_cell, 1, 0))
	guard_wall.current_hp = wall_card.hp
	var guard_e := _spawn_enemy(runner, _east_spawn())
	var condenser_card: Resource = _registry.find(&"moisture_condenser")
	var cactus_card: Resource = _registry.find(&"cactus_battery")
	var cell_healer: Vector2i = _next_buildable([])
	var healer := _place_card(condenser_card, cell_healer)
	var cell_plant: Vector2i = _free_cell_near(cell_healer, 0, 1)
	var plant := _place_card(cactus_card, cell_plant)
	plant.current_hp = cactus_card.hp - 4
	_start_night(6)
	var healed: bool = await _wait_for(func() -> bool: return plant.current_hp > cactus_card.hp - 4)
	_check(healed, "конденсатор не лечит растение")
	_check(plant.current_hp == cactus_card.hp - 4 + int(condenser_card.night_effect.value),
		"heal != value: %d" % [plant.current_hp])
	# Потолок: доводим до card.hp - 1, следующий импульс не пробивает потолок.
	plant.current_hp = cactus_card.hp - 1
	var capped: bool = await _wait_for(func() -> bool: return plant.current_hp >= cactus_card.hp)
	_check(capped and plant.current_hp == cactus_card.hp,
		"heal пробил потолок HP: %d" % [plant.current_hp])
	guard_e.queue_free()
	guard_wall.queue_free()
	healer.queue_free()
	plant.queue_free()
	await process_frame

	# Часть B: интеграция с машиной фаз — прорыв до 0 HP → поражение.
	await _part_breach()
	await _part_early_dawn()

	if _failures == 0:
		print("BATTLE_TEST_OK")
		quit(0)
	else:
		printerr("BATTLE_TEST_FAIL: ошибок %d" % _failures)
		quit(1)


# Враг прорывается к Ядру с HP 1 → core_destroyed → run_ended(false).
func _part_breach() -> void:
	# Автозагрузы (EventBus, RunState) — не трогаем.
	for node: Node in root.get_children():
		if node.name != &"EventBus" and node.name != &"RunState":
			node.queue_free()
	await process_frame

	var config: Resource = load("res://scripts/data/run_config.gd").new()
	config.day_duration = 0.05
	config.sunset_duration = 0.05
	config.night_duration = 30.0
	config.run_days = 2
	config.core_hp = 1
	var machine: Node = load("res://scripts/core/phase_machine.gd").new()
	machine.config = config
	root.add_child(machine)
	await process_frame

	_layout = load("res://resources/grid_layout_default.tres")
	_grid = load("res://scripts/systems/grid_manager.gd").new()
	_grid.layout = _layout
	root.add_child(_grid)
	_core = load("res://scripts/entities/station_core.gd").new()
	_core.grid = _grid
	_core.layout = _layout
	_core.config = config
	root.add_child(_core)
	_economy = load("res://scripts/systems/economy_manager.gd").new()
	_economy.config = config
	root.add_child(_economy)
	var night_fx: Node = load("res://scripts/systems/night_effects.gd").new()
	night_fx.economy = _economy
	night_fx.layout = _layout
	root.add_child(night_fx)
	var waves: Node = load("res://scripts/systems/wave_manager.gd").new()
	waves.schedule = load("res://resources/waves/wave_schedule.tres")  # день 1: 3 бегуна
	waves.layout = _layout
	waves.grid = _grid
	waves.core = _core
	root.add_child(waves)
	await process_frame

	var breach_log: Array = []
	_bus.connect("night_ended",
		func(_d: int, breached: bool) -> void: breach_log.append(breached))
	var ended_log: Array = []
	_bus.connect("run_ended",
		func(victory: bool, day: int) -> void:
			ended_log.append(victory)
			ended_log.append(day), CONNECT_ONE_SHOT)

	_bus.emit_signal("run_start_requested")
	var in_night: bool = await _wait_for(func() -> bool: return machine.current_id == &"night")
	_check(in_night, "машина не дошла до night")
	var ended: bool = await _wait_for(func() -> bool: return machine.current_id == &"run_end")
	_check(ended, "после прорыва Ядра фаза не run_end")
	_check(ended_log == [false, 1], "run_ended поражения неверен: %s" % [ended_log])
	_check(breach_log == [true], "night_ended не сообщил о прорыве: %s" % [breach_log])
	machine.queue_free()
	await process_frame


# Зачистка: пустая волна + нет врагов → night_completed → dawn раньше таймера.
func _part_early_dawn() -> void:
	for node: Node in root.get_children():
		if node.name != &"EventBus" and node.name != &"RunState":
			node.queue_free()
	await process_frame

	var config: Resource = load("res://scripts/data/run_config.gd").new()
	config.day_duration = 0.05
	config.sunset_duration = 0.05
	config.night_duration = 30.0  # длинная ночь: рассвет может прийти только от зачистки
	config.run_days = 2
	var machine: Node = load("res://scripts/core/phase_machine.gd").new()
	machine.config = config
	root.add_child(machine)
	await process_frame

	_layout = load("res://resources/grid_layout_default.tres")
	_grid = load("res://scripts/systems/grid_manager.gd").new()
	_grid.layout = _layout
	root.add_child(_grid)
	_core = load("res://scripts/entities/station_core.gd").new()
	_core.grid = _grid
	_core.layout = _layout
	_core.config = config
	root.add_child(_core)
	# Свежая экономика: предыдущая часть освободила свои узлы.
	_economy = load("res://scripts/systems/economy_manager.gd").new()
	_economy.config = config
	root.add_child(_economy)
	var night_fx: Node = load("res://scripts/systems/night_effects.gd").new()
	night_fx.economy = _economy
	night_fx.layout = _layout
	root.add_child(night_fx)
	var waves: Node = load("res://scripts/systems/wave_manager.gd").new()
	waves.schedule = _empty_schedule()
	waves.layout = _layout
	waves.grid = _grid
	waves.core = _core
	root.add_child(waves)
	await process_frame

	var breach_log: Array = []
	_bus.connect("night_ended",
		func(_d: int, breached: bool) -> void: breach_log.append(breached))
	var night_count: Array = []
	_bus.connect("night_started", func(_d: int) -> void: night_count.append(1))
	_bus.emit_signal("run_start_requested")
	# night_completed мгновенен: фаза night может не быть видна между кадрами,
	# поэтому ловим сам вход (night_started) и уход в day.
	var saw_night: bool = await _wait_for(func() -> bool: return night_count.size() == 1)
	_check(saw_night, "машина не дошла до night (зачистка)")
	# Dawn мгновенно уходит в day (следующий день), таймер ночи — 30 сек:
	# наблюдаем day раньше таймера только через night_completed.
	var next_day: bool = await _wait_for(
		func() -> bool: return machine.current_id == &"day", 5000)
	_check(next_day, "night_completed не перевёл ночь в рассвет раньше таймера")
	_check(breach_log == [false], "night_ended зачистки неверен: %s" % [breach_log])
	machine.queue_free()
