-- WeaponMeshes.lua (ServerStorage/ModuleScript)
-- Build weapon Tools from shared procedural models. Each Tool has:
--   - PrimaryPart "Handle" (welded to player's RightHand on equip)
--   - Attachment "Muzzle" at the end of the barrel (used as raycast/VFX origin)
-- Visual style matches the dark cinematic theme: dark gray/black bodies with
-- subtle accent neon for visibility against the cinematic backdrop.
--
-- WeaponVisuals lives in ReplicatedStorage so the shop's ViewportFrames and
-- the server-held Tool always use the exact same model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponVisuals = require(ReplicatedStorage:WaitForChild("WeaponVisuals"))

local WeaponMeshes = {}
local MESH_FORWARD_ROTATION = CFrame.Angles(0, math.rad(180), 0)

-- Local position of the LeftGrip attachment (relative to Handle) per weapon Type.
-- ViewmodelController consumes these attachments on every client to select the
-- non-physical TwoHandHold pose. The old server solver stays disabled (#56);
-- attachLeftHandIK only normalizes RightGrip orientation. Nil entries (Pistol,
-- Knife) mean "single-handed".
--
-- Avatar-Joint-Upgrade rigs have a hard reach limit on the left arm:
-- shoulder→LeftHand-center fully extended ≈ 1.86 studs. With the old
-- forward-grip Tool.Grip (CFrame.new(0, 0.45, 0)) the LeftShoulder is
-- ~3.81 studs from the gun's grip area — a 2-stud deficit no IK or
-- physics constraint can solve (#51 / Studio measurement). Two
-- changes here close that gap geometrically instead of solver-side:
--   1) tool.Grip below pulls the gun inward (+X 0.4) and back (-Z 0.4)
--      so its grip sits within left-arm reach.
--   2) LEFT_GRIP_OFFSET targets the gun's left side (negative X) and
--      slightly behind/above the Handle origin — where the left hand
--      naturally lands once the gun is pulled inward.
-- Verified in Studio: 16-sample steady-state across all NPCs settles
-- at LH→LG ≈ 0.46 studs (PASS, < 0.5 acceptance criterion).
local REAR_TWO_HAND_GRIP_OFFSET = Vector3.new(-1.0, -0.1, 0.3)
local LEFT_GRIP_OFFSET = {
	SMG     = REAR_TWO_HAND_GRIP_OFFSET,
	Rifle   = REAR_TWO_HAND_GRIP_OFFSET,
	Shotgun = REAR_TWO_HAND_GRIP_OFFSET,
	Sniper  = REAR_TWO_HAND_GRIP_OFFSET,
	Minigun = REAR_TWO_HAND_GRIP_OFFSET,
}

local WEAPON_LEFT_GRIP_OFFSET = {
	["Wraith Longshot"] = Vector3.new(0.3, -0.1, -0.3),
}

local WEAPON_GRIP = {
	["Wraith Longshot"] = CFrame.new(
		-0.208078682, -0.628678381, -0.911342144,
		-0.275695592, -0.612808824, 0.740579069,
		-0.842862010, 0.524521172, 0.120254286,
		-0.462142259, -0.591052413, -0.661121428
	),
}

-- Public: build(weaponName) -> Tool (Handle is the BasePart, Muzzle is an
-- Attachment on the Handle). Wrapping as a Tool lets Roblox's built-in grip
-- system handle the hand pose; we set Tool.Grip so the player's hand sits at
-- the top of the grip with barrel pointing forward.
-- Returns nil for unknown weapon names or weapons with no Style builder.
function WeaponMeshes.build(weaponName)
	local cfg = GameConfig.WEAPONS[weaponName]
	if not cfg then return nil end
	local model = WeaponVisuals.buildModel(weaponName, cfg)
	if not model then return nil end
	local handle = model:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end

	-- Mark two-handed weapons for the client-side, non-physical hold pose.
	local leftGripOffset = WEAPON_LEFT_GRIP_OFFSET[weaponName]
		or LEFT_GRIP_OFFSET[cfg.Type]
	if leftGripOffset then
		local leftGrip = Instance.new("Attachment")
		leftGrip.Name = "LeftGrip"
		leftGrip.Position = leftGripOffset
		leftGrip.Parent = handle
	end

	-- Convert Model wrapper to a Tool. Tool wants Handle as a direct child
	-- named "Handle". Move all the model's children up into the Tool.
	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true  -- prevent default click-to-activate
	for _, c in ipairs(model:GetChildren()) do
		c.Parent = tool
	end
	model:Destroy()

	local weaponGrip = WEAPON_GRIP[weaponName]
	if weaponGrip then
		tool.Grip = weaponGrip
	elseif leftGripOffset then
		-- Two-handed grip: pull the gun inward (+X 0.4) and toward the chest
		-- (-Z 0.4 from default) so the LeftGrip Attachment lands inside the
		-- left arm's 1.86-stud reach. Y=+0.45 unchanged (hand wraps the top
		-- of the grip). No rotation — barrel still points along Hand's -Z so
		-- aim/raycast direction is unchanged from prior versions.
		tool.Grip = CFrame.new(0.4, 0.45, -0.4) * MESH_FORWARD_ROTATION
	else
		-- Single-handed weapons do not need #51 reach compensation.
		tool.Grip = CFrame.new(0, 0.45, 0) * MESH_FORWARD_ROTATION
	end

	return tool
end

local LEFT_ARM_PARTS = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
}

local GRIP_ATTR = "FinalStrikeLeftGripDisabled"
local GRIP_WAS_ENABLED_ATTR = "FinalStrikeLeftGripWasEnabled"

local function isAnimationConstraint(instance)
	local ok, result = pcall(function()
		return instance:IsA("AnimationConstraint")
	end)
	return ok and result
end

local function animationConstraintTouchesLeftArm(constraint)
	if constraint.Parent and LEFT_ARM_PARTS[constraint.Parent.Name] then
		return true
	end

	for _, propertyName in ipairs({ "Attachment0", "Attachment1" }) do
		local ok, attachment = pcall(function()
			return constraint[propertyName]
		end)
		if ok and attachment and attachment.Parent and LEFT_ARM_PARTS[attachment.Parent.Name] then
			return true
		end
	end

	return false
end

local function getLeftArmAnimationConstraints(character)
	local constraints = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if isAnimationConstraint(descendant) and animationConstraintTouchesLeftArm(descendant) then
			table.insert(constraints, descendant)
		end
	end
	return constraints
end

local function restoreLeftArmAnimationConstraints(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if isAnimationConstraint(descendant) and descendant:GetAttribute(GRIP_ATTR) then
			descendant.Enabled = descendant:GetAttribute(GRIP_WAS_ENABLED_ATTR) == true
			descendant:SetAttribute(GRIP_ATTR, nil)
			descendant:SetAttribute(GRIP_WAS_ENABLED_ATTR, nil)
		end
	end
end

local function clearLeftHandGrip(character)
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local existingIK = humanoid:FindFirstChild("LeftHandIK")
		if existingIK then existingIK:Destroy() end
	end

	local leftHand = character:FindFirstChild("LeftHand")
	if leftHand then
		local existingAlign = leftHand:FindFirstChild("LeftHandGripAlign")
		if existingAlign then existingAlign:Destroy() end
		local existingAttachment = leftHand:FindFirstChild("LeftHandGripAttachment")
		if existingAttachment then existingAttachment:Destroy() end
	end

	restoreLeftArmAnimationConstraints(character)
end

-- Attach-time weapon pose maintenance. The off-hand solver below is currently
-- disabled (#56); the live path only resets the RightGrip weld rotation. The
-- old IK/AlignPosition implementation is left below the early return as
-- reference for a future non-propulsive grip mechanism.
--
-- No-op for single-handed weapons (Pistol / Knife — no LeftGrip Attachment).
function WeaponMeshes.attachLeftHandIK(character, tool)
	if not character or not tool then return nil end

	-- (#56) Fix Avatar-Joint-Upgrade RightGripAttachment orientation. Modern
	-- R15 rigs (CreateHumanoidModelFromDescription output) set the attachment's
	-- local CFrame to Rx(90) — its -Z (the "grip forward" direction Roblox
	-- uses to align Handle) points along the fingers, which is DOWN when the
	-- arm hangs at the side. Tool.Parent = character creates a Weld with
	-- C0 = attachment.CFrame, so the gun's barrel inherits this downward
	-- orientation and ends up pointing straight into the floor. Previously
	-- the rigid-pin LeftHand IK was masking this — its kinematic loop
	-- force-rotated the right arm into a horizontal pose. With IK disabled
	-- (below), the bug surfaces. Reset Weld.C0 to identity rotation while
	-- preserving the position offset; Handle.LookVector then tracks
	-- RightHand.LookVector, so the gun follows the animation pose naturally.
	--
	-- The Weld is created by Roblox's Tool grip machinery; in practice it's
	-- present immediately after Tool.Parent = character on the same frame,
	-- but defensive bounded WaitForChild handles the (rare) deferred case
	-- without silently skipping the reset.
	task.spawn(function()
		local rh = character:WaitForChild("RightHand", 2)
		if not rh then return end
		local weld = rh:WaitForChild("RightGrip", 2)
		if weld and weld:IsA("Weld") then
			weld.C0 = CFrame.new(weld.C0.Position)
		end
	end)

	-- (#56) Disable server-side LeftHand IK entirely. On modern Avatar-Joint-Upgrade
	-- rigs, AlignPosition.RigidityEnabled=true creates a closed kinematic loop
	-- (LeftHand → BallSocket joints → UpperTorso) that drags HumanoidRootPart:
	--   - NPCs: 4-5x WalkSpeed propulsion (Armored vmag 9.82 vs ws 2.40,
	--     Elite vmag 19.64 vs ws 4.20 in Studio A/B).
	--   - Players: 0.7-2.5 stud/s drift while standing still — RootPart moves
	--     even when MoveDirection=(0,0,0); 100% eliminated by destroying the
	--     AlignPosition in A/B test.
	-- Softening (RigidityEnabled=false) doesn't help: BallSocket joint limits
	-- pin the hand 2.2 studs from the LeftGrip regardless of MaxForce (1k–50k
	-- all measured the same gap). The rigid pin is the only path that closes
	-- that distance, and it's also the only path that causes the drag.
	-- Non-physical client systems now supply both visuals: ViewmodelController
	-- writes third-person R15 joint transforms, while FirstPersonViewmodel owns
	-- the camera-local hands and weapon. Keep the old physical implementation
	-- below disabled so RootPart drift / NPC propulsion cannot return.
	if true then return nil end
	-- luacheck: ignore (rest kept for reference / future re-enable)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	-- Tear down any prior grip from the previous weapon. Do this BEFORE the
	-- single-handed early-return so swapping from a two-handed to a
	-- single-handed weapon correctly clears the off-hand grip.
	clearLeftHandGrip(character)

	local handle = tool:FindFirstChild("Handle")
	if not handle then return nil end
	local leftGrip = handle:FindFirstChild("LeftGrip")
	if not leftGrip or not leftGrip:IsA("Attachment") then return nil end  -- single-handed weapon

	local leftHand = character:FindFirstChild("LeftHand")
	local upperTorso = character:FindFirstChild("UpperTorso")
	if not leftHand or not upperTorso then return nil end

	local animationConstraints = getLeftArmAnimationConstraints(character)
	if #animationConstraints > 0 then
		for _, constraint in ipairs(animationConstraints) do
			constraint:SetAttribute(GRIP_WAS_ENABLED_ATTR, constraint.Enabled == true)
			constraint:SetAttribute(GRIP_ATTR, true)
			constraint.Enabled = false
		end

		local handAttachment = Instance.new("Attachment")
		handAttachment.Name = "LeftHandGripAttachment"
		handAttachment.Parent = leftHand

		local align = Instance.new("AlignPosition")
		align.Name = "LeftHandGripAlign"
		align.Attachment0 = handAttachment
		align.Attachment1 = leftGrip
		align.RigidityEnabled = true
		align.MaxForce = 100000
		align.Responsiveness = 200
		align.Parent = leftHand

		local destroyingConn
		local ancestryConn
		local function disconnect()
			if destroyingConn then
				destroyingConn:Disconnect()
				destroyingConn = nil
			end
			if ancestryConn then
				ancestryConn:Disconnect()
				ancestryConn = nil
			end
		end
		local function clearAlignGrip()
			if align.Parent ~= leftHand and handAttachment.Parent ~= leftHand then
				disconnect()
				return
			end
			disconnect()
			clearLeftHandGrip(character)
		end

		destroyingConn = tool.Destroying:Connect(clearAlignGrip)
		ancestryConn = tool.AncestryChanged:Connect(function()
			if tool.Parent ~= character then
				clearAlignGrip()
			end
		end)

		return align
	end

	if not humanoid:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Legacy Motor6D rigs still support IKControl. ChainRoot = UpperTorso gives
	-- the solver shoulder + elbow + wrist reach.
	local ik = Instance.new("IKControl")
	ik.Name = "LeftHandIK"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = upperTorso
	ik.EndEffector = leftHand
	ik.Target = leftGrip
	ik.Weight = 1.0
	ik.SmoothTime = 0  -- LeftGrip is rigidly welded to RightHand; no smoothing needed
	ik.Parent = humanoid

	local destroyingConn
	local ancestryConn
	local function disconnect()
		if destroyingConn then
			destroyingConn:Disconnect()
			destroyingConn = nil
		end
		if ancestryConn then
			ancestryConn:Disconnect()
			ancestryConn = nil
		end
	end
	local function clearIKGrip()
		if ik.Parent ~= humanoid then
			disconnect()
			return
		end
		disconnect()
		clearLeftHandGrip(character)
	end

	destroyingConn = tool.Destroying:Connect(clearIKGrip)
	ancestryConn = tool.AncestryChanged:Connect(function()
		if tool.Parent ~= character then
			clearIKGrip()
		end
	end)

	return ik
end

return WeaponMeshes
