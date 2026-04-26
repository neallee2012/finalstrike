# Final Strike - Roblox Game Project

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 概要
Final Strike 是一款 12 人 Roblox 生存射擊遊戲。
PvE 蒐集階段 (180秒) → PvP 淘汰賽 → 最後存活者獲勝。

## 開發規則
- 所有角色和 NPC 必須使用 R15 骨架，不用 R6
- 只使用虛構武器名稱（Viper, Stinger, Phantom, Thunder, Wraith, Fang）
- 避免寫實血腥效果和真實武器品牌
- 視覺風格：黑暗、電影感、紅色警示燈、霧氣、陰影
- 程式碼簡潔、可讀、容易擴充
- 使用 RemoteEvent 做 client-server 通訊
- 使用 ModuleScript 做共用邏輯
- 地圖名稱: "Last Zone"

## MCP 工作流程（Roblox 官方 MCP）
1. 先用 `search_game_tree` 了解當前 Studio 結構
2. 用 `multi_edit` 寫入或修改腳本（不存在則自動建立）
3. 用 `execute_luau` 快速驗證邏輯片段
4. 修改後用 `start_stop_play` 測試
5. 用 `console_output` 檢查錯誤
6. 用 `script_grep` 搜尋相關程式碼
7. 用 `generate_mesh` / `generate_material` 生成 3D 資產
8. 用 `user_keyboard_input` / `user_mouse_input` 模擬玩家操作

## 腳本位置對照表
| 腳本 | Service | 類型 | 職責 |
|---|---|---|---|
| MatchManager | ServerScriptService | Script | 比賽流程核心 |
| NPCSystem | ServerScriptService | Script | NPC 生成 + AI |
| LootSystem | ServerScriptService | Script | 戰利品生成拾取 |
| PlayerHealth | ServerScriptService | ModuleScript | 血量 API |
| MapBuilder | ServerScriptService | Script | 地圖生成 |
| GameConfig | ReplicatedStorage | ModuleScript | 全域設定 |
| GameEvents | ReplicatedStorage | Script | RemoteEvent |
| WeaponSystem | ServerStorage | ModuleScript | 武器數據 |
| HUDController | StarterGui | LocalScript | UI |
| WeaponClient | StarterPlayerScripts | LocalScript | 射擊輸入 |

## 比賽階段
1. Lobby — 等待玩家，踩啟動台開始
2. PvE (180s) — 打 NPC、撿戰利品、PvP 關閉
3. PvP Warning (10s) — "FINAL STRIKE BEGINS" 倒數
4. PvP — 玩家互相攻擊，淘汰不重生
5. Match End — 宣布勝者，8 秒後回大廳

## 武器數據
- Viper (手槍): 25 dmg, 半自動
- Stinger (衝鋒槍): 15 dmg, 全自動
- Phantom (步槍): 30 dmg, 全自動
- Thunder (霰彈槍): 12×8 pellets, 半自動
- Wraith (狙擊槍): 90 dmg, 慢射速
- Fang (小刀): 40 dmg, 近戰

## NPC 類型
- Patrol: 60 HP, 低傷害, 基本戰利品
- Armored: 150 HP, 慢速, 好戰利品
- Elite: 250 HP, 快速強力, 最好戰利品

## Workload Contracts
見 `workloads/` 目錄，每個系統有對應的 YAML contract。

## Lessons Learned
_隨開發進度持續更新_

- R15 NPC 需要完整 Motor6D joints 才能 MoveTo
- Roblox Raycast 的 FilterType 要用 Exclude 而非 Include
- RemoteEvent 必須先在 ReplicatedStorage 建立，client 才能 WaitForChild
- ScreenGui.ResetOnSpawn = false 才不會每次重生丟失 UI
- Touched event 需要 CanCollide=false 的 Part 才穩定觸發
- 全自動武器用 RunService.Heartbeat 而非 while loop
- 官方 MCP 工具名稱與社群版不同，以官方文件為準
