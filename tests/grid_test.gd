extends SceneTree
## Тест GridManager: размещение/перемещение/удаление оккупантов, соседи.
## Запуск: godot --headless -s res://tests/grid_test.gd
## Логика без сцены: раскладка из .tres, оккупанты — пустые Node.

var _failures: int = 0
var _bus: Node
var _manager: Node  # GridManager
var _layout: Resource  # GridLayout


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("GRID_FAIL: " + message)


# Первая buildable-клетка, не входящая в skip.
func _next_buildable(skip: Array) -> Vector2i:
	for y in _layout.grid_size.y:
		for x in _layout.grid_size.x:
			var cell := Vector2i(x, y)
			if _manager.is_buildable(cell) and not skip.has(cell):
				return cell
	return Vector2i(-1, -1)


func _run() -> void:
	_bus = root.get_node("EventBus")
	_layout = load("res://resources/grid_layout_default.tres")
	_manager = load("res://scripts/systems/grid_manager.gd").new()
	_manager.layout = _layout
	root.add_child(_manager)
	await process_frame

	var placed_log: Array = []
	var moved_log: Array = []
	var removed_log: Array = []
	_bus.connect("grid_occupant_placed",
		func(cell: Vector2i, occ: Node) -> void: placed_log.append([cell, occ]))
	_bus.connect("grid_occupant_moved",
		func(from: Vector2i, to: Vector2i, occ: Node) -> void: moved_log.append([from, to, occ]))
	_bus.connect("grid_occupant_removed",
		func(cell: Vector2i, occ: Node) -> void: removed_log.append([cell, occ]))

	# 1. place на NORMAL → true + сигнал; повтор на занятую → false.
	var cell_a: Vector2i = _next_buildable([])
	var occupant_a := Node.new()
	_check(_manager.place(cell_a, occupant_a), "place на NORMAL не прошёл: %s" % [cell_a])
	_check(placed_log == [[cell_a, occupant_a]],
		"grid_occupant_placed неверен: %s" % [placed_log])
	_check(_manager.occupant_at(cell_a) == occupant_a, "occupant_at не вернул оккупанта")
	_check(not _manager.is_buildable(cell_a), "занятая клетка buildable")
	_check(not _manager.place(cell_a, Node.new()), "place на занятую прошёл")

	# 2. place на ROCK/DIRT → false (клетки из .tres).
	var rock_cell: Vector2i = _layout.blocked_cells.find_key(1)  # Terrain.ROCK
	var dirt_cell: Vector2i = _layout.blocked_cells.find_key(2)  # Terrain.DIRT
	_check(not _manager.place(rock_cell, Node.new()), "place на ROCK прошёл")
	_check(not _manager.place(dirt_cell, Node.new()), "place на DIRT прошёл")

	# 3. place за пределами сетки → false.
	_check(not _manager.place(Vector2i(-1, 0), Node.new()), "place слева за сеткой")
	_check(not _manager.place(Vector2i(0, -1), Node.new()), "place сверху за сеткой")
	_check(not _manager.place(_layout.grid_size, Node.new()), "place за правым нижним углом")

	# 4. move: на занятую → false; на свободную → true, оккупант переехал.
	var cell_b: Vector2i = _next_buildable([cell_a])
	var occupant_b := Node.new()
	_check(_manager.place(cell_b, occupant_b), "place второго оккупанта не прошёл")
	_check(not _manager.move(cell_a, cell_b), "move на занятую прошёл")

	var cell_c: Vector2i = _next_buildable([cell_b])
	_check(_manager.move(cell_a, cell_c), "move на свободную не прошёл")
	_check(_manager.occupant_at(cell_a) == null, "исходная клетка не пуста после move")
	_check(_manager.occupant_at(cell_c) == occupant_a, "оккупант не переехал")
	_check(moved_log == [[cell_a, cell_c, occupant_a]],
		"grid_occupant_moved неверен: %s" % [moved_log])
	_check(not _manager.move(cell_c, rock_cell), "move на ROCK прошёл")
	_check(not _manager.move(cell_c, Vector2i(-1, 0)), "move за сетку прошёл")

	# 5. remove → возвращает оккупанта, клетка свободна; повтор → null.
	_check(_manager.remove(cell_c) == occupant_a, "remove не вернул оккупанта")
	_check(_manager.occupant_at(cell_c) == null, "клетка не пуста после remove")
	_check(_manager.is_buildable(cell_c), "клетка не buildable после remove")
	_check(_manager.remove(cell_c) == null, "remove из пустой не вернул null")
	_check(removed_log == [[cell_c, occupant_a]],
		"grid_occupant_removed неверен: %s" % [removed_log])

	# 6. neighbors4: угловая клетка → 2 соседа, центральная → 4.
	_check(_manager.neighbors4(Vector2i(0, 0)).size() == 2, "у угла не 2 соседа")
	var center := Vector2i(_layout.grid_size.x / 2 - 1, _layout.grid_size.y / 2 - 1)
	_check(_manager.neighbors4(center).size() == 4, "у центра не 4 соседа")

	if _failures == 0:
		print("GRID_TEST_OK")
		quit(0)
	else:
		printerr("GRID_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
