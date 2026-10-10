extends SceneTree
## Тест WaveManager: расписание (кламп), порядок и количество спавнов,
## геометрия спавна по направлению, зачистка на рассвете.
## Запуск: godot --headless -s res://tests/wave_test.gd

var _failures: int = 0
var _bus: Node
var _layout: Resource  # GridLayout


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("WAVE_FAIL: " + message)


func _wait_for(cond: Callable, max_frames: int = 2000) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return false


func _make_manager(schedule: Resource) -> Node:
	var manager: Node = load("res://scripts/systems/wave_manager.gd").new()
	manager.schedule = schedule
	manager.layout = _layout
	root.add_child(manager)
	return manager


# Тестовый сценарий со сжатыми таймингами: 2 бегуна (0.05с) + 1 танк (0.15с).
func _fast_schedule() -> Resource:
	var runner: Resource = load("res://resources/enemies/swarm_runner.tres")
	var brute: Resource = load("res://resources/enemies/swarm_brute.tres")
	var entry_a: Resource = load("res://scripts/data/spawn_entry.gd").new()
	entry_a.delay = 0.05
	entry_a.enemy = runner
	entry_a.count = 2
	entry_a.spacing = 0.02
	var entry_b: Resource = load("res://scripts/data/spawn_entry.gd").new()
	entry_b.delay = 0.15
	entry_b.enemy = brute
	var scenario: Resource = load("res://scripts/data/wave_scenario.gd").new()
	scenario.id = &"test_wave"
	scenario.direction = 0  # EAST
	scenario.spawns.append(entry_a)
	scenario.spawns.append(entry_b)
	var schedule: Resource = load("res://scripts/data/wave_schedule.gd").new()
	schedule.waves.append(scenario)
	return schedule


func _run() -> void:
	_bus = root.get_node("EventBus")
	_layout = load("res://resources/grid_layout_default.tres")

	# 1. Расписание: for_day(1..3) — свои волны, for_day(99) — кламп на последнюю.
	var schedule: Resource = load("res://resources/waves/wave_schedule.tres")
	_check(schedule.for_day(1).id == &"wave_day1", "for_day(1) != wave_day1")
	_check(schedule.for_day(3).id == &"wave_day3", "for_day(3) != wave_day3")
	_check(schedule.for_day(99) == schedule.for_day(3), "for_day(99) не кламп на последнюю")

	# 2. Спавн по сжатым таймингам: порядок и количество.
	var manager := _make_manager(_fast_schedule())
	await process_frame
	var spawned: Array = []
	_bus.connect("enemy_spawned", func(e: Node) -> void: spawned.append(e))
	var started_log: Array = []
	_bus.connect("wave_started",
		func(day: int, scenario: Resource) -> void: started_log.append([day, scenario.id]))
	var finished_log: Array = []
	_bus.connect("wave_spawns_finished", func(day: int) -> void: finished_log.append(day))

	_bus.emit_signal("night_started", 1)
	var finished: bool = await _wait_for(func() -> bool: return finished_log.size() == 1)
	_check(finished, "волна не отспавнилась за отведённые кадры")
	_check(started_log == [[1, &"test_wave"]], "wave_started неверен: %s" % [started_log])
	_check(finished_log == [1], "wave_spawns_finished неверен: %s" % [finished_log])
	_check(spawned.size() == 3, "спавнов != 3: %d" % [spawned.size()])
	var ids: Array = []
	for e: Node in spawned:
		ids.append(e.enemy.id)
	_check(ids == [&"swarm_runner", &"swarm_runner", &"swarm_brute"],
		"порядок спавнов неверен: %s" % [ids])

	# 3. Геометрия EAST: все враги правее правого края сетки (из GridLayout).
	var right_edge: float = _layout.origin.x + _layout.grid_size.x * _layout.cell_size
	for e: Node in spawned:
		_check(e.position.x > right_edge, "спавн не за восточным краем: %s" % [e.position])

	# 4. Рассвет: группа enemies пуста.
	_bus.emit_signal("dawn_started", 2)
	await process_frame
	await process_frame
	_check(get_nodes_in_group(&"enemies").is_empty(),
		"враги не рассеяны на рассвете: %d" % [get_nodes_in_group(&"enemies").size()])

	manager.queue_free()
	await process_frame

	# 5. Направления: WEST — левее левого края, SOUTH — ниже нижнего.
	for dir_pair in [[1, "west"], [3, "south"]]:
		var s := _fast_schedule()
		s.waves[0].direction = dir_pair[0]
		manager = _make_manager(s)
		await process_frame
		spawned.clear()
		finished_log.clear()
		_bus.emit_signal("night_started", 1)
		finished = await _wait_for(func() -> bool: return finished_log.size() == 1)
		_check(finished, "волна (%s) не отспавнилась" % [dir_pair[1]])
		for e: Node in spawned:
			if dir_pair[1] == "west":
				_check(e.position.x < _layout.origin.x, "WEST: спавн не слева: %s" % [e.position])
			else:
				var bottom_edge: float = _layout.origin.y + _layout.grid_size.y * _layout.cell_size
				_check(e.position.y > bottom_edge, "SOUTH: спавн не снизу: %s" % [e.position])
		_bus.emit_signal("dawn_started", 2)
		await process_frame
		manager.queue_free()
		await process_frame

	if _failures == 0:
		print("WAVE_TEST_OK")
		quit(0)
	else:
		printerr("WAVE_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
