-- HUDController.lua (StarterPlayerScripts)
-- Client-side HUD: HP bar, ammo, match phase, timer, announcements, kill feed.
-- Lives in StarterPlayerScripts (NOT StarterGui) so it runs once per player session.
-- Putting it in StarterGui causes a duplicate ScreenGui on every character respawn,
-- producing overlapping LOBBY/timer text (issue #2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- ====== CREATE HUD ======
-- Main HUD ScreenGui keeps the default IgnoreGuiInset=false so existing widgets
-- (HP bar at bottom, alive count + currency at top, kill feed, announcement, etc.)
-- stay in their authored positions relative to the inset-aware coordinate space.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FinalStrikeHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- === HP BAR ===
local hpFrame = Instance.new("Frame")
hpFrame.Name = "HPFrame"
hpFrame.Size = UDim2.new(0, 300, 0, 30)
hpFrame.Position = UDim2.new(0.5, -150, 1, -60)
hpFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
hpFrame.BorderSizePixel = 0
hpFrame.Parent = screenGui

local hpCorner = Instance.new("UICorner")
hpCorner.CornerRadius = UDim.new(0, 6)
hpCorner.Parent = hpFrame

local hpBar = Instance.new("Frame")
hpBar.Name = "HPBar"
hpBar.Size = UDim2.new(1, -4, 1, -4)
hpBar.Position = UDim2.new(0, 2, 0, 2)
hpBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
hpBar.BorderSizePixel = 0
hpBar.Parent = hpFrame

local hpBarCorner = Instance.new("UICorner")
hpBarCorner.CornerRadius = UDim.new(0, 4)
hpBarCorner.Parent = hpBar

local hpText = Instance.new("TextLabel")
hpText.Name = "HPText"
hpText.Size = UDim2.new(1, 0, 1, 0)
hpText.BackgroundTransparency = 1
hpText.Text = "100 / 100"
hpText.TextColor3 = Color3.fromRGB(255, 255, 255)
hpText.TextScaled = true
hpText.Font = Enum.Font.GothamBold
hpText.ZIndex = 2
hpText.Parent = hpFrame

-- === AMMO DISPLAY ===
local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "AmmoLabel"
ammoLabel.Size = UDim2.new(0, 150, 0, 30)
ammoLabel.Position = UDim2.new(1, -170, 1, -60)
ammoLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
ammoLabel.BackgroundTransparency = 0.3
ammoLabel.BorderSizePixel = 0
ammoLabel.Text = "AMMO: 30"
ammoLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
ammoLabel.TextScaled = true
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.Parent = screenGui

local ammoCorner = Instance.new("UICorner")
ammoCorner.CornerRadius = UDim.new(0, 6)
ammoCorner.Parent = ammoLabel

-- === PHASE & TIMER ===
local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "PhaseLabel"
phaseLabel.Size = UDim2.new(0, 300, 0, 40)
phaseLabel.Position = UDim2.new(0.5, -150, 0, 10)
phaseLabel.BackgroundTransparency = 1
phaseLabel.Text = "LOBBY"
phaseLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
phaseLabel.TextScaled = true
phaseLabel.Font = Enum.Font.GothamBold
phaseLabel.Parent = screenGui

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0, 200, 0, 50)
timerLabel.Position = UDim2.new(0.5, -100, 0, 50)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = ""
timerLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Parent = screenGui

-- === ANNOUNCEMENT ===
local announcementLabel = Instance.new("TextLabel")
announcementLabel.Name = "Announcement"
announcementLabel.Size = UDim2.new(0.8, 0, 0, 60)
announcementLabel.Position = UDim2.new(0.1, 0, 0.35, 0)
announcementLabel.BackgroundTransparency = 1
announcementLabel.Text = ""
announcementLabel.TextColor3 = Color3.fromRGB(255, 60, 50)
announcementLabel.TextScaled = true
announcementLabel.Font = Enum.Font.GothamBold
announcementLabel.TextTransparency = 1
announcementLabel.Parent = screenGui

local function showAnnouncement(text)
	announcementLabel.Text = text
	announcementLabel.TextTransparency = 0
	-- Fade out after 3 seconds
	task.delay(3, function()
		for i = 0, 1, 0.05 do
			announcementLabel.TextTransparency = i
			task.wait(0.02)
		end
		announcementLabel.TextTransparency = 1
	end)
end

-- === KILL FEED ===
local killFeedFrame = Instance.new("Frame")
killFeedFrame.Name = "KillFeed"
killFeedFrame.Size = UDim2.new(0, 350, 0, 200)
killFeedFrame.Position = UDim2.new(1, -370, 0, 10)
killFeedFrame.BackgroundTransparency = 1
killFeedFrame.Parent = screenGui

local killFeedLayout = Instance.new("UIListLayout")
killFeedLayout.FillDirection = Enum.FillDirection.Vertical
killFeedLayout.VerticalAlignment = Enum.VerticalAlignment.Top
killFeedLayout.SortOrder = Enum.SortOrder.LayoutOrder
killFeedLayout.Padding = UDim.new(0, 2)
killFeedLayout.Parent = killFeedFrame

local killFeedOrder = 0

local function addKillFeedEntry(killer, victim, weapon)
	killFeedOrder = killFeedOrder + 1
	local entry = Instance.new("TextLabel")
	entry.Size = UDim2.new(1, 0, 0, 22)
	entry.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	entry.BackgroundTransparency = 0.5
	entry.BorderSizePixel = 0
	entry.Font = Enum.Font.GothamMedium
	entry.TextScaled = true
	entry.TextColor3 = Color3.fromRGB(255, 255, 255)
	entry.LayoutOrder = killFeedOrder

	if killer == "" then
		entry.Text = "  " .. victim .. " was eliminated"
	else
		entry.Text = "  " .. killer .. " [" .. weapon .. "] " .. victim
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = entry

	entry.Parent = killFeedFrame

	-- Remove after 5 seconds
	task.delay(5, function()
		entry:Destroy()
	end)
end

-- === CURRENCY DISPLAY (top-left, above alive count) ===
local currencyFrame = Instance.new("Frame")
currencyFrame.Name = "CurrencyFrame"
currencyFrame.Size = UDim2.new(0, 200, 0, 32)
currencyFrame.Position = UDim2.new(0, 20, 0, 10)
currencyFrame.BackgroundColor3 = Color3.fromRGB(25, 22, 15)
currencyFrame.BackgroundTransparency = 0.2
currencyFrame.BorderSizePixel = 0
currencyFrame.Parent = screenGui

local currencyCorner = Instance.new("UICorner")
currencyCorner.CornerRadius = UDim.new(0, 6)
currencyCorner.Parent = currencyFrame

local currencyStroke = Instance.new("UIStroke")
currencyStroke.Color = Color3.fromRGB(255, 215, 0)
currencyStroke.Thickness = 1
currencyStroke.Parent = currencyFrame

local currencyLabel = Instance.new("TextLabel")
currencyLabel.Name = "CurrencyLabel"
currencyLabel.Size = UDim2.new(1, -10, 1, 0)
currencyLabel.Position = UDim2.new(0, 5, 0, 0)
currencyLabel.BackgroundTransparency = 1
currencyLabel.Text = "0 子彈幣 (B 開店)"
currencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
currencyLabel.TextScaled = true
currencyLabel.Font = Enum.Font.GothamBold
currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
currencyLabel.Parent = currencyFrame

-- === ALIVE PLAYERS COUNT ===
local aliveFrame = Instance.new("Frame")
aliveFrame.Name = "AliveFrame"
aliveFrame.Size = UDim2.new(0, 160, 0, 30)
aliveFrame.Position = UDim2.new(0, 20, 0, 50)  -- moved down to make room for currency display above
aliveFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
aliveFrame.BackgroundTransparency = 0.3
aliveFrame.BorderSizePixel = 0
aliveFrame.Parent = screenGui

local aliveCorner = Instance.new("UICorner")
aliveCorner.CornerRadius = UDim.new(0, 6)
aliveCorner.Parent = aliveFrame

local aliveLabel = Instance.new("TextLabel")
aliveLabel.Name = "AliveLabel"
aliveLabel.Size = UDim2.new(1, 0, 1, 0)
aliveLabel.BackgroundTransparency = 1
aliveLabel.Text = "ALIVE: -"
aliveLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
aliveLabel.TextScaled = true
aliveLabel.Font = Enum.Font.GothamBold
aliveLabel.Parent = aliveFrame

-- === WINNER BANNER ===
local winnerLabel = Instance.new("TextLabel")
winnerLabel.Name = "WinnerBanner"
winnerLabel.Size = UDim2.new(0.8, 0, 0, 80)
winnerLabel.Position = UDim2.new(0.1, 0, 0.25, 0)
winnerLabel.BackgroundTransparency = 1
winnerLabel.Text = ""
winnerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
winnerLabel.TextScaled = true
winnerLabel.Font = Enum.Font.GothamBold
winnerLabel.TextTransparency = 1
winnerLabel.TextStrokeTransparency = 0.5
winnerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
winnerLabel.Parent = screenGui

local function showWinner(text)
	winnerLabel.Text = text
	winnerLabel.TextTransparency = 0
	task.delay(6, function()
		for i = 0, 1, 0.03 do
			winnerLabel.TextTransparency = i
			task.wait(0.02)
		end
		winnerLabel.TextTransparency = 1
	end)
end

-- === CROSSHAIR ===
-- Lives in its own ScreenGui with IgnoreGuiInset=true so the crosshair at
-- UDim2(0.5, _, 0.5, _) lines up with camera.CFrame.LookVector (real viewport
-- center). Without this, the crosshair sits ~18px below true center because of
-- the top-bar inset, and shots aim slightly above what the player thinks they
-- are targeting (#13). Kept in a separate ScreenGui so the inset adjustment
-- doesn't affect the rest of the HUD layout (which is authored against the
-- inset-aware coordinate space).
local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "FinalStrikeCrosshair"
crosshairGui.ResetOnSpawn = false
crosshairGui.IgnoreGuiInset = true
crosshairGui.Parent = player.PlayerGui

-- CEO-spec 4-segment open-center reticle: top/bottom/left/right white lines
-- with a center gap. Black UIStroke outline keeps the reticle visible against
-- bright backgrounds (sky, neon lights). Matches the reference image — gap
-- around center, subtle black border.
local LINE_LENGTH = 14    -- length of each arm
local LINE_THICKNESS = 2
local CENTER_GAP = 6      -- pixels from screen center to inner end of each arm

local function makeReticleLine(name, size, position)
	local line = Instance.new("Frame")
	line.Name = name
	line.Size = size
	line.Position = position
	line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	line.BorderSizePixel = 0
	line.Parent = crosshairGui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.Parent = line
end

makeReticleLine("ReticleTop",
	UDim2.new(0, LINE_THICKNESS, 0, LINE_LENGTH),
	UDim2.new(0.5, -math.floor(LINE_THICKNESS/2), 0.5, -CENTER_GAP - LINE_LENGTH))
makeReticleLine("ReticleBottom",
	UDim2.new(0, LINE_THICKNESS, 0, LINE_LENGTH),
	UDim2.new(0.5, -math.floor(LINE_THICKNESS/2), 0.5, CENTER_GAP))
makeReticleLine("ReticleLeft",
	UDim2.new(0, LINE_LENGTH, 0, LINE_THICKNESS),
	UDim2.new(0.5, -CENTER_GAP - LINE_LENGTH, 0.5, -math.floor(LINE_THICKNESS/2)))
makeReticleLine("ReticleRight",
	UDim2.new(0, LINE_LENGTH, 0, LINE_THICKNESS),
	UDim2.new(0.5, CENTER_GAP, 0.5, -math.floor(LINE_THICKNESS/2)))

-- ====== EVENT HANDLERS ======
events:WaitForChild("HealthUpdate").OnClientEvent:Connect(function(hp, maxHP)
	hpBar.Size = UDim2.new(math.clamp(hp / maxHP, 0, 1), -4, 1, -4)
	hpText.Text = math.floor(hp) .. " / " .. math.floor(maxHP)

	-- Color shift based on HP
	if hp / maxHP > 0.6 then
		hpBar.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
	elseif hp / maxHP > 0.3 then
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	else
		hpBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	end
end)

events:WaitForChild("AmmoUpdate").OnClientEvent:Connect(function(current, max)
	ammoLabel.Text = "AMMO: " .. current
end)

events:WaitForChild("PhaseChanged").OnClientEvent:Connect(function(phase)
	phaseLabel.Text = string.upper(phase)

	if phase == "PvP" then
		phaseLabel.TextColor3 = Color3.fromRGB(255, 60, 50)
	elseif phase == "PvPWarning" then
		phaseLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	else
		phaseLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end)

events:WaitForChild("TimerUpdate").OnClientEvent:Connect(function(seconds)
	-- Server sends 0 to mean "no active countdown" (e.g. PvP phase has no time
	-- limit) — clear the label instead of showing 0:00 (#6).
	if seconds <= 0 then
		timerLabel.Text = ""
	else
		local min = math.floor(seconds / 60)
		local sec = seconds % 60
		timerLabel.Text = string.format("%d:%02d", min, sec)
	end
end)

events:WaitForChild("Announcement").OnClientEvent:Connect(function(msg)
	showAnnouncement(msg)
	-- Show winner banner for victory/defeat messages
	if string.find(msg, "WINS") or string.find(msg, "NO SURVIVORS") then
		showWinner(msg)
	end
end)

events:WaitForChild("KillFeed").OnClientEvent:Connect(function(killer, victim, weapon)
	addKillFeedEntry(killer, victim, weapon)
end)

events:WaitForChild("LootPickedUp").OnClientEvent:Connect(function(lootType, amount)
	showAnnouncement("+" .. lootType .. (amount > 1 and (" x" .. amount) or ""))
end)

events:WaitForChild("EquipWeapon").OnClientEvent:Connect(function(weaponName)
	showAnnouncement("EQUIPPED: " .. weaponName)
end)

-- Alive count update
local AliveCountUpdate = events:FindFirstChild("AliveCountUpdate")
if AliveCountUpdate then
	AliveCountUpdate.OnClientEvent:Connect(function(count)
		aliveLabel.Text = "ALIVE: " .. count
	end)
end

-- === CURRENCY UPDATES + REWARD POPUPS ===
-- Floating "+N" text that drifts up + fades, anchored under the currency frame.
local function showRewardPopup(delta)
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 200, 0, 30)
	popup.Position = UDim2.new(0, 20, 0, 48)
	popup.BackgroundTransparency = 1
	popup.Text = "+" .. delta .. " 子彈幣"
	popup.TextColor3 = Color3.fromRGB(255, 230, 60)
	popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	popup.TextStrokeTransparency = 0
	popup.TextScaled = true
	popup.Font = Enum.Font.GothamBlack
	popup.TextXAlignment = Enum.TextXAlignment.Left
	popup.Parent = screenGui

	-- Float down + fade (positioned below currencyFrame, drifts further)
	local TweenService = game:GetService("TweenService")
	TweenService:Create(popup, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 20, 0, 95),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.3, function() popup:Destroy() end)
end

local lastCoins = nil
local function updateCurrencyDisplay(amount)
	currencyLabel.Text = string.format("%d 子彈幣 (B 開店)", amount)
	if lastCoins ~= nil and amount > lastCoins then
		showRewardPopup(amount - lastCoins)
	end
	lastCoins = amount
end

local CurrencyUpdate = events:FindFirstChild("CurrencyUpdate")
if CurrencyUpdate then
	CurrencyUpdate.OnClientEvent:Connect(updateCurrencyDisplay)
end

-- Initial pull (sync RemoteFunction — no race with subscribe)
task.spawn(function()
	local GetCurrency = events:WaitForChild("GetCurrency", 5)
	if GetCurrency then
		local ok, c = pcall(function() return GetCurrency:InvokeServer() end)
		if ok and type(c) == "number" then
			updateCurrencyDisplay(c)
			lastCoins = c  -- suppress popup on initial load (would show "+0" or "+full balance" otherwise)
		end
	end
end)

-- Hit marker effect (any surface) — bigger ball + pulsing PointLight
local TweenService = game:GetService("TweenService")

events:WaitForChild("WeaponHit").OnClientEvent:Connect(function(position, normal)
	local spark = Instance.new("Part")
	spark.Size = Vector3.new(1.2, 1.2, 1.2)
	spark.Position = position
	spark.Anchored = true
	spark.CanCollide = false
	spark.Color = Color3.fromRGB(255, 220, 120)
	spark.Material = Enum.Material.Neon
	spark.Shape = Enum.PartType.Ball
	spark.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 100)
	light.Brightness = 6
	light.Range = 14
	light.Parent = spark

	-- Quick fade-and-shrink
	TweenService:Create(spark, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()

	task.delay(0.3, function() spark:Destroy() end)
end)

-- NPC hit: red flash on the body + floating damage number
events:WaitForChild("NPCDamaged").OnClientEvent:Connect(function(npcModel, damage, hitPos)
	if not npcModel or not npcModel.Parent then return end

	-- Red highlight pulse
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 60, 40)
	hl.OutlineColor = Color3.fromRGB(255, 200, 100)
	hl.FillTransparency = 0.4
	hl.OutlineTransparency = 0
	hl.Parent = npcModel
	task.delay(0.15, function() hl:Destroy() end)

	-- Floating damage number
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = hitPos + Vector3.new(0, 1, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 100, 0, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "-" .. damage
	lbl.TextColor3 = Color3.fromRGB(255, 230, 80)
	lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextStrokeTransparency = 0
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = bb

	-- Float up + fade
	TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = hitPos + Vector3.new(0, 5, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.7), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.75, function() anchor:Destroy() end)
end)
