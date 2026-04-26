-- WeaponSystem.lua (ServerStorage/ModuleScript)
-- Weapon data access and utility functions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local WeaponSystem = {}

function WeaponSystem.getConfig(weaponName)
	return GameConfig.WEAPONS[weaponName]
end

function WeaponSystem.getAllWeapons()
	local list = {}
	for name, config in pairs(GameConfig.WEAPONS) do
		table.insert(list, { Name = name, Config = config })
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end

function WeaponSystem.getRandomWeapon()
	local names = {}
	for name, _ in pairs(GameConfig.WEAPONS) do
		table.insert(names, name)
	end
	return names[math.random(#names)]
end

function WeaponSystem.isMelee(weaponName)
	local config = GameConfig.WEAPONS[weaponName]
	return config and config.Type == "Knife"
end

function WeaponSystem.isAutomatic(weaponName)
	local config = GameConfig.WEAPONS[weaponName]
	return config and config.Auto == true
end

function WeaponSystem.getDPS(weaponName)
	local config = GameConfig.WEAPONS[weaponName]
	if not config then return 0 end
	if config.Type == "Knife" then
		return config.Damage / config.AttackRate
	end
	local pellets = config.Pellets or 1
	return (config.Damage * pellets) / config.FireRate
end

return WeaponSystem
