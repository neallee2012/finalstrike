-- GameConfig.lua (ReplicatedStorage)
-- Shared configuration for Final Strike

local GameConfig = {}

-- Match settings
GameConfig.MIN_PLAYERS = 1          -- 1 for testing, change to 2+ for production
GameConfig.MAX_PLAYERS = 12
GameConfig.PVE_DURATION = 180       -- seconds
GameConfig.PVP_COUNTDOWN = 10       -- seconds
GameConfig.LOBBY_COUNTDOWN = 10     -- seconds before match starts
GameConfig.SPAWN_PROTECTION = 3     -- seconds of NPC-damage immunity after teleport to arena

-- Player settings
GameConfig.MAX_HP = 100
GameConfig.MEDKIT_HEAL = 50

-- Match phases
GameConfig.PHASE = {
	LOBBY = "Lobby",
	PVE = "PvE",
	PVP_WARNING = "PvPWarning",
	PVP = "PvP",
	MATCH_END = "MatchEnd",
}

-- Weapon definitions (fictional names only)
GameConfig.WEAPONS = {
	Viper = {
		Type = "Pistol",
		Damage = 25,
		FireRate = 0.4,       -- seconds between shots
		MagSize = 12,
		ReloadTime = 1.5,
		Range = 200,
		Spread = 0.02,
		Auto = false,
	},
	Stinger = {
		Type = "SMG",
		Damage = 15,
		FireRate = 0.08,
		MagSize = 30,
		ReloadTime = 2.0,
		Range = 150,
		Spread = 0.04,
		Auto = true,
	},
	Phantom = {
		Type = "Rifle",
		Damage = 30,
		FireRate = 0.15,
		MagSize = 25,
		ReloadTime = 2.5,
		Range = 300,
		Spread = 0.015,
		Auto = true,
	},
	Thunder = {
		Type = "Shotgun",
		Damage = 12,           -- per pellet
		Pellets = 8,
		FireRate = 0.8,
		MagSize = 6,
		ReloadTime = 3.0,
		Range = 50,
		Spread = 0.1,
		Auto = false,
	},
	Wraith = {
		Type = "Sniper",
		Damage = 90,
		FireRate = 1.5,
		MagSize = 5,
		ReloadTime = 3.5,
		Range = 500,
		Spread = 0.005,
		Auto = false,
	},
	Fang = {
		Type = "Knife",
		Damage = 40,
		AttackRate = 0.5,
		Range = 8,
	},
}

-- NPC enemy types
GameConfig.ENEMIES = {
	Patrol = {
		HP = 60,
		Damage = 10,
		Speed = 12,
		DetectRange = 40,
		AttackRange = 6,
		AttackRate = 1.0,
		LootTable = { Ammo = 0.6, Coin = 0.3, Medkit = 0.1 },
		Color = Color3.fromRGB(120, 120, 120),
	},
	Armored = {
		HP = 150,
		Damage = 15,
		Speed = 8,
		DetectRange = 35,
		AttackRange = 7,
		AttackRate = 1.5,
		LootTable = { Ammo = 0.4, Coin = 0.3, Medkit = 0.2, Weapon = 0.1 },
		Color = Color3.fromRGB(80, 80, 100),
	},
	Elite = {
		HP = 250,
		Damage = 25,
		Speed = 14,
		DetectRange = 50,
		AttackRange = 8,
		AttackRate = 0.8,
		LootTable = { Ammo = 0.2, Coin = 0.2, Medkit = 0.3, Weapon = 0.3 },
		Color = Color3.fromRGB(180, 40, 40),
	},
}

-- Loot pickup values
GameConfig.LOOT = {
	Ammo = { Amount = 15 },
	Medkit = { Heal = 50 },
	Coin = { Amount = 10 },
}

return GameConfig
