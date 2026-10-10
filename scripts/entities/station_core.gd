class_name StationCore extends Node2D
## Ядро станции: HP из RunConfig. Регистрируется на сетке — клетка
## недоступна картам. При 0 HP → core_destroyed (машина фаз → поражение).

@export var grid: GridManager
@export var layout: GridLayout
@export var config: RunConfig

var hp: int = 0
var max_hp: int = 0


func _ready() -> void:
	add_to_group(&"station_core")
	max_hp = config.core_hp
	hp = max_hp
	position = layout.cell_rect(layout.core_cell).get_center()
	grid.place(layout.core_cell, self)
	EventBus.core_hp_changed.emit(hp, max_hp)
	EventBus.run_start_requested.connect(_on_run_start)


# Новый забег — Ядро восстанавливается.
func _on_run_start() -> void:
	hp = max_hp
	EventBus.core_hp_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	EventBus.core_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		EventBus.core_destroyed.emit()
