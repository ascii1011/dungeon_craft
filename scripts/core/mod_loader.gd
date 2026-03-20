extends Node
## ModLoader — scans user://mods/ and merges external JSON data into DataLoader's cache.
## Register as an autoload in project settings after DataLoader.

const MOD_DIR = "user://mods/"

signal mod_loaded(mod_name: String, item_count: int)
signal mod_load_failed(mod_name: String, reason: String)

var loaded_mods: Array[String] = []
var _mod_data: Dictionary = {}  # { category: { id: data } }

# Known data categories that mods are allowed to provide.
const VALID_CATEGORIES: Array[String] = ["races", "items", "spells", "enemies"]


func _ready() -> void:
	scan_mods()
	load_all_mods()


## Returns a list of mod folder names found inside MOD_DIR.
## Returns an empty array if the directory does not exist.
func scan_mods() -> Array[String]:
	var dir := DirAccess.open(MOD_DIR)
	if dir == null:
		return []

	var names: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return names


## Iterates all discovered mods and loads each one.
func load_all_mods() -> void:
	var mod_names := scan_mods()
	for mod_name in mod_names:
		load_mod(mod_name)


## Loads a single mod by name from user://mods/{mod_name}/.
## Expects subdirectories matching VALID_CATEGORIES, each containing JSON files.
## Returns true on success, false if the mod directory cannot be opened.
func load_mod(mod_name: String) -> bool:
	var mod_path := MOD_DIR + mod_name + "/"
	var mod_dir := DirAccess.open(mod_path)
	if mod_dir == null:
		var reason := "Directory not found: %s" % mod_path
		push_warning("ModLoader: %s" % reason)
		mod_load_failed.emit(mod_name, reason)
		return false

	var item_count := 0

	for category in VALID_CATEGORIES:
		var cat_path := mod_path + category + "/"
		var cat_dir := DirAccess.open(cat_path)
		if cat_dir == null:
			continue  # Category folder not present — that is fine.

		if not _mod_data.has(category):
			_mod_data[category] = {}

		cat_dir.list_dir_begin()
		var file_name := cat_dir.get_next()
		while file_name != "":
			if not cat_dir.current_is_dir() and file_name.ends_with(".json"):
				var file_path := cat_path + file_name
				var data := _load_json_file(file_path)
				if not data.is_empty():
					var id := file_name.get_basename()
					_mod_data[category][id] = data
					item_count += 1
			file_name = cat_dir.get_next()
		cat_dir.list_dir_end()

	if not loaded_mods.has(mod_name):
		loaded_mods.append(mod_name)

	print("ModLoader: loaded mod '%s' with %d item(s)." % [mod_name, item_count])
	mod_loaded.emit(mod_name, item_count)
	return true


## Returns the mod data for a given category and id, or an empty Dictionary if not found.
func get_mod_data(category: String, id: String) -> Dictionary:
	if _mod_data.has(category) and _mod_data[category].has(id):
		return _mod_data[category][id]
	return {}


## Merges all loaded mod data into DataLoader's internal cache.
## Call this after DataLoader has finished its own _ready().
func inject_into_data_loader() -> void:
	if not Engine.has_singleton("DataLoader"):
		push_warning("ModLoader: DataLoader singleton not found; skipping injection.")
		return

	var data_loader = Engine.get_singleton("DataLoader")
	for category in _mod_data:
		for id in _mod_data[category]:
			var cache_path := "res://data/%s/%s.json" % [category, id]
			data_loader._cache[cache_path] = _mod_data[category][id]


## Returns the list of successfully loaded mod names.
func get_loaded_mods() -> Array[String]:
	return loaded_mods


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ModLoader: could not open file: %s" % path)
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("ModLoader: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return {}

	var result = json.get_data()
	if result is Dictionary:
		return result

	push_warning("ModLoader: expected a JSON object in '%s', got %s" % [path, typeof(result)])
	return {}
