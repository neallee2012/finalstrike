# Final Strike - Roblox Studio Prototype

A 12-player survival shooter for Roblox. PvE loot phase → PvP elimination.

## Setup in Roblox Studio

1. Open a new Baseplate place in Roblox Studio
2. Set Avatar Type to **R15** (Game Settings → Avatar → Avatar Type → R15)
3. Copy each `.lua` file into the corresponding Roblox service:
   - `src/ServerScriptService/` → ServerScriptService
   - `src/StarterGui/` → StarterGui
   - `src/StarterPlayerScripts/` → StarterPlayerScripts
   - `src/ReplicatedStorage/` → ReplicatedStorage
   - `src/ServerStorage/` → ServerStorage
4. Run `MapBuilder` first (it auto-runs on server start to generate the map)
5. Playtest!

## Architecture

- **MatchManager.lua** - Core game loop (Lobby → PvE → PvP → End)
- **MapBuilder.lua** - Procedural map generation (lobby, arena, spectator area)
- **NPCSystem.lua** - R15 NPC spawning, AI, patrol, chase, attack, loot drops
- **WeaponSystem.lua** - Gun/melee framework with fictional weapons
- **LootSystem.lua** - Pickups: ammo, medkits, coins, weapons
- **HealthSystem.lua** - Player HP, elimination, spectator teleport
- **HUDController.lua** - Client-side HP bar, match phase, kill feed
- **WeaponClient.lua** - Client-side weapon input, animations, FX
