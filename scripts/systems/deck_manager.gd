class_name DeckManager extends Node
## Колода и рука: старт забега, утренний добор, драфт на рассвете.
## Сыгранные карты уходят на поле (сброса нет) — колода пополняется драфтом.

@export var registry: CardRegistry
@export var config: RunConfig

var deck: Array[CardResource] = []  # доборная стопка (перемешана на старте)
var hand: Array[CardResource] = []


func _ready() -> void:
	add_to_group(&"savable")
	EventBus.run_start_requested.connect(start_run)
	EventBus.day_started.connect(_on_day_started)
	EventBus.dawn_started.connect(_on_dawn_started)
	EventBus.draft_picked.connect(add_to_deck)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.hand_index_selected.connect(_on_hand_index_selected)


func start_run() -> void:
	deck = registry.starter_deck()
	deck.shuffle()
	hand.clear()
	_emit_state()


# Утро: добор до hand_draw_size, не выше hand_limit. Пустая колода — молча.
func draw_morning() -> void:
	var target: int = mini(config.hand_draw_size, config.hand_limit)
	while hand.size() < target and not deck.is_empty():
		hand.append(deck.pop_back())
	_emit_state()


func remove_from_hand(card: CardResource) -> bool:
	var idx := hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
	_emit_state()
	return true


func add_to_deck(card: CardResource) -> void:
	deck.append(card)
	EventBus.deck_count_changed.emit(deck.size())


func _on_day_started(_day: int) -> void:
	draw_morning()


func _on_dawn_started(_day: int) -> void:
	# Драфт равновесный; взвешивание по редкости — Фаза 2.
	var pool := registry.cards.duplicate()
	pool.shuffle()
	var options: Array[CardResource] = []
	for i in mini(3, pool.size()):
		options.append(pool[i])
	EventBus.draft_offered.emit(options)


func _on_hand_index_selected(index: int) -> void:
	# Выбор карты геймпад-курсором (строка руки).
	if index >= 0 and index < hand.size():
		EventBus.hand_card_selected.emit(hand[index])


func _on_run_ended(_victory: bool, _day: int) -> void:
	deck.clear()
	hand.clear()
	_emit_state()


func _emit_state() -> void:
	EventBus.hand_changed.emit(hand)
	EventBus.deck_count_changed.emit(deck.size())


# --- сохранение (группа savable) --------------------------------------

func save_key() -> StringName:
	return &"deck"


func get_save_data() -> Dictionary:
	var deck_ids: Array = []
	for card: CardResource in deck:
		deck_ids.append(String(card.id))
	var hand_ids: Array = []
	for card: CardResource in hand:
		hand_ids.append(String(card.id))
	return {"deck": deck_ids, "hand": hand_ids}


func apply_save_data(d: Dictionary) -> void:
	deck.clear()
	for id: String in d.get("deck", []):
		var card := registry.find(StringName(id))
		if card == null:
			push_warning("DeckManager: карта '%s' не в ростере, пропуск" % [id])
			continue
		deck.append(card)
	hand.clear()
	for id: String in d.get("hand", []):
		var card := registry.find(StringName(id))
		if card == null:
			push_warning("DeckManager: карта '%s' не в ростере, пропуск" % [id])
			continue
		hand.append(card)
	_emit_state()
