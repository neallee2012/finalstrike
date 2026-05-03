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
-- ViewmodelController uses this to drive an IKControl that pins LeftHand to the
-- weapon — making both hands visually grip two-handed weapons in first-person.
-- Nil entries (Pistol, Knife) mean "single-handed, no IK".
local LEFT_GRIP_OFFSET = {
	SMG     = Vector3.new(0, 0.5, -1.0),   -- ~Mag area
	Rifle   = Vector3.new(0, 0.18, -1.4),  -- on the Foregrip
	Shotgun = Vector3.new(0, 0.32, -1.0),  -- on the Pump
	Sniper  = Vector3.new(0, 0.5, -2.0),   -- mid-barrel
	Minigun = Vector3.new(0, 0.5, -1.0),
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

	-- Add LeftGrip attachment for two-handed weapons so client IKControl can
	-- snap the player's LeftHand to it (visual: both hands gripping the gun).
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

	-- Grip CFrame: hand wraps the top of the grip (Handle.Y=+0.45 is grip top).
	-- No rotation — Roblox tool system aligns Handle's -Z with hand's forward
	-- look direction by default, which is exactly where our muzzle points.
	tool.Grip = CFrame.new(0, 0.45, 0)

	return tool
end

return WeaponMeshes
