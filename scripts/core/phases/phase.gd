class_name Phase extends RefCounted
## Базовая фаза забега.

var id: StringName = &""
var machine: PhaseMachine


func enter(_config: RunConfig) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass
