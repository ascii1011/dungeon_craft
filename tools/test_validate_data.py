#!/usr/bin/env python3
"""
test_validate_data.py - Unit tests for validate_data.py

Run with:
    python -m pytest tools/test_validate_data.py -v
    python -m unittest tools/test_validate_data.py
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

# Ensure the tools/ directory is on the path so we can import validate_data
sys.path.insert(0, str(Path(__file__).resolve().parent))

from validate_data import (
    validate_class,
    validate_enemy,
    validate_item,
    validate_race,
    validate_shop,
    validate_spell,
    validate_cross_references,
    run_validation,
    load_json,
)


# ---------------------------------------------------------------------------
# Fixtures – minimal valid objects for each schema type
# ---------------------------------------------------------------------------

def valid_race() -> dict:
    return {
        "id": "human",
        "name": "Human",
        "description": "A human.",
        "base_stats": {
            "hp": 100, "mana": 80, "strength": 10,
            "dexterity": 10, "intelligence": 10, "vitality": 10,
        },
        "stat_growth": {
            "hp": 8, "mana": 5, "strength": 1,
            "dexterity": 1, "intelligence": 1, "vitality": 1,
        },
        "traits": ["adaptable"],
        "allowed_classes": ["warrior"],
    }


def valid_class() -> dict:
    return {
        "id": "warrior",
        "name": "Warrior",
        "description": "A fighter.",
        "stat_modifiers": {"strength": 3, "vitality": 2, "intelligence": -1},
        "starting_spells": [],
        "starting_items": ["sword_iron"],
    }


def valid_item_weapon() -> dict:
    return {
        "id": "sword_iron",
        "name": "Iron Sword",
        "description": "A sword.",
        "type": "weapon",
        "slot": "weapon",
        "rarity": "common",
        "value": 50,
        "stats": {"attack": 8, "attack_speed": 1.2},
        "requirements": {"strength": 5},
        "stackable": False,
        "max_stack": 1,
    }


def valid_item_consumable() -> dict:
    return {
        "id": "potion_health",
        "name": "Health Potion",
        "description": "Restores health.",
        "type": "consumable",
        "slot": None,
        "rarity": "common",
        "value": 25,
        "stats": {},
        "requirements": {},
        "effect": {"type": "heal", "amount": 50},
        "stackable": True,
        "max_stack": 10,
    }


def valid_spell_damage() -> dict:
    return {
        "id": "fireball",
        "name": "Fireball",
        "description": "A fireball.",
        "type": "damage",
        "mana_cost": 25,
        "cooldown": 2.0,
        "range": 300,
        "damage": 45,
        "damage_type": "fire",
        "area_radius": 80,
        "cast_time": 0.5,
        "projectile_speed": 400,
    }


def valid_spell_heal() -> dict:
    return {
        "id": "heal",
        "name": "Heal",
        "description": "Restores health.",
        "type": "heal",
        "mana_cost": 20,
        "cooldown": 3.0,
        "range": 0,
        "heal_amount": 40,
        "cast_time": 0.8,
    }


def valid_spell_debuff() -> dict:
    return {
        "id": "slow",
        "name": "Slow",
        "description": "Slows a target.",
        "type": "debuff",
        "mana_cost": 15,
        "cooldown": 4.0,
        "range": 250,
        "cast_time": 0.3,
        "effect": {"movement_speed_mult": 0.5, "duration": 3.0},
    }


def valid_enemy() -> dict:
    return {
        "id": "goblin",
        "name": "Goblin",
        "description": "A goblin.",
        "level": 1,
        "stats": {
            "hp": 30, "attack": 5, "defense": 2, "speed": 80,
            "aggro_range": 150, "attack_range": 40, "attack_speed": 1.5,
        },
        "xp_reward": 10,
        "gold_drop": {"min": 1, "max": 5},
        "loot_table": [{"item_id": "potion_health", "chance": 0.15}],
        "ai": "melee_chase",
    }


def valid_shop() -> dict:
    return {
        "id": "blacksmith",
        "name": "Blacksmith",
        "description": "A blacksmith.",
        "inventory": [
            {"item_id": "sword_iron", "stock": -1, "price_multiplier": 1.0},
        ],
        "buy_multiplier": 0.4,
        "restock_interval_seconds": 300,
    }


# ---------------------------------------------------------------------------
# Helper to build a temporary data directory
# ---------------------------------------------------------------------------

def build_data_dir(tmp: Path, overrides: dict | None = None) -> Path:
    """
    Write a complete, valid set of data files to tmp/data/.
    `overrides` is a dict of relative paths (e.g. 'items/sword_iron.json') -> dict to
    replace the default content, or None to skip writing that file.
    """
    overrides = overrides or {}
    defaults = {
        "races/human.json": valid_race(),
        "classes/warrior.json": valid_class(),
        "items/sword_iron.json": valid_item_weapon(),
        "items/potion_health.json": valid_item_consumable(),
        "spells/fireball.json": valid_spell_damage(),
        "enemies/goblin.json": valid_enemy(),
        "shops/blacksmith.json": valid_shop(),
    }
    data_root = tmp / "data"
    for rel, content in defaults.items():
        if rel in overrides:
            content = overrides[rel]
        if content is None:
            continue  # skip this file
        dest = data_root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(content), encoding="utf-8")
    # Ensure all category directories exist (even if empty)
    for cat in ("races", "classes", "items", "spells", "enemies", "shops"):
        (data_root / cat).mkdir(parents=True, exist_ok=True)
    return data_root


# ---------------------------------------------------------------------------
# Tests: individual schema validators
# ---------------------------------------------------------------------------

class TestValidRacePass(unittest.TestCase):
    def test_valid_race_passes(self):
        errors = validate_race(valid_race())
        self.assertEqual(errors, [], f"Expected no errors, got: {errors}")


class TestRaceMissingField(unittest.TestCase):
    def test_missing_description(self):
        data = valid_race()
        del data["description"]
        errors = validate_race(data)
        self.assertTrue(any("description" in e for e in errors))

    def test_missing_base_stats(self):
        data = valid_race()
        del data["base_stats"]
        errors = validate_race(data)
        self.assertTrue(any("base_stats" in e for e in errors))

    def test_base_stats_missing_stat(self):
        data = valid_race()
        del data["base_stats"]["mana"]
        errors = validate_race(data)
        self.assertTrue(any("mana" in e for e in errors))

    def test_missing_allowed_classes(self):
        data = valid_race()
        del data["allowed_classes"]
        errors = validate_race(data)
        self.assertTrue(any("allowed_classes" in e for e in errors))


class TestRaceWrongType(unittest.TestCase):
    def test_name_wrong_type(self):
        data = valid_race()
        data["name"] = 42
        errors = validate_race(data)
        self.assertTrue(any("name" in e for e in errors))

    def test_traits_wrong_type(self):
        data = valid_race()
        data["traits"] = "adaptable"  # should be a list
        errors = validate_race(data)
        self.assertTrue(any("traits" in e for e in errors))


class TestValidClassPass(unittest.TestCase):
    def test_valid_class_passes(self):
        errors = validate_class(valid_class())
        self.assertEqual(errors, [])


class TestClassMissingField(unittest.TestCase):
    def test_missing_stat_modifiers(self):
        data = valid_class()
        del data["stat_modifiers"]
        errors = validate_class(data)
        self.assertTrue(any("stat_modifiers" in e for e in errors))

    def test_missing_starting_items(self):
        data = valid_class()
        del data["starting_items"]
        errors = validate_class(data)
        self.assertTrue(any("starting_items" in e for e in errors))


class TestClassWrongType(unittest.TestCase):
    def test_starting_spells_wrong_type(self):
        data = valid_class()
        data["starting_spells"] = "fireball"
        errors = validate_class(data)
        self.assertTrue(any("starting_spells" in e for e in errors))


class TestValidItemPass(unittest.TestCase):
    def test_valid_weapon_passes(self):
        self.assertEqual(validate_item(valid_item_weapon()), [])

    def test_valid_consumable_passes(self):
        self.assertEqual(validate_item(valid_item_consumable()), [])


class TestItemMissingField(unittest.TestCase):
    def test_missing_type(self):
        data = valid_item_weapon()
        del data["type"]
        errors = validate_item(data)
        self.assertTrue(any("type" in e for e in errors))

    def test_missing_slot(self):
        data = valid_item_weapon()
        del data["slot"]
        errors = validate_item(data)
        self.assertTrue(any("slot" in e for e in errors))

    def test_missing_rarity(self):
        data = valid_item_weapon()
        del data["rarity"]
        errors = validate_item(data)
        self.assertTrue(any("rarity" in e for e in errors))

    def test_consumable_missing_effect(self):
        data = valid_item_consumable()
        del data["effect"]
        errors = validate_item(data)
        self.assertTrue(any("effect" in e for e in errors))


class TestItemWrongType(unittest.TestCase):
    def test_value_wrong_type(self):
        data = valid_item_weapon()
        data["value"] = "fifty"
        errors = validate_item(data)
        self.assertTrue(any("value" in e for e in errors))

    def test_stackable_wrong_type(self):
        data = valid_item_weapon()
        data["stackable"] = "no"
        errors = validate_item(data)
        self.assertTrue(any("stackable" in e for e in errors))

    def test_invalid_item_type(self):
        data = valid_item_weapon()
        data["type"] = "magic_thing"
        errors = validate_item(data)
        self.assertTrue(any("Invalid item type" in e for e in errors))

    def test_invalid_rarity(self):
        data = valid_item_weapon()
        data["rarity"] = "super_duper"
        errors = validate_item(data)
        self.assertTrue(any("Invalid rarity" in e for e in errors))

    def test_non_stackable_wrong_max_stack(self):
        data = valid_item_weapon()
        data["stackable"] = False
        data["max_stack"] = 5
        errors = validate_item(data)
        self.assertTrue(any("max_stack" in e for e in errors))


class TestValidSpellPass(unittest.TestCase):
    def test_damage_spell_passes(self):
        self.assertEqual(validate_spell(valid_spell_damage()), [])

    def test_heal_spell_passes(self):
        self.assertEqual(validate_spell(valid_spell_heal()), [])

    def test_debuff_spell_passes(self):
        self.assertEqual(validate_spell(valid_spell_debuff()), [])


class TestSpellMissingField(unittest.TestCase):
    def test_missing_mana_cost(self):
        data = valid_spell_damage()
        del data["mana_cost"]
        errors = validate_spell(data)
        self.assertTrue(any("mana_cost" in e for e in errors))

    def test_damage_spell_missing_damage(self):
        data = valid_spell_damage()
        del data["damage"]
        errors = validate_spell(data)
        self.assertTrue(any("damage" in e for e in errors))

    def test_heal_spell_missing_heal_amount(self):
        data = valid_spell_heal()
        del data["heal_amount"]
        errors = validate_spell(data)
        self.assertTrue(any("heal_amount" in e for e in errors))

    def test_debuff_spell_missing_effect(self):
        data = valid_spell_debuff()
        del data["effect"]
        errors = validate_spell(data)
        self.assertTrue(any("effect" in e for e in errors))


class TestSpellWrongType(unittest.TestCase):
    def test_cooldown_wrong_type(self):
        data = valid_spell_damage()
        data["cooldown"] = "fast"
        errors = validate_spell(data)
        self.assertTrue(any("cooldown" in e for e in errors))

    def test_invalid_spell_type(self):
        data = valid_spell_damage()
        data["type"] = "summon"
        errors = validate_spell(data)
        self.assertTrue(any("Invalid spell type" in e for e in errors))


class TestValidEnemyPass(unittest.TestCase):
    def test_valid_enemy_passes(self):
        self.assertEqual(validate_enemy(valid_enemy()), [])


class TestEnemyMissingField(unittest.TestCase):
    def test_missing_level(self):
        data = valid_enemy()
        del data["level"]
        errors = validate_enemy(data)
        self.assertTrue(any("level" in e for e in errors))

    def test_missing_xp_reward(self):
        data = valid_enemy()
        del data["xp_reward"]
        errors = validate_enemy(data)
        self.assertTrue(any("xp_reward" in e for e in errors))

    def test_missing_stat(self):
        data = valid_enemy()
        del data["stats"]["hp"]
        errors = validate_enemy(data)
        self.assertTrue(any("hp" in e for e in errors))

    def test_loot_table_missing_chance(self):
        data = valid_enemy()
        data["loot_table"] = [{"item_id": "potion_health"}]
        errors = validate_enemy(data)
        self.assertTrue(any("chance" in e for e in errors))


class TestEnemyWrongType(unittest.TestCase):
    def test_level_wrong_type(self):
        data = valid_enemy()
        data["level"] = 1.5
        errors = validate_enemy(data)
        self.assertTrue(any("level" in e for e in errors))

    def test_chance_out_of_range(self):
        data = valid_enemy()
        data["loot_table"] = [{"item_id": "potion_health", "chance": 1.5}]
        errors = validate_enemy(data)
        self.assertTrue(any("chance" in e for e in errors))


class TestValidShopPass(unittest.TestCase):
    def test_valid_shop_passes(self):
        self.assertEqual(validate_shop(valid_shop()), [])


class TestShopMissingField(unittest.TestCase):
    def test_missing_inventory(self):
        data = valid_shop()
        del data["inventory"]
        errors = validate_shop(data)
        self.assertTrue(any("inventory" in e for e in errors))

    def test_missing_buy_multiplier(self):
        data = valid_shop()
        del data["buy_multiplier"]
        errors = validate_shop(data)
        self.assertTrue(any("buy_multiplier" in e for e in errors))

    def test_inventory_entry_missing_item_id(self):
        data = valid_shop()
        data["inventory"] = [{"stock": -1, "price_multiplier": 1.0}]
        errors = validate_shop(data)
        self.assertTrue(any("item_id" in e for e in errors))


class TestShopWrongType(unittest.TestCase):
    def test_buy_multiplier_wrong_type(self):
        data = valid_shop()
        data["buy_multiplier"] = "half"
        errors = validate_shop(data)
        self.assertTrue(any("buy_multiplier" in e for e in errors))

    def test_stock_wrong_type(self):
        data = valid_shop()
        data["inventory"] = [{"item_id": "sword_iron", "stock": "unlimited", "price_multiplier": 1.0}]
        errors = validate_shop(data)
        self.assertTrue(any("stock" in e for e in errors))


# ---------------------------------------------------------------------------
# Tests: cross-reference validation
# ---------------------------------------------------------------------------

class TestCrossReferences(unittest.TestCase):
    def test_valid_data_passes_cross_refs(self):
        with tempfile.TemporaryDirectory() as tmp:
            data_root = build_data_dir(Path(tmp))
            errors = validate_cross_references(data_root)
            self.assertEqual(errors, [], f"Unexpected errors: {errors}")

    def test_shop_references_missing_item(self):
        with tempfile.TemporaryDirectory() as tmp:
            shop = valid_shop()
            shop["inventory"].append({"item_id": "nonexistent_item", "stock": 1, "price_multiplier": 1.0})
            data_root = build_data_dir(Path(tmp), {"shops/blacksmith.json": shop})
            errors = validate_cross_references(data_root)
            self.assertTrue(
                any("nonexistent_item" in e for e in errors),
                f"Expected cross-ref error for missing item, got: {errors}",
            )

    def test_enemy_loot_references_missing_item(self):
        with tempfile.TemporaryDirectory() as tmp:
            enemy = valid_enemy()
            enemy["loot_table"].append({"item_id": "ghost_dagger", "chance": 0.1})
            data_root = build_data_dir(Path(tmp), {"enemies/goblin.json": enemy})
            errors = validate_cross_references(data_root)
            self.assertTrue(any("ghost_dagger" in e for e in errors))

    def test_class_starting_item_references_missing_item(self):
        with tempfile.TemporaryDirectory() as tmp:
            cls = valid_class()
            cls["starting_items"].append("legendary_blade")
            data_root = build_data_dir(Path(tmp), {"classes/warrior.json": cls})
            errors = validate_cross_references(data_root)
            self.assertTrue(any("legendary_blade" in e for e in errors))

    def test_class_starting_spell_references_missing_spell(self):
        with tempfile.TemporaryDirectory() as tmp:
            cls = valid_class()
            cls["starting_spells"].append("meteor_strike")
            data_root = build_data_dir(Path(tmp), {"classes/warrior.json": cls})
            errors = validate_cross_references(data_root)
            self.assertTrue(any("meteor_strike" in e for e in errors))

    def test_race_allowed_classes_references_missing_class(self):
        with tempfile.TemporaryDirectory() as tmp:
            race = valid_race()
            race["allowed_classes"].append("necromancer")
            data_root = build_data_dir(Path(tmp), {"races/human.json": race})
            errors = validate_cross_references(data_root)
            self.assertTrue(any("necromancer" in e for e in errors))


# ---------------------------------------------------------------------------
# Tests: end-to-end run_validation
# ---------------------------------------------------------------------------

class TestRunValidation(unittest.TestCase):
    def test_full_valid_data_passes(self):
        with tempfile.TemporaryDirectory() as tmp:
            data_root = build_data_dir(Path(tmp))
            result = run_validation(data_root)
            self.assertTrue(result)

    def test_invalid_file_causes_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad_race = valid_race()
            del bad_race["description"]
            data_root = build_data_dir(Path(tmp), {"races/human.json": bad_race})
            result = run_validation(data_root)
            self.assertFalse(result)

    def test_cross_ref_failure_causes_overall_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            shop = valid_shop()
            shop["inventory"].append({"item_id": "phantom_sword", "stock": 1, "price_multiplier": 1.0})
            data_root = build_data_dir(Path(tmp), {"shops/blacksmith.json": shop})
            result = run_validation(data_root)
            self.assertFalse(result)


# ---------------------------------------------------------------------------
# Tests: load_json helper
# ---------------------------------------------------------------------------

class TestLoadJson(unittest.TestCase):
    def test_valid_json_loads(self):
        with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as fh:
            json.dump({"key": "value"}, fh)
            path = Path(fh.name)
        self.assertEqual(load_json(path), {"key": "value"})
        path.unlink()

    def test_invalid_json_raises(self):
        with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as fh:
            fh.write("{not valid json")
            path = Path(fh.name)
        with self.assertRaises(ValueError):
            load_json(path)
        path.unlink()


if __name__ == "__main__":
    unittest.main()
