-- GameEvents.lua (ReplicatedStorage)
-- Remote events and functions for client-server communication

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

return events
