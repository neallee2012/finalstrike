-- LootSystem.lua (ServerScriptService)
-- Spawn initial loot pickups in the arena at designated spawn points

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local LootSystem = {}
local activeLoot = {}  -- list of Part instances
-- Per-pickup bob state, keyed by Part. One Heartbeat below drives all of them
-- in a single pass — replaces N coroutines × 33Hz of task.wait(0.03) loops.
local bobState = {}    -- [Part] = { StartY = number, Phase = number }

local function createPickup(lootType, position)
	local part = Instance.new("Part")
	part.Name = lootType .. "Pickup"
	part.Anchored = true
	part.CanCollide = false
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position + Vector3.new(0, 2, 0)
	part:SetAttribute("LootType", lootType)

	-- Sprint 8b: 4-tier medkit colors (light → standard → deep green → off-white for full)
	if lootType == "Ammo" then
		part.Color = Color3.fromRGB(255, 200, 50)
	elseif lootType == "MedkitSmall" then
		part.Color = Color3.fromRGB(120, 255, 150)  -- light green (50 HP)
	elseif lootType == "Medkit" then
		part.Color = Color3.fromRGB(50, 255, 100)   -- standard green (100 HP)
	elseif lootType == "MedkitLarge" then
		part.Color = Color3.fromRGB(20, 200, 80)    -- deep green (150 HP)
	elseif lootType == "MedkitFull" then
		part.Color = Color3.fromRGB(255, 255, 200)  -- off-white (full restore, 200 HP)
	elseif lootType == "Coin" then
		part.Color = Color3.fromRGB(255, 215, 0)
	end
	part.Material = Enum.Material.Neon

	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 1
	light.Range = 12
	light.Parent = part

	-- Register bob state; the central Heartbeat below ticks every active
	-- pickup in one pass.
	bobState[part] = { StartY = part.Position.Y, Phase = math.random() * math.pi * 2 }

	-- Pickup on touch. `consumed` guards idempotency — Roblox fires Touched
	-- once per character part that intersects (head, torso, legs, arms…) so a
	-- single pickup would otherwise pay out 6× before Destroy propagates.
	local consumed = false
	part.Touched:Connect(function(hit)
		if consumed then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		local mm = _G.MatchManager
		if not mm then return end
		local data = mm.getPlayerData(player)
		if not data or data.Eliminated then return end

		consumed = true

		if lootType == "Ammo" then
			data.Ammo = data.Ammo + GameConfig.LOOT.Ammo.Amount
			-- AmmoUpdate max should reflect equipped weapon's MagSize, not a hardcoded 30 (Issue 4).
			local weaponCfg = GameConfig.WEAPONS[data.Weapon]
			local maxAmmo = (weaponCfg and weaponCfg.MagSize) or data.Ammo
			events.AmmoUpdate:FireClient(player, data.Ammo, maxAmmo)
		elseif lootType == "MedkitSmall" or lootType == "Medkit"
		    or lootType == "MedkitLarge" or lootType == "MedkitFull" then
			-- Sprint 8b: 4-tier medkit; heal amount lookup from GameConfig.LOOT[tier].Heal
			local entry = GameConfig.LOOT[lootType]
			if entry and entry.Heal then
				mm.healPlayer(player, entry.Heal)
			end
		elseif lootType == "Coin" then
			-- Award persistent BulletCoins via CurrencyService (Issue 3 fix —
			-- previously a dead-state per-match counter that nothing read).
			if _G.CurrencyService then
				_G.CurrencyService.addCoins(player, GameConfig.LOOT.Coin.Amount, "NpcKills")
			end
		end

		-- Quest progress: any loot pickup counts toward "拾取 5 個戰利品"
		if _G.DailyQuestService then
			_G.DailyQuestService.recordEvent(player, "LootPickup", 1)
		end

		events.LootPickedUp:FireClient(player, lootType, 1)

		-- Remove from active list & bob registry, then destroy.
		for i, l in ipairs(activeLoot) do
			if l == part then table.remove(activeLoot, i) break end
		end
		bobState[part] = nil
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
		bobState[l] = nil
		if l.Parent then l:Destroy() end
	end
	activeLoot = {}
end

-- Central bob driver. One Heartbeat ticks every active pickup in one loop
-- pass — was N coroutines × ~33Hz of task.wait(0.03) before. Phase offset
-- per-pickup keeps the original "out of sync" wave look. Skips entries whose
-- Part has been destroyed (defensive; should already be cleaned up by callers).
local BOB_AMPLITUDE = 0.5  -- studs above/below StartY
local BOB_SPEED = 1.66     -- radians/sec (was t += 0.05 every 0.03s ≈ 1.66 rad/s)
local SPIN_DEG_PER_SEC = 50 -- rotation rate around Y
RunService.Heartbeat:Connect(function(dt)
	for part, state in pairs(bobState) do
		if part.Parent then
			state.Phase = state.Phase + BOB_SPEED * dt
			local pos = part.Position
			part.Position = Vector3.new(pos.X, state.StartY + math.sin(state.Phase) * BOB_AMPLITUDE, pos.Z)
			local orient = part.Orientation
			part.Orientation = Vector3.new(orient.X, (orient.Y + SPIN_DEG_PER_SEC * dt) % 360, orient.Z)
		else
			bobState[part] = nil
		end
	end
end)

-- React to phase changes via MatchManager.PhaseChangedServer (server-only
-- BindableEvent). Replaces a 1Hz polling loop — loot now spawns instantly
-- on PvE enter and clears immediately on LOBBY return.
task.spawn(function()
	local mm
	for _ = 1, 50 do  -- ~5s max wait for MatchManager to register itself
		mm = _G.MatchManager
		if mm and mm.PhaseChangedServer then break end
		task.wait(0.1)
	end
	if not mm or not mm.PhaseChangedServer then
		warn("[LootSystem] MatchManager.PhaseChangedServer never appeared; loot won't spawn")
		return
	end
	mm.PhaseChangedServer:Connect(function(phase)
		if phase == GameConfig.PHASE.PVE and #activeLoot == 0 then
			LootSystem.spawnLoot()
		elseif phase == GameConfig.PHASE.LOBBY and #activeLoot > 0 then
			LootSystem.cleanup()
		end
	end)
	-- Edge case: connected after PvE already started → kick a spawn.
	if mm.CurrentPhase == GameConfig.PHASE.PVE and #activeLoot == 0 then
		LootSystem.spawnLoot()
	end
end)

return LootSystem
