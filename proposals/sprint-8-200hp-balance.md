# Sprint 8 提案：200 HP 戰鬥平衡

Date: 2026-05-03
Author: claude-code
Driving feedback: CEO「把玩家血量改成 200 HP，重新平衡武器/NPC/補血/掉落，加入護甲片」
Status: 🔄 部分拍板（Q1/Q2 RESOLVED 2026-05-03 / Q3-Q5 + NPC + Stinger 仍待決策）

## 決策狀態
| 項目 | 狀態 | 決議 |
|---|---|---|
| **Q1** Wraith 1 發秒殺 vs 2 發 | ✅ RESOLVED 2026-05-03 | **身體 150 dmg（75%）+ 爆頭 200 dmg（一發秒殺）— 新增 headshot 偵測** |
| **Q2** Thunder per-pellet vs 總傷害 | ✅ RESOLVED 2026-05-03 | **10 pellets × 13 dmg，近距離滿中 130、中遠距離靠 spread 自然散落** |
| Q3 channel 式補血 | ⏳ 待決策（推薦延後 S9） | — |
| Q4 護甲片系統 | ⏳ 待決策（推薦 S9） | — |
| Q5 4 把新武器 | ⏳ 待決策（推薦 S10+） | — |
| NPC 數值（提案值 vs ×2） | ⏳ 待決策（推薦 ×2） | — |
| Stinger 微調 18 → 20 | ⏳ 待決策（推薦微調） | — |

---

## TL;DR

**支持核心方向**（200 HP 確實能解決「秒死、補血無意義、最終決戰太短」三個現存問題）。

但提案內含 **5 個需要 CEO 拍板的設計分歧**、**3 個項目超出單 Sprint 範圍**、以及 **1 個會影響武器定位的副作用**。建議：

| Sprint | 範圍 | 風險 | 工程量估計 |
|---|---|---|---|
| **Sprint 8** | 200 HP + 武器 6 把重平衡 + NPC 重平衡 + 4 階補血包 | 低 | ~1 天 |
| **Sprint 9** | 護甲片系統（pickup + HUD overlay + 傷害吸收） | 中 | ~1 天 |
| **Sprint 10+** | 4 把新武器 / 子彈幣碎片＋核心 / 補血通道使用 / 訓練場 | 高（已超出本提案） | 各 0.5–1 天 |

不建議一口氣全做，理由見 §6。

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

以下用現存 6 把武器的 fire rate 計算實際 TTK（單位：秒；命中率假設 100%，純頭/胸無 headshot 倍率）。

| 武器 | 現在 dmg | 現在 TTK（vs 100HP） | CEO 提案 dmg | 新 TTK（vs 200HP） | 變化 | 評估 |
|---|---|---|---|---|---|---|
| Viper (Pistol) | 25 | 4 發 / 1.6s | 35 | 6 發 / 2.4s | +50% | ✅ 合理，手槍應該是「打不過撤退換槍」 |
| Stinger (SMG) | 15 | 7 發 / 0.56s | 18 | 12 發 / 0.96s | +71% | ⚠️ TTK 比現在拉長 71%，近距離換槍會太久 |
| Phantom (Rifle) | 30 | 4 發 / 0.6s | 45 | 5 發 / 0.75s | +25% | ✅ 主力武器手感維持，最好 |
| Thunder (Shotgun) | 12×8=96 | 1 發 / 0s | 13×10=130 | 1–2 發近距 / 多發中遠距 | 散落機制 | ✅ Q2 RESOLVED：10 pellets × 13 |
| Wraith (Sniper) | 90 | 1 發 / 0s | 150 / 200 爆頭 | 身體 2 發 / 爆頭 1 發 | headshot 機制 | ✅ Q1 RESOLVED：身體 75% / 爆頭 100% |
| Fang (Knife) | 40 | 3 揮 / 1.5s | 60 | 4 揮 / 2.0s | +33% | ✅ 近戰風險換報酬合理 |

\* `90~140` 看起來是總傷害範圍而非 per-pellet，需要 CEO 確認（Q2）。

---

## 3. ❓ 待 CEO 拍板（Q1–Q5）

### Q1: Wraith 狙擊是否仍然「一發致命」？ ✅ RESOLVED 2026-05-03

**CEO 決議**：採類似選項 C 的設計
- **擊中身體** = 150 dmg（玩家從 200 → 50，剩 25%，但仍存活）
- **擊中頭** = 200 dmg（一發秒殺）

**工程影響**：需要新增 **headshot 偵測**。詳見 §3.5。

### Q2: Thunder 霰彈槍 90~140 是「總傷害」還是「per-pellet」？ ✅ RESOLVED 2026-05-03

**CEO 決議**：

| 屬性 | 值 |
|---|---|
| 每次散彈數（Pellets） | **10**（從 8 提高到 10） |
| 每顆傷害（Damage per pellet） | **13** |
| 近距離全中總傷害 | 130（10 × 13）|
| 中距離總傷害（期望） | 60–90（5–7 顆命中）|
| 遠距離總傷害（期望） | 20–40（2–3 顆命中）|

**設計解讀**：中/遠距離傷害衰減 = **靠 spread 自然散落**（彈丸偏離目標 miss），不是新增距離 falloff 機制。

**工程影響**：
- `GameConfig.WEAPONS.Thunder.Pellets` 8 → 10
- `GameConfig.WEAPONS.Thunder.Damage` 12 → 13
- 不改 spread（現值 0.1）— playtest 後若中遠距太低/太高再 tune
- 如果實測中遠距落在期望外，調整 spread 或加距離 falloff（Sprint 8 子任務）

### 3.5 ⚙️ Headshot 系統（Q1 衍生新工程）

**範圍**：Sprint 8 必須做，但**只 Wraith 套用**。其他 5 把武器爆頭仍同 dmg。

**理由**：
- 全武器爆頭 1.5x/2x 是 FPS 標準但會打亂 §2 TTK 表（Phantom 5 發殺變 3 發），影響面太大
- CEO 訊息只描述 Wraith 爆頭機制，採最小範圍實作
- Sprint 9+ 評估是否擴展到全武器

**實作邏輯**（MatchManager.lua FireWeapon handler）：
```lua
-- 偽程式碼
local hitPart = result.Instance
local hitChar = hitPart.Parent
local isHeadshot = hitPart.Name == "Head"

local damage = config.Damage
if weaponName == "Wraith" and isHeadshot then
    damage = config.HeadshotDamage  -- 200，定義在 GameConfig
end
```

**GameConfig 新增**：
```lua
Wraith = {
    ...
    Damage = 150,
    HeadshotDamage = 200,  -- NEW
    ...
}
```

**對 NPC 也適用**（R15 NPC 也有 Head part，命名一致）。爆頭 NPC 的 Wraith 即殺：
- Patrol 120 HP → Wraith 一發秒殺（爆頭 200）/ 身體 1 發剩 -30 → 也死
- Armored 300 HP → 爆頭 200（剩 100）/ 身體 150（剩 150），仍要 2 發
- Elite 500 HP → 爆頭 200（剩 300）/ 身體 150（剩 350），仍要 3 發

**驗證項目**：
- [ ] 玩家 vs 玩家：Wraith 爆頭 1 發殺 / 身體 2 發殺
- [ ] 玩家 vs Patrol：Wraith 爆頭 1 發殺
- [ ] 玩家 vs Armored：Wraith 身體 2 發 / 爆頭 + 身體 2 發
- [ ] 其他武器（Viper/Stinger/Phantom/Thunder/Fang）爆頭傷害 = 一般傷害（不加成）
- [ ] killfeed 顯示 "[Wraith] HEADSHOT" 標記（visual polish，可延後）

**已知風險**：
- Roblox R15 Head part 是 MeshPart，命名固定為 "Head"，但 Sprint 7 NPC 有掛 helmet/hood 等 accessories（NPCSystem.lua:73,79,88），這些 accessory part 命名不是 "Head" 但 parent 是 Head — raycast 命中 accessory 不算 headshot。**這是 ok 的**（爆頭應該命中頭部本體，命中頭盔讓盔甲擋下也合理）。
- 如果 hitPart 是 hat/cap accessory（Patrol 警衛帽），目前邏輯會視為非爆頭。如果 CEO 希望「命中頭部任何部位都算」，需擴展邏輯查 hitPart.Parent 鏈。**Sprint 8 採嚴格 Head part only**。

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

這 4 把是新武器，不是現存 6 把的調整。每把要：
- `GameConfig.WEAPONS` 加數據
- `WeaponMeshes.lua` 加 builder（Sprint 7 才剛做完 6 把的 mesh，每把約 30–60 行）
- `LootSystem` / `NPCSystem` 抽武器池更新
- 第三人稱握持位置實測（Sprint 7 receipt 記錄 Wraith 太長卡牆，需注意）

→ **Claude 建議：Sprint 10 候選**，本次提案範圍不做。理由：
1. 6 把武器已經涵蓋手槍/SMG/步槍/霰彈/狙擊/近戰 5 種定位
2. 左輪 = 慢射速手槍版 Viper、迷你槍 = 連射版 Stinger，定位重複
3. 古代長火槍是有趣的差異化武器，但需要單獨設計（裝填動畫、單發大威力的反饋）

---

## 4. Sprint 8 範圍（推薦）

只做「血量平衡」，不做護甲、不做新武器、不做 channel 補血。

### 4.1 玩家
- `MAX_HP` 100 → 200
- `MEDKIT_HEAL` 棄用，改為 4 階補血量（見 4.3）
- 淘汰機制不變
- 觸碰補血包仍然立即回血（4 階差異就是回多少）

### 4.2 武器（6 把現存）

| 武器 | 新 dmg | FireRate（不動） | Pellets | 特殊機制 | 備註 |
|---|---|---|---|---|---|
| Viper | **35** | 0.4s | — | — | 半自動手槍 |
| Stinger | **20** | 0.08s | — | — | ⚠️ 比 CEO 提案 18 略高，維持 SMG 近戰壓制力（待 CEO 確認） |
| Phantom | **45** | 0.15s | — | — | 主力步槍 |
| Thunder | **13** | 0.8s | **10** | spread 自然散落 | ✅ Q2: 10 pellets，近距滿中 130 |
| Wraith | **150 身體 / 200 爆頭** | 1.5s | — | **headshot 偵測** | ✅ Q1: hitPart.Name=="Head" 觸發 |
| Fang | **60** | 0.5s | — | — | 近戰 |

> **Stinger 偏離提案的理由**：提案 18 dmg × FireRate 0.08 對 200 HP = TTK 0.96s（12 發），Stinger 的 magsize 是 30 發，等於每換 1 顆殺人也要燒掉 40% 彈匣，遠不如 Phantom (5 發 / 25 mag = 20%)。改 20 dmg 維持 SMG 「近戰熱兵器」定位。**待 CEO 確認是否接受微調**。

> **Wraith headshot 工程細節**：見 §3.5。需要修改 `MatchManager.lua` FireWeapon handler 加 hitPart.Name=="Head" 判斷分支，僅 Wraith 套用。其他 5 把武器命中頭部 = 正常傷害（Sprint 8 不擴展全武器爆頭機制）。

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

維持現存的「每個 slot 獨立 roll」模型（見 NPCSystem.lua:172）。

**Patrol** （目標：每殺 1 隻平均 ~1 個道具）：
```
Ammo:        0.50
MedkitSmall: 0.25
Coin:        0.20
Weapon:      0.10  (random from 6 weapons)
```

**Armored**：
```
Ammo:        0.50
Medkit:      0.35
Coin:        0.35
Weapon:      0.20
```

**Elite**：
```
Ammo:        0.70
MedkitLarge: 0.50
MedkitFull:  0.05   (待 CEO 拍板，是否在這出)
Coin:        0.60
Weapon:      0.45
```

> 提案表中提到的「護甲片」「子彈幣碎片/核心」「Common/Uncommon/Rare/Epic 武器稀有度」**全部 Sprint 9+ 處理**。Sprint 8 的 Weapon pickup 仍是「隨機從 6 把現存武器抽一把」。

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

## 7. Sprint 8 工作項目（如 CEO 拍板）

```
1. GameConfig.lua:        改 MAX_HP, 武器 6 把 dmg, Wraith.HeadshotDamage=200,
                          Thunder Pellets 8→10, NPC HP/dmg, LOOT 加 4 階 medkit
2. MatchManager.lua:      FireWeapon handler 加 hitPart.Name=="Head" 判斷（Wraith only）,
                          initPlayerData MAX_HP=200, healPlayer 對應不同 medkit type
3. NPCSystem.lua:         loot table 更新, dropLoot 對應 4 階 medkit type
4. LootSystem.lua:        createPickup 對應 4 階 medkit, 顏色區分（淺綠→深綠→金綠→白）
5. HUDController.lua:     [可能無需改] 確認 HP 條 maxHP=200 時顯示正確
6. workloads/03,04,05,06,07.yaml: 更新 success_criteria 與 status
7. Studio MCP playtest:   單人跑 PvE 1 輪 → 驗證：
                          - NPC TTK 對玩家
                          - 玩家 TTK 對 NPC
                          - Wraith 對 R15 NPC.Head 部位 raycast 命中觸發 200 dmg
                          - Thunder 10 pellets，近距全中 130，遠距散落實測
                          - 4 階 medkit 拾取
8. receipts/sprint-8-200hp.md: 產出
```

成功條件：
- 玩家 200 HP 起始，HP cap 200
- 4 階 medkit 顏色可辨、回血量正確、不會超過 200
- 6 把武器 TTK 落在 §2 表格估計（容差 ±0.2s，因為 fire rate 不動）
- **Wraith headshot 200 dmg / body 150 dmg 在 server 正確分流**
- **Thunder 10 pellets × 13 dmg，近距全中 130，遠距 20–40（spread 散落驗證）**
- NPC 不會 4 秒帶走站著不動的玩家（用 Patrol 站樁測）
- 0 console error

---

## 附：影響的檔案清單

| 檔案 | Sprint 8 改動 | Sprint 9 改動 |
|---|---|---|
| `src/ReplicatedStorage/GameConfig.lua` | MAX_HP, WEAPONS dmg, ENEMIES, LOOT 4 階 medkit | + ARMOR, + ARMOR pickup config |
| `src/ServerScriptService/MatchManager.lua` | initPlayerData 200 HP, healPlayer 多 medkit type | damagePlayer 護甲吸收公式, ArmorUpdate 廣播 |
| `src/ServerScriptService/NPCSystem.lua` | loot table, 4 階 medkit dropLoot | + ArmorPlate drop |
| `src/ServerScriptService/LootSystem.lua` | createPickup 4 階 medkit 顏色 | + ArmorPlate pickup |
| `src/StarterPlayerScripts/HUDController.lua` | （可能無）maxHP 200 適配 | + 護甲條 overlay |
| `workloads/03–07.yaml` | 全部更新 success_criteria | + workloads/11-armor-system.yaml |

---

## 等 CEO 回覆的決策點摘要

- [x] **Q1** Wraith — ✅ 身體 150 dmg / 爆頭 200 dmg（一發秒殺）
- [x] **Q2** Thunder — ✅ 10 pellets × 13 dmg，spread 自然散落
- [ ] **Q3** 補血通道使用機制延後 Sprint 9？（推薦 A：S8 即時觸碰回血）
- [ ] **Q4** 護甲片延後 Sprint 9？（推薦 B：S8 不做）
- [ ] **Q5** 4 把新武器延後 Sprint 10+？（推薦：本提案不含）
- [ ] **NPC 數值** 用提案值（100/220/350）還是 ×2 值（120/300/500）？（推薦 ×2）
- [ ] **Stinger 微調 20 dmg 而非 18**？（推薦微調）
