#!/usr/bin/env python3
"""
validate_data.py - Validates all game data JSON files in data/ against their schemas.

Usage:
    python tools/validate_data.py

Exits with code 1 if any validation fails (suitable for CI).
"""

import json
import os
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_json(path: Path):
    """Load and return a JSON file, or raise ValueError with context on failure."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON: {exc}") from exc


def check_fields(data: dict, required: dict, path: str) -> list[str]:
    """
    Validate required fields and their types.

    `required` maps field_name -> expected type (or tuple of types).
    Returns a list of error strings (empty = all OK).
    """
    errors = []
    for field, expected_type in required.items():
        if field not in data:
            errors.append(f"Missing required field '{field}'")
        elif expected_type is not None:
            value = data[field]
            # Allow None values when expected type includes None
            if isinstance(expected_type, tuple):
                if not isinstance(value, expected_type) and value is not None:
                    errors.append(
                        f"Field '{field}' has type {type(value).__name__}, "
                        f"expected {' or '.join(t.__name__ for t in expected_type if isinstance(t, type))}"
                    )
            else:
                if value is not None and not isinstance(value, expected_type):
                    errors.append(
                        f"Field '{field}' has type {type(value).__name__}, "
                        f"expected {expected_type.__name__}"
                    )
    return errors


# ---------------------------------------------------------------------------
# Schema validators – each returns a list of error strings
# ---------------------------------------------------------------------------

STAT_NAMES_BASE = {"hp", "mana", "strength", "dexterity", "intelligence", "vitality"}

RACE_REQUIRED = {
    "id": str,
    "name": str,
    "description": str,
    "base_stats": dict,
    "stat_growth": dict,
    "traits": list,
    "allowed_classes": list,
}

CLASS_REQUIRED = {
    "id": str,
    "name": str,
    "description": str,
    "stat_modifiers": dict,
    "starting_spells": list,
    "starting_items": list,
}

ITEM_REQUIRED = {
    "id": str,
    "name": str,
    "description": str,
    "type": str,
    "rarity": str,
    "value": (int, float),
    "stats": dict,
    "requirements": dict,
    "stackable": bool,
    "max_stack": int,
}

VALID_ITEM_TYPES = {"weapon", "armor", "consumable", "accessory", "misc"}
VALID_RARITIES = {"common", "uncommon", "rare", "epic", "legendary"}

SPELL_REQUIRED = {
    "id": str,
    "name": str,
    "description": str,
    "type": str,
    "mana_cost": (int, float),
    "cooldown": (int, float),
    "range": (int, float),
    "cast_time": (int, float),
}

VALID_SPELL_TYPES = {"damage", "heal", "debuff", "buff", "utility"}

ENEMY_REQUIRED = {
    "id": str,
    "name": str,
    "description": str,
    "level": int,
    "stats": dict,
    "xp_reward": (int, float),
    "gold_drop": dict,
    "loot_table": list,
    "ai": str,
}

ENEMY_STAT_REQUIRED = {
    "hp": (int, float),
    "attack": (int, float),
    "defense": (int, float),
    "speed": (int, float),
    "aggro_range": (int, float),
    "attack_range": (int, float),
    "attack_speed": (int, float),
}

SHOP_REQUIRED = {
    "id": str,
    "name": str,
    "description": str,
    "inventory": list,
    "buy_multiplier": (int, float),
    "restock_interval_seconds": (int, float),
}


def validate_race(data: dict) -> list[str]:
    errors = check_fields(data, RACE_REQUIRED, "race")
    if "base_stats" in data and isinstance(data["base_stats"], dict):
        for stat in STAT_NAMES_BASE:
            if stat not in data["base_stats"]:
                errors.append(f"base_stats missing '{stat}'")
    if "stat_growth" in data and isinstance(data["stat_growth"], dict):
        for stat in STAT_NAMES_BASE:
            if stat not in data["stat_growth"]:
                errors.append(f"stat_growth missing '{stat}'")
    return errors


def validate_class(data: dict) -> list[str]:
    errors = check_fields(data, CLASS_REQUIRED, "class")
    if "starting_items" in data and not isinstance(data["starting_items"], list):
        errors.append("starting_items must be a list")
    if "starting_spells" in data and not isinstance(data["starting_spells"], list):
        errors.append("starting_spells must be a list")
    return errors


def validate_item(data: dict) -> list[str]:
    errors = check_fields(data, ITEM_REQUIRED, "item")
    # slot can be null for consumables
    if "slot" not in data:
        errors.append("Missing required field 'slot'")
    if "type" in data and data["type"] not in VALID_ITEM_TYPES:
        errors.append(f"Invalid item type '{data['type']}'. Must be one of {sorted(VALID_ITEM_TYPES)}")
    if "rarity" in data and data["rarity"] not in VALID_RARITIES:
        errors.append(f"Invalid rarity '{data['rarity']}'. Must be one of {sorted(VALID_RARITIES)}")
    if "stackable" in data and "max_stack" in data:
        if not data["stackable"] and data["max_stack"] != 1:
            errors.append("Non-stackable item must have max_stack=1")
    if "type" in data and data["type"] == "consumable":
        if "effect" not in data:
            errors.append("Consumable item missing required 'effect' field")
        elif not isinstance(data["effect"], dict):
            errors.append("'effect' field must be an object")
        else:
            if "type" not in data["effect"]:
                errors.append("'effect' missing 'type' field")
            if "amount" not in data["effect"]:
                errors.append("'effect' missing 'amount' field")
    return errors


def validate_spell(data: dict) -> list[str]:
    errors = check_fields(data, SPELL_REQUIRED, "spell")
    spell_type = data.get("type")
    if spell_type and spell_type not in VALID_SPELL_TYPES:
        errors.append(f"Invalid spell type '{spell_type}'. Must be one of {sorted(VALID_SPELL_TYPES)}")
    if spell_type == "damage":
        for field in ("damage", "damage_type"):
            if field not in data:
                errors.append(f"Damage spell missing required field '{field}'")
    if spell_type == "heal":
        if "heal_amount" not in data:
            errors.append("Heal spell missing required field 'heal_amount'")
    if spell_type in ("debuff", "buff", "utility"):
        if "effect" not in data:
            errors.append(f"Spell type '{spell_type}' missing required 'effect' field")
        elif not isinstance(data["effect"], dict):
            errors.append("'effect' must be an object")
    return errors


def validate_enemy(data: dict) -> list[str]:
    errors = check_fields(data, ENEMY_REQUIRED, "enemy")
    if "stats" in data and isinstance(data["stats"], dict):
        for stat, stype in ENEMY_STAT_REQUIRED.items():
            if stat not in data["stats"]:
                errors.append(f"Enemy stats missing '{stat}'")
            elif not isinstance(data["stats"][stat], stype):
                errors.append(
                    f"Enemy stat '{stat}' has type {type(data['stats'][stat]).__name__}, "
                    f"expected numeric"
                )
    if "gold_drop" in data and isinstance(data["gold_drop"], dict):
        for key in ("min", "max"):
            if key not in data["gold_drop"]:
                errors.append(f"gold_drop missing '{key}'")
    if "loot_table" in data and isinstance(data["loot_table"], list):
        for i, entry in enumerate(data["loot_table"]):
            if not isinstance(entry, dict):
                errors.append(f"loot_table[{i}] must be an object")
                continue
            if "item_id" not in entry:
                errors.append(f"loot_table[{i}] missing 'item_id'")
            if "chance" not in entry:
                errors.append(f"loot_table[{i}] missing 'chance'")
            elif not isinstance(entry["chance"], (int, float)) or not (0.0 <= entry["chance"] <= 1.0):
                errors.append(f"loot_table[{i}] 'chance' must be a float between 0 and 1")
    return errors


def validate_shop(data: dict) -> list[str]:
    errors = check_fields(data, SHOP_REQUIRED, "shop")
    if "inventory" in data and isinstance(data["inventory"], list):
        for i, entry in enumerate(data["inventory"]):
            if not isinstance(entry, dict):
                errors.append(f"inventory[{i}] must be an object")
                continue
            if "item_id" not in entry:
                errors.append(f"inventory[{i}] missing 'item_id'")
            if "stock" not in entry:
                errors.append(f"inventory[{i}] missing 'stock'")
            elif not isinstance(entry["stock"], int):
                errors.append(f"inventory[{i}] 'stock' must be an integer (-1 for unlimited)")
            if "price_multiplier" not in entry:
                errors.append(f"inventory[{i}] missing 'price_multiplier'")
            elif not isinstance(entry["price_multiplier"], (int, float)):
                errors.append(f"inventory[{i}] 'price_multiplier' must be numeric")
    return errors


# ---------------------------------------------------------------------------
# Cross-reference validation
# ---------------------------------------------------------------------------

def collect_ids(data_root: Path, subdir: str) -> set[str]:
    """Return the set of IDs found in all JSON files under data_root/subdir."""
    ids = set()
    folder = data_root / subdir
    if not folder.is_dir():
        return ids
    for path in folder.glob("*.json"):
        try:
            obj = load_json(path)
            if isinstance(obj, dict) and "id" in obj:
                ids.add(obj["id"])
        except ValueError:
            pass
    return ids


def validate_cross_references(data_root: Path) -> list[str]:
    """Validate that all referenced IDs actually exist in the appropriate data folders."""
    errors = []

    item_ids = collect_ids(data_root, "items")
    spell_ids = collect_ids(data_root, "spells")
    class_ids = collect_ids(data_root, "classes")

    # Check class starting_items and starting_spells
    for path in (data_root / "classes").glob("*.json"):
        try:
            obj = load_json(path)
        except ValueError:
            continue
        for item_ref in obj.get("starting_items", []):
            if item_ref not in item_ids:
                errors.append(f"{path.name}: starting_items references unknown item '{item_ref}'")
        for spell_ref in obj.get("starting_spells", []):
            if spell_ref not in spell_ids:
                errors.append(f"{path.name}: starting_spells references unknown spell '{spell_ref}'")

    # Check race allowed_classes
    for path in (data_root / "races").glob("*.json"):
        try:
            obj = load_json(path)
        except ValueError:
            continue
        for cls_ref in obj.get("allowed_classes", []):
            if cls_ref not in class_ids:
                errors.append(f"{path.name}: allowed_classes references unknown class '{cls_ref}'")

    # Check enemy loot_table item_ids
    for path in (data_root / "enemies").glob("*.json"):
        try:
            obj = load_json(path)
        except ValueError:
            continue
        for entry in obj.get("loot_table", []):
            if isinstance(entry, dict) and "item_id" in entry:
                if entry["item_id"] not in item_ids:
                    errors.append(
                        f"{path.name}: loot_table references unknown item '{entry['item_id']}'"
                    )

    # Check shop inventory item_ids
    for path in (data_root / "shops").glob("*.json"):
        try:
            obj = load_json(path)
        except ValueError:
            continue
        for entry in obj.get("inventory", []):
            if isinstance(entry, dict) and "item_id" in entry:
                if entry["item_id"] not in item_ids:
                    errors.append(
                        f"{path.name}: inventory references unknown item '{entry['item_id']}'"
                    )

    return errors


# ---------------------------------------------------------------------------
# Main runner
# ---------------------------------------------------------------------------

SCHEMA_MAP = {
    "races": validate_race,
    "classes": validate_class,
    "items": validate_item,
    "spells": validate_spell,
    "enemies": validate_enemy,
    "shops": validate_shop,
}


def run_validation(data_root: Path) -> bool:
    """
    Validate all JSON files under data_root.

    Returns True if everything passes, False otherwise.
    Prints PASS/FAIL per file and a summary.
    """
    all_passed = True

    # Per-file schema validation
    for category, validator in SCHEMA_MAP.items():
        folder = data_root / category
        if not folder.is_dir():
            print(f"  WARNING: Directory '{folder}' not found, skipping.")
            continue
        json_files = sorted(folder.glob("*.json"))
        if not json_files:
            print(f"  WARNING: No JSON files found in '{folder}'.")
        for path in json_files:
            rel = path.relative_to(data_root.parent)
            try:
                data = load_json(path)
            except ValueError as exc:
                print(f"  FAIL  {rel}: {exc}")
                all_passed = False
                continue
            errors = validator(data)
            if errors:
                all_passed = False
                print(f"  FAIL  {rel}:")
                for err in errors:
                    print(f"          - {err}")
            else:
                print(f"  PASS  {rel}")

    # Cross-reference validation
    print()
    print("Cross-reference checks:")
    xref_errors = validate_cross_references(data_root)
    if xref_errors:
        all_passed = False
        for err in xref_errors:
            print(f"  FAIL  {err}")
    else:
        print("  PASS  All cross-references resolved.")

    return all_passed


def main(data_root: Path | None = None) -> int:
    if data_root is None:
        # Default: data/ relative to the repo root (one level up from this script)
        script_dir = Path(__file__).resolve().parent
        data_root = script_dir.parent / "data"

    print(f"Validating game data in: {data_root}")
    print("=" * 60)

    passed = run_validation(data_root)

    print()
    print("=" * 60)
    if passed:
        print("RESULT: ALL CHECKS PASSED")
        return 0
    else:
        print("RESULT: VALIDATION FAILED")
        return 1


if __name__ == "__main__":
    sys.exit(main())
