-- CameraController.lua (StarterPlayerScripts)
-- Locks first-person + center-mouse during arena phases (PvE / PvPWarning / PvP).
-- Releases to third-person free mouse in Lobby / MatchEnd.
--
-- Also temporarily releases the mouse cursor while shop/quest UI panels are
-- open, so the player can actually click their buttons in first-person mode.
-- Without this, MouseBehavior=LockCenter swallows clicks.
--
-- Fixes #5.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- Names of GUIs that, when Enabled, should release the cursor for clicking.
-- ScreenGui.Name on those LocalScripts.
local INTERACTIVE_UIS = {
	ShopUI = true,
	DailyQuestUI = true,
}

local inArena = false  -- set true on PvE/PvPWarning/PvP, false on Lobby/MatchEnd
local localEliminated = false  -- true after this player dies; cleared on next match start

local function isAnyInteractiveUIOpen()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return false end
	for _, gui in ipairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled and INTERACTIVE_UIS[gui.Name] then
			return true
		end
	end
	return false
end

local function shouldLock()
	-- Eliminated players spectate in third-person (#11). Phase still says PvP
	-- because the match continues — local elimination is tracked separately.
	return inArena and not localEliminated and not isAnyInteractiveUIOpen()
end

local function applyCameraState()
	-- CameraMode is the visual trigger; mouse state is enforced per-frame below
	-- because the built-in CameraScript can re-lock LockCenter when CameraMode
	-- transitions through LockFirstPerson, ignoring single-shot Default sets.
	if shouldLock() then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseIconEnabled = false
	else
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
	end
end

-- Every frame, force MouseBehavior to match shouldLock(). Cheap (one comparison
-- + occasional assignment) and reliable against CameraScript's overrides.
RunService.RenderStepped:Connect(function()
	local target = shouldLock() and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	if UserInputService.MouseBehavior ~= target then
		UserInputService.MouseBehavior = target
	end
end)

-- Phase changes drive arena state. PvE start of a new match clears the
-- local-elimination flag so the player drops back into first-person.
events:WaitForChild("PhaseChanged").OnClientEvent:Connect(function(phase)
	inArena = (phase == "PvE" or phase == "PvPWarning" or phase == "PvP")
	if phase == "PvE" then
		localEliminated = false
	end
	applyCameraState()
end)

-- Server fires PlayerEliminated to all clients with the victim name; we only
-- care if it's us — flip to spectator camera for the rest of the match (#11).
events:WaitForChild("PlayerEliminated").OnClientEvent:Connect(function(victimName)
	if victimName == player.Name then
		localEliminated = true
		applyCameraState()
	end
end)

-- Watch for shop/quest UI toggles so we release/recapture the mouse correctly.
-- Connecting per ScreenGui (not the whole InputService) keeps the listener cheap.
local function watchGui(gui)
	if gui:IsA("ScreenGui") and INTERACTIVE_UIS[gui.Name] then
		gui:GetPropertyChangedSignal("Enabled"):Connect(applyCameraState)
	end
end

local pg = player:WaitForChild("PlayerGui")
for _, gui in ipairs(pg:GetChildren()) do watchGui(gui) end
pg.ChildAdded:Connect(watchGui)

-- Apply initial state (we boot in lobby — third-person, free mouse)
applyCameraState()
