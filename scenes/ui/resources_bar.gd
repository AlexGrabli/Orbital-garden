extends HBoxContainer
## Полоса ресурсов (плейсхолдер до HUD — задача 8).

@onready var _label: Label = $Label


func _ready() -> void:
	EventBus.resources_changed.connect(_on_resources_changed)


func _on_resources_changed(energy: int, water: int, biomass: int) -> void:
	_label.text = "Э%d · В%d · Б%d" % [energy, water, biomass]
