# Final Strike - Roblox Game Project

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

## MCP 工作流程
1. 先用 `get_file_tree` 了解當前 Studio 結構
2. 用 `create_script` / `update_script_source` 寫入或修改程式碼
3. 修改後用 `start_playtest` 測試
4. 用 `get_playtest_output` 檢查錯誤
5. 有問題就用 `grep_scripts` 搜尋相關程式碼

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
