# Final Strike - Roblox Studio Prototype

A 12-player survival shooter for Roblox. PvE loot phase → PvP elimination.

## Setup in Roblox Studio

1. Open a new Baseplate place in Roblox Studio
2. Set Avatar Type to **R15** (Game Settings → Avatar → Avatar Type → R15)
3. Copy each `.lua` file into the corresponding Roblox service:
   - `src/ServerScriptService/` → ServerScriptService
   - `src/StarterPlayerScripts/` → StarterPlayer.StarterPlayerScripts
   - `src/ReplicatedStorage/` → ReplicatedStorage
   - `src/ServerStorage/` → ServerStorage
4. Run `MapBuilder` first (it auto-runs on server start to generate the map)
5. Playtest!

## Architecture

- **GameConfig.lua** - Shared match, weapon, NPC, economy, and quest configuration
- **GameEventsBootstrap.lua** - Runtime `GameEvents` RemoteEvent/RemoteFunction creation
- **MatchManager.lua** - Lobby → PvE → PvP → Match End flow, player health, ammo, and weapon validation
- **MapBuilder.lua** - Procedural Last Zone lobby, arena, spectator area, and training arena
- **NPCSystem.lua** - R15 NPC spawning, AI, combat, training dummies, and loot drops
- **LootSystem.lua** - Ammo, medkit, and coin pickups
- **CurrencyService.lua / ShopService.lua** - BulletCoin persistence and 30-weapon ownership/loadout
- **DailyQuestService.lua** - UTC-reset daily quest progress and rewards
- **TrainingService.lua** - Training arena entry, exit, and unrestricted weapon selection
- **WeaponMeshes.lua** - Tool-based weapon model builders and grip setup
- **HUDController.lua / WeaponClient.lua** - HUD, firing input, reload input, and local weapon FX
- **ViewmodelController.lua / CameraController.lua** - First-person arms, crosshair, and camera behavior
- **ShopController.lua / DailyQuestUI.lua / TrainingArenaUI.lua** - Interactive client UI
- **NPCWeaponEffectsClient.lua** - Client-only NPC muzzle flash and tracer FX

## Verification

- `verification/sprint-8b-runtime-checks.lua` contains reusable Studio runtime checks.
- `src/ServerScriptService/Tests/` contains the Studio-only TestEZ suite; current automated coverage includes `CurrencyMath` and `ReloadLogic`.
- The `2026-07-12` full-place Studio E2E in `最後一擊` covered the complete match lifecycle, manual/automatic/partial reload, reserve pickups, reload cancellation, and NPC R15 aim/fire poses.
