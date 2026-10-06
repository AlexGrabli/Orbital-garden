extends Node2D
## Главная сцена. Кнопка «Начать забег» — временная заглушка до HUD (задача 8).

@onready var _start_button: Button = $StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	EventBus.input_confirmed.connect(_on_input_confirmed)


func _on_start_pressed() -> void:
	EventBus.run_start_requested.emit()
	_start_button.hide()


# Паритет для геймпада/тача: confirm стартует забег, пока кнопка видна.
func _on_input_confirmed() -> void:
	if _start_button.visible:
		_on_start_pressed()
