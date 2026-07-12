-- MatchManager.lua (ServerScriptService)
-- Core game loop: Lobby → PvE → PvP Warning → PvP → Match End

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Wait for modules
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponMeshes = require(ServerStorage:WaitForChild("WeaponMeshes"))
local ReloadLogic = require(ServerStorage:WaitForChild("ReloadLogic"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local PhaseChanged = events:WaitForChild("PhaseChanged")
local TimerUpdate = events:WaitForChild("TimerUpdate")
local Announcement = events:WaitForChild("Announcement")
local PlayerEliminated = events:WaitForChild("PlayerEliminated")
local KillFeed = events:WaitForChild("KillFeed")
local AmmoUpdate = events:WaitForChild("AmmoUpdate")
local ReloadStateChanged = events:WaitForChild("ReloadStateChanged")
local RELOAD_POSE_ATTRIBUTE = "FinalStrikeReloading"

-- Per-shot [Fire] debug logging. Auto weapons fire ~12 shots/sec and shotguns
-- log per pellet, so this is OFF by default to avoid flooding the console
-- during normal play. Flip to true on the running server (or here) when
-- debugging aim drift / hit registration. Reviewer-requested gate (#13).
local DEBUG_FIRE_LOG = false

local MatchManager = {}
MatchManager.CurrentPhase = GameConfig.PHASE.LOBBY
MatchManager.AlivePlayers = {}
MatchManager.PvPEnabled = false
MatchManager.MatchRunning = false
MatchManager.EliminationOrder = {}  -- victims pushed in death order; placement = TotalPlayers - #order + 1
MatchManager.TotalPlayers = 0       -- snapshot at startMatch for placement math

-- Server-only phase event for sibling server scripts (NPCSystem / LootSystem)
-- to react to phase changes without polling _G.MatchManager.CurrentPhase every
-- second. Exposed on MatchManager so consumers can `:Connect` directly.
local phaseChangedServer = Instance.new("BindableEvent")
phaseChangedServer.Name = "PhaseChangedServer"
MatchManager.PhaseChangedServer = phaseChangedServer.Event

-- Player data store (per-match)
local playerData = {}  -- [player] = { HP, MaxHP, Ammo, ReserveAmmo, Weapon, Eliminated, ProtectedUntil, Reloading, ReloadToken, ReloadEndsAt }

local function pushAmmoState(player, data)
	if player.Parent ~= Players then return end
	local config = GameConfig.WEAPONS[data.Weapon]
	local magSize = (config and config.MagSize) or 0
	AmmoUpdate:FireClient(player, data.Ammo or 0, data.ReserveAmmo or 0, magSize)
end

local function setReloadPoseState(player, active)
	if player.Parent == Players then
		player:SetAttribute(RELOAD_POSE_ATTRIBUTE, active == true)
	end
end

-- Reward helper: routes through CurrencyService (which enforces per-match caps)
-- and logs successful awards. Returns 0 if CurrencyService not loaded yet or capped.
local function awardCoins(player, amount, category, reason)
	if not _G.CurrencyService then return 0 end
	local actual = _G.CurrencyService.addCoins(player, amount, category)
	if actual > 0 then
		print(string.format("[Reward] %s +%d coins (%s)", player.Name, actual, reason))
	end
	return actual
end

-- Quest helper: increments daily quest progress (silent if service not loaded)
local function recordQuest(player, eventType, count)
	if _G.DailyQuestService then
		_G.DailyQuestService.recordEvent(player, eventType, count or 1)
	end
end

function MatchManager.getPlayerData(player)
	return playerData[player]
end

function MatchManager.setPhase(phase)
	MatchManager.CurrentPhase = phase
	PhaseChanged:FireAllClients(phase)
	phaseChangedServer:Fire(phase)  -- server-side fan-out for NPCSystem / LootSystem
	-- Phases without an active countdown clear the timer label.
	-- PvE / PvPWarning / PvP all push their own per-second TimerUpdate now (#19),
	-- so only MATCH_END / LOBBY need the explicit zero clear.
	if phase == GameConfig.PHASE.MATCH_END or phase == GameConfig.PHASE.LOBBY then
		TimerUpdate:FireAllClients(0)
	end
	print("[MatchManager] Phase:", phase)
end

function MatchManager.initPlayerData(player)
	-- Use player's chosen primary weapon (from shop equip) — fallback to STARTER_WEAPONS
	-- if ShopService isn't loaded or hasn't loaded the player yet.
	local equipped = (_G.ShopService and _G.ShopService.getPrimary(player)) or GameConfig.STARTER_WEAPONS[1]
	if not GameConfig.WEAPONS[equipped] then
		equipped = GameConfig.STARTER_WEAPONS[1]
	end
	local equippedCfg = GameConfig.WEAPONS[equipped]

	-- Start each player with a full magazine of their equipped weapon (Issue 4).
	-- Knives have no MagSize, so we fall back to 0 (knives ignore Ammo anyway).
	local startingAmmo = equippedCfg.MagSize or 0
	local previousData = playerData[player]
	if previousData then ReloadLogic.cancel(previousData) end
	playerData[player] = {
		HP = GameConfig.MAX_HP,
		MaxHP = GameConfig.MAX_HP,
		Ammo = startingAmmo,
		ReserveAmmo = startingAmmo * GameConfig.STARTING_RESERVE_MAGAZINES,
		Weapon = equipped,
		Eliminated = false,
		ProtectedUntil = 0,  -- set after teleportToArena
		Reloading = false,
		ReloadToken = 0,
		ReloadEndsAt = 0,
	}
	-- Send initial HP + ammo + equipped weapon. WeaponClient relies on
	-- EquipWeapon to update its `currentWeapon`; without it the client
	-- keeps STARTER_WEAPONS[1] as the assumed weapon and uses wrong
	-- Range/FireRate/Auto stats client-side.
	local healthUpdate = events:WaitForChild("HealthUpdate")
	healthUpdate:FireClient(player, GameConfig.MAX_HP, GameConfig.MAX_HP)
	pushAmmoState(player, playerData[player])
	setReloadPoseState(player, false)
	ReloadStateChanged:FireClient(player, false, 0, equipped)
	events:WaitForChild("EquipWeapon"):FireClient(player, equipped)
end

function MatchManager.syncAmmoState(player)
	local data = playerData[player]
	if data then pushAmmoState(player, data) end
end

local function pushReloadState(player, active, duration, weaponName)
	if player.Parent == Players then
		setReloadPoseState(player, active)
		ReloadStateChanged:FireClient(player, active, duration or 0, weaponName)
	end
end

function MatchManager.cancelReload(player)
	local data = playerData[player]
	if not data then
		setReloadPoseState(player, false)
		return false
	end

	local wasReloading = ReloadLogic.cancel(data)
	if wasReloading then
		pushReloadState(player, false, 0, data.Weapon)
	else
		setReloadPoseState(player, false)
	end
	return wasReloading
end

function MatchManager.syncReloadState(player)
	local data = playerData[player]
	if not data then
		pushReloadState(player, false, 0, nil)
		return
	end

	if data.Reloading then
		local remaining = math.max(0, (data.ReloadEndsAt or 0) - tick())
		pushReloadState(player, true, remaining, data.Weapon)
	else
		pushReloadState(player, false, 0, data.Weapon)
	end
end

local function hasEquippedWeapon(player, weaponName)
	local character = player.Character
	local equippedTool = character and character:FindFirstChild(weaponName)
	return equippedTool ~= nil and equippedTool:IsA("Tool")
end

function MatchManager.startReload(player)
	local data = playerData[player]
	if not data then return false end
	if not hasEquippedWeapon(player, data.Weapon) then return false end

	local config = GameConfig.WEAPONS[data.Weapon]
	local operation = ReloadLogic.start(data, config, tick())
	if not operation then return false end

	pushReloadState(player, true, operation.Duration, operation.Weapon)
	task.delay(operation.Duration, function()
		if playerData[player] ~= data then return end
		if not hasEquippedWeapon(player, operation.Weapon) then
			MatchManager.cancelReload(player)
			return
		end
		if not ReloadLogic.complete(data, operation, config) then return end

		pushAmmoState(player, data)
		pushReloadState(player, false, 0, operation.Weapon)
	end)
	return true
end

function MatchManager.addAmmo(player, amount)
	local data = playerData[player]
	if not data or data.Eliminated then return 0 end
	if type(amount) ~= "number" or amount <= 0 then return 0 end

	local config = GameConfig.WEAPONS[data.Weapon]
	local magSize = config and config.MagSize
	if type(magSize) ~= "number" or magSize <= 0 then return 0 end

	local added = ReloadLogic.addReserve(
		data,
		config,
		amount,
		GameConfig.MAX_RESERVE_MAGAZINES
	)
	pushAmmoState(player, data)
	return added
end

-- Build a weapon Tool and parent it to the player's Character so Roblox's
-- built-in grip system holds it in the right hand with proper "tool pose"
-- animation. Removes any previously equipped weapon first. Tool is replicated
-- server-side so other players see it (third-person visible).
function MatchManager.attachWeapon(player, weaponName)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Remove any currently equipped Tool (auto-unequips and destroys)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then c:Destroy() end
	end

	local tool = WeaponMeshes.build(weaponName)
	if not tool then
		-- Weapon was removed from GameConfig (or builder Type missing). Fall back
		-- to the starter weapon so the player isn't left empty-handed. Avoid
		-- infinite recursion by only retrying if the fallback is different.
		local fallback = GameConfig.STARTER_WEAPONS[1]
		if fallback and fallback ~= weaponName then
			warn(string.format("[MatchManager] No mesh for %s; falling back to %s", weaponName, fallback))
			-- Update server-side weapon record so subsequent fire/reload paths use the fallback
			local data = playerData[player]
			if data then data.Weapon = fallback end
			tool = WeaponMeshes.build(fallback)
		end
		if not tool then return end
	end

	-- Parenting Tool directly to Character auto-equips it (skipping Backpack)
	-- and triggers the engine's grip + tool-hold animation.
	tool.Parent = char

	-- WeaponMeshes currently normalizes the RightGrip orientation here; the
	-- off-hand IK path is disabled inside the module until a non-propulsive
	-- grip mechanism replaces the old rigid solver (#56).
	WeaponMeshes.attachLeftHandIK(char, tool)
end

-- Hook respawn so the weapon re-attaches on the new Character.
-- Phase guard (#35 / #38): only re-attach during ARENA phases. Lobby /
-- MatchEnd respawns must NOT carry a weapon — players hang out in the lobby
-- without guns. Without this guard, a death → respawn during the brief
-- window before resetToLobby clears playerData would hand the weapon back.
local ARENA_PHASES = {
	[GameConfig.PHASE.PVE] = true,
	[GameConfig.PHASE.PVP_WARNING] = true,
	[GameConfig.PHASE.PVP] = true,
}

local function bindRespawnHook(player)
	player.CharacterAdded:Connect(function()
		-- A new character invalidates any reload animation/tool state tied to
		-- the previous rig. Cancel before the client clears its local state.
		MatchManager.cancelReload(player)
		task.wait(0.5)  -- let R15 rig finish loading
		if not ARENA_PHASES[MatchManager.CurrentPhase] then return end
		local data = playerData[player]
		if data and not data.Eliminated and data.Weapon then
			MatchManager.attachWeapon(player, data.Weapon)
		end
	end)
end
Players.PlayerAdded:Connect(bindRespawnHook)
for _, p in ipairs(Players:GetPlayers()) do bindRespawnHook(p) end

function MatchManager.damagePlayer(player, damage, attacker)
	local data = playerData[player]
	if not data or data.Eliminated then return end

	-- (#33) Player is invincible while in the training arena. Training NPCs
	-- still chase, shoot, and animate, but no damage applies — the practice
	-- is about aim and movement, not survival. Outside training this guard
	-- is a fast no-op via the inTraining[player] hash lookup.
	if _G.TrainingService and _G.TrainingService.isInTraining(player) then return end

	local isPlayerAttacker = attacker and attacker:IsA("Player")

	-- Check PvP rules
	if isPlayerAttacker then
		if not MatchManager.PvPEnabled then
			return  -- PvP not active, no player damage
		end
	else
		-- NPC / environmental damage — honour spawn protection window
		if data.ProtectedUntil and tick() < data.ProtectedUntil then
			print(string.format("[damagePlayer] BLOCKED by spawn protection: %s (until t+%.1f)", player.Name, data.ProtectedUntil - tick()))
			return
		end
	end

	print(string.format("[damagePlayer] %s -%d (%d->%d) by %s", player.Name, damage, data.HP, data.HP-damage, isPlayerAttacker and attacker.Name or "NPC"))
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

	MatchManager.cancelReload(player)
	data.Eliminated = true
	MatchManager.AlivePlayers[player] = nil

	-- Track elimination order for placement rewards. Placement is computed as
	-- (TotalPlayers - #EliminationOrder + 1) — the Nth-to-last person dies in Nth-to-last place.
	table.insert(MatchManager.EliminationOrder, player)
	local placement = MatchManager.TotalPlayers - #MatchManager.EliminationOrder + 1
	local rewards = GameConfig.ECONOMY.Rewards
	if placement <= 3 then
		awardCoins(player, rewards.PlacementTop3, nil, "Top 3 placement")
		recordQuest(player, "Top3Placement", 1)
	elseif placement <= 5 then
		awardCoins(player, rewards.PlacementTop5, nil, "Top 5 placement")
	end

	-- Killer reward (PvP only — eliminate is also called for NPC deaths but those
	-- have killer=NPC model not Player, so the IsA check filters correctly).
	if killer and killer:IsA("Player") and killer ~= player then
		awardCoins(killer, rewards.KillPlayer, "PlayerKills", "PvP kill on " .. player.Name)
		recordQuest(killer, "PlayerKill", 1)
	end

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
			-- Defensive Tool destroy (#35) — spectator respawn must be weaponless
			for _, c in ipairs(player.Character:GetChildren()) do
				if c:IsA("Tool") then c:Destroy() end
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
		-- Reset HUD HP back to full so the HP bar in the spectator/lobby view
		-- shows 100/100 instead of the 0/100 from when they died (#18). The
		-- per-match playerData is left as Eliminated=true so they can't fight
		-- back this match.
		data.HP = data.MaxHP
		events:WaitForChild("HealthUpdate"):FireClient(player, data.MaxHP, data.MaxHP)
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

	-- Winner gets the placement-1 bonus (in addition to MatchComplete below).
	-- Last-alive winners aren't pushed onto EliminationOrder, so the placement
	-- math in eliminatePlayer skips them — we award PlacementWin explicitly here.
	-- Plus FirstWinDaily if this is their first match win of the UTC day.
	local rewards = GameConfig.ECONOMY.Rewards
	if winner then
		awardCoins(winner, rewards.PlacementWin, nil, "Match win")
		if _G.DailyQuestService and rewards.FirstWinDaily then
			_G.DailyQuestService.claimFirstWinDailyIfAvailable(winner, rewards.FirstWinDaily)
		end
	end

	-- Match completion: everyone who was in the match (alive + eliminated) gets it.
	-- We use playerData (still populated until resetToLobby) to identify match participants.
	for player, _ in pairs(playerData) do
		if player.Parent then  -- still connected
			awardCoins(player, rewards.MatchComplete, nil, "Match complete")
			recordQuest(player, "MatchComplete", 1)
		end
	end

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
	for player in pairs(playerData) do
		MatchManager.cancelReload(player)
	end
	playerData = {}

	-- Defensive Tool destroy (#35 / #38): even though LoadCharacter destroys
	-- the existing character (and its Tool with it), some Roblox versions
	-- can race here. Explicitly destroying any equipped Tool first guarantees
	-- the lobby spawn is gun-less.
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			for _, c in ipairs(char:GetChildren()) do
				if c:IsA("Tool") then c:Destroy() end
			end
		end
	end

	-- Teleport all players to lobby + reset HUD HP back to full (#18) so the
	-- HP bar doesn't keep showing whatever it was at when the match ended.
	local healthUpdate = events:WaitForChild("HealthUpdate")
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
		healthUpdate:FireClient(player, GameConfig.MAX_HP, GameConfig.MAX_HP)
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

	-- Reset placement tracking and snapshot player count for placement math
	MatchManager.EliminationOrder = {}
	MatchManager.TotalPlayers = #Players:GetPlayers()

	-- Initialize all current players + reset their per-match earning caps so
	-- the previous match's cap doesn't leak into this one.
	for _, player in ipairs(Players:GetPlayers()) do
		MatchManager.initPlayerData(player)
		MatchManager.AlivePlayers[player] = true
		if _G.CurrencyService then _G.CurrencyService.resetMatchCaps(player) end
	end

	Announcement:FireAllClients("MATCH STARTING...")
	task.wait(2)

	-- Teleport to arena
	MatchManager.teleportToArena()
	-- Grant spawn protection so NPCs can't gank players the instant they land,
	-- and equip everyone's starting weapon model so it shows in their hand.
	local protectionEnd = tick() + GameConfig.SPAWN_PROTECTION
	for _, p in ipairs(Players:GetPlayers()) do
		local d = playerData[p]
		if d then
			d.ProtectedUntil = protectionEnd
			MatchManager.attachWeapon(p, d.Weapon)
		end
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

	-- Survival reward: every 60s elapsed, give SurvivePerMin to all currently alive
	-- players. Counted in PvE phase only here; you could extend to PvP if desired.
	local survivalRate = GameConfig.ECONOMY.Rewards.SurvivePerMin
	for t = GameConfig.PVE_DURATION, 1, -1 do
		if not MatchManager.MatchRunning then return end
		TimerUpdate:FireAllClients(t)
		local elapsed = GameConfig.PVE_DURATION - t + 1
		if elapsed % 60 == 0 then
			for player, _ in pairs(MatchManager.AlivePlayers) do
				if player.Parent then
					awardCoins(player, survivalRate, "Survival", "Survived 1 minute")
					recordQuest(player, "SurviveSeconds", 60)
				end
			end
		end
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

	-- PvP has a 5-minute cap (#19). Whoever's alive when time runs out wins;
	-- if everyone died, the match ends with NO SURVIVORS. checkWinCondition
	-- can also end the match early once aliveCount drops to 1.
	for t = GameConfig.PVP_DURATION, 1, -1 do
		if not MatchManager.MatchRunning then return end
		TimerUpdate:FireAllClients(t)
		task.wait(1)
	end

	if MatchManager.MatchRunning then
		-- Time ran out — pick first surviving player as winner
		local winner = nil
		for p, _ in pairs(MatchManager.AlivePlayers) do
			if p.Parent then winner = p; break end
		end
		MatchManager.endMatch(winner)
	end
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

-- Anti-cheat: per-player last-fire timestamp for server-side rate limiting.
-- Declared up here (before PlayerRemoving) so the cleanup closure can see it
-- as an upvalue. Used by the FireWeapon handler below.
local lastFireTick = {}  -- [player] = tick() at last accepted shot

-- ============ PLAYER CONNECTIONS ============
Players.PlayerRemoving:Connect(function(player)
	if MatchManager.AlivePlayers[player] then
		MatchManager.AlivePlayers[player] = nil
		MatchManager.checkWinCondition()
	end
	local data = playerData[player]
	if data then ReloadLogic.cancel(data) end
	playerData[player] = nil
	lastFireTick[player] = nil  -- don't leak Player keys
end)

-- Anti-cheat: max distance from a player's HumanoidRootPart that we'll accept
-- as a "muzzle origin" for FireWeapon (Issue 2). Generous enough to cover any
-- weapon's handle-to-muzzle offset (longest is the Wraith sniper at ~4 studs)
-- plus normal client-server position desync, but far smaller than the map. A
-- cheating client trying to teleport-shoot has to first move their character close.
local MAX_FIRE_ORIGIN_DIST = 10

-- WeaponHit broadcast radius (Issue 7) — only clients with a character within
-- this distance of the impact point receive the hit-spark VFX. Cuts peak
-- network traffic during PvP without affecting gameplay.
local WEAPON_HIT_BROADCAST_DIST = 80

-- Send WeaponHit to nearby players only (Issue 7: distance filter).
local function broadcastHitNearby(position, normal)
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= WEAPON_HIT_BROADCAST_DIST then
			events.WeaponHit:FireClient(p, position, normal)
		end
	end
end

-- Anti-cheat helper: minimum allowed seconds between shots for this weapon.
-- Client also gates with FireRate, but a tampered client could spam past it;
-- the server enforces 90% of the declared FireRate (10% slack absorbs network
-- jitter / client-server timing drift). FireRate of 0 (knives use AttackRate)
-- and missing config skip the check.
local function getMinFireInterval(config)
	-- Knives use AttackRate; ranged weapons use FireRate. Both are seconds-per-shot.
	local rate = config.FireRate or config.AttackRate
	if not rate or rate <= 0 then return 0 end
	return rate * 0.9  -- 10% grace for jitter
end

-- Handle weapon fire from client
events:WaitForChild("FireWeapon").OnServerEvent:Connect(function(player, origin, direction, weaponName)
	local data = playerData[player]
	if not data or data.Eliminated then return end
	-- Anti-spoof: client must fire with their currently-equipped weapon name.
	-- Without this, a malicious client could pass any weapon (incl. unowned
	-- Demon-tier) and the server would use that weapon's stats for the raycast.
	if weaponName ~= data.Weapon then return end

	local config = GameConfig.WEAPONS[weaponName]
	if not config then return end
	if data.Reloading then return end

	-- Anti-cheat: server-side fire-rate limit. Reject calls faster than the
	-- weapon's declared rate (with 10% slack for jitter). Without this, an
	-- auto-clicker / packet-spammer can multiply DPS by spamming the RemoteEvent
	-- past the client's local FireRate gate.
	local minInterval = getMinFireInterval(config)
	if minInterval > 0 then
		local now = tick()
		local last = lastFireTick[player] or 0
		if now - last < minInterval then return end
		lastFireTick[player] = now
	end

	-- Anti-cheat: validate the client-supplied origin and direction (Issue 2).
	-- A naive exploit is to send an origin near a target so any direction is a
	-- guaranteed hit. We reject origins too far from the player's HumanoidRootPart
	-- and direction vectors that aren't real Vector3s.
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude < 0.001 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (origin - root.Position).Magnitude > MAX_FIRE_ORIGIN_DIST then
		warn(string.format("[FireWeapon] %s rejected: origin %.1f studs from HRP (max %d)", player.Name, (origin - root.Position).Magnitude, MAX_FIRE_ORIGIN_DIST))
		return
	end

	local shouldAutoReload = false

	-- Ammo check
	if config.Type ~= "Knife" then
		if data.Ammo <= 0 then return end
		data.Ammo = data.Ammo - 1
		pushAmmoState(player, data)
		shouldAutoReload = data.Ammo == 0
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
		-- Per-shot debug log (#13) — gated behind DEBUG_FIRE_LOG so auto-weapons
		-- and shotguns don't flood the console during normal combat.
		if DEBUG_FIRE_LOG then
			print(string.format("[Fire] %s %s hit=%s",
				player.Name, weaponName,
				result and (result.Instance:GetFullName() .. " @ " .. tostring(result.Position)) or "MISS"))
		end
		if result then
			local hitPart = result.Instance
			local hitChar = hitPart.Parent
			local hitHumanoid = hitChar and hitChar:FindFirstChildOfClass("Humanoid")

			if hitHumanoid then
				-- Sprint 8b D1: Sniper Type only — hitting Head part applies headshot multiplier.
				-- Other Types (Pistol/SMG/Rifle/Shotgun/Knife/Minigun) deal flat Damage on Head hit.
				-- Strict "Head part only" — NPC hat/hood/helmet accessories don't count (deflected).
				local damage = config.Damage
				local isHeadshot = hitPart.Name == "Head"
				if config.Type == "Sniper" and isHeadshot then
					damage = damage * GameConfig.HEADSHOT_MULTIPLIER
				end

				-- Check if it's a player
				local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
				if hitPlayer then
					MatchManager.damagePlayer(hitPlayer, damage, player)
				else
					-- It's an NPC - let NPCSystem handle death via HP attribute listener.
					-- Stamp LastAttackerId so NPCSystem.dropLoot can credit the kill bonus
					-- to the correct player. UserId (number) is used because Instance refs
					-- can't be stored in attributes.
					local npcHP = hitChar:GetAttribute("HP")
					if npcHP then
						npcHP = npcHP - damage
						hitChar:SetAttribute("HP", npcHP)
						hitChar:SetAttribute("LastAttackerId", player.UserId)
						-- Tell clients to flash the NPC and float a damage number
						events.NPCDamaged:FireAllClients(hitChar, damage, result.Position)
					end
				end
			end

			-- Generic hit spark (also fires for non-Humanoid hits like cover).
			-- Only nearby players see it (Issue 7: cuts peak PvP traffic ~70%).
			broadcastHitNearby(result.Position, result.Normal)
		end
	end

	if shouldAutoReload then
		MatchManager.startReload(player)
	end
end)

-- Reload handler
events:WaitForChild("ReloadWeapon").OnServerEvent:Connect(function(player)
	if not MatchManager.startReload(player) then
		MatchManager.syncReloadState(player)
	end
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
