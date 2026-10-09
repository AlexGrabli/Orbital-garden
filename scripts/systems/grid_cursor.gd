class_name GridCursor extends Node2D
## Виртуальный курсор (геймпад/клавиатура). Две зоны:
## сетка (y < grid_size.y) и строка руки (y == grid_size.y, x — индекс карты).

@export var layout: GridLayout

var cell: Vector2i = Vector2i.ZERO

var _hand_size: int = 0
var _cursor_rect: ColorRect
var _neighbor_rects: Array[ColorRect] = []


func _ready() -> void:
	cell = Vector2i(layout.grid_size.x / 2, layout.grid_size.y / 2)  # старт — центр сетки
	_build_visuals()
	_refresh()
	EventBus.input_cursor_moved.connect(_on_cursor_moved)
	EventBus.input_confirmed.connect(_on_confirmed)
	EventBus.input_cancelled.connect(_on_cancelled)
	EventBus.hand_changed.connect(_on_hand_changed)


func _hand_row() -> int:
	return layout.grid_size.y


func _on_cursor_moved(dir: Vector2i) -> void:
	var next := cell + dir
	next.x = clampi(next.x, 0, layout.grid_size.x - 1)
	next.y = clampi(next.y, 0, _hand_row())
	if next.y == _hand_row():
		if _hand_size == 0:  # в пустую руку не уходим
			next.y = layout.grid_size.y - 1
		else:
			next.x = clampi(next.x, 0, _hand_size - 1)
	if next != cell:
		cell = next
		_refresh()


func _on_confirmed(source: StringName) -> void:
	if source != &"cursor":  # указатель выбирает через input_tapped/pointer_released
		return
	if cell.y == _hand_row():
		EventBus.hand_index_selected.emit(cell.x)
	else:
		EventBus.grid_cell_confirmed.emit(cell)


func _on_cancelled() -> void:
	EventBus.grid_selection_cancelled.emit()


func _on_hand_changed(hand: Array) -> void:
	_hand_size = hand.size()
	if _hand_size == 0 and cell.y == _hand_row():  # рука опустела — вернуться на сетку
		cell.y = layout.grid_size.y - 1
	_refresh()


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
	var on_grid := cell.y < _hand_row()
	var neighbors: Array[Vector2i] = layout.neighbors4(cell) if on_grid else []
	for i in _neighbor_rects.size():
		var rect := _neighbor_rects[i]
		rect.visible = i < neighbors.size()
		if rect.visible:
			rect.position = Vector2(neighbors[i]) * layout.cell_size
