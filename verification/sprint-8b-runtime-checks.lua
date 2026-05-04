--!strict
-- verification/sprint-8b-runtime-checks.lua
--
-- Reproducible Sprint 8b runtime verification.
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
--      drifted from the Sprint 8b design contract.
--
-- Equivalently, run just the assertion section via execute_luau over MCP
-- (see receipts/sprint-8b-studio-verify.md §"Static config verification").
--
-- This script is read-only — it inspects state but doesn't mutate anything.
--
-- Source of truth this checks against: proposals/30-weapon-dps-retune.md §9
-- + receipts/sprint-8b-200hp-rebalance.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

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
check("HEADSHOT_MULTIPLIER", GameConfig.HEADSHOT_MULTIPLIER, 2.0)

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
-- 3. 30-weapon Damage values (proposals/30-weapon-dps-retune.md §9)
-- ============================================================
local weaponExpect = {
	-- Common (5)
	["Viper Mk1"]=30, ["Viper SD"]=24, ["Fang Scout"]=40,
	["Thunder Stub"]=14, ["Thunder Cut"]=11,
	-- Uncommon (5)
	["Stinger Mk2"]=11, ["Stinger Tac"]=12, ["Phantom Ranger"]=19,
	["Wraith Scout"]=120, ["Stinger Burst"]=9,
	-- Rare (5)
	["Reaver-X"]=20, ["Phantom Night"]=17, ["Thunder Guard"]=12,
	["Wraith Hunter"]=172, ["Thunder Triple"]=11,
	-- Epic (6)
	["Stinger Storm"]=12, ["Phantom Apex"]=21, ["Wraith Frost"]=190,
	["Phantom Whisper"]=25, ["Thunder Royal"]=13, ["Viper Left"]=62,
	-- Legendary (5)
	["Viper Aurum"]=51, ["Phantom Finale"]=24, ["Wraith Apex"]=206,
	["Thunder Crown"]=14, ["Hailstorm"]=18,
	-- Demon (4)
	["Fang Demon"]=76, ["Phantom Hellfire"]=27, ["Wraith Abyss"]=220,
	["Thunder Bloodmoon"]=14,
}
for name, expected in pairs(weaponExpect) do
	local cfg = GameConfig.WEAPONS[name]
	check("WEAPONS." .. name .. ".Damage", cfg and cfg.Damage, expected)
end

-- All Sniper variants Type assertion (used by headshot detection)
for _, name in ipairs({"Wraith Scout", "Wraith Hunter", "Wraith Frost", "Wraith Apex", "Wraith Abyss"}) do
	check("WEAPONS." .. name .. ".Type", GameConfig.WEAPONS[name].Type, "Sniper")
end

-- ============================================================
-- 3.5. 30-weapon Price values (Sprint 9 Option A — CEO 2026-05-04)
-- Tier discounts: Common 0% / Uncommon 0% / Rare -5% / Epic -10% / Legendary -20% / Demon -25%
-- See proposals/demon-shop-price-realignment.md.
-- ============================================================
local priceExpect = {
	-- Common (5) — 0% (unchanged)
	["Viper Mk1"]=300, ["Viper SD"]=350, ["Fang Scout"]=450,
	["Thunder Stub"]=550, ["Thunder Cut"]=650,
	-- Uncommon (5) — 0% (unchanged)
	["Stinger Mk2"]=1200, ["Stinger Tac"]=1350, ["Phantom Ranger"]=1500,
	["Wraith Scout"]=1650, ["Stinger Burst"]=1800,
	-- Rare (5) — -5%
	["Reaver-X"]=2850, ["Phantom Night"]=3150, ["Thunder Guard"]=3400,
	["Wraith Hunter"]=3800, ["Thunder Triple"]=4275,
	-- Epic (6) — -10%
	["Stinger Storm"]=6750, ["Phantom Apex"]=7200, ["Wraith Frost"]=7650,
	["Phantom Whisper"]=8100, ["Thunder Royal"]=8800, ["Viper Left"]=8800,
	-- Legendary (5) — -20%
	["Viper Aurum"]=12800, ["Phantom Finale"]=14400, ["Wraith Apex"]=16000,
	["Thunder Crown"]=17600, ["Hailstorm"]=20000,
	-- Demon (4) — -25%
	["Fang Demon"]=26250, ["Phantom Hellfire"]=31500, ["Wraith Abyss"]=36000,
	["Thunder Bloodmoon"]=41250,
}
for name, expected in pairs(priceExpect) do
	local cfg = GameConfig.WEAPONS[name]
	check("WEAPONS." .. name .. ".Price", cfg and cfg.Price, expected)
end

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
-- e.g. (passed=63, hadHud=true, hasNpcs=false) means script was run in
-- lobby (62 static + 1 HUD), no drift, just no NPC sample.
return {
	passed = pass,
	failed = fail,
	failures = failures,
	hasNpcs = hasNpcs,
	hadHud = hadHud,
}
