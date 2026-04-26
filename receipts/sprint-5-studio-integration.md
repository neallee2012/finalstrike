# Sprint 5 Receipt — Studio Integration (smoke test)

Date: 2026-04-26
Studio: Place1 (`7cafef90-a9cc-4077-a777-a7c9181d9acb`), fresh baseplate
Method: Roblox 官方 MCP (`multi_edit` / `execute_luau` / `start_stop_play` / `get_console_output`)

## Status: ✅ PASS (server boot + first PvE phase verified)

Full match cycle (PvP → end → lobby loop) NOT verified — would need ≥190 s wait + multi-player.

## Work Items
- [x] 透過 MCP 寫入所有 10 個腳本到 Studio — PASS
- [x] 完整 Playtest 啟動 — PASS (boot 無 error)
- [x] 觸發 startMatch + 進入 PvE phase — PASS
- [x] NPC spawn — PASS (10/10, type 與 HP 正確)
- [x] Loot spawn — PASS (10/10, 4 種類型分布正確)
- [x] NPC AI 在 Patrol 狀態移動 — PASS
- [ ] PvP 倒數 + 切換 — 未測（時間 + 需多人）
- [ ] 武器射擊 / 換彈 — 未測（單人 playtest 無法雙向驗證）
- [ ] HUD 顯示 — 未測（沒有 client 截圖工具）
- [ ] generate_mesh / generate_material 視覺打磨 — 未做（保留給 Sprint 6）

## Test Evidence

### Console output
```
[MapBuilder] Map generated successfully!
[MatchManager] Phase: PvE
[NPCSystem] Spawned 10 NPCs
[LootSystem] Spawned 10 pickups
```

### NPC 狀態（PvE 開始 ~8 秒後）
```
Patrol  HP=60   state=Patrol  ×5
Armored HP=150  state=Patrol  ×3
Elite   HP=250  state=Patrol  ×2
```
全部離開 spawn marker 位置 → AI loop 確實在跑。

### Loot 分布
4 Ammo / 2 Medkit / 2 Coin / 3 Weapon（含 NPC 死亡掉落 OFF，因為 PvE 才開始）

## Known Issues / 修了什麼

### 🔴 P0 — GameEvents Script vs Folder 同名衝突（已修）
**症狀**：第一輪 playtest 卡 `Infinite yield possible on 'ReplicatedStorage.GameEvents:WaitForChild("PhaseChanged")'`

**根因**：
1. `src/ReplicatedStorage/GameEvents.lua` 是 Script，寫入 Studio 後成為 `ReplicatedStorage.GameEvents` Script
2. 該 Script 執行時又建立一個 Folder 也叫 `GameEvents`
3. `ReplicatedStorage:WaitForChild("GameEvents")` 拿到的是 **Script**，不是 Folder
4. 後續 `WaitForChild("PhaseChanged")` 在 Script 上找不到 → 永久 yield

**修法**（在 Studio 端）：
- `Script.RunContext = Enum.RunContext.Server`（讓 ReplicatedStorage 的 Script 能執行）
- `Script.Name = "GameEventsBootstrap"`（改名避免與它建立的 Folder 撞名）

**原始碼層面尚未同步**：`src/ReplicatedStorage/GameEvents.lua` 還是叫 `GameEvents.lua`、CLAUDE.md script 表也還寫 `GameEvents | ReplicatedStorage | Script`。下次 re-sync 會再撞一次。建議：
- 重命名 `src/ReplicatedStorage/GameEvents.lua` → `GameEventsBootstrap.lua`
- 更新 CLAUDE.md / workloads 對應條目
- 或：把這段 RemoteEvent 建立邏輯改放 ServerScriptService，避免 ReplicatedStorage Script 的 RunContext 陷阱

### 🟡 仍未驗證的 Sprint 1–4 Known Issues（從上份 receipt 帶來）
- 多人同時踩啟動台是否重複觸發 `startMatch`（單人測無法重現）
- NPC Motor6D joints — 目前 NPC 站立、會 MoveTo，初步 OK，但下肢動畫未細看
- Thunder shotgun 8-pellet raycast 效能 — 沒進 PvP 測過
- 觀戰區玩家武器隔離 — 未測

## Artifacts
Studio 內已建立:
- `ReplicatedStorage.GameConfig` (ModuleScript)
- `ReplicatedStorage.GameEventsBootstrap` (Script, RunContext=Server) ← 已改名
- `ReplicatedStorage.GameEvents` (Folder, runtime-created, 含 17 個 RemoteEvent)
- `ServerStorage.WeaponSystem` (ModuleScript)
- `ServerScriptService.{MapBuilder, MatchManager, NPCSystem, LootSystem}` (Script)
- `ServerScriptService.PlayerHealth` (ModuleScript)
- `StarterGui.HUDController` (LocalScript)
- `StarterPlayer.StarterPlayerScripts.WeaponClient` (LocalScript)

Workspace 在 PvE phase 包含:
- `LastZone/{Lobby, Arena, SpectatorArea}`
- 10 個 `<EnemyType>NPC` Model
- 10 個 `<LootType>Pickup` Part

## Lessons Learned（建議寫回 CLAUDE.md）
- ReplicatedStorage 的 Script 預設 `RunContext=Legacy` 不會自動執行；必須改 `Server`。
- Script 與它在 runtime 建立的 Folder/Instance 不能同名 — `WaitForChild` 會回傳第一個（通常是 Script），導致下游路徑全錯。Bootstrap script 一律加 `Bootstrap` 後綴。
- `execute_luau` 在 playtest 是 client context — 看不到 ServerScriptService 子物件、`_G` 也是 client 的；要驗證 server 狀態靠 `print` + `console_output` 或檢查 ReplicatedStorage 共享物件。

## Sprint 5 Addendum — Combat smoke test attempted

### 驗證結果
**通過**：
- ✅ FireWeapon RemoteEvent client→server 傳遞正常
- ✅ Server `playerData[player]` 正確初始化
- ✅ Server raycast 執行（hit detection 邏輯走完）
- ✅ 命中非 NPC 物件（ArenaFloor / AmmoPickup）的分支正確 fallthrough

**未通過 / blocked**：
- ❌ NPC HP 從未掉落（即使瞄準 anchored NPC + 移除 Baseplate 阻擋）

### 又抓到 2 個 P0 bug

#### 🔴 P0 — Studio 預設 Baseplate 阻擋 arena raycast（已修）
**症狀**：從 Lobby 區射往 Arena 的所有 raycast 命中 `Workspace.Baseplate`

**根因**：Studio Baseplate template 的 Baseplate 是 2048×16×2048 at y=-8，頂面在 y=0，跨在 Lobby (z=0~+40) 與 Arena (z=-249~-551) 中間。任何 z 跨度經過 ±256 的 raycast 都會撞到。

**修法**：`src/ServerScriptService/MapBuilder.lua` `buildAll()` 開頭加 `workspace.Baseplate:Destroy()`（已寫入 src + Studio）

#### 🔴 P0 — NPC R15 rig 壞掉（**已修**）
**症狀**：anchored Patrol NPC 各身體部位 Y 座標：
```
HumanoidRootPart Y=0.99
Head             Y=1.99   (上方 OK)
UpperTorso       Y=2.19   (上方 OK)
LowerTorso       Y=1.19   (在 HRP 與 UpperTorso 之間)
LeftUpperLeg     Y=2.04   ← 應該在 LowerTorso 下方！
LeftLowerLeg     Y=3.34   ← 越來越高
LeftFoot         Y=4.14   ← 比 Head 還高！
```
腿部漂到頭上 → NPC 視覺根本不對 + raycast 命中 box 全錯位 + hitbox 不可預測。

**根因**：`NPCSystem.lua` `createR15NPC()` 的 Motor6D C0/C1 設定有誤。具體看 LeftHip joint：
```lua
{ Part0 = "LeftUpperLeg", Part1 = "LowerTorso", Name = "LeftHip", 
  C0 = CFrame.new(0, 0.65, 0), C1 = CFrame.new(-0.5, -0.2, 0) },
```
而 motor 建立程式碼把 j.Part1 設為 motor.Part0：
```lua
motor.Part0 = model:FindFirstChild(j.Part1)  -- LowerTorso
motor.Part1 = model:FindFirstChild(j.Part0)  -- LeftUpperLeg
motor.C0 = j.C0   -- CFrame.new(0, 0.65, 0)  ← 應該對應 Part0 (LowerTorso) 的 attachment
motor.C1 = j.C1   -- CFrame.new(-0.5, -0.2, 0) ← Part1 (LeftUpperLeg)
```
Motor6D 公式：`Part1.CFrame = Part0.CFrame * C0 * C1:Inverse()`
代入：`LeftUpperLeg = LowerTorso * (0, 0.65, 0) * (-0.5, -0.2, 0):Inverse() = LowerTorso * (0.5, 0.85, 0)`

→ LeftUpperLeg 被 force 到 LowerTorso 上方 0.85 — 跟現實相反（應該在下方 -0.65）。

**修法（已套用，src + Studio 都改）**：
1. 重寫 joints 表用 Parent/Child 命名（不再用 Part0/Part1 反轉），C0 = Child 相對 Parent 的 translation，C1 = identity
2. 加 `humanoid.HipHeight = 3.5` — 讓 Humanoid locomotion 把 HRP levitate 到正確高度（feet 不可碰撞，純靠 HRP collision 會讓 feet 沉到地下 -2.35）

**驗證**（PatrolNPC after fix）：
```
Y=6.27  Head           ← top
Y=5.27  UpperTorso
Y=4.47  HumanoidRootPart  ← hip area (HipHeight 3.5 above feet)
Y=4.27  LowerTorso
Y=3.12  LeftUpperLeg
Y=1.82  LeftLowerLeg
Y=1.12  LeftFoot       ← bottom, just above ArenaFloor (Y=0)
```
Humanoid State = Running, HipHeight = 3.50.

### Combat smoke test — RIG 修完後重跑（✅ ALL GREEN）

**Viper × 4 shots on anchored Patrol NPC**（HP 60，Damage 25/shot）：
```
hit HumanoidRootPart  npcHP 60 → 35
hit UpperTorso        npcHP 35 → 10
hit UpperTorso        npcHP 10 → -15
hit HumanoidRootPart  npcHP -15 → -40
NPC.Parent == nil  ← 死亡 destroy 成功
```

**NPC 死亡掉落**：殺多個 NPC 後 workspace pickup 從 10 → 12 (+2 NPC drops)。
LootTable RNG 命中 ~25%（這次 Patrol NPCs 各掉了 0–2 顆，符合 Ammo 0.6 / Coin 0.3 / Medkit 0.1 機率分布）。

**Loot 撿起**：fresh 重啟、開賽後立刻走到 AmmoPickup at (-40, 3, -430)：
```
before = true (AmmoPickup.Parent ~= nil)
after  = false (Touched 觸發 → :Destroy())
```

### Studio 端的暫時 debug（會被下次 re-sync 覆蓋）
- `MatchManager` 加了 3 個 print：`[FireWeapon] from ...`、`raycast result:`、`hitChar=`、`EARLY_RETURN`。對之後 debug 有幫助、可保留。

## Next: Sprint 6
- [ ] 多人測試（2 人以上踩 pad / PvP / 勝負判定）
- [ ] 完整 PvE→PvPWarning→PvP→MatchEnd 一輪
- [ ] 用 `generate_mesh` / `generate_material` 升級 NPC 與掩體視覺
- [ ] Thunder shotgun 效能量測（8 pellets）
- [ ] 觀戰區物理隔離（被淘汰玩家不能影響比賽）
- [ ] NPC AI 對玩家的攻擊節奏（測試發現玩家很容易被群殺）
