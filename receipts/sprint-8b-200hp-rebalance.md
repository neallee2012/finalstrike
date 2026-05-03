# Sprint 8b Receipt — 200 HP rebalance + 30-weapon DPS retune + Sniper headshot

Date: 2026-05-03
Driving feedback: CEO 200 HP 提案 + decision (b) 30-weapon DPS gap convergence + D1 全 Sniper 1-shot 爆頭
Source proposals: `proposals/sprint-8-200hp-balance.md` (PR #23) + `proposals/30-weapon-dps-retune.md` (PR #25)

## Status: ✅ IMPLEMENTED（待 Studio playtest verification）

## Work Items

### Player blood (workloads/03)
- [x] `GameConfig.MAX_HP` 100 → **200**
- [x] `GameConfig.HEADSHOT_MULTIPLIER = 2.0` 新增（Sniper Type only）
- [x] `MatchManager.initPlayerData` 起始 200 HP（透過 GameConfig.MAX_HP，無硬編碼）
- [x] `healPlayer` 邏輯不變，由 LootSystem / NPCSystem 傳入對應 4 階 amount
- [x] `HUDController` line 52 初始 hpText 從硬編碼 "100 / 100" 改為動態 `GameConfig.MAX_HP`

### Weapon system (workloads/04)
- [x] `GameConfig.RARITY` DPS 倍率：1.0/1.25/1.55/1.95/2.40/3.00 → **1.0/1.15/1.30/1.50/1.70/1.90**
- [x] **30 武器 Damage 重平衡** per `proposals/30-weapon-dps-retune.md` §9 template
  - Common (5): Viper Mk1 25→30, Viper SD 22→24, Fang Scout 40 (no change), Thunder Stub 12→14, Thunder Cut 11 (no change)
  - Uncommon (5): Stinger Mk2 16→11, Stinger Tac 18→12, Phantom Ranger 35→19, Wraith Scout 70→**120**, Stinger Burst 14→9
  - Rare (5): Reaver-X 42→20, Phantom Night 38→17, Thunder Guard 14→12, Wraith Hunter 110→**172**, Thunder Triple 15→11
  - Epic (6): Stinger Storm 22→12, Phantom Apex 50→21, Wraith Frost 140→**190**, Phantom Whisper 55→25, Thunder Royal 18→13, Viper Left 70→62
  - Legendary (5): Viper Aurum 60→51, Phantom Finale 60→24, Wraith Apex 170→**206**, Thunder Crown 22→14, Hailstorm 18 (no change — option B)
  - Demon (4): Fang Demon 120→76, Phantom Hellfire 75→27, Wraith Abyss 210→**220**, Thunder Bloodmoon 28→14
- [x] **Sniper headshot D1**：`MatchManager.lua` FireWeapon handler 加 `config.Type == "Sniper" and hitPart.Name == "Head"` 分支套用 HEADSHOT_MULTIPLIER（×2.0）
- [x] 其他 Type（Pistol/SMG/Rifle/Shotgun/Knife/Minigun）爆頭 = 一般 Damage（嚴格 scope D1）
- [x] NPC 爆頭也適用同一機制（NPC 也有 Head part）

### NPC system (workloads/05)
- [x] `ENEMIES.Patrol`: HP 60→**120** / Damage 10→**18** / Speed 12 (no change)
- [x] `ENEMIES.Armored`: HP 150→**300** / Damage 15→**28** / Speed 8
- [x] `ENEMIES.Elite`: HP 250→**500** / Damage 25→**40** / Speed 14
- [x] `LootTable` 更新對應 4 階 medkit type（移除舊的單一 Medkit）：
  - Patrol: `{ Ammo=0.50, MedkitSmall=0.25, Coin=0.20 }`
  - Armored: `{ Ammo=0.50, Medkit=0.35, Coin=0.35 }`
  - Elite: `{ Ammo=0.40, MedkitLarge=0.50, MedkitFull=0.05, Coin=0.50 }`
- [x] `dropLoot` 顏色 + Touched handler 對應 4 階 medkit

### Loot system (workloads/06)
- [x] `GameConfig.LOOT` 加 4 階：MedkitSmall=50 / Medkit=100 / MedkitLarge=150 / MedkitFull=200
- [x] `createPickup` 顏色：淺綠 (120,255,150) → 標準綠 (50,255,100) → 深綠 (20,200,80) → 米白 (255,255,200)
- [x] Touched handler 4 種 medkit type 共用 GameConfig.LOOT[lootType].Heal lookup

### HUD (workloads/07)
- [x] HP 條使用比例計算（hp/maxHP），200 HP 自動適配
- [x] 顏色閾值維持 >60% 綠 / >30% 黃 / ≤30% 紅
- [x] 初始文字從硬編碼 "100 / 100" 改為 GameConfig.MAX_HP 動態

## Test Evidence (post-implementation, pre-playtest)

### 程式碼變更統計
- `src/ReplicatedStorage/GameConfig.lua`: ~50 lines（30 武器 + RARITY + ENEMIES + LOOT）
- `src/ServerScriptService/MatchManager.lua`: ~20 lines（FireWeapon Sniper headshot 分支）
- `src/ServerScriptService/NPCSystem.lua`: ~15 lines（dropLoot 4 階 medkit）
- `src/ServerScriptService/LootSystem.lua`: ~15 lines（createPickup 4 階 medkit）
- `src/StarterPlayerScripts/HUDController.lua`: ~3 lines（GameConfig require + dynamic 200 HP text）
- 5 個 workload contracts status 標 RESOLVED + 本 receipt

### 數值驗證（DPS 公式套用）
所有 30 武器 Damage 落在新公式 ±5% 範圍：
- Common Pistol Viper Mk1: 30 dmg / 0.40 = **75 DPS** ✓ baseline
- Demon Knife Fang Demon: 76 dmg / 0.50 = **152 DPS** = 80 × 1.90 ✓
- Sniper Wraith Abyss: 220 dmg / 1.05 = **209.5 DPS** ≈ 110 × 1.90 ✓
- Shotgun Thunder Bloodmoon: 14×8/0.60 = **186.7 DPS** = 99 × 1.89 ✓ (nearly perfect)

### Headshot 機制驗證（理論）
所有 Sniper post-(b) headshot 對 200 HP 玩家：
- Wraith Scout: 120 × 2.0 = 240 → **1-shot ✓**
- Wraith Hunter: 172 × 2.0 = 344 → **1-shot ✓**
- Wraith Frost: 190 × 2.0 = 380 → **1-shot ✓**
- Wraith Apex: 206 × 2.0 = 412 → **1-shot ✓**
- Wraith Abyss: 220 × 2.0 = 440 → **1-shot ✓**

D1 達成：5 把 Sniper 全部 post-(b) 爆頭 1-shot，付費差距由其他維度體現（body TTK / Range / Pierce）。

## Known Issues / Pending Verification

### 🟡 待 Studio playtest 確認
- [ ] 200 HP 起始實際 spawn / HUD 顯示
- [ ] Patrol NPC 站樁攻擊 → 玩家 200 HP 真實掉血速度（理論 11.1s 對 18 dmg/1.0s）
- [ ] Phantom Ranger (19 dmg) 對 Patrol (120 HP) 殺敵時間（理論 7 發 / 0.90s）
- [ ] Wraith Scout 爆頭 R15 NPC.Head 觸發 240 dmg（從 console_output 觀察 NPCDamaged 數字）
- [ ] 4 階 medkit pickup 顏色目視差異
- [ ] MedkitFull 5% drop on Elite 實測抽取（若不出現，可能要 console 顯式測）
- [ ] 30 武器全部能正常射擊（loop 跑商店買 30 把 + 切 primary 測）

### 🟡 邊界情況待測
- [ ] NPC 戴帽子 (Patrol cap / Armored helmet / Elite hood) 命中時 hitPart.Name 確認不是 "Head"（不算爆頭，吃到頭盔擋下）
- [ ] Wraith Abyss `Pierce=true` 多人命中：每根 raycast 各自判 headshot
- [ ] Phantom Hellfire `Burn=true` DOT 機制是否仍生效（未量化進 Damage，但 Burn 邏輯應該獨立）

### 🟡 需要後續觀察的設計風險
- [ ] **Demon 武器 -37%~-64% Damage nerf** 玩家手感 — CEO 已接受，但實戰可能感受到「Demon 變弱」，需 1-2 週玩家數據
- [ ] **Sniper TTK 結構性偏短**（Wraith Scout 2-body-shot 0.95s, Wraith Hunter 1.20s）— Sniper 可能成為 PvP 主導武器
- [ ] **新手 Common Viper Mk1 vs Demon Wraith Abyss** TTK 仍 1:N 但已從 1:無限收斂；玩家觀感待測
- [ ] **MedkitFull 5%** 機率太低可能讓玩家覺得「永遠抽不到」— 觀察玩家數據再調

## Lessons Learned

- **大批量數值改動分多個 commit 跨多個檔案易踩坑** — 用獨立 retune doc (proposals/30-weapon-dps-retune.md) 列 30 武器逐一 Damage + DPS 驗證，commit 時對照 doc 一行一行核對才不會漏
- **Sniper Type-based 機制比寫死武器名乾淨太多** — 用 `config.Type == "Sniper"` 一句涵蓋 5 把 Wraith 系列；如果硬編碼武器名，每次商店加新 Sniper 都得改 server
- **HUD 初始文字也要從 GameConfig 讀** — line 52 硬編碼 "100 / 100" 是 Sprint 1 留下的；玩家進大廳到 initPlayerData 觸發 HealthUpdate 之間有 ~1 frame 顯示舊文字
- **DPS 公式收斂的副作用是 Demon nerf 比 Common buff 大** — Common Viper Mk1 +20% / Demon Phantom Hellfire -64%。CEO 須事前明確接受才不會在 Sprint 8b 後被質疑
- **first-shot-immediate vs shots×FireRate** — Roblox client 射擊 timing 是 fire 然後 task.delay(FireRate)，所以 N 發殺敵 TTK = (N-1) × FireRate，比 shots × FireRate 快 1 個 FireRate。balance doc 一定要用對的 timing model 否則 CEO sign-off 失準（PR #25 review 抓到的 blocker）

## Artifacts

```
src/ReplicatedStorage/GameConfig.lua          (200 HP, RARITY, 30 weapons, ENEMIES, LOOT)
src/ServerScriptService/MatchManager.lua      (Sniper headshot branch in FireWeapon handler)
src/ServerScriptService/NPCSystem.lua         (4-tier medkit colors + Touched handler)
src/ServerScriptService/LootSystem.lua        (4-tier medkit colors + Touched handler)
src/StarterPlayerScripts/HUDController.lua    (require GameConfig + dynamic init text)
workloads/03-player-health.yaml               (status → ✅ DONE Sprint 8b)
workloads/04-weapon-system.yaml               (status → ✅ DONE Sprint 8b)
workloads/05-npc-system.yaml                  (status → ✅ DONE Sprint 8b)
workloads/06-loot-system.yaml                 (status → ✅ DONE Sprint 8b)
receipts/sprint-8b-200hp-rebalance.md         (本 receipt)
```

## Next: Sprint 9 候選

- 護甲片系統（workloads/11-armor-system.yaml）— Q4 拍板做的話
- Channel 式補血（按 H 使用 1 秒、可被打斷）— Q3 拍板做的話
- 全武器 headshot 1.5x 評估（D1 之外擴展）— 需 playtest 後再定
- Demon 武器商店價格是否調降（與本 sprint 的 nerf 對齊玩家感受）
- 古代長火槍 — 4 把新武器中唯一未存在於 main，含獨特 reload mechanic
