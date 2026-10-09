extends SceneTree
## Тест колоды и розыгрыша: старт, добор, лимит руки, размещение на сетку,
## отказ на неудобной клетке, драфт на рассвете.
## Запуск: godot --headless -s res://tests/deck_test.gd

var _failures: int = 0
var _bus: Node
var _grid: Node  # GridManager
var _deck: Node  # DeckManager


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("DECK_FAIL: " + message)


# Первая buildable-клетка, не входящая в skip.
func _next_buildable(skip: Array) -> Vector2i:
	for y in _grid.layout.grid_size.y:
		for x in _grid.layout.grid_size.x:
			var cell := Vector2i(x, y)
			if _grid.is_buildable(cell) and not skip.has(cell):
				return cell
	return Vector2i(-1, -1)


func _run() -> void:
	_bus = root.get_node("EventBus")

	_grid = load("res://scripts/systems/grid_manager.gd").new()
	_grid.layout = load("res://resources/grid_layout_default.tres")
	root.add_child(_grid)

	_deck = load("res://scripts/systems/deck_manager.gd").new()
	_deck.registry = load("res://resources/cards/card_registry.tres")
	# Добор заведомо больше лимита — для проверки hand_limit.
	_deck.config = load("res://resources/run_config_default.tres").duplicate()
	_deck.config.hand_draw_size = 10
	root.add_child(_deck)

	var controller: Node = load("res://scripts/systems/play_controller.gd").new()
	controller.grid = _grid
	controller.deck = _deck
	var economy: Node = load("res://scripts/systems/economy_manager.gd").new()
	economy.config = _deck.config
	root.add_child(economy)
	controller.economy = economy
	controller.config = _deck.config
	root.add_child(controller)
	await process_frame

	var played_log: Array = []
	var offered_log: Array = []
	_bus.connect("card_played",
		func(card: Resource, cell: Vector2i) -> void: played_log.append([card, cell]))
	_bus.connect("draft_offered",
		func(options: Array) -> void: offered_log.append(options))

	# 1. Старт забега: колода 6 стартовых карт (перемешана).
	_bus.emit_signal("run_start_requested")
	await process_frame
	_check(_deck.deck.size() == 6, "колода после старта != 6: %d" % [_deck.deck.size()])
	var starter_set: Dictionary = {}
	for card: Resource in _deck.deck:
		starter_set[card.id] = true
	var expected_set: Dictionary = {}
	for id: StringName in [&"turret_laser", &"wall_barrier", &"solar_panel",
			&"moisture_condenser", &"cactus_battery", &"chicken_incubator"]:
		expected_set[id] = true
	_check(starter_set == expected_set,
		"колода не из стартовых карт: %s" % [starter_set.keys()])
	_check(_deck.hand.is_empty(), "рука не пуста на старте")

	# 2. Утро: добор ровно до hand_draw_size (3).
	_deck.config.hand_draw_size = 3
	_bus.emit_signal("day_started", 1)
	await process_frame
	_check(_deck.hand.size() == 3, "рука после утра != 3: %d" % [_deck.hand.size()])
	_check(_deck.deck.size() == 3, "колода после добора != 3: %d" % [_deck.deck.size()])

	# 3. Розыгрыш: выбор карты + клетка → card_played, клетка занята, рука меньше.
	var card_a: Resource = _deck.hand[0]
	var cell_a: Vector2i = _next_buildable([])
	_bus.emit_signal("hand_card_selected", card_a)
	_bus.emit_signal("grid_cell_confirmed", cell_a)
	await process_frame
	_check(_deck.hand.size() == 2, "рука после розыгрыша != 2: %d" % [_deck.hand.size()])
	_check(played_log == [[card_a, cell_a]], "card_played неверен: %s" % [played_log])
	var entity: Node = _grid.occupant_at(cell_a)
	_check(entity != null and entity.card == card_a, "клетка не занята CardEntity")
	_check(entity != null and entity.current_hp == card_a.hp, "HP сущности != HP карты")

	# 4. Отказ на ROCK: карта остаётся в руке, клетка пуста.
	var card_b: Resource = _deck.hand[0]
	var rock_cell: Vector2i = _grid.layout.blocked_cells.find_key(1)
	_bus.emit_signal("hand_card_selected", card_b)
	_bus.emit_signal("grid_cell_confirmed", rock_cell)
	await process_frame
	_check(_deck.hand.has(card_b), "карта пропала из руки при отказе")
	_check(_grid.occupant_at(rock_cell) == null, "ROCK занят после отказа")
	_check(played_log.size() == 1, "card_played эмитнут при отказе")

	# 5. Лимит руки: 10 карт в колоде, добор не выше hand_limit (5).
	_deck.hand.clear()
	var registry: Resource = _deck.registry
	for i in 10:
		_deck.add_to_deck(registry.find(&"solar_panel"))
	_deck.config.hand_draw_size = 10
	_deck.draw_morning()
	await process_frame
	_check(_deck.hand.size() == 5, "лимит руки 5 нарушен: %d" % [_deck.hand.size()])

	# 6. Драфт: рассвет → 3 опции; выбор → карта в колоде.
	var deck_before: int = _deck.deck.size()
	_bus.emit_signal("dawn_started", 1)
	await process_frame
	_check(offered_log.size() == 1 and offered_log[0].size() == 3,
		"draft_offered не с 3 картами: %s" % [offered_log])
	var picked: Resource = offered_log[0][0]
	_bus.emit_signal("draft_picked", picked)
	await process_frame
	_check(_deck.deck.size() == deck_before + 1,
		"драфт не попал в колоду: %d -> %d" % [deck_before, _deck.deck.size()])
	_check(_deck.deck.has(picked), "выбранной карты нет в колоде")

	# 7. Геймпад-выбор карты: hand_index_selected → hand_card_selected.
	var index_log: Array = []
	_bus.connect("hand_card_selected", func(card: Resource) -> void: index_log.append(card))
	_bus.emit_signal("hand_index_selected", 2)
	await process_frame
	_check(index_log == [_deck.hand[2]],
		"hand_index_selected не дал hand_card_selected: %s" % [index_log])

	if _failures == 0:
		print("DECK_TEST_OK")
		quit(0)
	else:
		printerr("DECK_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
