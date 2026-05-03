# Sprint 8 Receipt — Shop economy + FPS viewmodel + NPC weapons

Date: 2026-05-03 (補檔)
Type: ⚠️ Backfill receipt — 此 Sprint 期間實作已完成（main 上 12 commits），但當時未補 receipt 與對應 workload contracts
Backfill driver: PR #23 review 發現 work truth 與 execution truth 嚴重脫節（200 HP 提案基於 6-weapon 假設寫，main 已是 30-weapon shop）
Backfilled by: claude-code (Sprint 8a 衛生補課)

## Status: ✅ PASS（功能已上 main 並通過 PR review；本 receipt 為事後追補設計意圖記錄）

> Peter Pangg AI-First 框架原則：「Receipt 是一級物件」。Sprint 8 期間未補 receipt 違反此原則，導致 Sprint 8b 設計時不知道 main 已是 30 武器世界。本 receipt + workloads/12–16 為 Sprint 8a 補檔。

## Sprint 8 範圍（commits 5928547 ~ cc88d6c，共 16 commits）

### 子彈幣經濟（commit 5928547 — feat(shop): bullet coin economy + 30-weapon shop + daily quests）
- [x] CurrencyService.lua（167 行）— PlayerCurrency_v1 DataStore + 比賽中 anti-farming caps
- [x] DailyQuestService.lua（180 行）— PlayerDailyQuests_v1 + UTC midnight lazy reset
- [x] ShopService.lua（199 行）— 30 武器持久化擁有 + primary weapon 選擇
- [x] DailyQuestUI.lua（243 行）— 6 任務 UI + claim 按鈕
- [x] ShopController.lua（362 行）— 30 武器商店 UI（含稀有度顏色 + DPS 顯示）
- [x] GameConfig 擴展：30 武器 × 6 稀有度（RARITY 倍率 1.0–3.0）+ ECONOMY config + DAILY_QUESTS
- [x] STARTER_WEAPONS = ["Viper Mk1", "Fang Scout"] — 新玩家初始就有
- [x] LootSystem 移除 weapon drop（武器只能商店買）

### 30 武器整合（commit 18db315 — fix(weapons): bullets now follow crosshair + weapon model attaches for all 30 weapons）
- [x] WeaponMeshes 為 30 武器 builder（部分 reuse Sprint 7 的 6 武器 mesh + 微調稀有度顏色）
- [x] bullets 對齊 crosshair：raycast origin 從 Muzzle 改為 Camera viewport center
- [x] 主武器 attachWeapon 從 ShopService.getPrimary 取，不再隨機

### FPS 視角（commits 3db2349, 78c4b9f, ab5a601, 9829d65, 6997184）
- [x] CameraController（130 行）— PvE/PvPWarning/PvP 鎖第一人稱 + LockCenter；大廳 / Match End / 觀戰 釋放
- [x] ViewmodelController（94 行）— 強制 6 個 arm parts 可見 + LeftHand IK pin 到 Tool.Handle.LeftGrip
- [x] crosshair 4-segment open-center 完成（commit d054043 — CEO spec）
- [x] crosshair 在自己的 ScreenGui FinalStrikeCrosshair 隔離（reviewer #13 要求）
- [x] crosshair 在大廳 / 觀戰 / UI 開啟時隱藏（commit 9829d65）
- [x] 觀戰 camera fix（commit 78c4b9f — 被淘汰玩家切第三人稱）
- [x] right-click work in third-person（commit ab5a601 — release MouseBehavior 機制）
- [x] IK Priority 1000 防 jump 時手脫離武器（commit 78c4b9f — fix #12）
- [x] IK survives jump（同上）

### NPC 武器與射擊視覺（commit 253863f, 6236dc1）
- [x] NPC 持槍（不再空手攻擊）— Tool 系統共用 WeaponMeshes
- [x] NPC 攻擊前轉向面對玩家（commit 6236dc1 — fix #19，避免側面開槍）
- [x] NPCWeaponEffectsClient.lua（62 行）— client local muzzle flash + tracer
- [x] NPCFireWeapon RemoteEvent — server fire 給 client，純 client FX 不 replicate Parts

### 戰鬥節奏（commit 253863f）
- [x] HP reset on death — 不靠 Roblox spawn 而 server 端手動 setter
- [x] PvP 5min cap — PVP_DURATION = 300，task.wait 累計

### Bug fixes（PRs #7, #10, #17, #21）
- [x] PR #7 (claude/sleepy-stonebraker): merge conflicts + camera + IK
- [x] PR #10 (fix/issues-5-6): bullets follow crosshair
- [x] PR #17 (fix/issues-14-15-16): right-click third-person + arena lighting
- [x] PR #21 (fix/issues-18-19-20): NPC face player + crosshair lobby/spectator

## Test Evidence (post-hoc)

### 程式碼結構 audit
- 17 files modified / created（diff stat from f66c269..origin/main）
- 2021 lines added / 144 deleted（淨 +1877）
- 6 個新檔案：CurrencyService, DailyQuestService, ShopService, DailyQuestUI, ShopController, CameraController, ViewmodelController, NPCWeaponEffectsClient（注意：8 個新 .lua）

### 整合驗證
- PR #21 在 2026-05-03 通過 review 並 merge to main → main HEAD = cc88d6c
- 30 武器全部可在 ShopController 中看到（PR descriptions 描述）
- FPS viewmodel + crosshair 與 bullet 對齊（PR #10 fix description）
- NPC face_player 與持槍視覺（PR #21 fix description）

## Known Issues / 未補課項目

### 🟡 Sprint 8 未補 workload contracts（已於 Sprint 8a 補課）
- `workloads/12-currency-service.yaml` — NEW
- `workloads/13-shop-service.yaml` — NEW
- `workloads/14-daily-quest.yaml` — NEW
- `workloads/15-fps-viewmodel.yaml` — NEW
- `workloads/16-npc-weapons.yaml` — NEW

### 🟡 Sprint 7 receipt 提到的「6 把武器」現實已變 30 把
- `receipts/sprint-7-visual-pass.md` 不修改（immutable historical record）
- 但 workloads/04-weapon-system.yaml 的「已完成的歷史」段落仍寫 6 武器
  - **Sprint 8a 在 PR #23 中已部分對齊**（sprint_8b_changes 區塊改寫為 30 武器）
  - 「已完成的歷史」段是 Sprint 3 的紀錄，不應追溯改成 30 武器

### 🟡 Sprint 8 未測項目（已知，CEO 接受）
- Demon 武器 vs 一般玩家在實戰是否「過強」未實測（單人 Studio playtest 限制）
- Daily quest UTC midnight reset 跨日跑通需多日測試
- Currency DataStore 在 Studio 沒開 API Services 時 graceful 但 production 確認待測
- 30 武器 grip pose 實測：Sprint 7 receipt 提到 Wraith 4+stud 可能卡牆；現有 5 把 Wraith，未全測

## Lessons Learned（已寫回 CLAUDE.md）

詳見 CLAUDE.md「Lessons Learned」段落 Sprint 8 新增條目（本 PR 同時更新）。

## 連帶引發的設計問題（Sprint 8b 待解）

Sprint 8 的 30-weapon shop 與 200 HP rebalance 提案結合產生新張力：
- **付費差距放大**：100 HP 下 Demon 武器近乎秒殺所以「看不出」DPS gap，200 HP 下 TTK 拉長 → 新手 vs Demon 玩家差距明顯
- **CEO 拍板路線 (b)**：30 武器 DPS 公式收斂（Common→Demon 從 3.0x → 1.9x）
- 詳見 `proposals/sprint-8-200hp-balance.md` §4.2

## Artifacts

### 新增檔案
```
src/ServerScriptService/CurrencyService.lua            (167 行)
src/ServerScriptService/DailyQuestService.lua          (180 行)
src/ServerScriptService/ShopService.lua                (199 行)
src/StarterPlayerScripts/CameraController.lua          (130 行)
src/StarterPlayerScripts/DailyQuestUI.lua              (243 行)
src/StarterPlayerScripts/NPCWeaponEffectsClient.lua    (62 行)
src/StarterPlayerScripts/ShopController.lua            (362 行)
src/StarterPlayerScripts/ViewmodelController.lua       (94 行)
```

### 修改檔案
```
src/ReplicatedStorage/GameConfig.lua             (+159 行：30 武器、RARITY、ECONOMY、DAILY_QUESTS)
src/ServerScriptService/MatchManager.lua          (+128 行：reward / quest hooks、attachWeapon 改用 ShopService.getPrimary)
src/ServerScriptService/NPCSystem.lua             (+91 行：face_player + 武器持槍 + NPCFireWeapon)
src/ServerScriptService/LootSystem.lua            (+23 行：移除 weapon drop)
src/ServerScriptService/MapBuilder.lua            (+37 行：lighting 微調)
src/ServerScriptService/GameEventsBootstrap.lua   (+24 行：新 RemoteEvent / RemoteFunction)
src/ServerStorage/WeaponMeshes.lua                (+53 行：30 武器 builder)
src/StarterPlayerScripts/HUDController.lua        (+165 行：4-seg crosshair、shop/quest icons、currency display)
src/StarterPlayerScripts/WeaponClient.lua         (+24 行：raycast origin 改 camera)
```

### 16 個 commits（Sprint 8 期間）
```
5928547 feat(shop): bullet coin economy + 30-weapon shop + daily quests
18db315 fix(weapons): bullets now follow crosshair + weapon model attaches for all 30 weapons
9e9cf72 Resolve PR #7 merge conflicts
f0c33d8 Merge updated PR #7 branch
2cf21f0 Merge pull request #7 from neallee2012/claude/sleepy-stonebraker-cbf6fa
3db2349 fix(camera+timer): FPS viewmodel + crosshair-aligned aim + clear PvP timer
78c4b9f fix(camera): spectator camera on death + IK survives jump + crosshair GuiInset
a66dc4a fix(review): isolate crosshair to its own ScreenGui + gate fire log
d054043 feat(hud): match CEO crosshair spec — 4-segment open-center reticle
7d20bb6 Merge pull request #10 from neallee2012/fix/issues-5-6
ab5a601 fix(camera+lighting): right-click works in third-person + brighten arena
c94f8e5 Merge pull request #17 from neallee2012/fix/issues-14-15-16
253863f feat(combat): HP reset on death + 5-min PvP timer + NPC weapons & fire visuals
6236dc1 fix(npc): turn to face player before firing instead of side-shooting
9829d65 fix(hud): hide crosshair in lobby + spectator + while menus are open
cc88d6c Merge pull request #21 from neallee2012/fix/issues-18-19-20
```

## Next: Sprint 8b（200 HP rebalance）

PR #23 提供 Sprint 8b 設計地圖（200 HP + 30 武器 DPS 公式收斂 + Sniper Type-based headshot D1）。
Sprint 8b 開工前還需 Claude 提交 `proposals/30-weapon-dps-retune.md` 給 CEO 一次拍板 30 武器 Damage 新值。
