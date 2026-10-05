class_name PhaseMainMenu extends Phase
## Главное меню: ждёт запроса на старт забега.


func _init() -> void:
	id = &"main_menu"


func enter(_config: RunConfig) -> void:
	RunState.reset()
