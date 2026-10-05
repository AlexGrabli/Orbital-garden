extends Node2D
## Главная сцена. Кнопка «Начать забег» — временная заглушка до HUD (задача 8).

@onready var _start_button: Button = $StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	EventBus.run_start_requested.emit()
	_start_button.hide()
