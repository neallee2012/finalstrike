-- TrainingArenaUI.lua (StarterPlayerScripts)
-- Weapon picker shown when the player teleports into the TrainingArena.
-- Lists ALL 30 weapons (no ownership filter — training mode is for testing
-- guns the player hasn't bought yet). Click a card → fires
-- SelectTrainingWeapon to the server, which equips the weapon and resets
-- ammo. UI auto-closes on selection so the player can immediately shoot.
--
-- Server fires:
--   - EnterTrainingArena → open the picker
--   - ExitTrainingArena  → close the picker (forced close on leaving)
--
-- Layout mirrors ShopController for visual consistency: tabbed by rarity,
-- grid of cards. No price column (training is free). No EQUIP/EQUIPPED
-- states — every click is a fresh pick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- Sorted list (rarity order, then price) — same logic as ShopController so
-- training picker visually matches the shop.
local function buildWeaponList()
	local list = {}
	for name, cfg in pairs(GameConfig.WEAPONS) do
		table.insert(list, { Name = name, Config = cfg })
	end
	table.sort(list, function(a, b)
		local ra = GameConfig.RARITY[a.Config.Rarity]
		local rb = GameConfig.RARITY[b.Config.Rarity]
		if ra.Order ~= rb.Order then return ra.Order < rb.Order end
		return (a.Config.Price or 0) < (b.Config.Price or 0)
	end)
	return list
end
local weaponList = buildWeaponList()

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TrainingArenaUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0.85, 0, 0.85, 0)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BorderSizePixel = 0
main.Parent = screenGui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 12) mc.Parent = main
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(255, 60, 50) ms.Thickness = 2 ms.Parent = main

-- Header
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
title.Text = "TRAINING ARENA — PICK A WEAPON"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(0.3, -70, 0.7, 0)
hint.Position = UDim2.new(0.65, 10, 0.15, 0)
hint.BackgroundTransparency = 1
hint.Text = "All 30 weapons free in training"
hint.TextColor3 = Color3.fromRGB(180, 180, 180)
hint.TextScaled = true
hint.Font = Enum.Font.GothamMedium
hint.TextXAlignment = Enum.TextXAlignment.Right
hint.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 50, 0, 50)
closeBtn.Position = UDim2.new(1, -55, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = header
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 8) cbc.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

-- Tab bar (same tabs as ShopController)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, 36)
tabBar.Position = UDim2.new(0, 10, 0, 70)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.Parent = tabBar

local TABS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Demon" }
local currentTab = "All"
local tabButtons = {}

-- Card grid
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -126)
scroll.Position = UDim2.new(0, 10, 0, 116)
scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main
local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, 6) sc.Parent = scroll
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 200, 0, 100)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scroll
local sp = Instance.new("UIPadding")
sp.PaddingTop = UDim.new(0, 10)
sp.PaddingLeft = UDim.new(0, 10)
sp.PaddingRight = UDim.new(0, 10)
sp.Parent = scroll

-- Status bar
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 24)
statusLabel.Position = UDim2.new(0, 10, 1, -30)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = "Pick any weapon — close (X) to start shooting"
statusLabel.Parent = main

local cards = {}  -- [weaponName] = { Frame= }

local function makeCard(weapon)
	local rarityCfg = GameConfig.RARITY[weapon.Config.Rarity]
	local card = Instance.new("Frame")
	card.Name = weapon.Name
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	card.BorderSizePixel = 0
	local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = card
	local cs = Instance.new("UIStroke") cs.Color = rarityCfg.Color cs.Thickness = 2 cs.Parent = card

	-- Top rarity strip
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 4)
	strip.BackgroundColor3 = rarityCfg.Color
	strip.BorderSizePixel = 0
	strip.Parent = card

	-- Each card is itself a button (whole-card click to select). No separate
	-- BUY/EQUIP buttons — training picker is "click and go".
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -10, 0, 28)
	nameLbl.Position = UDim2.new(0, 5, 0, 12)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = weapon.Name
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Parent = card

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -10, 0, 18)
	subLbl.Position = UDim2.new(0, 5, 0, 44)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = string.format("%s · %s", weapon.Config.Rarity, weapon.Config.Type)
	subLbl.TextColor3 = rarityCfg.Color
	subLbl.TextScaled = true
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.Parent = card

	-- Stats row: damage + fire rate (or attack rate for knives)
	local rate = weapon.Config.FireRate or weapon.Config.AttackRate
	local stats = Instance.new("TextLabel")
	stats.Size = UDim2.new(1, -10, 0, 18)
	stats.Position = UDim2.new(0, 5, 0, 66)
	stats.BackgroundTransparency = 1
	stats.Text = string.format("DMG %d  ·  %.2fs", weapon.Config.Damage, rate or 0)
	stats.TextColor3 = Color3.fromRGB(220, 220, 220)
	stats.TextScaled = true
	stats.Font = Enum.Font.GothamMedium
	stats.Parent = card

	btn.MouseButton1Click:Connect(function()
		events.SelectTrainingWeapon:FireServer(weapon.Name)
		statusLabel.Text = "✓ Equipped " .. weapon.Name .. " — close (X) to shoot"
		statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
	end)

	cards[weapon.Name] = { Frame = card }
	return card
end

local function applyTabFilter()
	for _, weapon in ipairs(weaponList) do
		local entry = cards[weapon.Name]
		if entry then
			entry.Frame.Visible = (currentTab == "All" or weapon.Config.Rarity == currentTab)
		end
	end
end

-- Build cards once
for i, weapon in ipairs(weaponList) do
	local card = makeCard(weapon)
	card.LayoutOrder = i
	card.Parent = scroll
end

-- Build tab buttons
for i, tabName in ipairs(TABS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 100, 1, 0)
	btn.Text = tabName
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.BackgroundColor3 = (tabName == currentTab) and Color3.fromRGB(60, 60, 80) or Color3.fromRGB(30, 30, 40)
	btn.LayoutOrder = i
	local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 4) tc.Parent = btn
	if GameConfig.RARITY[tabName] then
		local ts = Instance.new("UIStroke") ts.Color = GameConfig.RARITY[tabName].Color ts.Thickness = 1 ts.Parent = btn
	end
	btn.Parent = tabBar
	btn.MouseButton1Click:Connect(function()
		currentTab = tabName
		for _, b in pairs(tabButtons) do
			b.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		end
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		applyTabFilter()
	end)
	tabButtons[tabName] = btn
end
applyTabFilter()

-- ==================== EVENT WIRING ====================
events:WaitForChild("EnterTrainingArena").OnClientEvent:Connect(function()
	screenGui.Enabled = true
	-- Reset status banner each entry
	statusLabel.Text = "Pick any weapon — close (X) to start shooting"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

events:WaitForChild("ExitTrainingArena").OnClientEvent:Connect(function()
	screenGui.Enabled = false
end)
