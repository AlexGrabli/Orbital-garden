class_name CardResource extends Resource
## Схема карты — docs/02, раздел 1. Числа карт — только в .tres.

enum Rarity { COMMON, RARE, EPIC }

@export var id: StringName
@export var name: String
@export var flavor_text: String
@export var art_day: Texture2D  # спрайт дня (Фаза 3)
@export var art_night: Texture2D  # спрайт ночи (Фаза 3)
@export var cost_water: int = 0  # В — вода (дневная постройка)
@export var cost_energy: int = 0  # Э — энергия
@export var hp: int = 0
@export var rarity: Rarity = Rarity.COMMON
@export var tags: Array[StringName] = []
@export var day_property: StringName = &"none"  # none | free_move
@export var day_effect: EffectData
@export var night_effect: EffectData
