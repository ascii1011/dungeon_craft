# DungeonCraft — Project Plan

> A top-down dungeon crawler with the look and feel of Warcraft I/II,
> set in a vast underground world, with the extensibility of World of Warcraft:
> moddable races, items, spells, and economy. Single-player first,
> multiplayer-ready by design.

---

## Vision

- **Feel:** Warcraft I/II aesthetic — chunky sprites, dark fantasy, tile-based maps
- **World:** One massive dungeon with many floors, zones, and biomes underground
- **Depth:** WoW-style systems — races with unique traits, tradeable items with stats,
  a spell system, and NPC economies — all data-driven and moddable
- **Scope:** V1 is single-player; architecture supports co-op and multiplayer later
  without a rebuild

---

## Engine & Language

**Godot 4** (GDScript + optional C# for performance-critical systems)

- Free and open source
- Excellent 2D/isometric support out of the box
- Built-in multiplayer API (ready when we need it)
- Exportable to Windows, macOS, Linux, Web, mobile
- Scene/node system maps naturally to an ECS-like architecture

---

## Architecture Pillars

### 1. Data-Driven Design
Everything game-relevant lives in data files, not code.
Races, classes, items, spells, enemies, quests, shop inventories — all JSON/TOML.
Code reads data. Modders (and us) only touch data to add content.

```
data/
  races/       human.json, dwarf.json, orc.json ...
  items/       sword_iron.json, potion_health.json ...
  spells/      fireball.json, heal.json ...
  enemies/     goblin.json, troll.json ...
  zones/       dungeon_floor_01.json ...
  shops/       blacksmith.json ...
```

### 2. Entity Component System (ECS)
Characters, enemies, and objects are assemblies of components.
Changing race = swapping a component set. Equipping gear = attaching item components.

Core components:
- `HealthComponent` — HP, regen, death handling
- `StatsComponent` — STR, DEX, INT, VIT, etc.
- `MovementComponent` — speed, pathfinding
- `CombatComponent` — attack, defense, hit detection
- `InventoryComponent` — item slots, weight
- `SpellbookComponent` — known spells, mana, cooldowns
- `FactionComponent` — allegiance, reputation
- `TradeComponent` — buy/sell logic, currency

### 3. Tile-Based Dungeon Engine
- Grid-based maps (supports procedural generation later)
- Multiple floors connected by stairs/portals
- Zone types: combat, safe (town/hub), puzzle, boss
- Fog of war, line-of-sight
- Tileset system: swap tilesets per zone biome (stone, lava, ice, etc.)

### 4. Multiplayer-Ready Architecture
Single-player v1 uses the same game loop as multiplayer.
- All game state mutation goes through a `GameState` singleton
- Input is abstracted: local input and network input are interchangeable
- When multiplayer is added, Godot's MultiplayerAPI slots in without rewriting logic

### 5. Economy & Trade Layer
- Global item registry (unique IDs, stats, rarity tiers)
- NPC shops: inventory defined in data, restocks on timer
- Player-to-NPC trade and (later) player-to-player trade
- Currency system: gold, gems, faction tokens

---

## Tech Stack

| Layer              | Choice                                         |
|--------------------|------------------------------------------------|
| Engine             | Godot 4                                        |
| Primary language   | GDScript                                       |
| Performance layer  | C# (GodotSharp) for hot paths if needed        |
| Data format        | JSON (game data), TOML (config)                |
| Version control    | Git                                            |
| CI/CD              | GitHub Actions                                 |
| Asset pipeline     | Godot import system + custom Python scripts    |
| Save system        | Godot `FileAccess` → JSON save files           |
| Audio              | Godot AudioStreamPlayer + OGG assets           |
| Future multiplayer | Godot MultiplayerAPI (ENet or WebSocket)       |
| Future server      | Godot headless server or custom Go/Python host |

---

## Repository Structure

```
dungeon_craft/
├── PLAN.md                        ← this file
├── README.md
├── project.godot                  ← Godot project file
├── export_presets.cfg
│
├── data/                          ← all game content data (moddable)
│   ├── races/
│   ├── classes/
│   ├── items/
│   ├── spells/
│   ├── enemies/
│   ├── zones/
│   └── shops/
│
├── scenes/                        ← Godot scenes
│   ├── main/                      ← main menu, game loop, HUD
│   ├── world/                     ← dungeon map, camera, tilemap
│   ├── entities/                  ← player, enemies, NPCs
│   ├── ui/                        ← inventory, spellbook, trade, minimap
│   └── effects/                   ← spells, particles, animations
│
├── scripts/                       ← GDScript source
│   ├── core/
│   │   ├── game_state.gd          ← singleton, authoritative state
│   │   ├── event_bus.gd           ← singleton, decoupled event system
│   │   └── data_loader.gd         ← loads + caches JSON data files
│   ├── components/
│   │   ├── health_component.gd
│   │   ├── stats_component.gd
│   │   ├── movement_component.gd
│   │   ├── combat_component.gd
│   │   ├── inventory_component.gd
│   │   ├── spellbook_component.gd
│   │   ├── faction_component.gd
│   │   └── trade_component.gd
│   ├── systems/
│   │   ├── combat_system.gd
│   │   ├── spell_system.gd
│   │   ├── economy_system.gd
│   │   ├── dungeon_generator.gd
│   │   └── save_system.gd
│   ├── entities/
│   │   ├── player.gd
│   │   ├── enemy.gd
│   │   └── npc.gd
│   └── ui/
│       ├── hud.gd
│       ├── inventory_ui.gd
│       ├── spellbook_ui.gd
│       └── trade_ui.gd
│
├── assets/
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/
│   └── fonts/
│
├── tests/                         ← GUT (Godot Unit Test) framework
│   ├── unit/
│   └── integration/
│
├── tools/                         ← helper scripts (Python)
│   ├── validate_data.py           ← lint/validate all JSON data files
│   └── export_build.py            ← trigger Godot headless export
│
└── .github/
    └── workflows/
        ├── ci.yml                 ← lint, validate data, run tests
        └── build.yml              ← export game builds on tag/release
```

---

## CI/CD Flow

```
Local dev
  ├── Godot editor (scene + script editing)
  ├── GUT tests (run in editor or headless)
  ├── python tools/validate_data.py
  └── git push → PR
          │
          └── GitHub Actions: ci.yml
                ├── Validate all JSON data files (Python)
                ├── GDScript lint (gdtoolkit)
                ├── Run GUT unit tests (Godot headless)
                └── On merge to main:
                        └── build.yml
                              ├── Export builds (Linux, Windows, Web)
                              └── Upload artifacts to GitHub Release
```

---

## V1 Scope (Single Player)

**One playable race** (Human — baseline stats, no special traits yet)
**One starting zone** — dungeon floor 1: 3–4 rooms, basic enemies, a merchant NPC
**Combat** — real-time click-to-attack (Warcraft-style), 3 basic spells
**Inventory** — 20 slots, equip weapon/armor/ring
**Items** — ~20 items (weapons, armor, potions, keys)
**Spells** — ~5 spells (fireball, heal, slow, shield, blink)
**Economy** — one NPC shop, gold drops, buy/sell
**Save/load** — single save slot
**HUD** — HP bar, mana bar, minimap, hotbar, gold counter

---

## Build Phases

### Phase 1 — Engine Foundation
- [ ] Godot project setup, folder structure, scene skeleton
- [ ] `GameState` and `EventBus` singletons
- [ ] `DataLoader` — reads and caches JSON data files
- [ ] Tilemap renderer + basic dungeon scene (hand-built floor 1)
- [ ] Player scene: movement (click-to-move or WASD), camera follow
- [ ] Basic CI: data validation + gdtoolkit lint

### Phase 2 — Entity & Component System
- [ ] Component scripts: Health, Stats, Movement, Combat, Inventory
- [ ] Player assembled from components + driven by data (human.json)
- [ ] Enemy scene + basic AI (patrol, aggro, attack)
- [ ] Combat system: melee hit detection, damage calc, death

### Phase 3 — Items & Spells
- [ ] Item registry + inventory component + inventory UI
- [ ] Equipment slots (weapon, armor, ring)
- [ ] Spell system: spellbook component, mana, cooldowns
- [ ] 5 starter spells implemented
- [ ] Loot drops from enemies

### Phase 4 — Economy & NPCs
- [ ] NPC scene + dialogue system (simple tree)
- [ ] Shop UI + trade component
- [ ] Gold currency flow
- [ ] Chest/treasure interactables

### Phase 5 — Polish & CI/CD
- [ ] HUD: HP, mana, minimap, hotbar, gold
- [ ] Save/load system
- [ ] Sound effects + background music
- [ ] GUT test suite (unit + integration)
- [ ] GitHub Actions: full CI + build exports

### Phase 6 — Extensibility Pass (before multiplayer)
- [ ] Procedural dungeon generator
- [ ] Additional races (Orc, Dwarf) via data only
- [ ] Mod loader: load data from external folder
- [ ] Multiplayer architecture groundwork (abstract input layer)

---

## Decisions

| Question | Decision |
|---|---|
| Perspective | Top-down orthographic |
| Movement | WASD |
| Combat | Real-time with cooldowns |
| Art | Pixel art asset packs (Kenney, itch.io free packs) |
| Dungeon | Hand-built for v1, generator added in Phase 6 |
