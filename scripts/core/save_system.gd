extends Node
## Сохранение (autoload): чекпоинт забега на рассвете + мета-биомасса
## между забегами. save_version с первого дня — сейвы не ломаются никогда
## (правило 7): миграции, бэкап битых/новых файлов, атомарная запись.
## Сбор — через группу savable: узел даёт save_key() и get_save_data().

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"

var save_path: String = SAVE_PATH  # тесты подменяют

var _data: Dictionary = {}


func _ready() -> void:
	EventBus.dawn_started.connect(func(_day: int) -> void: save_game())
	EventBus.run_ended.connect(_on_run_ended)


func has_run() -> bool:
	var data: Variant = _read_file()
	return data != null and data.get("run") != null


# Продолжение из меню: старт штатный, сейв накладывается следующим кадром
# (системы должны сначала отработать run_start_requested).
func request_continue() -> void:
	if not _read_into_data():
		return
	EventBus.run_start_requested.emit()
	call_deferred("_apply")


func save_game() -> void:
	_data = _collect()
	_write(_data)


# Чтение + миграция + применение к текущим системам.
func load_game() -> bool:
	if not _read_into_data():
		return false
	_apply()
	return true


func wipe_run() -> void:
	_data["run"] = null
	_write(_data)


func meta_biomass() -> int:
	return int(_data.get("meta", {}).get("biomass", 0))


# --- сбор и применение -------------------------------------------------

func _collect() -> Dictionary:
	var snapshot: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"savable"):
		snapshot[node.save_key()] = node.get_save_data()
	return {
		"save_version": SAVE_VERSION,
		"meta": _data.get("meta", {"biomass": 0}),
		"run": {
			"day_number": RunState.day_number,
			"snapshot": snapshot,
		},
	}


func _apply() -> void:
	var run: Variant = _data.get("run")
	if typeof(run) != TYPE_DICTIONARY:
		return
	RunState.day_number = int(run.get("day_number", 1))
	var snapshot: Dictionary = run.get("snapshot", {})
	for node: Node in get_tree().get_nodes_in_group(&"savable"):
		var key: StringName = node.save_key()
		if snapshot.has(key):
			node.apply_save_data(snapshot[key])


# --- файлы ------------------------------------------------------------

func _read_into_data() -> bool:
	var data: Variant = _read_file()
	if data == null:
		return false
	_data = _migrate(data)
	return true


func _read_file() -> Variant:
	if not FileAccess.file_exists(save_path):
		return null
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup_corrupt()
		_data = _fresh()
		_write(_data)
		return null
	if int(parsed.get("save_version", -1)) > SAVE_VERSION:
		# Сейв новее игры — не ломаемся: бэкап и свежий сейв.
		_backup_corrupt()
		_data = _fresh()
		_write(_data)
		return null
	return parsed


func _write(data: Dictionary) -> void:
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: не записать %s" % [tmp])
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	DirAccess.rename_absolute(tmp, save_path)


func _backup_corrupt() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var backup := "user://save_corrupt_%d.json" % [Time.get_unix_time_from_system()]
	DirAccess.copy_absolute(save_path, backup)


func _fresh() -> Dictionary:
	return {"save_version": SAVE_VERSION, "meta": {"biomass": 0}, "run": null}


# Цепочка миграторов: version 0 → 1 и далее. Каждый шаг — отдельная ветка.
func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 0))
	while version < SAVE_VERSION:
		version += 1
		if version == 1:
			data["meta"] = data.get("meta", {"biomass": 0})
	data["save_version"] = version
	return data


# Конец забега: заработанная в забеге биомасса уходит в мета-копилку
# (cozy — награда не сгорает, docs/01 §10 по духу); забег стирается.
func _on_run_ended(_victory: bool, _day: int) -> void:
	var meta := int(_data.get("meta", {}).get("biomass", 0))
	for node: Node in get_tree().get_nodes_in_group(&"savable"):
		if node.save_key() == &"economy":
			meta += node.biomass  # биомасса забега → мета
			node.biomass = 0
	_data["meta"] = {"biomass": meta}
	_data["run"] = null
	_write(_data)
