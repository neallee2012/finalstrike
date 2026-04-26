# Final Strike — AI-First 開發計劃
## 套用 Peter Pangg 的 AI-First 框架

---

## 核心原則

Peter Pangg 的 AI-first **不是**「用 AI 寫比較快的 code」。

是把整個開發迴圈重寫成 **agent-native operating model**：
- Planning → 外部化成機器可讀的 contract
- Work → 以 work item 為單位，不是以 prompt 為單位
- Execution → agent-native stage flow，可中斷、可恢復
- Verification → 制度化驗證，不靠聊天考古
- Learning → 每次迭代的回饋回流成系統能力

---

## 五層架構套用到 Final Strike

### Layer 1: PLAN — 把遊戲需求變成 Workload Contract

**不是這樣：** 在 Discord 打一大段「幫我做一個射擊遊戲」

**而是這樣：** 每個系統都是一份 contract，定義清楚輸入、輸出、驗收標準

```yaml
# workloads/weapon-system.yaml
name: WeaponSystem
owner: claude-code
priority: P0-prototype
stages:
  - define: 武器數據結構 (GameConfig)
  - implement: 射擊 raycast + 傷害計算
  - implement: 客戶端輸入 + 自動射擊
  - verify: 每把武器能正確造成傷害
  - verify: 彈藥消耗和換彈正常
success_criteria:
  - 6 把虛構武器可裝備可射擊
  - 傷害數值與 GameConfig 一致
  - 全自動/半自動模式正確
artifacts:
  - src/ReplicatedStorage/GameConfig.lua
  - src/ServerScriptService/MatchManager.lua (weapon fire handler)
  - src/StarterPlayerScripts/WeaponClient.lua
  - src/ServerStorage/WeaponSystem.lua
recovery:
  - raycast 穿牆 → 加 FilterDescendants
  - 傷害不觸發 → 檢查 RemoteEvent 連線
```

#### 所有系統的 Contract 清單

| # | Workload | 優先級 | Owner | 依賴 |
|---|----------|--------|-------|------|
| 1 | MapBuilder ("Last Zone") | P0 | claude-code | 無 |
| 2 | MatchManager (遊戲循環) | P0 | claude-code | MapBuilder |
| 3 | PlayerHealth (血量系統) | P0 | claude-code | MatchManager |
| 4 | WeaponSystem (武器) | P0 | claude-code | PlayerHealth |
| 5 | NPCSystem (R15 敵人) | P0 | claude-code | WeaponSystem, PlayerHealth |
| 6 | LootSystem (戰利品) | P1 | claude-code | NPCSystem |
| 7 | HUD (UI) | P1 | claude-code | 所有 P0 |
| 8 | SpectatorArea (觀戰) | P2 | claude-code | MatchManager |
| 9 | TeamMode (隊伍模式) | P3-future | TBD | MatchManager |
| 10 | Ranking / Leaderboard | P3-future | TBD | MatchManager |

---

### Layer 2: ISSUE — 把工作發出去，不是把 Prompt 打出去

**開發節奏：Sprint-based，每個 Sprint 是一天**

#### Sprint 1：地基（Day 1）
```
Issue: "建立可進入的遊戲世界"
Work Items:
  □ MapBuilder 生成 Last Zone 地圖
  □ 大廳 + 啟動台
  □ 競技場 + 掩體
  □ 觀戰區
  □ 燈光氛圍 (夜間/紅光/霧氣)
  □ R15 Avatar 設定確認
驗收: 進入 Studio → Play → 能在大廳走動 → 踩啟動台傳送到競技場
```

#### Sprint 2：核心循環（Day 2）
```
Issue: "比賽可以從頭跑到尾"
Work Items:
  □ MatchManager 5 階段循環
  □ PlayerHealth 100 HP + 淘汰
  □ PvE/PvP 切換邏輯
  □ 倒數 UI
  □ 勝利判定
驗收: 1人測試 → 大廳啟動 → 180秒倒數 → PvP倒數 → 比賽結束回大廳
```

#### Sprint 3：戰鬥（Day 3）
```
Issue: "能打能撿能死"
Work Items:
  □ 6把武器射擊功能
  □ R15 NPC 3種類型
  □ NPC AI (巡邏/追擊/攻擊)
  □ 戰利品掉落 + 拾取
  □ 醫療包回血 (cap 100)
驗收: 進競技場 → 撿武器 → 打NPC → NPC掉寶 → 撿醫療包回血
```

#### Sprint 4：打磨（Day 4）
```
Issue: "看起來像個遊戲"
Work Items:
  □ 完整 HUD (HP/彈藥/階段/存活人數/Kill Feed)
  □ 命中特效 (spark)
  □ 準心
  □ 淘汰後傳送觀戰區
  □ 觀戰區打靶練習
驗收: 完整一輪 12人測試（或模擬），UI 清晰，體驗流暢
```

---

### Layer 3: EXECUTE — Agent-Native Stage Flow

每個 Work Item 的執行不是「一段很長的 prompt」，而是有階段的 flow：

```
┌─────────┐    ┌──────────┐    ┌──────────┐    ┌────────┐
│  CLAIM   │───►│  WRITE   │───►│  TEST    │───►│ VERIFY │
│ 認領工作  │    │ 寫入代碼  │    │ Playtest │    │ 驗收   │
└─────────┘    └──────────┘    └──────────┘    └────────┘
                    │                │               │
                    ▼                ▼               ▼
               src/*.lua       Studio Output    Receipt ✓/✗
```

#### Claude Code + MCP 的執行流程

```bash
# 1. CLAIM: AI 確認要做什麼
claude> "讀取 workloads/weapon-system.yaml，開始 WeaponSystem"

# 2. WRITE: 透過 MCP 寫入 Studio
claude> get_file_tree                    # 看當前結構
claude> create_script ServerScriptService MatchManager Script "..."  # 寫入
claude> update_script_source ...         # 修改

# 3. TEST: 透過 MCP 測試
claude> start_playtest                   # 開始測試
claude> get_playtest_output              # 看 Output 錯誤
claude> stop_playtest                    # 停止

# 4. VERIFY: 檢查是否符合 contract
claude> grep_scripts "Damage"            # 確認傷害邏輯
claude> get_instance_properties ...      # 確認物件屬性
```

#### 失敗處理（Recovery Path = Happy Path 同等重要）

| 失敗情境 | Recovery |
|----------|----------|
| Script error on playtest | `get_playtest_output` → 讀錯誤 → 修復 → 重測 |
| NPC 不動 | 檢查 Humanoid:MoveTo 呼叫 → 確認 R15 骨架完整 |
| 武器不造成傷害 | 檢查 RemoteEvent 是否建立 → Raycast 參數 |
| UI 不顯示 | 確認 LocalScript 在 StarterGui → ScreenGui 層級 |
| MCP 連不上 Studio | 確認 Plugin 安裝 → HTTP Requests 開啟 |

---

### Layer 4: VERIFY — 制度化驗證

每個 Sprint 結束時產生一份 **Receipt**：

```markdown
# Sprint 2 Receipt — 2026-04-27

## Status: ✅ PASS

## Work Items
- [x] MatchManager 5 階段循環 — PASS
- [x] PlayerHealth 100 HP — PASS  
- [x] PvE/PvP 切換 — PASS
- [x] 倒數 UI — PASS
- [x] 勝利判定 — PASS (1人測試)

## Test Evidence
- Playtest output: 0 errors
- 完整循環時間: ~200 秒 (180 PvE + 10 countdown + ~10 PvP)
- 淘汰後正確傳送觀戰區

## Known Issues
- [ ] 多人同時踩啟動台會觸發多次 startMatch
- [ ] 斷線玩家的 AlivePlayers 清理有延遲

## Artifacts
- src/ServerScriptService/MatchManager.lua (v2)
- src/ServerScriptService/PlayerHealth.lua (v1)
- src/StarterGui/HUDController.lua (v1)
```

#### 驗收不是人工翻 Discord

而是每次 Playtest 後自動產生：
- ✅ Output 有無 error
- ✅ 各系統 contract 的 success criteria 是否滿足
- ✅ 已知問題列表
- ✅ 產出的 artifact 清單

---

### Layer 5: LEARN — 回饋回流成系統能力

每完成一個 Sprint，提取的 lesson 要回寫：

#### 寫回 CLAUDE.md
```markdown
## Lessons Learned
- R15 NPC 需要完整 Motor6D joints 才能 MoveTo
- Roblox raycast 的 FilterType 要用 Exclude 而非 Include
- RemoteEvent 必須先在 ReplicatedStorage 建立，client 才能 WaitForChild
- ScreenGui.ResetOnSpawn = false 才不會每次重生丟失 UI
```

#### 寫回 workload config
```yaml
# 下次做類似系統時的 recovery hint
recovery_hints:
  - "R15 骨架: 必須有 HumanoidRootPart 和所有 Motor6D"
  - "Touched event: 需要 CanCollide=false 的 Part 才穩定觸發"
  - "全自動武器: 用 RunService.Heartbeat 而非 while loop"
```

#### 寫回 GBrain / Memory
- Final Strike 專案頁：進度、架構決策、技術堆疊
- Roblox 開發知識頁：R15 骨架、MCP 工具、常見陷阱

---

## 開發工具鏈

```
你 (歐爸)
  │
  │ 自然語言需求
  ▼
小蝦蝦 (OpenClaw)
  │
  │ 拆解成 workload contract
  │ 產生 Sprint plan
  ▼
Claude Code + Roblox MCP ◄──── robloxstudio-mcp (npm)
  │                                    │
  │ MCP tools                          │ HTTP :3002
  │ (43 tools)                         │
  ▼                                    ▼
Roblox Studio ◄─────────────── Studio Plugin (.rbxm)
  │
  │ Playtest
  ▼
遊戲測試 → Receipt → Learn → 下一個 Sprint
```

---

## 六條設計原則（from Peter Pangg）

1. **Prompt 不是工作物件** — 每個功能先定義 contract，再寫 code
2. **Schedule 不等於 Execution** — Sprint 計劃和實際開發分開管理
3. **Work truth 和 Execution truth 分開** — 需求文件 vs Studio 裡的實際狀態
4. **Receipt 是一級物件** — 每個 Sprint 結束必須有驗收紀錄
5. **Recovery path = Happy path** — 錯誤處理跟正常流程一樣被設計
6. **Onboarding 新功能是 config-first** — 加新武器/新NPC/新地圖，先改 GameConfig

---

## 立即行動

1. **今天**：在你的電腦裝好 Claude Code + Roblox MCP + Studio Plugin
2. **Day 1**：跑 Sprint 1（地圖生成），用 MCP 把 MapBuilder 寫進 Studio
3. **Day 2**：跑 Sprint 2（核心循環），MatchManager + PlayerHealth
4. **Day 3**：跑 Sprint 3（戰鬥），WeaponSystem + NPCSystem + LootSystem
5. **Day 4**：跑 Sprint 4（打磨），HUD + 特效 + 觀戰區
6. **Day 5**：整體 Playtest + Receipt + Learn cycle

**4-5 天出一個可玩原型。**
