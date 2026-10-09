class_name EffectData extends Resource
## Данные эффекта карты. Тип — только из закрытого списка (docs/01, раздел 7).

@export var type: StringName  # generate|heal|damage|slow|stun|shield|taunt|
# spawn|reveal|buff|convert|summon_active
@export var value: float = 0.0
@export var radius: float = 0.0
@export var duration: float = 0.0
@export var cooldown: float = 0.0
@export var conditions: Dictionary = {}  # теги соседей, пороги ресурсов
