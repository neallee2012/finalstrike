--!strict
-- verification/sprint-8b-runtime-checks.lua
--
-- Reproducible balance-contract runtime verification.
-- Originally a Sprint 8b artifact (filename kept for backref stability);
-- now also covers the current 16-weapon visual roster.
--
-- Usage:
--   1. Open the Final Strike Studio place file
--   2. Press Play to start a single-player playtest
--   3. Wait until you reach the PvE phase (after walking onto StartMatchPad
--      and the lobby countdown). NPCs should be spawned.
--   4. Open the Studio command bar (View → Command Bar)
--   5. Paste this entire file's contents and press Enter
--   6. Check Output window for the [VERIFY] lines — every check should
--      end with "OK" (green-ish prefix). Any "FAIL" prefix means runtime
--      drifted from a covered design contract.
--
-- Equivalently, run via execute_luau over MCP (the script's `return`
-- gives a structured `{ passed, failed, failures, hasNpcs, hadHud }`).
--
-- This script is read-only — it inspects state but doesn't mutate anything.
--
-- Sources of truth checked:
--   - GameConfig.WEAPON_ORDER (16-weapon roster)
--   - WeaponVisuals (shared Tool / ViewportFrame models)
--   - receipts/sprint-8b-200hp-rebalance.md
--   - receipts/sprint-9a-demon-price-realign.md
--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponVisuals = require(ReplicatedStorage:WaitForChild("WeaponVisuals"))

local pass, fail = 0, 0
local failures = {}  -- list of {label, expected, actual} for structured return
local function check(label: string, actual: any, expected: any)
	local ok = actual == expected
	if ok then
		pass = pass + 1
		print(string.format("[VERIFY OK] %s = %s", label, tostring(actual)))
	else
		fail = fail + 1
		local msg = string.format("%s expected=%s actual=%s",
			label, tostring(expected), tostring(actual))
		table.insert(failures, { label = label, expected = tostring(expected), actual = tostring(actual) })
		warn("[VERIFY FAIL] " .. msg)
	end
end

-- ============================================================
-- 1. Player base config
-- ============================================================
check("MAX_HP", GameConfig.MAX_HP, 200)
check("HEADSHOT_MULTIPLIER", GameConfig.HEADSHOT_MULTIPLIER, 1.25)

-- ============================================================
-- 2. Rarity DPS multipliers (CEO decision b: gap 3.0x → 1.9x)
-- ============================================================
check("RARITY.Common.DPS",    GameConfig.RARITY.Common.DPS,    1.00)
check("RARITY.Uncommon.DPS",  GameConfig.RARITY.Uncommon.DPS,  1.15)
check("RARITY.Rare.DPS",      GameConfig.RARITY.Rare.DPS,      1.30)
check("RARITY.Epic.DPS",      GameConfig.RARITY.Epic.DPS,      1.50)
check("RARITY.Legendary.DPS", GameConfig.RARITY.Legendary.DPS, 1.70)
check("RARITY.Demon.DPS",     GameConfig.RARITY.Demon.DPS,     1.90)

-- ============================================================
-- 3. Current 16-weapon config + distinct shared models
-- ============================================================
local weaponExpect = {
	["Phantom Ranger"]    = { Damage=24,  Head=30,  FireRate=0.10, Price=500,   Style="AssaultRifle",   Slot="Primary" },
	["Stinger Vector"]    = { Damage=20,  Head=25,  FireRate=0.07, Price=1200,  Style="SMG",            Slot="Primary" },
	["Thunder Pump"]      = { Damage=13,  Head=16,  FireRate=0.85, Price=700,   Style="PumpShotgun",    Slot="Primary" },
	["Wraith Longshot"]   = { Damage=120, Head=150, FireRate=1.50, Price=3800,  Style="Sniper",         Slot="Primary" },
	["Hailstorm LMG"]     = { Damage=22,  Head=28,  FireRate=0.12, Price=18000, Style="LMG",            Slot="Primary" },
	["Phantom Vanguard"]  = { Damage=36,  Head=45,  FireRate=0.28, Price=3200,  Style="BattleRifle",    Slot="Primary" },
	["Thunder Tempest"]   = { Damage=10,  Head=13,  FireRate=0.40, Price=8200,  Style="RapidShotgun",   Slot="Primary" },
	["Wraith Marksman"]   = { Damage=38,  Head=48,  FireRate=0.35, Price=7600,  Style="PrecisionRifle", Slot="Primary" },
	["Viper Mk1"]         = { Damage=18,  Head=23,  FireRate=0.22, Price=300,   Style="StandardPistol", Slot="Secondary" },
	["Viper Outlaw"]      = { Damage=30,  Head=38,  FireRate=0.90, Price=1500,  Style="Revolver",       Slot="Secondary" },
	["Viper Talon"]       = { Damage=25,  Head=31,  FireRate=1.25, Price=2800,  Style="DesertPistol",   Slot="Secondary" },
	["Thunder Handcannon"]= { Damage=50,  Head=63,  FireRate=2.00, Price=4200,  Style="HeavyPistol",    Slot="Secondary" },
	["Viper Swift"]       = { Damage=14,  Head=18,  FireRate=0.18, Price=450,   Style="CompactPistol",  Slot="Secondary" },
	["Viper Trinity"]     = { Damage=15,  Head=19,  FireRate=0.75, Price=7800,  Style="TriplePistol",   Slot="Secondary" },
	["Stinger Sidearm"]   = { Damage=11,  Head=14,  FireRate=0.06, Price=1800,  Style="MachinePistol",  Slot="Secondary" },
	["Thunder Twin"]      = { Damage=37,  Head=46,  FireRate=1.20, Price=15000, Style="TwinPistol",     Slot="Secondary" },
}

local weaponCount = 0
for _ in pairs(GameConfig.WEAPONS) do weaponCount = weaponCount + 1 end
check("WEAPONS count", weaponCount, 16)
check("WEAPON_ORDER count", #GameConfig.WEAPON_ORDER, 16)

local seenStyles = {}
local slotCounts = { Primary = 0, Secondary = 0 }
for index, name in ipairs(GameConfig.WEAPON_ORDER) do
	local expected = weaponExpect[name]
	local cfg = GameConfig.WEAPONS[name]
	check(("WEAPON_ORDER[%d] is expected"):format(index), expected ~= nil, true)
	check("WEAPONS." .. name .. ".Damage", cfg and cfg.Damage, expected and expected.Damage)
	check("WEAPONS." .. name .. ".HeadDamage", cfg and GameConfig.getHeadshotDamage(cfg), expected and expected.Head)
	check("WEAPONS." .. name .. ".FireRate", cfg and cfg.FireRate, expected and expected.FireRate)
	check("WEAPONS." .. name .. ".Price", cfg and cfg.Price, expected and expected.Price)
	check("WEAPONS." .. name .. ".Style", cfg and cfg.Style, expected and expected.Style)
	check("WEAPONS." .. name .. ".Slot", cfg and cfg.Slot, expected and expected.Slot)
	local style = cfg and cfg.Style
	local slot = cfg and cfg.Slot
	check("WEAPONS." .. name .. ".Style unique", style and seenStyles[style] or nil, nil)
	if style then seenStyles[style] = name end
	if slot then slotCounts[slot] = (slotCounts[slot] or 0) + 1 end

	local model = WeaponVisuals.buildModel(name, cfg)
	local handle = model and model:FindFirstChild("Handle")
	local meshCount = 0
	local basePartCount = 0
	if model then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("MeshPart") then meshCount = meshCount + 1 end
			if descendant:IsA("BasePart") then basePartCount = basePartCount + 1 end
		end
	end
	check("WeaponVisuals." .. name .. ".model", model ~= nil, true)
	check("WeaponVisuals." .. name .. ".Handle", handle and handle:IsA("MeshPart"), true)
	check("WeaponVisuals." .. name .. ".single MeshPart", meshCount, 1)
	check("WeaponVisuals." .. name .. ".no extra Parts", basePartCount, 1)
	check("WeaponVisuals." .. name .. ".Muzzle", handle and handle:FindFirstChild("Muzzle") ~= nil, true)
	check(
		"WeaponVisuals." .. name .. ".Muzzle local +Z",
		handle and handle:FindFirstChild("Muzzle") and handle.Muzzle.Position.Z > 0,
		true
	)
	if model then model:Destroy() end
end
check("Primary weapon count", slotCounts.Primary, 8)
check("Secondary weapon count", slotCounts.Secondary, 8)
check("Wraith Longshot.Type", GameConfig.WEAPONS["Wraith Longshot"].Type, "Sniper")
check("Wraith Marksman.Type", GameConfig.WEAPONS["Wraith Marksman"].Type, "Sniper")

-- ============================================================
-- 4. NPC HP / Damage ×2 + 4-tier loot drop tables
-- ============================================================
check("ENEMIES.Patrol.HP",      GameConfig.ENEMIES.Patrol.HP,      120)
check("ENEMIES.Patrol.Damage",  GameConfig.ENEMIES.Patrol.Damage,  18)
check("ENEMIES.Armored.HP",     GameConfig.ENEMIES.Armored.HP,     300)
check("ENEMIES.Armored.Damage", GameConfig.ENEMIES.Armored.Damage, 28)
check("ENEMIES.Elite.HP",       GameConfig.ENEMIES.Elite.HP,       500)
check("ENEMIES.Elite.Damage",   GameConfig.ENEMIES.Elite.Damage,   40)

-- LootTable presence (4-tier medkit ladder)
check("Patrol.LootTable.MedkitSmall",  GameConfig.ENEMIES.Patrol.LootTable.MedkitSmall, 0.25)
check("Armored.LootTable.Medkit",      GameConfig.ENEMIES.Armored.LootTable.Medkit,    0.35)
check("Elite.LootTable.MedkitLarge",   GameConfig.ENEMIES.Elite.LootTable.MedkitLarge, 0.50)
check("Elite.LootTable.MedkitFull",    GameConfig.ENEMIES.Elite.LootTable.MedkitFull,  0.05)

-- Weapon drops removed (commit 5928547 + Sprint 8b unchanged)
check("Patrol.LootTable.Weapon (removed)",  GameConfig.ENEMIES.Patrol.LootTable.Weapon,  nil)
check("Armored.LootTable.Weapon (removed)", GameConfig.ENEMIES.Armored.LootTable.Weapon, nil)
check("Elite.LootTable.Weapon (removed)",   GameConfig.ENEMIES.Elite.LootTable.Weapon,   nil)

-- ============================================================
-- 5. LOOT pickup definitions (4-tier medkit + ammo + coin)
-- ============================================================
check("LOOT.MedkitSmall.Heal", GameConfig.LOOT.MedkitSmall and GameConfig.LOOT.MedkitSmall.Heal, 50)
check("LOOT.Medkit.Heal",      GameConfig.LOOT.Medkit and GameConfig.LOOT.Medkit.Heal,           100)
check("LOOT.MedkitLarge.Heal", GameConfig.LOOT.MedkitLarge and GameConfig.LOOT.MedkitLarge.Heal, 150)
check("LOOT.MedkitFull.Heal",  GameConfig.LOOT.MedkitFull and GameConfig.LOOT.MedkitFull.Heal,   200)
check("LOOT.Ammo.Amount",      GameConfig.LOOT.Ammo.Amount, 15)
check("LOOT.Coin.Amount",      GameConfig.LOOT.Coin.Amount, 10)

-- ============================================================
-- 6. Runtime spawn check (only meaningful during PvE phase)
-- ============================================================
local npcsByType = { Patrol = 0, Armored = 0, Elite = 0 }
local npcAttrOK = { Patrol = true, Armored = true, Elite = true }
for _, m in ipairs(workspace:GetChildren()) do
	if m:IsA("Model") then
		local t = m:GetAttribute("EnemyType")
		if t and npcsByType[t] ~= nil then
			npcsByType[t] = npcsByType[t] + 1
			-- Verify each NPC's runtime HP / Damage matches GameConfig
			if m:GetAttribute("HP") ~= GameConfig.ENEMIES[t].HP then npcAttrOK[t] = false end
			if m:GetAttribute("Damage") ~= GameConfig.ENEMIES[t].Damage then npcAttrOK[t] = false end
		end
	end
end

local hasNpcs = (npcsByType.Patrol + npcsByType.Armored + npcsByType.Elite) > 0
if not hasNpcs then
	print("[VERIFY SKIP] No NPCs in workspace — run during PvE phase to verify spawn pipeline")
else
	-- Sprint 5 layout: 4 Patrol / 3 Armored / 2 Elite
	check("workspace.Patrol count",  npcsByType.Patrol,  4)
	check("workspace.Armored count", npcsByType.Armored, 3)
	check("workspace.Elite count",   npcsByType.Elite,   2)
	check("Patrol runtime attrs match config",  npcAttrOK.Patrol,  true)
	check("Armored runtime attrs match config", npcAttrOK.Armored, true)
	check("Elite runtime attrs match config",   npcAttrOK.Elite,   true)
end

-- ============================================================
-- 7. Player HUD initial text (only meaningful for local player after init)
-- ============================================================
local hadHud = false
local lp = Players.LocalPlayer
if lp then
	local pg = lp:FindFirstChild("PlayerGui")
	local hud = pg and pg:FindFirstChild("FinalStrikeHUD")
	local hpText = hud and hud:FindFirstChild("HPText", true)
	if hpText then
		check("HUD HPText format reflects MAX_HP", hpText.Text, "200 / 200")
		hadHud = true
	else
		print("[VERIFY SKIP] HUD HPText not yet built")
	end
else
	print("[VERIFY SKIP] No LocalPlayer (server-only context)")
end

-- ============================================================
-- Summary
-- ============================================================
print(string.format("\n[VERIFY SUMMARY] %d passed, %d failed", pass, fail))
if fail == 0 then
	print("[VERIFY] ✅ Sprint 8b runtime state matches design contract")
else
	warn(string.format("[VERIFY] ❌ %d check(s) failed — runtime has drifted from Sprint 8b design", fail))
end

-- Structured return for programmatic callers (e.g. MCP execute_luau).
-- For Studio command-bar use, the return value is ignored — the print/warn
-- output is the human-readable result.
--
-- hasNpcs / hadHud flags let callers explain why `passed` count varied —
-- e.g. (passed=93, hadHud=true, hasNpcs=false) means script was run in
-- lobby (92 static + 1 HUD), no drift, just no NPC sample. See header
-- count table for all valid totals (92/93/98/99).
return {
	passed = pass,
	failed = fail,
	failures = failures,
	hasNpcs = hasNpcs,
	hadHud = hadHud,
}
