-- PlayerHealth.lua (ServerScriptService)
-- Modular player health management, wraps into MatchManager

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local PlayerHealth = {}

function PlayerHealth.getHP(player)
	local mm = _G.MatchManager
	if not mm then return 0 end
	local data = mm.getPlayerData(player)
	return data and data.HP or 0
end

function PlayerHealth.damage(player, amount, attacker)
	local mm = _G.MatchManager
	if mm then
		mm.damagePlayer(player, amount, attacker)
	end
end

function PlayerHealth.heal(player, amount)
	local mm = _G.MatchManager
	if mm then
		mm.healPlayer(player, amount)
	end
end

function PlayerHealth.isEliminated(player)
	local mm = _G.MatchManager
	if not mm then return false end
	local data = mm.getPlayerData(player)
	return data and data.Eliminated or false
end

function PlayerHealth.isAlive(player)
	return not PlayerHealth.isEliminated(player) and PlayerHealth.getHP(player) > 0
end

return PlayerHealth
