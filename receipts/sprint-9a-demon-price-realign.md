# Sprint 9a Receipt — Demon / Legendary 武器商店價格 realignment (Option A)

Date: 2026-05-04
CEO Decision: 2026-05-04 — 選 Option A、Demon -25%
Source: `proposals/demon-shop-price-realignment.md` §3 + §5

## Status: ✅ IMPLEMENTED + VERIFIED

20 個 weapon Price 已套到 main + Studio。Verification script 加 30 個 Price assertions 全部 pass。

## Tier discount table（已套用）

| Rarity | 折扣 | 影響 weapons |
|---|---|---|
| Common | 0% | 5 把（不變）|
| Uncommon | 0% | 5 把（不變）|
| Rare | **-5%** | 5 把（Reaver-X, Phantom Night, Thunder Guard, Wraith Hunter, Thunder Triple）|
| Epic | **-10%** | 6 把（Stinger Storm, Phantom Apex, Wraith Frost, Phantom Whisper, Thunder Royal, Viper Left）|
| Legendary | **-20%** | 5 把（Viper Aurum, Phantom Finale, Wraith Apex, Thunder Crown, Hailstorm）|
| Demon | **-25%** | 4 把（Fang Demon, Phantom Hellfire, Wraith Abyss, Thunder Bloodmoon）|

## Per-weapon Price changes（20 個）

### Rare (5 — -5%)

| 武器 | 舊價 | 新價 | 算式 |
|---|---|---|---|
| Reaver-X | 3000 | **2850** | 3000 × 0.95 = 2850 |
| Phantom Night | 3300 | **3150** | 3300 × 0.95 = 3135 → 3150（rounded） |
| Thunder Guard | 3600 | **3400** | 3600 × 0.95 = 3420 → 3400（rounded） |
| Wraith Hunter | 4000 | **3800** | 4000 × 0.95 = 3800 |
| Thunder Triple | 4500 | **4275** | 4500 × 0.95 = 4275 |

### Epic (6 — -10%)

| 武器 | 舊價 | 新價 |
|---|---|---|
| Stinger Storm | 7500 | **6750** |
| Phantom Apex | 8000 | **7200** |
| Wraith Frost | 8500 | **7650** |
| Phantom Whisper | 9000 | **8100** |
| Thunder Royal | 9800 | **8800**（rounded down from 8820）|
| Viper Left | 9800 | **8800**（rounded down from 8820）|

### Legendary (5 — -20%)

| 武器 | 舊價 | 新價 |
|---|---|---|
| Viper Aurum | 16000 | **12800** |
| Phantom Finale | 18000 | **14400** |
| Wraith Apex | 20000 | **16000** |
| Thunder Crown | 22000 | **17600** |
| Hailstorm | 25000 | **20000** |

### Demon (4 — -25%)

| 武器 | 舊價 | 新價 |
|---|---|---|
| Fang Demon | 35000 | **26250** |
| Phantom Hellfire | 42000 | **31500** |
| Wraith Abyss | 48000 | **36000** |
| Thunder Bloodmoon | 55000 | **41250** |

## Test Evidence

### Static config verification

跑 `verification/sprint-8b-runtime-checks.lua` 的新增 §3.5 Price assertions（30 weapons）:

```
{ passed = 30, failed = 0, failures = [] }
```

Verification script self-test on running Studio (post-realignment): 30/30 prices match expected.

### 工程改動

```
src/ReplicatedStorage/GameConfig.lua             — 20 weapon Price 改動 + 註解 block 新增
verification/sprint-8b-runtime-checks.lua        — 新增 §3.5 priceExpect table + 30 個 Price check
receipts/sprint-9a-demon-price-realign.md        — 本 receipt
```

不影響：
- ShopController UI（自動讀新 Price）
- ShopService DataStore（武器名稱不變，只是新買價格不同）
- 已擁有武器的玩家（已買的不會被收回，coin 也不退）

## DPS-per-coin 結果驗證（Option A 預期）

選項 A 的目標是收斂 Demon price-per-DPS（之前 +58% vs 舊世界）：

| Rarity | 平均售價 | 新 DPS 倍率 | **新 price/DPS** | 改前 | 改後變動 |
|---|---|---|---|---|---|
| Common | 460 | 1.00 | 460 | 460 | 0% |
| Uncommon | 1500 | 1.15 | 1304 | 1304 | 0% |
| Rare | 3495 | 1.30 | 2688 | 2831 | -5% |
| Epic | 7883 | 1.50 | 5256 | 5845 | -10% |
| Legendary | 16160 | 1.70 | 9506 | 11882 | -20% |
| Demon | 33750 | 1.90 | **17763** | 23684 | **-25%** |

Demon price/DPS 從 23684（pre-realignment）→ 17763（Option A），**-25%**，符合期望。
仍比舊世界 15000 高 +18%（接受 trade-off：商店 progression > 完美 DPS 對齊）。

## CEO 拍板溯源

CEO 在 2026-05-04 訊息：「demon price（"選 A，Demon -25%"）」→ 對應 proposal §3 Option A + §5 完整價格表。所有改動嚴格依照 §5 範例價格表。

## Lessons Learned

- **`gh pr edit --body` 可以一次更新整份 PR description** — 用 HEREDOC 餵入。對 review pass 之後 stale numbers 修正是 must-have（PR #28 review 抓到 PR body 與文件不同步，正是這個用法）
- **Studio multi_edit 一次 21 edits 沒問題** — 大批量精準替換比逐個 Edit 快多了，前提是每個 old_string 在檔內 unique
- **驗證 script 加 Price assertions 是 worth it** — 加 30 個 check 一次寫，未來任何 GameConfig.Price drift（誤改、merge conflict）都會被抓
- **Receipt 用「per-tier table」+「per-weapon table」雙層結構** — CEO 看 tier 表確認決策落地，工程 review 對 weapon 表逐個 verify 算式

## Next: Sprint 9 候選（仍待 CEO 拍板）

從 `receipts/sprint-8b-200hp-rebalance.md` §Next 取仍未做的：
1. **Manual playtest checklist 跑一輪** — 5 deferred items 收尾 Sprint 8b production-ready（不阻塞，但建議盡快做完）
2. **護甲片系統**（workloads/11，需 CEO Q4 拍板）
3. **Channel 式補血**（需 CEO Q3 拍板）
4. **古代長火槍**（需 CEO 重新拍板，原 Q5 deferred Sprint 10+）
5. **全武器 headshot 1.5x evaluation**（需 production data，玩家上線後才有）
