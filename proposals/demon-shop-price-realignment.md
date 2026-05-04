# Demon / Legendary 武器商店價格 realignment（Sprint 8b 後遺症）

Date: 2026-05-04
Author: claude-code
Status: 📋 待 CEO 拍板（3 個選項，推薦 A）
Driving:  Sprint 8b (b) 決議把 Demon DPS 從 3.0x baseline 收斂到 1.9x baseline (-37%)，但商店價格沒動。
Source: `proposals/30-weapon-dps-retune.md` + `receipts/sprint-8b-200hp-rebalance.md`

---

## TL;DR

(b) 決議讓 Demon 武器 DPS 直接 nerf 37%，但 35K–55K 子彈幣的商店價格還是 Sprint 8 設定 (依舊 3.0x DPS 假設)。**Demon 變相超貴**：花 55K 拿 1.9x DPS 等同舊世界花 55K 拿一個 1.9x 武器 — 但舊世界 1.9x 是 Epic 區段，Epic 平均 8.7K coins。

CEO 拍板路線 (b) 雖然解了 P2W 問題，但留下「Demon 物有所值嗎？」的 open question。本文件給 3 個選項。

---

## 1. Background

Sprint 8b (b) 公式收斂：

| Rarity | 舊 DPS 倍率 | 新 DPS 倍率 | DPS 變化 |
|---|---|---|---|
| Common | 1.00x | 1.00x | 0% |
| Uncommon | 1.25x | 1.15x | **-8%** |
| Rare | 1.55x | 1.30x | **-16%** |
| Epic | 1.95x | 1.50x | **-23%** |
| Legendary | 2.40x | 1.70x | **-29%** |
| Demon | 3.00x | 1.90x | **-37%** |

商店價格（GameConfig.WEAPONS[*].Price）**未調整**，仍是 Sprint 8 原值。

---

## 2. Current price-per-DPS 失衡分析

每 tier 平均價格 ÷ 該 tier DPS 倍率（= 玩家「每 1 個 DPS 單位要花多少 coin」）：

| Rarity | 平均售價 | 舊 DPS 倍率 | **舊 price/DPS** | 新 DPS 倍率 | **新 price/DPS** | 失衡 % |
|---|---|---|---|---|---|---|
| Common | 460 | 1.00 | 460 | 1.00 | 460 | 0% |
| Uncommon | 1500 | 1.25 | 1200 | 1.15 | **1304** | +9% |
| Rare | 3680 | 1.55 | 2374 | 1.30 | **2831** | +19% |
| Epic | 8767 | 1.95 | 4496 | 1.50 | **5845** | +30% |
| Legendary | 20200 | 2.40 | 8417 | 1.70 | **11882** | +41% |
| Demon | 45000 | 3.00 | 15000 | 1.90 | **23684** | **+58%** |

**Demon 武器現在每單位 DPS 要花 23.7K coins**，相對舊世界 15K → **多付 58% 才得到同樣 DPS 等級**。

老玩家用「Demon = 最強」直覺購買，玩 1 場後感受到「咦怎麼沒比 Legendary 強多少」會直接質疑商店價值。

---

## 3. 三個選項

### 選項 A（推薦）：Tier-uniform haircut，保留「Demon 是 elite」感受

每個 tier 套一個固定折扣，比例溫和：

| Rarity | 現價 | 折扣 | 新價（範例） |
|---|---|---|---|
| Common | 300–650 | 0% | 不變 |
| Uncommon | 1200–1800 | 0% | 不變 |
| Rare | 3000–4500 | -5% | 2850–4275 |
| Epic | 7500–9800 | -10% | 6750–8820 |
| Legendary | 16000–25000 | -20% | 12800–20000 |
| Demon | 35000–55000 | **-25%** | **26250–41250** |

**邏輯**：DPS gap 收斂 37% 但商店「感覺」是 progression 而非純 DPS — 給 -25% 的折扣（較 -37% 保守），讓玩家不會覺得「Demon 變廉價」。

**Demon 武器新價（B 選項對照）**：
- Fang Demon: 35000 → **26250**
- Phantom Hellfire: 42000 → **31500**
- Wraith Abyss: 48000 → **36000**
- Thunder Bloodmoon: 55000 → **41250**

可進一步 round：26250 → 26000，31500 → 32000 等便於玩家心算。

**Pros**：
- 不會讓老玩家（已存了 50K 想買 Demon）感受到通膨
- 仍維持 Common→Demon ~57x 的價格 gap（從現在 117x 收斂）
- 保住「Demon = 最強」的視覺體感

**Cons**：
- Demon 仍比舊世界相對「貴」（每 DPS 17K vs 舊 15K，+13%）
- 不完全解決 price-per-DPS 失衡

### 選項 B：Pure proportional —— 嚴格按 DPS 倍率變化等比

每 tier 的價格 × （新倍率 / 舊倍率）：

| Rarity | 現價 (avg) | × ratio | 新價 (avg) |
|---|---|---|---|
| Common | 460 | × 1.00 | 460 |
| Uncommon | 1500 | × 0.92 | 1380 |
| Rare | 3680 | × 0.84 | 3091 |
| Epic | 8767 | × 0.77 | 6750 |
| Legendary | 20200 | × 0.71 | 14342 |
| Demon | 45000 | × 0.63 | **28350** |

**Pros**：完美 mathematical alignment，每 tier price-per-DPS 與舊世界相同
**Cons**：Demon 從 45K 砍到 28K **-37%**，老玩家可能反彈；商店「elite tier」感變淡

### 選項 C：Status quo（不動價格）

接受「Demon 是 luxury rarity tier，價格反映稀有度而非純 DPS」。

**Pros**：
- 0 工程
- 商店 progression 感維持
- Demon 玩家「我付這麼多就是要爽」

**Cons**：
- Sprint 8b 的 P2W 收斂功夫沒完全傳導到玩家感受
- Demon 玩家 DPS 體驗不如預期 → 可能差評
- price-per-DPS 失衡 +58% 的 Demon 是商店設計風險

---

## 4. 推薦：選項 A

理由：
1. **Sprint 8b 動機是降 P2W，不是讓 Demon 廉價** — 選項 A 平衡兩者
2. **商店 progression 是長期留存核心** — 選項 B 砍 Demon 37% 太傷商店設計
3. **選項 C 沒有閉環 8b 的後遺症** — 玩家會問「為什麼 Demon DPS 變弱但價格沒變」

選項 A 的 Demon -25% 折扣是**「承認 nerf 但維持 elite tier 形象」**的中間路線。

---

## 5. 完整新價格表（如選 A）

```lua
-- ===== Common (5) — 0% =====
["Viper Mk1"]      Price=  300  -- unchanged
["Viper SD"]       Price=  350  -- unchanged
["Fang Scout"]     Price=  450  -- unchanged
["Thunder Stub"]   Price=  550  -- unchanged
["Thunder Cut"]    Price=  650  -- unchanged

-- ===== Uncommon (5) — 0% =====
["Stinger Mk2"]    Price= 1200  -- unchanged
["Stinger Tac"]    Price= 1350  -- unchanged
["Phantom Ranger"] Price= 1500  -- unchanged
["Wraith Scout"]   Price= 1650  -- unchanged
["Stinger Burst"]  Price= 1800  -- unchanged

-- ===== Rare (5) — -5% =====
["Reaver-X"]       Price= 2850  -- was 3000
["Phantom Night"]  Price= 3150  -- was 3300
["Thunder Guard"]  Price= 3400  -- was 3600
["Wraith Hunter"]  Price= 3800  -- was 4000
["Thunder Triple"] Price= 4275  -- was 4500

-- ===== Epic (6) — -10% =====
["Stinger Storm"]  Price= 6750  -- was 7500
["Phantom Apex"]   Price= 7200  -- was 8000
["Wraith Frost"]   Price= 7650  -- was 8500
["Phantom Whisper"]Price= 8100  -- was 9000
["Thunder Royal"]  Price= 8800  -- was 9800
["Viper Left"]     Price= 8800  -- was 9800

-- ===== Legendary (5) — -20% =====
["Viper Aurum"]    Price=12800  -- was 16000
["Phantom Finale"] Price=14400  -- was 18000
["Wraith Apex"]    Price=16000  -- was 20000
["Thunder Crown"]  Price=17600  -- was 22000
["Hailstorm"]      Price=20000  -- was 25000

-- ===== Demon (4) — -25% =====
["Fang Demon"]     Price=26250  -- was 35000
["Phantom Hellfire"]Price=31500 -- was 42000
["Wraith Abyss"]   Price=36000  -- was 48000
["Thunder Bloodmoon"]Price=41250 -- was 55000
```

---

## 6. 影響的玩家 / 系統

- **新玩家**：升級到 Rare/Epic/Legendary/Demon 更便宜 → 商店 funnel 更平滑（正向）
- **既有玩家** (DataStore 有 coins)：他們存的 coins **價值上升**（同樣 35K 現在能買到舊 47K 等級的 Demon）→ 正向
- **既有 Demon 持有者**：他們花 50K 買到的武器，現在新玩家花 36K 就買到 → **可能感受不公平**。需要溝通說明：(b) decision 是 server-wide rebalance，獎勵新玩家進入。
- **Daily quest reward / match reward 不需動** — 這只是商店價格 realignment

---

## 7. 工程影響

很小：
- 改 `src/ReplicatedStorage/GameConfig.lua` 30 個 weapon Price 數值（25 個有變動）
- ShopController UI 自動讀新值，不需改
- 不影響 ShopService DataStore（因為買到的武器名稱不變，只是新買價格不同）

工時 ~0.2 天（含 verification）。

---

## 8. CEO 拍板項目

- [ ] **採選項 A / B / C**？（推薦 A）
- [ ] **Demon 折扣比例**：A 預設 -25%，可微調 -20% ~ -30%
- [ ] **既有 Demon 玩家補償**：要不要對 Sprint 8b 之前買 Demon 的玩家做一次性補貼？（建議不做 — 太工程；但要在 patch note 說明）
- [ ] **是否本 sprint 一起做還是 Sprint 9 第一個工作項**？（推薦 Sprint 9 開頭）

---

## 9. Sprint 9 implementation 計劃（如選 A）

1. CEO 拍板選項 + 確認新 prices
2. 改 GameConfig.lua 25 個 Price 值
3. Studio MCP playtest：開 ShopUI 確認新價格顯示
4. 在 verification/sprint-8b-runtime-checks.lua 加 Price assertions（每把武器新價）
5. 產出 receipts/sprint-9a-demon-price-realign.md
