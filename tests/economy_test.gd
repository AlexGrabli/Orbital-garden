extends SceneTree
## Тест экономики дня: стартовые запасы, утренний сбор (generate/convert),
## оплата размещения, перемещение (в т.ч. free_move), ставка заката, рассвет.
## Запуск: godot --headless -s res://tests/economy_test.gd

var _failures: int = 0
var _bus: Node
var _grid: Node  # GridManager
var _deck: Node  # DeckManager
var _economy: Node  # EconomyManager
var _config: Resource  # RunConfig
var _registry: Resource  # CardRegistry

var _last_resources: Array = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("ECONOMY_FAIL: " + message)


# Первая buildable-клетка, не входящая в skip.
func _next_buildable(skip: Array) -> Vector2i:
	for y in _grid.layout.grid_size.y:
		for x in _grid.layout.grid_size.x:
			var cell := Vector2i(x, y)
			if _grid.is_buildable(cell) and not skip.has(cell):
				return cell
	return Vector2i(-1, -1)


# Разместить сущность карты напрямую (мимо оплаты и руки).
func _place_entity(card: Resource, cell: Vector2i) -> Node:
	var entity: Node = load("res://scripts/entities/card_entity.gd").new()
	entity.setup(card)
	root.add_child(entity)
	_grid.place(cell, entity)
	return entity


func _run() -> void:
	_bus = root.get_node("EventBus")
	_config = load("res://resources/run_config_default.tres")
	_registry = load("res://resources/cards/card_registry.tres")

	_grid = load("res://scripts/systems/grid_manager.gd").new()
	_grid.layout = load("res://resources/grid_layout_default.tres")
	root.add_child(_grid)

	_deck = load("res://scripts/systems/deck_manager.gd").new()
	_deck.registry = _registry
	_deck.config = _config
	root.add_child(_deck)

	_economy = load("res://scripts/systems/economy_manager.gd").new()
	_economy.config = _config
	root.add_child(_economy)

	var day_fx: Node = load("res://scripts/systems/day_effects.gd").new()
	day_fx.economy = _economy
	root.add_child(day_fx)

	var controller: Node = load("res://scripts/systems/play_controller.gd").new()
	controller.grid = _grid
	controller.deck = _deck
	controller.economy = _economy
	controller.config = _config
	root.add_child(controller)
	await process_frame

	_bus.connect("resources_changed",
		func(e: int, w: int, b: int) -> void: _last_resources = [e, w, b])
	var denied_log: Array = []
	_bus.connect("placement_denied",
		func(reason: StringName) -> void: denied_log.append(reason))
	var entity_selected_log: Array = []
	_bus.connect("card_entity_selected",
		func(entity: Node) -> void: entity_selected_log.append(entity))

	# 1. Старт забега: запасы из RunConfig.
	_bus.emit_signal("run_start_requested")
	await process_frame
	_check(_last_resources == [_config.start_energy, _config.start_water, _config.start_biomass],
		"стартовые запасы неверны: %s" % [_last_resources])

	# 2. Утренний сбор: solar_panel → энергия, condenser → вода (числа из .tres).
	var solar: Resource = _registry.find(&"solar_panel")
	var condenser: Resource = _registry.find(&"moisture_condenser")
	var cell_s: Vector2i = _next_buildable([])
	var cell_c: Vector2i = _next_buildable([cell_s])
	_place_entity(solar, cell_s)
	_place_entity(condenser, cell_c)
	_bus.emit_signal("day_started", 1)
	await process_frame
	var expected_energy: int = _config.start_energy + int(solar.day_effect.value)
	var expected_water: int = _config.start_water + int(condenser.day_effect.value)
	_check(_last_resources[0] == expected_energy and _last_resources[1] == expected_water,
		"утренний сбор неверен: %s (ожидалось Э%d В%d)" % [_last_resources, expected_energy, expected_water])

	# Убираем генераторы — дальше чистые проверки convert.
	var solar_entity: Node = _grid.remove(cell_s)
	solar_entity.queue_free()
	var condenser_entity: Node = _grid.remove(cell_c)
	condenser_entity.queue_free()
	await process_frame

	# 3. Турель утром: convert энергия→charge, потолок = value из данных.
	var turret: Resource = _registry.find(&"turret_laser")
	var cell_t: Vector2i = _next_buildable([])
	var turret_entity: Node = _place_entity(turret, cell_t)
	_economy.energy = 10
	_economy._emit()
	_bus.emit_signal("day_started", 2)
	await process_frame
	_check(int(turret_entity.charge) == mini(int(turret.day_effect.value), 10),
		"charge турели неверен: %s" % [turret_entity.charge])
	_check(_last_resources[0] == 10 - int(turret_entity.charge),
		"энергия после convert неверна: %s" % [_last_resources[0]])

	# 4. Не хватает ресурсов: pay → false, размещение отклонено, карта в руке.
	_deck.hand.clear()
	_deck.add_to_deck(turret)
	_deck.hand.append(turret)  # рука без добора
	_economy.water = 0
	_economy.energy = 0
	_economy._emit()
	var denied_card: Resource = _deck.hand[0]
	var cell_denied: Vector2i = _next_buildable([cell_t])
	_bus.emit_signal("hand_card_selected", denied_card)
	_bus.emit_signal("grid_cell_confirmed", cell_denied)
	await process_frame
	_check(denied_log == [&"not_enough_resources"], "placement_denied не эмитнут: %s" % [denied_log])
	_check(_deck.hand.has(denied_card), "карта пропала из руки при отказе")
	_check(_grid.occupant_at(cell_denied) == null, "клетка занята при отказе")

	# Отмена выбора карты — дальше перемещение размещённых карт.
	_bus.emit_signal("input_cancelled")
	await process_frame

	# 5. Перемещение: стена (free_move) — бесплатно; турель — move_cost_energy.
	var wall: Resource = _registry.find(&"wall_barrier")
	var cell_w: Vector2i = _next_buildable([cell_t])
	var wall_entity: Node = _place_entity(wall, cell_w)
	_economy.energy = 5
	_economy._emit()
	var energy_before: int = _economy.energy

	_bus.emit_signal("grid_cell_confirmed", cell_w)  # выбрать стену
	await process_frame
	_check(entity_selected_log == [wall_entity], "стена не выбрана: %s" % [entity_selected_log])
	var cell_w2: Vector2i = _next_buildable([cell_t, cell_w])
	_bus.emit_signal("grid_cell_confirmed", cell_w2)  # переместить
	await process_frame
	_check(_economy.energy == energy_before, "free_move списал энергию: %d -> %d" % [energy_before, _economy.energy])
	_check(_grid.occupant_at(cell_w2) == wall_entity, "стена не переехала")
	_check(_grid.occupant_at(cell_w) == null, "исходная клетка стены не пуста")

	energy_before = _economy.energy
	_bus.emit_signal("grid_cell_confirmed", cell_t)  # выбрать турель
	_bus.emit_signal("grid_cell_confirmed", cell_w)  # переместить на освободившуюся
	await process_frame
	_check(_economy.energy == energy_before - _config.move_cost_energy,
		"перемещение турели стоит не move_cost_energy: %d -> %d" % [energy_before, _economy.energy])
	_check(_grid.occupant_at(cell_w) == turret_entity, "турель не переехала")

	# 6. Ставка заката: РОСТ — ремонт до потолка, вода → 0.
	_bus.emit_signal("sunset_started", 1)
	await process_frame
	turret_entity.current_hp = 1
	_economy.water = 3
	_economy._emit()
	_bus.emit_signal("sunset_bet_made", &"growth", 3)
	await process_frame
	var expected_hp: int = mini(1 + 3 * _config.sunset_heal_per_water, turret.hp)
	_check(turret_entity.current_hp == expected_hp,
		"РОСТ: HP %d, ожидалось %d" % [turret_entity.current_hp, expected_hp])
	_check(_economy.water == 0, "вода после ставки != 0: %d" % [_economy.water])
	_check(wall_entity.current_hp == wall.hp, "РОСТ пробил потолок HP стены")

	# Ставка БОЕПРИПАСЫ: заряды damage-картам, вода → 0.
	_bus.emit_signal("sunset_started", 2)
	await process_frame
	var charge_before: float = turret_entity.charge
	_economy.water = 2
	_economy._emit()
	_bus.emit_signal("sunset_bet_made", &"ammo", 2)
	await process_frame
	_check(turret_entity.charge == charge_before + 2 * _config.sunset_ammo_per_water,
		"БОЕПРИПАСЫ: charge %s, было %s" % [turret_entity.charge, charge_before])
	_check(_economy.water == 0, "вода после боеприпасов != 0")

	# AFK: без выбора дефолт — РОСТ.
	_bus.emit_signal("sunset_started", 3)
	await process_frame
	turret_entity.current_hp = 2
	_economy.water = 1
	_economy._emit()
	_bus.emit_signal("night_started", 1)
	await process_frame
	_check(turret_entity.current_hp == mini(2 + _config.sunset_heal_per_water, turret.hp),
		"AFK-ставка не применила РОСТ: HP %d" % [turret_entity.current_hp])
	_check(_economy.water == 0, "вода после AFK-ставки != 0")

	# 7. Рассвет: биомасса + награда.
	var biomass_before: int = _economy.biomass
	_bus.emit_signal("dawn_started", 2)
	await process_frame
	_check(_economy.biomass == biomass_before + _config.dawn_biomass_reward,
		"награда рассвета не начислена: %d" % [_economy.biomass])

	if _failures == 0:
		print("ECONOMY_TEST_OK")
		quit(0)
	else:
		printerr("ECONOMY_TEST_FAIL: ошибок %d" % _failures)
		quit(1)
