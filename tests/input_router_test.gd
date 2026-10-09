extends SceneTree
## Тест InputRouter: события устройств → сигналы EventBus, зеркалирование биндингов.
## Запуск: godot --headless -s res://tests/input_router_test.gd
## Паттерн как в phase_machine_test: шина из дерева, роутер через load(),
## результаты лямбд — только append в массив.

var _failures: int = 0
var _bus: Node


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("INPUT_FAIL: " + message)


func _key(physical: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	ev.pressed = pressed
	return ev


func _joy_button(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	return ev


func _mouse_button(button: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	return ev


# Доставка события через конвейер ввода и ожидание обработки.
func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await process_frame
	await process_frame


func _run() -> void:
	_bus = root.get_node("EventBus")
	var router: Node = load("res://scripts/core/input_router.gd").new()
	root.add_child(router)
	await process_frame

	var log: Array[StringName] = []
	var cursor_dirs: Array = []
	var place_positions: Array = []
	_bus.connect("input_confirmed", func() -> void: log.append(&"confirm"))
	_bus.connect("input_cancelled", func() -> void: log.append(&"cancel"))
	_bus.connect("input_active_ability", func() -> void: log.append(&"ability"))
	_bus.connect("input_cursor_moved", func(dir: Vector2i) -> void: cursor_dirs.append(dir))
	_bus.connect("input_place_card", func(pos: Vector2) -> void: place_positions.append(pos))

	# 1. InputEventAction(confirm) → input_confirmed
	var act := InputEventAction.new()
	act.action = &"confirm"
	act.pressed = false
	await _send(act)
	_check(log == [&"confirm"], "InputEventAction(confirm) не дал input_confirmed: %s" % [log])
	log.clear()

	# 2. Клавиатура: Enter (release) → confirm, Esc → cancel, F → active_ability
	await _send(_key(KEY_ENTER, false))
	_check(log == [&"confirm"], "Enter не дал input_confirmed: %s" % [log])
	log.clear()
	await _send(_key(KEY_ESCAPE, true))
	_check(log == [&"cancel"], "Esc не дал input_cancelled: %s" % [log])
	log.clear()
	await _send(_key(KEY_F, true))
	_check(log == [&"ability"], "F не дал input_active_ability: %s" % [log])
	log.clear()

	# 3. Геймпад: A press → place_card, A release → confirm, B → cancel
	await _send(_joy_button(JOY_BUTTON_A, true))
	_check(place_positions.size() == 1, "кнопка A (press) не дала input_place_card")
	await _send(_joy_button(JOY_BUTTON_A, false))
	_check(log == [&"confirm"], "кнопка A (release) не дала input_confirmed: %s" % [log])
	log.clear()
	await _send(_joy_button(JOY_BUTTON_B, true))
	_check(log == [&"cancel"], "кнопка B не дала input_cancelled: %s" % [log])
	log.clear()

	# 4. Стик вверх → input_cursor_moved(UP)
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	await _send(stick)
	_check(cursor_dirs == [Vector2i.UP], "стик вверх не дал курсор UP: %s" % [cursor_dirs])
	cursor_dirs.clear()

	# 5. Тач: тап → input_tapped с позицией + input_confirmed (паритет UI)
	var tapped: Array = []
	_bus.connect("input_tapped", func(pos: Vector2) -> void: tapped.append(pos))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(320, 180)
	await _send(touch)
	_check(log == [&"confirm"], "тап не дал input_confirmed: %s" % [log])
	var expected_tap: Vector2 = root.get_screen_transform().affine_inverse() * Vector2(320, 180)
	_check(tapped.size() == 1 and tapped[0].is_equal_approx(expected_tap),
		"тап не дал input_tapped с позицией: %s" % [tapped])
	log.clear()

	# 6. Мышь: ПКМ → cancel, ЛКМ press → place_card с позицией, ЛКМ release → confirm
	await _send(_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(10, 10)))
	_check(log == [&"cancel"], "ПКМ не дала input_cancelled: %s" % [log])
	log.clear()
	# Движок трансформирует координаты окна в canvas-координаты (stretch).
	var expected_pos: Vector2 = root.get_screen_transform().affine_inverse() * Vector2(100, 50)
	await _send(_mouse_button(MOUSE_BUTTON_LEFT, true, Vector2(100, 50)))
	var got_pos: Vector2 = place_positions[1] if place_positions.size() == 2 else Vector2(-1, -1)
	_check(place_positions.size() == 2 and got_pos.is_equal_approx(expected_pos),
		"ЛКМ (press) не дала input_place_card с позицией: %s != %s" % [place_positions, expected_pos])
	await _send(_mouse_button(MOUSE_BUTTON_LEFT, false, Vector2(100, 50)))
	_check(log == [&"confirm"], "ЛКМ (release) не дала input_confirmed: %s" % [log])
	log.clear()

	# 7. Зеркалирование: у каждого действия биндинги минимум двух классов устройств.
	for action: StringName in [
		&"move_cursor_up", &"move_cursor_down", &"move_cursor_left", &"move_cursor_right",
		&"confirm", &"cancel", &"place_card", &"active_ability",
	]:
		var classes: Dictionary = {}
		for ev: InputEvent in InputMap.action_get_events(action):
			classes[ev.get_class()] = true
		_check(classes.size() >= 2,
			"действие %s не зеркалировано (классы: %s)" % [action, classes.keys()])

	router.queue_free()

	if _failures == 0:
		print("INPUT_TEST_OK")
		quit(0)
	else:
		printerr("INPUT_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
