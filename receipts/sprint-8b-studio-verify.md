# Sprint 8b Studio Verification Receipt

Date: 2026-05-04
Studio: 最後一擊 (`9696fd4d-07ac-47b0-9765-7299d89aeb8d`)
Method: Roblox 官方 MCP (`multi_edit` / `execute_luau` / `start_stop_play` / `screen_capture`)
Driver: PR #26 merge 後、把 Sprint 8b 改動 sync 進 Studio + 跑 playtest 驗證 200 HP 平衡實際運作

## Status: ✅ PASS (smoke test) | ⚠️ PARTIAL (interactive integration tests deferred)

5 個 .lua 檔案以 multi_edit 全部 sync 進 Studio。playtest 啟動，PvE 階段確認 player HUD/NPC 數值/loot 對齊 Sprint 8b 設計。Sniper headshot integration test 因 client `execute_luau` 是 client context 限制無法直接驗證，靜態程式碼已驗證。

## Sync Studio 狀態

main 改動透過 multi_edit 套到 Studio 5 個 script：

| Script Path | Edits applied |
|---|---|
| `game.ReplicatedStorage.GameConfig` | 5 (MAX_HP, RARITY, 30 weapons, ENEMIES, LOOT) |
| `game.ServerScriptService.MatchManager` | 1 (FireWeapon Sniper headshot) |
| `game.ServerScriptService.LootSystem` | 2 (createPickup colors, Touched 4-tier) |
| `game.ServerScriptService.NPCSystem` | 2 (dropLoot colors, Touched 4-tier) |
| `game.StarterPlayer.StarterPlayerScripts.HUDController` | 2 (require GameConfig, dynamic init text) |

## Verification Results

### ✅ Static config (high confidence — execute_luau on running game)

```
GameConfig.MAX_HP                 = 200    ✓
GameConfig.HEADSHOT_MULTIPLIER    = 2.0    ✓
GameConfig.RARITY.Common.DPS      = 1.00   ✓
GameConfig.RARITY.Demon.DPS       = 1.90   ✓ (was 3.00)
GameConfig.WEAPONS.Viper Mk1      = 30     ✓ (was 25)
GameConfig.WEAPONS.Wraith Scout   = 120    ✓ (was 70)
GameConfig.WEAPONS.Wraith Hunter  = 172    ✓ (was 110)
GameConfig.WEAPONS.Wraith Abyss   = 220    ✓ (was 210)
GameConfig.WEAPONS.Fang Demon     = 76     ✓ (was 120)
GameConfig.WEAPONS.Hailstorm      = 18     ✓ (option B unchanged)
GameConfig.WEAPONS.Phantom Hellfire = 27   ✓ (was 75)
GameConfig.WEAPONS.Wraith Abyss.Type = "Sniper"  ✓
GameConfig.LOOT keys = {Ammo, Coin, Medkit, MedkitFull, MedkitLarge, MedkitSmall}  ✓ (4 tiers)
GameConfig.ENEMIES.Patrol  = HP 120 / Damage 18  ✓ (was 60/10)
GameConfig.ENEMIES.Elite   = HP 500 / LootTable {Ammo=0.4, MedkitLarge=0.5, MedkitFull=0.05, Coin=0.5}  ✓
```

### ✅ Runtime spawn smoke test

PvE phase started after navigating character to StartMatchPad:
- 9 NPCs spawned (4 Patrol / 3 Armored / 2 Elite — Sprint 5 layout unchanged)
- 20 loot pickups in arena (existing Sprint 7 LootSpawn pads)
- All NPCs have correct **runtime attributes** (HP/MaxHP/Damage):
  - 4× Patrol: HP=120, MaxHP=120, Damage=18 ✓
  - 3× Armored: HP=300, MaxHP=300, Damage=28 ✓
  - 2× Elite: HP=500, MaxHP=500, Damage=40 ✓
- Player HUD initialized: `hpText.Text = "200 / 200"` ✓
- Phase: PVE / Timer: 1:53 / 子彈幣: 20 ✓
- Crosshair 4-segment open-center ✓
- Viper Mk1 weapon mesh visible (FPS viewmodel + arms) ✓

Screenshot saved at MCP session: `sprint_8b_pve_phase` (FPS view of arena with HUD).

### ✅ Code path verified (script_grep)

- `MatchManager.lua`: `config.Type == "Sniper" and isHeadshot` — present (1 match)
- `LootSystem.lua` + `NPCSystem.lua`: `MedkitSmall" or lootType ==` — present (2 matches, both pickup paths)

### ⚠️ Interactive integration tests deferred

Could not validate via `execute_luau` due to client-context limitation
(CLAUDE.md lesson: "execute_luau 在 playtest 是 client context — 設 Part 屬性也不會 replicate 給 server"):

| Test | Approach Tried | Result |
|---|---|---|
| Pistol head hit ≠ headshot bonus | `FireWeapon:FireServer` from client position | Distance/aim mismatch (origin at 300/0/0, target at -40/-380); raycast missed, damage=0 |
| Wraith Scout body 120 / head 240 | Need to equip Wraith Scout first; player has only starter Viper Mk1 / Fang Scout | Skipped (would need shop purchase + 1650 coins) |
| Elite drops MedkitLarge / MedkitFull | `SetAttribute("HP", 0)` from client | Did not replicate to server (per known lesson); NPC didn't die |

These remain integration test items requiring an actual play session
(human controlling player + shooting weapons + getting kills).

## What this verifies vs what it doesn't

✅ **Verifies**:
- All Sprint 8b code changes loaded into Studio runtime
- GameConfig values mathematically correct (CEO-approved retune table applied)
- Player initialization uses 200 HP (HUD + healthData)
- NPC spawn pipeline uses new HP/Damage/LootTable
- 4-tier medkit lookup in `GameConfig.LOOT` dictionary works
- Sniper headshot code path exists in MatchManager

❌ **Does NOT verify** (deferred):
- Wraith Scout 240 headshot **actually applies during gameplay** to a real NPC kill
- Pistol/SMG/Rifle/Knife/Minigun head hit **doesn't accidentally** get Sniper bonus
- 4-tier medkit visual color when actually dropped from NPC kill
- 200 HP player vs Patrol attack → 11s drain rate
- NPC戴帽子的 hit edge case（Patrol Cap, Armored Helmet, Elite Hood — accessories shouldn't count as Head）

These need a human play session — recommend doing 1 manual playtest before announcing Sprint 8b "production ready" to players.

## Lessons reinforced

- `execute_luau` 是 client context — 設 Part attribute 不 replicate；`_G.MatchManager` 看不到；`_G.CurrencyService` 也是 client `_G`。Server-side 操作要靠：(a) RemoteEvent fire 走 server-validated path、(b) MCP server-side debug 入口（待加）
- `multi_edit` block-replace 要 trim entire block including outer whitespace；單 edits 跨多行用 `\n` (LF) 即可；Studio 內部用 LF 不是 CRLF
- `character_navigation` 對 PathfindingService 失敗時會卡在中間位置 — 不可靠靠 navigate 對齊精準射擊
- `screen_capture` 是 edit-time screenshot，playtest 中也能 capture — 拿來確認 HUD 視覺 + 武器 mesh 很有用

## Artifacts

- `receipts/sprint-8b-studio-verify.md` (本 receipt — origin/main 已含 PR #26 sprint-8b code)
- **`verification/sprint-8b-runtime-checks.lua`** — 可重跑的 verification script（reviewer 要求 durable artifact）
- Studio scripts already synced (5 files via multi_edit during this session)

## How to re-run verification（durable）

> Reviewer 觀察：本 receipt 內提到的 screenshot artifact 只 saved at MCP session（session-bound，不持久）。為了長期審計，把驗證步驟封裝成可重跑 script。

**Method A — Studio command bar（人類審計）**：
1. 開啟 Final Strike `.rbxl`
2. Press Play 進 PvE 階段（走到 StartMatchPad + 等 lobby 倒數 + spawn protection）
3. Open Command Bar (View → Command Bar)
4. Paste `verification/sprint-8b-runtime-checks.lua` 全部內容並 Enter
5. 看 Output：所有 `[VERIFY OK]` = pass；`[VERIFY FAIL]` = 設計漂移；尾端印 `[VERIFY SUMMARY] X passed, Y failed`

**Method B — MCP execute_luau（自動化審計）**：
把 script body 餵進 `mcp__Roblox_Studio__execute_luau` 並要求 `return { passed, failed, failures }`。本 receipt 即如此驗證。

**Last self-test result（2026-05-04, MCP execute_luau on `最後一擊` instance）**：
```
{ passed = 65, failed = 0, failures = [] }
```

Coverage：base config (2) + Rarity (6) + 30 weapons Damage (30) + Sniper Type (5) + ENEMIES HP/Damage (6) + LootTable (5) + Weapon-drop-removed (1) + LOOT 4-tier (4) + Runtime spawn (6) — all under PvE phase.

Screenshot at `sprint_8b_pve_phase` (MCP session-bound) 仍可作為視覺輔助，但不再是審計主憑據 — 以 `verification/sprint-8b-runtime-checks.lua` 65 checks 為準。

## Next

- Manual human playtest to close 5 deferred integration items
- Sprint 9 候選 work items (見 `receipts/sprint-8b-200hp-rebalance.md` §Next):
  1. 護甲片系統 (workloads/11) — Q4 拍板做的話
  2. Channel 式補血 — Q3 拍板做的話
  3. 全武器 headshot 1.5x evaluation
  4. Demon 武器商店價格 vs nerf 對齊
  5. 古代長火槍 (4 把新武器中唯一未存在於 main)
