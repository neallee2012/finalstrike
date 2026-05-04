# Sprint 8b Manual Playtest Checklist — 5 Deferred Integration Tests

Date: 2026-05-04
Purpose: Close the 5 integration tests that `verification/sprint-8b-runtime-checks.lua` could not auto-verify (執行 luau 在 client context 跑不了 server-side state mutation；參見 `receipts/sprint-8b-studio-verify.md` §"Deferred"). 一次 human playtest，~10 分鐘。

## How to use

1. 開 Final Strike `.rbxl`、按 Play
2. 走完每個 §X 步驟，在 `[ ]` 打勾
3. 任何 expected 不符記錄到 §"Issues found" 段
4. 跑完更新 `receipts/sprint-8b-studio-verify.md` §"Deferred" 區塊狀態，並 commit 本 checklist 結果

## Setup — Two-phase playtest

> ⚠️ **必讀**：`MatchManager.initPlayerData()` 在 match start 時 snapshot `playerData[player].Weapon`，之後 `FireWeapon` 拒絕任何 `weaponName ~= data.Weapon`。中途買武器或按 EquipPrimaryWeapon **不會改 server 的 data.Weapon**，要等下一場 match init 才生效。
>
> 因此 Tests 分 2 個 phase 跑：
> - **Phase 1**（用 starter Viper Mk1）：Test 2 + Test 4
> - **Phase 2**（restart match 用 Wraith Scout）：Test 1 + Test 3 + Test 5

### 共同 setup（一次）

- [ ] **Open Studio** at the Final Strike place
- [ ] **Press Play** — 進大廳
- [ ] **F9 開 Output 視窗** — 等等要看 server 端的 `[damagePlayer]` log 與 NPCDamaged 數字

---

### Phase 1: 用 starter Viper Mk1 跑 Test 2 + Test 4

- [ ] 確認手上拿 **Viper Mk1**（player 預設 STARTER_WEAPONS[1]）
- [ ] **走到 StartMatchPad** 觸發比賽
- [ ] **等到 PvE 階段**，HUD "200 / 200"
- [ ] **跑 Test 2**（Pistol head hit ≠ Sniper bonus）— 見 §Test 2
- [ ] **跑 Test 4**（200 HP drain rate）— 見 §Test 4
- [ ] Test 2 + 4 完成後，**讓自己被 NPC 殺死**（或等比賽結束）回大廳

---

### Phase 2: 大廳買 Wraith Scout，restart match 跑 Test 1 + 3 + 5

- [ ] 回到大廳（match end → lobby teleport）
- [ ] **Command Bar 跑 coin grant**（bypass MatchTotal cap，必須用 addDailyReward 而非 addCoins）：
  ```lua
  -- addDailyReward 跳過 GameConfig.ECONOMY.MatchCaps.MatchTotal = 1500 限制
  -- 用 addCoins(_, _, nil) 會只發 1500 coins，買不起 1650 的 Wraith Scout
  if _G.CurrencyService then
      _G.CurrencyService.addDailyReward(game.Players:GetPlayers()[1], 5000, "playtest setup")
  end
  ```
  HUD 子彈幣顯示應跳到 **5000+**
- [ ] **B 鍵開 Shop UI**
- [ ] **買 Wraith Scout**（1650 coins）
- [ ] **設 Wraith Scout 為 primary**（shop UI 按 Equip）→ 觸發 PrimaryWeaponUpdate
- [ ] **走到 StartMatchPad 重新觸發比賽** — `initPlayerData` 會 snapshot Wraith Scout 為 `data.Weapon`
- [ ] **等到 PvE 階段**，**確認手上拿 Wraith Scout**（不是 Viper Mk1）
- [ ] **跑 Test 1**（Wraith body / head）— 見 §Test 1
- [ ] **跑 Test 3**（NPC drop visual，殺 Elite）— 見 §Test 3
- [ ] **跑 Test 5**（NPC accessory edge）— 見 §Test 5

---

## Test 1: Wraith Scout body 120 / headshot 240（Sniper headshot 正面驗證） — Phase 2

**Setup**: 已在 Phase 2 setup 買好 Wraith Scout、set primary、re-start match → init snapshot 用 Wraith Scout。
- [ ] 確認手上拿的是 **Wraith Scout**（不是 Viper Mk1）
- [ ] 找一隻 Patrol NPC（120 HP）站著沒動的目標

**Action A — body shot**:
- [ ] 對 Patrol 的 Torso (UpperTorso) 開 1 槍
- [ ] 觀察 Patrol HP attribute（可在 Studio Explorer 看 NPC model.HP，或看 NPCDamaged event 印出的 dmg）

**Expected**:
- [ ] Damage = **120**（NPC HP 120 → 0，秒殺；console 印 NPCDamaged 數字 = 120）

**Action B — headshot**:
- [ ] 等下一隻活的 Patrol（剛剛 body shot 一發秒殺，要找新的）
- [ ] 對 Patrol 的 **Head** 部位開 1 槍

**Expected**:
- [ ] Damage = **240**（120 × HEADSHOT_MULTIPLIER 2.0；對 Patrol 120 HP 是 overkill，秒殺；NPCDamaged 印 240）

**Pass criteria**：body 120 dmg / head 240 dmg 兩個數值都在 console 看到

---

## Test 2: Pistol Head hit ≠ Sniper bonus（headshot 負面驗證） — Phase 1

**Setup**：Phase 1，玩家手上是 starter **Viper Mk1**（30 dmg, Type=Pistol）— 這是 init 預設 primary，data.Weapon=Viper Mk1，FireWeapon 接受。

**Action**:
- [ ] 對 Patrol 的 **Head** 部位開 1 槍

**Expected**:
- [ ] Damage = **30**（不是 60）— Pistol Type 不該觸發 HEADSHOT_MULTIPLIER
- [ ] Console NPCDamaged event 印 30，**NOT** 60

**Why this matters**: 確認 `MatchManager.lua` FireWeapon handler 的 `if config.Type == "Sniper" and isHeadshot` 條件嚴格只 Sniper 適用，沒有 leak 到其他 Type。

**Optional 進階**: 拿 Phantom Ranger（Rifle, 19 dmg）對 head — 應該是 19 dmg 不是 38。

---

## Test 3: 4-tier medkit visual color from NPC drop — Phase 2

**Setup**: Phase 2 中（Wraith Scout 為 primary）。站在 Elite NPC 附近（500 HP、紅色發光、可能戴兜帽）

**Action**:
- [ ] 用 Wraith Scout 連續打 Elite 直到死（500 HP / 120 body = 5 發 body，或 1 爆頭 + 2 body）
- [ ] 看 NPC 死亡後 spawn 的 loot pickup 球體顏色

**Expected**（per dropLoot rolls）:
- 50% 機率出 **MedkitLarge**（深綠色 RGB 20/200/80）
- 5% 機率出 **MedkitFull**（米白色 RGB 255/255/200）— 要多打幾次才看得到
- 40% 機率 Ammo（黃 255/200/50）
- 50% 機率 Coin（金 255/215/0）

各 lootType 是獨立 roll，所以一隻 Elite 可能出 0-3 個 pickups。

**Pass criteria**：
- [ ] 至少看到一次 MedkitLarge 深綠球（可能 1-2 隻 Elite 死後就出）
- [ ] 試運氣看到 MedkitFull 米白球（10-20 隻 Elite 死後機率高）
- [ ] 撿起 MedkitLarge → HUD HP +150（如果你受傷的話）

進階：殺 Patrol NPC → 看 MedkitSmall (淺綠 120/255/150)；殺 Armored → 看 Medkit (標準綠 50/255/100)。

---

## Test 4: 200 HP vs Patrol attack drain rate（NPC ×2 damage 驗證） — Phase 1

**Setup**: Phase 1（Viper Mk1 starter）— Test 4 是純被動觀察 drain rate，武器無關。Phase 2 也可以但 Phase 1 順便做最有效率。
- [ ] 走到一隻 Patrol NPC 攻擊範圍內（AttackRange = 6）
- [ ] **不要躲也不要還手**，站樁讓 Patrol 攻擊
- [ ] 計時器（手機 stopwatch 或 console 看時間）

**Expected**:
- Patrol Damage = 18 / AttackRate = 1 秒
- 200 HP / 18 dmg = 11.11 → 12 hits 死
- 12 hits × 1.0s = **約 12 秒**（含 spawn protection 後的時間）
- Sprint 8b 之前是 100 HP / 10 dmg = 10 hits / 10 秒

**Pass criteria**：
- [ ] 從第一發攻擊到死 ~12 秒（容差 ±2 秒）
- [ ] HUD HP 條從 200 線性降到 0
- [ ] 死後切觀戰相機（spectator camera）

---

## Test 5: NPC accessory（cap/helmet/hood）head-hit edge case — Phase 2

**Setup**: Phase 2，玩家拿 Wraith Scout

**Why test**：D1 設計只 hitPart.Name == "Head" 觸發爆頭。但 NPC 戴的 hat/cap/helmet/hood 是獨立的 Part 掛在 Head 上（NPCSystem.dressNPC），它們的 Name 不是 "Head" 所以不該觸發爆頭加成 — 視覺上「子彈打到頭盔被擋」。

**Action A — Patrol Cap (Security cap)**:
- [ ] 找 Patrol，瞄準它頭頂的小帽子（不是臉部）
- [ ] 開 1 槍

**Expected**:
- [ ] Damage = **120**（不是 240）— 命中 "Cap" Part 而非 "Head"，不算爆頭

**Action B — Armored Helmet**:
- [ ] 找 Armored，瞄準它的戰術頭盔（覆蓋整個頭部）
- [ ] 開 1 槍

**Expected**:
- [ ] Damage = **120**（命中 "Helmet" 或 "HelmetVisor"，不是 "Head"）

**Action C — Elite Hood**:
- [ ] 找 Elite，瞄準兜帽（包覆頭部）
- [ ] 開 1 槍

**Expected**:
- [ ] Damage = **120**（命中 "Hood" 或 "HoodFront"，不是 "Head"）

**Pass criteria**：3 種 NPC 戴的 accessory 命中時 console NPCDamaged 都印 120，不是 240。如果**有任何一個** accessory 觸發 240 → 設計 bug，hitPart.Name 邏輯需要修。

---

## Issues found during playtest

> 玩家寫進這段，每條附 step、expected、actual、可能原因。

-

---

## Post-playtest steps

- [ ] 把 Test 1-5 的勾與 Issues found 留在這份 checklist 裡
- [ ] Commit 這份 checklist 已勾選版本到 repo
- [ ] 更新 `receipts/sprint-8b-studio-verify.md` §"⚠️ Interactive integration tests deferred" 表格 — 把 5 個 deferred 項目改成 ✅ verified manual playtest YYYY-MM-DD
- [ ] 如有 issues found → 開 GitHub issue 或新 PR fix

如果 5 項 Pass，Sprint 8b 才能宣告 production-ready。
