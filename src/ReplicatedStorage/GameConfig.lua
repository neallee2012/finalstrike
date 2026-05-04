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

-- Player settings (Sprint 8b: 200 HP rebalance)
GameConfig.MAX_HP = 200
GameConfig.MEDKIT_HEAL = 100  -- legacy fallback; new code reads GameConfig.LOOT[tier].Heal directly

-- Headshot multiplier — Sprint 8b only Sniper Type applies (D1 decision)
-- See proposals/sprint-8-200hp-balance.md §3.5 for full rationale.
GameConfig.HEADSHOT_MULTIPLIER = 2.0

-- Match phases
GameConfig.PHASE = {
	LOBBY = "Lobby",
	PVE = "PvE",
	PVP_WARNING = "PvPWarning",
	PVP = "PvP",
	MATCH_END = "MatchEnd",
}

-- Rarity tiers (UI color + DPS scaling vs Common baseline)
-- Sprint 8b (b) decision: gap converged from 3.0x → 1.9x to reduce P2W feel.
-- See proposals/30-weapon-dps-retune.md.
GameConfig.RARITY = {
	Common    = { Order = 1, DPS = 1.00, Color = Color3.fromRGB(200, 200, 200) },
	Uncommon  = { Order = 2, DPS = 1.15, Color = Color3.fromRGB( 80, 220, 100) },  -- was 1.25
	Rare      = { Order = 3, DPS = 1.30, Color = Color3.fromRGB( 80, 160, 255) },  -- was 1.55
	Epic      = { Order = 4, DPS = 1.50, Color = Color3.fromRGB(180,  90, 240) },  -- was 1.95
	Legendary = { Order = 5, DPS = 1.70, Color = Color3.fromRGB(255, 200,  60) },  -- was 2.40
	Demon     = { Order = 6, DPS = 1.90, Color = Color3.fromRGB(220,  40,  40) },  -- was 3.00
}

-- Weapon definitions (fictional names only — no real-world brands)
-- Balance: Sprint 8b (b) retune — Damage tuned so each weapon's DPS matches the
-- new rarity multiplier (1.0 / 1.15 / 1.30 / 1.50 / 1.70 / 1.90) over Common baseline.
-- Type baselines: Pistol 75 / SMG 110 / Rifle 110 / Shotgun 99 / Sniper 110 / Knife 80.
-- Hailstorm Minigun: option B (Damage 18 unchanged, SpinUp is the trade-off).
-- See proposals/30-weapon-dps-retune.md for full table + per-weapon TTK.
--
-- Sprint 9 (Option A) — shop price realignment per CEO 2026-05-04 decision:
-- tier-graduated discount aligning coin cost with post-(b) DPS reality.
--   Common 0% / Uncommon 0% / Rare -5% / Epic -10% / Legendary -20% / Demon -25%
-- See proposals/demon-shop-price-realignment.md.
GameConfig.WEAPONS = {
	-- ===== Common (5) — 1.00x DPS =====
	["Viper Mk1"]      = { Type="Pistol",  Rarity="Common",    Price=  300, Damage= 30, FireRate=0.40, MagSize=12, ReloadTime=1.5, Range=200, Spread=0.020, Auto=false },  -- was 25
	["Viper SD"]       = { Type="Pistol",  Rarity="Common",    Price=  350, Damage= 24, FireRate=0.32, MagSize=15, ReloadTime=1.6, Range=180, Spread=0.022, Auto=false },  -- was 22
	["Fang Scout"]     = { Type="Knife",   Rarity="Common",    Price=  450, Damage= 40, AttackRate=0.50, Range=8 },                                                          -- unchanged
	["Thunder Stub"]   = { Type="Shotgun", Rarity="Common",    Price=  550, Damage= 14, Pellets=6, FireRate=0.85, MagSize=4, ReloadTime=2.8, Range=40, Spread=0.12, Auto=false },  -- was 12
	["Thunder Cut"]    = { Type="Shotgun", Rarity="Common",    Price=  650, Damage= 11, Pellets=8, FireRate=0.90, MagSize=5, ReloadTime=3.0, Range=45, Spread=0.11, Auto=false },  -- unchanged

	-- ===== Uncommon (5) — 1.15x DPS =====
	["Stinger Mk2"]    = { Type="SMG",     Rarity="Uncommon",  Price= 1200, Damage= 11, FireRate=0.085, MagSize=30, ReloadTime=2.0, Range=150, Spread=0.040, Auto=true },  -- was 16
	["Stinger Tac"]    = { Type="SMG",     Rarity="Uncommon",  Price= 1350, Damage= 12, FireRate=0.095, MagSize=28, ReloadTime=2.0, Range=160, Spread=0.038, Auto=true },  -- was 18
	["Phantom Ranger"] = { Type="Rifle",   Rarity="Uncommon",  Price= 1500, Damage= 19, FireRate=0.15,  MagSize=25, ReloadTime=2.5, Range=300, Spread=0.018, Auto=true },  -- was 35
	["Wraith Scout"]   = { Type="Sniper",  Rarity="Uncommon",  Price= 1650, Damage=120, FireRate=0.95,  MagSize=8,  ReloadTime=3.0, Range=400, Spread=0.008, Auto=false }, -- was 70
	["Stinger Burst"]  = { Type="SMG",     Rarity="Uncommon",  Price= 1800, Damage=  9, FireRate=0.07,  MagSize=32, ReloadTime=2.0, Range=140, Spread=0.045, Auto=true },  -- was 14

	-- ===== Rare (5) — 1.30x DPS =====
	["Reaver-X"]       = { Type="Rifle",   Rarity="Rare",      Price= 2850, Damage= 20, FireRate=0.14,  MagSize=30, ReloadTime=2.4, Range=320, Spread=0.020, Auto=true },  -- price was 3000 (-5%)
	["Phantom Night"]  = { Type="Rifle",   Rarity="Rare",      Price= 3150, Damage= 17, FireRate=0.12,  MagSize=30, ReloadTime=2.3, Range=320, Spread=0.014, Auto=true },  -- price was 3300 (-5% rounded)
	["Thunder Guard"]  = { Type="Shotgun", Rarity="Rare",      Price= 3400, Damage= 12, Pellets=8, FireRate=0.75, MagSize=6, ReloadTime=2.7, Range=55, Spread=0.10, Auto=false },  -- price was 3600 (-5% rounded)
	["Wraith Hunter"]  = { Type="Sniper",  Rarity="Rare",      Price= 3800, Damage=172, FireRate=1.20,  MagSize=6,  ReloadTime=3.2, Range=480, Spread=0.006, Auto=false }, -- price was 4000 (-5%)
	["Thunder Triple"] = { Type="Shotgun", Rarity="Rare",      Price= 4275, Damage= 11, Pellets=9, FireRate=0.80, MagSize=3, ReloadTime=3.5, Range=50, Spread=0.13, Auto=false },  -- price was 4500 (-5%)

	-- ===== Epic (6) — 1.50x DPS =====
	["Stinger Storm"]  = { Type="SMG",     Rarity="Epic",      Price= 6750, Damage= 12, FireRate=0.075, MagSize=35, ReloadTime=1.9, Range=170, Spread=0.035, Auto=true },  -- price was 7500 (-10%)
	["Phantom Apex"]   = { Type="Rifle",   Rarity="Epic",      Price= 7200, Damage= 21, FireRate=0.13,  MagSize=30, ReloadTime=2.2, Range=340, Spread=0.013, Auto=true },  -- price was 8000 (-10%)
	["Wraith Frost"]   = { Type="Sniper",  Rarity="Epic",      Price= 7650, Damage=190, FireRate=1.15,  MagSize=6,  ReloadTime=3.0, Range=520, Spread=0.005, Auto=false }, -- price was 8500 (-10%)
	["Phantom Whisper"]= { Type="Rifle",   Rarity="Epic",      Price= 8100, Damage= 25, FireRate=0.15,  MagSize=24, ReloadTime=2.4, Range=360, Spread=0.011, Auto=true, Silent=true },  -- price was 9000 (-10%) (Silent unchanged)
	["Thunder Royal"]  = { Type="Shotgun", Rarity="Epic",      Price= 8800, Damage= 13, Pellets=8, FireRate=0.70, MagSize=6, ReloadTime=2.6, Range=60, Spread=0.09, Auto=false },  -- price was 9800 (-10% rounded)
	["Viper Left"]     = { Type="Pistol",  Rarity="Epic",      Price= 8800, Damage= 62, FireRate=0.55,  MagSize=6,  ReloadTime=1.8, Range=240, Spread=0.018, Auto=false },  -- price was 9800 (-10% rounded)

	-- ===== Legendary (5) — 1.70x DPS =====
	["Viper Aurum"]    = { Type="Pistol",  Rarity="Legendary", Price=12800, Damage= 51, FireRate=0.40,  MagSize=12, ReloadTime=1.4, Range=260, Spread=0.015, Auto=false },  -- price was 16000 (-20%)
	["Phantom Finale"] = { Type="Rifle",   Rarity="Legendary", Price=14400, Damage= 24, FireRate=0.13,  MagSize=30, ReloadTime=2.1, Range=360, Spread=0.012, Auto=true },  -- price was 18000 (-20%)
	["Wraith Apex"]    = { Type="Sniper",  Rarity="Legendary", Price=16000, Damage=206, FireRate=1.10,  MagSize=6,  ReloadTime=2.9, Range=560, Spread=0.004, Auto=false }, -- price was 20000 (-20%)
	["Thunder Crown"]  = { Type="Shotgun", Rarity="Legendary", Price=17600, Damage= 14, Pellets=8, FireRate=0.65, MagSize=6, ReloadTime=2.5, Range=65, Spread=0.085, Auto=false },  -- price was 22000 (-20%)
	["Hailstorm"]      = { Type="Minigun", Rarity="Legendary", Price=20000, Damage= 18, FireRate=0.05,  MagSize=120,ReloadTime=4.5, Range=220, Spread=0.055, Auto=true, SpinUp=0.5 },  -- price was 25000 (-20%) (Damage unchanged option B)

	-- ===== Demon (4) — 1.90x DPS =====
	["Fang Demon"]     = { Type="Knife",   Rarity="Demon",     Price=26250, Damage= 76, AttackRate=0.50, Range=10 },  -- price was 35000 (-25%)
	["Phantom Hellfire"]= {Type="Rifle",   Rarity="Demon",     Price=31500, Damage= 27, FireRate=0.13,  MagSize=30, ReloadTime=2.0, Range=380, Spread=0.012, Auto=true, Burn=true },  -- price was 42000 (-25%) (Burn unchanged)
	["Wraith Abyss"]   = { Type="Sniper",  Rarity="Demon",     Price=36000, Damage=220, FireRate=1.05,  MagSize=5,  ReloadTime=2.8, Range=600, Spread=0.003, Auto=false, Pierce=true },  -- price was 48000 (-25%) (Pierce unchanged)
	["Thunder Bloodmoon"]={Type="Shotgun", Rarity="Demon",     Price=41250, Damage= 14, Pellets=8, FireRate=0.60, MagSize=6, ReloadTime=2.3, Range=70, Spread=0.080, Auto=false },  -- price was 55000 (-25%)
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

-- NPC enemy types — Sprint 8b: HP/Damage ×2 to keep PvE pressure under 200 HP players.
-- LootTable expanded into 4-tier medkit ladder matching player's new heal options.
GameConfig.ENEMIES = {
	Patrol = {
		HP = 120,    -- was 60
		Damage = 18, -- was 10
		Speed = 12,
		DetectRange = 40,
		AttackRange = 6,
		AttackRate = 1.0,
		LootTable = { Ammo = 0.50, MedkitSmall = 0.25, Coin = 0.20 },
		Color = Color3.fromRGB(120, 120, 120),
	},
	Armored = {
		HP = 300,    -- was 150
		Damage = 28, -- was 15
		Speed = 8,
		DetectRange = 35,
		AttackRange = 7,
		AttackRate = 1.5,
		LootTable = { Ammo = 0.50, Medkit = 0.35, Coin = 0.35 },
		Color = Color3.fromRGB(80, 80, 100),
	},
	Elite = {
		HP = 500,    -- was 250
		Damage = 40, -- was 25
		Speed = 14,
		DetectRange = 50,
		AttackRange = 8,
		AttackRate = 0.8,
		LootTable = { Ammo = 0.40, MedkitLarge = 0.50, MedkitFull = 0.05, Coin = 0.50 },
		Color = Color3.fromRGB(180, 40, 40),
	},
}

-- Loot pickup values — Sprint 8b: 4-tier medkit ladder (200 HP rebalance).
-- Weapon drops remain removed (weapons are shop-only).
GameConfig.LOOT = {
	Ammo        = { Amount = 15 },
	MedkitSmall = { Heal = 50 },   -- 25% HP regen, common (Patrol drop)
	Medkit      = { Heal = 100 },  -- 50% HP regen, standard (Armored drop) — was Heal=50 in Sprint 7
	MedkitLarge = { Heal = 150 },  -- 75% HP regen, rare (Elite drop)
	MedkitFull  = { Heal = 200 },  -- full restore, ultra-rare (Elite 5% drop)
	Coin        = { Amount = 10 },
}

return GameConfig
