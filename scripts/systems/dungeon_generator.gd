## BSP Procedural Dungeon Generator
## Produces a Dictionary describing a dungeon layout for floor 2+.
## Suitable for stamping into a TileMapLayer.
class_name DungeonGenerator
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const MIN_ROOM_SIZE: int = 6
const MAX_ROOM_SIZE: int = 16
const MIN_SPLIT_SIZE: int = 14
const TILE_FLOOR: int = 0
const TILE_WALL: int = 1
const TILE_DOOR: int = 2
const TILE_EMPTY: int = -1

# ---------------------------------------------------------------------------
# BSPNode inner class
# ---------------------------------------------------------------------------
class BSPNode:
	var rect: Rect2i
	var left: BSPNode
	var right: BSPNode
	var room: Rect2i
	var is_leaf: bool = false

	func _init(r: Rect2i) -> void:
		rect = r

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var _tiles: Array = []
var _rooms: Array[Rect2i] = []
var _corridors: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Generate a dungeon of the given dimensions.
## Returns a Dictionary with keys: width, height, seed, tiles, rooms,
## corridors, spawn_room, exit_room, room_centers.
func generate(width: int, height: int, seed: int = -1) -> Dictionary:
	var seed_used: int = seed if seed != -1 else randi()
	_rng.seed = seed_used

	# Reset state
	_rooms.clear()
	_corridors.clear()
	_init_grid(width, height)

	# Build BSP tree
	var root := BSPNode.new(Rect2i(0, 0, width, height))
	_split(root, 0)
	_create_rooms(root)
	_connect_rooms(root)

	# Determine spawn / exit
	_find_spawn_and_exit()

	var spawn_room: Rect2i = _rooms[0] if _rooms.size() > 0 else Rect2i()
	var exit_room: Rect2i = _rooms[_rooms.size() - 1] if _rooms.size() > 1 else spawn_room

	var room_centers: Array[Vector2i] = []
	for r in _rooms:
		room_centers.append(r.get_center())

	return {
		"width": width,
		"height": height,
		"seed": seed_used,
		"tiles": _tiles,
		"rooms": _rooms.duplicate(),
		"corridors": _corridors.duplicate(),
		"spawn_room": spawn_room,
		"exit_room": exit_room,
		"room_centers": room_centers,
	}

# ---------------------------------------------------------------------------
# BSP splitting
# ---------------------------------------------------------------------------

func _split(node: BSPNode, depth: int) -> void:
	# Stop conditions: too small or too deep
	if depth > 5:
		node.is_leaf = true
		return
	if node.rect.size.x < MIN_SPLIT_SIZE * 2 and node.rect.size.y < MIN_SPLIT_SIZE * 2:
		node.is_leaf = true
		return

	# Bias toward splitting the longer axis
	var split_horizontal: bool
	if node.rect.size.x < MIN_SPLIT_SIZE * 2:
		split_horizontal = true
	elif node.rect.size.y < MIN_SPLIT_SIZE * 2:
		split_horizontal = false
	else:
		split_horizontal = _rng.randi() % 2 == 0

	if split_horizontal:
		# Split along Y axis
		var min_split: int = node.rect.position.y + MIN_SPLIT_SIZE
		var max_split: int = node.rect.position.y + node.rect.size.y - MIN_SPLIT_SIZE
		if max_split <= min_split:
			node.is_leaf = true
			return
		var split_y: int = min_split + _rng.randi() % (max_split - min_split + 1)
		node.left = BSPNode.new(Rect2i(
			node.rect.position.x,
			node.rect.position.y,
			node.rect.size.x,
			split_y - node.rect.position.y
		))
		node.right = BSPNode.new(Rect2i(
			node.rect.position.x,
			split_y,
			node.rect.size.x,
			node.rect.position.y + node.rect.size.y - split_y
		))
	else:
		# Split along X axis
		var min_split: int = node.rect.position.x + MIN_SPLIT_SIZE
		var max_split: int = node.rect.position.x + node.rect.size.x - MIN_SPLIT_SIZE
		if max_split <= min_split:
			node.is_leaf = true
			return
		var split_x: int = min_split + _rng.randi() % (max_split - min_split + 1)
		node.left = BSPNode.new(Rect2i(
			node.rect.position.x,
			node.rect.position.y,
			split_x - node.rect.position.x,
			node.rect.size.y
		))
		node.right = BSPNode.new(Rect2i(
			split_x,
			node.rect.position.y,
			node.rect.position.x + node.rect.size.x - split_x,
			node.rect.size.y
		))

	_split(node.left, depth + 1)
	_split(node.right, depth + 1)

# ---------------------------------------------------------------------------
# Room creation
# ---------------------------------------------------------------------------

func _create_rooms(node: BSPNode) -> void:
	if node.is_leaf:
		# Determine room dimensions, clamped to leaf size minus a border
		var max_w: int = min(MAX_ROOM_SIZE, node.rect.size.x - 2)
		var max_h: int = min(MAX_ROOM_SIZE, node.rect.size.y - 2)
		if max_w < MIN_ROOM_SIZE or max_h < MIN_ROOM_SIZE:
			# Leaf too small to fit even a minimum room; skip
			node.room = Rect2i()
			return
		var room_w: int = MIN_ROOM_SIZE + _rng.randi() % (max_w - MIN_ROOM_SIZE + 1)
		var room_h: int = MIN_ROOM_SIZE + _rng.randi() % (max_h - MIN_ROOM_SIZE + 1)

		# Random offset within the leaf, keeping at least 1-tile border
		var offset_x_max: int = node.rect.size.x - room_w - 1
		var offset_y_max: int = node.rect.size.y - room_h - 1
		var offset_x: int = 1 + (_rng.randi() % max(1, offset_x_max))
		var offset_y: int = 1 + (_rng.randi() % max(1, offset_y_max))

		var room := Rect2i(
			node.rect.position.x + offset_x,
			node.rect.position.y + offset_y,
			room_w,
			room_h
		)
		node.room = room
		_carve_room(room)
		_rooms.append(room)
	else:
		if node.left != null:
			_create_rooms(node.left)
		if node.right != null:
			_create_rooms(node.right)
		# Propagate a room rect up so _connect_rooms can use it
		# Use left child's room if available, otherwise right
		var left_room: Rect2i = _get_room(node.left)
		var right_room: Rect2i = _get_room(node.right)
		if left_room != Rect2i():
			node.room = left_room
		else:
			node.room = right_room

# Helper: walk down to find a valid room rect
func _get_room(node: BSPNode) -> Rect2i:
	if node == null:
		return Rect2i()
	if node.is_leaf:
		return node.room
	var r: Rect2i = _get_room(node.left)
	if r != Rect2i():
		return r
	return _get_room(node.right)

# ---------------------------------------------------------------------------
# Corridor connection
# ---------------------------------------------------------------------------

func _connect_rooms(node: BSPNode) -> void:
	if node.is_leaf:
		return
	if node.left != null:
		_connect_rooms(node.left)
	if node.right != null:
		_connect_rooms(node.right)

	# Connect the rooms belonging to left and right children
	if node.left == null or node.right == null:
		return
	var left_room: Rect2i = _get_room(node.left)
	var right_room: Rect2i = _get_room(node.right)
	if left_room == Rect2i() or right_room == Rect2i():
		return

	var from: Vector2i = left_room.get_center()
	var to: Vector2i = right_room.get_center()
	_carve_corridor(from, to)
	_corridors.append([from, to])

# ---------------------------------------------------------------------------
# Tile manipulation
# ---------------------------------------------------------------------------

func _init_grid(w: int, h: int) -> void:
	_tiles = []
	for x in range(w):
		var col: Array = []
		col.resize(h)
		col.fill(TILE_WALL)
		_tiles.append(col)

## Carve a room: interior = TILE_FLOOR, border = TILE_WALL (border is already
## TILE_WALL from _init_grid, so we only need to set floor tiles inside).
func _carve_room(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			if not _in_bounds(x, y):
				continue
			# Determine if this tile is on the border of the room
			var on_border: bool = (
				x == rect.position.x
				or x == rect.position.x + rect.size.x - 1
				or y == rect.position.y
				or y == rect.position.y + rect.size.y - 1
			)
			if on_border:
				_tiles[x][y] = TILE_WALL
			else:
				_tiles[x][y] = TILE_FLOOR

## Carve an L-shaped corridor 2 tiles wide from `from` to `to`.
func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	# Horizontal segment first, then vertical (L-shape)
	var min_x: int = min(from.x, to.x)
	var max_x: int = max(from.x, to.x)
	for x in range(min_x, max_x + 1):
		for dy in range(-1, 2):
			var ty: int = from.y + dy
			if _in_bounds(x, ty) and _tiles[x][ty] != TILE_FLOOR:
				_tiles[x][ty] = TILE_FLOOR

	var min_y: int = min(from.y, to.y)
	var max_y: int = max(from.y, to.y)
	for y in range(min_y, max_y + 1):
		for dx in range(-1, 2):
			var tx: int = to.x + dx
			if _in_bounds(tx, y) and _tiles[tx][y] != TILE_FLOOR:
				_tiles[tx][y] = TILE_FLOOR

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _tiles.size() and (_tiles.size() > 0 and y < _tiles[0].size())

## Get tile value at (x, y). Returns TILE_EMPTY if out of bounds.
func get_tile(x: int, y: int) -> int:
	if not _in_bounds(x, y):
		return TILE_EMPTY
	return _tiles[x][y]

# ---------------------------------------------------------------------------
# Spawn / exit determination
# ---------------------------------------------------------------------------

func _find_spawn_and_exit() -> void:
	if _rooms.size() < 2:
		return
	# spawn = first room (already _rooms[0])
	# exit = room furthest from spawn by center distance
	var spawn_center: Vector2i = _rooms[0].get_center()
	var furthest_idx: int = 1
	var furthest_dist: float = 0.0
	for i in range(1, _rooms.size()):
		var d: float = spawn_center.distance_to(_rooms[i].get_center())
		if d > furthest_dist:
			furthest_dist = d
			furthest_idx = i
	# Move the furthest room to the end of _rooms so generate() picks it up
	var exit_room: Rect2i = _rooms[furthest_idx]
	_rooms.remove_at(furthest_idx)
	_rooms.append(exit_room)
