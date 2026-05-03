# Sprint 7 Receipt — NPC + Weapon Visual Pass

Date: 2026-05-02
Studio: 最後一擊 (`ce636945-9a96-4ed9-a741-ebf81f9e6a80`)
Method: Roblox 官方 MCP (`multi_edit` / `execute_luau` / `start_stop_play` / `screen_capture` / `search_creator_store` / `insert_from_creator_store`)
Driving feedback: CEO「武器做好是什麼意思？要看到武器外型」+「NPC 改成 R15 character mesh」

## Status: ✅ PASS (visual upgrade verified for all 9 NPC instances + 6 weapons)

## Work Items

### NPC visual upgrade — commit `9c196d5`
- [x] 把手刻 16-Part block rig + 手刻 Motor6D + HipHeight 3.5 補償全部刪掉 — PASS
- [x] 改用 `Players:CreateHumanoidModelFromDescription(desc, R15)` 拿真實 R15 character mesh + 內建 BodyColors + 內建 Animate LocalScript — PASS
- [x] Per-type body color via `HumanoidDescription`：Patrol 灰、Armored 暗鋼藍、Elite 純黑 — PASS
- [x] `dressNPC()` programmatic accessories 用 Part + WeldConstraint：Patrol 警衛帽 + 黃色徽章；Armored 戰術頭盔 + 厚重背心 + 雙肩護甲 + 雙彈藥袋；Elite 兜帽 + 紅色發光徽記 + 披風 — PASS
- [x] 9 NPC 全 spawn 並 Running 狀態（4 Patrol / 3 Armored / 2 Elite）— PASS

### Weapon visual upgrade — commit `d35a9b4`
- [x] 新增 `ServerStorage/WeaponMeshes` ModuleScript：6 把武器 builder（Viper / Stinger / Phantom / Thunder / Wraith / Fang）— PASS
- [x] 每把武器有 Handle BasePart + Muzzle Attachment 在槍口 — PASS
- [x] `MatchManager.attachWeapon(player, weaponName)`：destroy 舊 Tool、build 新 Tool、parent 到 Character（auto-equip）— PASS
- [x] Wired into：`startMatch`（Viper 初始）、`LootSystem` weapon pickup、`NPCSystem` death-drop pickup、`CharacterAdded` respawn re-equip — PASS
- [x] WeaponClient `getMuzzle()`：raycast origin 從 Head 換成 Muzzle.WorldPosition — PASS
- [x] WeaponClient `spawnMuzzleFlash()`：barrel 處 neon 球 + PointLight 0.08s fade — PASS
- [x] Tool.CanBeDropped = false + ManualActivationOnly = true 防止意外 drop / 觸發 default activation — PASS

### 6 把武器 grip pose 實測
| 武器 | Tool 名 | 外觀重點 | 截圖 |
|---|---|---|---|
| Viper (pistol) | ✅ | 短身、stub barrel、neon sight | `tool_grip_v2`, `muzzle_flash_visible` |
| Stinger (SMG) | ✅ | 白 receiver、彈匣下垂、folded stock | `weapon_stinger_actual` |
| Phantom (rifle) | ✅ | 長 receiver、foregrip、neon sight | `weapon_phantom_actual` |
| Thunder (shotgun) | ✅ | 厚 barrel、wood pump + stock | `weapon_third` (Thunder) |
| Wraith (sniper) | ✅ | 4+ stud 全長、scope + bipod | `weapon_third` (Wraith) |
| Fang (knife) | ✅ | 短刀身、neon edge 紅光 | `weapon_phantom` (Fang) |

所有 6 把都被 Roblox 內建 tool-hold 動畫抬起右手，水平握持，barrel 朝玩家面向方向。Muzzle attachment 在所有 6 把都指到槍口/刀尖。

## Test Evidence

### 視覺對照（Sprint 5 → Sprint 7）
**NPC**：
- Sprint 5：16 個 `Part` + 手刻 Motor6D，純色方塊人，無臉、無動畫
- Sprint 7：R15 MeshPart character mesh，有臉（內建表情）、idle 動畫自動播、肩腰部分節、三種類型衣裝差異化

**武器**：
- Sprint 5：完全無視覺，玩家手上空，raycast 從 Head 出（穿掩體 bug 風險）
- Sprint 7：Tool 系統、玩家右手握槍、Roblox 內建 tool-hold 動畫、muzzle flash 從槍口爆 + PointLight 照場景、raycast 從 Muzzle 世界座標出

### 關鍵驗證數據
- Patrol NPC：HP 60、State=Running、HipHeight 2.19（vs Sprint 5 手刻 3.5）、結構 16 個 MeshPart + 內建 BodyColors + Animate LocalScript
- Viper Tool：Handle world Y == RightHand world Y（水平握持）；Muzzle world Y 與 Handle 相同（barrel 水平不再指地）
- 6 把武器都成功觸發 `attachWeapon` → Character.Tool 出現對應名稱、Muzzle attachment 命中槍口

## Known Issues / 修了什麼

### 🟡 — Creator store search 給的不是 HumanoidDescription.Shirt 認的型別
**症狀**：search_creator_store + insert_from_creator_store 拿到的 asset ID 套到 `HumanoidDescription.Shirt`，3 種 NPC 全部 fallback 到同一張預設 ShirtTemplate (855777285)，看起來都穿同一件淡藍色衣服。

**根因**：creator store 多數「shirt」搜尋結果是 layered clothing 3D model（`Model` 包 `MeshPart`），不是 classic 2D `Shirt` asset type。HumanoidDescription.Shirt 只認後者，前者餵進去會 fallback 到內建預設。

**處理**：放棄 shirt 路線，改 programmatic accessories（Part + WeldConstraint 掛在 Head/UpperTorso）。差異化效果反而比薄薄一張 shirt 更明顯。

### 🟡 — Tool.Grip CFrame 旋轉一開始算錯，barrel 朝天
**症狀**：第一次掛 Tool 進去，Viper 拿在手上 barrel 指天花板（Muzzle world Y 比 Hand 高 1.29 stud）。

**根因**：用 Motor6D + 手刻 C0 的方式，把 `CFrame.Angles(rad(-90), 0, 0)` 帶進來；Roblox 內建 tool grip pose 是「手臂前伸」不是「手臂下垂」，hand 局部軸方向不同我預想的。

**修法**：放棄 Motor6D 路線，改 Tool 標準系統（`Tool.Grip` 屬性）。`tool.Grip = CFrame.new(0, 0.45, 0)`（hand 抓 grip top，無旋轉）剛好讓 Handle 的 -Z（即 muzzle 方向）對到 hand 標準前向。

### 🟡 — 從 client `execute_luau` 設 Part 屬性不會 replicate 給 server
**症狀**：想 hot-patch WeaponPickup 的 WeaponName attribute 來控制玩家拿到哪把武器測試，結果 client 改的屬性 server 看不到，server's Touched handler 讀的還是原本 random 抽的名字。

**處理**：直接靠 random + restart play，分 3 round 拿齊 6 把武器。

## Artifacts

### Studio
- `ServerStorage.WeaponMeshes` (ModuleScript) ← NEW
- `ServerScriptService.MatchManager` 加 `attachWeapon` + CharacterAdded 重綁 + startMatch 初始 equip
- `ServerScriptService.LootSystem` weapon-pickup 路徑加 `mm.attachWeapon`
- `ServerScriptService.NPCSystem` createR15NPC 重寫 + dressNPC + NPC death-drop 加 `mm.attachWeapon`
- `StarterPlayer.StarterPlayerScripts.WeaponClient` 加 `getMuzzle` + `spawnMuzzleFlash`，fire origin 換成 Muzzle.WorldPosition

### src 同步
- `src/ServerStorage/WeaponMeshes.lua` (NEW)
- `src/ServerScriptService/MatchManager.lua`
- `src/ServerScriptService/LootSystem.lua`
- `src/ServerScriptService/NPCSystem.lua`
- `src/StarterPlayerScripts/WeaponClient.lua`

### Commits
- `9c196d5` feat(npc): R15 character mesh + per-type accessories — pushed to origin/main
- `d35a9b4` feat(weapons): visible 3D weapons + muzzle flash from barrel — pushed to origin/main

### Screenshots（在 Studio capture，受限於 MCP 不能存檔）
- `npc_dressed_three_types`：3 種 NPC 並排、衣裝差異
- `tool_grip_v2`：Viper 水平握持
- `tool_grip_behind`：第三人稱後視 Viper hold pose
- `muzzle_flash_visible`：muzzle flash 黃色 neon 球 + PointLight 照亮場景
- `weapon_stinger_actual` / `weapon_phantom_actual` / `weapon_third` (Wraith/Thunder) / `weapon_phantom` (Fang)：剩 5 把武器握持

## Lessons Learned（建議寫回 CLAUDE.md）

- **R15 NPC 別手刻**：`Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)` 直接給完整 character mesh + Motor6D + Animate + BodyColors + 預設 HipHeight 2.19。手刻 16 個 Part + Motor6D 是浪費 100+ 行還會踩 Sprint 5 的 C0/C1 反向 bug。
- **HumanoidDescription.Shirt 要的是 classic 2D Shirt asset type**，不是 layered clothing 3D model。creator store 多數「shirt/pants」結果是後者，會 fallback 到預設 template。視覺差異化用 programmatic accessories（Part + WeldConstraint）反而更可控。
- **Tool > 自刻 Motor6D 接武器**：Roblox `Tool` parent 到 Character 會自動 auto-equip + 套用 tool-hold 動畫 + 用 `Tool.Grip` 屬性管 grip pose。手刻 Motor6D 要解決 hand 局部軸方向 + 動畫姿勢 + respawn 重綁，比直接用 Tool 麻煩太多。
- **Tool.Grip 預設**：Handle 局部 -Z 方向會對到 hand 前向。Handle 設計時把 muzzle 放 -Z 端，`Tool.Grip = CFrame.new(0, +0.45, 0)`（hand 抓 grip top）就夠用。
- **`execute_luau` 在 playtest 是 client context**：設 Part 屬性不 replicate 給 server，呼叫 `_G.MatchManager` 也拿不到（server `_G` 跟 client `_G` 不同 table）。要驗 server 行為靠 `print` + `console_output`，要操控 server 狀態靠既有 RemoteEvent / Touched 鏈或臨時加 server-side debug 入口。
- **Tool.CanBeDropped + Tool.ManualActivationOnly**：給角色「永久持槍 + 不要 default click 行為」配置時必設這兩個。

## Next: Sprint 8 候選

未做（Sprint 5 → Sprint 7 累積）：
- [ ] Thunder shotgun 8-pellet 連續 fire 效能量測（沒實際 PvP 過）
- [ ] 觀戰區物理隔離（被淘汰玩家不能影響比賽）
- [ ] NPC AI 對玩家的攻擊節奏調整（Sprint 6 加了 spawn protection 但實戰節奏未細調）
- [ ] 多人測試（2 人以上踩 pad / 真 PvP / 勝負判定）— 目前都單人 Studio playtest
- [ ] `generate_mesh` / `generate_material` 升級 NPC 與掩體視覺（CEO 確認用內建 R15 後優先級降低）

新發現：
- [ ] 武器 grip pose 對 5 把都 OK，但 Wraith 4+ stud 太長，第三人稱看可能會卡牆 — 還沒在 PvP 戰鬥中實測
- [ ] muzzle flash 目前 client-only，其他玩家看不到開槍者的槍口閃光（只看得到命中 spark）。要不要做跨玩家 muzzle flash 看下次需求
- [ ] Tool 系統會在螢幕底下顯示 inventory tab（"Viper" 之類），目前是 Roblox 預設 UI；要不要藏掉看後續

CEO Demo 點：可以給 CEO 看的 deliverable
1. NPC 三種類型差異化截圖 — `npc_dressed_three_types`
2. 玩家手持武器 + muzzle flash — `tool_grip_behind` + `muzzle_flash_visible`
3. 6 把武器各拿一張 — 已備齊
