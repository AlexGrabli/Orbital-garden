extends SceneTree
## Тест автомата фаз: полный цикл, победа, поражение, запрет переходов.
## Запуск: godot --headless -s res://tests/phase_machine_test.gd
## В -s режиме автозагрузы регистрируются после компиляции раннера, поэтому
## скрипты машины грузятся через load() в рантайме, а шина — из дерева.

var _failures: int = 0
var _phase_log: Array[StringName] = []
var _bus: Node


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("PHASE_FAIL: " + message)


func _make_machine() -> Node:
	var config: Resource = load("res://scripts/data/run_config.gd").new()
	config.day_duration = 0.05
	config.sunset_duration = 0.05
	config.night_duration = 0.05
	config.run_days = 2
	var machine: Node = load("res://scripts/core/phase_machine.gd").new()
	machine.config = config
	root.add_child(machine)
	return machine


func _wait_for(cond: Callable, max_frames: int = 20000) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await process_frame
	return false


func _run() -> void:
	_bus = root.get_node("EventBus")
	_bus.connect(
		"phase_changed",
		func(new_phase: StringName, _day: int) -> void: _phase_log.append(new_phase)
	)

	# 1-3. Победный забег: порядок фаз и run_ended(victory=true)
	var machine := _make_machine()
	await process_frame
	_check(machine.current_id == &"main_menu", "стартовая фаза не main_menu")

	var victory_result: Array = []
	_bus.connect(
		"run_ended",
		func(victory: bool, day: int) -> void:
			victory_result.append(victory)
			victory_result.append(day),
		CONNECT_ONE_SHOT
	)

	_bus.emit_signal("run_start_requested")
	var finished: bool = await _wait_for(func() -> bool: return machine.current_id == &"run_end")
	_check(finished, "победный забег не дошёл до run_end")

	var expected: Array[StringName] = [
		&"main_menu", &"day", &"sunset", &"night", &"dawn",
		&"day", &"sunset", &"night", &"dawn", &"run_end",
	]
	_check(_phase_log == expected, "неверный порядок фаз: %s" % [_phase_log])
	_check(victory_result == [true, 3], "run_ended победы неверен: %s" % [victory_result])

	machine.queue_free()
	await process_frame

	# 4-5. Поражение и запрет перехода
	_phase_log.clear()
	machine = _make_machine()
	await process_frame

	var defeat_result: Array = []
	_bus.connect(
		"run_ended",
		func(victory: bool, day: int) -> void:
			defeat_result.append(victory)
			defeat_result.append(day),
		CONNECT_ONE_SHOT
	)
	var breach_log: Array = []
	_bus.connect(
		"night_ended",
		func(_day: int, breached: bool) -> void: breach_log.append(breached),
		CONNECT_ONE_SHOT
	)

	_bus.emit_signal("run_start_requested")
	var in_sunset: bool = await _wait_for(func() -> bool: return machine.current_id == &"sunset")
	_check(in_sunset, "не дошли до sunset")

	# 5. Запрещённый переход sunset → day игнорируется
	machine.transition_to(&"day")
	await process_frame
	_check(machine.current_id == &"sunset", "запрещённый переход sunset → day не отклонён")

	# 4. Ядро уничтожено ночью → run_ended(victory=false)
	var in_night: bool = await _wait_for(func() -> bool: return machine.current_id == &"night")
	_check(in_night, "не дошли до night")
	_bus.emit_signal("core_destroyed")
	await process_frame
	_check(machine.current_id == &"run_end", "после core_destroyed фаза не run_end")
	_check(defeat_result == [false, 1], "run_ended поражения неверен: %s" % [defeat_result])
	_check(breach_log == [true], "night_ended не сообщил о прорыве Ядра: %s" % [breach_log])

	machine.queue_free()

	if _failures == 0:
		print("PHASE_TEST_OK")
		quit(0)
	else:
		printerr("PHASE_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
