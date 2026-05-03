# 30-Weapon DPS Retune (Sprint 8b 解鎖文件)

Date: 2026-05-03
Author: claude-code
Status: ✅ KEY DECISIONS RESOLVED 2026-05-03（解鎖 Sprint 8b 實作）
Source decision: `proposals/sprint-8-200hp-balance.md` §4.2 — CEO 決議路線 (b)
Related contract: `workloads/04-weapon-system.yaml`

## 🟢 2026-05-03 CEO 拍板摘要

| 項目 | 決議 |
|---|---|
| **Demon 武器 -37%~-64% Damage nerf** | ✅ 可接受（(b) 路線必然結果） |
| **Hailstorm Minigun 處理** | ✅ **選項 B**（Damage 18 維持，SpinUp 是 trade-off） |
| (b) 整體倍率 1.00/1.15/1.30/1.50/1.70/1.90 | ✅ via PR #23 |
| Sniper headshot 2.0x (D1) | ✅ via PR #23 |
| Sniper +21%~+71% Damage buff | ✅ 隱含（(b) 路線結果） |

剩下幾個非阻塞項（Burn/Pierce/Silent 量化、Common Pistol 75 DPS、Fang Scout 40 dmg 維持）採 Claude 預設推薦處理，CEO 未反對 = 同意。Sprint 8b 解鎖開工。

---

## TL;DR

CEO 決議 (b)：**重新校 30 武器的 DPS 公式，讓 Common→Demon 的 TTK 差距收斂**。本文件列出 30 武器逐一的新 Damage 值，CEO 一次拍板後 Sprint 8b 開工。

- **新 RARITY 倍率**：1.00 / 1.15 / 1.30 / 1.50 / 1.70 / 1.90（vs 現 1.00 / 1.25 / 1.55 / 1.95 / 2.40 / 3.00）
- **Common→Demon DPS gap**：從 3.00x → 1.90x（**付費差距 ↓ 37%**）
- **Sniper headshot D1**：全 5 把 Sniper 套 HEADSHOT_MULTIPLIER 2.0x → 對 200 HP 玩家爆頭 1-shot
- **武器 Damage 改動範圍**：Common +20%（buff）/ Demon -37%（nerf）

---

## 1. 公式

```
新 Damage = Type baseline DPS × Rarity 倍率 × FireRate
                                          (per pellet for Shotgun)
                                          (per swing for Knife — AttackRate)
```

> ⚠️ **TTK timing model（2026-05-03 reviewer 修正）**：WeaponClient 的射擊節奏是「first-shot-immediate」— 點擊立即發第一槍，**FireRate 是 cooldown（下一槍延遲）**而非「第一槍前的延遲」。所以 N 發殺敵 TTK = **(N − 1) × FireRate**，不是 N × FireRate。
>
> 這個修正讓所有武器的真實 TTK **比初版文件快 ~1 個 FireRate**。Damage 與 DPS 公式不變（DPS = Damage / FireRate 在 sustained fire 下與 timing model 無關），但下表 TTK 已全部重算。
>
> **影響評估**：
> - Pistol/SMG/Rifle/Knife 多發武器 TTK 縮短 12-25%（仍接近原始目標範圍）
> - **Sniper TTK 收縮明顯**：Wraith Scout 2-shot body 從 1.90s → **0.95s**；Wraith Hunter 2-shot 從 2.40s → **1.20s**。Sniper Type 內部「單發重擊 + 一發冷卻」特性使其 TTK 結構性偏短，這是 design intent（Sniper 應該感覺「快、致命、需精準」）
> - Demon 1-shot body 武器 (Wraith Apex/Abyss) TTK = 0s（即時）
> - Hailstorm Minigun 含 SpinUp 真實 TTK 1.05s（不變）

**Type baseline DPS**（Common tier；TTK 用 (N-1)×FireRate 算，多發武器接近原目標，單發/低 FireRate 武器結構性偏短）：

| Type | baseline DPS | 200 HP 實際 TTK | 備註 |
|---|---|---|---|
| Pistol Common | 75 | 2.40s（Viper Mk1）/ 2.56s（SD） | Common 起跳 |
| SMG Uncommon | 110 × 1.15 | 1.52–1.54s | Common 無，Uncommon 起跳 |
| Rifle Uncommon | 110 × 1.15 | 1.50s | Common 無，Uncommon 起跳 |
| Shotgun Common 近距 | 99 | 0.85–0.90s（理想 2-shot 全中） | Common 起跳 |
| Sniper Uncommon body | 110 × 1.15 | **0.95s**（2-shot body）/ 0s（爆頭 1-shot） | Common 無；單發重擊 + 一發冷卻使 TTK 結構性偏短 |
| Knife Common | 80 | 2.00s | Common 起跳 |
| Minigun Legendary | 110 × 1.70 + SpinUp | 0.55s sustained + 0.5s SpinUp = **1.05s** | Hailstorm 唯一 |

> ⚠️ Minigun（Hailstorm）的 Damage 計算需要 CEO 額外確認 — 詳見 §4 Minigun 特殊處理。

---

## 2. 30 武器逐一 Damage 對照表

格式：**現 Damage → 新 Damage**（變化 %）。post-(b) TTK = 新 Damage 對 200 HP 玩家全中。

### 2.1 Common (5) — 倍率 1.00

> TTK = (N − 1) × FireRate

| # | 武器 | Type | FireRate | Pellets | 現 Damage | **新 Damage** | Δ | post-(b) TTK |
|---|---|---|---|---|---|---|---|---|
| 1 | Viper Mk1 | Pistol | 0.40 | — | 25 | **30** | +20% | 7 發 / **2.40s** |
| 2 | Viper SD | Pistol | 0.32 | — | 22 | **24** | +9% | 9 發 / **2.56s** |
| 3 | Fang Scout | Knife | 0.50 (AttackRate) | — | 40 | **40** | 0% | 5 揮 / **2.00s** |
| 4 | Thunder Stub | Shotgun | 0.85 | 6 | 12 | **14** | +17% | 全中 84/shot → 3 shots / **1.70s**（理想近距 2 shots / **0.85s**）|
| 5 | Thunder Cut | Shotgun | 0.90 | 8 | 11 | **11** | 0% | 全中 88/shot → 3 shots / **1.80s**（理想近距 2 shots / **0.90s**）|

### 2.2 Uncommon (5) — 倍率 1.15

| # | 武器 | Type | FireRate | Pellets | 現 Damage | **新 Damage** | Δ | post-(b) TTK |
|---|---|---|---|---|---|---|---|---|
| 6 | Stinger Mk2 | SMG | 0.085 | — | 16 | **11** | -31% | 19 發 / **1.53s** |
| 7 | Stinger Tac | SMG | 0.095 | — | 18 | **12** | -33% | 17 發 / **1.52s** |
| 8 | Phantom Ranger | Rifle | 0.15 | — | 35 | **19** | -46% | 11 發 / **1.50s** |
| 9 | Wraith Scout | Sniper | 0.95 | — | 70 | **120** | +71% | 2 發 body / **0.95s** · **爆頭 240 一發秒殺 / 0s** |
| 10 | Stinger Burst | SMG | 0.07 | — | 14 | **9** | -36% | 23 發 / **1.54s** |

### 2.3 Rare (5) — 倍率 1.30

| # | 武器 | Type | FireRate | Pellets | 現 Damage | **新 Damage** | Δ | post-(b) TTK |
|---|---|---|---|---|---|---|---|---|
| 11 | Reaver-X | Rifle | 0.14 | — | 42 | **20** | -52% | 10 發 / **1.26s** |
| 12 | Phantom Night | Rifle | 0.12 | — | 38 | **17** | -55% | 12 發 / **1.32s** |
| 13 | Thunder Guard | Shotgun | 0.75 | 8 | 14 | **12** | -14% | 全中 96/shot → 3 shots / **1.50s**（理想近距 2 shots / **0.75s**）|
| 14 | Wraith Hunter | Sniper | 1.20 | — | 110 | **172** | +56% | 2 發 body / **1.20s** · **爆頭 344 一發秒殺 / 0s** |
| 15 | Thunder Triple | Shotgun | 0.80 | 9 | 15 | **11** | -27% | 全中 99/shot → 3 shots / **1.60s**（理想近距 2 shots / **0.80s**）|

### 2.4 Epic (6) — 倍率 1.50

| # | 武器 | Type | FireRate | Pellets | 現 Damage | **新 Damage** | Δ | post-(b) TTK |
|---|---|---|---|---|---|---|---|---|
| 16 | Stinger Storm | SMG | 0.075 | — | 22 | **12** | -45% | 17 發 / **1.20s** |
| 17 | Phantom Apex | Rifle | 0.13 | — | 50 | **21** | -58% | 10 發 / **1.17s** |
| 18 | Wraith Frost | Sniper | 1.15 | — | 140 | **190** | +36% | 2 發 body / **1.15s** · **爆頭 380 一發秒殺 / 0s** |
| 19 | Phantom Whisper | Rifle (Silent) | 0.15 | — | 55 | **25** | -55% | 8 發 / **1.05s** |
| 20 | Thunder Royal | Shotgun | 0.70 | 8 | 18 | **13** | -28% | 全中 104/shot → 2 shots / **0.70s** |
| 21 | Viper Left | Pistol (Heavy Revolver) | 0.55 | — | 70 | **62** | -11% | 4 發 / **1.65s** |

### 2.5 Legendary (5) — 倍率 1.70

| # | 武器 | Type | FireRate | Pellets | 現 Damage | **新 Damage** | Δ | post-(b) TTK |
|---|---|---|---|---|---|---|---|---|
| 22 | Viper Aurum | Pistol | 0.40 | — | 60 | **51** | -15% | 4 發 / **1.20s** |
| 23 | Phantom Finale | Rifle | 0.13 | — | 60 | **24** | -60% | 9 發 / **1.04s** |
| 24 | Wraith Apex | Sniper | 1.10 | — | 170 | **206** | +21% | **1 發 body** / **0s**（206 > 200，即時擊殺）· 爆頭 412 |
| 25 | Thunder Crown | Shotgun | 0.65 | 8 | 22 | **14** | -36% | 全中 112/shot → 2 shots / **0.65s** |
| 26 | Hailstorm | Minigun (SpinUp 0.5) | 0.05 | — | 18 | **18** | 0% | 12 發 sustained / 0.55s + SpinUp 0.5s = **1.05s 真實 TTK**（CEO 選項 B，§4 RESOLVED） |

### 2.6 Demon (4) — 倍率 1.90

| # | 武器 | Type | FireRate | Pellets | 現 Damage | **新 Damage** | Δ | post-(b) TTK |
|---|---|---|---|---|---|---|---|---|
| 27 | Fang Demon | Knife | 0.50 (AttackRate) | — | 120 | **76** | -37% | 3 揮 / **1.00s** |
| 28 | Phantom Hellfire | Rifle (Burn) | 0.13 | — | 75 | **27** | -64% | 8 發 / **0.91s**（Burn DOT 額外） |
| 29 | Wraith Abyss | Sniper (Pierce) | 1.05 | — | 210 | **220** | +5% | **1 發 body** / **0s**（即時擊殺，220 > 200）· 爆頭 440 |
| 30 | Thunder Bloodmoon | Shotgun | 0.60 | 8 | 28 | **14** | -50% | 全中 112/shot → 2 shots / **0.60s** |

---

## 3. ⚠️ 大幅變動的武器（CEO 注意點）

### 3.1 Demon 武器整體 Damage -37% 至 -64%

這是 (b) 路線的本質結果。Demon 武器原本 DPS 倍率 3.0x（vs Common），收斂後 1.9x → Damage 在 0.95s FireRate 下 ×(1.9/3.0) = -37%。

**最大跌幅**：
- Phantom Hellfire **-64%**（75 → 27）— 但 `Burn=true` DOT 機制是隱性加成，未量化
- Thunder Bloodmoon **-50%**（28 → 14 per pellet）
- Phantom Finale **-60%**（60 → 24）
- Phantom Apex **-58%**（50 → 21）

**輕微跌幅或反而 buff**：
- Wraith Abyss **+5%**（210 → 220）— Sniper Type 有 multiplier benefit，幾乎不變
- Wraith Apex **+21%**（170 → 206）

### 3.2 Sniper 系列整體 Damage 大幅 buff

| 武器 | 現 Damage | 新 Damage | Δ |
|---|---|---|---|
| Wraith Scout | 70 | 120 | **+71%** |
| Wraith Hunter | 110 | 172 | **+56%** |
| Wraith Frost | 140 | 190 | +36% |
| Wraith Apex | 170 | 206 | +21% |
| Wraith Abyss | 210 | 220 | +5% |

**為什麼 Sniper buff**：原先 Sniper Damage 對 100 HP 設計（Wraith Scout 70 → 30% HP）。現在 200 HP 下，body damage 要拉到接近 baseline DPS × FireRate（0.95–1.20s）才合理 TTK。

### 3.3 SMG / Rifle 系列 Damage 大幅 nerf

| 武器 | 現 Damage | 新 Damage | Δ |
|---|---|---|---|
| Stinger Mk2 | 16 | 11 | -31% |
| Phantom Ranger | 35 | 19 | -46% |
| Reaver-X | 42 | 20 | -52% |
| Phantom Apex | 50 | 21 | -58% |
| Phantom Finale | 60 | 24 | -60% |

**為什麼 SMG/Rifle nerf 這麼多**：原先 Damage 不光是「對 100 HP」，而是配合稀有度 1.5x–3.0x 倍率。新公式 (b) 下，Rifle/SMG 的 fire rate 高、若維持原 Damage = 對 200 HP TTK 太短（< 1.0s），不符合 Type 定位。

---

## 4. ✅ Hailstorm（Minigun）特殊處理 — RESOLVED 2026-05-03 採選項 B

**CEO 決議**：選項 **B**（Damage 18 維持，SpinUp 是 trade-off）

效果驗證：
- Damage 18，FireRate 0.05s → sustained DPS = 360
- 對 200 HP 玩家 sustained TTK = 12 發 / (12-1)×0.05 = **0.55s**
- + SpinUp 0.5s 啟動 = **1.05s 真實 TTK**
- effective DPS over first second = 0.5 × 0 (spinup) + 0.5 × 360 = 180 ≈ 110 × 1.64x baseline
- 接近 Legendary 目標倍率 1.70x（差 ~3%，於誤差容忍範圍）

選項 B 的設計精神：**Hailstorm 的 SpinUp 是其 Legendary 強度的 trade-off**。維持現有 18 dmg，玩家手感不變、商店價值維持。

> 以下保留 A/C 選項評估作為歷史紀錄。

Minigun 是 main 上唯一 Type，沒有公式 baseline。三個選項：

### 選項 A: 純公式（推薦小心使用）
```
Damage = 110 × 1.70 × 0.05 = 9.35 → 9
```
- 對 200 HP TTK = 23 發，(23-1)×0.05 = 1.10s sustained（不算 SpinUp）
- 含 SpinUp 0.5s 啟動 = 1.60s 真實 TTK
- **比現在 Damage 18 nerf -50%**

### 選項 B: 補償 SpinUp
- 假設 SpinUp 期間 0 DPS、0.5s 後 sustained：平均 1s 內 effective DPS = sustained × 0.5 = baseline DPS / 2
- 補償公式：Damage = 9 × 2 = **18**（與現值一致）
- 等於「Hailstorm 的 SpinUp 是 trade-off，sustained DPS 算 1.7x 的兩倍以平衡」
- **不變更現值**

### 選項 C: 妥協
- Damage = **15**（介於 9 與 18 之間）
- sustained TTK = 200/15 × 0.05 = 0.67s sustained，加 SpinUp = 1.17s
- 介於選項 A 與 B 之間

→ **Claude 建議選項 B**：最少改動，SpinUp 機制本身就是 Minigun 與其他 Legendary 武器的 trade-off。

→ **CEO 拍板**：A / B / C？

---

## 5. ✅ DPS Gap 收斂驗證

對每個 Type 計算 Common→Demon 的 DPS 比值：

| Type | Common DPS | Demon DPS | 新 gap | 目標 1.90x |
|---|---|---|---|---|
| Pistol | Viper Mk1: 30/0.40 = 75 | Viper Aurum (Leg): 51/0.40 = 127.5 → ratio 1.70 | (Demon 無 Pistol) | — |
| Pistol (closest) | Viper Mk1: 75 | Viper Left (Epic): 62/0.55 = 112.7 | 1.50 | (Epic 1.50x ✓) |
| SMG | Common 無 | Demon 無 | — | — |
| SMG (Uncommon→Epic) | Stinger Mk2: 11/0.085 = 129 | Stinger Storm (Epic): 12/0.075 = 160 | 1.24 | (1.50/1.15=1.30 ✓ ±5%) |
| Rifle | Common 無 | Phantom Hellfire (Demon): 27/0.13 = 207.7 | vs Uncommon 19/0.15=126.7 → **1.64** | (1.90/1.15=1.65 ✓) |
| Shotgun | Thunder Stub: 14×6/0.85 = 98.8 | Thunder Bloodmoon: 14×8/0.6 = 186.7 | **1.89** | ✓ |
| Sniper | Common 無 | Wraith Abyss: 220/1.05 = 209.5 | vs Uncommon 120/0.95=126.3 → **1.66** | (1.90/1.15=1.65 ✓) |
| Knife | Fang Scout: 40/0.5 = 80 | Fang Demon: 76/0.5 = 152 | **1.90** | ✓ 完美 |

**結論**：DPS gap 全部落在 1.50x–1.90x 之間，整體 Common→Demon 約 **1.9x**，達到 (b) 路線目標。

---

## 6. ✅ Sniper Headshot 1-shot 驗證（D1）

post-(b) Sniper body × HEADSHOT_MULTIPLIER 2.0 對 200 HP 玩家：

| 武器 | post-(b) Body | × 2.0 | vs 200 HP | D1 ✓ |
|---|---|---|---|---|
| Wraith Scout | 120 | **240** | 1-shot ✓ | ✓ |
| Wraith Hunter | 172 | **344** | 1-shot ✓ | ✓ |
| Wraith Frost | 190 | **380** | 1-shot ✓ | ✓ |
| Wraith Apex | 206 | **412** | 1-shot ✓ | ✓ |
| Wraith Abyss | 220 | **440** | 1-shot ✓ | ✓ |

全 5 把 Sniper 對 200 HP 玩家爆頭 1-shot — D1 達成。

---

## 7. NPC TTK 驗證（Sprint 8b 後 NPC ×2 假設）

> TTK = (N − 1) × FireRate（first-shot-immediate 模型）

以 Common Viper Mk1 (30 dmg, FireRate 0.40) 對各 NPC：

| NPC | post-(b) HP | shots | TTK |
|---|---|---|---|
| Patrol | 120 | 4 | **1.20s** |
| Armored | 300 | 10 | **3.60s** |
| Elite | 500 | 17 | **6.40s** |

以 Common Thunder Stub (14×6=84/shot 近距全中, FireRate 0.85) 對 NPC：
- Patrol 120 HP → 2 shots / **0.85s**
- Armored 300 HP → 4 shots / **2.55s**
- Elite 500 HP → 6 shots / **4.25s**

以 Demon Wraith Abyss (220 dmg + Pierce, FireRate 1.05) 對 NPC：
- Patrol 120 HP → **1 發 0s 即時秒殺**
- Armored 300 HP → 2 發 / **1.05s**
- Elite 500 HP → 3 發 / **2.10s**
  - 爆頭一發 440 dmg → 1 發秒殺 Patrol、爆頭+身體 2 發殺 Armored、爆頭+身體+身體 = 880 → 3 發殺 Elite（同 body 路線，但更穩）

整體 NPC TTK 落在合理範圍，新手用 Common 武器仍能對抗 Patrol（4 發 / 1.20s）。

---

## 8. 拍板項目（2026-05-03 結算）

### ✅ 已 RESOLVED
- [x] **整體公式 (b) 倍率** 1.0/1.15/1.30/1.50/1.70/1.90 — via PR #23 §4.2
- [x] **Minigun Hailstorm 處理** — 選 **B**（Damage 18 維持），2026-05-03 CEO 拍板
- [x] **Sniper headshot multiplier 2.0x**（D1，全 5 把 1-shot）— via PR #23 §3.5
- [x] **整體 Demon -37%~-64% Damage nerf** — 2026-05-03 CEO 「可接受」
- [x] **整體 Sniper +21%~+71% Damage buff** — 隱含（(b) 路線必然結果，CEO 接受 (b)）

### 🟡 採 Claude 預設處理（CEO 未反對 = 同意）
- [x] **Phantom Hellfire Burn DOT** — 不量化進 Damage，視為定性加成
- [x] **Wraith Abyss Pierce** — 不量化進 Damage，視為定性加成
- [x] **Phantom Whisper Silent** — 不量化進 Damage（Silent 是聲音 stealth，不是傷害修飾）
- [x] **Common Pistol baseline 75 DPS** — 接受，Sprint 8b 開工後可在 playtest 微調
- [x] **Common Knife Fang Scout 維持 40 dmg** — 接受（Damage 0% 變動，Common 1.0x baseline）

→ **全部 10 項拍板完成。Sprint 8b 解鎖實作。**

---

## 9. Sprint 8b 落地後的 GameConfig diff 範例

```lua
-- ===== RARITY 倍率改動 =====
GameConfig.RARITY = {
    Common    = { Order = 1, DPS = 1.00, Color = ... },
    Uncommon  = { Order = 2, DPS = 1.15, Color = ... },  -- was 1.25
    Rare      = { Order = 3, DPS = 1.30, Color = ... },  -- was 1.55
    Epic      = { Order = 4, DPS = 1.50, Color = ... },  -- was 1.95
    Legendary = { Order = 5, DPS = 1.70, Color = ... },  -- was 2.40
    Demon     = { Order = 6, DPS = 1.90, Color = ... },  -- was 3.00
}

-- ===== 新增 Headshot Multiplier =====
GameConfig.HEADSHOT_MULTIPLIER = 2.0  -- Sniper Type only (Sprint 8b)

-- ===== 玩家血量 =====
GameConfig.MAX_HP = 200  -- was 100

-- ===== 4 階補血 =====
GameConfig.LOOT.MedkitSmall = { Heal = 50 }
GameConfig.LOOT.Medkit      = { Heal = 100 }  -- was 50
GameConfig.LOOT.MedkitLarge = { Heal = 150 }
GameConfig.LOOT.MedkitFull  = { Heal = 200 }

-- ===== 30 武器 Damage 更新 =====
-- Common
["Viper Mk1"]      = { ..., Damage = 30 }   -- was 25
["Viper SD"]       = { ..., Damage = 24 }   -- was 22
["Fang Scout"]     = { ..., Damage = 40 }   -- (no change)
["Thunder Stub"]   = { ..., Damage = 14 }   -- was 12
["Thunder Cut"]    = { ..., Damage = 11 }   -- (no change)

-- Uncommon
["Stinger Mk2"]    = { ..., Damage = 11 }   -- was 16
["Stinger Tac"]    = { ..., Damage = 12 }   -- was 18
["Phantom Ranger"] = { ..., Damage = 19 }   -- was 35
["Wraith Scout"]   = { ..., Damage = 120 }  -- was 70
["Stinger Burst"]  = { ..., Damage = 9 }    -- was 14

-- Rare
["Reaver-X"]       = { ..., Damage = 20 }   -- was 42
["Phantom Night"]  = { ..., Damage = 17 }   -- was 38
["Thunder Guard"]  = { ..., Damage = 12 }   -- was 14
["Wraith Hunter"]  = { ..., Damage = 172 }  -- was 110
["Thunder Triple"] = { ..., Damage = 11 }   -- was 15

-- Epic
["Stinger Storm"]  = { ..., Damage = 12 }   -- was 22
["Phantom Apex"]   = { ..., Damage = 21 }   -- was 50
["Wraith Frost"]   = { ..., Damage = 190 }  -- was 140
["Phantom Whisper"]= { ..., Damage = 25 }   -- was 55 (Silent unchanged)
["Thunder Royal"]  = { ..., Damage = 13 }   -- was 18
["Viper Left"]     = { ..., Damage = 62 }   -- was 70

-- Legendary
["Viper Aurum"]    = { ..., Damage = 51 }   -- was 60
["Phantom Finale"] = { ..., Damage = 24 }   -- was 60
["Wraith Apex"]    = { ..., Damage = 206 }  -- was 170
["Thunder Crown"]  = { ..., Damage = 14 }   -- was 22
["Hailstorm"]      = { ..., Damage = 18 }   -- was 18 (推薦選項 B)

-- Demon
["Fang Demon"]     = { ..., Damage = 76 }   -- was 120
["Phantom Hellfire"]={ ..., Damage = 27 }   -- was 75 (Burn unchanged)
["Wraith Abyss"]   = { ..., Damage = 220 }  -- was 210 (Pierce unchanged)
["Thunder Bloodmoon"]={..., Damage = 14 }   -- was 28
```

---

## 10. 影響商店價格嗎？

**不影響** — 商店價格（Price）是「玩家覺得這把武器值多少」的設計值，與 Damage 公式解耦。

但 CEO 可考慮：Demon 武器 Damage -37%~-64% 後是否仍值得花 35,000–55,000 子彈幣？玩家視角的「Demon 強度感」會變弱（雖然 DPS gap 仍 1.9x）。

→ **推薦：Sprint 8b 後 1–2 週玩家數據觀察，再決定價格是否調整**。本 Sprint 不動價格。

---

## 拍板後 Sprint 8b 工作節點

1. CEO 拍板本文件（10 個拍板項目 §8）
2. Claude 把本文件的 Damage 表搬進 GameConfig.lua（單一 commit）
3. MatchManager FireWeapon handler 加 Sniper headshot 分支 + 200 HP / 4 階 medkit 邏輯
4. NPCSystem ENEMIES HP/Damage ×2
5. LootSystem 4 階 medkit pickup
6. Studio MCP playtest 驗證
7. 產出 `receipts/sprint-8b-200hp-rebalance.md`
