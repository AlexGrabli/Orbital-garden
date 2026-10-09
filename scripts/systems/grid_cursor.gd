class_name GridCursor extends Node2D
## Виртуальный курсор (геймпад/клавиатура): ячейка, подтверждение, подсветка соседей.
## TODO(задача 4): confirm от мыши (release ЛКМ) дойдёт сюда — развести по контексту.

@export var layout: GridLayout

var cell: Vector2i = Vector2i.ZERO

var _cursor_rect: ColorRect
var _neighbor_rects: Array[ColorRect] = []


func _ready() -> void:
	cell = Vector2i(layout.grid_size.x / 2, layout.grid_size.y / 2)  # старт — центр сетки
	_build_visuals()
	_refresh()
	EventBus.input_cursor_moved.connect(_on_cursor_moved)
	EventBus.input_confirmed.connect(_on_confirmed)
	EventBus.input_cancelled.connect(_on_cancelled)


func _on_cursor_moved(dir: Vector2i) -> void:
	var next := Vector2i(
		clampi(cell.x + dir.x, 0, layout.grid_size.x - 1),
		clampi(cell.y + dir.y, 0, layout.grid_size.y - 1))
	if next != cell:
		cell = next
		_refresh()


func _on_confirmed() -> void:
	EventBus.grid_cell_confirmed.emit(cell)


func _on_cancelled() -> void:
	EventBus.grid_selection_cancelled.emit()


func _build_visuals() -> void:
	position = layout.origin
	_cursor_rect = ColorRect.new()
	_cursor_rect.size = Vector2(layout.cell_size, layout.cell_size)
	_cursor_rect.color = Color(1.0, 0.85, 0.2, 0.35)
	add_child(_cursor_rect)
	for i in 4:
		var rect := ColorRect.new()
		rect.size = _cursor_rect.size
		rect.color = Color(0.3, 0.9, 0.4, 0.25)  # подсветка соседства (синергии)
		rect.visible = false
		add_child(rect)
		_neighbor_rects.append(rect)


func _refresh() -> void:
	_cursor_rect.position = Vector2(cell) * layout.cell_size
	var neighbors := layout.neighbors4(cell)
	for i in _neighbor_rects.size():
		var rect := _neighbor_rects[i]
		rect.visible = i < neighbors.size()
		if rect.visible:
			rect.position = Vector2(neighbors[i]) * layout.cell_size
