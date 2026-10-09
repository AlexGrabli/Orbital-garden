class_name CardEntity extends Node2D
## Размещённая на сетке карта: данные + HP. Эффекты исполняются позже
## (дневные — задача 5, ночные — задача 7).

var card: CardResource
var current_hp: int = 0


func setup(p_card: CardResource) -> void:
	card = p_card
	current_hp = p_card.hp


func _ready() -> void:
	# Визуал-плейсхолдер (арт — Фаза 3); размер чуть меньше клетки 32px.
	var rect := ColorRect.new()
	rect.size = Vector2(28, 28)
	rect.position = Vector2(-14, -14)
	rect.color = Color(0.85, 0.6, 0.3, 0.9)
	add_child(rect)
	var label := Label.new()
	label.text = card.name if card != null else "?"
	label.position = Vector2(-14, 12)
	add_child(label)
