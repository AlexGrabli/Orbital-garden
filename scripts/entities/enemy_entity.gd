class_name EnemyEntity extends Node2D
## Враг Роя. Ночью: движение по прямой к Ядру (без pathfinding — минимум
## docs/03), рукопашка по блокирующим картам, прорыв = урон Ядру и деспавн.

var enemy: EnemyResource
var current_hp: int = 0

var _layout: GridLayout = null
var _grid: GridManager = null
var _core: StationCore = null
var _attack_timer: float = 0.0


func setup(p_enemy: EnemyResource) -> void:
	enemy = p_enemy
	current_hp = p_enemy.hp


# Ссылки на мир даёт WaveManager при спавне.
func bind(p_layout: GridLayout, p_grid: GridManager, p_core: StationCore) -> void:
	_layout = p_layout
	_grid = p_grid
	_core = p_core


func _ready() -> void:
	add_to_group(&"enemies")
	_build_visual()


func _process(delta: float) -> void:
	# RunState — источник истины: враг может появиться посреди эмиссии
	# night_started и пропустить сигнал.
	if not RunState.night_active or _core == null:
		return
	_attack_timer -= delta
	# Прорыв: у Ядра → урон и исчезновение.
	if position.distance_to(_core.position) < _layout.cell_size * 0.5:
		_core.take_damage(enemy.core_damage)
		queue_free()
		return
	# Рукопашка: ближайшая карта вплотную блокирует путь (эмерджентный taunt).
	var blocker := _blocker()
	if blocker != null:
		if _attack_timer <= 0.0:
			_attack_timer = enemy.attack_cooldown
			_attack_card(blocker)
		return
	position = position.move_toward(_core.position, enemy.speed * delta)


func _blocker() -> CardEntity:
	for node: Node in get_tree().get_nodes_in_group(&"card_entities"):
		var entity := node as CardEntity
		if entity.position.distance_to(position) < _layout.cell_size * 0.5:
			return entity
	return null


func _attack_card(entity: CardEntity) -> void:
	entity.current_hp -= enemy.attack_damage
	if entity.current_hp <= 0:
		# TODO(Фаза 2): ремонтный док — возврат карты через 1 день (docs/01 §10).
		var cell := _grid.cell_of(entity)
		_grid.remove(cell)
		entity.queue_free()
		EventBus.card_destroyed.emit(entity, cell)


func _build_visual() -> void:
	# Плейсхолдер: тёмно-фиолетовый — палитра Роя (docs/01 §1).
	var rect := ColorRect.new()
	rect.size = Vector2(20, 20)
	rect.position = Vector2(-10, -10)
	rect.color = Color(0.35, 0.15, 0.5)
	add_child(rect)
