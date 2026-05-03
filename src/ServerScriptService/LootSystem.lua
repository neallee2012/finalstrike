-- LootSystem.lua (ServerScriptService)
-- Spawn initial loot pickups in the arena at designated spawn points

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local LootSystem = {}
local activeLoot = {}

local function createPickup(lootType, position)
	local part = Instance.new("Part")
	part.Name = lootType .. "Pickup"
	part.Anchored = true
	part.CanCollide = false
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position + Vector3.new(0, 2, 0)
	part:SetAttribute("LootType", lootType)

	if lootType == "Ammo" then
		part.Color = Color3.fromRGB(255, 200, 50)
	elseif lootType == "Medkit" then
		part.Color = Color3.fromRGB(50, 255, 100)
	elseif lootType == "Coin" then
		part.Color = Color3.fromRGB(255, 215, 0)
	end
	part.Material = Enum.Material.Neon

	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 1
	light.Range = 12
	light.Parent = part

	-- Bobbing animation
	local startY = part.Position.Y
	task.spawn(function()
		local t = math.random() * math.pi * 2
		while part and part.Parent do
			t = t + 0.05
			part.Position = Vector3.new(part.Position.X, startY + math.sin(t) * 0.5, part.Position.Z)
			part.Orientation = Vector3.new(0, t * 30 % 360, 0)
			task.wait(0.03)
		end
	end)

	-- Pickup on touch
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		local mm = _G.MatchManager
		if not mm then return end
		local data = mm.getPlayerData(player)
		if not data or data.Eliminated then return end

		if lootType == "Ammo" then
			data.Ammo = data.Ammo + GameConfig.LOOT.Ammo.Amount
			events.AmmoUpdate:FireClient(player, data.Ammo, 30)
		elseif lootType == "Medkit" then
			mm.healPlayer(player, GameConfig.LOOT.Medkit.Heal)
		elseif lootType == "Coin" then
			data.Coins = data.Coins + GameConfig.LOOT.Coin.Amount
		end

		-- Quest progress: any loot pickup counts toward "拾取 5 個戰利品"
		if _G.DailyQuestService then
			_G.DailyQuestService.recordEvent(player, "LootPickup", 1)
		end

		events.LootPickedUp:FireClient(player, lootType, 1)

		-- Remove from active list & destroy
		for i, l in ipairs(activeLoot) do
			if l == part then table.remove(activeLoot, i) break end
		end
		part:Destroy()
	end)

	part.Parent = workspace
	table.insert(activeLoot, part)
	return part
end

function LootSystem.spawnLoot()
	local arena = workspace:FindFirstChild("LastZone") and workspace.LastZone:FindFirstChild("Arena")
	if not arena then return end

	local lootSpawns = arena:FindFirstChild("LootSpawns")
	if not lootSpawns then return end

	for _, marker in ipairs(lootSpawns:GetChildren()) do
		local lootType = marker:GetAttribute("LootType")
		if lootType then
			createPickup(lootType, marker.Position)
		end
	end

	print("[LootSystem] Spawned", #activeLoot, "pickups")
end

function LootSystem.cleanup()
	for _, l in ipairs(activeLoot) do
		if l.Parent then l:Destroy() end
	end
	activeLoot = {}
end

-- Phase listener
task.spawn(function()
	while true do
		task.wait(1)
		local mm = _G.MatchManager
		if mm then
			if mm.CurrentPhase == GameConfig.PHASE.PVE and #activeLoot == 0 then
				LootSystem.spawnLoot()
			elseif mm.CurrentPhase == GameConfig.PHASE.LOBBY then
				if #activeLoot > 0 then
					LootSystem.cleanup()
				end
			end
		end
	end
end)

return LootSystem
