class_name EconomyManager extends Node
## Три ресурса забега (docs/01 §5): энергия, вода, биомасса.
## Локальные запасы сущностей (charge) — НЕ ресурсы.

@export var config: RunConfig

var energy: int = 0
var water: int = 0
var biomass: int = 0

var _bet_pending: bool = false


func _ready() -> void:
	add_to_group(&"savable")
	EventBus.run_start_requested.connect(_on_run_start)
	EventBus.sunset_started.connect(_on_sunset_started)
	EventBus.sunset_bet_made.connect(_on_sunset_bet)
	EventBus.night_started.connect(_on_night_started)
	EventBus.dawn_started.connect(_on_dawn_started)


func can_afford(water_cost: int, energy_cost: int) -> bool:
	return water >= water_cost and energy >= energy_cost


# Недостаточно — false, ничего не списано.
func pay(water_cost: int, energy_cost: int) -> bool:
	if not can_afford(water_cost, energy_cost):
		return false
	water -= water_cost
	energy -= energy_cost
	_emit()
	return true


func earn(resource: StringName, amount: int) -> void:
	match resource:
		&"energy":
			energy += amount
		&"water":
			water += amount
		&"biomass":
			biomass += amount
		_:
			push_warning("EconomyManager: неизвестный ресурс %s" % [resource])
	_emit()


func _on_run_start() -> void:
	energy = config.start_energy
	water = config.start_water
	biomass = config.start_biomass
	_bet_pending = false
	_emit()


func _on_sunset_started(_day: int) -> void:
	_bet_pending = true


func _on_sunset_bet(mode: StringName, water_spent: int) -> void:
	if not _bet_pending:
		return
	_bet_pending = false
	_apply_bet(mode, mini(water_spent, water))


func _on_night_started(_day: int) -> void:
	# Ставки не было (AFK): дефолт — РОСТ, cozy-игра не наказывает.
	if _bet_pending:
		_bet_pending = false
		_apply_bet(&"growth", water)


func _on_dawn_started(_day: int) -> void:
	earn(&"biomass", config.dawn_biomass_reward)


# Ставка тратит ВСЮ оставшуюся воду (остаток на закате сгорает).
func _apply_bet(mode: StringName, water_spent: int) -> void:
	water = 0
	var entities := get_tree().get_nodes_in_group(&"card_entities")
	match mode:
		&"growth":
			var heal := water_spent * config.sunset_heal_per_water
			for node: Node in entities:
				var entity := node as CardEntity
				entity.current_hp = mini(entity.current_hp + heal, entity.card.hp)
		&"ammo":
			var shooters: Array = []
			for node: Node in entities:
				var entity := node as CardEntity
				if entity.card.night_effect != null and entity.card.night_effect.type == &"damage":
					shooters.append(entity)
			if shooters.is_empty():
				return
			var total := water_spent * config.sunset_ammo_per_water
			var per := total / shooters.size()
			var extra := total % shooters.size()  # остаток — первым
			for i in shooters.size():
				(shooters[i] as CardEntity).charge += per + (1 if i < extra else 0)
	_emit()


func _emit() -> void:
	EventBus.resources_changed.emit(energy, water, biomass)


# --- сохранение (группа savable) --------------------------------------

func save_key() -> StringName:
	return &"economy"


func get_save_data() -> Dictionary:
	return {"energy": energy, "water": water, "biomass": biomass}


func apply_save_data(d: Dictionary) -> void:
	energy = int(d.get("energy", energy))
	water = int(d.get("water", water))
	biomass = int(d.get("biomass", biomass))
	_emit()
