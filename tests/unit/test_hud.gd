extends GutTest

var hud = null

func before_each() -> void:
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child_autofree(hud)

func test_update_hp_sets_bar_value() -> void:
	hud.update_hp(50, 100)
	assert_eq(hud.hp_bar.value, 50.0, "hp_bar.value should be 50 after update_hp(50, 100)")

func test_update_hp_sets_label() -> void:
	hud.update_hp(50, 100)
	assert_eq(hud.hp_label.text, "50 / 100", "hp_label.text should be '50 / 100'")

func test_update_mana_sets_bar_value() -> void:
	hud.update_mana(30, 80)
	assert_eq(hud.mana_bar.value, 30.0, "mana_bar.value should be 30 after update_mana(30, 80)")

func test_update_gold_sets_label() -> void:
	hud.update_gold(42)
	assert_true("Gold: 42" in hud.gold_label.text, "gold_label.text should contain 'Gold: 42'")

func test_show_hide_hud() -> void:
	hud.show_hud()
	assert_true(hud.visible, "HUD should be visible after show_hud()")
	hud.hide_hud()
	assert_false(hud.visible, "HUD should not be visible after hide_hud()")
