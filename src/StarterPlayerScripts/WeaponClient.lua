-- WeaponClient.lua (StarterPlayerScripts)
-- Client-side weapon input: shooting, reloading, aiming

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local FireWeapon = events:WaitForChild("FireWeapon")
local ReloadWeapon = events:WaitForChild("ReloadWeapon")

-- Look up the equipped weapon Tool's Muzzle attachment on the local character.
-- Returns nil if no Tool equipped or muzzle missing (e.g. first frame before
-- server attaches the Tool on respawn).
local function getMuzzle()
	local char = player.Character
	if not char then return nil end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return nil end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return nil end
	return handle:FindFirstChild("Muzzle")
end

-- Quick muzzle flash at the gun barrel: bright sphere + PointLight, fade-out
-- in 0.08s. Local-only effect (each player sees their own).
local function spawnMuzzleFlash(muzzle)
	if not muzzle then return end
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(0.6, 0.6, 0.6)
	flash.CFrame = CFrame.new(muzzle.WorldPosition)
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 230, 140)
	flash.Shape = Enum.PartType.Ball
	flash.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 130)
	light.Brightness = 8
	light.Range = 12
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.08), { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) }):Play()
	TweenService:Create(light, TweenInfo.new(0.08), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.15)
end

local currentWeapon = GameConfig.STARTER_WEAPONS[1]
local canFire = true
local isReloading = false
local isFiring = false

-- Listen for weapon equip
events:WaitForChild("EquipWeapon").OnClientEvent:Connect(function(weaponName)
	if GameConfig.WEAPONS[weaponName] then
		currentWeapon = weaponName
		canFire = true
		isReloading = false
	end
end)

events:WaitForChild("ReloadComplete").OnClientEvent:Connect(function()
	isReloading = false
	canFire = true
end)

local function fireWeapon()
	if not canFire or isReloading then return end

	local config = GameConfig.WEAPONS[currentWeapon]
	if not config then return end

	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	canFire = false

	-- Origin = gun muzzle if equipped, else head as fallback (e.g. first frame
	-- before server attaches weapon model on respawn).
	local muzzle = getMuzzle()
	local origin = muzzle and muzzle.WorldPosition or head.Position

	-- Two-stage aim (fixes #8): the muzzle is offset from the camera (right
	-- hand vs head/eye position), so firing FROM muzzle along the camera's ray
	-- direction puts shots noticeably off the crosshair. Instead:
	--   1. Cast from the camera along the screen-pointer ray to find what the
	--      crosshair is actually over (or a far point if it hits nothing).
	--   2. Aim from the muzzle TOWARD that point — bullets now follow the
	--      crosshair regardless of muzzle offset.
	local screenRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local aimParams = RaycastParams.new()
	aimParams.FilterType = Enum.RaycastFilterType.Exclude
	aimParams.FilterDescendantsInstances = { character }
	local maxRange = config.Range or 500
	local aimResult = workspace:Raycast(screenRay.Origin, screenRay.Direction * maxRange, aimParams)
	local targetPos = aimResult and aimResult.Position
		or (screenRay.Origin + screenRay.Direction * maxRange)
	local direction = (targetPos - origin).Unit

	-- Local muzzle flash for the local player (server's WeaponHit handles the
	-- impact spark; this is the gun-end of the shot).
	spawnMuzzleFlash(muzzle)

	if config.Type == "Knife" then
		-- Melee: short range check
		FireWeapon:FireServer(origin, direction, currentWeapon)
		task.delay(config.AttackRate, function()
			canFire = true
		end)
	else
		-- Ranged weapon
		FireWeapon:FireServer(origin, direction, currentWeapon)
		task.delay(config.FireRate, function()
			canFire = true
		end)
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = true
		fireWeapon()
	end

	if input.KeyCode == Enum.KeyCode.R then
		if not isReloading then
			isReloading = true
			canFire = false
			ReloadWeapon:FireServer()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = false
	end
end)

-- Auto-fire for automatic weapons
RunService.Heartbeat:Connect(function()
	if isFiring and canFire and not isReloading then
		local config = GameConfig.WEAPONS[currentWeapon]
		if config and config.Auto then
			fireWeapon()
		end
	end
end)
