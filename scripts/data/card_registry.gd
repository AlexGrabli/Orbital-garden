class_name CardRegistry extends Resource
## Реестр всех карт. Новая карта = .tres + запись здесь, код не меняется.

@export var cards: Array[CardResource] = []
@export var starter_deck_ids: Array[StringName] = []


func find(id: StringName) -> CardResource:
	for card: CardResource in cards:
		if card.id == id:
			return card
	return null


func starter_deck() -> Array[CardResource]:
	var result: Array[CardResource] = []
	for id: StringName in starter_deck_ids:
		var card := find(id)
		if card != null:
			result.append(card)
	return result
