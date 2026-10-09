extends CenterContainer
## Драфт 1 из 3 на рассвете (заглушка до HUD): кнопки + фокус на первой
## (геймпад-паритет: confirm активирует сфокусированную кнопку).

@onready var _options: HBoxContainer = $Panel/Box/Options


func _ready() -> void:
	hide()
	EventBus.draft_offered.connect(_on_draft_offered)


func _on_draft_offered(options: Array[CardResource]) -> void:
	for child: Node in _options.get_children():
		child.queue_free()
	for card: CardResource in options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 64)
		var night := card.night_effect.type if card.night_effect != null else &"—"
		button.text = "%s\n☀ %s · 🌙 %s" % [card.name, card.day_effect.type, night]
		button.pressed.connect(func() -> void:
			EventBus.draft_picked.emit(card)
			hide())
		_options.add_child(button)
	if not options.is_empty():
		show()
		_options.get_child(0).call_deferred("grab_focus")
