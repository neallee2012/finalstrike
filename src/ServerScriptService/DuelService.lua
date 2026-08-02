-- DuelService.lua (ServerScriptService)
-- Standalone 1v1 duel mode, fully separate from MatchManager's 12-player
-- lifecycle. Owns its own queue, map vote, countdown, combat, and cleanup
-- state machine — never touches MatchManager.playerData / PvPEnabled.
--
-- Flow: touch DuelQueuePortal (lobby) → paired with 2nd queued player →
-- both vote on a map (DuelMaps registry) → teleport to the resolved map's
-- SpawnA/SpawnB → short countdown (camera locks via reused PhaseChanged
-- "PvE"/"PvPWarning" strings, same mechanism CameraController already uses
-- for the 12-player arena) → combat enabled ("PvP") → elimination or
-- disconnect resolves the winner exactly once → result banner → cleanup →
-- both players returned to the lobby.
--
-- Combat itself reuses the existing FireWeapon/ReloadWeapon RemoteEvents
-- (WeaponClient/ReloadLogic don't know or care which mode is running) via
-- dedicated listeners here that only act when the shooter is in an active
-- duel — MatchManager's own listeners on the same events no-op for duel
-- participants since they have no MatchManager.playerData entry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local DuelMaps = require(ReplicatedStorage:WaitForChild("DuelMaps"))
local ReloadLogic = require(ServerStorage:WaitForChild("ReloadLogic"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- Cache every remote via WaitForChild (not dot-indexing) — GameEventsBootstrap
-- creates the GameEvents Folder and then adds each RemoteEvent to it
-- synchronously but on a separate script thread, so a plain `events.X` lookup
-- from this script can race ahead of that population. Same pattern MatchManager
-- and TrainingService already use for every remote they reference.
local AmmoUpdate = events:WaitForChild("AmmoUpdate")
local ReloadStateChanged = events:WaitForChild("ReloadStateChanged")
local HealthUpdate = events:WaitForChild("HealthUpdate")
local FireWeapon = events:WaitForChild("FireWeapon")
local ReloadWeapon = events:WaitForChild("ReloadWeapon")
local WeaponHit = events:WaitForChild("WeaponHit")
local PhaseChanged = events:WaitForChild("PhaseChanged")
local TimerUpdate = events:WaitForChild("TimerUpdate")
local Announcement = events:WaitForChild("Announcement")
local PlayerEliminated = events:WaitForChild("PlayerEliminated")
local EquipWeapon = events:WaitForChild("EquipWeapon")
local DuelVoteOpen = events:WaitForChild("DuelVoteOpen")
local DuelVoteCast = events:WaitForChild("DuelVoteCast")
local DuelVoteClosed = events:WaitForChild("DuelVoteClosed")

local RELOAD_POSE_ATTRIBUTE = "FinalStrikeReloading"
local QUEUE_DEBOUNCE = 1.5      -- seconds; mirrors TrainingService's portal debounce
local MAX_FIRE_ORIGIN_DIST = 10 -- mirrors MatchManager's FireWeapon anti-cheat check

local DuelService = {}

local queue = {}            -- ordered array of players waiting for a pairing (max size 1 before pairing)
local playerDuel = {}       -- [player] = session (nil when not queued/dueling)
local lastQueueToggle = {}  -- [player] = tick() debounce
local lastFireTick = {}     -- [player] = tick() at last accepted shot (duel-scoped, independent of MatchManager)
local sessions = {}         -- active session list, for bulk sweeps (12p-start interference guard)

-- ============ SMALL HELPERS ============

local function getOpponent(session, player)
	if player == session.Players.A then return session.Players.B end
	if player == session.Players.B then return session.Players.A end
	return nil
end

local function pushAmmoState(player, data)
	if player.Parent ~= Players then return end
	local config = GameConfig.WEAPONS[data.Weapon]
	local magSize = (config and config.MagSize) or 0
	AmmoUpdate:FireClient(player, data.Ammo or 0, data.ReserveAmmo or 0, magSize)
end

local function pushReloadState(player, active, duration, weaponName)
	if player.Parent ~= Players then return end
	player:SetAttribute(RELOAD_POSE_ATTRIBUTE, active == true)
	ReloadStateChanged:FireClient(player, active, duration or 0, weaponName)
end

local function hasEquippedWeapon(player, weaponName)
	local character = player.Character
	local tool = character and character:FindFirstChild(weaponName)
	return tool ~= nil and tool:IsA("Tool")
end

local function updateQueueSign()
	local label = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("Lobby")
		and workspace.LastZone.Lobby:FindFirstChild("Bays")
	if not label then return end
	local sign = label:FindFirstChild("DuelQueueSign", true)
	local countLabel = sign and sign:FindFirstChild("QueueGui") and sign.QueueGui:FindFirstChild("CountLabel")
	if countLabel then
		countLabel.Text = string.format("1V1 QUEUE: %d/2", #queue)
	end
end

local function teleportToLobby(player)
	if not player or not player.Character then return end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	local lobbySpawn = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("Lobby")
		and workspace.LastZone.Lobby:FindFirstChild("LobbySpawn")
	if hrp and lobbySpawn then
		hrp.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
	end
	for _, c in ipairs(player.Character:GetChildren()) do
		if c:IsA("Tool") then c:Destroy() end
	end
end

-- ============ RELOAD (duel-scoped copy of MatchManager's flow) ============

local function startReload(player, session)
	local data = session.Data[player]
	if not data then return false end
	if not hasEquippedWeapon(player, data.Weapon) then return false end

	local config = GameConfig.WEAPONS[data.Weapon]
	local operation = ReloadLogic.start(data, config, tick())
	if not operation then return false end

	pushReloadState(player, true, operation.Duration, operation.Weapon)
	task.delay(operation.Duration, function()
		if session.Ended then return end
		if session.Data[player] ~= data then return end
		if not hasEquippedWeapon(player, operation.Weapon) then
			ReloadLogic.cancel(data)
			pushReloadState(player, false, 0, data.Weapon)
			return
		end
		if not ReloadLogic.complete(data, operation, config) then return end
		pushAmmoState(player, data)
		pushReloadState(player, false, 0, operation.Weapon)
	end)
	return true
end

-- ============ COMBAT RESOLUTION ============

local function applyDamage(session, victim, damage, attacker)
	if session.Ended then return end
	local data = session.Data[victim]
	if not data or data.Eliminated then return end

	data.HP = math.max(0, data.HP - damage)
	HealthUpdate:FireClient(victim, data.HP, data.MaxHP)

	if data.HP <= 0 then
		DuelService._eliminate(session, victim, attacker)
	end
end

local function removeSession(session)
	for i, s in ipairs(sessions) do
		if s == session then
			table.remove(sessions, i)
			break
		end
	end
end

local function cleanupSession(session)
	for _, p in pairs(session.Players) do
		if p then
			playerDuel[p] = nil
			if p.Parent then
				teleportToLobby(p)
				PhaseChanged:FireClient(p, GameConfig.PHASE.LOBBY)
				HealthUpdate:FireClient(p, GameConfig.MAX_HP, GameConfig.MAX_HP)
				AmmoUpdate:FireClient(p, 0, 0, 0)
			end
		end
	end
	removeSession(session)
end

local function finishDuel(session, winner, loser)
	session.Ended = true
	session.State = "Ended"

	for _, p in pairs(session.Players) do
		if p and p.Parent then
			PhaseChanged:FireClient(p, GameConfig.PHASE.MATCH_END)
			TimerUpdate:FireClient(p, 0)
		end
	end
	if loser and loser.Parent then
		PlayerEliminated:FireClient(loser, loser.Name)
	end
	if winner and winner.Parent then
		Announcement:FireClient(winner, "🏆 你贏得了 1v1 對決！")
	end
	if loser and loser.Parent then
		local winnerName = (winner and winner.Name) or "?"
		Announcement:FireClient(loser, string.format("💀 %s 贏得了對決", winnerName))
	end

	task.delay(GameConfig.DUEL.RESULT_DISPLAY_SECONDS, function()
		cleanupSession(session)
	end)
end

-- Exposed on the table (not local) so the CharacterAdded respawn-safety hook
-- below can call it without a forward-declaration dance.
function DuelService._eliminate(session, loser, killer)
	if session.Ended then return end
	local data = session.Data[loser]
	if data then data.Eliminated = true end
	local winner = getOpponent(session, loser)
	finishDuel(session, winner, loser)
end

-- ============ FIRE / RELOAD LISTENERS ============
-- Independent Connect on the shared RemoteEvents; MatchManager's own
-- listeners on these same events no-op for duel participants (no
-- MatchManager.playerData entry exists for them), so there is no double
-- damage or conflicting ammo state.

local function getMinFireInterval(config)
	local rate = config.FireRate or config.AttackRate
	if not rate or rate <= 0 then return 0 end
	return rate * 0.9
end

FireWeapon.OnServerEvent:Connect(function(player, origin, direction, weaponName)
	local session = playerDuel[player]
	if not session or session.Ended or session.State ~= "Combat" then return end
	local data = session.Data[player]
	if not data or data.Eliminated then return end
	if weaponName ~= data.Weapon then return end

	local config = GameConfig.WEAPONS[weaponName]
	if not config then return end
	if data.Reloading then return end

	local minInterval = getMinFireInterval(config)
	if minInterval > 0 then
		local now = tick()
		local last = lastFireTick[player] or 0
		if now - last < minInterval then return end
		lastFireTick[player] = now
	end

	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude < 0.001 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (origin - root.Position).Magnitude > MAX_FIRE_ORIGIN_DIST then return end

	local opponent = getOpponent(session, player)
	local shouldAutoReload = false

	if config.Type ~= "Knife" then
		if data.Ammo <= 0 then return end
		data.Ammo = data.Ammo - 1
		pushAmmoState(player, data)
		shouldAutoReload = data.Ammo == 0
	end

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
			local hitChar = result.Instance.Parent
			local hitPlayer = hitChar and Players:GetPlayerFromCharacter(hitChar)
			if hitPlayer and hitPlayer == opponent then
				local damage = config.Damage
				if config.Type == "Sniper" and result.Instance.Name == "Head" then
					damage = damage * GameConfig.HEADSHOT_MULTIPLIER
				end
				applyDamage(session, opponent, damage, player)
			end
			WeaponHit:FireClient(player, result.Position, result.Normal)
			if opponent and opponent.Parent then
				WeaponHit:FireClient(opponent, result.Position, result.Normal)
			end
		end
	end

	if shouldAutoReload then
		startReload(player, session)
	end
end)

ReloadWeapon.OnServerEvent:Connect(function(player)
	local session = playerDuel[player]
	if not session or session.Ended then return end
	if not startReload(player, session) then
		local data = session.Data[player]
		if data then
			pushReloadState(player, data.Reloading or false, 0, data.Weapon)
		end
	end
end)

-- ============ COUNTDOWN / COMBAT START ============

local function startCombat(session)
	if session.Ended then return end
	session.State = "Combat"
	for _, p in pairs(session.Players) do
		if p and p.Parent then
			PhaseChanged:FireClient(p, GameConfig.PHASE.PVP)
			TimerUpdate:FireClient(p, 0)
			Announcement:FireClient(p, "⚔ 開戰！")
		end
	end
end

local function abortSession(session, reason)
	if session.Ended then return end
	session.Ended = true
	session.State = "Ended"
	for _, p in pairs(session.Players) do
		if p and p.Parent then
			Announcement:FireClient(p, reason or "1v1 對決已取消")
		end
	end
	cleanupSession(session)
end

local function startCountdown(session)
	session.State = "Countdown"
	local arena = session.Arena
	local spawnA = arena and arena:FindFirstChild("SpawnA")
	local spawnB = arena and arena:FindFirstChild("SpawnB")
	if not arena or not spawnA or not spawnB then
		warn("[DuelService] Missing arena/spawns for map " .. tostring(session.MapId))
		abortSession(session, "地圖載入失敗，對決已取消")
		return
	end

	local function place(player, spawnPart)
		if not player or not player.Character then return end
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		hrp.CFrame = spawnPart.CFrame + Vector3.new(0, 3, 0)

		local data = session.Data[player]
		data.HP = data.MaxHP
		HealthUpdate:FireClient(player, data.HP, data.MaxHP)
		AmmoUpdate:FireClient(player, data.Ammo, data.ReserveAmmo,
			(GameConfig.WEAPONS[data.Weapon] and GameConfig.WEAPONS[data.Weapon].MagSize) or 0)

		if _G.MatchManager then
			_G.MatchManager.attachWeapon(player, data.Weapon)
		end
		EquipWeapon:FireClient(player, data.Weapon)
		-- Reuses the exact phase string CameraController already keys off of
		-- to lock first-person + crosshair for arena combat (see #99-106 of
		-- CameraController.lua) and to clear localEliminated for the new duel.
		PhaseChanged:FireClient(player, GameConfig.PHASE.PVE)
	end

	place(session.Players.A, spawnA)
	place(session.Players.B, spawnB)

	local mapDef = DuelMaps.get(session.MapId)
	for _, p in pairs(session.Players) do
		if p and p.Parent then
			Announcement:FireClient(p, "地圖：" .. (mapDef and mapDef.Name or session.MapId))
			PhaseChanged:FireClient(p, GameConfig.PHASE.PVP_WARNING)
		end
	end

	task.spawn(function()
		for t = GameConfig.DUEL.COUNTDOWN, 1, -1 do
			if session.Ended then return end
			for _, p in pairs(session.Players) do
				if p and p.Parent then
					TimerUpdate:FireClient(p, t)
				end
			end
			task.wait(1)
		end
		if session.Ended then return end
		startCombat(session)
	end)
end

-- ============ MAP VOTE ============

local function resolveMapAndStartCountdown(session)
	if session.State ~= "Voting" or session.Ended then return end
	session.State = "Resolving"

	local counts = {}
	for _, mapId in pairs(session.Votes) do
		counts[mapId] = (counts[mapId] or 0) + 1
	end
	local chosenId = DuelMaps.resolveVote(counts) or DuelMaps.defaultId()
	if not chosenId then
		abortSession(session, "沒有可用地圖，對決已取消")
		return
	end
	session.MapId = chosenId

	local arena = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("DuelArenas")
		and workspace.LastZone.DuelArenas:FindFirstChild(chosenId)
	session.Arena = arena

	local mapDef = DuelMaps.get(chosenId)
	for _, p in pairs(session.Players) do
		if p and p.Parent then
			DuelVoteClosed:FireClient(p, { MapId = chosenId, MapName = mapDef and mapDef.Name or chosenId })
		end
	end

	startCountdown(session)
end

DuelVoteCast.OnServerEvent:Connect(function(player, mapId)
	local session = playerDuel[player]
	-- Rejects outsider votes (no session), late votes (not in Voting state),
	-- and duplicate votes (first vote per player is locked in).
	if not session or session.Ended or session.State ~= "Voting" then return end
	if session.Votes[player] then return end
	if type(mapId) ~= "string" or not DuelMaps.isValid(mapId) then return end

	session.Votes[player] = mapId

	local a, b = session.Players.A, session.Players.B
	if session.Votes[a] and session.Votes[b] then
		resolveMapAndStartCountdown(session)
	end
end)

local function startVotePhase(session)
	session.State = "Voting"
	local options = DuelMaps.list()
	for _, p in pairs(session.Players) do
		if p and p.Parent then
			DuelVoteOpen:FireClient(p, options, GameConfig.DUEL.VOTE_SECONDS)
			Announcement:FireClient(p, "配對成功！請投票選擇地圖")
		end
	end

	task.delay(GameConfig.DUEL.VOTE_SECONDS, function()
		if session.State == "Voting" and not session.Ended then
			resolveMapAndStartCountdown(session)
		end
	end)
end

-- ============ PAIRING / QUEUE ============

local function createSession(playerA, playerB)
	local session = {
		Players = { A = playerA, B = playerB },
		Votes = {},
		MapId = nil,
		Arena = nil,
		State = "Voting",
		Ended = false,
		Data = {},
	}

	for _, p in ipairs({ playerA, playerB }) do
		local equipped = (_G.ShopService and _G.ShopService.getPrimary(p)) or GameConfig.STARTER_WEAPONS[1]
		if not GameConfig.WEAPONS[equipped] then
			equipped = GameConfig.STARTER_WEAPONS[1]
		end
		local cfg = GameConfig.WEAPONS[equipped]
		local magSize = cfg.MagSize or 0
		session.Data[p] = {
			HP = GameConfig.MAX_HP,
			MaxHP = GameConfig.MAX_HP,
			Ammo = magSize,
			ReserveAmmo = magSize * GameConfig.STARTING_RESERVE_MAGAZINES,
			Weapon = equipped,
			Eliminated = false,
			Reloading = false,
			ReloadToken = 0,
			ReloadEndsAt = 0,
		}
		playerDuel[p] = session
	end

	table.insert(sessions, session)
	startVotePhase(session)
end

-- Public read-only check so other systems (currently only MatchManager,
-- via the compatibility guard added to startMatch/teleportToArena) can avoid
-- double-processing a player who is mid-duel. DuelService never calls into
-- MatchManager beyond this — the guard lives on the MatchManager side.
function DuelService.isDueling(player)
	return playerDuel[player] ~= nil
end

-- Read-only check: is this player currently absorbed into a live 12-player
-- match (has non-eliminated MatchManager.playerData)? Used both when a
-- player tries to join the queue, and again right before pairing — a player
-- can sit in `queue` (unpaired) for an arbitrary amount of time, and a 12p
-- match can start while they wait (isDueling() only protects them from
-- MatchManager once they're actually paired into a session). Re-checking at
-- pairing time closes that gap: it's the only way to guarantee a session is
-- never created for someone MatchManager has already absorbed as a live
-- participant (which would otherwise double-process their FireWeapon/Reload
-- the same way an unguarded match-start race would).
local function isBlockedByMatch(player)
	local mm = _G.MatchManager
	if not (mm and mm.MatchRunning) then return false end
	local d = mm.getPlayerData and mm.getPlayerData(player)
	return d ~= nil and not d.Eliminated
end

function DuelService.queueToggle(player)
	if not player or not player.Parent then return end

	if playerDuel[player] then
		Announcement:FireClient(player, "你正在進行 1v1 對決中")
		return
	end

	local now = tick()
	if (lastQueueToggle[player] or 0) + QUEUE_DEBOUNCE > now then return end
	lastQueueToggle[player] = now

	-- Soft-block (mirrors TrainingService): don't pull an active 12-player
	-- match participant into the duel queue.
	if isBlockedByMatch(player) then
		Announcement:FireClient(player, "比賽進行中，無法加入 1v1 佇列")
		return
	end

	for i, qp in ipairs(queue) do
		if qp == player then
			table.remove(queue, i)
			Announcement:FireClient(player, "已離開 1v1 佇列")
			updateQueueSign()
			return
		end
	end

	table.insert(queue, player)
	Announcement:FireClient(player, "已加入 1v1 佇列，等待對手...")
	updateQueueSign()

	if #queue >= 2 then
		local a = table.remove(queue, 1)
		local b = table.remove(queue, 1)
		updateQueueSign()

		-- Re-validate both at the moment of pairing, not just at their own
		-- original toggle-in — a 12p match can have started (and silently
		-- absorbed either of them as a live participant) while they sat in
		-- the raw queue waiting for a 2nd opponent.
		local aOk = a and a.Parent and not isBlockedByMatch(a)
		local bOk = b and b.Parent and not isBlockedByMatch(b)

		if aOk and bOk then
			createSession(a, b)
		else
			if a and a.Parent and not aOk then
				Announcement:FireClient(a, "比賽進行中，1v1 配對已取消")
			end
			if b and b.Parent and not bOk then
				Announcement:FireClient(b, "比賽進行中，1v1 配對已取消")
			end
			-- Requeue whichever side is still a valid, connected candidate.
			if bOk then table.insert(queue, 1, b) end
			if aOk then table.insert(queue, 1, a) end
			updateQueueSign()
		end
	end
end

-- ============ PORTAL WIRING ============

task.spawn(function()
	local lz = workspace:WaitForChild("LastZone", 30)
	if not lz then return end
	local lobby = lz:WaitForChild("Lobby", 10)
	if not lobby then return end
	local portal = lobby:WaitForChild("DuelQueuePortal", 10)
	if not portal then return end

	portal.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then DuelService.queueToggle(player) end
	end)

	print("[DuelService] DuelQueuePortal wired")
end)

-- ============ 12-PLAYER MATCH INTERFERENCE GUARD ============
-- MatchManager.startMatch/teleportToArena/resetToLobby now skip any player
-- DuelService.isDueling() reports true for (see the compatibility guard
-- added to MatchManager.lua), so an already-paired duel — voting, counting
-- down, or fighting — runs fully isolated from the 12p match and needs no
-- special handling here. The only thing NOT protected by that guard is the
-- unpaired queue (players waiting for a 2nd opponent have no session yet,
-- so MatchManager has no way to know they're "spoken for") — clear that out
-- so a 12p match starting doesn't leave a stale queue entry that pops a
-- vote UI on someone who just got swept into the 12-player arena.
task.spawn(function()
	local mm
	for _ = 1, 50 do
		mm = _G.MatchManager
		if mm and mm.PhaseChangedServer then break end
		task.wait(0.1)
	end
	if not mm or not mm.PhaseChangedServer then return end

	mm.PhaseChangedServer:Connect(function(phase)
		if phase ~= GameConfig.PHASE.PVE then return end

		for _, p in ipairs(queue) do
			if p and p.Parent then
				Announcement:FireClient(p, "12 人對戰已開始，1v1 佇列已清空")
			end
		end
		queue = {}
		updateQueueSign()
	end)
end)

-- ============ LIFECYCLE ============

Players.PlayerRemoving:Connect(function(player)
	for i, qp in ipairs(queue) do
		if qp == player then
			table.remove(queue, i)
			updateQueueSign()
			break
		end
	end
	lastQueueToggle[player] = nil
	lastFireTick[player] = nil

	local session = playerDuel[player]
	if session and not session.Ended then
		-- Disconnect resolves as a forfeit — exactly once, same idempotency
		-- guard (session.Ended) as a normal elimination.
		local opponent = getOpponent(session, player)
		session.Ended = true
		session.State = "Ended"
		playerDuel[player] = nil
		if opponent and opponent.Parent then
			Announcement:FireClient(opponent, "對手已離線 — 你獲勝！")
			PhaseChanged:FireClient(opponent, GameConfig.PHASE.MATCH_END)
			TimerUpdate:FireClient(opponent, 0)
		end
		task.delay(1, function()
			cleanupSession(session)
		end)
	end
end)

-- Respawn-safety: if a duelist's character actually respawns mid-duel (e.g.
-- real fall damage killing the Humanoid — duel HP is tracked virtually, same
-- as MatchManager's 12p players), treat it as an elimination instead of
-- leaving orphaned session state. Teleports performed by this service itself
-- reposition the existing character and never trigger CharacterAdded, so this
-- only fires on genuine respawns.
local function bindRespawnHook(player)
	player.CharacterAdded:Connect(function()
		local session = playerDuel[player]
		if not session or session.Ended then return end
		task.wait(0.2)
		if playerDuel[player] == session and not session.Ended then
			DuelService._eliminate(session, player, nil)
		end
	end)
end
Players.PlayerAdded:Connect(bindRespawnHook)
for _, p in ipairs(Players:GetPlayers()) do bindRespawnHook(p) end

_G.DuelService = DuelService
return DuelService
