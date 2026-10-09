class_name GridLayout extends Resource
## Раскладка сетки станции. Числа сетки — только здесь.

enum Terrain { NORMAL, ROCK, DIRT }  # неудобные клетки: камень/грязь (Свинтус, Фаза 2)

@export var grid_size: Vector2i = Vector2i(4, 4)
@export var cell_size: int = 32
@export var origin: Vector2 = Vector2(48, 88)  # левый верх сетки на экране 640×360
@export var blocked_cells: Dictionary = {}  # Vector2i → Terrain (пусто = всё NORMAL)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func terrain_at(cell: Vector2i) -> Terrain:
	var value: int = blocked_cells.get(cell, 0)
	return [Terrain.NORMAL, Terrain.ROCK, Terrain.DIRT][clampi(value, 0, 2)]


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * cell_size, Vector2(cell_size, cell_size))


func screen_to_cell(pos: Vector2) -> Vector2i:
	var local := pos - origin
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))


# 4 направления — база синергий по соседству.
func neighbors4(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = cell + dir
		if is_inside(n):
			result.append(n)
	return result
