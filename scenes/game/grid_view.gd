extends Node2D
## Визуал сетки (плейсхолдеры-ColorRect) и маппинг указателя в клетки.
## Позиции уже в canvas-координатах (нюанс stretch — см. AGENTS.md).

@export var layout: GridLayout


func _ready() -> void:
	_build_cells()
	EventBus.input_place_card.connect(_on_pointer)  # ЛКМ/драг (press)
	EventBus.input_tapped.connect(_on_pointer)  # тач-тап


# Цвета — визуал-плейсхолдер (арт появится в Фазе 3).
func _terrain_color(terrain: GridLayout.Terrain) -> Color:
	match terrain:
		GridLayout.Terrain.ROCK:
			return Color(0.3, 0.3, 0.34)
		GridLayout.Terrain.DIRT:
			return Color(0.28, 0.2, 0.12)
	return Color(0.1, 0.12, 0.18)


func _build_cells() -> void:
	for y in layout.grid_size.y:
		for x in layout.grid_size.x:
			var cell := Vector2i(x, y)
			var rect := ColorRect.new()
			rect.position = layout.origin + Vector2(cell) * layout.cell_size + Vector2.ONE
			rect.size = Vector2(layout.cell_size - 2, layout.cell_size - 2)
			rect.color = _terrain_color(layout.terrain_at(cell))
			add_child(rect)


# Клик/тап по клетке → подтверждение клетки (выбор карты — задача 4).
func _on_pointer(screen_pos: Vector2) -> void:
	var cell := layout.screen_to_cell(screen_pos)
	if layout.is_inside(cell):
		EventBus.grid_cell_confirmed.emit(cell)
