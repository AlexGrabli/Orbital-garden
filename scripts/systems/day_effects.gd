class_name DayEffects extends Node
## Интерпретатор дневных эффектов: утренний сбор (day_started).
## Исполняются generate и convert; прочие типы — пропуск (их время — Фаза 2).

@export var economy: EconomyManager


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)


func _on_day_started(_day: int) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"card_entities"):
		var entity := node as CardEntity
		if entity.card == null:
			continue
		_run(entity, entity.card.day_effect)


func _run(entity: CardEntity, effect: EffectData) -> void:
	if effect == null:
		return
	match effect.type:
		&"generate":
			_run_generate(entity, effect)
		&"convert":
			_run_convert(entity, effect)
		_:
			push_warning("DayEffects: тип '%s' днём не исполняется (Фаза 2)" % [effect.type])


# generate: ресурс забега — в экономику; mode=store или расходник (яйца) — в запас сущности.
func _run_generate(entity: CardEntity, effect: EffectData) -> void:
	var resource: StringName = effect.conditions.get(&"resource", &"")
	if effect.conditions.get(&"mode", &"") == &"store":
		entity.charge = mini(entity.charge + effect.value, effect.value)  # потолок = value
	elif resource == &"energy" or resource == &"water" or resource == &"biomass":
		economy.earn(resource, int(effect.value))
	else:
		entity.charge += effect.value


# convert: энергия → заряд сущности; потолок = value из данных.
func _run_convert(entity: CardEntity, effect: EffectData) -> void:
	if effect.conditions.get(&"from", &"") != &"energy" \
			or effect.conditions.get(&"to", &"") != &"charge":
		push_warning("DayEffects: convert %s не поддержан днём" % [effect.conditions])
		return
	var room := effect.value - entity.charge
	var amount := int(mini(room, economy.energy))
	if amount > 0:
		economy.pay(0, amount)
		entity.charge += amount
