## DungeonRenderer
## Generates a BSP dungeon, bakes it into an ImageTexture displayed via Sprite2D,
## and builds wall collision. ImageTexture rendering works on all backends
## including macOS GL Compatibility. Exposes spawn, exit, and room-center
## positions for the rest of the systems to use.
class_name DungeonRenderer
extends Node2D

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------

## Base tile footprint — matches Warcraft II's 32 px tiles.
const TILE_SIZE:   int = 32
## Bright top-cap strip on each wall tile (the horizontal surface seen from above).
const WALL_TOP_H:  int = 7
## South-face overhang — how far the wall's front face bleeds BELOW its tile boundary.
## This is the key to the raised-3D-block look: the face overlaps the floor tiles south of
## the wall, creating the illusion of height without any real 3D geometry.
const WALL_FACE_H: int = 26

const COLOR_BG            := Color(0.02, 0.02, 0.02)   # void / black
const COLOR_FLOOR         := Color(0.28, 0.24, 0.18)   # warm dark stone floor
const COLOR_FLOOR_ALT     := Color(0.24, 0.20, 0.15)   # alternate floor tile
const COLOR_FLOOR_GROUT   := Color(0.14, 0.12, 0.09)   # mortar lines between tiles
const COLOR_FLOOR_SHADOW  := Color(0.13, 0.10, 0.07)   # shadow under south-facing walls
const COLOR_WALL          := Color(0.15, 0.13, 0.11)   # wall body (very dark stone)
const COLOR_WALL_TOP      := Color(0.52, 0.46, 0.35)   # lit top-cap surface
const COLOR_WALL_SIDE     := Color(0.26, 0.22, 0.17)   # side-edge highlight
const COLOR_WALL_FACE     := Color(0.23, 0.19, 0.15)   # south-facing wall face (mid-dark)
const COLOR_WALL_FACE_LIT := Color(0.38, 0.32, 0.24)   # top edge of face (catches light)
const COLOR_WALL_SHADOW   := Color(0.07, 0.06, 0.04)   # shadow edge
const COLOR_DOOR          := Color(0.52, 0.38, 0.22)   # wooden door
const COLOR_DOOR_FRAME    := Color(0.30, 0.22, 0.12)   # door frame

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _dungeon_data: Dictionary = {}
var _room_centers: Array[Vector2] = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Generate and render a dungeon of the given dimensions.
## Returns the raw dungeon_data dict from DungeonGenerator.
func generate(width: int = 50, height: int = 35, seed_val: int = -1) -> Dictionary:
	var gen := DungeonGenerator.new()
	add_child(gen)
	_dungeon_data = gen.generate(width, height, seed_val)
	gen.queue_free()

	# Convert tile-space room centers to world-space pixel positions.
	_room_centers.clear()
	for rc in _dungeon_data.get("room_centers", []):
		_room_centers.append(
			Vector2(rc.x * TILE_SIZE + TILE_SIZE * 0.5,
					rc.y * TILE_SIZE + TILE_SIZE * 0.5)
		)

	_build_wall_collision()
	_bake_texture()
	return _dungeon_data


## World-space position where the player should spawn (first room center).
func get_spawn_position() -> Vector2:
	if _room_centers.size() > 0:
		return _room_centers[0]
	return Vector2(80.0, 80.0)


## World-space position of the exit portal (last room center).
func get_exit_position() -> Vector2:
	if _room_centers.size() > 1:
		return _room_centers[_room_centers.size() - 1]
	return Vector2(720.0, 480.0)


## All room centers in world space, spawn first, exit last.
func get_room_centers() -> Array[Vector2]:
	return _room_centers


## Total dungeon size in pixels.
func get_bounds() -> Vector2:
	var w: int = _dungeon_data.get("width",  0)
	var h: int = _dungeon_data.get("height", 0)
	return Vector2(w * TILE_SIZE, h * TILE_SIZE)

# ---------------------------------------------------------------------------
# Texture baking — bakes all tiles into a single Image then displays
# via Sprite2D. Works on every Godot 4 rendering backend.
# ---------------------------------------------------------------------------

func _bake_texture() -> void:
	var tiles: Array = _dungeon_data.get("tiles", [])
	var w: int       = _dungeon_data.get("width",  0)
	var h: int       = _dungeon_data.get("height", 0)
	if w == 0 or h == 0:
		return

	# Extra pixel rows at the bottom to hold the wall-face overhang of the last row.
	var img := Image.create(w * TILE_SIZE, h * TILE_SIZE + WALL_FACE_H, false, Image.FORMAT_RGB8)
	img.fill(COLOR_BG)

	# -----------------------------------------------------------------------
	# Pass 1 — floors (drawn first; wall faces will correctly overdraw them)
	# -----------------------------------------------------------------------
	for x in range(w):
		for y in range(h):
			if x >= tiles.size() or y >= tiles[x].size():
				continue
			var t: int = tiles[x][y]
			if t != 0 and t != 2:
				continue
			var px := x * TILE_SIZE
			var py := y * TILE_SIZE
			var n_north := _get_tile(tiles, x, y - 1, w, h)
			var n_west  := _get_tile(tiles, x - 1, y, w, h)

			var base_col := COLOR_FLOOR_ALT if (x + y) % 4 == 0 else COLOR_FLOOR
			img.fill_rect(Rect2i(px, py, TILE_SIZE, TILE_SIZE), base_col)
			# Mortar / grout lines between stone tiles
			img.fill_rect(Rect2i(px, py, TILE_SIZE, 1), COLOR_FLOOR_GROUT)
			img.fill_rect(Rect2i(px, py, 1, TILE_SIZE), COLOR_FLOOR_GROUT)
			# Shadow cast onto floor by a wall directly to the north or west
			if n_north == 1:
				img.fill_rect(Rect2i(px, py, TILE_SIZE, 6), COLOR_FLOOR_SHADOW)
			if n_west == 1:
				img.fill_rect(Rect2i(px, py, 4, TILE_SIZE), COLOR_FLOOR_SHADOW)
			# Door tile: wooden plank colour + frame border
			if t == 2:
				img.fill_rect(Rect2i(px, py, TILE_SIZE, TILE_SIZE), COLOR_DOOR)
				img.fill_rect(Rect2i(px,                 py,                 TILE_SIZE, 2), COLOR_DOOR_FRAME)
				img.fill_rect(Rect2i(px,                 py,                 2, TILE_SIZE), COLOR_DOOR_FRAME)
				img.fill_rect(Rect2i(px + TILE_SIZE - 2, py,                 2, TILE_SIZE), COLOR_DOOR_FRAME)
				img.fill_rect(Rect2i(px,                 py + TILE_SIZE - 2, TILE_SIZE, 2), COLOR_DOOR_FRAME)

	# -----------------------------------------------------------------------
	# Pass 2 — walls (after floors; south-face bleeds below tile into floor row)
	# -----------------------------------------------------------------------
	for x in range(w):
		for y in range(h):
			if x >= tiles.size() or y >= tiles[x].size():
				continue
			if tiles[x][y] != 1:
				continue
			var px := x * TILE_SIZE
			var py := y * TILE_SIZE
			var n_south := _get_tile(tiles, x,     y + 1, w, h)
			var n_east  := _get_tile(tiles, x + 1, y,     w, h)
			var n_west  := _get_tile(tiles, x - 1, y,     w, h)

			# --- Wall body (fills the full tile) ---
			img.fill_rect(Rect2i(px, py, TILE_SIZE, TILE_SIZE), COLOR_WALL)

			# Lit top-cap: the horizontal stone surface seen from slightly above.
			img.fill_rect(Rect2i(px, py, TILE_SIZE, WALL_TOP_H), COLOR_WALL_TOP)

			# Side edges of the body
			img.fill_rect(Rect2i(px,                 py + WALL_TOP_H, 2, TILE_SIZE - WALL_TOP_H), COLOR_WALL_SIDE)
			img.fill_rect(Rect2i(px + TILE_SIZE - 2, py + WALL_TOP_H, 2, TILE_SIZE - WALL_TOP_H), COLOR_WALL_SHADOW)
			img.fill_rect(Rect2i(px,                 py + TILE_SIZE - 2, TILE_SIZE, 2), COLOR_WALL_SHADOW)

			# --- South-facing front face ---
			# Extends WALL_FACE_H pixels BELOW the tile boundary, drawing over the
			# floor tile to the south.  This is the core of the raised-block 3D illusion.
			if n_south == 0 or n_south == 2:
				var fy := py + TILE_SIZE   # face starts at the bottom edge of the wall tile
				img.fill_rect(Rect2i(px, fy,                    TILE_SIZE, WALL_FACE_H), COLOR_WALL_FACE)
				# Lit edge at the very top of the face (where it meets the wall body)
				img.fill_rect(Rect2i(px, fy,                    TILE_SIZE, 3), COLOR_WALL_FACE_LIT)
				# Left edge highlight, right/bottom shadows
				img.fill_rect(Rect2i(px,                 fy + 3, 2, WALL_FACE_H - 3), COLOR_WALL_SIDE)
				img.fill_rect(Rect2i(px + TILE_SIZE - 2, fy + 3, 2, WALL_FACE_H - 3), COLOR_WALL_SHADOW)
				img.fill_rect(Rect2i(px,                 fy + WALL_FACE_H - 2, TILE_SIZE, 2), COLOR_WALL_SHADOW)

			# Right-side face when open floor is directly to the east
			if n_east == 0 or n_east == 2:
				img.fill_rect(Rect2i(px + TILE_SIZE - 5, py + WALL_TOP_H, 5, TILE_SIZE - WALL_TOP_H), COLOR_WALL_SIDE)

	# Replace any previous sprite so re-generation works cleanly.
	var old := get_node_or_null("DungeonSprite")
	if old:
		old.queue_free()

	var sprite := Sprite2D.new()
	sprite.name     = "DungeonSprite"
	sprite.texture  = ImageTexture.create_from_image(img)
	sprite.centered = false   # anchor top-left at (0, 0)
	add_child(sprite)


## Returns tile value at (x, y), treating out-of-bounds as wall (1).
func _get_tile(tiles: Array, x: int, y: int, w: int, h: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 1
	if x >= tiles.size() or y >= tiles[x].size():
		return 1
	return tiles[x][y]

# ---------------------------------------------------------------------------
# Collision generation
# ---------------------------------------------------------------------------

## Create a single StaticBody2D whose shapes cover every wall/empty tile.
## Adjacent wall tiles in the same column are merged into one shape to keep
## the physics body lean.
func _build_wall_collision() -> void:
	var tiles: Array = _dungeon_data.get("tiles", [])
	var w: int       = _dungeon_data.get("width",  0)
	var h: int       = _dungeon_data.get("height", 0)

	# Remove any previous collision body so re-generation works cleanly.
	var old_body := get_node_or_null("WallCollision")
	if old_body:
		old_body.queue_free()

	var body := StaticBody2D.new()
	body.name             = "WallCollision"
	body.collision_layer  = 1
	body.collision_mask   = 0
	add_child(body)

	# Iterate by column; merge consecutive solid tiles into one tall rectangle.
	for x in range(w):
		var run_start: int = -1
		for y in range(h + 1):          # +1 to flush any open run at the end
			var solid: bool = false
			if y < h:
				if x < tiles.size() and y < tiles[x].size():
					var v: int = tiles[x][y]
					solid = (v == 1 or v == -1)   # wall or empty

			if solid and run_start == -1:
				run_start = y
			elif not solid and run_start != -1:
				# Emit one rectangle for the run [run_start .. y-1]
				var run_len: int = y - run_start
				var shape := CollisionShape2D.new()
				var rs    := RectangleShape2D.new()
				rs.size        = Vector2(TILE_SIZE, run_len * TILE_SIZE)
				shape.shape    = rs
				shape.position = Vector2(
					x * TILE_SIZE + TILE_SIZE * 0.5,
					(run_start + run_len * 0.5) * TILE_SIZE
				)
				body.add_child(shape)
				run_start = -1
