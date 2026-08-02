-- DuelVoteUI.lua (StarterPlayerScripts)
-- Map-vote panel for the 1v1 duel mode. Renders generically from whatever
-- option list the server sends via DuelVoteOpen — it never hardcodes a map
-- name, so registering a new map in DuelMaps.lua is enough for it to show up
-- here with zero client changes.
--
-- Visual style mirrors ShopController/TrainingArenaUI (dark panel, red
-- accent stroke, Gotham fonts) for consistency with the rest of the lobby UI.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DuelVoteUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0.5, 0, 0.45, 0)
main.Position = UDim2.new(0.5, 0, 0.4, 0)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Parent = screenGui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 12) mc.Parent = main
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(255, 60, 50) ms.Thickness = 2 ms.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 60)
header.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
header.BorderSizePixel = 0
header.Parent = main
local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0, 12) hc.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.65, -20, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "1V1 — 選擇地圖"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0.3, -20, 1, 0)
timerLabel.Position = UDim2.new(0.7, 0, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Parent = header

-- Card grid — populated dynamically from whatever options the server sends.
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -126)
scroll.Position = UDim2.new(0, 10, 0, 70)
scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main
local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 6) sc.Parent = scroll
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 220, 0, 100)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scroll
local sp = Instance.new("UIPadding")
sp.PaddingTop = UDim.new(0, 10)
sp.PaddingLeft = UDim.new(0, 10)
sp.PaddingRight = UDim.new(0, 10)
sp.Parent = scroll

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 24)
statusLabel.Position = UDim2.new(0, 10, 1, -30)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = "點選一張地圖投票"
statusLabel.Parent = main

local hasVoted = false
local cards = {}  -- [mapId] = Frame

local function setVotedVisual(mapId)
	for id, card in pairs(cards) do
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = (id == mapId) and Color3.fromRGB(80, 220, 100) or Color3.fromRGB(90, 90, 100)
		end
	end
end

local function makeCard(mapDef, layoutOrder)
	local card = Instance.new("Frame")
	card.Name = mapDef.Id
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	card.BorderSizePixel = 0
	card.Parent = scroll
	local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = card
	local cs = Instance.new("UIStroke") cs.Color = Color3.fromRGB(255, 60, 50) cs.Thickness = 2 cs.Parent = card

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -10, 0, 30)
	nameLbl.Position = UDim2.new(0, 5, 0, 8)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = mapDef.Name or mapDef.Id
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Parent = card

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -10, 0, 55)
	descLbl.Position = UDim2.new(0, 5, 0, 40)
	descLbl.BackgroundTransparency = 1
	descLbl.Text = mapDef.Description or ""
	descLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLbl.TextScaled = true
	descLbl.TextWrapped = true
	descLbl.Font = Enum.Font.GothamMedium
	descLbl.Parent = card

	btn.MouseButton1Click:Connect(function()
		if hasVoted then return end
		hasVoted = true
		events:WaitForChild("DuelVoteCast"):FireServer(mapDef.Id)
		setVotedVisual(mapDef.Id)
		statusLabel.Text = "已投票：" .. (mapDef.Name or mapDef.Id) .. " — 等待對手..."
		statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
	end)

	return card
end

local function clearCards()
	for _, card in pairs(cards) do
		card:Destroy()
	end
	cards = {}
end

local countdownToken = 0

local function runClientCountdown(seconds)
	countdownToken = countdownToken + 1
	local myToken = countdownToken
	task.spawn(function()
		for t = seconds, 0, -1 do
			if myToken ~= countdownToken then return end
			timerLabel.Text = (t > 0) and (tostring(t) .. "s") or ""
			task.wait(1)
		end
	end)
end

-- ==================== EVENT WIRING ====================
events:WaitForChild("DuelVoteOpen").OnClientEvent:Connect(function(options, seconds)
	clearCards()
	hasVoted = false
	statusLabel.Text = "點選一張地圖投票"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)

	for i, mapDef in ipairs(options or {}) do
		cards[mapDef.Id] = makeCard(mapDef, i)
	end

	runClientCountdown(seconds or 0)
	screenGui.Enabled = true
end)

events:WaitForChild("DuelVoteClosed").OnClientEvent:Connect(function(result)
	countdownToken = countdownToken + 1  -- stop any running countdown
	timerLabel.Text = ""
	if result then
		statusLabel.Text = "已選擇地圖：" .. (result.MapName or result.MapId)
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	end
	task.delay(1.5, function()
		screenGui.Enabled = false
	end)
end)
