## GUT unit tests for DungeonGenerator
extends GutTest

var _gen: DungeonGenerator

func before_each() -> void:
	_gen = DungeonGenerator.new()
	add_child(_gen)

func after_each() -> void:
	_gen.queue_free()

# ---------------------------------------------------------------------------
# test_generate_returns_dict_with_required_keys
# ---------------------------------------------------------------------------
func test_generate_returns_dict_with_required_keys() -> void:
	var result: Dictionary = _gen.generate(50, 50, 42)
	assert_true(result.has("width"),        "missing key: width")
	assert_true(result.has("height"),       "missing key: height")
	assert_true(result.has("seed"),         "missing key: seed")
	assert_true(result.has("tiles"),        "missing key: tiles")
	assert_true(result.has("rooms"),        "missing key: rooms")
	assert_true(result.has("corridors"),    "missing key: corridors")
	assert_true(result.has("spawn_room"),   "missing key: spawn_room")
	assert_true(result.has("exit_room"),    "missing key: exit_room")
	assert_true(result.has("room_centers"), "missing key: room_centers")

# ---------------------------------------------------------------------------
# test_tile_grid_dimensions_match_request
# ---------------------------------------------------------------------------
func test_tile_grid_dimensions_match_request() -> void:
	var w: int = 60
	var h: int = 40
	var result: Dictionary = _gen.generate(w, h, 1)
	var tiles: Array = result["tiles"]
	assert_eq(tiles.size(), w, "tiles x dimension should equal requested width")
	assert_eq(tiles[0].size(), h, "tiles y dimension should equal requested height")
	assert_eq(result["width"], w, "result width key mismatch")
	assert_eq(result["height"], h, "result height key mismatch")

# ---------------------------------------------------------------------------
# test_at_least_three_rooms_generated
# ---------------------------------------------------------------------------
func test_at_least_three_rooms_generated() -> void:
	var result: Dictionary = _gen.generate(50, 50, 7)
	var rooms: Array = result["rooms"]
	assert_true(rooms.size() >= 3,
		"expected at least 3 rooms, got %d" % rooms.size())

# ---------------------------------------------------------------------------
# test_all_room_tiles_are_floor
# ---------------------------------------------------------------------------
func test_all_room_tiles_are_floor() -> void:
	var result: Dictionary = _gen.generate(60, 60, 99)
	var rooms: Array = result["rooms"]
	var tiles: Array = result["tiles"]
	for room in rooms:
		# Check interior tiles (skip the 1-tile border row/col)
		for x in range(room.position.x + 1, room.position.x + room.size.x - 1):
			for y in range(room.position.y + 1, room.position.y + room.size.y - 1):
				assert_eq(
					tiles[x][y],
					DungeonGenerator.TILE_FLOOR,
					"interior tile at (%d,%d) should be TILE_FLOOR" % [x, y]
				)

# ---------------------------------------------------------------------------
# test_spawn_and_exit_are_different_rooms
# ---------------------------------------------------------------------------
func test_spawn_and_exit_are_different_rooms() -> void:
	var result: Dictionary = _gen.generate(60, 60, 5)
	var spawn: Rect2i = result["spawn_room"]
	var exit_r: Rect2i = result["exit_room"]
	assert_ne(spawn, exit_r, "spawn_room and exit_room should be different")

# ---------------------------------------------------------------------------
# test_same_seed_produces_same_layout
# ---------------------------------------------------------------------------
func test_same_seed_produces_same_layout() -> void:
	var r1: Dictionary = _gen.generate(50, 50, 42)
	var r2: Dictionary = _gen.generate(50, 50, 42)
	var tiles1: Array = r1["tiles"]
	var tiles2: Array = r2["tiles"]
	var identical: bool = true
	for x in range(tiles1.size()):
		for y in range(tiles1[x].size()):
			if tiles1[x][y] != tiles2[x][y]:
				identical = false
				break
		if not identical:
			break
	assert_true(identical, "same seed should produce identical tile layouts")

# ---------------------------------------------------------------------------
# test_different_seeds_produce_different_layouts
# ---------------------------------------------------------------------------
func test_different_seeds_produce_different_layouts() -> void:
	var r1: Dictionary = _gen.generate(60, 60, 1)
	var r2: Dictionary = _gen.generate(60, 60, 2)
	var tiles1: Array = r1["tiles"]
	var tiles2: Array = r2["tiles"]
	var differs: bool = false
	for x in range(tiles1.size()):
		for y in range(tiles1[x].size()):
			if tiles1[x][y] != tiles2[x][y]:
				differs = true
				break
		if differs:
			break
	assert_true(differs, "different seeds should produce different tile layouts")

# ---------------------------------------------------------------------------
# test_no_tiles_out_of_bounds
# ---------------------------------------------------------------------------
func test_no_tiles_out_of_bounds() -> void:
	var w: int = 70
	var h: int = 70
	var result: Dictionary = _gen.generate(w, h, 13)
	var rooms: Array = result["rooms"]
	for room in rooms:
		assert_true(room.position.x >= 0,
			"room left edge out of bounds: x=%d" % room.position.x)
		assert_true(room.position.y >= 0,
			"room top edge out of bounds: y=%d" % room.position.y)
		assert_true(room.position.x + room.size.x <= w,
			"room right edge out of bounds: x+w=%d" % (room.position.x + room.size.x))
		assert_true(room.position.y + room.size.y <= h,
			"room bottom edge out of bounds: y+h=%d" % (room.position.y + room.size.y))

# ---------------------------------------------------------------------------
# test_generate_multiple_sizes
# ---------------------------------------------------------------------------
func test_generate_multiple_sizes() -> void:
	var sizes: Array = [[30, 30], [60, 60], [100, 100]]
	for size in sizes:
		var result: Dictionary = _gen.generate(size[0], size[1], 77)
		assert_eq(result["width"], size[0],
			"width mismatch for size %dx%d" % [size[0], size[1]])
		assert_eq(result["height"], size[1],
			"height mismatch for size %dx%d" % [size[0], size[1]])
		assert_true(result["rooms"].size() > 0,
			"no rooms generated for size %dx%d" % [size[0], size[1]])
		assert_true(result["tiles"].size() == size[0],
			"tiles x-dim wrong for size %dx%d" % [size[0], size[1]])
