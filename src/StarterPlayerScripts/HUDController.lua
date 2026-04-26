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

-- === ALIVE PLAYERS COUNT ===
local aliveFrame = Instance.new("Frame")
aliveFrame.Name = "AliveFrame"
aliveFrame.Size = UDim2.new(0, 160, 0, 30)
aliveFrame.Position = UDim2.new(0, 20, 0, 10)
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
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.new(0, 2, 0, 20)
crosshair.Position = UDim2.new(0.5, -1, 0.5, -10)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshair.BorderSizePixel = 0
crosshair.Parent = screenGui

local crosshairH = Instance.new("Frame")
crosshairH.Size = UDim2.new(0, 20, 0, 2)
crosshairH.Position = UDim2.new(0.5, -10, 0.5, -1)
crosshairH.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshairH.BorderSizePixel = 0
crosshairH.Parent = screenGui

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
	local min = math.floor(seconds / 60)
	local sec = seconds % 60
	timerLabel.Text = string.format("%d:%02d", min, sec)
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

-- Winner display
local WinnerAnnounce = events:FindFirstChild("Announcement")
-- We detect winner text inside the existing Announcement handler
local origAnnouncementHandler = nil -- already connected above

-- Hit marker effect
events:WaitForChild("WeaponHit").OnClientEvent:Connect(function(position, normal)
	-- Simple hit spark
	local spark = Instance.new("Part")
	spark.Size = Vector3.new(0.3, 0.3, 0.3)
	spark.Position = position
	spark.Anchored = true
	spark.CanCollide = false
	spark.Color = Color3.fromRGB(255, 200, 100)
	spark.Material = Enum.Material.Neon
	spark.Shape = Enum.PartType.Ball
	spark.Parent = workspace

	task.delay(0.15, function()
		spark:Destroy()
	end)
end)
