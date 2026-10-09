class_name PlayController extends Node
## Связывает руку и сетку: выбранная карта + подтверждённая клетка → CardEntity.

@export var grid: GridManager
@export var deck: DeckManager

var _selected: CardResource = null

var _entity_scene: PackedScene = preload("res://scenes/entities/card_entity.tscn")


func _ready() -> void:
	EventBus.hand_card_selected.connect(_on_hand_card_selected)
	EventBus.grid_cell_confirmed.connect(_on_grid_cell_confirmed)
	EventBus.grid_selection_cancelled.connect(_clear_selection)
	EventBus.input_cancelled.connect(_clear_selection)


func _on_hand_card_selected(card: CardResource) -> void:
	_selected = card


func _on_grid_cell_confirmed(cell: Vector2i) -> void:
	if _selected == null:
		return
	# TODO(задача 5): оплата стоимости (вода/энергия) перед размещением.
	if not grid.is_buildable(cell):
		return  # выбор карты сохраняется — можно кликнуть другую клетку
	var entity: CardEntity = _entity_scene.instantiate()
	entity.setup(_selected)
	add_child(entity)
	entity.position = grid.layout.cell_rect(cell).get_center()
	if grid.place(cell, entity):
		deck.remove_from_hand(_selected)
		EventBus.card_played.emit(_selected, cell)
		_selected = null
	else:
		entity.queue_free()


func _clear_selection() -> void:
	_selected = null
