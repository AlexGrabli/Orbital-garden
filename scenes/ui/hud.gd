extends CanvasLayer
## Единый слой HUD: день/фаза, прогноз атаки, HP Ядра, пауза.
## Чистый подписчик EventBus; единственное исключение — get_tree().paused
## (Godot-механизм паузы). Полоса ресурсов подписывается сама.

@export var config: RunConfig
@export var schedule: WaveSchedule

# Направления волны → родительный падеж для прогноза.
const _DIRECTIONS: Dictionary = {
	WaveScenario.Direction.EAST: &"востока",
	WaveScenario.Direction.WEST: &"запада",
	WaveScenario.Direction.NORTH: &"севера",
	WaveScenario.Direction.SOUTH: &"юга",
}

@onready var _safe: MarginContainer = $SafeMargins
@onready var _day_label: Label = $SafeMargins/Layout/TopBar/DayLabel
@onready var _phase_label: Label = $SafeMargins/Layout/TopBar/PhaseLabel
@onready var _forecast_label: Label = $SafeMargins/Layout/TopBar/ForecastLabel
@onready var _core_label: Label = $SafeMargins/Layout/TopBar/CoreLabel
@onready var _start_button: Button = $SafeMargins/Layout/TopBar/StartButton
@onready var _continue_button: Button = $SafeMargins/Layout/TopBar/ContinueButton
@onready var _end_day_button: Button = $SafeMargins/Layout/TopBar/EndDayButton
@onready var _pause_button: Button = $SafeMargins/Layout/TopBar/PauseButton
@onready var _overlay: CenterContainer = $PauseOverlay
@onready var _overlay_title: Label = $PauseOverlay/Panel/Box/Title
@onready var _resume_button: Button = $PauseOverlay/Panel/Box/ResumeButton


func _ready() -> void:
	_apply_safe_area()
	EventBus.core_hp_changed.connect(_on_core_hp_changed)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.run_ended.connect(_on_run_ended)
	_start_button.pressed.connect(func() -> void: EventBus.run_start_requested.emit())
	_continue_button.pressed.connect(func() -> void: SaveSystem.request_continue())
	_end_day_button.pressed.connect(func() -> void: EventBus.day_completed.emit())
	_pause_button.pressed.connect(_on_pause_pressed)
	_resume_button.pressed.connect(_on_resume_pressed)
	_on_phase_changed(&"main_menu", RunState.day_number)


# Отступы из safe area (чёлки/камеры телефонов). В headless — нулевые.
# MarginContainer хранит отступы как theme-константы.
func _apply_safe_area() -> void:
	var area := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	_safe.add_theme_constant_override(&"margin_left", area.position.x)
	_safe.add_theme_constant_override(&"margin_top", area.position.y)
	_safe.add_theme_constant_override(&"margin_right", screen.x - area.end.x)
	_safe.add_theme_constant_override(&"margin_bottom", screen.y - area.end.y)


func _on_core_hp_changed(hp: int, max_hp: int) -> void:
	_core_label.text = "Ядро %d/%d" % [hp, max_hp]


func _on_phase_changed(new_phase: StringName, day_number: int) -> void:
	_day_label.text = "День %d из %d" % [day_number, config.run_days]
	_start_button.visible = new_phase == &"main_menu"
	_continue_button.visible = new_phase == &"main_menu" and SaveSystem.has_run()
	_end_day_button.visible = new_phase == &"day"
	match new_phase:
		&"day":
			_phase_label.text = "День"
			_forecast_label.show()
		&"sunset":
			_phase_label.text = "Закат"
			_forecast_label.show()
		&"night":
			_phase_label.text = "Ночь"
			_forecast_label.hide()
		&"dawn":
			_phase_label.text = "Рассвет"
			_forecast_label.hide()
		&"run_end":
			_phase_label.text = "Конец забега"
			_forecast_label.hide()
		_:
			_phase_label.text = "Меню"
			_forecast_label.hide()
	_update_forecast(day_number)


# Прогноз: направление и состав завтрашней волны (честная игра — пиллар).
# Гейт за радаром — одна строка условия в Фазе 2 (docs/01 §10).
func _update_forecast(day_number: int) -> void:
	var scenario := schedule.for_day(day_number)
	if scenario == null or not _forecast_label.visible:
		return
	var parts: Array[String] = []
	for spawn: SpawnEntry in scenario.spawns:
		parts.append("%d×%s" % [spawn.count, spawn.enemy.name])
	_forecast_label.text = "🌙 Рой придёт с %s: %s" % [
		_DIRECTIONS[scenario.direction], ", ".join(parts)]


func _on_pause_pressed() -> void:
	get_tree().paused = true
	_overlay_title.text = "Пауза"
	_resume_button.show()
	_overlay.show()
	_resume_button.call_deferred("grab_focus")


func _on_resume_pressed() -> void:
	get_tree().paused = false
	_overlay.hide()


func _on_run_ended(victory: bool, _day: int) -> void:
	get_tree().paused = false
	_overlay_title.text = "Победа" if victory else "Поражение"
	_resume_button.hide()
	_overlay.show()
