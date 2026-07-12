-- ReloadLogic.lua (ServerStorage ModuleScript)
-- Side-effect-free reload state transitions shared by MatchManager and TestEZ.

local ReloadLogic = {}

function ReloadLogic.addReserve(data, config, amount, maxReserveMagazines)
	if type(data) ~= "table" or type(config) ~= "table" then return 0 end
	if type(amount) ~= "number" or amount <= 0 then return 0 end
	if type(maxReserveMagazines) ~= "number" or maxReserveMagazines <= 0 then return 0 end
	if type(config.MagSize) ~= "number" or config.MagSize <= 0 then return 0 end

	local reserveCap = config.MagSize * maxReserveMagazines
	local previousReserve = math.clamp(data.ReserveAmmo or 0, 0, reserveCap)
	data.ReserveAmmo = math.min(reserveCap, previousReserve + amount)
	return data.ReserveAmmo - previousReserve
end

function ReloadLogic.canStart(data, config)
	if type(data) ~= "table" or type(config) ~= "table" then return false end
	if data.Eliminated or data.Reloading then return false end
	if config.Type == "Knife" then return false end
	if type(data.Ammo) ~= "number" then return false end
	if type(data.ReserveAmmo) ~= "number" or data.ReserveAmmo <= 0 then return false end
	if type(config.MagSize) ~= "number" or config.MagSize <= 0 then return false end
	if type(config.ReloadTime) ~= "number" or config.ReloadTime <= 0 then return false end
	return data.Ammo < config.MagSize
end

function ReloadLogic.start(data, config, now)
	if not ReloadLogic.canStart(data, config) then return nil end

	local token = (data.ReloadToken or 0) + 1
	local duration = config.ReloadTime
	data.ReloadToken = token
	data.Reloading = true
	data.ReloadEndsAt = now + duration

	return {
		Token = token,
		Weapon = data.Weapon,
		Duration = duration,
		EndsAt = data.ReloadEndsAt,
	}
end

function ReloadLogic.cancel(data)
	if type(data) ~= "table" then return false end

	local wasReloading = data.Reloading == true
	data.ReloadToken = (data.ReloadToken or 0) + 1
	data.Reloading = false
	data.ReloadEndsAt = 0
	return wasReloading
end

function ReloadLogic.complete(data, operation, config)
	if type(data) ~= "table" or type(operation) ~= "table" or type(config) ~= "table" then
		return false
	end
	if data.Eliminated or not data.Reloading then return false end
	if data.ReloadToken ~= operation.Token then return false end
	if data.Weapon ~= operation.Weapon then return false end
	if type(config.MagSize) ~= "number" or config.MagSize <= 0 then return false end

	local missingRounds = math.max(0, config.MagSize - data.Ammo)
	local reserveAmmo = math.max(0, data.ReserveAmmo or 0)
	local loadedRounds = math.min(missingRounds, reserveAmmo)
	data.Ammo = data.Ammo + loadedRounds
	data.ReserveAmmo = reserveAmmo - loadedRounds
	data.Reloading = false
	data.ReloadEndsAt = 0
	return true
end

return ReloadLogic
