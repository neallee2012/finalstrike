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

-- Magazine economy. Players enter a match (or select a training weapon) with
-- five spare magazines; ammo pickups add reserve rounds up to fifteen magazines.
GameConfig.STARTING_RESERVE_MAGAZINES = 5
GameConfig.MAX_RESERVE_MAGAZINES = 15

-- All ranged weapons use the reference-sheet headshot rule. Per-pellet weapons
-- apply this rounded value to every pellet that hits the Head.
GameConfig.HEADSHOT_MULTIPLIER = 1.25

function GameConfig.getHeadshotDamage(config)
	if not config or type(config.Damage) ~= "number" then return 0 end
	return math.floor(config.Damage * GameConfig.HEADSHOT_MULTIPLIER + 0.5)
end

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

-- Sixteen fictional weapons matching the approved 8-primary / 8-secondary
-- visual roster. Style selects a distinct WeaponVisuals builder; Type remains
-- the gameplay contract used by firing, reload, recoil, and headshot systems.
GameConfig.WEAPONS = {
	-- Primary weapons
	["Phantom Ranger"]   = { Style="AssaultRifle",   Slot="Primary",   Type="Rifle",   Rarity="Common",    Price=  500, Damage=24, FireRate=0.10, MagSize=30, ReloadTime=2.4, Range=310, Spread=0.018, Auto=true },
	["Stinger Vector"]   = { Style="SMG",            Slot="Primary",   Type="SMG",     Rarity="Uncommon",  Price= 1200, Damage=20, FireRate=0.07, MagSize=32, ReloadTime=2.0, Range=160, Spread=0.038, Auto=true },
	["Thunder Pump"]     = { Style="PumpShotgun",    Slot="Primary",   Type="Shotgun", Rarity="Common",    Price=  700, Damage=13, Pellets=8, FireRate=0.85, MagSize=5,  ReloadTime=3.0, Range=48,  Spread=0.11,  Auto=false },
	["Wraith Longshot"]  = { Style="Sniper",         Slot="Primary",   Type="Sniper",  Rarity="Rare",      Price= 3800, Damage=120,FireRate=1.50, MagSize=6,  ReloadTime=3.2, Range=500, Spread=0.006, Auto=false },
	["Hailstorm LMG"]    = { Style="LMG",            Slot="Primary",   Type="Minigun", Rarity="Legendary", Price=18000, Damage=22, FireRate=0.12, MagSize=100,ReloadTime=4.2, Range=230, Spread=0.05,  Auto=true, SpinUp=0.4 },
	["Phantom Vanguard"] = { Style="BattleRifle",    Slot="Primary",   Type="Rifle",   Rarity="Rare",      Price= 3200, Damage=36, FireRate=0.28, MagSize=24, ReloadTime=2.6, Range=360, Spread=0.014, Auto=true },
	["Thunder Tempest"]  = { Style="RapidShotgun",   Slot="Primary",   Type="Shotgun", Rarity="Epic",      Price= 8200, Damage=10, Pellets=8, FireRate=0.40, MagSize=8,  ReloadTime=2.8, Range=55,  Spread=0.095, Auto=true },
	["Wraith Marksman"]  = { Style="PrecisionRifle", Slot="Primary",   Type="Sniper",  Rarity="Epic",      Price= 7600, Damage=38, FireRate=0.35, MagSize=10, ReloadTime=2.8, Range=440, Spread=0.005, Auto=false },

	-- Secondary weapons
	["Viper Mk1"]        = { Style="StandardPistol", Slot="Secondary", Type="Pistol",  Rarity="Common",    Price=  300, Damage=18, FireRate=0.22, MagSize=12, ReloadTime=1.5, Range=200, Spread=0.020, Auto=false },
	["Viper Outlaw"]     = { Style="Revolver",       Slot="Secondary", Type="Pistol",  Rarity="Uncommon",  Price= 1500, Damage=30, FireRate=0.90, MagSize=6,  ReloadTime=2.2, Range=230, Spread=0.018, Auto=false },
	["Viper Talon"]      = { Style="DesertPistol",   Slot="Secondary", Type="Pistol",  Rarity="Rare",      Price= 2800, Damage=25, FireRate=1.25, MagSize=8,  ReloadTime=2.0, Range=245, Spread=0.017, Auto=false },
	["Thunder Handcannon"]= {Style="HeavyPistol",    Slot="Secondary", Type="Pistol",  Rarity="Rare",      Price= 4200, Damage=50, FireRate=2.00, MagSize=7,  ReloadTime=2.4, Range=270, Spread=0.016, Auto=false },
	["Viper Swift"]      = { Style="CompactPistol",  Slot="Secondary", Type="Pistol",  Rarity="Common",    Price=  450, Damage=14, FireRate=0.18, MagSize=14, ReloadTime=1.4, Range=165, Spread=0.028, Auto=false },
	["Viper Trinity"]    = { Style="TriplePistol",   Slot="Secondary", Type="Pistol",  Rarity="Epic",      Price= 7800, Damage=15, Pellets=3, FireRate=0.75, MagSize=9,  ReloadTime=2.3, Range=210, Spread=0.025, Auto=false },
	["Stinger Sidearm"]  = { Style="MachinePistol",  Slot="Secondary", Type="SMG",     Rarity="Uncommon",  Price= 1800, Damage=11, FireRate=0.06, MagSize=24, ReloadTime=2.0, Range=125, Spread=0.05,  Auto=true },
	["Thunder Twin"]     = { Style="TwinPistol",     Slot="Secondary", Type="Pistol",  Rarity="Legendary", Price=15000, Damage=37, Pellets=2, FireRate=1.20, MagSize=8,  ReloadTime=2.5, Range=235, Spread=0.022, Auto=false },
}

-- Stable visual order matching the approved reference sheet.
GameConfig.WEAPON_ORDER = {
	"Phantom Ranger",
	"Stinger Vector",
	"Thunder Pump",
	"Wraith Longshot",
	"Hailstorm LMG",
	"Phantom Vanguard",
	"Thunder Tempest",
	"Wraith Marksman",
	"Viper Mk1",
	"Viper Outlaw",
	"Viper Talon",
	"Thunder Handcannon",
	"Viper Swift",
	"Viper Trinity",
	"Stinger Sidearm",
	"Thunder Twin",
}

-- Published R15 reload animations by matching weapon type. WeaponClient scales
-- each clip to the weapon's ReloadTime; unlisted types use procedural R15 poses.
GameConfig.RELOAD_ANIMATION_IDS = {
	Pistol = 102338606855201,
	Rifle = 99673558497035,
	Shotgun = 70858423637669,
}

-- One starter per visual category; the shop still chooses a single active weapon.
GameConfig.STARTER_WEAPONS = { "Phantom Ranger", "Viper Mk1" }

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
		AttackRange = 9,    -- issue #24: was 6 (≈1.8m); now ~2.7m so NPCs engage at the spec'd 3m
		AttackRate = 1.0,
		LootTable = { Ammo = 0.50, MedkitSmall = 0.25, Coin = 0.20 },
		Color = Color3.fromRGB(120, 120, 120),
	},
	Armored = {
		HP = 300,    -- was 150
		Damage = 28, -- was 15
		Speed = 8,
		DetectRange = 35,
		AttackRange = 10,   -- issue #24: was 7 (≈2.1m); now ~3m
		AttackRate = 1.5,
		LootTable = { Ammo = 0.50, Medkit = 0.35, Coin = 0.35 },
		Color = Color3.fromRGB(80, 80, 100),
	},
	Elite = {
		HP = 500,    -- was 250
		Damage = 40, -- was 25
		Speed = 14,
		DetectRange = 50,
		AttackRange = 11,   -- issue #24: was 8 (≈2.4m); Elite gets longest reach ~3.3m
		AttackRate = 0.8,
		LootTable = { Ammo = 0.40, MedkitLarge = 0.50, MedkitFull = 0.05, Coin = 0.50 },
		Color = Color3.fromRGB(180, 40, 40),
	},
}

-- (#53) Training-arena NPC behavior profile. Live-match values (per-enemy
-- Speed / DetectRange above) are untouched; these only apply when a Tool is
-- spawned via NPCSystem.spawnDummyAt and stamped with IsTrainingDummy=true.
-- The goal is "observable practice target", not "live combat at half speed":
--   1) walk slowly so visuals are readable
--   2) only react when the player is genuinely close — no across-arena aggro
--   3) stay near the spawn marker (small patrol radius + leash on chase)
-- AttackRate / AttackRange / HP / Damage stay at match values so combat is
-- still meaningful once the player closes in.
GameConfig.TRAINING_SPEED_MULTIPLIER = 0.3
GameConfig.TRAINING_DETECT_RANGE    = 18   -- vs live 35-50; player must approach
GameConfig.TRAINING_PATROL_RADIUS   = 6    -- vs live ±30; tight wander around home
GameConfig.TRAINING_LEASH_RADIUS    = 20   -- abort chase if pulled past this from home

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
