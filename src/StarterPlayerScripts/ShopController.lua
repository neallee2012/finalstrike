-- ShopController.lua (StarterPlayerScripts)
-- Press B to open the weapon shop. Tabbed by rarity, grid of weapon cards.
-- Server (ShopService) is authoritative; client validates affordability/ownership
-- only for UX feedback and immediately disables already-owned cards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- Sort weapons by rarity order, then price (mirrors the CEO mockup layout)
local function buildWeaponList()
	local list = {}
	for name, cfg in pairs(GameConfig.WEAPONS) do
		if cfg.Price and cfg.Price > 0 then
			table.insert(list, { Name = name, Config = cfg })
		end
	end
	table.sort(list, function(a, b)
		local ra = GameConfig.RARITY[a.Config.Rarity]
		local rb = GameConfig.RARITY[b.Config.Rarity]
		if ra.Order ~= rb.Order then return ra.Order < rb.Order end
		return a.Config.Price < b.Config.Price
	end)
	return list
end
local weaponList = buildWeaponList()

-- Client-side state, refreshed via RemoteFunctions on open + RemoteEvents on change
local coins = 0
local owned = {}  -- set: [weaponName] = true
local primaryWeapon = nil  -- name of currently-equipped main weapon (server-authoritative)

-- ==================== UI ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
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

-- Header (title + currency display + close button)
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 60)
header.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
header.BorderSizePixel = 0
header.Parent = main
local hc = Instance.new("UICorner") hc.CornerRadius = UDim.new(0, 12) hc.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.5, -20, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FINAL STRIKE — WEAPON SHOP"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(0.35, -70, 0.7, 0)
coinsLabel.Position = UDim2.new(0.5, 10, 0.15, 0)
coinsLabel.BackgroundTransparency = 1
coinsLabel.Text = "0 子彈幣"
coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinsLabel.TextScaled = true
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
coinsLabel.Parent = header

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

-- Tab bar
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

-- Scroll grid of weapon cards
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
gridLayout.CellSize = UDim2.new(0, 200, 0, 110)
gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scroll
local sp = Instance.new("UIPadding")
sp.PaddingTop = UDim.new(0, 10)
sp.PaddingLeft = UDim.new(0, 10)
sp.PaddingRight = UDim.new(0, 10)
sp.Parent = scroll

-- Status bar (transient feedback for buy result)
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 24)
statusLabel.Position = UDim2.new(0, 10, 1, -30)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = "Press B to close"
statusLabel.Parent = main

local cards = {}  -- [weaponName] = { Frame=, BuyBtn= }

-- ==================== CARDS ====================
local function makeCard(weapon)
	local rarityCfg = GameConfig.RARITY[weapon.Config.Rarity]
	local card = Instance.new("Frame")
	card.Name = weapon.Name
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	card.BorderSizePixel = 0
	local cc = Instance.new("UICorner") cc.CornerRadius = UDim.new(0, 6) cc.Parent = card
	local cs = Instance.new("UIStroke") cs.Color = rarityCfg.Color cs.Thickness = 2 cs.Parent = card

	-- Rarity strip across the top of the card
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 4)
	strip.BackgroundColor3 = rarityCfg.Color
	strip.BorderSizePixel = 0
	strip.Parent = card

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -10, 0, 26)
	nameLbl.Position = UDim2.new(0, 5, 0, 8)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = weapon.Name
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.Parent = card

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -10, 0, 16)
	subLbl.Position = UDim2.new(0, 5, 0, 36)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = string.format("%s · %s", weapon.Config.Rarity, weapon.Config.Type)
	subLbl.TextColor3 = rarityCfg.Color
	subLbl.TextScaled = true
	subLbl.Font = Enum.Font.GothamMedium
	subLbl.Parent = card

	local priceLbl = Instance.new("TextLabel")
	priceLbl.Size = UDim2.new(0.5, -5, 0, 26)
	priceLbl.Position = UDim2.new(0, 5, 0, 56)
	priceLbl.BackgroundTransparency = 1
	priceLbl.Text = string.format("%d 幣", weapon.Config.Price)
	priceLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	priceLbl.TextScaled = true
	priceLbl.Font = Enum.Font.GothamBold
	priceLbl.TextXAlignment = Enum.TextXAlignment.Left
	priceLbl.Parent = card

	local buyBtn = Instance.new("TextButton")
	buyBtn.Size = UDim2.new(0.5, -10, 0, 30)
	buyBtn.Position = UDim2.new(0.5, 5, 0, 75)
	buyBtn.Text = "BUY"
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextScaled = true
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
	buyBtn.AutoButtonColor = true
	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 4) bc.Parent = buyBtn
	buyBtn.Parent = card

	-- Single button serves three states (BUY / EQUIP / inactive). Action depends
	-- on current text — refreshCards() updates text+color when state changes.
	buyBtn.MouseButton1Click:Connect(function()
		if buyBtn.Text == "BUY" then
			events.BuyWeapon:FireServer(weapon.Name)
			statusLabel.Text = "Buying " .. weapon.Name .. "..."
			statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		elseif buyBtn.Text == "EQUIP" then
			events.EquipPrimaryWeapon:FireServer(weapon.Name)
			statusLabel.Text = "Equipped " .. weapon.Name .. " as primary"
			statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
		end
		-- TOO POOR / EQUIPPED: no-op (server would reject anyway)
	end)

	cards[weapon.Name] = { Frame = card, BuyBtn = buyBtn }
	return card
end

local function refreshCards()
	for name, card in pairs(cards) do
		local cfg = GameConfig.WEAPONS[name]
		if owned[name] then
			if name == primaryWeapon then
				card.BuyBtn.Text = "EQUIPPED"
				card.BuyBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
				card.BuyBtn.AutoButtonColor = false
			else
				card.BuyBtn.Text = "EQUIP"
				card.BuyBtn.BackgroundColor3 = Color3.fromRGB(50, 90, 140)
				card.BuyBtn.AutoButtonColor = true
			end
		elseif coins < cfg.Price then
			card.BuyBtn.Text = "TOO POOR"
			card.BuyBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 50)
			card.BuyBtn.AutoButtonColor = false
		else
			card.BuyBtn.Text = "BUY"
			card.BuyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
			card.BuyBtn.AutoButtonColor = true
		end
	end
end

local function applyTabFilter()
	for _, weapon in ipairs(weaponList) do
		local entry = cards[weapon.Name]
		if entry then
			entry.Frame.Visible = (currentTab == "All" or weapon.Config.Rarity == currentTab)
		end
	end
end

-- Build all cards once
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
refreshCards()

-- ==================== EVENT WIRING ====================
events:WaitForChild("CurrencyUpdate").OnClientEvent:Connect(function(newAmount)
	coins = newAmount
	coinsLabel.Text = string.format("%d 子彈幣", coins)
	refreshCards()
end)

events:WaitForChild("OwnedWeaponsUpdate").OnClientEvent:Connect(function(list)
	owned = {}
	for _, name in ipairs(list) do owned[name] = true end
	refreshCards()
end)

events:WaitForChild("PrimaryWeaponUpdate").OnClientEvent:Connect(function(weaponName)
	primaryWeapon = weaponName
	refreshCards()
end)

events:WaitForChild("BuyWeaponResult").OnClientEvent:Connect(function(ok, reason, weaponName)
	if ok then
		statusLabel.Text = "✓ Purchased " .. weaponName
		statusLabel.TextColor3 = Color3.fromRGB(80, 220, 100)
	else
		local msg = ({
			broke = "Not enough 子彈幣 for " .. weaponName,
			owned = "You already own " .. weaponName,
			unknown = "Unknown weapon: " .. weaponName,
			noservice = "Shop unavailable, try again",
		})[reason] or ("Failed: " .. reason)
		statusLabel.Text = "✗ " .. msg
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
	end
end)

-- Initial state pull (sync RemoteFunctions — no race with OnClientEvent subscribe)
task.spawn(function()
	local GetCurrency = events:WaitForChild("GetCurrency")
	local GetOwned = events:WaitForChild("GetOwnedWeapons")
	local GetPrimary = events:WaitForChild("GetPrimaryWeapon")
	local ok1, c = pcall(function() return GetCurrency:InvokeServer() end)
	if ok1 and type(c) == "number" then
		coins = c
		coinsLabel.Text = string.format("%d 子彈幣", coins)
	end
	local ok2, list = pcall(function() return GetOwned:InvokeServer() end)
	if ok2 and type(list) == "table" then
		owned = {}
		for _, name in ipairs(list) do owned[name] = true end
	end
	local ok3, p = pcall(function() return GetPrimary:InvokeServer() end)
	if ok3 and type(p) == "string" then
		primaryWeapon = p
	end
	refreshCards()
end)

-- ==================== INPUT (B = toggle) ====================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		screenGui.Enabled = not screenGui.Enabled
	end
end)
