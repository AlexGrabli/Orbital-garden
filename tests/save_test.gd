extends SceneTree
## Тест SaveSystem: roundtrip чекпоинта, save_version, битый файл (бэкап),
## миграция, атомарность записи, wipe_run с мета-биомассой.
## Запуск: godot --headless -s res://tests/save_test.gd

const TEST_PATH := "user://test_save.json"

var _failures: int = 0
var _bus: Node
var _runstate: Node
var _save: Node
var _layout: Resource
var _config: Resource
var _registry: Resource


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("SAVE_FAIL: " + message)


func _next_buildable(grid: Node, skip: Array) -> Vector2i:
	for y in _layout.grid_size.y:
		for x in _layout.grid_size.x:
			var cell := Vector2i(x, y)
			if grid.is_buildable(cell) and not skip.has(cell):
				return cell
	return Vector2i(-1, -1)


func _place_card(grid: Node, card: Resource, cell: Vector2i) -> Node:
	var scene: PackedScene = load("res://scenes/entities/card_entity.tscn")
	var e: Node = scene.instantiate()
	e.setup(card)
	root.add_child(e)
	e.position = _layout.cell_rect(cell).get_center()
	grid.place(cell, e)
	return e


# Мир забега: grid + economy + deck + controller + core (без машины фаз).
func _build_world() -> Dictionary:
	var grid: Node = load("res://scripts/systems/grid_manager.gd").new()
	grid.layout = _layout
	root.add_child(grid)
	var economy: Node = load("res://scripts/systems/economy_manager.gd").new()
	economy.config = _config
	root.add_child(economy)
	var deck: Node = load("res://scripts/systems/deck_manager.gd").new()
	deck.registry = _registry
	deck.config = _config
	root.add_child(deck)
	var controller: Node = load("res://scripts/systems/play_controller.gd").new()
	controller.grid = grid
	controller.deck = deck
	controller.economy = economy
	controller.config = _config
	root.add_child(controller)
	var core: Node = load("res://scripts/entities/station_core.gd").new()
	core.grid = grid
	core.layout = _layout
	core.config = _config
	root.add_child(core)
	return {"grid": grid, "economy": economy, "deck": deck, "controller": controller, "core": core}


func _free_world(world: Dictionary) -> void:
	for key: String in world:
		(world[key] as Node).queue_free()
	await process_frame
	await process_frame


func _cleanup_files() -> void:
	for f: String in ["test_save.json", "test_save.json.tmp"]:
		if FileAccess.file_exists("user://" + f):
			DirAccess.remove_absolute("user://" + f)
	var dir := DirAccess.open("user://")
	for f: String in dir.get_files():
		if f.begins_with("save_corrupt_"):
			DirAccess.remove_absolute("user://" + f)


func _run() -> void:
	_bus = root.get_node("EventBus")
	_runstate = root.get_node("RunState")
	_save = root.get_node("SaveSystem")
	_layout = load("res://resources/grid_layout_default.tres")
	_config = load("res://resources/run_config_default.tres")
	_registry = load("res://resources/cards/card_registry.tres")
	_save.save_path = TEST_PATH
	_cleanup_files()

	# --- Roundtrip: состояние → save → снос → load → совпадение. ---------
	var world := _build_world()
	var grid: Node = world["grid"]
	var economy: Node = world["economy"]
	var deck: Node = world["deck"]
	var core: Node = world["core"]
	_bus.emit_signal("run_start_requested")
	await process_frame

	# Два дня состояния: день 3, ресурсы, колода/рука, 2 карты (одна подбита),
	# HP Ядра снижено.
	_runstate.day_number = 3
	economy.energy = 7
	economy.water = 2
	economy.biomass = 4
	economy._emit()
	deck.hand.clear()
	deck.hand.append(_registry.find(&"wall_barrier"))
	deck.add_to_deck(_registry.find(&"cactus_battery"))
	var cell_a: Vector2i = _next_buildable(grid, [])
	var cell_b: Vector2i = _next_buildable(grid, [cell_a])
	var entity_a := _place_card(grid, _registry.find(&"solar_panel"), cell_a)
	var entity_b := _place_card(grid, _registry.find(&"turret_laser"), cell_b)
	entity_b.current_hp = 17
	entity_b.charge = 5.0
	core.take_damage(3)
	await process_frame

	_save.save_game()
	_check(FileAccess.file_exists(TEST_PATH), "файл сейва не создан")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(typeof(parsed) == TYPE_DICTIONARY, "сейв не парсится как JSON")
	var file_data: Dictionary = parsed
	_check(int(file_data.get("save_version", -1)) == 1, "save_version != 1")
	_check(file_data.get("run") != null, "run == null в свежем сейве")
	var file_grid: Array = file_data["run"]["snapshot"]["grid"]
	_check(file_grid.size() == 2, "в сейве карт != 2: %d" % [file_grid.size()])

	# Атомарность: осиротевшего .tmp нет.
	_check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "осиротевший .tmp после записи")

	# Снос мира, пересбор, штатный старт, применение сейва.
	var saved_run: Dictionary = file_data["run"]
	await _free_world(world)
	world = _build_world()
	grid = world["grid"]
	economy = world["economy"]
	deck = world["deck"]
	core = world["core"]
	_bus.emit_signal("run_start_requested")
	await process_frame
	await process_frame

	var ok: bool = _save.load_game()
	_check(ok, "load_game вернул false")
	await process_frame
	_check(_runstate.day_number == 3, "день не восстановлен: %d" % [_runstate.day_number])
	_check(economy.energy == 7 and economy.water == 2 and economy.biomass == 4,
		"ресурсы не восстановлены: %d/%d/%d" % [economy.energy, economy.water, economy.biomass])
	_check(deck.hand.size() == 1 and deck.hand[0].id == &"wall_barrier",
		"рука не восстановлена: %s" % [deck.hand])
	var has_cactus := false
	for card: Resource in deck.deck:
		if card.id == &"cactus_battery":
			has_cactus = true
	_check(deck.deck.size() == 7 and has_cactus,
		"колода не восстановлена: %d карт" % [deck.deck.size()])
	var restored_a := grid.occupant_at(cell_a) as Node
	var restored_b := grid.occupant_at(cell_b) as Node
	_check(restored_a != null and restored_a.card.id == &"solar_panel",
		"карта A не восстановлена в %s" % [cell_a])
	_check(restored_b != null and restored_b.card.id == &"turret_laser"
		and restored_b.current_hp == 17 and restored_b.charge == 5.0,
		"карта B не восстановлена с hp/charge")
	_check(core.hp == 17, "HP Ядра не восстановлено: %d" % [core.hp])

	# --- wipe_run: run == null, биомасса забега → мета. -------------------
	economy.biomass = 4
	_save.save_game()
	_bus.emit_signal("run_ended", false, 3)
	await process_frame
	var after_wipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(after_wipe.get("run") == null, "run не стёрт после run_ended")
	_check(int(after_wipe["meta"]["biomass"]) == 4,
		"мета-биомасса не увеличена: %s" % [after_wipe["meta"]])
	_check(economy.biomass == 0, "забеговая биомасса не обнулена")
	_check(not _save.has_run(), "has_run true после wipe")

	# --- Битый файл: false, краша нет, создан бэкап. ----------------------
	_cleanup_files()
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ это не json")
	f.close()
	var broken_ok: bool = _save.load_game()
	_check(not broken_ok, "load_game на мусоре вернул true")
	var dir_backup := DirAccess.open("user://")
	var backed_up := false
	for fname: String in dir_backup.get_files():
		if fname.begins_with("save_corrupt_"):
			backed_up = true
	_check(backed_up, "бэкап битого сейва не создан")
	_cleanup_files()

	# --- Миграция: save_version 0 → 1. ------------------------------------
	var legacy := {"save_version": 0, "run": null}
	f = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	var migrated_ok: bool = _save.load_game()
	_check(migrated_ok, "миграция 0→1 не прошла")
	# Миграция — в памяти; файл перезаписывается следующим сохранением.
	_save.save_game()
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(int(migrated.get("save_version", -1)) == 1, "после миграции version != 1")
	_check(migrated.has("meta"), "после миграции нет meta")

	# Финальная уборка: файлов теста и бэкапов быть не должно.
	_cleanup_files()
	var dir := DirAccess.open("user://")
	var leftovers: Array = []
	for fname: String in dir.get_files():
		if fname.begins_with("test_save") or fname.begins_with("save_corrupt_"):
			leftovers.append(fname)
	_check(leftovers.is_empty(), "остались файлы сейва: %s" % [leftovers])
	_save.save_path = _save.SAVE_PATH
	await _free_world(world)

	if _failures == 0:
		print("SAVE_TEST_OK")
		quit(0)
	else:
		printerr("SAVE_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
