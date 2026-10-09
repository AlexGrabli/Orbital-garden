extends Node2D
## Главная сцена. Кнопка «Начать забег» — временная заглушка до HUD (задача 8).

@onready var _start_button: Button = $StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	EventBus.input_confirmed.connect(_on_menu_confirm)  # клавиатура/геймпад
	EventBus.input_tapped.connect(_on_menu_tap)  # тач


func _on_start_pressed() -> void:
	EventBus.run_start_requested.emit()
	_start_button.hide()


# Паритет для геймпада/тача: старт забега, пока кнопка видна (временно, до HUD).
func _on_menu_confirm(_source: StringName) -> void:
	_try_start()


func _on_menu_tap(_pos: Vector2) -> void:
	_try_start()


func _try_start() -> void:
	if _start_button.visible:
		_on_start_pressed()
