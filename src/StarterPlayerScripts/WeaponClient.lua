-- WeaponClient.lua (StarterPlayerScripts)
-- Client-side weapon input: shooting, reloading, aiming

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local FireWeapon = events:WaitForChild("FireWeapon")
local ReloadWeapon = events:WaitForChild("ReloadWeapon")

local currentWeapon = "Viper"
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

	-- Get aim direction from camera
	local origin = head.Position
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local direction = unitRay.Direction

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
