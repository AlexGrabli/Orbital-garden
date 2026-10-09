class_name GridManager extends Node
## Логика сетки станции: оккупанты клеток. Без визуала и ввода.
## Оккупант — произвольный Node (в задаче 4 — узел карты).

@export var layout: GridLayout

var _occupants: Dictionary = {}  # Vector2i → Node


func is_inside(cell: Vector2i) -> bool:
	return layout.is_inside(cell)


func terrain_at(cell: Vector2i) -> GridLayout.Terrain:
	return layout.terrain_at(cell)


# Внутри сетки + удобная клетка + не занята.
func is_buildable(cell: Vector2i) -> bool:
	return is_inside(cell) and terrain_at(cell) == GridLayout.Terrain.NORMAL \
		and not _occupants.has(cell)


func occupant_at(cell: Vector2i) -> Node:
	return _occupants.get(cell) as Node


func place(cell: Vector2i, occupant: Node) -> bool:
	if not is_buildable(cell):
		return false
	_occupants[cell] = occupant
	EventBus.grid_occupant_placed.emit(cell, occupant)
	return true


func move(from: Vector2i, to: Vector2i) -> bool:
	if not _occupants.has(from) or not is_buildable(to):
		return false
	var occupant: Node = _occupants[from]
	_occupants.erase(from)
	_occupants[to] = occupant
	EventBus.grid_occupant_moved.emit(from, to, occupant)
	return true


# Возвращает оккупанта (для «ремонтного дока» позже) или null.
func remove(cell: Vector2i) -> Node:
	var occupant: Node = _occupants.get(cell) as Node
	if occupant == null:
		return null
	_occupants.erase(cell)
	EventBus.grid_occupant_removed.emit(cell, occupant)
	return occupant


# 4 направления — база синергий (см. docs/01, раздел 9).
func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	return layout.neighbors4(cell)
