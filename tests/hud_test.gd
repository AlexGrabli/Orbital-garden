extends SceneTree
## Тест HUD: ресурсы, HP Ядра, день/фаза, прогноз атаки, старт/«к ночи»,
## пауза. Запуск: godot --headless -s res://tests/hud_test.gd

var _failures: int = 0
var _bus: Node
var _hud: Node


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("HUD_FAIL: " + message)


func _run() -> void:
	_bus = root.get_node("EventBus")
	var scene: PackedScene = load("res://scenes/ui/hud.tscn")
	_hud = scene.instantiate()
	_hud.config = load("res://resources/run_config_default.tres")
	_hud.schedule = load("res://resources/waves/wave_schedule.tres")
	root.add_child(_hud)
	await process_frame

	# 1. Ресурсы: полоса — самостоятельный подписчик.
	_bus.emit_signal("resources_changed", 7, 3, 2)
	await process_frame
	var bar_text: String = _hud.get_node("SafeMargins/Layout/TopBar/ResourcesBar/Label").text
	_check(bar_text == "Э7 · В3 · Б2", "полоса ресурсов: '%s'" % [bar_text])

	# 2. HP Ядра.
	_bus.emit_signal("core_hp_changed", 15, 20)
	await process_frame
	var core_text: String = _hud.get_node("SafeMargins/Layout/TopBar/CoreLabel").text
	_check(core_text == "Ядро 15/20", "HP Ядра: '%s'" % [core_text])

	# 3. Меню: старт забега виден, confirm-паритет через фокус кнопки.
	var start_button: Button = _hud.get_node("SafeMargins/Layout/TopBar/StartButton")
	_check(start_button.visible, "кнопка старта не видна в меню")
	var started: Array = []
	_bus.connect("run_start_requested", func() -> void: started.append(1))
	start_button.pressed.emit()
	await process_frame
	_check(started.size() == 1, "кнопка старта не эмитит run_start_requested")

	# 4. День: счётчик, фаза, прогноз (направление и состав — из данных).
	_bus.emit_signal("phase_changed", &"day", 1)
	await process_frame
	var day_text: String = _hud.get_node("SafeMargins/Layout/TopBar/DayLabel").text
	_check(day_text == "День 1 из 12", "счётчик дня: '%s'" % [day_text])
	var phase_text: String = _hud.get_node("SafeMargins/Layout/TopBar/PhaseLabel").text
	_check(phase_text == "День", "название фазы: '%s'" % [phase_text])
	var forecast: Label = _hud.get_node("SafeMargins/Layout/TopBar/ForecastLabel")
	_check(forecast.visible, "прогноз скрыт днём")
	# Ожидание строим из wave_schedule.tres, не хардкодом строки.
	var scenario: Resource = _hud.schedule.for_day(1)
	var expected_dir := "востока"
	match scenario.direction:
		1:
			expected_dir = "запада"
		2:
			expected_dir = "севера"
		3:
			expected_dir = "юга"
	var total := 0
	for spawn: Resource in scenario.spawns:
		total += spawn.count
	_check(forecast.text.contains(expected_dir),
		"прогноз без направления из данных: '%s'" % [forecast.text])
	_check(forecast.text.contains(str(total)),
		"прогноз без состава волны: '%s'" % [forecast.text])

	# 5. «К ночи»: досрочный day_completed.
	var end_day: Button = _hud.get_node("SafeMargins/Layout/TopBar/EndDayButton")
	_check(end_day.visible, "«К ночи» скрыта днём")
	var day_done: Array = []
	_bus.connect("day_completed", func() -> void: day_done.append(1))
	end_day.pressed.emit()
	await process_frame
	_check(day_done.size() == 1, "«К ночи» не эмитит day_completed")

	# 6. Ночь: прогноз скрыт.
	_bus.emit_signal("phase_changed", &"night", 1)
	await process_frame
	_check(not forecast.visible, "прогноз виден ночью")

	# 7. Пауза: переключает get_tree().paused, HUD — PROCESS_MODE_ALWAYS.
	_check(_hud.process_mode == Node.PROCESS_MODE_ALWAYS,
		"HUD не PROCESS_MODE_ALWAYS: %d" % [_hud.process_mode])
	var pause_button: Button = _hud.get_node("SafeMargins/Layout/TopBar/PauseButton")
	pause_button.pressed.emit()
	await process_frame
	_check(paused, "пауза не включила get_tree().paused")
	var overlay: Control = _hud.get_node("PauseOverlay")
	_check(overlay.visible, "оверлей паузы не показан")
	# HUD интерактивен на паузе: кнопка «Продолжить» снимает.
	var resume: Button = _hud.get_node("PauseOverlay/Panel/Box/ResumeButton")
	resume.pressed.emit()
	await process_frame
	_check(not paused, "«Продолжить» не сняла паузу")

	# 8. Конец забега: плашка Поражение/Победа.
	_bus.emit_signal("run_ended", false, 3)
	await process_frame
	_check(overlay.visible, "плашка конца забега не показана")
	var title: String = _hud.get_node("PauseOverlay/Panel/Box/Title").text
	_check(title == "Поражение", "плашка поражения: '%s'" % [title])

	_hud.queue_free()
	await process_frame

	if _failures == 0:
		print("HUD_TEST_OK")
		quit(0)
	else:
		printerr("HUD_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
