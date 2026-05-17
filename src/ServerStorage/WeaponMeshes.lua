-- WeaponMeshes.lua (ServerStorage/ModuleScript)
-- Build weapon models from primitive Parts. Each model has:
--   - PrimaryPart "Handle" (welded to player's RightHand on equip)
--   - Attachment "Muzzle" at the end of the barrel (used as raycast/VFX origin)
-- Visual style matches the dark cinematic theme: dark gray/black bodies with
-- subtle accent neon for visibility against the cinematic backdrop.
--
-- 30 weapons share 6 underlying mesh builders, dispatched by Config.Type
-- (see TYPE_TO_BUILDER below). Per-weapon distinct meshes are deferred to a
-- polish sprint — fixes #9 (Stage 1 rename broke direct name lookup).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local WeaponMeshes = {}

local DARK     = Color3.fromRGB(35, 35, 40)
local STEEL    = Color3.fromRGB(70, 72, 80)
local ACCENT   = Color3.fromRGB(255, 60, 50)
local BARREL   = Color3.fromRGB(20, 20, 22)
local POLY     = Color3.fromRGB(45, 50, 60)

-- Helper: create a Part owned by the model, welded to the Handle. Massless so
-- it doesn't unbalance the player. CFrame is local-offset from the Handle.
local function addPart(model, handle, name, size, color, material, localOffset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.CFrame = handle.CFrame * localOffset
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
	p.Parent = model
	return p
end

-- Place the muzzle attachment at a local point on the Handle (forward = -Z in
-- typical Roblox tool-grip space). Returns the Attachment.
local function addMuzzle(handle, localPos)
	local a = Instance.new("Attachment")
	a.Name = "Muzzle"
	a.Position = localPos
	a.Parent = handle
	return a
end

-- Each builder returns (Model, Handle, Muzzle).
local builders = {}

function builders.Viper()
	-- Compact pistol: short body, stubby barrel
	local m = Instance.new("Model")
	m.Name = "Viper"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.9, 0.3)  -- grip
	handle.Color = DARK
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = m
	m.PrimaryPart = handle

	addPart(m, handle, "Slide",  Vector3.new(0.4, 0.5, 1.2),  STEEL,  Enum.Material.Metal,         CFrame.new(0, 0.45, -0.4))
	addPart(m, handle, "Barrel", Vector3.new(0.18, 0.18, 0.4),BARREL, Enum.Material.Metal,         CFrame.new(0, 0.45, -1.05))
	addPart(m, handle, "Sight",  Vector3.new(0.08, 0.1, 0.1), ACCENT, Enum.Material.Neon,          CFrame.new(0, 0.78, -0.2))
	return m, handle, addMuzzle(handle, Vector3.new(0, 0.45, -1.3))
end

function builders.Stinger()
	-- SMG: stubby with magazine sticking down + folded stock
	local m = Instance.new("Model")
	m.Name = "Stinger"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.85, 0.3)
	handle.Color = DARK
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = m
	m.PrimaryPart = handle

	addPart(m, handle, "Receiver", Vector3.new(0.4, 0.5, 1.6),  STEEL,  Enum.Material.Metal,         CFrame.new(0, 0.5, -0.5))
	addPart(m, handle, "Mag",      Vector3.new(0.35, 0.7, 0.25),DARK,   Enum.Material.SmoothPlastic, CFrame.new(0, 0.05, -0.55))
	addPart(m, handle, "Barrel",   Vector3.new(0.16, 0.16, 0.6),BARREL, Enum.Material.Metal,         CFrame.new(0, 0.5, -1.5))
	addPart(m, handle, "Stock",    Vector3.new(0.3, 0.3, 0.5),  POLY,   Enum.Material.Metal,         CFrame.new(0, 0.55, 0.45))
	return m, handle, addMuzzle(handle, Vector3.new(0, 0.5, -1.85))
end

function builders.Phantom()
	-- Assault rifle: long receiver, full stock, foregrip
	local m = Instance.new("Model")
	m.Name = "Phantom"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.85, 0.3)
	handle.Color = DARK
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = m
	m.PrimaryPart = handle

	addPart(m, handle, "Receiver", Vector3.new(0.4, 0.5, 2.0),  STEEL,  Enum.Material.Metal,         CFrame.new(0, 0.5, -0.5))
	addPart(m, handle, "Mag",      Vector3.new(0.35, 0.55, 0.3),DARK,   Enum.Material.SmoothPlastic, CFrame.new(0, 0.1, -0.4))
	addPart(m, handle, "Foregrip", Vector3.new(0.3, 0.45, 0.4), POLY,   Enum.Material.Metal,         CFrame.new(0, 0.18, -1.4))
	addPart(m, handle, "Barrel",   Vector3.new(0.16, 0.16, 1.0),BARREL, Enum.Material.Metal,         CFrame.new(0, 0.5, -2.0))
	addPart(m, handle, "Stock",    Vector3.new(0.3, 0.4, 0.9),  POLY,   Enum.Material.Metal,         CFrame.new(0, 0.55, 0.7))
	addPart(m, handle, "Sight",    Vector3.new(0.18, 0.18, 0.3),ACCENT, Enum.Material.Neon,          CFrame.new(0, 0.85, -0.4))
	return m, handle, addMuzzle(handle, Vector3.new(0, 0.5, -2.55))
end

function builders.Thunder()
	-- Shotgun: pump-action, thick barrel, wood-toned stock
	local m = Instance.new("Model")
	m.Name = "Thunder"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.85, 0.3)
	handle.Color = DARK
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = m
	m.PrimaryPart = handle

	addPart(m, handle, "Receiver", Vector3.new(0.45, 0.55, 1.3),STEEL,  Enum.Material.Metal,         CFrame.new(0, 0.5, -0.4))
	addPart(m, handle, "Pump",     Vector3.new(0.4, 0.45, 0.45),POLY,   Enum.Material.Wood,          CFrame.new(0, 0.32, -1.0))
	addPart(m, handle, "Barrel",   Vector3.new(0.32, 0.32, 1.6),BARREL, Enum.Material.Metal,         CFrame.new(0, 0.55, -1.85))
	addPart(m, handle, "Stock",    Vector3.new(0.32, 0.45, 1.0),Color3.fromRGB(60, 40, 30), Enum.Material.Wood, CFrame.new(0, 0.55, 0.75))
	return m, handle, addMuzzle(handle, Vector3.new(0, 0.55, -2.7))
end

function builders.Wraith()
	-- Sniper: long barrel, big scope, bipod
	local m = Instance.new("Model")
	m.Name = "Wraith"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.85, 0.3)
	handle.Color = DARK
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = m
	m.PrimaryPart = handle

	addPart(m, handle, "Receiver", Vector3.new(0.4, 0.5, 2.2),  STEEL,  Enum.Material.Metal,         CFrame.new(0, 0.5, -0.6))
	addPart(m, handle, "Mag",      Vector3.new(0.35, 0.4, 0.25),DARK,   Enum.Material.SmoothPlastic, CFrame.new(0, 0.18, -0.4))
	addPart(m, handle, "Barrel",   Vector3.new(0.18, 0.18, 2.4),BARREL, Enum.Material.Metal,         CFrame.new(0, 0.5, -2.9))
	addPart(m, handle, "ScopeBody",Vector3.new(0.25, 0.25, 1.0),POLY,   Enum.Material.Metal,         CFrame.new(0, 0.92, -0.7))
	addPart(m, handle, "ScopeLens",Vector3.new(0.22, 0.22, 0.05),ACCENT, Enum.Material.Neon,         CFrame.new(0, 0.92, -1.22))
	addPart(m, handle, "Stock",    Vector3.new(0.3, 0.4, 1.0),  POLY,   Enum.Material.Metal,         CFrame.new(0, 0.55, 0.8))
	addPart(m, handle, "Bipod",    Vector3.new(0.25, 0.4, 0.05),STEEL,  Enum.Material.Metal,         CFrame.new(0, 0.18, -3.7))
	return m, handle, addMuzzle(handle, Vector3.new(0, 0.5, -4.15))
end

function builders.Fang()
	-- Combat knife: short blade + handle
	local m = Instance.new("Model")
	m.Name = "Fang"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.7, 0.25)
	handle.Color = DARK
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = m
	m.PrimaryPart = handle

	addPart(m, handle, "Guard", Vector3.new(0.55, 0.1, 0.25), STEEL,  Enum.Material.Metal, CFrame.new(0, 0.4, 0))
	addPart(m, handle, "Blade", Vector3.new(0.08, 0.1, 1.2),  Color3.fromRGB(180, 200, 220), Enum.Material.Metal, CFrame.new(0, 0.4, -0.65))
	addPart(m, handle, "Edge",  Vector3.new(0.04, 0.06, 1.0), ACCENT, Enum.Material.Neon, CFrame.new(0, 0.45, -0.55))
	-- Knife "muzzle" is the blade tip — used as melee origin / hit spark anchor
	return m, handle, addMuzzle(handle, Vector3.new(0, 0.4, -1.3))
end

-- 30 named weapons map to 6 underlying meshes by Type. Same SMG mesh serves
-- Stinger Mk2 / Stinger Tac / Stinger Storm / Hailstorm (minigun gets SMG
-- mesh as placeholder until a proper minigun mesh is built).
local TYPE_TO_BUILDER = {
	Pistol  = builders.Viper,
	SMG     = builders.Stinger,
	Rifle   = builders.Phantom,
	Shotgun = builders.Thunder,
	Sniper  = builders.Wraith,
	Knife   = builders.Fang,
	Minigun = builders.Stinger,  -- placeholder
}

-- Local position of the LeftGrip attachment (relative to Handle) per weapon Type.
-- WeaponMeshes.attachLeftHandIK (called server-side from MatchManager + NPCSystem)
-- drives the off-hand grip solver — every viewer sees two-hand grip including
-- NPCs and other players (#39).
-- Nil entries (Pistol, Knife) mean "single-handed, no IK".
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

-- Public: build(weaponName) -> Tool (Handle is the BasePart, Muzzle is an
-- Attachment on the Handle). Wrapping as a Tool lets Roblox's built-in grip
-- system handle the hand pose; we set Tool.Grip so the player's hand sits at
-- the top of the grip with barrel pointing forward.
-- Returns nil for unknown weapon names or weapons with no Type-mapped builder.
function WeaponMeshes.build(weaponName)
	local cfg = GameConfig.WEAPONS[weaponName]
	if not cfg then return nil end
	local fn = TYPE_TO_BUILDER[cfg.Type]
	if not fn then
		warn("[WeaponMeshes] No builder for Type=" .. tostring(cfg.Type) .. " (weapon: " .. weaponName .. ")")
		return nil
	end
	local model, handle = fn()

	-- Add LeftGrip attachment for two-handed weapons so the server grip solver can
	-- snap the character's LeftHand to it (visual: both hands gripping the gun).
	local leftGripOffset = LEFT_GRIP_OFFSET[cfg.Type]
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

	if leftGripOffset then
		-- Two-handed grip: pull the gun inward (+X 0.4) and toward the chest
		-- (-Z 0.4 from default) so the LeftGrip Attachment lands inside the
		-- left arm's 1.86-stud reach. Y=+0.45 unchanged (hand wraps the top
		-- of the grip). No rotation — barrel still points along Hand's -Z so
		-- aim/raycast direction is unchanged from prior versions.
		tool.Grip = CFrame.new(0.4, 0.45, -0.4)
	else
		-- Single-handed weapons do not need #51 reach compensation.
		tool.Grip = CFrame.new(0, 0.45, 0)
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

-- Pin a character's LeftHand to the Tool's LeftGrip Attachment. Modern Roblox
-- Avatar-Joint-Upgrade rigs use AnimationConstraint + BallSocketConstraint
-- joints instead of Motor6Ds, so IKControl is inert there; those rigs use an
-- AlignPosition pull while temporarily pausing the left arm animation drivers.
-- Legacy Motor6D rigs fall back to IKControl. Everything is server-created so
-- the grip replicates to every viewer: local first-person, third-party
-- observers, and NPC viewers all see the same two-hand grip.
-- (#39) Previous implementation was client-only in ViewmodelController,
-- which left NPCs and other players' characters with the off-hand hanging
-- at the side.
--
-- No-op for single-handed weapons (Pistol / Knife — no LeftGrip Attachment).
function WeaponMeshes.attachLeftHandIK(character, tool)
	if not character or not tool then return nil end

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
