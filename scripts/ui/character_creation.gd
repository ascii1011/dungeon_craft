## CharacterCreation
## Full-screen character creation screen. Builds its own UI at runtime from
## DataLoader so adding new races/classes requires no scene changes.
## Emits character_confirmed(race_id, class_id) when the player clicks Begin.
extends CanvasLayer

signal character_confirmed(race_id: String, class_id: String)

const RACE_IDS := ["human", "orc", "dwarf"]
const CLASS_IDS := ["warrior", "mage", "ranger"]

var _selected_race: String = ""
var _selected_class: String = ""

# UI node references built in _build_ui()
var _race_buttons: Dictionary = {}
var _class_buttons: Dictionary = {}
var _class_btn_container: HBoxContainer
var _info_name: Label
var _info_desc: Label
var _stat_value_labels: Dictionary = {}
var _trait_label: Label
var _class_info_name: Label
var _class_info_desc: Label
var _class_mods_label: Label
var _begin_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# ---- Background ----
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ---- Centered panel ----
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(920, 580)
	panel.set_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left   = -460
	panel.offset_right  =  460
	panel.offset_top    = -290
	panel.offset_bottom =  290
	add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	root_vbox.offset_left   =  16
	root_vbox.offset_right  = -16
	root_vbox.offset_top    =  12
	root_vbox.offset_bottom = -12
	panel.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Create Your Character"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root_vbox.add_child(title)
	root_vbox.add_child(HSeparator.new())

	# ---- Three-column content row ----
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root_vbox.add_child(cols)

	# --- LEFT: Race column ---
	var race_col := VBoxContainer.new()
	race_col.custom_minimum_size = Vector2(170, 0)
	race_col.add_theme_constant_override("separation", 6)
	cols.add_child(race_col)

	var race_hdr := Label.new()
	race_hdr.text = "Race"
	race_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_hdr.add_theme_font_size_override("font_size", 18)
	race_col.add_child(race_hdr)
	race_col.add_child(HSeparator.new())

	for race_id in RACE_IDS:
		var rd: Dictionary = DataLoader.load_race(race_id)
		var btn := Button.new()
		btn.text = rd.get("name", race_id.capitalize())
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_race_selected.bind(race_id))
		race_col.add_child(btn)
		_race_buttons[race_id] = btn

	# --- CENTER: Info panel ---
	var info_panel := Panel.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_vbox.add_theme_constant_override("separation", 6)
	info_vbox.offset_left   =  10
	info_vbox.offset_right  = -10
	info_vbox.offset_top    =  10
	info_vbox.offset_bottom = -10
	info_panel.add_child(info_vbox)

	_info_name = Label.new()
	_info_name.text = "← Select a race"
	_info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_name.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(_info_name)

	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(_info_desc)

	# Stats grid (3 columns: label + value, repeated)
	var stats_grid := GridContainer.new()
	stats_grid.columns = 6
	info_vbox.add_child(stats_grid)
	for stat_id in ["HP", "MP", "STR", "DEX", "INT", "VIT"]:
		var n := Label.new()
		n.text = stat_id + ":"
		stats_grid.add_child(n)
		var v := Label.new()
		v.text = "—"
		v.custom_minimum_size = Vector2(36, 0)
		stats_grid.add_child(v)
		_stat_value_labels[stat_id] = v

	_trait_label = Label.new()
	_trait_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	_trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(_trait_label)

	# Class buttons (inside info panel, populated when race chosen)
	var class_hdr := Label.new()
	class_hdr.text = "Class"
	class_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_hdr.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(class_hdr)
	info_vbox.add_child(HSeparator.new())

	_class_btn_container = HBoxContainer.new()
	_class_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_class_btn_container.add_theme_constant_override("separation", 10)
	info_vbox.add_child(_class_btn_container)

	# --- RIGHT: Class info column ---
	var class_col := VBoxContainer.new()
	class_col.custom_minimum_size = Vector2(200, 0)
	class_col.add_theme_constant_override("separation", 6)
	cols.add_child(class_col)

	var class_col_hdr := Label.new()
	class_col_hdr.text = "Class Info"
	class_col_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_col_hdr.add_theme_font_size_override("font_size", 18)
	class_col.add_child(class_col_hdr)
	class_col.add_child(HSeparator.new())

	_class_info_name = Label.new()
	_class_info_name.text = "—"
	_class_info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_info_name.add_theme_font_size_override("font_size", 16)
	class_col.add_child(_class_info_name)

	_class_info_desc = Label.new()
	_class_info_desc.text = "Select a class."
	_class_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_info_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	class_col.add_child(_class_info_desc)

	_class_mods_label = Label.new()
	_class_mods_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_class_mods_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	class_col.add_child(_class_mods_label)

	# ---- Bottom row ----
	root_vbox.add_child(HSeparator.new())

	_begin_btn = Button.new()
	_begin_btn.text = "Begin Adventure"
	_begin_btn.disabled = true
	_begin_btn.add_theme_font_size_override("font_size", 20)
	_begin_btn.pressed.connect(_on_begin_pressed)
	root_vbox.add_child(_begin_btn)


func _on_race_selected(race_id: String) -> void:
	_selected_race = race_id
	_selected_class = ""
	_begin_btn.disabled = true

	# Toggle race buttons.
	for rid in _race_buttons:
		_race_buttons[rid].button_pressed = (rid == race_id)

	# Load and display race info.
	var rd: Dictionary = DataLoader.load_race(race_id)
	_info_name.text = rd.get("name", race_id.capitalize())
	_info_desc.text = rd.get("description", "")

	var bs: Dictionary = rd.get("base_stats", {})
	_stat_value_labels["HP"].text  = str(bs.get("hp",           "—"))
	_stat_value_labels["MP"].text  = str(bs.get("mana",         "—"))
	_stat_value_labels["STR"].text = str(bs.get("strength",     "—"))
	_stat_value_labels["DEX"].text = str(bs.get("dexterity",    "—"))
	_stat_value_labels["INT"].text = str(bs.get("intelligence", "—"))
	_stat_value_labels["VIT"].text = str(bs.get("vitality",     "—"))

	var traits: Array = rd.get("traits", [])
	var trait_descs: Dictionary = rd.get("trait_descriptions", {})
	var trait_text := ""
	for t in traits:
		trait_text += "• " + trait_descs.get(t, t.capitalize().replace("_", " ")) + "\n"
	_trait_label.text = trait_text.strip_edges()

	# Rebuild class buttons filtered by this race's allowed_classes.
	for child in _class_btn_container.get_children():
		child.queue_free()
	_class_buttons.clear()
	_class_info_name.text = "—"
	_class_info_desc.text = "Select a class."
	_class_mods_label.text = ""

	var allowed: Array = rd.get("allowed_classes", [])
	for class_id in allowed:
		var cd: Dictionary = DataLoader.load_class(class_id)
		var btn := Button.new()
		btn.text = cd.get("name", class_id.capitalize())
		btn.toggle_mode = true
		btn.pressed.connect(_on_class_selected.bind(class_id))
		_class_btn_container.add_child(btn)
		_class_buttons[class_id] = btn


func _on_class_selected(class_id: String) -> void:
	_selected_class = class_id

	# Toggle class buttons.
	for cid in _class_buttons:
		_class_buttons[cid].button_pressed = (cid == class_id)

	# Display class info.
	var cd: Dictionary = DataLoader.load_class(class_id)
	_class_info_name.text = cd.get("name", class_id.capitalize())
	_class_info_desc.text = cd.get("description", "")

	var mods: Dictionary = cd.get("stat_modifiers", {})
	var mod_lines := ""
	for stat in mods:
		var val: int = int(mods[stat])
		var sign_str := "+" if val >= 0 else ""
		mod_lines += "%s %s%d\n" % [stat.capitalize(), sign_str, val]
	var starting_spells: Array = cd.get("starting_spells", [])
	if starting_spells.size() > 0:
		mod_lines += "Spells: " + ", ".join(starting_spells).capitalize() + "\n"
	var starting_items: Array = cd.get("starting_items", [])
	if starting_items.size() > 0:
		mod_lines += "Items: " + ", ".join(starting_items).replace("_", " ").capitalize()
	_class_mods_label.text = mod_lines.strip_edges()

	_begin_btn.disabled = false


func _on_begin_pressed() -> void:
	if _selected_race.is_empty() or _selected_class.is_empty():
		return
	character_confirmed.emit(_selected_race, _selected_class)
