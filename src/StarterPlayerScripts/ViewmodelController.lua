-- ViewmodelController.lua (StarterPlayerScripts)
-- Client-side, non-physical third-person R15 weapon hold.
--
-- Every client applies the pose to every visible player so Transform state does
-- not need server replication. FirstPersonViewmodel owns the local camera rig.
-- The physical server solver stays disabled because it moved RootParts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local R15Pose = require(ReplicatedStorage:WaitForChild("R15Pose"))
local ReloadStateChanged = ReplicatedStorage:WaitForChild("GameEvents")
	:WaitForChild("ReloadStateChanged")

local RELOAD_ATTRIBUTE = "FinalStrikeReloading"
local HOLD_BLEND_TIME = 0.12
local HOLD_RESUME_DELAY = 0.1
local POSE_JOINT_NAMES = {
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
}
local playerStates = {}
local localReloadActive = false

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function findTwoHandedTool(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local handle = child:FindFirstChild("Handle")
			local leftGrip = handle and handle:FindFirstChild("LeftGrip")
			if leftGrip and leftGrip:IsA("Attachment") then
				return child
			end
		end
	end
	return nil
end

local function stopHold(characterState, destroy)
	characterState.RefreshGeneration += 1
	if not characterState.PoseController then return end

	if destroy then
		characterState.PoseController:Destroy()
		characterState.PoseController = nil
	else
		characterState.PoseController:Stop()
	end
end

local function refreshHold(owner, characterState)
	local character = characterState.Character
	if characterState.Dead or character.Parent == nil then
		stopHold(characterState, true)
		return
	end

	local reloading = owner:GetAttribute(RELOAD_ATTRIBUTE) == true
		or (owner == player and localReloadActive)
	if reloading or not findTwoHandedTool(character) then
		stopHold(characterState, false)
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		stopHold(characterState, true)
		return
	end

	if not characterState.PoseController then
		local controller = R15Pose.new(character)
		if not controller:IsSupported() then
			controller:Destroy()
			if not characterState.UnsupportedWarningPending then
				characterState.UnsupportedWarningPending = true
				task.delay(1, function()
					characterState.UnsupportedWarningPending = false
					if not characterState.Dead
						and characterState.Character.Parent
						and not characterState.PoseController
						and findTwoHandedTool(characterState.Character)
					then
						warn("Two-hand pose requires an R15 character with both shoulder joints")
					end
				end)
			end
			return
		end
		characterState.PoseController = controller
	end

	characterState.PoseController:SetPersistentPose(R15Pose.Poses.TwoHandHold, HOLD_BLEND_TIME)
end

local function scheduleRefresh(owner, characterState, delaySeconds)
	characterState.RefreshGeneration += 1
	local generation = characterState.RefreshGeneration
	task.delay(delaySeconds or 0, function()
		if characterState.RefreshGeneration == generation then
			refreshHold(owner, characterState)
		end
	end)
end

local function cleanupCharacterState(characterState)
	if not characterState then return end
	characterState.Dead = true
	stopHold(characterState, true)
	disconnectAll(characterState.Connections)
end

local function watchCharacter(owner, ownerState, character)
	cleanupCharacterState(ownerState.CharacterState)
	if owner == player then
		localReloadActive = owner:GetAttribute(RELOAD_ATTRIBUTE) == true
	end

	local characterState = {
		Character = character,
		Connections = {},
		PoseController = nil,
		RefreshGeneration = 0,
		Dead = false,
	}
	ownerState.CharacterState = characterState

	local function bindHumanoid(child)
		if not child:IsA("Humanoid") or characterState.Humanoid then return end
		characterState.Humanoid = child
		table.insert(characterState.Connections, child.Died:Connect(function()
			characterState.Dead = true
			stopHold(characterState, true)
		end))
	end
	for _, child in ipairs(character:GetChildren()) do
		bindHumanoid(child)
	end

	table.insert(characterState.Connections, character.ChildAdded:Connect(function(child)
		bindHumanoid(child)
		if child:IsA("Tool") or child:IsA("Humanoid") then
			scheduleRefresh(owner, characterState)
		end
	end))
	table.insert(characterState.Connections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			scheduleRefresh(owner, characterState)
		end
	end))
	table.insert(characterState.Connections, character.DescendantAdded:Connect(function(descendant)
		local isPoseJoint = POSE_JOINT_NAMES[descendant.Name]
			and (descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint"))
		if descendant.Name == "LeftGrip" or isPoseJoint then
			if isPoseJoint and characterState.PoseController then
				stopHold(characterState, true)
			end
			scheduleRefresh(owner, characterState)
		end
	end))
	table.insert(characterState.Connections, character.AncestryChanged:Connect(function(_, parent)
		if not parent then cleanupCharacterState(characterState) end
	end))

	refreshHold(owner, characterState)
end

local function watchPlayer(owner)
	if playerStates[owner] then return end

	local ownerState = {
		Connections = {},
		CharacterState = nil,
	}
	playerStates[owner] = ownerState

	table.insert(ownerState.Connections, owner.CharacterAdded:Connect(function(character)
		watchCharacter(owner, ownerState, character)
	end))
	table.insert(ownerState.Connections, owner.CharacterRemoving:Connect(function(character)
		local characterState = ownerState.CharacterState
		if characterState and characterState.Character == character then
			cleanupCharacterState(characterState)
			ownerState.CharacterState = nil
		end
	end))
	table.insert(ownerState.Connections, owner:GetAttributeChangedSignal(RELOAD_ATTRIBUTE):Connect(function()
		local characterState = ownerState.CharacterState
		if not characterState then return end

		if owner:GetAttribute(RELOAD_ATTRIBUTE) == true then
			stopHold(characterState, false)
			return
		end

		scheduleRefresh(
			owner,
			characterState,
			owner == player and 0 or HOLD_RESUME_DELAY
		)
	end))

	if owner.Character then
		watchCharacter(owner, ownerState, owner.Character)
	end
end

local function unwatchPlayer(owner)
	local ownerState = playerStates[owner]
	if not ownerState then return end
	cleanupCharacterState(ownerState.CharacterState)
	disconnectAll(ownerState.Connections)
	playerStates[owner] = nil
end

for _, owner in ipairs(Players:GetPlayers()) do
	watchPlayer(owner)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(unwatchPlayer)

-- Stop immediately in the same turn WeaponClient begins its authoritative
-- reload. The replicated Player attribute handles cross-client resume.
ReloadStateChanged.OnClientEvent:Connect(function(active)
	localReloadActive = active == true
	local ownerState = playerStates[player]
	local characterState = ownerState and ownerState.CharacterState
	if not characterState then return end
	if localReloadActive then
		stopHold(characterState, false)
	else
		scheduleRefresh(player, characterState)
	end
end)
