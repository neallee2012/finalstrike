-- GameConfig.lua (ReplicatedStorage)
-- Shared configuration for Final Strike

local GameConfig = {}

-- Match settings
GameConfig.MIN_PLAYERS = 1          -- 1 for testing, change to 2+ for production
GameConfig.MAX_PLAYERS = 12
GameConfig.PVE_DURATION = 180       -- seconds
GameConfig.PVP_COUNTDOWN = 10       -- seconds (warning before PvP starts)
GameConfig.PVP_DURATION = 300       -- seconds (5 min PvP cap; ends with current alive winner)
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

-- Rarity tiers (UI color + DPS scaling vs Common baseline)
GameConfig.RARITY = {
	Common    = { Order = 1, DPS = 1.00, Color = Color3.fromRGB(200, 200, 200) },
	Uncommon  = { Order = 2, DPS = 1.25, Color = Color3.fromRGB( 80, 220, 100) },
	Rare      = { Order = 3, DPS = 1.55, Color = Color3.fromRGB( 80, 160, 255) },
	Epic      = { Order = 4, DPS = 1.95, Color = Color3.fromRGB(180,  90, 240) },
	Legendary = { Order = 5, DPS = 2.40, Color = Color3.fromRGB(255, 200,  60) },
	Demon     = { Order = 6, DPS = 3.00, Color = Color3.fromRGB(220,  40,  40) },
}

-- Weapon definitions (fictional names only — no real-world brands)
-- Balance: Damage tuned so each weapon's DPS matches its rarity's DPS multiplier vs the
-- Common baseline (Viper Mk1 = 62.5 DPS pistol, Thunder Stub = 90 DPS shotgun, etc.)
GameConfig.WEAPONS = {
	-- ===== Common (5) =====
	["Viper Mk1"]      = { Type="Pistol",  Rarity="Common",    Price=  300, Damage= 25, FireRate=0.40, MagSize=12, ReloadTime=1.5, Range=200, Spread=0.020, Auto=false },
	["Viper SD"]       = { Type="Pistol",  Rarity="Common",    Price=  350, Damage= 22, FireRate=0.32, MagSize=15, ReloadTime=1.6, Range=180, Spread=0.022, Auto=false },
	["Fang Scout"]     = { Type="Knife",   Rarity="Common",    Price=  450, Damage= 40, AttackRate=0.50, Range=8 },
	["Thunder Stub"]   = { Type="Shotgun", Rarity="Common",    Price=  550, Damage= 12, Pellets=6, FireRate=0.85, MagSize=4, ReloadTime=2.8, Range=40, Spread=0.12, Auto=false },
	["Thunder Cut"]    = { Type="Shotgun", Rarity="Common",    Price=  650, Damage= 11, Pellets=8, FireRate=0.90, MagSize=5, ReloadTime=3.0, Range=45, Spread=0.11, Auto=false },

	-- ===== Uncommon (5) — 1.25x DPS =====
	["Stinger Mk2"]    = { Type="SMG",     Rarity="Uncommon",  Price= 1200, Damage= 16, FireRate=0.085, MagSize=30, ReloadTime=2.0, Range=150, Spread=0.040, Auto=true },
	["Stinger Tac"]    = { Type="SMG",     Rarity="Uncommon",  Price= 1350, Damage= 18, FireRate=0.095, MagSize=28, ReloadTime=2.0, Range=160, Spread=0.038, Auto=true },
	["Phantom Ranger"] = { Type="Rifle",   Rarity="Uncommon",  Price= 1500, Damage= 35, FireRate=0.15,  MagSize=25, ReloadTime=2.5, Range=300, Spread=0.018, Auto=true },
	["Wraith Scout"]   = { Type="Sniper",  Rarity="Uncommon",  Price= 1650, Damage= 70, FireRate=0.95,  MagSize=8,  ReloadTime=3.0, Range=400, Spread=0.008, Auto=false },
	["Stinger Burst"]  = { Type="SMG",     Rarity="Uncommon",  Price= 1800, Damage= 14, FireRate=0.07,  MagSize=32, ReloadTime=2.0, Range=140, Spread=0.045, Auto=true },

	-- ===== Rare (5) — 1.55x DPS =====
	["Reaver-X"]       = { Type="Rifle",   Rarity="Rare",      Price= 3000, Damage= 42, FireRate=0.14,  MagSize=30, ReloadTime=2.4, Range=320, Spread=0.020, Auto=true },
	["Phantom Night"]  = { Type="Rifle",   Rarity="Rare",      Price= 3300, Damage= 38, FireRate=0.12,  MagSize=30, ReloadTime=2.3, Range=320, Spread=0.014, Auto=true },
	["Thunder Guard"]  = { Type="Shotgun", Rarity="Rare",      Price= 3600, Damage= 14, Pellets=8, FireRate=0.75, MagSize=6, ReloadTime=2.7, Range=55, Spread=0.10, Auto=false },
	["Wraith Hunter"]  = { Type="Sniper",  Rarity="Rare",      Price= 4000, Damage=110, FireRate=1.20,  MagSize=6,  ReloadTime=3.2, Range=480, Spread=0.006, Auto=false },
	["Thunder Triple"] = { Type="Shotgun", Rarity="Rare",      Price= 4500, Damage= 15, Pellets=9, FireRate=0.80, MagSize=3, ReloadTime=3.5, Range=50, Spread=0.13, Auto=false },

	-- ===== Epic (6) — 1.95x DPS =====
	["Stinger Storm"]  = { Type="SMG",     Rarity="Epic",      Price= 7500, Damage= 22, FireRate=0.075, MagSize=35, ReloadTime=1.9, Range=170, Spread=0.035, Auto=true },
	["Phantom Apex"]   = { Type="Rifle",   Rarity="Epic",      Price= 8000, Damage= 50, FireRate=0.13,  MagSize=30, ReloadTime=2.2, Range=340, Spread=0.013, Auto=true },
	["Wraith Frost"]   = { Type="Sniper",  Rarity="Epic",      Price= 8500, Damage=140, FireRate=1.15,  MagSize=6,  ReloadTime=3.0, Range=520, Spread=0.005, Auto=false },
	["Phantom Whisper"]= { Type="Rifle",   Rarity="Epic",      Price= 9000, Damage= 55, FireRate=0.15,  MagSize=24, ReloadTime=2.4, Range=360, Spread=0.011, Auto=true, Silent=true },
	["Thunder Royal"]  = { Type="Shotgun", Rarity="Epic",      Price= 9800, Damage= 18, Pellets=8, FireRate=0.70, MagSize=6, ReloadTime=2.6, Range=60, Spread=0.09, Auto=false },
	["Viper Left"]     = { Type="Pistol",  Rarity="Epic",      Price= 9800, Damage= 70, FireRate=0.55,  MagSize=6,  ReloadTime=1.8, Range=240, Spread=0.018, Auto=false },

	-- ===== Legendary (5) — 2.40x DPS =====
	["Viper Aurum"]    = { Type="Pistol",  Rarity="Legendary", Price=16000, Damage= 60, FireRate=0.40,  MagSize=12, ReloadTime=1.4, Range=260, Spread=0.015, Auto=false },
	["Phantom Finale"] = { Type="Rifle",   Rarity="Legendary", Price=18000, Damage= 60, FireRate=0.13,  MagSize=30, ReloadTime=2.1, Range=360, Spread=0.012, Auto=true },
	["Wraith Apex"]    = { Type="Sniper",  Rarity="Legendary", Price=20000, Damage=170, FireRate=1.10,  MagSize=6,  ReloadTime=2.9, Range=560, Spread=0.004, Auto=false },
	["Thunder Crown"]  = { Type="Shotgun", Rarity="Legendary", Price=22000, Damage= 22, Pellets=8, FireRate=0.65, MagSize=6, ReloadTime=2.5, Range=65, Spread=0.085, Auto=false },
	["Hailstorm"]      = { Type="Minigun", Rarity="Legendary", Price=25000, Damage= 18, FireRate=0.05,  MagSize=120,ReloadTime=4.5, Range=220, Spread=0.055, Auto=true, SpinUp=0.5 },

	-- ===== Demon (4) — 3.00x DPS =====
	["Fang Demon"]     = { Type="Knife",   Rarity="Demon",     Price=35000, Damage=120, AttackRate=0.50, Range=10 },
	["Phantom Hellfire"]= {Type="Rifle",   Rarity="Demon",     Price=42000, Damage= 75, FireRate=0.13,  MagSize=30, ReloadTime=2.0, Range=380, Spread=0.012, Auto=true, Burn=true },
	["Wraith Abyss"]   = { Type="Sniper",  Rarity="Demon",     Price=48000, Damage=210, FireRate=1.05,  MagSize=5,  ReloadTime=2.8, Range=600, Spread=0.003, Auto=false, Pierce=true },
	["Thunder Bloodmoon"]={Type="Shotgun", Rarity="Demon",     Price=55000, Damage= 28, Pellets=8, FireRate=0.60, MagSize=6, ReloadTime=2.3, Range=70, Spread=0.080, Auto=false },
}

-- Default starter weapons — every player owns these from the start, no purchase needed
GameConfig.STARTER_WEAPONS = { "Viper Mk1", "Fang Scout" }

-- Economy: per-action rewards + per-match caps (anti-farming)
GameConfig.ECONOMY = {
	Rewards = {
		MatchComplete   = 50,
		SurvivePerMin   = 20,
		KillPatrolNPC   = 10,
		KillArmoredNPC  = 25,
		KillEliteNPC    = 60,
		KillPlayer      = 100,
		AssistPlayer    = 40,
		PlacementTop5   = 150,
		PlacementTop3   = 250,
		PlacementWin    = 500,
		FirstWinDaily   = 300,   -- bonus on top of PlacementWin
	},
	MatchCaps = {
		NpcKills        = 300,   -- sum of all NPC kill rewards
		Survival        = 200,
		PlayerKills     = 600,
		MatchTotal      = 1500,  -- hard cap regardless of category breakdown
	},
	-- Training/practice modes (future) — daily soft cap separate from match cap
	TrainingDailyCap   = 100,
}

-- Daily quests: each player tracks progress, claims when target met. Resets at UTC midnight.
-- Rewards bypass MatchTotal cap (handled by CurrencyService.addDailyReward).
-- EventType strings are emitted by hooks in MatchManager / NPCSystem / LootSystem.
GameConfig.DAILY_QUESTS = {
	{ Id = "play3matches",   Name = "完成 3 場比賽",     EventType = "MatchComplete", Target = 3,   Reward = 300 },
	{ Id = "kill20npcs",     Name = "擊敗 20 隻 NPC",    EventType = "NpcKill",       Target = 20,  Reward = 250 },
	{ Id = "survive10min",   Name = "存活總共 10 分鐘",  EventType = "SurviveSeconds",Target = 600, Reward = 300 },
	{ Id = "kill3players",   Name = "擊敗 3 位玩家",     EventType = "PlayerKill",    Target = 3,   Reward = 400 },
	{ Id = "top3once",       Name = "進入前 3 名一次",   EventType = "Top3Placement", Target = 1,   Reward = 500 },
	{ Id = "pickup5loot",    Name = "拾取 5 個戰利品",   EventType = "LootPickup",    Target = 5,   Reward = 250 },
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
		LootTable = { Ammo = 0.7, Coin = 0.3 },
		Color = Color3.fromRGB(120, 120, 120),
	},
	Armored = {
		HP = 150,
		Damage = 15,
		Speed = 8,
		DetectRange = 35,
		AttackRange = 7,
		AttackRate = 1.5,
		LootTable = { Ammo = 0.5, Coin = 0.3, Medkit = 0.2 },
		Color = Color3.fromRGB(80, 80, 100),
	},
	Elite = {
		HP = 250,
		Damage = 25,
		Speed = 14,
		DetectRange = 50,
		AttackRange = 8,
		AttackRate = 0.8,
		LootTable = { Ammo = 0.3, Coin = 0.4, Medkit = 0.3 },
		Color = Color3.fromRGB(180, 40, 40),
	},
}

-- Loot pickup values (Weapon dropped removed — weapons are shop-only now)
GameConfig.LOOT = {
	Ammo = { Amount = 15 },
	Medkit = { Heal = 50 },
	Coin = { Amount = 10 },
}

return GameConfig
