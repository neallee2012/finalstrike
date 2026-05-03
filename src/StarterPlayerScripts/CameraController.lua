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

-- Transient enforcement window after exiting first-person. The built-in
-- CameraScript clings to LockCenter for several frames as it transitions out
-- of LockFirstPerson — without this window, MouseBehavior re-locks itself
-- and shop / spectate become unusable. After the window expires we stop
-- enforcing so right-click drag and click-to-move work normally (#14, #15).
local releaseEnforceUntil = 0

-- Crosshair visibility — only show when actually aiming in first-person.
-- Hidden in lobby (no shooting context), spectator, and while a menu is open.
local function setCrosshairVisible(visible)
	local pg = player:FindFirstChild("PlayerGui")
	local cross = pg and pg:FindFirstChild("FinalStrikeCrosshair")
	if cross then cross.Enabled = visible end
end

local function applyCameraState()
	if shouldLock() then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		UserInputService.MouseIconEnabled = false
		releaseEnforceUntil = 0
		setCrosshairVisible(true)
	else
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		-- Hold Default for ~1s so CameraScript's transition can't re-lock us
		releaseEnforceUntil = tick() + 1.0
		setCrosshairVisible(false)
	end
end

-- RenderStepped enforcement, three branches:
--   1. shouldLock() (in-arena, no UI open): keep LockCenter — CameraScript can
--      release it during transitions, so we have to clamp it back.
--   2. interactive UI open (shop/quest): keep Default for as long as the panel
--      is open, otherwise CameraScript creeps it back to LockCenter and the
--      player can't click buttons after a few seconds (#14, #15).
--   3. lobby/spectate (no UI, no lock): only enforce Default during the brief
--      transition window (releaseEnforceUntil); afterwards release entirely so
--      Roblox's CameraScript can manage right-click drag and click-to-move.
RunService.RenderStepped:Connect(function()
	if shouldLock() then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	elseif isAnyInteractiveUIOpen() or tick() < releaseEnforceUntil then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
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
