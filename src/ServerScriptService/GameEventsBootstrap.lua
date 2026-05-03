-- GameEventsBootstrap.lua (ServerScriptService)
-- Creates the ReplicatedStorage.GameEvents Folder + RemoteEvents at server startup.
-- Bootstrap script lives in ServerScriptService (not ReplicatedStorage) so it auto-runs
-- under default RunContext, and its name doesn't collide with the Folder it creates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = Instance.new("Folder")
events.Name = "GameEvents"
events.Parent = ReplicatedStorage

local function makeRemoteEvent(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = events
	return e
end

local function makeRemoteFunction(name)
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = events
	return f
end

-- Match phase updates
makeRemoteEvent("PhaseChanged")        -- server → client: phase, timeLeft
makeRemoteEvent("TimerUpdate")         -- server → client: seconds remaining
makeRemoteEvent("Announcement")        -- server → client: message string

-- Health
makeRemoteEvent("HealthUpdate")        -- server → client: currentHP, maxHP
makeRemoteEvent("PlayerEliminated")    -- server → all: playerName
makeRemoteEvent("PlayerDamaged")       -- server → client: damage amount, attacker

-- Weapons
makeRemoteEvent("FireWeapon")          -- client → server: origin, direction, weaponName
makeRemoteEvent("WeaponHit")           -- server → client: hit effects
makeRemoteEvent("EquipWeapon")         -- server → client: weaponName
makeRemoteEvent("ReloadWeapon")        -- client → server
makeRemoteEvent("ReloadComplete")      -- server → client

-- Loot
makeRemoteEvent("LootPickedUp")       -- server → client: lootType, amount
makeRemoteEvent("AmmoUpdate")         -- server → client: current, max

-- NPC
makeRemoteEvent("NPCDamaged")         -- visual feedback
makeRemoteEvent("NPCEliminated")      -- server → all: npcType, position

-- Kill feed
makeRemoteEvent("KillFeed")           -- server → all: killer, victim, weapon

-- Alive count
makeRemoteEvent("AliveCountUpdate")   -- server → all: aliveCount

-- Currency
makeRemoteEvent("CurrencyUpdate")     -- server → client: newCoinAmount

-- Shop
makeRemoteEvent("BuyWeapon")          -- client → server: weaponName
makeRemoteEvent("BuyWeaponResult")    -- server → client: success, reason, weaponName
makeRemoteEvent("OwnedWeaponsUpdate") -- server → client: sorted list of owned weapon names

-- Equip / loadout
makeRemoteEvent("EquipPrimaryWeapon")   -- client → server: weaponName (must be owned)
makeRemoteEvent("PrimaryWeaponUpdate")  -- server → client: equippedWeaponName

-- Daily quests
makeRemoteEvent("DailyQuestUpdate")     -- server → client: { Date, Progress, Claimed }
makeRemoteEvent("ClaimDailyQuest")      -- client → server: questId
makeRemoteEvent("ClaimDailyQuestResult")-- server → client: success, reason, questId

-- Initial-state queries (sync, avoid client/server subscribe race on player join)
makeRemoteFunction("GetCurrency")       -- client → server, returns int coin balance
makeRemoteFunction("GetOwnedWeapons")   -- client → server, returns sorted list of owned weapon names
makeRemoteFunction("GetPrimaryWeapon")  -- client → server, returns equipped weapon name
makeRemoteFunction("GetDailyQuests")    -- client → server, returns { Date, Progress, Claimed }

return events
