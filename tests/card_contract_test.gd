extends SceneTree
## Машинный контракт карт (docs/02 §8.3): двойное назначение, ≤2 ресурсов,
## теги, закрытый список типов эффектов, стартовая колода.
## Запуск: godot --headless -s res://tests/card_contract_test.gd

const ALLOWED_EFFECTS: Array[StringName] = [
	&"generate", &"heal", &"damage", &"slow", &"stun", &"shield", &"taunt",
	&"spawn", &"reveal", &"buff", &"convert", &"summon_active",
]
const ALLOWED_PROPERTIES: Array[StringName] = [&"none", &"free_move"]
const STARTER_IDS: Array[StringName] = [
	&"turret_laser", &"wall_barrier", &"solar_panel",
	&"moisture_condenser", &"cactus_battery", &"chicken_incubator",
]

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("CONTRACT_FAIL: " + message)


func _check_effect(effect: Resource, card_id: StringName, phase: String) -> void:
	_check(effect.type in ALLOWED_EFFECTS,
		"%s: тип %s-эффекта '%s' вне закрытого списка" % [card_id, phase, effect.type])


func _run() -> void:
	var registry: Resource = load("res://resources/cards/card_registry.tres")
	_check(registry != null, "реестр card_registry.tres не загрузился")
	if registry == null:
		_finish()

	var seen: Dictionary = {}
	for card: Resource in registry.cards:
		var id: StringName = card.id
		_check(not seen.has(id), "дубль id карты: %s" % [id])
		seen[id] = true
		_check(card.resource_path.get_file().get_basename() == String(id),
			"%s: id не совпадает с именем файла (%s)" % [id, card.resource_path])
		_check(card.name != "" and card.flavor_text != "",
			"%s: пустые name/flavor_text" % [id])
		_check(not card.tags.is_empty(), "%s: нет тегов" % [id])

		# ≤2 ресурса на карту (нулевые стоимости не считаются).
		var resources := int(card.cost_water > 0) + int(card.cost_energy > 0)
		_check(resources <= 2, "%s: больше 2 ресурсов (В%d Э%d)" % [id, card.cost_water, card.cost_energy])

		# Двойное назначение: днём — эффект или свойство; ночью — эффект.
		_check(card.day_effect != null or card.day_property != &"none",
			"%s: нет дневной функции" % [id])
		if id in STARTER_IDS:
			_check(card.night_effect != null, "%s стартовой колоды: нет ночной функции" % [id])
		_check(ALLOWED_PROPERTIES.has(card.day_property),
			"%s: day_property '%s' не из {none, free_move}" % [id, card.day_property])

		if card.day_effect != null:
			_check_effect(card.day_effect, id, "дневного")
		if card.night_effect != null:
			_check_effect(card.night_effect, id, "ночного")

	# Стартовая колода: ровно 6 id из docs/02 §7, все COMMON и найдены.
	_check(registry.starter_deck_ids == STARTER_IDS,
		"starter_deck_ids != ростеру docs/02 §7: %s" % [registry.starter_deck_ids])
	for id: StringName in STARTER_IDS:
		var card: Resource = registry.find(id)
		_check(card != null, "карта стартовой колоды не в реестре: %s" % [id])
		if card != null:
			_check(card.rarity == 0, "%s: стартовая карта не COMMON" % [id])
	_check(registry.starter_deck().size() == 6,
		"стартовая колода != 6 карт: %d" % [registry.starter_deck().size()])

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("CARD_CONTRACT_OK")
		quit(0)
	else:
		printerr("CARD_CONTRACT_FAIL: ошибок %d" % _failures)
		quit(1)
