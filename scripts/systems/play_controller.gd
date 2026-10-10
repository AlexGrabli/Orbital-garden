class_name PlayController extends Node
## Связывает руку, экономику и сетку:
## — карта из руки + клетка → оплата → CardEntity на сетке;
## — размещённая карта + свободная клетка → оплата перемещения → grid.move.

@export var grid_path: NodePath  # Node-экспорты ручных .tscn не резолвятся — путь + get_node
@export var deck_path: NodePath
@export var economy_path: NodePath
@export var config: RunConfig

var grid: GridManager = null
var deck: DeckManager = null
var economy: EconomyManager = null

var _selected_card: CardResource = null  # карта из руки
var _selected_entity: CardEntity = null  # размещённая карта (для перемещения)

var _entity_scene: PackedScene = preload("res://scenes/entities/card_entity.tscn")


func _ready() -> void:
	add_to_group(&"savable")
	if grid_path != NodePath(""):
		grid = get_node(grid_path) as GridManager
		deck = get_node(deck_path) as DeckManager
		economy = get_node(economy_path) as EconomyManager
	EventBus.hand_card_selected.connect(_on_hand_card_selected)
	EventBus.grid_cell_confirmed.connect(_on_grid_cell_confirmed)
	EventBus.grid_selection_cancelled.connect(_clear_selection)
	EventBus.input_cancelled.connect(_clear_selection)


func _on_hand_card_selected(card: CardResource) -> void:
	_selected_card = card
	_selected_entity = null


func _on_grid_cell_confirmed(cell: Vector2i) -> void:
	if _selected_card != null:
		_try_place(cell)
	elif _selected_entity != null:
		_try_move(cell)
	else:
		var occupant := grid.occupant_at(cell) as CardEntity
		if occupant != null:
			_selected_entity = occupant
			EventBus.card_entity_selected.emit(occupant)


func _try_place(cell: Vector2i) -> void:
	if not grid.is_buildable(cell):
		return  # выбор карты сохраняется — можно кликнуть другую клетку
	if not economy.pay(_selected_card.cost_water, _selected_card.cost_energy):
		EventBus.placement_denied.emit(&"not_enough_resources")
		return
	var entity: CardEntity = _entity_scene.instantiate()
	entity.setup(_selected_card)
	add_child(entity)
	entity.position = grid.layout.cell_rect(cell).get_center()
	if grid.place(cell, entity):
		deck.remove_from_hand(_selected_card)
		EventBus.card_played.emit(_selected_card, cell)
		_selected_card = null
	else:
		entity.queue_free()


func _try_move(cell: Vector2i) -> void:
	if not grid.is_buildable(cell):
		return
	# free_move (wall_barrier) — перемещение бесплатно (docs/02 §2.2).
	var cost := 0 if _selected_entity.card.day_property == &"free_move" \
		else config.move_cost_energy
	if not economy.pay(0, cost):
		EventBus.placement_denied.emit(&"not_enough_resources")
		return
	var from := grid.cell_of(_selected_entity)
	if grid.move(from, cell):
		_selected_entity.position = grid.layout.cell_rect(cell).get_center()
		_selected_entity = null  # одно перемещение на выбор; повтор — через новый выбор
	else:
		economy.earn(&"energy", cost)  # возврат при отказе grid.move


func _clear_selection() -> void:
	_selected_card = null
	_selected_entity = null


# --- сохранение (группа savable) --------------------------------------

func save_key() -> StringName:
	return &"grid"


# Размещённые карты (Ядро — не CardEntity, не попадает).
func get_save_data() -> Array:
	var cells: Array = []
	for y in grid.layout.grid_size.y:
		for x in grid.layout.grid_size.x:
			var cell := Vector2i(x, y)
			var entity := grid.occupant_at(cell) as CardEntity
			if entity == null or entity.card == null:
				continue
			cells.append({
				"cell": [cell.x, cell.y],
				"card": String(entity.card.id),
				"hp": entity.current_hp,
				"charge": entity.charge,
			})
	return cells


# Восстановление чекпоинта: размещение без списания стоимости.
func apply_save_data(cells: Array) -> void:
	for entry: Dictionary in cells:
		var card: CardResource = deck.registry.find(StringName(entry.get("card", "")))
		if card == null:
			push_warning("PlayController: карта '%s' не в ростере, клетка пропущена" % [entry.get("card")])
			continue
		var pos: Array = entry.get("cell", [0, 0])
		var cell := Vector2i(int(pos[0]), int(pos[1]))
		if not grid.is_buildable(cell):
			push_warning("PlayController: клетка %s недоступна, карта пропущена" % [cell])
			continue
		var entity: CardEntity = _entity_scene.instantiate()
		entity.setup(card)
		entity.current_hp = int(entry.get("hp", card.hp))
		entity.charge = float(entry.get("charge", 0.0))
		add_child(entity)
		entity.position = grid.layout.cell_rect(cell).get_center()
		grid.place(cell, entity)
