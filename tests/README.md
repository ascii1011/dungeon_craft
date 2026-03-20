# DungeonCraft Tests

Unit tests for DungeonCraft are written with the [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) framework.

---

## 1. Install GUT in the Godot Editor

**Option A — Asset Library (recommended)**

1. Open the Godot project in the editor.
2. Go to **AssetLib** tab (top-center).
3. Search for **GUT - Godot Unit Testing**.
4. Click **Download**, then **Install**.
5. Enable the plugin: **Project → Project Settings → Plugins → GUT → Enable**.

**Option B — Manual install**

1. Download the latest GUT 7.4.x release zip from https://github.com/bitwes/Gut/releases.
2. Extract the zip and copy the `addons/gut/` folder into your project's `addons/` directory.
3. Enable the plugin as described in Option A, step 5.

---

## 2. Run Tests in the Editor

Once the plugin is enabled, a **GUT** panel appears at the bottom of the editor.

1. Open the GUT panel.
2. Set **Tests Directory** to `res://tests/unit/` (or click **Add Directory**).
3. Click **Run All** to execute every test, or select individual test scripts and click **Run Selected**.

Results are displayed in the GUT panel with pass/fail counts and any assertion failures.

---

## 3. Run Tests Headless from the Command Line

Use the Godot headless binary with the GUT command-line runner. This is the same command used in CI:

```bash
./Godot_v4.3-stable_linux.x86_64 \
  --headless \
  --path . \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests/unit/ \
  -gexit
```

**Parameters:**

| Flag | Purpose |
|---|---|
| `--headless` | Run without a display (no GPU required) |
| `--path .` | Set the Godot project root to the current directory |
| `-s addons/gut/gut_cmdln.gd` | Use GUT's command-line script |
| `-gdir=res://tests/unit/` | Directory to scan for test scripts |
| `-gexit` | Exit Godot automatically when tests finish |

The process exits with code `0` on success and non-zero on failure, making it suitable for CI gates.

---

## 4. Writing New Tests — GUT Cheatsheet

### File naming and location

- Place test files under `tests/unit/`.
- Name files with the prefix `test_`, e.g. `test_player.gd`.

### Basic structure

```gdscript
extends GutTest

# Called once before all tests in this file
func before_all():
    pass

# Called before each individual test
func before_each():
    pass

# Called after each individual test
func after_each():
    pass

# Called once after all tests in this file
func after_all():
    pass

# Every test function must start with "test_"
func test_example():
    assert_eq(1 + 1, 2, "Basic arithmetic should work")
```

### Common assertions

| Assertion | Description |
|---|---|
| `assert_eq(got, expected, msg?)` | Assert two values are equal |
| `assert_ne(got, not_expected, msg?)` | Assert two values are not equal |
| `assert_true(value, msg?)` | Assert value is truthy |
| `assert_false(value, msg?)` | Assert value is falsy |
| `assert_not_null(value, msg?)` | Assert value is not null |
| `assert_null(value, msg?)` | Assert value is null |
| `assert_gt(got, expected, msg?)` | Assert got > expected |
| `assert_lt(got, expected, msg?)` | Assert got < expected |
| `assert_has(collection, value, msg?)` | Assert collection contains value |
| `assert_does_not_have(collection, value, msg?)` | Assert collection does not contain value |
| `assert_almost_eq(got, expected, tolerance, msg?)` | Assert float equality within tolerance |

### Testing nodes

```gdscript
extends GutTest

var _player: Node

func before_each():
    _player = preload("res://scenes/player.tscn").instantiate()
    add_child(_player)

func after_each():
    _player.queue_free()

func test_player_initial_health():
    assert_eq(_player.health, 100, "Player should start with 100 HP")

func test_player_takes_damage():
    _player.take_damage(30)
    assert_eq(_player.health, 70, "Player health should decrease by damage amount")
```

### Doubling (mocking)

```gdscript
func test_with_double():
    var enemy_double = double(Enemy).new()
    stub(enemy_double, "get_attack_power").to_return(10)
    assert_eq(enemy_double.get_attack_power(), 10)
```

For full documentation see https://gut.readthedocs.io/.
