-- ShopService.lua (ServerScriptService)
-- Persistent weapon ownership + purchase validation.
--
-- DataStore: PlayerOwnedWeapons_v1, key = UserId, value = array of weapon names
-- Starter weapons (GameConfig.STARTER_WEAPONS) are always granted on load — they
-- aren't persisted so adding to that list later automatically benefits old players.
--
-- Client buys via the BuyWeapon RemoteEvent; server replies via BuyWeaponResult
-- with (success: bool, reason: string, weaponName: string).
--
-- Coins are spent via CurrencyService.spend (which keeps the running balance in
-- memory; persistence happens at PlayerRemoving / BindToClose to avoid throttling).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local ShopService = {}

local store = DataStoreService:GetDataStore("PlayerOwnedWeapons_v1")
local primaryStore = DataStoreService:GetDataStore("PlayerPrimaryWeapon_v1")
local owned = {}    -- [player] = { [weaponName] = true, ... }  (set, not list)
local primary = {}  -- [player] = weaponName  (currently equipped main weapon)

local function newDefaultOwnership()
	local set = {}
	for _, name in ipairs(GameConfig.STARTER_WEAPONS) do
		set[name] = true
	end
	return set
end

local function setToSortedList(set)
	local list = {}
	for name in pairs(set) do table.insert(list, name) end
	table.sort(list)
	return list
end

local function pushUpdate(player)
	local set = owned[player]
	if not set then return end
	local ev = events:FindFirstChild("OwnedWeaponsUpdate")
	if ev then ev:FireClient(player, setToSortedList(set)) end
end

local function pushPrimaryUpdate(player)
	local ev = events:FindFirstChild("PrimaryWeaponUpdate")
	if ev then ev:FireClient(player, primary[player]) end
end

local function loadPlayer(player)
	local set = newDefaultOwnership()
	local ok, result = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if ok then
		if type(result) == "table" then
			for _, name in ipairs(result) do
				-- Skip weapons that no longer exist (e.g. removed from GameConfig in a patch)
				if GameConfig.WEAPONS[name] then
					set[name] = true
				end
			end
		end
	else
		warn("[ShopService] Load failed for " .. player.Name .. ": " .. tostring(result))
	end
	owned[player] = set
	pushUpdate(player)

	-- Load primary (separate DataStore key). Validate it's still owned + still exists.
	local primaryName = nil
	local pok, presult = pcall(function()
		return primaryStore:GetAsync(tostring(player.UserId))
	end)
	if pok and type(presult) == "string" and set[presult] and GameConfig.WEAPONS[presult] then
		primaryName = presult
	end
	primary[player] = primaryName or GameConfig.STARTER_WEAPONS[1]
	pushPrimaryUpdate(player)

	local count = 0
	for _ in pairs(set) do count = count + 1 end
	print(string.format("[ShopService] Loaded %s = %d weapons owned, primary=%s", player.Name, count, primary[player]))
end

local function savePlayer(player)
	local set = owned[player]
	if not set then return end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), setToSortedList(set))
	end)
	if not ok then
		warn("[ShopService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
	-- Persist primary in its own key (kept separate so corrupted primary doesn't lose ownership)
	local pname = primary[player]
	if pname then
		local pok, perr = pcall(function()
			primaryStore:SetAsync(tostring(player.UserId), pname)
		end)
		if not pok then
			warn("[ShopService] Primary save failed for " .. player.Name .. ": " .. tostring(perr))
		end
	end
end

function ShopService.getOwned(player)
	return owned[player]
end

function ShopService.isOwned(player, weaponName)
	local set = owned[player]
	return set and set[weaponName] == true
end

function ShopService.getPrimary(player)
	return primary[player]
end

-- Set primary weapon. Validates player owns it and the weapon exists.
-- Returns success: bool, reason: string ("ok" / "notowned" / "unknown")
function ShopService.setPrimary(player, weaponName)
	if not GameConfig.WEAPONS[weaponName] then return false, "unknown" end
	if not ShopService.isOwned(player, weaponName) then return false, "notowned" end
	primary[player] = weaponName
	pushPrimaryUpdate(player)
	print(string.format("[Shop] %s equipped %s as primary", player.Name, weaponName))
	return true, "ok"
end

-- Try to buy. Returns success: bool, reason: string
-- Reasons: "ok" / "unknown" (bad weaponName) / "owned" / "broke" / "noservice"
function ShopService.tryBuy(player, weaponName)
	local set = owned[player]
	if not set then return false, "noservice" end
	local cfg = GameConfig.WEAPONS[weaponName]
	if not cfg or not cfg.Price or cfg.Price <= 0 then return false, "unknown" end
	if set[weaponName] then return false, "owned" end
	if not _G.CurrencyService then return false, "noservice" end
	if not _G.CurrencyService.spend(player, cfg.Price) then
		return false, "broke"
	end
	set[weaponName] = true
	pushUpdate(player)
	print(string.format("[Shop] %s bought %s for %d coins", player.Name, weaponName, cfg.Price))
	return true, "ok"
end

-- BuyWeapon RemoteEvent handler (client → server)
local BuyWeapon = events:WaitForChild("BuyWeapon")
local BuyWeaponResult = events:WaitForChild("BuyWeaponResult")
BuyWeapon.OnServerEvent:Connect(function(player, weaponName)
	if type(weaponName) ~= "string" then return end
	local ok, reason = ShopService.tryBuy(player, weaponName)
	BuyWeaponResult:FireClient(player, ok, reason, weaponName)
end)

-- EquipPrimaryWeapon handler (client → server). No reply event needed since
-- PrimaryWeaponUpdate fires automatically on success.
local EquipPrimaryWeapon = events:WaitForChild("EquipPrimaryWeapon")
EquipPrimaryWeapon.OnServerEvent:Connect(function(player, weaponName)
	if type(weaponName) ~= "string" then return end
	ShopService.setPrimary(player, weaponName)  -- silent on failure (UI shouldn't allow it)
end)

-- Initial-state queries for clients (avoid update-event subscribe race on join)
local GetOwnedWeapons = events:WaitForChild("GetOwnedWeapons")
GetOwnedWeapons.OnServerInvoke = function(player)
	local set = owned[player]
	return set and setToSortedList(set) or {}
end

local GetPrimaryWeapon = events:WaitForChild("GetPrimaryWeapon")
GetPrimaryWeapon.OnServerInvoke = function(player)
	return primary[player] or GameConfig.STARTER_WEAPONS[1]
end

-- Lifecycle
Players.PlayerAdded:Connect(loadPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	owned[player] = nil
	primary[player] = nil
end)

game:BindToClose(function()
	for player, _ in pairs(owned) do savePlayer(player) end
end)

_G.ShopService = ShopService

return ShopService
