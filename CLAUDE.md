# Final Strike - Roblox Game Project

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 概要
Final Strike 是一款 12 人 Roblox 生存射擊遊戲。
PvE 蒐集階段 (180秒) → PvP 淘汰賽 → 最後存活者獲勝。

## 開發規則
- 所有角色和 NPC 必須使用 R15 骨架，不用 R6
- 只使用虛構武器名稱（Viper, Stinger, Phantom, Thunder, Wraith, Fang）
- 避免寫實血腥效果和真實武器品牌
- 視覺風格：黑暗、電影感、紅色警示燈、霧氣、陰影
- 程式碼簡潔、可讀、容易擴充
- 使用 RemoteEvent 做 client-server 通訊
- 使用 ModuleScript 做共用邏輯
- 地圖名稱: "Last Zone"

## MCP 工作流程（Roblox 官方 MCP）
1. 先用 `search_game_tree` 了解當前 Studio 結構
2. 用 `multi_edit` 寫入或修改腳本（不存在則自動建立）
3. 用 `execute_luau` 快速驗證邏輯片段
4. 修改後用 `start_stop_play` 測試
5. 用 `console_output` 檢查錯誤
6. 用 `script_grep` 搜尋相關程式碼
7. 用 `generate_mesh` / `generate_material` 生成 3D 資產
8. 用 `user_keyboard_input` / `user_mouse_input` 模擬玩家操作

## 腳本位置對照表
| 腳本 | Service | 類型 | 職責 |
|---|---|---|---|
| MatchManager | ServerScriptService | Script | 比賽流程核心 |
| NPCSystem | ServerScriptService | Script | NPC 生成 + AI |
| LootSystem | ServerScriptService | Script | 戰利品生成拾取 |
| PlayerHealth | ServerScriptService | ModuleScript | 血量 API |
| MapBuilder | ServerScriptService | Script | 地圖生成 |
| GameEventsBootstrap | ServerScriptService | Script | runtime 建立 ReplicatedStorage.GameEvents Folder + RemoteEvents |
| GameConfig | ReplicatedStorage | ModuleScript | 全域設定 |
| GameEvents | ReplicatedStorage | Folder (runtime) | 由 GameEventsBootstrap 建立，內含所有 RemoteEvent |
| WeaponSystem | ServerStorage | ModuleScript | 武器數據 |
| HUDController | StarterPlayerScripts | LocalScript | UI（放此處避免每次重生 clone 一份新 ScreenGui，issue #2）|
| WeaponClient | StarterPlayerScripts | LocalScript | 射擊輸入 |

## 比賽階段
1. Lobby — 等待玩家，踩啟動台開始
2. PvE (180s) — 打 NPC、撿戰利品、PvP 關閉
3. PvP Warning (10s) — "FINAL STRIKE BEGINS" 倒數
4. PvP — 玩家互相攻擊，淘汰不重生
5. Match End — 宣布勝者，8 秒後回大廳

## 武器系統（Sprint 8 — 30 武器商店）
- 30 把武器分 6 個稀有度：Common (5) / Uncommon (5) / Rare (5) / Epic (6) / Legendary (5) / Demon (4)
- DPS 倍率：Common 1.0x / Uncommon 1.25x / Rare 1.55x / Epic 1.95x / Legendary 2.40x / Demon 3.00x
  - **Sprint 8b 計劃改為 1.0/1.15/1.30/1.50/1.70/1.90（CEO 決議 b，收斂付費差距）**
- Type：Pistol / SMG / Rifle / Shotgun / Sniper / Knife / Minigun
- 玩家經商店購買（CurrencyService.spend），STARTER_WEAPONS = ["Viper Mk1", "Fang Scout"]
- 武器掉落已移除（NPC drop 只剩 Ammo / Coin / Medkit）
- 詳見 `workloads/04-weapon-system.yaml` + `workloads/13-shop-service.yaml` + `GameConfig.WEAPONS`
- 命名範例：Viper Mk1 (Common), Wraith Scout (Uncommon), Phantom Apex (Epic), Hailstorm (Legendary Minigun), Wraith Abyss (Demon)

## 經濟系統（Sprint 8 — 子彈幣）
- 子彈幣（BulletCoins）持久化儲存：CurrencyService → DataStore PlayerCurrency_v1
- 比賽中 anti-farming：MatchCaps（NpcKills 300 / Survival 200 / PlayerKills 600 / Total 1500）
- Daily quest：6 個任務 + UTC midnight reset，獎勵 bypass match cap（DailyQuestService）
- 武器商店：30 把武器，價格 300（Viper Mk1）→ 55,000（Thunder Bloodmoon Demon）（ShopService）

## NPC 類型
- Patrol: 60 HP, 低傷害, 基本戰利品
- Armored: 150 HP, 慢速, 好戰利品
- Elite: 250 HP, 快速強力, 最好戰利品

## Workload Contracts
見 `workloads/` 目錄，每個系統有對應的 YAML contract。

## Lessons Learned
_隨開發進度持續更新_

- R15 NPC 不要自己手刻 — 用 `Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)` 直接拿完整 character mesh + Motor6D + Animate LocalScript + BodyColors + 預設 HipHeight 2.19。手刻 16 Part + Motor6D 是 Sprint 5 踩過的 C0/C1 反向陷阱
- 角色掛武器：用 `Tool` 不要手刻 Motor6D。Tool 直接 parent 到 Character 會 auto-equip + tool-hold 動畫 + Tool.Grip 自動算 grip pose
- Tool.Grip 預設讓 Handle 的 `-Z` 方向對齊 hand 前向，所以武器 mesh 設計時把 muzzle attachment 放 Handle 的 -Z 端，`Tool.Grip = CFrame.new(0, +halfGripHeight, 0)` 就夠用，不需自己加旋轉
- Tool 持槍要設 `CanBeDropped = false` + `ManualActivationOnly = true`，不然玩家會丟槍或觸發 default click 行為
- HumanoidDescription.Shirt / Pants 只認 classic 2D Shirt/Pants asset type；creator store 多數結果是 layered clothing 3D model，餵進去會 fallback 到預設 template，3 種 NPC 看起來都穿同一件。視覺差異化用 programmatic accessories（Part + WeldConstraint 掛 Head/UpperTorso）反而更可控
- `execute_luau` 在 playtest 是 client context — 看不到 ServerScriptService 子物件、`_G` 也是 client 的、設 Part 屬性也不會 replicate 給 server。驗證 server 狀態靠 `print` + `console_output`；要操控 server 狀態靠既有 RemoteEvent 鏈或臨時加 server-side debug 入口
- Roblox Raycast 的 FilterType 要用 Exclude 而非 Include
- 武器 raycast origin 要用 `Muzzle.WorldPosition`（gun barrel）不要用 Head — 不然子彈會從玩家臉穿出，掩體後伸出去的槍管沒用
- RemoteEvent 必須先在 ReplicatedStorage 建立，client 才能 WaitForChild
- ScreenGui.ResetOnSpawn = false 才不會每次重生丟失 UI
- Touched event 需要 CanCollide=false 的 Part 才穩定觸發
- 全自動武器用 RunService.Heartbeat 而非 while loop
- 官方 MCP 工具名稱與社群版不同，以官方文件為準
- ReplicatedStorage 的 Script 預設 RunContext=Legacy 不會自動執行；bootstrap 腳本放 ServerScriptService 比較安全
- Bootstrap script 不可與它在 runtime 建立的物件同名 — `WaitForChild` 會回傳第一個（通常是 Script），下游路徑全錯。慣例：`<Name>Bootstrap`
- 持久化 HUD/UI：LocalScript 放 StarterPlayerScripts（每個玩家只跑一次），不要放 StarterGui（每次重生 clone 一份）。ScreenGui 也要 `ResetOnSpawn = false`

### Sprint 8 補充（補檔 2026-05-03，詳見 receipts/sprint-8-shop-economy-fps.md）
- **武器 raycast origin 改用 camera viewport center 而非 Muzzle.WorldPosition**：Sprint 7 從 muzzle 發射雖然「視覺合理」但與螢幕中心 crosshair 不對齊（muzzle 在槍身右側 → bullet 飄）。Sprint 8 改回 camera center + crosshair-aligned direction（推翻 Sprint 7 的「camera→muzzle」決定，issue #5/6/7）
- **FPS LockFirstPerson 隱藏所有 body parts**：CameraScript 設 `LocalTransparencyModifier=1` 在所有 body parts 上 → 玩家看不到自己的手。每 frame `RenderStepped` 強制 6 個 arm parts (Left/Right Upper/Lower/Hand) `LocalTransparencyModifier=0` 才能可見
- **LeftHand IK 必須 Priority 1000**：默認 priority 會被 jump animation 的 LeftArm track 蓋掉，玩家跳起時左手會脫離武器（issue #12）
- **MouseBehavior LockCenter 過渡時要強制 Default 一段時間**：`CameraMode = Classic` 後，內建 CameraScript 仍會延續 LockCenter 數 frames。退出第一人稱時設 `releaseEnforceUntil = tick() + 1.0`，`RenderStepped` 在這 1 秒內持續強制 Default，否則鼠標被搶回 LockCenter，shop / 觀戰點不到 UI（issue #14, #15）
- **Interactive UI 開啟時必須臨時釋放 MouseBehavior**：LockCenter 會吞掉 click，shop / daily-quest UI 開啟期間要切回 Default 才能點 UI 按鈕。連 GUI Enabled signal 偵測比監聽整個 InputService 更便宜
- **Crosshair 必須在自己的 ScreenGui**：HUD 主 ScreenGui 隱藏時 crosshair 也跟著隱藏 → 不該。隔離成獨立 ScreenGui (`FinalStrikeCrosshair`) 才能獨立控制（reviewer #13 要求）
- **Crosshair 的 4 segment 必須開中心**：CEO 提出 「open-center 4-segment」spec — 中心空，4 條黑線從中心向外延伸（commit d054043）。實作時要 `GuiInset` 處理偏移
- **NPC 攻擊前必須 face 玩家**：PathfindingService 路徑用 humanoid:MoveTo 後在攻擊範圍內停下，character orientation 卡在上一個 waypoint 方向 → 從側面開槍視覺超怪。攻擊邏輯內 `HumanoidRootPart.CFrame = CFrame.lookAt(currentPos, playerPos.WithSameY)` 修正（issue #19）
- **NPC 武器視覺 (muzzle flash + tracer) 用 client-only**：12 個 NPC 同時開火 = 24+ Parts replicate，效能爆。改成 server fire RemoteEvent → client 各自 spawn local Parts + Debris:AddItem 自動清理。FX 永遠不 replicate
- **DataStore Studio playtest 注意 API Services**：Game Settings → Security → Enable Studio Access to API Services 要啟用，否則 GetAsync/SetAsync 失敗。Code 要 graceful（warning 不 crash），玩家從 0 起算
- **DataStore 不要每個動作都 SetAsync**：throttling 風險高。spend / addCoins / quest progress 都更新 in-memory，PlayerRemoving + BindToClose 才批次寫入。Crash 中失去 session 增量是 acceptable tradeoff
- **Persistent state DataStore 用 v1 後綴命名**：未來 schema migration 不用改名 — 例如 `PlayerCurrency_v1` → `PlayerCurrency_v2`，老 store 留著參考
- **Daily quest reset 用 lazy 不用 background timer**：玩家可能跨 UTC midnight 在線。`recordEvent / load / claim` 進入時呼叫 `ensureFreshDay()` 比較簡單可靠，不會錯過 reset
- **HP reset on death 不靠 Roblox spawn**：Roblox `Humanoid.Died` 觸發 spawn 重置會干擾 spectator camera。改為 server 端手動 setter — `data.HP = data.MaxHP` 在 `eliminatePlayer` 後（commit 253863f）
- **PR 開太多時注意 work truth vs execution truth 脫節**：Sprint 8 在 PR #23 寫設計提案期間 main 跑進 12 commits，作者不知道 30-weapon shop 已存在。導致提案基於「6 武器世界」假設，merge 前 PR review 抓到嚴重矛盾。Lesson：每次開新提案 PR 前先 `git fetch + git log HEAD..origin/main` audit
- **Workload contracts 是 PR review 的設計地圖**：Sprint 8 期間實作 8 個新 .lua 檔案但沒補對應 contract → Sprint 8b 設計時不知道 main 已是 30 武器世界。Sprint 8a 補檔 5 份 contract（workloads/12–16）+ 1 份 receipt（receipts/sprint-8-shop-economy-fps.md）對齊。原則：每個新系統 .lua 必須有對應 workload contract，違反 = work truth 與 execution truth 脫節
