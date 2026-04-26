-- MatchManager.lua (ServerScriptService)
-- Core game loop: Lobby → PvE → PvP Warning → PvP → Match End

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for modules
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local PhaseChanged = events:WaitForChild("PhaseChanged")
local TimerUpdate = events:WaitForChild("TimerUpdate")
local Announcement = events:WaitForChild("Announcement")
local PlayerEliminated = events:WaitForChild("PlayerEliminated")
local KillFeed = events:WaitForChild("KillFeed")

local MatchManager = {}
MatchManager.CurrentPhase = GameConfig.PHASE.LOBBY
MatchManager.AlivePlayers = {}
MatchManager.PvPEnabled = false
MatchManager.MatchRunning = false

-- Player data store (per-match)
local playerData = {}  -- [player] = { HP, Ammo, Coins, Weapon, Eliminated }

function MatchManager.getPlayerData(player)
	return playerData[player]
end

function MatchManager.setPhase(phase)
	MatchManager.CurrentPhase = phase
	PhaseChanged:FireAllClients(phase)
	print("[MatchManager] Phase:", phase)
end

function MatchManager.initPlayerData(player)
	playerData[player] = {
		HP = GameConfig.MAX_HP,
		MaxHP = GameConfig.MAX_HP,
		Ammo = 30,
		Coins = 0,
		Weapon = "Viper",  -- start with pistol
		Eliminated = false,
		ProtectedUntil = 0,  -- set after teleportToArena
	}
	-- Send initial HP
	local healthUpdate = events:WaitForChild("HealthUpdate")
	healthUpdate:FireClient(player, GameConfig.MAX_HP, GameConfig.MAX_HP)
	local ammoUpdate = events:WaitForChild("AmmoUpdate")
	ammoUpdate:FireClient(player, 30, GameConfig.WEAPONS.Viper.MagSize)
end

function MatchManager.damagePlayer(player, damage, attacker)
	local data = playerData[player]
	if not data or data.Eliminated then return end

	local isPlayerAttacker = attacker and attacker:IsA("Player")

	-- Check PvP rules
	if isPlayerAttacker then
		if not MatchManager.PvPEnabled then
			return  -- PvP not active, no player damage
		end
	else
		-- NPC / environmental damage — honour spawn protection window
		if data.ProtectedUntil and tick() < data.ProtectedUntil then
			return
		end
	end

	data.HP = math.max(0, data.HP - damage)

	local healthUpdate = events:WaitForChild("HealthUpdate")
	healthUpdate:FireClient(player, data.HP, data.MaxHP)

	if data.HP <= 0 then
		MatchManager.eliminatePlayer(player, attacker)
	end
end

function MatchManager.healPlayer(player, amount)
	local data = playerData[player]
	if not data or data.Eliminated then return end

	data.HP = math.min(data.MaxHP, data.HP + amount)
	local healthUpdate = events:WaitForChild("HealthUpdate")
	healthUpdate:FireClient(player, data.HP, data.MaxHP)
end

function MatchManager.eliminatePlayer(player, killer)
	local data = playerData[player]
	if not data or data.Eliminated then return end

	data.Eliminated = true
	MatchManager.AlivePlayers[player] = nil

	-- Announce elimination
	PlayerEliminated:FireAllClients(player.Name)

	if killer and killer:IsA("Player") and killer ~= player then
		local killerData = playerData[killer]
		local weaponName = killerData and killerData.Weapon or "Unknown"
		KillFeed:FireAllClients(killer.Name, player.Name, weaponName)
	else
		KillFeed:FireAllClients("", player.Name, "Eliminated")
	end

	-- Teleport to spectator area
	task.delay(1, function()
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local specSpawn = workspace:FindFirstChild("LastZone")
				and workspace.LastZone:FindFirstChild("SpectatorArea")
				and workspace.LastZone.SpectatorArea:FindFirstChild("SpectatorSpawn")
			if specSpawn then
				player.Character.HumanoidRootPart.CFrame = specSpawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
		-- Respawn them in spectator
		player:LoadCharacter()
		task.wait(1)
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local specSpawn = workspace.LastZone.SpectatorArea:FindFirstChild("SpectatorSpawn")
			if specSpawn then
				player.Character.HumanoidRootPart.CFrame = specSpawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end)

	-- Check win condition
	MatchManager.broadcastAliveCount()
	MatchManager.checkWinCondition()
end

function MatchManager.broadcastAliveCount()
	local count = 0
	for player, _ in pairs(MatchManager.AlivePlayers) do
		if player.Parent then count = count + 1 end
	end
	local aliveEvent = events:FindFirstChild("AliveCountUpdate")
	if aliveEvent then
		aliveEvent:FireAllClients(count)
	end
end

function MatchManager.checkWinCondition()
	if MatchManager.CurrentPhase ~= GameConfig.PHASE.PVP then return end

	local aliveCount = 0
	local lastAlive = nil
	for player, _ in pairs(MatchManager.AlivePlayers) do
		if player.Parent then  -- still in game
			aliveCount = aliveCount + 1
			lastAlive = player
		end
	end

	if aliveCount <= 1 then
		MatchManager.endMatch(lastAlive)
	end
end

function MatchManager.endMatch(winner)
	MatchManager.setPhase(GameConfig.PHASE.MATCH_END)
	MatchManager.MatchRunning = false
	MatchManager.PvPEnabled = false

	if winner then
		Announcement:FireAllClients(winner.Name .. " WINS!")
	else
		Announcement:FireAllClients("NO SURVIVORS")
	end

	-- Return to lobby after delay
	task.delay(8, function()
		MatchManager.resetToLobby()
	end)
end

function MatchManager.resetToLobby()
	MatchManager.setPhase(GameConfig.PHASE.LOBBY)
	MatchManager.AlivePlayers = {}
	MatchManager.PvPEnabled = false
	playerData = {}

	-- Teleport all players to lobby
	for _, player in ipairs(Players:GetPlayers()) do
		player:LoadCharacter()
		task.wait(0.5)
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local lobbySpawn = workspace:FindFirstChild("LastZone")
				and workspace.LastZone:FindFirstChild("Lobby")
				and workspace.LastZone.Lobby:FindFirstChild("LobbySpawn")
			if lobbySpawn then
				player.Character.HumanoidRootPart.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	Announcement:FireAllClients("WAITING FOR MATCH...")
end

function MatchManager.teleportToArena()
	local spawns = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("Arena")
		and workspace.LastZone.Arena:FindFirstChild("PlayerSpawns")
	if not spawns then return end

	local spawnList = spawns:GetChildren()
	local i = 1
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local sp = spawnList[((i - 1) % #spawnList) + 1]
			player.Character.HumanoidRootPart.CFrame = sp.CFrame + Vector3.new(0, 3, 0)
			i = i + 1
		end
	end
end

-- ============ MAIN MATCH LOOP ============
function MatchManager.startMatch()
	if MatchManager.MatchRunning then return end
	MatchManager.MatchRunning = true

	-- Initialize all current players
	for _, player in ipairs(Players:GetPlayers()) do
		MatchManager.initPlayerData(player)
		MatchManager.AlivePlayers[player] = true
	end

	Announcement:FireAllClients("MATCH STARTING...")
	task.wait(2)

	-- Teleport to arena
	MatchManager.teleportToArena()
	-- Grant spawn protection so NPCs can't gank players the instant they land
	local protectionEnd = tick() + GameConfig.SPAWN_PROTECTION
	for _, p in ipairs(Players:GetPlayers()) do
		local d = playerData[p]
		if d then d.ProtectedUntil = protectionEnd end
	end
	Announcement:FireAllClients(string.format("SPAWN PROTECTION %ds", GameConfig.SPAWN_PROTECTION))
	task.wait(1)
	MatchManager.broadcastAliveCount()

	-- === PvE Phase ===
	MatchManager.setPhase(GameConfig.PHASE.PVE)
	MatchManager.PvPEnabled = false
	Announcement:FireAllClients("PvE PHASE - FIGHT ENEMIES & COLLECT LOOT!")

	-- Spawn NPCs (handled by NPCSystem listening to phase)
	-- Spawn loot (handled by LootSystem listening to phase)

	for t = GameConfig.PVE_DURATION, 1, -1 do
		if not MatchManager.MatchRunning then return end
		TimerUpdate:FireAllClients(t)
		task.wait(1)
	end

	-- === PvP Warning ===
	MatchManager.setPhase(GameConfig.PHASE.PVP_WARNING)
	Announcement:FireAllClients("⚠ FINAL STRIKE BEGINS ⚠")

	for t = GameConfig.PVP_COUNTDOWN, 1, -1 do
		if not MatchManager.MatchRunning then return end
		TimerUpdate:FireAllClients(t)
		Announcement:FireAllClients("PvP IN " .. t .. "...")
		task.wait(1)
	end

	-- === PvP Phase ===
	MatchManager.setPhase(GameConfig.PHASE.PVP)
	MatchManager.PvPEnabled = true
	Announcement:FireAllClients("⚔ FINAL STRIKE - LAST ONE STANDING WINS ⚔")

	-- PvP runs until someone wins (checkWinCondition handles it)
end

-- ============ LOBBY TRIGGER ============
local function setupLobbyTrigger()
	-- Wait for map
	local map = workspace:WaitForChild("LastZone", 30)
	if not map then return end
	local lobby = map:WaitForChild("Lobby", 10)
	if not lobby then return end
	local pad = lobby:WaitForChild("StartMatchPad", 10)
	if not pad then return end

	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if MatchManager.MatchRunning then return end

		local playerCount = #Players:GetPlayers()
		if playerCount >= GameConfig.MIN_PLAYERS then
			MatchManager.startMatch()
		end
	end)
end

-- ============ PLAYER CONNECTIONS ============
Players.PlayerRemoving:Connect(function(player)
	if MatchManager.AlivePlayers[player] then
		MatchManager.AlivePlayers[player] = nil
		playerData[player] = nil
		MatchManager.checkWinCondition()
	end
end)

-- Handle weapon fire from client
events:WaitForChild("FireWeapon").OnServerEvent:Connect(function(player, origin, direction, weaponName)
	local data = playerData[player]
	if not data or data.Eliminated then return end

	local config = GameConfig.WEAPONS[weaponName]
	if not config then return end

	-- Ammo check
	if config.Type ~= "Knife" then
		if data.Ammo <= 0 then return end
		data.Ammo = data.Ammo - 1
		events.AmmoUpdate:FireClient(player, data.Ammo, config.MagSize)
	end

	-- Raycast
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { player.Character }

	local pellets = config.Pellets or 1
	for _ = 1, pellets do
		local spread = Vector3.new(
			(math.random() - 0.5) * config.Spread * 2,
			(math.random() - 0.5) * config.Spread * 2,
			(math.random() - 0.5) * config.Spread * 2
		)
		local dir = (direction.Unit + spread).Unit * config.Range

		local result = workspace:Raycast(origin, dir, rayParams)
		if result then
			local hitPart = result.Instance
			local hitChar = hitPart.Parent
			local hitHumanoid = hitChar and hitChar:FindFirstChildOfClass("Humanoid")

			if hitHumanoid then
				-- Check if it's a player
				local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
				if hitPlayer then
					MatchManager.damagePlayer(hitPlayer, config.Damage, player)
				else
					-- It's an NPC - let NPCSystem handle death via HP attribute listener
					local npcHP = hitChar:GetAttribute("HP")
					if npcHP then
						npcHP = npcHP - config.Damage
						hitChar:SetAttribute("HP", npcHP)
						-- Tell clients to flash the NPC and float a damage number
						events.NPCDamaged:FireAllClients(hitChar, config.Damage, result.Position)
					end
				end
			end

			-- Generic hit spark (also fires for non-Humanoid hits like cover)
			events.WeaponHit:FireAllClients(result.Position, result.Normal)
		end
	end
end)

-- Reload handler
events:WaitForChild("ReloadWeapon").OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data or data.Eliminated then return end

	local config = GameConfig.WEAPONS[data.Weapon]
	if not config or config.Type == "Knife" then return end

	task.wait(config.ReloadTime)
	data.Ammo = config.MagSize
	events.AmmoUpdate:FireClient(player, data.Ammo, config.MagSize)
	events.ReloadComplete:FireClient(player)
end)

-- Make MatchManager accessible to other scripts
local mmValue = Instance.new("ObjectValue")
mmValue.Name = "MatchManagerRef"
mmValue.Parent = ReplicatedStorage

-- Store reference for other server scripts
_G.MatchManager = MatchManager

-- Start
task.defer(setupLobbyTrigger)

return MatchManager
