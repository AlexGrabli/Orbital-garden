extends SceneTree
## Smoke-тест: главная сцена грузится, дерево сцен не пустое.
## Запуск: godot --headless -s res://tests/smoke_test.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/game/main.tscn")
	if packed == null:
		printerr("SMOKE_FAIL: не удалось загрузить scenes/game/main.tscn")
		quit(1)
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)

	for i in 3:
		await process_frame

	if scene.is_inside_tree() and root.get_child_count() > 0:
		print("SMOKE_OK")
		quit(0)
	else:
		printerr("SMOKE_FAIL: дерево сцен пустое")
		quit(1)
