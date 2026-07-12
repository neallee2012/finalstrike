# Issue #55 Receipt - Industrial Bunker Lobby

Date: 2026-07-12
Studio: 最後一擊 (PlaceId `76520783469506`, GameId `10086488941`)
Base: `main@33fbe91`
Method: Roblox official MCP (`search_game_tree`, `multi_edit`, `execute_luau`, `start_stop_play`, `console_output`, `script_grep`, `character_navigation`, `user_keyboard_input`, `screen_capture`)

## Status: PASS - 20/20 visual rubric and all hard gates

The old 80 x 80 lobby, green start pad, center pedestal, and Classic Teams/Crisis panel were replaced by an 80 x 180 x 28 industrial bunker hub. `LobbyBuilder.lua` owns the visual scene while `MapBuilder.lua` continues to orchestrate the full Last Zone.

## Runtime evidence

| Check | Result |
|---|---|
| Shell | Floor `80 x 2 x 180`; room height 28; central aisle 30 studs |
| Lobby budget | 225 BaseParts, 362 descendants, 20 Lights, 12 SurfaceGuis |
| Focused client render | 300 frames in 5.053 s = **59.37 FPS**; physics 60 FPS |
| Background-throttled control | 300 frames in 21.899 s = 13.70 FPS; physics 60 FPS |
| Direct integration children | `LobbySpawn`, `StartMatchPad`, and `TrainingArenaPortal` all direct children of `workspace.LastZone.Lobby` |
| Training dependencies | `TrainingEntry`, `TrainingExitPad`, and `DummySpawns` present under `workspace.LastZone.TrainingArena` |
| Spawn | `(0, 3, -72)`, facing +Z toward FINAL STRIKE |
| Training entry | Portal touch moved the player to `(499.94, 3, 50.05)` and enabled `TrainingArenaUI` |
| Training exit | Exit touch disabled `TrainingArenaUI` and returned within 2.01 studs of `LobbySpawn` |
| Shop / quests | B opened `ShopUI`; Q opened `DailyQuestUI`; interactive UI released `MouseBehavior` to `Default` |
| Match start | Crossing the invisible central threshold moved the player to the arena, changed HUD phase to `PVE`, and equipped a weapon |
| Placeholder safety | Six bay models present; no `ProximityPrompt`, `ClickDetector`, or `TouchTransmitter` under `Lobby.Bays` |
| Source parity | Repository and Studio `LobbyBuilder` normalized source length 20,803 bytes and weighted checksum `3682555878` |

The focused FPS sample was taken after activating the `最後一擊 - Roblox Studio` window. The control sample documents normal background Studio render throttling and is not used for acceptance.

## 20-point visual parity rubric

Each pass is 5%. Final score: **20/20 (100%)**.

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Dimensions/proportions | PASS | Runtime shell probe: 80 wide x 180 long x 28 high |
| 2 | Central composition | PASS | `Issue55_After_Primary_Final_v3` |
| 3 | All six bay positions | PASS | Primary and reverse captures plus six runtime bay models |
| 4 | Sign texts | PASS | Runtime TextLabel probe found all six exact labels |
| 5 | Portal/display frames | PASS | Primary, left, right, shop, and armory captures |
| 6 | FINAL STRIKE sign | PASS | `Issue55_After_CentralDestination_Final_v3` |
| 7 | Floor red lanes | PASS | Primary and reverse captures |
| 8 | Wall red strips | PASS | Primary, left, and right captures |
| 9 | Ceiling white strips | PASS | Primary and reverse captures |
| 10 | Dark metal palette | PASS | All final captures |
| 11 | Materials/paneling | PASS | Metal floor, segmented walls, pillars, ribs, and stepped frames |
| 12 | Training crosshair | PASS | `Issue55_After_LeftBays_Final` |
| 13 | 1V1/Player Arena cues | PASS | Primary, left, and reverse captures |
| 14 | Weapon Shop display | PASS | `Issue55_After_WeaponShop_Final` |
| 15 | Armory display | PASS | `Issue55_After_Armory_Final` |
| 16 | Leaderboard | PASS | `Issue55_After_RightBays_Final` |
| 17 | Props | PASS | Sparse crate/barrel clusters remain outside paths |
| 18 | Lighting/reflection | PASS | 20 local lights, neon accents, readable shadows, reflective aisle |
| 19 | Spawn camera composition | PASS | Spawn probe and `Issue55_After_Primary_Final_v3` |
| 20 | Visual cleanliness/performance | PASS | 59.37 FPS, within all budgets, no visible clipping or z-fighting |

## Capture evidence

Official Studio captures are session-bound binary assets:

- Before: `Issue55_Before_Clean_MatchedCamera`
- Primary spawn view: `Issue55_After_Primary_Final_v3`
- Left bays: `Issue55_After_LeftBays_Final`
- Right bays: `Issue55_After_RightBays_Final`
- Reverse/wide: `Issue55_After_WideReverse_Final`
- Weapon Shop: `Issue55_After_WeaponShop_Final`
- Armory: `Issue55_After_Armory_Final`
- Central destination: `Issue55_After_CentralDestination_Final_v3`

The capture host does not expose binary assets as ordinary filesystem files. Capture IDs are retained here as the durable session references, matching prior project receipt practice.

## Console classification

No `LobbyBuilder` or `MapBuilder` product errors occurred. The playtest produced the expected map generation, training enter/exit, match phase, NPC, and loot logs.

Known unrelated environment/session noise:

- TestEZ is not installed in the Studio place.
- Studio API Services are disabled, so DataStore-backed services warn and use their existing playtest behavior.
- The parallel issue #39 session injected `[Issue39Acceptance]` probes and one `AssistantCommand` error for a missing `ReloadRequest`; no issue #55 file depends on or modifies that branch.

## Changed surfaces

- `src/ServerScriptService/LobbyBuilder.lua`
- `src/ServerScriptService/MapBuilder.lua`
- `workloads/01-map-builder.yaml`
- `README.md`

No gameplay service, UI controller, GameConfig, weapon pose/viewmodel file, or issue #39 branch file was changed.
