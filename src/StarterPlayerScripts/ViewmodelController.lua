-- ViewmodelController.lua (StarterPlayerScripts)
-- First-person quality-of-life for the FPS view (#5):
--   1. Force arms visible — LockFirstPerson hides body parts via
--      LocalTransparencyModifier; we re-set arms to 0 each frame so the
--      player sees their own hands holding the gun.
--   2. LeftHand IK — when a Tool with a LeftGrip attachment is equipped, an
--      IKControl pins the LeftHand to that attachment so both hands appear
--      to grip the weapon (Pistol/Knife are single-handed and skip this).
--
-- Issue #39 hardening: jump-animation tracks (LeftArm) used to win against
-- IKControl, popping the off-hand off the weapon mid-jump even with
-- IKControl.Priority=1000. Three reinforcements:
--   a) SmoothTime=0 so IK is instant (no smoothing lag during fast state
--      transitions like Running → Jumping).
--   b) HumanoidStateChanged hook — when the player enters Jumping /
--      Freefall, force-rebuild the IK (toggle Enabled false→true) so
--      the constraint solver re-runs against the current animation pose.
--   c) Per-frame defensive: while airborne, walk through playing
--      AnimationTracks and damp the weight of any track named with
--      "Jump"/"Fall" so the LeftArm channel can't fight the IK.
-- Pistol/Knife (single-handed weapons, no LeftGrip Attachment) are
-- unaffected — they take the early-return path.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ARM_PARTS = {
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
}

-- Animation tracks whose default behavior animates the LeftArm chain enough
-- to pull the off-hand off the weapon. We damp these to ~zero weight only
-- while the humanoid is Jumping/Freefall — landing restores normal weights.
-- Heuristic by name; Roblox doesn't expose which Motor6Ds an animation
-- targets via the public API. Conservative — won't catch custom anims.
local function isAirborneTrack(trackName)
	local n = string.lower(trackName or "")
	return n:find("jump") or n:find("fall") or n:find("air")
end

local function ensureLeftHandIK(char, tool)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	-- Tear down any previous IK before setting up new one
	local existing = humanoid:FindFirstChild("LeftHandIK")
	if existing then existing:Destroy() end

	if not tool then return nil end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return nil end
	local leftGrip = handle:FindFirstChild("LeftGrip")
	if not leftGrip or not leftGrip:IsA("Attachment") then return nil end

	local leftHand = char:FindFirstChild("LeftHand")
	-- (#39 round 2) ChainRoot was LeftUpperArm — only 2 joints (elbow + wrist),
	-- not enough reach to bring LeftHand across the body to LeftGrip (which
	-- sits ~1 stud forward from RightHand on the Handle). Anatomically the
	-- shoulder has to rotate too. UpperTorso gives the IK solver 3 joints:
	-- LeftShoulder + LeftElbow + LeftWrist. Now the off-hand can actually
	-- reach the LeftGrip Attachment.
	local upperTorso = char:FindFirstChild("UpperTorso")
	if not leftHand or not upperTorso then return nil end

	local ik = Instance.new("IKControl")
	ik.Name = "LeftHandIK"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upperTorso
	ik.EndEffector = leftHand
	ik.Target = leftGrip  -- IKControl accepts Attachment targets
	ik.Weight = 1.0
	ik.SmoothTime = 0     -- (#39) instant solve; default 0.1s smoothing lagged through jump
	-- High Priority so the jump animation's LeftArm tracks don't override the
	-- grip pose — without this, hand pops off the gun mid-jump.
	ik.Priority = 1000
	ik.Parent = humanoid

	print(string.format(
		"[ViewmodelController] LeftHandIK active: tool=%s ChainRoot=%s Target=%s",
		tool.Name, upperTorso.Name, leftGrip:GetFullName()
	))
	return ik
end

-- (#39) Force the IK to re-solve by briefly toggling Enabled. Roblox's IK
-- solver re-evaluates ChainRoot/Target relationships fresh on enable, which
-- helps when an animation transition has put the chain into a pose that
-- the solver got "stuck" on.
local function reassertIK(humanoid)
	local ik = humanoid:FindFirstChild("LeftHandIK")
	if not ik then return end
	ik.Enabled = false
	task.defer(function()
		if ik.Parent then ik.Enabled = true end
	end)
end

-- (#39) While airborne, damp the weight of any LeftArm-affecting playing
-- animation track so it can't fight the IK. We don't Stop() the track —
-- the body still needs to look like it's jumping; we just want the LeftArm
-- channel to defer to IK. Restored on landing.
local function dampAirborneTracks(humanoid)
	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		if isAirborneTrack(track.Name) then
			-- Tiny weight, not zero — Stop()/Weight=0 can break Roblox's
			-- internal animation blending state. Near-zero is safe.
			track:AdjustWeight(0.05, 0.05)
		end
	end
end

local function restoreTracks(humanoid)
	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		if isAirborneTrack(track.Name) then
			track:AdjustWeight(1.0, 0.1)
		end
	end
end

local function watchCharacter(char)
	-- Cache arm refs once
	local arms = {}
	for _, name in ipairs(ARM_PARTS) do
		local p = char:WaitForChild(name, 5)
		if p then table.insert(arms, p) end
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Force arms visible every frame in first-person.
	local conn = RunService.RenderStepped:Connect(function()
		if player.CameraMode == Enum.CameraMode.LockFirstPerson then
			for _, p in ipairs(arms) do
				p.LocalTransparencyModifier = 0
			end
		end
	end)
	-- Disconnect when this character despawns
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then conn:Disconnect() end
	end)

	-- Tool equip/unequip → rebuild IKControl
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			task.wait(0.1)  -- let server's grip weld settle before resolving attachments
			ensureLeftHandIK(char, c)
		end
	end)
	char.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then ensureLeftHandIK(char, nil) end
	end)

	-- Apply to any tool already equipped on character init (e.g. respawn into match)
	local existingTool = char:FindFirstChildOfClass("Tool")
	if existingTool then
		task.wait(0.1)
		ensureLeftHandIK(char, existingTool)
	end

	-- (#39) Re-assert IK + damp jump tracks when humanoid enters airborne states.
	-- Restore weights when grounded.
	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping
			or newState == Enum.HumanoidStateType.Freefall then
			reassertIK(humanoid)
			dampAirborneTracks(humanoid)
		elseif newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics then
			restoreTracks(humanoid)
		end
	end)
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)
