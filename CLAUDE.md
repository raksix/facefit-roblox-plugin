# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This workspace is associated with a Roblox Studio place file named **"zombi oyunu"** (Turkish for "zombie game"). The game is a wave-based zombie survival shooter with a shop, perks, and weapon variety. The Studio is connected via MCP — use the `mcp__Roblox_Studio__*` tools to read/write scripts, inspect the tree, run Luau code, and drive playtests.

## Languages

- **Luau** — all gameplay scripts (server + client)
- **Turkish** — UI text, item names, notifications. Don't translate them unless explicitly asked.

## Codebase Architecture

The Roblox DataModel is organized as follows. **ServerScriptService and ServerStorage are currently empty** — wave logic, hit detection, leaderstats, and shop fulfillment must live on the server but aren't yet wired up. The local scripts assume the server will fire events back on the `Remotes/*` channels.

### Workspace
- `Baseplate`, `SpawnLocation` — arena floor / spawn.
- `Zombies/` — pre-placed NPC test zombies (R15 character). Real spawns happen at runtime into `ActiveZombies/`.
- `TestArea/` — development tooling, including:
  - `WeaponDevScene/` — grid platform with X/Z markers and a `DirectionArrow` for orienting weapon viewmodels.
  - `WeaponTestMap/` — separate test arena. Loaded by `WeaponEditorController` when **F8** is pressed (teleports player to `Vector3.new(0, 8, 5050)`).
- `Classics/` — large library of legacy gun mesh Parts (`Pistols/`, `SMGs/`, `Rifles/`, `Snipers/`, `Shotguns/`, `Automatic rifles/`, `Specials/`, `Melee/`, `Ammunition/`). **Decorative / reference only** — the active weapon set lives in `ReplicatedStorage.Weapons`.
- `Raksins/` — placeholder NPC model in workspace.

### ReplicatedStorage (shared assets)
- `Weapons/` — Legacy **Tool** instances (pre-ACS). Each has a `FireScript` (LocalScript), `Handle`/`Barrel` parts, `FireSound`, `ReloadSound`, and tuning **Attributes** (see "Weapon attributes" below). Active gameplay uses ACS weapons from `StarterPack` (see below); this folder is kept for reference only.
- `Armor/` — Tool instances worn by character: `HafifYelek`, `AgirYelek`, `TaktikYelek`.
- `ZombieTemplate.ZombieBase` — R15 character template cloned at spawn time. Contains `Humanoid`, `Animate`, clothing, hair accessory.
- `WeaponOffsets` — **ModuleScript**. Stores per-weapon grip offset (posX/Y/Z in studs, rotX/Y/Z in degrees) and exposes `getOffset`, `setOffset`, `getAll`, `getNames`. Drives weapon viewmodel positioning and is edited live by `WeaponEditorController`.
- `Modules/GameConfig` — **ModuleScript**, single source of truth for tuning. Contains wave scaling, shop catalog, zombie type stats, spawn points. See "GameConfig cheat sheet" below.
- `Remotes/` — `RemoteEvent`s for client↔server communication (see "Remotes" below).
- `WeaponFireEvent` — top-level RemoteEvent; **all weapons fire on this single channel** with full damage/range/spread/explosive payload, instead of per-weapon remotes.

### StarterPlayer / StarterCharacterScripts (LocalScripts and Scripts)
- `PlayerScriptsLoader` — Roblox default; just `require`s `PlayerModule`. Don't remove.
- `SprintScript` — Shift = sprint (WalkSpeed 16 ↔ 28). Also disables mouse icon.
- `WeaponEditorController` — developer tool. Toggles the `WeaponEditorGUI` test map (F8), equips selected weapon, edits `WeaponOffsets` via sliders, copies/pastes config strings (K = copy, L = paste). Spawns `TextBox` instances inside the GUI for clipboard transfer.
- `RbxCharacterSounds`, `PlayerModule` — Roblox default character sound + control module.
- `StarterCharacter` (Model, built programmatically) — **R6 rig** with Head/Torso/4 limbs/HumanoidRootPart + 6 Motor6Ds (Neck, Left/Right Shoulder, Left/Right Hip, RootJoint) + BodyColors + Humanoid. Required by `ACS_Framework` (which waits for `Torso` and `Body Colors`). Built and parented to StarterPlayer so Roblox uses it as the player character.
- `ACS_Framework` (LocalScript, ~2000 lines) — full ACS 201 client framework. Handles viewmodel, ammo, fire, reload, melee via ContextActionService. Requires R6.
- `MedSys_Client` (Script) — ACS med system. `script.Parent` resolves to the cloned character.
- `MedSys_FX` (LocalScript) — ACS FX layer. Must not call `ClearAllChildren` on the camera (destroys viewmodel).
- `StarterPack` — Tool templates spawned to Backpack on join. Each ACS weapon is a `Tool` with `ACS_Settings` (ModuleScript) + `ACS_Animations` (ModuleScript). Active set (10 weapons): `Tabanca` (USP), `Tabanca2` (MP5), `OtomatikTufek` (HK416), `OtomatikTufek2` (HK33), `Pompali` (M870), `KeskinNisanci` (R700), `Bicak` (Knife, 9999 damage = one-shot kill), `Bomba` (M67), `Bomba2` (M18), `Flash` (Flashbang).

### StarterGui (LocalScripts and ScreenGuis)
- `HUD/HUDController` — crosshair, health bar, ammo counter, reload bar, kill/point readout, sprint indicator. Exposes **BindableEvents** (`AmmoUpdate`, `ReloadStarted`, `ReloadFinished`, `WeaponEquipped`, `WeaponUnequipped`) under the `HUD` ScreenGui that weapon `FireScript`s fire into.
- `ShopUI` — full UI generator (built in code, not in the GUI tree). Tabbed shop (Silahlar / Zirhlar / Perkler), wave announcer, notification toasts. Reacts to `Remotes/UpdateHUD`, `WaveStart`, `WaveEnd`, `ShowShop`, `ShowNotification`, `ZombieKilled`, `BuyItem`, `BuyPerk`.
- `ScreenGui` — placeholder, currently not used as code.
- `WeaponEditorGUI/OffsetPanel` — slider-driven weapon viewmodel editor (linked to `WeaponEditorController`).

### ServerScriptService
- `ACS_Server` (Script) — authoritative damage resolver for all ACS weapons. Validates `ACS_Settings` against client payload via `compareTables` and applies `Humanoid:TakeDamage`. Bicak has 9999 damage on all hit zones → one-shot kill.
- `WaveManager` (Script) — orchestrates wave progression, broadcasts `WaveStart`/`WaveEnd`.
- `ShopService` (Script) — listens for `BuyItem`/`BuyPerk`, gives tools. `refreshWeaponInBackpack` is non-destructive (adds tool only if missing) so the ACS hotbar is preserved on repurchase.
- `ZombieSpawner` / `ZombieFactory` / `ZombieSwarm` / `ZombieAI` — zombie lifecycle and behavior.
- `BossTanriAI` — boss zombie behavior.
- `ItemCollector` — picks up dropped items.
- `WeaponHandler` — bridges the legacy `WeaponFireEvent` channel (kept for compatibility).
- `MainServerNVG` — NVG system from ACS deployment.

## Weapon attributes (read by every FireScript)

All `Tool` attributes are read at script init via `tool:GetAttribute(...)`. The `WeaponFireEvent` payload mirrors these so the server doesn't need separate config per weapon.

| Attribute      | Type | Default | Notes                                    |
| -------------- | ---- | ------- | ---------------------------------------- |
| `Damage`       | num  | 25      | Per pellet                               |
| `Range`        | num  | 100     | Studs                                    |
| `FireRate`     | num  | 0.18    | Seconds between shots                    |
| `Pellets`      | int  | 1       | Shotguns use 8                           |
| `Spread`       | num  | 0       | Random cone radians                      |
| `IsExplosive`  | bool | false   | Roketatar only                           |
| `MagSize`      | int  | 12      |                                          |
| `ReloadTime`   | num  | 1.4     | Seconds                                  |
| `Automatic`    | bool | false   | OtomatikTufek; holds to fire              |

## Remotes

Client-to-server intent goes through `ReplicatedStorage.Remotes/*`:

- `BuyItem` (type, name) — type is `"weapon"` or `"armor"`
- `BuyPerk` (perkName)
- `WeaponFireEvent` — top-level: `(origin: Vector3, dir: Vector3, damage, range, pellets, spread, isExplosive)`

Server-to-client broadcasts: `WaveStart`, `WaveEnd`, `ZombieKilled`, `UpdateHUD`, `ShowShop`, `ShowNotification`, `PlaySound`, `GiveItem`.

The existing `WeaponFireEvent` (top-level, NOT inside `Remotes/`) is the only one client-side weapons use. New weapon-specific remotes aren't needed.

## GameConfig cheat sheet (`ReplicatedStorage.Modules.GameConfig`)

- **Wave scaling**: `ZOMBIES_PER_WAVE_INCREMENT = 3`; health/damage/speed grow by `0.18 / 0.10 / 0.04` per wave.
- **Zombie types**: `Normal`, `Runner`, `Tank`, `Boomer`, `Hunter` — each has `MinWave`, `SpawnWeight`, sight/hearing ranges, and special abilities (`CanEnrage`, `ExplodeOnDeath`, `CanPounce`).
- **Spawn points**: hand-tuned grid in `SPAWN_POINTS` (corners + interior).
- **Shop**: `SHOP_WEAPONS` (10 ACS weapons: Tabanca, Tabanca2, OtomatikTufek, OtomatikTufek2, Pompali, KeskinNisanci, Bicak, Bomba, Bomba2, Flash — all Price=0 in the ACS deployment), `SHOP_ARMOR` (4 incl. `Yok`), `SHOP_PERKS` (4 with `MaxLevel`).
- **Economy**: `STARTING_MONEY = 100`, `STARTING_LIVES = 3`, `KILL_REWARD = 12`, `WAVE_COMPLETE_BONUS = 75`.

When you change economy or wave numbers, edit `GameConfig` — don't hardcode them in scripts.

## Conventions

- Naming is **Turkish** for player-facing content (weapons = `Tabanca`, armor = `Yelek`, zombies = `Zombie`). New code identifiers should follow the existing style (e.g., `KeskinNisanci`, `Roketatar`).
- Weapon viewmodel positioning: always go through `WeaponOffsets.getOffset(name)` rather than hardcoding CFrames. The editor GUI lets you tweak these live in Play mode.
- Use `task.spawn` / `task.delay` / `task.wait` — not deprecated `spawn`/`wait`.
- Local FX (muzzle flash, recoil, tracer) belong in `FireScript` (LocalScript). Damage resolution and authoritative hit detection belong on the server.
- HUD updates from weapons use **BindableEvents** under `StarterGui.HUD` (not Remotes) because they are client-only signals.

## Common workflows

### Adding a new weapon
1. Duplicate a `ReplicatedStorage/Weapons/<ExistingTool>` and rename it (keep the `FireScript`).
2. Set the new Tool's Attributes (see table above).
3. Add an entry to `GameConfig.SHOP_WEAPONS`.
4. Add an offset entry to `ReplicatedStorage/WeaponOffsets`.
5. Add a `TextButton` to `StarterGui/WeaponEditorGUI/OffsetPanel/WeaponList`.
6. Run play, enter test map (F8), tune offsets via sliders, copy with K, paste values back into `WeaponOffsets`.

### Editing weapon viewmodel offsets live
1. Press **F8** in Play mode → teleports to `TestArea/WeaponTestMap`.
2. Click a weapon in the `WeaponEditorGUI` to equip and select.
3. Drag X/Y/Z/Pitch/Yaw/Roll sliders.
4. Press **K** to copy config string → paste back into `ReplicatedStorage/WeaponOffsets`.

### Reading scripts from Studio
Use `mcp__Roblox_Studio__script_read` with a dot-notation path, e.g.
`game.ReplicatedStorage.Modules.GameConfig`. For multi-line edits use `multi_edit` (atomic; pass all edits at once).

### Writing new server scripts
`ServerScriptService` is empty. New server `Script`s go there. They typically wait on `ReplicatedStorage.Remotes/*` and broadcast back via the same events. Remember: weapon firing already happens through the top-level `WeaponFireEvent`, so a single server-side handler can resolve hits for all weapons.

### Playtesting
Press Play in Studio; the local client runs immediately. The MCP `mcp__Roblox_Studio__start_stop_play` toggles play mode. Use the `playtest` subagent for end-to-end verification across multiple waves.

## FaceFit Plugin

A separate Roblox Studio plugin that places a user-picked image on a selected character Head (R6/R15) as a face Decal.

- **Source tree (this repo)**: `D:\AI\src\plugins\FaceFit\` — mirrors what ships.
- **Installed plugin (live)**: `C:\Users\raksi\AppData\Local\Roblox\Plugins\FaceFit\` — Studio loads the plugin from here. The two paths must stay byte-identical. When you edit source, also copy to the installed path (Studio auto-detects file changes and reloads).
- **Layout**:
  - `init.server.lua` — Plugin entry point. Creates toolbar + dock widget; on first click reparents `DockWidgetGui/DockWidget.client.lua` into the runtime DockWidgetPluginGui so `buildUI()` parents UI to a renderable dock. BindableEvents (`RequestPreview`, `RequestApply`) live in the source Folder at `Plugin.DockWidgetGui/`, NOT inside the dock widget itself — PreviewModal looks them up there.
  - `DockWidgetGui/DockWidget.client.lua` — Main editor UI: image picker, R6/R15 radio, 512/1024 toggle, canvas with ghost overlay, zoom/offset/rotation sliders, grid snap, Reset, Preview, Apply.
  - `DockWidgetGui/services/` — Pure-Luau modules: `FaceMapper`, `ImageProcessor`, `GhostRenderer`, `AssetUploader`, `DecalApplier`. Required by `DockWidget.client.lua` and `PreviewModal.client.lua`.
  - `PreviewModalGui/PreviewModal.client.lua` — 3D ViewportFrame preview opened by DockWidget's Preview button. Fires `RequestApply` (BindableEvent on `DockWidgetGui` Folder) when its Apply button is clicked; the DockWidget listener does the actual apply.
  - `tests/` — TestEZ scaffold + 17 unit tests for FaceMapper + ImageProcessor. Run via `require(game.ReplicatedStorage.Plugins.FaceFit.tests.run_tests)` in Play mode.
- **Dev scaffold (in-place testing)**: When `ReplicatedStorage.Plugins.FaceFit` is a Folder (not a real Plugin instance), `init.server.lua` short-circuits via `IsA("Plugin")` guard. Real toolbar only works after install via Plugin Manager or `File → Save as Local Plugin`.
- **Important**: When modifying, edit the source at `D:\AI\src\plugins\FaceFit\` AND copy to `C:\Users\raksi\AppData\Local\Roblox\Plugins\FaceFit\`. Studio auto-reloads plugin source on file change.

## Local backups outside Studio

`D:\AI\tabanca_firescript.lua` — flat copy of the `Tabanca.FireScript` body (matches what is in Studio). If asked to "find the script," check this file first.