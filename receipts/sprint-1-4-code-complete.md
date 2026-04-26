# Sprint 1-4 Receipt — Code Complete

## Status: ✅ CODE COMPLETE (pending Studio integration)

All 10 scripts written, totaling 2053 lines of Lua.
Code has NOT yet been tested in Roblox Studio via MCP.

## Sprint 1: 地基 (MapBuilder)
- [x] Last Zone 地圖生成 — MapBuilder.lua
- [x] 大廳 + FINAL STRIKE 標題 + 啟動台
- [x] 競技場 + 12 掩體 + 高台 + 斜坡
- [x] 觀戰區 + 4 練習靶
- [x] 夜間氛圍 + 紅色警示燈 + 霧氣 + Bloom + ColorCorrection

## Sprint 2: 核心循環 (MatchManager + PlayerHealth)
- [x] 5 階段循環 (Lobby/PvE/PvPWarning/PvP/MatchEnd)
- [x] 180 秒 PvE 倒數
- [x] "FINAL STRIKE BEGINS" 公告 + 10 秒 PvP 倒數
- [x] 100 HP 系統 + 淘汰 + 觀戰區傳送
- [x] 勝利判定 + 8 秒回大廳
- [x] 斷線玩家清理 (PlayerRemoving)

## Sprint 3: 戰鬥 (Weapons + NPC + Loot)
- [x] 6 把虛構武器 (Viper/Stinger/Phantom/Thunder/Wraith/Fang)
- [x] Raycast 射擊 + 彈藥消耗 + 換彈
- [x] 全自動/半自動模式
- [x] 3 種 R15 NPC (Patrol 60HP / Armored 150HP / Elite 250HP)
- [x] NPC AI: 巡邏 → 偵測 → 追擊 → 攻擊
- [x] NPC 死亡掉落戰利品 (LootTable)
- [x] 4 種拾取物 (Ammo/Medkit/Coin/Weapon) + 浮動動畫

## Sprint 4: 打磨 (HUD)
- [x] HP 血量條 (顏色隨血量變化)
- [x] 彈藥顯示
- [x] 階段文字 + 倒數計時器
- [x] 存活人數 (ALIVE: X)
- [x] Kill Feed (5 秒消失)
- [x] 勝利者金色橫幅
- [x] 準心
- [x] 公告系統 (淡入淡出)
- [x] 命中火花特效

## Known Issues (code review, not yet tested in Studio)
- [ ] 多人同時踩啟動台可能重複觸發 startMatch
- [ ] NPC Motor6D joints 在 Studio 中可能需要調整 C0/C1
- [ ] 霰彈槍 8 pellets raycast 可能有效能問題
- [ ] 觀戰區玩家仍可能用武器影響比賽區（需物理隔離）

## Artifacts
- src/ReplicatedStorage/GameConfig.lua
- src/ReplicatedStorage/GameEvents.lua
- src/ServerScriptService/MapBuilder.lua
- src/ServerScriptService/MatchManager.lua
- src/ServerScriptService/NPCSystem.lua
- src/ServerScriptService/LootSystem.lua
- src/ServerScriptService/PlayerHealth.lua
- src/ServerStorage/WeaponSystem.lua
- src/StarterGui/HUDController.lua
- src/StarterPlayerScripts/WeaponClient.lua

## Next: Sprint 5 — Studio Integration
- [ ] 透過 MCP 寫入所有腳本到 Studio
- [ ] 完整 Playtest
- [ ] 用 generate_mesh 替換基本幾何
- [ ] 修復 Playtest 中發現的 bug
