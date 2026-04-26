# Final Strike — Roblox 開發環境設定指南

## 架構概覽

```
┌─────────────────────────────────────────────┐
│  你的電腦 (Windows/Mac)                      │
│                                              │
│  ┌──────────────┐   stdio    ┌───────────┐  │
│  │ Claude Code  │◄──────────►│ rbxmcp    │  │
│  │              │            │ (內建CLI)  │  │
│  └──────────────┘            └─────┬─────┘  │
│                                    │         │
│                              ┌─────▼─────┐  │
│                              │  Roblox    │  │
│                              │  Studio    │  │
│                              │ (內建MCP)  │  │
│                              └───────────┘  │
└─────────────────────────────────────────────┘
```

Claude Code ←(stdio)→ rbxmcp CLI ←→ Roblox Studio（內建 MCP server）

## Step 1: 安裝 Claude Code

如果還沒裝：
```bash
npm install -g @anthropic-ai/claude-code
```

驗證：
```bash
claude --version
```

## Step 2: 連接 Roblox 官方 MCP Server（內建 Studio）

Roblox Studio 最新版**內建 MCP server**，不需要額外 plugin。

官方文件：https://create.roblox.com/docs/zh-tw/studio/mcp

加入 MCP server 到 Claude Code：

```bash
claude mcp add roblox-studio -- rbxmcp
```

或手動建立專案根目錄的 `.mcp.json`：
```json
{
  "mcpServers": {
    "roblox-studio": {
      "command": "rbxmcp",
      "args": []
    }
  }
}
```

> **注意**：`rbxmcp` 是 Roblox Studio 安裝時附帶的 CLI，確保 Studio 已更新到最新版。
> 如果 `rbxmcp` 不在 PATH 裡，去 Studio 安裝目錄找（通常在 Roblox Studio 同層資料夾下）。

## Step 3: Roblox Studio 設定

1. 打開 Roblox Studio（確保是**最新版本**）
2. **Game Settings → Avatar → Avatar Type → R15**
3. MCP server 隨 Studio 自動啟動，不需要額外 plugin

## Step 4: 開始使用

```bash
# 進入你的專案目錄
cd ~/projects/final-strike

# 啟動 Claude Code
claude

# 現在可以直接跟 Claude Code 說：
# "看一下 Studio 裡面的遊戲結構"
# "在 ServerScriptService 建立 MatchManager 腳本"
# "把這段 NPC AI 程式碼寫進 NPCSystem"
```

## MCP 提供的工具（官方版）

Claude Code 透過官方 MCP 可以：

### 腳本
- `script_read` — 讀取腳本原始碼（支援行範圍）
- `multi_edit` — 多重編輯腳本（不存在則建立新腳本）
- `script_search` — 模糊搜尋腳本名稱
- `script_grep` — 在所有腳本中搜尋字串模式

### 資產生成（⭐ 官方獨家）
- `generate_mesh` — 生成帶紋理的 3D 網格
- `generate_material` — 生成自定義材質/紋理
- `insert_from_creator_store` — 從創作者商店插入資產、模型

### 資料模型探索
- `search_game_tree` — 探索實例層級結構
- `inspect_instance` — 查看實例屬性、子項

### Luau 執行（⭐ 官方獨家）
- `execute_luau` — 在 Studio 中直接執行 Luau 代碼

### 測試
- `start_stop_play` — 開始/停止 Playtest
- `console_output` — 取得 Output 日誌

### 玩家輸入模擬（⭐ 官方獨家）
- `simulate_input` — 模擬玩家輸入（移動、點擊等）

## 建議的專案結構

```
final-strike/
├── .mcp.json              ← MCP server 配置
├── README.md
├── CLAUDE.md              ← Claude Code 專案指引
└── src/                   ← 參考原始碼（已經幫你建好）
    ├── ReplicatedStorage/
    │   ├── GameConfig.lua
    │   └── GameEvents.lua
    ├── ServerScriptService/
    │   ├── MapBuilder.lua
    │   ├── MatchManager.lua
    │   ├── NPCSystem.lua
    │   ├── LootSystem.lua
    │   └── PlayerHealth.lua
    ├── ServerStorage/
    │   └── WeaponSystem.lua
    ├── StarterGui/
    │   └── HUDController.lua
    └── StarterPlayerScripts/
        └── WeaponClient.lua
```

## CLAUDE.md（Claude Code 專案指引）

把這個檔案放在專案根目錄，Claude Code 每次啟動時會自動讀取：

```markdown
# Final Strike - Roblox Game Project

## 概要
Final Strike 是一款 12 人 Roblox 生存射擊遊戲。
PvE 蒐集階段 → PvP 淘汰賽。

## 開發規則
- 所有角色和 NPC 必須使用 R15 骨架
- 只使用虛構武器名稱
- 避免寫實血腥效果
- 視覺風格：黑暗、電影感、紅色警示燈
- 程式碼要簡潔、可讀、容易擴充
- 使用 RemoteEvent 做 client-server 通訊
- 使用 ModuleScript 做共用邏輯

## MCP 工作流程
1. 先用 get_file_tree 了解當前結構
2. 用 create_script / update_script_source 修改程式碼
3. 修改後用 start_playtest 測試
4. 用 get_playtest_output 看錯誤訊息

## 腳本位置
- ServerScriptService: MatchManager, NPCSystem, LootSystem, PlayerHealth, MapBuilder
- ReplicatedStorage: GameConfig (ModuleScript), GameEvents
- ServerStorage: WeaponSystem (ModuleScript)
- StarterGui: HUDController (LocalScript)
- StarterPlayerScripts: WeaponClient (LocalScript)
```
