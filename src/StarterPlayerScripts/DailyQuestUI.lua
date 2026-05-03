-- DailyQuestUI.lua (StarterPlayerScripts)
-- Press Q to open daily quest panel. Lists 6 quests from GameConfig.DAILY_QUESTS,
-- shows progress bar + claim button per row. Server (DailyQuestService) is
-- authoritative; client only displays state and dispatches ClaimDailyQuest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- Client-side mirror of server quest state
local questState = { Date = "", Progress = {}, Claimed = {} }

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DailyQuestUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 520, 0, 480)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Parent = screenGui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 12) mc.Parent = main
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(255, 200, 50) ms.Thickness = 2 ms.Parent = main

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(30, 25, 15)
header.BorderSizePixel = 0
header.Parent = main
local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0, 12) hc.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "每日任務"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 6) cbc.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

-- Quest list area
local listFrame = Instance.new("Frame")
listFrame.Size = UDim2.new(1, -20, 1, -70)
listFrame.Position = UDim2.new(0, 10, 0, 60)
listFrame.BackgroundTransparency = 1
listFrame.Parent = main

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

-- Quest rows: build one per definition
local rows = {}  -- [questId] = { Bar, BarFill, Text, ClaimBtn }
for i, quest in ipairs(GameConfig.DAILY_QUESTS) do
	local row = Instance.new("Frame")
	row.Name = quest.Id
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
	row.BorderSizePixel = 0
	row.LayoutOrder = i
	local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, 6) rc.Parent = row
	row.Parent = listFrame

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0.6, -10, 0, 22)
	nameLbl.Position = UDim2.new(0, 10, 0, 6)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = quest.Name
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = row

	-- Progress bar background + fill
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.6, -10, 0, 16)
	barBg.Position = UDim2.new(0, 10, 0, 32)
	barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	barBg.BorderSizePixel = 0
	barBg.Parent = row
	local bbc = Instance.new("UICorner") bbc.CornerRadius = UDim.new(0, 4) bbc.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local bfc = Instance.new("UICorner") bfc.CornerRadius = UDim.new(0, 4) bfc.Parent = barFill

	local progressText = Instance.new("TextLabel")
	progressText.Size = UDim2.new(1, 0, 1, 0)
	progressText.BackgroundTransparency = 1
	progressText.Text = "0 / " .. quest.Target
	progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressText.TextScaled = true
	progressText.Font = Enum.Font.GothamBold
	progressText.ZIndex = 2
	progressText.Parent = barBg

	-- Reward + claim button
	local rewardLbl = Instance.new("TextLabel")
	rewardLbl.Size = UDim2.new(0.18, -5, 0, 22)
	rewardLbl.Position = UDim2.new(0.6, 5, 0, 6)
	rewardLbl.BackgroundTransparency = 1
	rewardLbl.Text = "+" .. quest.Reward
	rewardLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	rewardLbl.TextScaled = true
	rewardLbl.Font = Enum.Font.GothamBold
	rewardLbl.Parent = row

	local claimBtn = Instance.new("TextButton")
	claimBtn.Size = UDim2.new(0.22, -10, 0, 40)
	claimBtn.Position = UDim2.new(0.78, 5, 0, 8)
	claimBtn.Text = "領取"
	claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimBtn.TextScaled = true
	claimBtn.Font = Enum.Font.GothamBold
	claimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	claimBtn.AutoButtonColor = false
	local cb = Instance.new("UICorner") cb.CornerRadius = UDim.new(0, 4) cb.Parent = claimBtn
	claimBtn.Parent = row

	claimBtn.MouseButton1Click:Connect(function()
		if claimBtn.Text == "領取" then
			events.ClaimDailyQuest:FireServer(quest.Id)
		end
	end)

	rows[quest.Id] = { Row = row, Bar = barBg, BarFill = barFill, Text = progressText, ClaimBtn = claimBtn, Quest = quest }
end

-- Status label at bottom (claim feedback)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 18)
statusLabel.Position = UDim2.new(0, 10, 1, -22)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = "Press Q to close"
statusLabel.Parent = main

-- ==================== STATE REFRESH ====================
local function refreshRows()
	for _, row in pairs(rows) do
		local quest = row.Quest
		local progress = math.min(questState.Progress[quest.Id] or 0, quest.Target)
		local claimed = questState.Claimed[quest.Id] == true
		local complete = progress >= quest.Target

		row.Text.Text = string.format("%d / %d", progress, quest.Target)
		row.BarFill.Size = UDim2.new(progress / quest.Target, 0, 1, 0)

		if claimed then
			row.ClaimBtn.Text = "已領取"
			row.ClaimBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 50)
			row.ClaimBtn.AutoButtonColor = false
		elseif complete then
			row.ClaimBtn.Text = "領取"
			row.ClaimBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 60)
			row.ClaimBtn.AutoButtonColor = true
		else
			row.ClaimBtn.Text = "進行中"
			row.ClaimBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			row.ClaimBtn.AutoButtonColor = false
		end
	end
end

-- ==================== EVENT HANDLERS ====================
events:WaitForChild("DailyQuestUpdate").OnClientEvent:Connect(function(state)
	questState = state
	refreshRows()
end)

events:WaitForChild("ClaimDailyQuestResult").OnClientEvent:Connect(function(ok, reason, questId)
	local quest = nil
	for _, q in ipairs(GameConfig.DAILY_QUESTS) do
		if q.Id == questId then quest = q break end
	end
	local name = quest and quest.Name or questId
	if ok then
		statusLabel.Text = "✓ 領取成功 +" .. (quest and quest.Reward or 0) .. " 子彈幣"
		statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
	else
		local msg = ({
			incomplete = "尚未完成",
			claimed = "已領取過",
			unknown = "未知任務",
			noservice = "服務暫時無法使用",
		})[reason] or reason
		statusLabel.Text = "✗ " .. name .. ": " .. msg
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
	end
end)

-- Initial state pull (sync RemoteFunction)
task.spawn(function()
	local GetDaily = events:WaitForChild("GetDailyQuests", 5)
	if GetDaily then
		local ok, state = pcall(function() return GetDaily:InvokeServer() end)
		if ok and type(state) == "table" then
			questState = state
			refreshRows()
		end
	end
end)

-- ==================== INPUT (Q = toggle) ====================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		screenGui.Enabled = not screenGui.Enabled
	end
end)
