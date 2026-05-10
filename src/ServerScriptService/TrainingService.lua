-- TrainingService.lua (ServerScriptService)
-- Standalone NPC practice flow:
--   - Listens on the lobby's TrainingArenaPortal pad — on touch, teleports
--     player to TrainingArena.TrainingEntry and fires EnterTrainingArena to
--     open the client-side weapon picker.
--   - Receives SelectTrainingWeapon from the client (any weapon, no
--     ownership check). Calls MatchManager.attachWeapon to swap models +
--     fires EquipWeapon so WeaponClient updates its currentWeapon.
--   - Listens on TrainingExitPad — on touch, teleports player back to
--     LobbySpawn and fires ExitTrainingArena.
--   - Spawns 6 mobile NPCs for combat practice (delegated to NPCSystem).
--
-- (#37 round 2) Touched events can drop after resetToLobby's LoadCharacter
-- — the new character's BaseParts may not all wire up Touched signals
-- before the player walks onto the pad. Defense in depth:
--   - Heartbeat-driven proximity poll (every 0.4s) calls the same entry
--     logic when a player is within 6 studs of the portal. Independent
--     of Touched.
--   - Aggressive logging on each reject branch so the next time the bug
--     surfaces, console output points at the failing check.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local TrainingService = {}

local inTraining = {}
local lastEnterTick = {}
local lastExitTick = {}
local PORTAL_DEBOUNCE = 1.5
local PROXIMITY_RANGE = 6   -- studs; pad is 8x8 so this catches "standing on pad"
local POLL_INTERVAL = 0.4   -- seconds between proximity sweeps

local function teleportPlayerTo(player, position)
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	return true
end

-- (#37) Single entry-decision function used by BOTH Touched and proximity
-- poll. Each reject path prints why so console output answers "why didn't
-- the portal let me in?" without a fresh debug session.
local function tryEnterTraining(player, source)
	if not player or not player.Parent then return end

	if inTraining[player] then
		print(string.format("[TrainingService] reject (%s): %s already inTraining", source, player.Name))
		return
	end

	local now = tick()
	if (lastEnterTick[player] or 0) + PORTAL_DEBOUNCE > now then
		-- Debounce hit — quiet log only when source is Touched (proximity
		-- poll naturally hits this constantly while standing on pad)
		if source == "Touched" then
			print(string.format("[TrainingService] reject (%s): %s in %.1fs debounce window",
				source, player.Name, PORTAL_DEBOUNCE - (now - (lastEnterTick[player] or 0))))
		end
		return
	end

	-- Soft-block: only refuse entry if THIS player is in an active match
	-- (in playerData with Eliminated=false). A lobby-bound player can always
	-- enter training, even if some other match is mid-cycle on a different
	-- server-state path. Previous version blanket-blocked on
	-- MatchManager.MatchRunning which was overly conservative.
	local mm = _G.MatchManager
	if mm and mm.MatchRunning then
		local data = mm.getPlayerData and mm.getPlayerData(player)
		if data and not data.Eliminated then
			print(string.format("[TrainingService] reject (%s): %s is in active match", source, player.Name))
			return
		end
	end

	local arena = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("TrainingArena")
	local entry = arena and arena:FindFirstChild("TrainingEntry")
	if not entry then
		warn(string.format("[TrainingService] reject (%s): TrainingArena.TrainingEntry not found", source))
		return
	end

	if not teleportPlayerTo(player, entry.Position) then
		print(string.format("[TrainingService] reject (%s): teleport failed for %s (no character/HRP)", source, player.Name))
		return
	end

	lastEnterTick[player] = now
	inTraining[player] = true
	if _G.NPCSystem and _G.NPCSystem.spawnTrainingDummies then
		_G.NPCSystem.spawnTrainingDummies()
	end
	events.EnterTrainingArena:FireClient(player)
	print(string.format("[TrainingService] entered (%s): %s → TrainingEntry", source, player.Name))
end

local function tryExitTraining(player, source)
	if not player or not player.Parent then return end
	if not inTraining[player] then return end  -- not in training; nothing to do

	local now = tick()
	if (lastExitTick[player] or 0) + PORTAL_DEBOUNCE > now then return end

	local lobby = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("Lobby")
	local lobbySpawn = lobby and lobby:FindFirstChild("LobbySpawn")
	if not lobbySpawn then
		warn(string.format("[TrainingService] reject exit (%s): LobbySpawn not found", source))
		return
	end

	-- Destroy equipped Tool before teleport — lobby is gun-less per #38.
	local char = player.Character
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Tool") then c:Destroy() end
		end
	end

	if not teleportPlayerTo(player, lobbySpawn.Position) then return end
	lastExitTick[player] = now
	inTraining[player] = nil
	events.ExitTrainingArena:FireClient(player)
	print(string.format("[TrainingService] exited (%s): %s → LobbySpawn", source, player.Name))
end

-- ============ WEAPON SELECT ============
events:WaitForChild("SelectTrainingWeapon").OnServerEvent:Connect(function(player, weaponName)
	if type(weaponName) ~= "string" then return end
	if not inTraining[player] then return end
	if not GameConfig.WEAPONS[weaponName] then return end

	local mm = _G.MatchManager
	if not mm then return end

	if not mm.getPlayerData(player) then
		mm.initPlayerData(player)
	end
	local data = mm.getPlayerData(player)
	if data then
		data.Weapon = weaponName
		data.Eliminated = false
		local cfg = GameConfig.WEAPONS[weaponName]
		data.Ammo = (cfg and cfg.MagSize) or data.Ammo
		events.AmmoUpdate:FireClient(player, data.Ammo, (cfg and cfg.MagSize) or data.Ammo)
	end
	mm.attachWeapon(player, weaponName)
	events.EquipWeapon:FireClient(player, weaponName)
	print(string.format("[TrainingService] %s picked %s", player.Name, weaponName))
end)

-- ============ PORTAL WIRING + PROXIMITY POLL ============
task.spawn(function()
	local lz = workspace:WaitForChild("LastZone", 30)
	if not lz then return end

	local lobby = lz:WaitForChild("Lobby", 10)
	local trainingArena = lz:WaitForChild("TrainingArena", 10)
	if not lobby or not trainingArena then
		warn("[TrainingService] Lobby or TrainingArena folder missing")
		return
	end

	-- Touched primary path
	local portal = lobby:WaitForChild("TrainingArenaPortal", 10)
	local exitPad = trainingArena:WaitForChild("TrainingExitPad", 10)
	if portal then
		portal.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then tryEnterTraining(player, "Touched") end
		end)
	end
	if exitPad then
		exitPad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then tryExitTraining(player, "Touched") end
		end)
	end

	-- (#37) Heartbeat proximity poll — fallback for when Touched silently
	-- doesn't fire after LoadCharacter. Re-finds the pad each tick so a
	-- destroyed/re-created Lobby can't kill the connection permanently.
	local pollAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		pollAcc = pollAcc + dt
		if pollAcc < POLL_INTERVAL then return end
		pollAcc = 0

		local lobbyNow = workspace:FindFirstChild("LastZone")
			and workspace.LastZone:FindFirstChild("Lobby")
		local portalNow = lobbyNow and lobbyNow:FindFirstChild("TrainingArenaPortal")
		local trainNow = workspace.LastZone and workspace.LastZone:FindFirstChild("TrainingArena")
		local exitNow = trainNow and trainNow:FindFirstChild("TrainingExitPad")

		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				if portalNow and (hrp.Position - portalNow.Position).Magnitude <= PROXIMITY_RANGE then
					tryEnterTraining(player, "Proximity")
				end
				if exitNow and (hrp.Position - exitNow.Position).Magnitude <= PROXIMITY_RANGE then
					tryExitTraining(player, "Proximity")
				end
			end
		end
	end)

	print("[TrainingService] Portals wired (Touched + proximity poll)")
end)

-- ============ LIFECYCLE ============
Players.PlayerRemoving:Connect(function(player)
	inTraining[player] = nil
	lastEnterTick[player] = nil
	lastExitTick[player] = nil
end)

-- (#37) On real-match start, sweep stale training state defensively.
task.spawn(function()
	local mm
	for _ = 1, 50 do
		mm = _G.MatchManager
		if mm and mm.PhaseChangedServer then break end
		task.wait(0.1)
	end
	if not mm or not mm.PhaseChangedServer then return end
	mm.PhaseChangedServer:Connect(function(phase)
		if phase == "PvE" then
			for player in pairs(inTraining) do
				inTraining[player] = nil
				lastEnterTick[player] = nil
			end
		end
	end)
end)

function TrainingService.isInTraining(player)
	return inTraining[player] == true
end

_G.TrainingService = TrainingService
return TrainingService
