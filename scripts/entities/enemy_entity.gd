class_name EnemyEntity extends Node2D
## Враг Роя (плейсхолдер): данные + HP. Движение к Ядру и бой — задача 7.

var enemy: EnemyResource
var current_hp: int = 0


func setup(p_enemy: EnemyResource) -> void:
	enemy = p_enemy
	current_hp = p_enemy.hp


func _ready() -> void:
	add_to_group(&"enemies")
	# Плейсхолдер: тёмно-фиолетовый — палитра Роя (docs/01 §1).
	var rect := ColorRect.new()
	rect.size = Vector2(20, 20)
	rect.position = Vector2(-10, -10)
	rect.color = Color(0.35, 0.15, 0.5)
	add_child(rect)
