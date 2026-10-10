class_name NightEffects extends Node
## Ночной интерпретатор эффектов (зеркало DayEffects): damage (single и
## stored_energy), heal, ночной convert. Остальные типы — пропуск (правило 4).

@export var economy: EconomyManager
@export var layout: GridLayout

var _night_active: bool = false
var _spawns_finished: bool = false
var _timers: Dictionary = {}  # CardEntity → остаток кулдауна
var _convert_timer: float = 0.0
var _convert_rr: int = 0
var _warned_types: Dictionary = {}  # тип → уже предупреждали


func _ready() -> void:
	EventBus.night_started.connect(_on_night_started)
	EventBus.night_ended.connect(func(_d: int, _b: bool) -> void: _night_active = false)
	EventBus.dawn_started.connect(func(_d: int) -> void: _night_active = false)
	EventBus.wave_spawns_finished.connect(func(_d: int) -> void: _spawns_finished = true)
	EventBus.card_destroyed.connect(_on_card_destroyed)


func _on_night_started(_day: int) -> void:
	_night_active = true
	_spawns_finished = false
	_timers.clear()
	_convert_timer = 0.0
	_convert_rr = 0


func _on_card_destroyed(entity: Node, _cell: Vector2i) -> void:
	_timers.erase(entity)


func _process(delta: float) -> void:
	if not _night_active:
		return
	for node: Node in get_tree().get_nodes_in_group(&"card_entities"):
		var entity := node as CardEntity
		if entity.card == null or entity.card.night_effect == null:
			continue
		_tick_entity(entity, delta)
	_tick_convert(delta)
	_check_night_end()


func _tick_entity(entity: CardEntity, delta: float) -> void:
	var effect: EffectData = entity.card.night_effect
	var left: float = _timers.get(entity, 0.0)
	if left > 0.0:
		_timers[entity] = left - delta
		return
	match effect.type:
		&"damage":
			if effect.conditions.get(&"scaling", &"") == &"stored_energy":
				if _cactus_volley(entity, effect):
					_timers[entity] = effect.cooldown
			else:
				if _turret_shot(entity, effect):
					_timers[entity] = effect.cooldown
		&"heal":
			if _heal_pulse(entity, effect):
				_timers[entity] = effect.cooldown
		&"convert":
			pass  # тикает глобально в _tick_convert
		_:
			if not _warned_types.has(effect.type):
				_warned_types[effect.type] = true
				push_warning("NightEffects: тип '%s' ночью не исполняется" % [effect.type])


# Турель: 1 заряд = 1 выстрел = value урона по врагу, ближайшему к Ядру.
func _turret_shot(entity: CardEntity, effect: EffectData) -> bool:
	if entity.charge < 1.0:
		return false
	var target := _nearest_enemy(entity.position, effect.radius * layout.cell_size)
	if target == null:
		return false
	entity.charge -= 1.0
	target.current_hp -= int(effect.value)
	if target.current_hp <= 0:
		target.queue_free()
	return true


# Кактус: залп = 1 × запас урона, равномерно по целям в радиусе.
# Запас не расходуется (интерпретация docs/01 §6; поменять — одно условие).
func _cactus_volley(entity: CardEntity, effect: EffectData) -> bool:
	var targets := _enemies_in_radius(entity.position, effect.radius * layout.cell_size)
	if targets.is_empty() or entity.charge <= 0.0:
		return false
	var total := int(entity.charge)
	var per := total / targets.size()
	var extra := total % targets.size()
	for i in targets.size():
		targets[i].current_hp -= per + (1 if i < extra else 0)
		if targets[i].current_hp <= 0:
			targets[i].queue_free()
	return true


# Конденсатор: союзные карты с тегом conditions.targets в радиусе, до потолка.
func _heal_pulse(entity: CardEntity, effect: EffectData) -> bool:
	var tag: StringName = effect.conditions.get(&"targets", &"")
	var radius := effect.radius * layout.cell_size
	var healed := false
	for node: Node in get_tree().get_nodes_in_group(&"card_entities"):
		var ally := node as CardEntity
		if ally == entity or ally.position.distance_to(entity.position) > radius:
			continue
		if not ally.card.tags.has(tag) or ally.current_hp >= ally.card.hp:
			continue
		ally.current_hp = mini(ally.current_hp + int(effect.value), ally.card.hp)
		healed = true
	return healed


# Солнечная панель: 1 энергия/сек → +rate зарядов damage-картам в радиусе (по кругу).
func _tick_convert(delta: float) -> void:
	_convert_timer -= delta
	if _convert_timer > 0.0:
		return
	_convert_timer = 1.0
	if economy.energy <= 0:
		return
	for node: Node in get_tree().get_nodes_in_group(&"card_entities"):
		var entity := node as CardEntity
		var effect: EffectData = entity.card.night_effect if entity.card != null else null
		if effect == null or effect.type != &"convert":
			continue
		var receivers: Array = []
		for other: Node in get_tree().get_nodes_in_group(&"card_entities"):
			var ally := other as CardEntity
			var night: EffectData = ally.card.night_effect if ally.card != null else null
			if night != null and night.type == &"damage" \
					and ally.position.distance_to(entity.position) <= effect.radius * layout.cell_size:
				receivers.append(ally)
		if receivers.is_empty():
			continue
		if economy.pay(0, 1):
			var rate := int(effect.conditions.get(&"rate", 1))
			receivers[_convert_rr % receivers.size()].charge += rate
			_convert_rr += 1


# Ранняя зачистка: спавны кончились и врагов не осталось.
func _check_night_end() -> void:
	if _spawns_finished and get_tree().get_nodes_in_group(&"enemies").is_empty():
		_night_active = false
		EventBus.night_completed.emit()


func _nearest_enemy(from: Vector2, radius: float) -> EnemyEntity:
	var best: EnemyEntity = null
	var best_dist := INF
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as EnemyEntity
		var d_core := enemy.position.distance_to(_core_pos())
		var d_self := enemy.position.distance_to(from)
		if d_self <= radius and d_core < best_dist:
			best_dist = d_core
			best = enemy
	return best


func _enemies_in_radius(from: Vector2, radius: float) -> Array:
	var result: Array = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as EnemyEntity
		if enemy.position.distance_to(from) <= radius:
			result.append(enemy)
	return result


func _core_pos() -> Vector2:
	for node: Node in get_tree().get_nodes_in_group(&"station_core"):
		return (node as StationCore).position
	return Vector2.ZERO
