class_name StationCore extends Node2D
## Ядро станции: HP из RunConfig. Регистрируется на сетке — клетка
## недоступна картам. При 0 HP → core_destroyed (машина фаз → поражение).

@export var grid_path: NodePath  # Node-экспорты ручных .tscn не резолвятся — путь + get_node
@export var layout: GridLayout
@export var config: RunConfig

var grid: GridManager = null

var hp: int = 0
var max_hp: int = 0


func _ready() -> void:
	add_to_group(&"station_core")
	if grid_path != NodePath(""):
		grid = get_node(grid_path) as GridManager
	max_hp = config.core_hp
	hp = max_hp
	position = layout.cell_rect(layout.core_cell).get_center()
	# Регистрация отложена: клетка должна быть свободна после всех _ready.
	call_deferred("_register_on_grid")
	EventBus.core_hp_changed.emit(hp, max_hp)
	EventBus.run_start_requested.connect(_on_run_start)


func _register_on_grid() -> void:
	grid.place(layout.core_cell, self)


# Новый забег — Ядро восстанавливается.
func _on_run_start() -> void:
	hp = max_hp
	EventBus.core_hp_changed.emit(hp, max_hp)


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	EventBus.core_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		EventBus.core_destroyed.emit()
