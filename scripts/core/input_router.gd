class_name InputRouter extends Node
## Единственное место чтения ввода. Переводит action map и тач в сигналы EventBus.

# Курсорные действия → направление.
const _CURSOR_DIRS: Dictionary = {
	&"move_cursor_up": Vector2i.UP,
	&"move_cursor_down": Vector2i.DOWN,
	&"move_cursor_left": Vector2i.LEFT,
	&"move_cursor_right": Vector2i.RIGHT,
}


func _unhandled_input(event: InputEvent) -> void:
	# Тач маппится вручную (эмуляция мыши из тача выключена в проекте).
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			EventBus.input_tapped.emit(touch.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		return # драг по сетке и картам — задача 8 / Фаза 4

	for action: StringName in _CURSOR_DIRS:
		if event.is_action_pressed(action):
			EventBus.input_cursor_moved.emit(_CURSOR_DIRS[action])
			get_viewport().set_input_as_handled()
			return

	# press = place_card (задел под драг), release = выбор.
	if event.is_action_pressed(&"place_card"):
		EventBus.input_place_card.emit(_event_position(event))
	elif event.is_action_released(&"confirm"):
		if event is InputEventMouse:
			EventBus.input_pointer_released.emit((event as InputEventMouse).position)
		else:
			EventBus.input_confirmed.emit(&"cursor")
	elif event.is_action_pressed(&"cancel"):
		EventBus.input_cancelled.emit()
	elif event.is_action_pressed(&"active_ability"):
		EventBus.input_active_ability.emit()
	else:
		return
	get_viewport().set_input_as_handled()


# Позиция нажатия есть только у мыши; у геймпада курсор виртуальный (задача 3).
func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return Vector2.ZERO
