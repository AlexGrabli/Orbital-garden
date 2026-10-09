extends CenterContainer
## Ставка заката: РОСТ (ремонт) или БОЕПРИПАСЫ (заряды). Зеркало ввода:
## тач/мышь — тап по кнопке; геймпад — фокус на первой кнопке + confirm.

@onready var _title: Label = $Panel/Box/Title
@onready var _growth: Button = $Panel/Box/Options/Growth
@onready var _ammo: Button = $Panel/Box/Options/Ammo

var _water: int = 0


func _ready() -> void:
	hide()
	EventBus.sunset_started.connect(_on_sunset_started)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.sunset_bet_made.connect(func(_mode: StringName, _spent: int) -> void: hide())
	_growth.pressed.connect(func() -> void: EventBus.sunset_bet_made.emit(&"growth", _water))
	_ammo.pressed.connect(func() -> void: EventBus.sunset_bet_made.emit(&"ammo", _water))


func _on_sunset_started(_day: int) -> void:
	_title.text = "Ставка заката — вода: %d" % [_water]
	show()
	_growth.call_deferred("grab_focus")


func _on_resources_changed(_e: int, water: int, _b: int) -> void:
	_water = water
