## Unit tests for InventoryUI.
## Run with the GUT framework.
##
## These tests focus on visibility state only; they do not exercise grid
## rendering or signal wiring (which require a live InventoryComponent and
## Godot scene tree with child nodes that are not available in the unit test
## harness without additional scene loading).
extends GutTest

var _ui: InventoryUI

func before_each() -> void:
	_ui = InventoryUI.new()
	# Prevent _ready from trying to resolve NodePath exports or find child
	# nodes — we add it to the tree after patching to avoid null-ref errors.
	add_child_autofree(_ui)
	# _ready() will run after add_child; the NodePath is empty so _inv stays
	# null and all node lookups return null gracefully.


# ---------------------------------------------------------------------------
# Visibility tests
# ---------------------------------------------------------------------------

func test_initial_not_visible() -> void:
	# _ready() sets visible = false.
	assert_false(_ui.visible, "InventoryUI should be hidden on startup")


func test_show_inventory_sets_visible() -> void:
	_ui.show_inventory()
	assert_true(_ui.visible, "show_inventory() should make the panel visible")


func test_hide_inventory_clears_visible() -> void:
	_ui.show_inventory()
	_ui.hide_inventory()
	assert_false(_ui.visible, "hide_inventory() should hide the panel")
