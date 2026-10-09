extends HBoxContainer
## Рука карт (плейсхолдер): кнопка на карту, клик/тап → выбор карты.

@export var cell_size: int = 40  # высота кнопки-карты в UI


func _ready() -> void:
	EventBus.hand_changed.connect(_on_hand_changed)


func _on_hand_changed(hand: Array[CardResource]) -> void:
	for child: Node in get_children():
		child.queue_free()
	for card: CardResource in hand:
		var button := Button.new()
		button.custom_minimum_size = Vector2(96, cell_size)
		button.text = "%s\nВ%d Э%d" % [card.name, card.cost_water, card.cost_energy]
		button.pressed.connect(func() -> void: EventBus.hand_card_selected.emit(card))
		add_child(button)
