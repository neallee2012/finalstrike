-- CurrencyService.lua (ServerScriptService)
-- Persistent BulletCoins storage + per-match earning cap enforcement.
--
-- DataStore: PlayerCurrency_v1, key = UserId, value = number (coin balance)
-- Per-match caps live in memory and reset via resetMatchCaps(player) — typically
-- called by MatchManager.startMatch. Caps are read from GameConfig.ECONOMY.MatchCaps.
--
-- API:
--   getCoins(player) -> number
--   addCoins(player, amount, category) -> actualAmount  (clamped by per-category + total match cap)
--   spend(player, amount) -> bool  (false if insufficient balance; for shop purchases)
--   resetMatchCaps(player)         (clears per-match earned counters)
--
-- DataStore note: Studio playtest needs "Enable Studio Access to API Services"
-- enabled in Game Settings → Security. Without it, GetAsync/SetAsync fail and
-- all players start at 0 coins (warning logged, not fatal).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CurrencyMath = require(ServerStorage:WaitForChild("CurrencyMath"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local CurrencyService = {}

local store = DataStoreService:GetDataStore("PlayerCurrency_v1")

-- [player] = { Coins = int, MatchEarned = { NpcKills, Survival, PlayerKills, Total } }
local data = {}

-- [player] = true once GetAsync succeeded for this player. savePlayer is a no-op
-- otherwise — prevents the "load failed → default 0 → overwrite real save" data
-- loss path. A failed load means we don't know what the player had, so we don't
-- write anything back.
local loaded = {}

local function newMatchCounters()
	return { NpcKills = 0, Survival = 0, PlayerKills = 0, Total = 0 }
end

local function pushUpdate(player)
	local entry = data[player]
	if not entry then return end
	local ev = events:FindFirstChild("CurrencyUpdate")
	if ev then
		ev:FireClient(player, entry.Coins)
	end
end

local function loadPlayer(player)
	local coins = 0
	local ok, result = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if ok then
		if type(result) == "number" then
			coins = result
		end
		loaded[player] = true
	else
		warn("[CurrencyService] Load failed for " .. player.Name .. ": " .. tostring(result))
	end
	data[player] = { Coins = coins, MatchEarned = newMatchCounters() }
	pushUpdate(player)
	print(string.format("[CurrencyService] Loaded %s = %d coins (loaded=%s)", player.Name, coins, tostring(loaded[player] == true)))
end

local function savePlayer(player)
	local entry = data[player]
	if not entry then return end
	if not loaded[player] then
		-- Load failed; entry.Coins is the default (0). Writing it would overwrite
		-- the player's real saved balance. Skip.
		warn("[CurrencyService] Skipping save for " .. player.Name .. " (load never succeeded)")
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), entry.Coins)
	end)
	if not ok then
		warn("[CurrencyService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function CurrencyService.getCoins(player)
	local entry = data[player]
	return entry and entry.Coins or 0
end

-- Add coins, respecting per-category cap (if category given) and total match cap.
-- category: "NpcKills" | "Survival" | "PlayerKills" | nil (uncapped per-category, still respects total)
-- Returns actualAmount added (may be < amount if cap was hit, 0 if entirely capped).
function CurrencyService.addCoins(player, amount, category)
	local entry = data[player]
	if not entry or amount <= 0 then return 0 end

	local caps = GameConfig.ECONOMY.MatchCaps
	local earned = entry.MatchEarned

	local applied = CurrencyMath.computeAppliedAmount(caps, earned, amount, category)
	if applied <= 0 then return 0 end

	entry.Coins = entry.Coins + applied
	earned.Total = earned.Total + applied
	if category and earned[category] then
		earned[category] = earned[category] + applied
	end
	pushUpdate(player)
	return applied
end

-- Spend for shop purchases. Returns true on success, false if insufficient.
-- Save happens at PlayerRemoving / BindToClose, not on every spend, to avoid
-- DataStore throttling. If a player crashes mid-session, they keep what they
-- earned in the previous session (acceptable tradeoff).
function CurrencyService.spend(player, amount)
	local entry = data[player]
	if not entry or amount <= 0 then return false end
	if entry.Coins < amount then return false end
	entry.Coins = entry.Coins - amount
	pushUpdate(player)
	return true
end

function CurrencyService.resetMatchCaps(player)
	local entry = data[player]
	if entry then
		entry.MatchEarned = newMatchCounters()
	end
end

-- Daily quest payout — bypasses per-match caps. Used by DailyQuestService.tryClaim.
-- Logged separately from match rewards so daily payouts are visible in console.
function CurrencyService.addDailyReward(player, amount, reason)
	local entry = data[player]
	if not entry or amount <= 0 then return 0 end
	entry.Coins = entry.Coins + amount
	pushUpdate(player)
	print(string.format("[Reward] %s +%d coins (%s)", player.Name, amount, reason or "Daily reward"))
	return amount
end

-- Initial-state query for clients (avoid CurrencyUpdate subscribe race on join)
local GetCurrency = events:WaitForChild("GetCurrency")
GetCurrency.OnServerInvoke = function(player)
	local entry = data[player]
	return entry and entry.Coins or 0
end

-- Player lifecycle
Players.PlayerAdded:Connect(loadPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	data[player] = nil
	loaded[player] = nil
end)

-- Save all on shutdown (BindToClose runs synchronously with ~30s budget)
game:BindToClose(function()
	for player, _ in pairs(data) do
		savePlayer(player)
	end
end)

_G.CurrencyService = CurrencyService

return CurrencyService
