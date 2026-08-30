-- WeaponVisuals.lua (ReplicatedStorage/ModuleScript)
-- One continuous MeshPart per weapon. The same asset drives Tools and thumbnails.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponVisuals = {}

local MESH_ASSETS = {
	["Phantom Ranger"] = {
		MeshId = "rbxassetid://105958273998826",
		TextureId = "rbxassetid://118709367984985",
		Size = Vector3.new(0.3784, 1.4, 3.8377),
	},
	["Stinger Vector"] = {
		MeshId = "rbxassetid://132019145012012",
		TextureId = "rbxassetid://119056874473614",
		Size = Vector3.new(0.3197, 1.4, 2.7711),
	},
	["Thunder Pump"] = {
		MeshId = "rbxassetid://128360439292032",
		TextureId = "rbxassetid://80034572166649",
		Size = Vector3.new(0.4377, 1.5, 4.8958),
	},
	["Wraith Longshot"] = {
		MeshId = "rbxassetid://115351779024522",
		TextureId = "rbxassetid://128640485599665",
		Size = Vector3.new(0.4662, 1.5, 4.7096),
	},
	["Hailstorm LMG"] = {
		MeshId = "rbxassetid://82225635310805",
		TextureId = "rbxassetid://133050651512039",
		Size = Vector3.new(0.4026, 1.6, 3.078),
	},
	["Phantom Vanguard"] = {
		MeshId = "rbxassetid://138824436288465",
		TextureId = "rbxassetid://109215318144405",
		Size = Vector3.new(0.4206, 1.5, 4.0667),
	},
	["Thunder Tempest"] = {
		MeshId = "rbxassetid://71243453378825",
		TextureId = "rbxassetid://116449037181582",
		Size = Vector3.new(0.4615, 1.5, 2.8805),
	},
	["Wraith Marksman"] = {
		MeshId = "rbxassetid://96439485272461",
		TextureId = "rbxassetid://103593069801864",
		Size = Vector3.new(0.3591, 1.45, 3.0319),
	},
	["Viper Mk1"] = {
		MeshId = "rbxassetid://121249729652115",
		TextureId = "rbxassetid://131611351358250",
		Size = Vector3.new(0.3569, 1.3, 1.6857),
	},
	["Viper Outlaw"] = {
		MeshId = "rbxassetid://86792636192217",
		TextureId = "rbxassetid://103427649639959",
		Size = Vector3.new(0.419, 1.4, 1.9172),
	},
	["Viper Talon"] = {
		MeshId = "rbxassetid://102144722623542",
		TextureId = "rbxassetid://115594424285991",
		Size = Vector3.new(0.4345, 1.4, 1.9375),
	},
	["Thunder Handcannon"] = {
		MeshId = "rbxassetid://73393287641368",
		TextureId = "rbxassetid://105385675722779",
		Size = Vector3.new(0.3754, 1.5, 2.2611),
	},
	["Viper Swift"] = {
		MeshId = "rbxassetid://114206266253437",
		TextureId = "rbxassetid://95424735526583",
		Size = Vector3.new(0.3648, 1.2, 1.6681),
	},
	["Viper Trinity"] = {
		MeshId = "rbxassetid://105371092118695",
		TextureId = "rbxassetid://78874165735454",
		Size = Vector3.new(0.3497, 1.35, 1.8608),
	},
	["Stinger Sidearm"] = {
		MeshId = "rbxassetid://106692855921357",
		TextureId = "rbxassetid://82308870552351",
		Size = Vector3.new(0.3782, 1.5, 2.3453),
	},
	["Thunder Twin"] = {
		MeshId = "rbxassetid://82964725059869",
		TextureId = "rbxassetid://126709138518508",
		Size = Vector3.new(0.3383, 1.45, 2.1318),
	},
}

local function newMeshPart(weaponName)
	local assetsFolder = ReplicatedStorage:FindFirstChild("WeaponMeshAssets")
	local source = assetsFolder and assetsFolder:FindFirstChild(weaponName)
	if source and source:IsA("MeshPart") then
		return source:Clone()
	end

	local asset = MESH_ASSETS[weaponName]
	if not asset then return nil end

	local mesh = Instance.new("MeshPart")
	mesh.MeshId = asset.MeshId
	mesh.TextureID = asset.TextureId
	mesh.Size = asset.Size
	return mesh
end

function WeaponVisuals.buildModel(weaponName, config)
	if not config or not MESH_ASSETS[weaponName] then
		warn(("[WeaponVisuals] Missing continuous mesh for %s"):format(tostring(weaponName)))
		return nil
	end

	local model = Instance.new("Model")
	model.Name = weaponName
	model:SetAttribute("WeaponStyle", config.Style)

	local handle = newMeshPart(weaponName)
	if not handle then
		model:Destroy()
		return nil
	end
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = model
	model.PrimaryPart = handle

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.2, handle.Size.Z * 0.5)
	muzzle.Parent = handle

	return model
end

function WeaponVisuals.createViewport(viewport, weaponName, config)
	local model = WeaponVisuals.buildModel(weaponName, config)
	if not model then return nil end

	local world = Instance.new("WorldModel")
	world.Name = "WeaponPreview"
	world.Parent = viewport
	model.Parent = world

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CastShadow = false
		end
	end

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-boundsCFrame.Position) * model:GetPivot())
	local maxDimension = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 26
	local sideOffset = config.Type == "Pistol" and 0.34 or 0.16
	camera.CFrame = CFrame.lookAt(
		Vector3.new(maxDimension * 1.3, maxDimension * 0.38, maxDimension * sideOffset),
		Vector3.new(0, 0.15, 0)
	)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return model
end

return WeaponVisuals
