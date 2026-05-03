# Sprint 8 提案：200 HP 戰鬥平衡

Date: 2026-05-03
Author: claude-code
Driving feedback: CEO「把玩家血量改成 200 HP，重新平衡武器/NPC/補血/掉落，加入護甲片」
Status: 🔄 (b) 路線 RESOLVED 2026-05-03（30 武器 DPS 公式收斂）/ Q1/Q2 設計意圖保留但具體數字已被 §3.5 + §4.2 取代 / Q3-Q5 + NPC + headshot multiplier + MedkitFull drop 仍待決策

## 決策狀態
| 項目 | 狀態 | 決議 |
|---|---|---|
| **(b) 30 武器 DPS 公式收斂** | ✅ RESOLVED 2026-05-03 | **新 Rarity 倍率 1.00/1.15/1.30/1.50/1.70/1.90（vs 現 1.00/1.25/1.55/1.95/2.40/3.00），Common→Demon gap 從 3x → 1.9x** |
| **Q1** Sniper headshot | ✅ RESOLVED 2026-05-03 | **改為 Type-based 機制：`config.Type=="Sniper"` && hitPart.Name=="Head" 套用 HEADSHOT_MULTIPLIER（提議 2.0x）— 涵蓋 5 把 Wraith 系列** |
| **Q2** Thunder pellet 機制 | ✅ RESOLVED 2026-05-03 | **Type-based、各 Shotgun 武器 Pellets 數維持既有設定（6/8/9 不一）；damage 走 (b) 公式 retune** |
| **Q5** 新武器 | ✅ RESOLVED 2026-05-03 | **不新增**：Hailstorm = 迷你槍、Thunder Triple = 三管霰彈槍 / 古代長火槍 → Sprint 10 |
| HEADSHOT_MULTIPLIER 數值 | ⏳ 推薦 2.0x | — |
| Q3 channel 式補血 | ⏳ 推薦延後 S9 | — |
| Q4 護甲片系統 | ⏳ 推薦 S9 | — |
| NPC 數值（×2 vs +47%~66%） | ⏳ 推薦 ×2 | — |
| MedkitFull 5% drop on Elite | ⏳ 推薦 yes | — |

---

## TL;DR

**支持核心方向**（200 HP 確實能解決「秒死、補血無意義、最終決戰太短」三個現存問題）。

但提案內含 **5 個需要 CEO 拍板的設計分歧**、**3 個項目超出單 Sprint 範圍**、以及 **1 個會影響武器定位的副作用**。建議：

| Sprint | 範圍 | 風險 | 工程量估計 |
|---|---|---|---|
| **Sprint 8a** | 衛生補課：補 main 上 12 commits 的 workload contracts + receipts | 低 | ~0.5 天 |
| **Sprint 8b** | 200 HP + **30 武器 DPS 公式收斂** (CEO 決議 b) + Sniper Type-based headshot + NPC ×2 + 4 階補血包 | 中 | ~2 天 |
| **Sprint 9** | 護甲片系統（pickup + HUD overlay + 傷害吸收） | 中 | ~1 天 |
| **Sprint 10+** | 古代長火槍（迷你槍 Hailstorm / 三管 Thunder Triple 已存在於 main）/ 補血通道使用 / 訓練場 | 高（已超出本提案） | 各 0.5–1 天 |

不建議一口氣全做，理由見 §6。

> ⚠️ **2026-05-03 關鍵 reconciliation**：本提案最初寫於 6-weapon 世界。main 已合併 30-weapon shop（commit 5928547+）。實際 Sprint 8b 設計見 §3.5（Sniper Type-based headshot）+ §4.2（30 武器 DPS 公式收斂）+ §9（Sprint 8a 衛生補課）。本表 §2 TTK、§3 Q1/Q2 的具體數值是「歷史快照」，不再採用。

---

## 1. 為什麼 200 HP 是對的方向

對照現狀（Sprint 6 receipt 提到「playability tuning」是修玩家被秒殺的問題）：

**現在 100 HP 的痛點**：
- Wraith 狙擊 90 dmg = 一發秒殺，鼓勵蹲伏狙擊不交火
- Phantom 步槍 30 dmg = 4 發 0.6 秒清線，新手沒反應時間
- 醫療包 50 HP = 已經回半條，價值高但很容易被打死前還來不及用
- Spawn protection 3 秒過後，2 個 NPC 圍毆能在 4 秒內帶走玩家

**改成 200 HP 後**：
- 玩家有約 1.5–2x 的反應時間
- 補血包真的「分等級」有意義（小補/中補/大補/急救）
- 1v1 PvP 從「誰先看到誰活」變成「誰操作好誰活」
- Wraith 失去秒殺能力 → ⚠️ **這是副作用，見 Q1**

---

## 2. TTK（Time-To-Kill）對照表

> ⚠️ **歷史快照**：本表為提案最初版（基於 Sprint 7 之前的 6 武器世界）的「現狀 vs CEO 提案」對照，作為「為什麼 200 HP 改變武器手感」的數學論據。
> **2026-05-03 Reconciliation 後實際做法見 §4.2**（30 武器走 (b) 路線、Sniper Type-based headshot）。本表的「CEO 提案 dmg」欄位數值不再採用。

以下用 Sprint 7 之前 6 把武器的 fire rate 計算實際 TTK（單位：秒；命中率假設 100%，純頭/胸無 headshot 倍率）。

| 武器 | 現在 dmg | 現在 TTK（vs 100HP） | CEO 提案 dmg | 新 TTK（vs 200HP） | 變化 | 評估 |
|---|---|---|---|---|---|---|
| Viper (Pistol) | 25 | 4 發 / 1.6s | 35 | 6 發 / 2.4s | +50% | ✅ 合理，手槍應該是「打不過撤退換槍」 |
| Stinger (SMG) | 15 | 7 發 / 0.56s | 18 | 12 發 / 0.96s | +71% | ⚠️ TTK 比現在拉長 71%，近距離換槍會太久 |
| Phantom (Rifle) | 30 | 4 發 / 0.6s | 45 | 5 發 / 0.75s | +25% | ✅ 主力武器手感維持，最好 |
| Thunder (Shotgun) | 12×8=96 | 1 發 / 0s | ~~13×10=130~~ | — | ⛔ 撤回 | 數字撤回；7 把 Shotgun 走 §4.2 (b) 公式 |
| Wraith (Sniper) | 90 | 1 發 / 0s | ~~150 / 200 爆頭~~ | — | ⛔ 撤回 | 數字撤回；5 把 Sniper 走 §3.5 Type-based headshot |
| Fang (Knife) | 40 | 3 揮 / 1.5s | 60 | 4 揮 / 2.0s | +33% | ✅ 近戰風險換報酬合理 |

\* `90~140` 看起來是總傷害範圍而非 per-pellet，需要 CEO 確認（Q2）。

---

## 3. ❓ 待 CEO 拍板（Q1–Q5）

> ⚠️ **2026-05-03 整節 reconciliation**：Q1 和 Q2 的 CEO 原始指示是基於 Sprint 7 之前的「單一 Wraith 90 dmg / 單一 Thunder 12×8」舊狀態。Q3–Q5 的選項分析仍有效。Q1/Q2 的「具體數值決議」已被 **(b) 30 武器 DPS 公式收斂** 與 **Type-based 機制** 取代（見 §3.5 + §4.2）。下面 Q1/Q2 內容保留為**設計意圖紀錄**，但具體數字（150/200/10/13）不再採用。

### Q1: Wraith 狙擊是否仍然「一發致命」？ ✅ RESOLVED 2026-05-03（設計意圖；具體數字已被 §3.5 取代）

**CEO 設計意圖**：
- 身體擊中 = 「重傷但不秒殺」(對舊 100 HP 的 75% / 對舊單一 Wraith)
- 爆頭 = 「一發秒殺」

**Sprint 8b 實作做法**（見 §3.5）：
- 改成 **Type-based**：`config.Type == "Sniper"` 套用 `GameConfig.HEADSHOT_MULTIPLIER`（提議 2.0x）
- 涵蓋 5 把 Wraith 系列，body damage 走 (b) 公式 retune（不寫死 150）
- 爆頭=身體 ×2.0：Rare 起跳 1 發秒殺 200 HP 玩家，Uncommon Wraith Scout 仍要 2 發
- ~~原 CEO 指示「身體 150 / 爆頭 200」~~ — **撤銷具體數字**，改走 Type-based 機制

### Q2: Thunder 霰彈槍 90~140 是「總傷害」還是「per-pellet」？ ⛔ WITHDRAWN 2026-05-03（具體數字撤回，per-pellet 設計意圖保留）

**CEO 設計意圖**（保留）：
- 霰彈總傷害**靠 spread 自然散落**：近距全中高 / 中遠距部分 miss
- 不新增距離 falloff 機制
- 解讀為 per-pellet damage（非單發總傷害）

**Sprint 8b 實作做法**（見 §4.2 + §4.2.4）：
- 改成 **Type-based**：所有 `config.Type == "Shotgun"` 武器（main 上有 7 把 Shotgun 系列）走 (b) 公式 retune
- **各武器既有 Pellets 數維持不動**（main: 6/8/8/9/8/8/8），不批量改 10
- per-pellet damage 由 (b) 新 RARITY 倍率公式推算
- ~~原 CEO 指示「Pellets 8→10、Damage 12→13」~~ — **撤回具體數字**（這是針對舊單一 Thunder 的設計，main 上的 7 把 Shotgun 各有自己的 Pellets 平衡點）
- 中/遠距「靠 spread 散落」的設計精神 → 透過維持各武器既有 spread 達成（playtest 後微調）

### 3.5 ⚙️ Headshot 系統（Q1 衍生新工程）— 適配 30 武器商店

> ⚠️ **Reconciliation 2026-05-03**：CEO Q1 訊息「身體 150 / 爆頭 200」是描述舊單一 `Wraith` (90 dmg) 的設計。main 上現在有 **5 把 Sniper 武器**（Type="Sniper"），不能寫死 `weaponName == "Wraith"`，需改用 Type-based 機制。

**main 上的 Sniper 系列**：

| 武器 | Rarity | 現 Damage | 倍率 2.0x 後爆頭 | 對 200 HP 玩家 |
|---|---|---|---|---|
| Wraith Scout | Uncommon | 70 | 140 | 仍要 2 發爆頭 |
| Wraith Hunter | Rare | 110 | 220 | **1 發秒殺** ✓ |
| Wraith Frost | Epic | 140 | 280 | **1 發秒殺** ✓ |
| Wraith Apex | Legendary | 170 | 340 | **1 發秒殺** ✓ |
| Wraith Abyss | Demon | 210 | 420 | **1 發秒殺** ✓（已 Pierce）|

**範圍**：Sprint 8b 只 `config.Type == "Sniper"` 套用 headshot 倍率。其他 Type（Pistol/SMG/Rifle/Shotgun/Knife/Minigun）爆頭 = 一般傷害（避免一次打亂 30 武器 TTK 預期）。

**實作邏輯**（MatchManager.lua FireWeapon handler，**Type-based**）：
```lua
-- 偽程式碼
local hitPart = result.Instance
local isHeadshot = hitPart.Name == "Head"

local damage = config.Damage
if config.Type == "Sniper" and isHeadshot then
    damage = damage * GameConfig.HEADSHOT_MULTIPLIER
end
```

**GameConfig 新增**：
```lua
GameConfig.HEADSHOT_MULTIPLIER = 2.0  -- 目前只 Sniper 套用 (Sprint 8b)
-- 不再為單一武器加 HeadshotDamage 欄位
```

**Headshot multiplier — 待 CEO 拍板**：

| 選項 | 倍率 | Wraith Scout (70) | Wraith Hunter (110) | Wraith Apex (170) | 評估 |
|---|---|---|---|---|---|
| A: 1.33x | 嚴格遵守 CEO 200/150 比例 | 93 | 146 | 226 | 只 Demon Wraith Abyss 1-shot；過保守 |
| **B: 2.0x（推薦）** | FPS 標準 | 140 | 220 | 340 | Rare+ 1-shot；商店升級「能秒殺」訊號明確 |
| C: 固定 +200 | 直接加常數 | 270 | 310 | 370 | 全部 1-shot；模糊稀有度差距 |

**推薦 B**：與商店稀有度共振 — Uncommon 仍要 2 發爆頭、Rare 起跳 1 發爆頭，付費升級的「能秒殺人」是明確里程碑。

**邊界情況**：
- NPC 戴的 hat/hood/helmet accessory 命中 hitPart.Name 不是 "Head" → 不算爆頭（吃到頭盔擋下，合理）
- `Wraith Abyss` 有 `Pierce=true`（穿透），headshot 邏輯每根 raycast 命中各自判斷
- Thunder 系列 (Type="Shotgun") 不套用 headshot（多 pellet 命中很難判定首發是頭，且打亂霰彈定位）

**驗證項目**：
- [ ] Wraith Scout 對 200 HP 玩家：身體 70 / 爆頭 140（仍存活）
- [ ] Wraith Hunter 對 200 HP 玩家：身體 110 / 爆頭 220（**秒殺** ✓）
- [ ] Wraith Hunter 對 Patrol 120 HP NPC：爆頭 220 一發殺 / 身體 110 兩發
- [ ] 其他 Type（Rifle/SMG/Pistol/Shotgun/Knife/Minigun）命中 Head part = 一般傷害（無加成）
- [ ] Wraith Abyss Pierce 多人命中：每人各自判 headshot

### Q3: 「補血需要短暫使用時間 + 不能攻擊」是否現在做？

現存補血包是「碰到就立刻回血」（`Touched` → `mm.healPlayer`）。提案要求：
- 拾取進「inventory」（沒有 inventory 系統）
- 主動觸發
- 使用時間（channel）
- 期間不能攻擊
- 期間可被打斷

→ 這是**獨立的大系統**（inventory + channel UI + 中斷邏輯 + 動畫）。

- 選項 A：**Sprint 8 維持碰到就回血**，只把回血量分成 4 階。最快上線。
- 選項 B：**Sprint 8 加上「按 H 使用」延遲 1 秒**（不要 inventory，地上撿的醫療包進「current medkit」slot，按 H 觸發 1 秒 channel）。中等複雜度。
- 選項 C：**Sprint 9 才做完整 inventory + channel**。

→ **Claude 建議：A 先上線 + Sprint 9 評估 B/C**。理由：4 階補血量＋200 HP 已經把節奏拉慢，channel 機制是錦上添花，不是必需。

### Q4: 護甲片系統現在做嗎？

提案描述清楚（50 護甲上限、先吸收傷害、護甲不能疊很高）。但會牽動：
- `MatchManager.damagePlayer` 傷害公式重寫
- `playerData` 加 `Armor` 欄位
- 新 RemoteEvent `ArmorUpdate` + HUD 護甲條 overlay
- `LootSystem` / `NPCSystem` 新增 `ArmorPlate` pickup type
- `GameConfig.LOOT.ArmorPlate`

→ 工程量約 **0.5–1 天**，獨立系統。

- 選項 A：**Sprint 8 一起做**。CEO 看到完整體驗，但風險高（同時改太多參數，難 isolate bug）。
- 選項 B：**拆 Sprint 9 做**（推薦）。Sprint 8 純血量平衡上線後玩 1–2 天再加護甲，能驗證新平衡是否舒服。

→ **Claude 建議：B**。

### Q5: 4 把新武器（左輪/古代長火槍/迷你槍/三管霰彈槍）做嗎？

> ⚠️ **Reconciliation 2026-05-03**：main 上已有 30 把武器商店 + 6 個稀有度。原提案的「4 把新武器」現實對照：

| CEO 提案武器 | main 上現況 | Sprint 8b 動作 |
|---|---|---|
| 左輪（慢射速、高單發） | ❌ 無，但 `Viper Left` (Epic, 70 dmg, 0.55s, MagSize 6) **mechanic 上已是 left-revolver** | 不新增，視覺可考慮 rebrand |
| 古代長火槍（裝填慢、單發重擊） | ❌ 無，獨特 reload mechanic 需新設計 | **Sprint 10 候選**（含獨特裝填動畫）|
| 迷你槍（壓制型） | ✅ **`Hailstorm`** (Legendary, 18×0.05s, SpinUp=0.5)，`Type="Minigun"` 已存在 | 不新增 |
| 三管霰彈槍（近距離爆發） | ✅ **`Thunder Triple`** (Rare, 15×9 pellets, 0.80s) | 不新增 |

**結論**：Sprint 8b **不新增武器**，30 把已涵蓋。古代長火槍如 CEO 仍要，Sprint 10 單獨處理。

---

## 4. Sprint 8 範圍（推薦）

只做「血量平衡」，不做護甲、不做新武器、不做 channel 補血。

### 4.1 玩家
- `MAX_HP` 100 → 200
- `MEDKIT_HEAL` 棄用，改為 4 階補血量（見 4.3）
- 淘汰機制不變
- 觸碰補血包仍然立即回血（4 階差異就是回多少）

### 4.2 武器：30 把 DPS 公式收斂（CEO 決議 b — 2026-05-03）

> ⚠️ **Reconciliation + CEO 決議 (b) 2026-05-03**：
> 原提案寫「6 把武器 damage 重平衡」，現實是 **main 上有 30 把武器 × 6 個稀有度**。
> CEO 拍板路線 (b)：**重新校 30 武器的 DPS 公式，讓 Common→Demon 的 TTK 差距收斂**。

#### 4.2.1 現行 vs 提議的 Rarity DPS 公式

| Rarity | 現行倍率 | 新倍率（提議） | Common→該 tier 的 DPS gap |
|---|---|---|---|
| Common | 1.00x | 1.00x | 1.00x |
| Uncommon | 1.25x | **1.15x** | 1.15x |
| Rare | 1.55x | **1.30x** | 1.30x |
| Epic | 1.95x | **1.50x** | 1.50x |
| Legendary | 2.40x | **1.70x** | 1.70x |
| Demon | 3.00x | **1.90x** | 1.90x |
| **Common→Demon gap** | **3.00x** | **1.90x** | **付費差距 ↓ 37%** |

**設計目標**：
- Common (起手 starter) 在 200 HP 下仍可玩（不被高稀有度碾壓）
- Demon 仍有「最強」感受（1.9x DPS = 比 Common 快約一倍 TTK），但不再是 3x 碾壓
- 商店誘因仍存在（升級 1.9x 仍值得花子彈幣），只是不再是 P2W

#### 4.2.2 Common Baseline（200 HP TTK 目標）

| Type | Common 目標 TTK vs 200 HP | 推算 DPS | 範例 |
|---|---|---|---|
| Pistol | 2.5–3.0s | 67–80 | Viper Mk1: 25 dmg × 0.4s = 62.5 → 改 30 dmg = 75 DPS ✓ |
| SMG | 1.5–2.0s | 100–133 | (Common 無 SMG，Stinger 起跳 Uncommon) |
| Rifle | 1.5–2.0s | 100–133 | (Common 無 Rifle，Phantom 起跳 Uncommon) |
| Shotgun | 0.8–1.5s（近距） | 130–250 | Thunder Stub: 12×6/0.85s = 85 → 改 14×6 = 99 DPS |
| Sniper | 1.5–2.0s（單發） | 100–133 | (Common 無 Sniper，Wraith 起跳 Uncommon) |
| Knife | 1.5–2.5s | 80–133 | Fang Scout: 40/0.5s = 80 ✓ 維持 |

**注意**：許多 Type 從 Uncommon 起跳（main 設計），所以 Uncommon 武器要負責 baseline 體驗，不能太弱。

#### 4.2.3 30 武器新 Damage（公式：`新 Damage = Common baseline DPS × 新 rarity 倍率 × FireRate`）

完整 30 武器數值表將於 **Sprint 8b 實作前由 Claude 提交給 CEO 拍板**（單獨 follow-up doc：`proposals/30-weapon-dps-retune.md`）。

**範例計算**（Wraith 系列，Sniper baseline DPS = 110）：

| 武器 | Rarity | 新倍率 | Target DPS | FireRate | 推算 Damage | 現 Damage | Δ |
|---|---|---|---|---|---|---|---|
| Wraith Scout | Uncommon | 1.15 | 127 | 0.95s | **120** | 70 | +71% |
| Wraith Hunter | Rare | 1.30 | 143 | 1.20s | **172** | 110 | +56% |
| Wraith Frost | Epic | 1.50 | 165 | 1.15s | **190** | 140 | +36% |
| Wraith Apex | Legendary | 1.70 | 187 | 1.10s | **206** | 170 | +21% |
| Wraith Abyss | Demon | 1.90 | 209 | 1.05s | **220** | 210 | +5% |

→ 對 200 HP 玩家：Wraith Scout 身體 2 發殺、爆頭（×2）240 1 發殺。**全部 Sniper 都能 1 發爆頭秒殺**（包含 Common 起手 — 但 Common 無 Sniper，最低 Uncommon Wraith Scout 240 爆頭）。

#### 4.2.4 機制改動（不依賴 damage retune 的部分）

| 機制 | 觸發條件 | 套用範圍 |
|---|---|---|
| Headshot 加成 | `config.Type == "Sniper"` && hitPart.Name=="Head" | 5 把 Sniper（×2.0 倍率） |
| 玩家血量 | initPlayerData | 全部 |
| NPC 血量/傷害 | createR15NPC | 3 種 NPC ×2 |
| Medkit 4 階 | LootSystem.createPickup | LOOT.Medkit{Small/_/Large/Full} |

> §3.5 詳述 Sniper headshot 機制。Sprint 8b 不擴展到其他 Type。

### 4.3 NPC

| NPC | 新 HP | 新 Damage | 移動速度（不動） | 備註 |
|---|---|---|---|---|
| Patrol | **120** (現 60) | **18** (現 10) | 12 | 純粹 ×2 + 略強，符合 200 HP 玩家 |
| Armored | **300** (現 150) | **28** (現 15) | 8 | ×2 + 強化 |
| Elite | **500** (現 250) | **40** (現 25) | 14 | ×2 + 強化 |

> 提案的 NPC 數值（100/220/350 HP）相對現在 60/150/250 是 +66%/+47%/+40%，**不到 ×2**。這會讓 NPC 對新玩家相對變弱。建議直接 ×2 比較簡單合理。**待 CEO 拍板用提案值還是 ×2 值**。

### 4.4 補血包（4 階）

| 名稱 | LootType | 回血量 | 稀有度 | 出現位置 |
|---|---|---|---|---|
| Small Medkit | `MedkitSmall` | 50 | 常見 | NPC 掉落 + 地圖 |
| Medkit | `Medkit` | 100 | 標準 | 地圖 + Armored 掉落 |
| Large Medkit | `MedkitLarge` | 150 | 稀有 | Elite 掉落 + 紅色警戒箱 |
| Full Medkit | `MedkitFull` | 200（補滿） | 極稀有 | 空投箱（**未實作，先放在 Elite 掉落 5%**） |

`MAX_HP` cap 邏輯不變，補滿型多餘的浪費掉。

### 4.5 戰利品掉落表更新

> ⚠️ **Reconciliation 2026-05-03**：main 已**移除武器 drop**（武器只能商店買，`GameConfig.LOOT` 註解明確寫 `Weapon dropped removed — weapons are shop-only now`）。NPC LootTable 現在只有 Ammo / Coin / Medkit。

**現行 main NPC LootTable**：
- Patrol: `{ Ammo=0.7, Coin=0.3 }`
- Armored: `{ Ammo=0.5, Coin=0.3, Medkit=0.2 }`
- Elite: `{ Ammo=0.3, Coin=0.4, Medkit=0.3 }`

**Sprint 8b 更新**：把單一 `Medkit` 拆成 4 階 type，對應 NPC tier 掉落不同等級。**保持武器 shop-only**（不重新加 weapon drop）。

**Patrol**（目標：每殺 1 隻平均 ~1 個道具）：
```
Ammo:        0.50
MedkitSmall: 0.25   ← 新（Heal 50）
Coin:        0.20
```

**Armored**：
```
Ammo:        0.50
Medkit:      0.35   ← 標準（Heal 100）
Coin:        0.35
```

**Elite**：
```
Ammo:        0.40
MedkitLarge: 0.50   ← 新（Heal 150）
MedkitFull:  0.05   ← 新（Heal 200，極稀有，待 CEO 拍板是否在這出）
Coin:        0.50
```

> Sprint 8b **不動**：商店、子彈幣 reward 公式、daily quest、shop pricing 維持 main 現狀。
> Sprint 9 候選：護甲片掉落（如 CEO Q4 拍板做）。

### 4.6 HUD

只改一個：HP 條的最大值從 100 → 200。顏色閾值（>60% 綠 / >30% 黃 / ≤30% 紅）維持比例計算，不需改。

---

## 5. Sprint 9 範圍（建議，提案後續）

只列範圍，細節延後設計：

- **護甲片系統**（GameConfig.ARMOR + playerData.Armor + damagePlayer 公式 + ArmorUpdate event + HUD overlay + ArmorPlate pickup type + NPC armor drop chance）
- **MedkitFull 空投箱**（如果 Sprint 8 沒先放在 Elite drop）
- **Channel 式補血（按 H 使用 1 秒、可被打斷）**：Q3 選項 B
- **武器稀有度標記（Common/Uncommon/Rare/Epic）**：影響 NPC drop 抽 weapon 時的權重

---

## 6. 為什麼不建議「全部一起做」

1. **變數隔離**：Sprint 8 改 200 HP 後，CEO 需要先實際玩 1–2 天確認新節奏舒服；同時加護甲、加 4 把新武器、加 channel 補血會讓「為什麼戰鬥手感變了」難以歸因
2. **Sprint 7 receipt 已標記未做事項**：Wraith 第三人稱卡牆、observatory 物理隔離、NPC 攻擊節奏未細調 — 這些更該優先驗
3. **Roblox 的 hot reload 痛點**：每次改 GameConfig 後要重啟 playtest 重打一輪 PvE → 才能驗證 PvP；變數一次改太多 ROI 低
4. **CLAUDE.md §2 Simplicity First**：本次提案核心是「玩家不會太快被打倒」，最小達成路徑就是 Sprint 8 範圍

---

## 7. Sprint 8b 工作項目（CEO 決議 b 後重寫）

> ⚠️ **Sprint 8a 必須先完成**：補 main 上 12 commits 的 workload contracts + receipts（見 §10 評估章節）。Sprint 8b 在 8a 完成後執行。

### 7.1 前置（CEO 拍板前不開工）
- [ ] CEO 確認新 Rarity DPS 倍率（提議 1.0/1.15/1.30/1.50/1.70/1.90）
- [ ] CEO 拍板 Headshot multiplier（提議 2.0x）
- [ ] CEO 拍板 NPC HP/Dmg ×2
- [ ] CEO 拍板 MedkitFull 是否 5% drop on Elite
- [ ] Claude 提交 `proposals/30-weapon-dps-retune.md`（30 武器逐一 Damage 新值，CEO 一次拍板）

### 7.2 實作（CEO 拍板後）
```
1. GameConfig.lua:
   - MAX_HP 100 → 200
   - HEADSHOT_MULTIPLIER = 2.0 (新增)
   - RARITY 倍率：1.0/1.25/1.55/1.95/2.40/3.00 → 1.0/1.15/1.30/1.50/1.70/1.90
   - 30 把 WEAPONS Damage 按新公式 retune（值參考 30-weapon-dps-retune.md）
   - ENEMIES HP/Damage ×2（Patrol 60→120/10→18, Armored 150→300/15→28, Elite 250→500/25→40）
   - LOOT 加 MedkitSmall/Medkit/MedkitLarge/MedkitFull 4 階
   - LOOT.Medkit.Heal 50 → 100（標準級）

2. MatchManager.lua:
   - FireWeapon handler：加 config.Type=="Sniper" && hitPart.Name=="Head" 分支套用 HEADSHOT_MULTIPLIER
   - initPlayerData MAX_HP=200
   - healPlayer 邏輯由 LootSystem 傳入 heal amount，不再讀 GameConfig.MEDKIT_HEAL 常數

3. NPCSystem.lua:
   - GameConfig.ENEMIES LootTable 更新：Patrol 加 MedkitSmall, Armored 維持 Medkit,
     Elite 改 MedkitLarge + MedkitFull
   - dropLoot 對應 medkit tier 與 NPC type（不再有 Weapon drop）

4. LootSystem.lua:
   - createPickup 加 4 階 medkit case（顏色：淺綠 → 標準綠 → 深綠 → 米白）
   - Touched handler 對應 healPlayer 各自回血量

5. HUDController.lua:
   - 確認 HP 條 maxHP=200 顯示正確（用比例計算則無需改，硬編碼 100 則改讀 GameConfig.MAX_HP）

6. workloads/03,04,05,06,07.yaml: 更新 success_criteria 與 status

7. Studio MCP playtest（單人）：
   - NPC TTK 對玩家：Patrol 18 dmg / 1.0s attack vs 200 HP = ~11 秒（vs 現在 ~5 秒）
   - 玩家對 NPC TTK：每個 Type 至少測 1 把 Common + 1 把 Demon（驗證 DPS gap 收斂）
   - Sniper headshot：Wraith Scout 對 NPC.Head 觸發 ×2 倍率
   - 4 階 medkit 拾取與回血量

8. receipts/sprint-8b-200hp.md: 產出
```

### 7.3 成功條件
- 玩家 200 HP 起始，HP cap 200
- 4 階 medkit 顏色可辨、回血量 50/100/150/200，不會超過 200
- 30 武器 Damage 落在新 Rarity DPS 公式 ±5%
- Sniper headshot 倍率正確套用（5 把 Wraith 系列）
- 其他 Type 命中 Head part = 一般傷害（無加成）
- Common 武器（Viper Mk1 等）對 200 HP 玩家 TTK 落在 2.5–3.0s
- Demon 武器 vs Common 武器 TTK 差距 ≤ 1:1.9（從現在 1:3 收斂）
- NPC ×2 不會 4 秒帶走站著不動的玩家
- 0 console error

---

## 8. 影響的檔案清單

| 檔案 | Sprint 8b 改動 | Sprint 9 改動 |
|---|---|---|
| `src/ReplicatedStorage/GameConfig.lua` | MAX_HP, RARITY 倍率, **30 武器 Damage**, HEADSHOT_MULTIPLIER, ENEMIES ×2, LOOT 4 階 medkit | + ARMOR, + ARMOR pickup config |
| `src/ServerScriptService/MatchManager.lua` | FireWeapon Type=="Sniper" headshot 分支, initPlayerData 200 HP, healPlayer 多 medkit type | damagePlayer 護甲吸收公式, ArmorUpdate 廣播 |
| `src/ServerScriptService/NPCSystem.lua` | LootTable 加 4 階 medkit type, dropLoot 對應（移除 Weapon — main 已移除） | + ArmorPlate drop |
| `src/ServerScriptService/LootSystem.lua` | createPickup 4 階 medkit 顏色, healPlayer 帶 amount | + ArmorPlate pickup |
| `src/StarterPlayerScripts/HUDController.lua` | （可能無）maxHP 200 適配 | + 護甲條 overlay |
| `workloads/03–07.yaml` | 全部更新 success_criteria | + workloads/11-armor-system.yaml |
| `proposals/30-weapon-dps-retune.md` | **NEW**（Sprint 8b 開工前由 Claude 提交，CEO 一次拍板 30 武器 Damage） | — |

---

## 9. Sprint 8a — 衛生補課（必須先做）

> ⚠️ main 上的 12 commits 帶進來大量未文件化系統。Peter Pangg 框架的「Receipt 是一級物件」原則被破壞。Sprint 8b 開工前必須補齊。

### 9.1 補 workload contracts（NEW）
- [ ] `workloads/12-currency-service.yaml` — 子彈幣經濟（Rewards/MatchCaps）
- [ ] `workloads/13-shop-service.yaml` — 30 武器商店 + EquipPrimaryWeapon
- [ ] `workloads/14-daily-quest.yaml` — 6 種任務 + UTC reset
- [ ] `workloads/15-fps-viewmodel.yaml` — CameraController + ViewmodelController + crosshair-aligned aim
- [ ] `workloads/16-npc-weapons.yaml` — NPC 持槍 + NPCWeaponEffectsClient

### 9.2 補 receipts（NEW）
- [ ] `receipts/sprint-8a-shop-economy-fps.md` — 12 commits 的決策、實測、issues
  - 涵蓋 commits: 5928547, 18db315, 3db2349, d054043, a66dc4a, 78c4b9f, 2cf21f0, 9e9cf72, f0c33d8, 7d20bb6, ab5a601, c94f8e5, 253863f, 6236dc1, 9829d65, cc88d6c

### 9.3 更新 CLAUDE.md Lessons Learned
- [ ] FPS viewmodel 需要 ViewmodelController (Camera context) 與 character 分離
- [ ] crosshair 必須在自己的 ScreenGui 隔離（issue #13 reviewer 要求）
- [ ] 子彈軌跡與 crosshair 對齊（issue #5/6/7 修正）
- [ ] HP reset on death 不靠 Roblox spawn 而靠手動 setter
- [ ] PvP 5min timer 用 task.wait 累計

### 9.4 更新已存在的 workload contracts（現實對齊）
- [ ] `workloads/04-weapon-system.yaml`：6 武器 → 30 武器 + RARITY 系統
- [ ] `workloads/06-loot-system.yaml`：移除武器 drop 章節
- [ ] `workloads/07-hud.yaml`：crosshair 改為 4-segment open-center

→ **Sprint 8a 純文件，0 風險，0.5 天**。完成後 Sprint 8b 才有對齊現實的設計地圖。

---

## 等 CEO 回覆的決策點摘要

### 已決議
- [x] **Q1** Wraith headshot — ✅ 改為 Type-based 機制（`config.Type=="Sniper"` 套用 HEADSHOT_MULTIPLIER）
- [x] **Q2** Thunder — ✅ Type-based、Pellets 數維持各武器既有設定（不再強制 10 pellets）
- [x] **(b) 30 武器 DPS 公式收斂** — ✅ 2026-05-03 CEO 拍板，新倍率 1.0/1.15/1.30/1.50/1.70/1.90
- [x] **Q5** 新武器 — ✅ 不需新增（Hailstorm 迷你槍 / Thunder Triple 三管已存在；古代長火槍延 Sprint 10）

### 尚待拍板
- [ ] **HEADSHOT_MULTIPLIER 確認 2.0x**（提議 B；A 1.33x 較保守）
- [ ] **Q3** 補血 channel 延後 Sprint 9？（推薦 A：8b 即時觸碰回血）
- [ ] **Q4** 護甲片延後 Sprint 9？（推薦 B：8b 不做）
- [ ] **NPC 數值** 用 ×2 值（120/300/500 HP）？（推薦 ×2）
- [ ] **MedkitFull 5% drop on Elite** 在 8b 出？（推薦 yes）
- [ ] **30-weapon-dps-retune.md follow-up doc** 由 Claude 在 8b 開工前提交

### 已撤回
- ~~Stinger 微調 18 → 20~~ — 撤回（main 上 Stinger 系列已分 Mk2/Tac/Burst/Storm 4 把，個別調整不適合批量做，全部走 (b) 公式 retune）
