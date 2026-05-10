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
--   - Spawns 6 stationary dummies on first match-start of a session
--     (delegated to NPCSystem.spawnTrainingDummies).
--
-- The training arena bypasses the match phase machine entirely. PvP/PvE
-- state and rewards do not apply here — players can fire freely, but no
-- coins are earned and no quest progress recorded (TrainingService does
-- NOT route through awardCoins / recordQuest).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local TrainingService = {}

-- Tracks players currently inside the training arena (set semantics).
-- Used to guard against re-entering the picker UI on dummy hits and to
-- skip lobby-trigger work when already inside.
local inTraining = {}

-- Touch debounce: prevents the portal pad from firing twice in rapid
-- succession when multiple body parts contact the pad on the same step.
local lastEnterTick = {}  -- [player] = tick()
local lastExitTick = {}

local PORTAL_DEBOUNCE = 1.5  -- seconds; long enough to cover the teleport itself

local function teleportPlayerTo(player, position)
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	hrp.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	return true
end

-- ============ ENTER ============
local function onPortalTouched(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end
	if inTraining[player] then return end
	if (lastEnterTick[player] or 0) + PORTAL_DEBOUNCE > tick() then return end
	lastEnterTick[player] = tick()

	-- Refuse entry if a real match is running — prevents accidentally yanking
	-- a player out of mid-match into the practice zone.
	local mm = _G.MatchManager
	if mm and mm.MatchRunning then return end

	local arena = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("TrainingArena")
	local entry = arena and arena:FindFirstChild("TrainingEntry")
	if not entry then
		warn("[TrainingService] TrainingArena.TrainingEntry not found")
		return
	end

	if not teleportPlayerTo(player, entry.Position) then return end
	inTraining[player] = true
	-- Spawn dummies on first entry of the session (idempotent inside NPCSystem)
	if _G.NPCSystem and _G.NPCSystem.spawnTrainingDummies then
		_G.NPCSystem.spawnTrainingDummies()
	end
	events.EnterTrainingArena:FireClient(player)
	print(string.format("[TrainingService] %s entered training arena", player.Name))
end

-- ============ EXIT ============
local function onExitTouched(hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end
	if not inTraining[player] then return end
	if (lastExitTick[player] or 0) + PORTAL_DEBOUNCE > tick() then return end
	lastExitTick[player] = tick()

	local lobby = workspace:FindFirstChild("LastZone")
		and workspace.LastZone:FindFirstChild("Lobby")
	local lobbySpawn = lobby and lobby:FindFirstChild("LobbySpawn")
	if not lobbySpawn then
		warn("[TrainingService] LobbySpawn not found")
		return
	end

	if not teleportPlayerTo(player, lobbySpawn.Position) then return end
	inTraining[player] = nil
	events.ExitTrainingArena:FireClient(player)
	print(string.format("[TrainingService] %s exited training arena", player.Name))
end

-- ============ WEAPON SELECT ============
-- Client picker fires SelectTrainingWeapon with any weapon name; we don't
-- check ownership (this is training, every gun is available). MatchManager
-- handles the actual model swap + ammo/ID broadcast.
events:WaitForChild("SelectTrainingWeapon").OnServerEvent:Connect(function(player, weaponName)
	if type(weaponName) ~= "string" then return end
	if not inTraining[player] then return end  -- ignore picker outside training
	if not GameConfig.WEAPONS[weaponName] then return end

	local mm = _G.MatchManager
	if not mm then return end

	-- Make sure the player has a playerData record for the FireWeapon path's
	-- ammo/ID checks. Reuse initPlayerData (which uses ShopService's primary
	-- as fallback), then immediately override Weapon to the picked one.
	if not mm.getPlayerData(player) then
		mm.initPlayerData(player)
	end
	local data = mm.getPlayerData(player)
	if data then
		data.Weapon = weaponName
		data.Eliminated = false  -- clear any leftover eliminated state
		local cfg = GameConfig.WEAPONS[weaponName]
		data.Ammo = (cfg and cfg.MagSize) or data.Ammo
		-- Update HUD ammo display (max from MagSize so reload reads sanely)
		events.AmmoUpdate:FireClient(player, data.Ammo, (cfg and cfg.MagSize) or data.Ammo)
	end
	mm.attachWeapon(player, weaponName)
	events.EquipWeapon:FireClient(player, weaponName)  -- WeaponClient updates currentWeapon
	print(string.format("[TrainingService] %s picked %s", player.Name, weaponName))
end)

-- ============ PORTAL WIRING ============
-- Wait for MapBuilder to finish (it auto-runs on server start, but we don't
-- have a finish signal — poll for the pads' existence with a timeout).
task.spawn(function()
	local lz = workspace:WaitForChild("LastZone", 30)
	if not lz then return end

	local lobby = lz:WaitForChild("Lobby", 10)
	local trainingArena = lz:WaitForChild("TrainingArena", 10)
	if not lobby or not trainingArena then
		warn("[TrainingService] Lobby or TrainingArena folder missing")
		return
	end

	local portal = lobby:WaitForChild("TrainingArenaPortal", 10)
	local exitPad = trainingArena:WaitForChild("TrainingExitPad", 10)
	if portal then portal.Touched:Connect(onPortalTouched) end
	if exitPad then exitPad.Touched:Connect(onExitTouched) end

	print("[TrainingService] Portals wired (enter + exit)")
end)

-- ============ LIFECYCLE ============
Players.PlayerRemoving:Connect(function(player)
	inTraining[player] = nil
	lastEnterTick[player] = nil
	lastExitTick[player] = nil
end)

_G.TrainingService = TrainingService
return TrainingService
