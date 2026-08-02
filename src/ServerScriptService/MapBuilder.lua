-- MapBuilder.lua (ServerScriptService)
-- Procedural generation of lobby, arena, and spectator areas

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LobbyBuilder = require(script.Parent:WaitForChild("LobbyBuilder"))
local DuelArenaBuilder = require(script.Parent:WaitForChild("DuelArenaBuilder"))
local DuelMaps = require(ReplicatedStorage:WaitForChild("DuelMaps"))

local MAP = {}

-- Atmosphere setup: dark, cinematic, foggy with red accents.
-- ClockTime tracks the real wall-clock so the sky reflects when you're playing,
-- but Brightness/Ambient/Fog stay dark for the cinematic look. NPCs carry their
-- own red PointLights (see NPCSystem.createR15NPC) so they're visible regardless.
local function setupAtmosphere()
	-- Bright enough to actually see the arena floor + cover + NPCs while still
	-- keeping the desaturated "dark thriller" mood (#16). Previous version used
	-- real-world ClockTime which made evening playtests pitch-black; we now pin
	-- it to early afternoon for consistent visibility.
	Lighting.Ambient = Color3.fromRGB(110, 100, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
	Lighting.Brightness = 3
	Lighting.ClockTime = 14            -- 2pm — always daytime regardless of when you play
	Lighting.FogEnd = 1000
	Lighting.FogStart = 300
	Lighting.FogColor = Color3.fromRGB(80, 75, 90)

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.08              -- ↓ from 0.15 (less haze swallowing distant cover)
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(110, 100, 120)
	atmo.Decay = Color3.fromRGB(140, 120, 150)
	atmo.Glare = 0.2
	atmo.Haze = 1.0                  -- ↓ from 1.5
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.15
	cc.Saturation = -0.1
	cc.Brightness = 0.05             -- ↑ slight lift so shadows aren't crushed
	cc.TintColor = Color3.fromRGB(255, 240, 245)
	cc.Parent = Lighting
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(50, 50, 55)
	p.Size = props.Size or Vector3.new(10, 1, 10)
	p.Position = props.Position or Vector3.new(0, 0, 0)
	p.Name = props.Name or "MapPart"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Transparency then p.Transparency = props.Transparency end
	if props.Parent then p.Parent = props.Parent end
	return p
end

local function addLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 80, 60)
	light.Brightness = brightness or 2
	light.Range = range or 30
	light.Parent = parent
end

local function addSpotLight(parent, color, brightness, range, angle)
	local light = Instance.new("SpotLight")
	light.Color = color or Color3.fromRGB(255, 200, 180)
	light.Brightness = brightness or 3
	light.Range = range or 40
	light.Angle = angle or 45
	light.Face = Enum.NormalId.Bottom
	light.Parent = parent
end

-- ============ LOBBY ============
function MAP.buildLobby(parent)
	return LobbyBuilder.build(parent)
end

-- ============ ARENA ============
function MAP.buildArena(parent)
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = parent

	-- Large floor
	makePart({
		Name = "ArenaFloor",
		Size = Vector3.new(300, 2, 300),
		Position = Vector3.new(0, -1, -400),
		Color = Color3.fromRGB(40, 38, 45),
		Material = Enum.Material.Slate,
		Parent = arena,
	})

	-- Cover structures (walls, crates, pillars)
	local coverPositions = {
		{ Size = Vector3.new(20, 10, 3), Pos = Vector3.new(40, 4, -350) },
		{ Size = Vector3.new(3, 10, 20), Pos = Vector3.new(-50, 4, -420) },
		{ Size = Vector3.new(15, 8, 15), Pos = Vector3.new(80, 3, -450) },
		{ Size = Vector3.new(8, 6, 8), Pos = Vector3.new(-80, 2, -380) },
		{ Size = Vector3.new(25, 12, 4), Pos = Vector3.new(0, 5, -480) },
		{ Size = Vector3.new(4, 12, 25), Pos = Vector3.new(60, 5, -350) },
		{ Size = Vector3.new(10, 5, 10), Pos = Vector3.new(-30, 1.5, -500) },
		{ Size = Vector3.new(6, 8, 6), Pos = Vector3.new(100, 3, -400) },
		{ Size = Vector3.new(18, 6, 3), Pos = Vector3.new(-100, 2, -450) },
		{ Size = Vector3.new(3, 6, 18), Pos = Vector3.new(30, 2, -530) },
		{ Size = Vector3.new(12, 10, 12), Pos = Vector3.new(-60, 4, -320) },
		{ Size = Vector3.new(5, 4, 5), Pos = Vector3.new(120, 1, -500) },
	}

	for i, c in ipairs(coverPositions) do
		local cover = makePart({
			Name = "Cover" .. i,
			Size = c.Size,
			Position = c.Pos,
			Color = Color3.fromRGB(55 + math.random(-10, 10), 50 + math.random(-10, 10), 60 + math.random(-10, 10)),
			Material = Enum.Material.Concrete,
			Parent = arena,
		})
		-- Some covers get red accent lights
		if i % 3 == 0 then
			local lp = makePart({
				Name = "CoverLight" .. i,
				Size = Vector3.new(1, 0.5, 1),
				Position = c.Pos + Vector3.new(0, c.Size.Y / 2 + 1, 0),
				Color = Color3.fromRGB(255, 50, 40),
				Material = Enum.Material.Neon,
				Parent = arena,
			})
			addLight(lp, Color3.fromRGB(255, 50, 40), 1.5, 20)
		end
	end

	-- Elevated platform
	makePart({
		Name = "Platform1",
		Size = Vector3.new(25, 1, 25),
		Position = Vector3.new(-40, 6, -400),
		Color = Color3.fromRGB(50, 45, 55),
		Material = Enum.Material.DiamondPlate,
		Parent = arena,
	})
	-- Ramp to platform
	local ramp = makePart({
		Name = "Ramp1",
		Size = Vector3.new(8, 1, 20),
		Position = Vector3.new(-25, 3, -400),
		Color = Color3.fromRGB(60, 55, 65),
		Material = Enum.Material.DiamondPlate,
		Parent = arena,
	})
	ramp.Orientation = Vector3.new(0, 0, -18)

	-- Arena boundary walls
	local bounds = {
		{ Vector3.new(300, 30, 3), Vector3.new(0, 14, -249) },
		{ Vector3.new(300, 30, 3), Vector3.new(0, 14, -551) },
		{ Vector3.new(3, 30, 300), Vector3.new(151, 14, -400) },
		{ Vector3.new(3, 30, 300), Vector3.new(-151, 14, -400) },
	}
	for i, b in ipairs(bounds) do
		makePart({
			Name = "ArenaWall" .. i,
			Size = b[1],
			Position = b[2],
			Color = Color3.fromRGB(35, 30, 40),
			Material = Enum.Material.Concrete,
			Transparency = 0.3,
			Parent = arena,
		})
	end

	-- NPC spawn markers
	local npcSpawns = Instance.new("Folder")
	npcSpawns.Name = "NPCSpawns"
	npcSpawns.Parent = arena

	-- All NPC spawns kept at z <= -400 so even with wander + DetectRange they
	-- can't reach players (z=-270~-290) within the first 5–8 seconds.
	-- Combined with MatchManager.SPAWN_PROTECTION grace this prevents instant ganks.
	local spawnPositions = {
		{ Type = "Patrol", Pos = Vector3.new(50, 1, -420) },
		{ Type = "Patrol", Pos = Vector3.new(-70, 1, -440) },
		{ Type = "Patrol", Pos = Vector3.new(90, 1, -480) },
		{ Type = "Patrol", Pos = Vector3.new(20, 1, -520) },
		{ Type = "Armored", Pos = Vector3.new(0, 1, -460) },
		{ Type = "Armored", Pos = Vector3.new(-100, 1, -470) },
		{ Type = "Armored", Pos = Vector3.new(80, 1, -410) },
		{ Type = "Elite", Pos = Vector3.new(0, 1, -510) },
		{ Type = "Elite", Pos = Vector3.new(-50, 7, -440) },  -- on platform
	}

	for i, s in ipairs(spawnPositions) do
		local marker = Instance.new("Part")
		marker.Name = s.Type .. "Spawn" .. i
		marker.Size = Vector3.new(2, 0.2, 2)
		marker.Position = s.Pos
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = npcSpawns
		marker:SetAttribute("EnemyType", s.Type)
	end

	-- Player spawn points in arena
	local playerSpawns = Instance.new("Folder")
	playerSpawns.Name = "PlayerSpawns"
	playerSpawns.Parent = arena

	local pSpawnPositions = {
		Vector3.new(20, 1, -270),
		Vector3.new(-20, 1, -270),
		Vector3.new(60, 1, -280),
		Vector3.new(-60, 1, -280),
		Vector3.new(40, 1, -290),
		Vector3.new(-40, 1, -290),
		Vector3.new(80, 1, -270),
		Vector3.new(-80, 1, -270),
		Vector3.new(100, 1, -280),
		Vector3.new(-100, 1, -280),
		Vector3.new(120, 1, -290),
		Vector3.new(-120, 1, -290),
	}
	for i, pos in ipairs(pSpawnPositions) do
		local sp = Instance.new("Part")
		sp.Name = "ArenaSpawn" .. i
		sp.Size = Vector3.new(4, 0.2, 4)
		sp.Position = pos
		sp.Anchored = true
		sp.CanCollide = false
		sp.Transparency = 1
		sp.Parent = playerSpawns
	end

	-- Loot spawn markers
	local lootSpawns = Instance.new("Folder")
	lootSpawns.Name = "LootSpawns"
	lootSpawns.Parent = arena

	local lootPositions = {
		{ Type = "Ammo", Pos = Vector3.new(30, 1, -370) },
		{ Type = "Ammo", Pos = Vector3.new(-40, 1, -430) },
		{ Type = "Ammo", Pos = Vector3.new(70, 1, -460) },
		{ Type = "Medkit", Pos = Vector3.new(-20, 1, -380) },
		{ Type = "Medkit", Pos = Vector3.new(50, 1, -500) },
		{ Type = "Coin", Pos = Vector3.new(10, 1, -420) },
		{ Type = "Coin", Pos = Vector3.new(-80, 1, -400) },
		{ Type = "Coin", Pos = Vector3.new(0, 1, -350) },
		{ Type = "Medkit", Pos = Vector3.new(-60, 7, -400) },
		{ Type = "Coin", Pos = Vector3.new(100, 1, -450) },
	}
	for i, l in ipairs(lootPositions) do
		local marker = Instance.new("Part")
		marker.Name = l.Type .. "Spawn" .. i
		marker.Size = Vector3.new(2, 0.2, 2)
		marker.Position = l.Pos
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = lootSpawns
		marker:SetAttribute("LootType", l.Type)
	end

	return arena
end

-- ============ SPECTATOR AREA ============
function MAP.buildSpectatorArea(parent)
	local spec = Instance.new("Folder")
	spec.Name = "SpectatorArea"
	spec.Parent = parent

	-- Floor
	makePart({
		Name = "SpecFloor",
		Size = Vector3.new(60, 2, 60),
		Position = Vector3.new(300, -1, 0),
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.Slate,
		Parent = spec,
	})

	-- Walls
	makePart({
		Name = "SpecWall1",
		Size = Vector3.new(60, 15, 2),
		Position = Vector3.new(300, 6.5, 31),
		Color = Color3.fromRGB(50, 45, 55),
		Material = Enum.Material.Concrete,
		Parent = spec,
	})
	makePart({
		Name = "SpecWall2",
		Size = Vector3.new(60, 15, 2),
		Position = Vector3.new(300, 6.5, -31),
		Color = Color3.fromRGB(50, 45, 55),
		Material = Enum.Material.Concrete,
		Parent = spec,
	})
	makePart({
		Name = "SpecWall3",
		Size = Vector3.new(2, 15, 60),
		Position = Vector3.new(331, 6.5, 0),
		Color = Color3.fromRGB(50, 45, 55),
		Material = Enum.Material.Concrete,
		Parent = spec,
	})

	-- Practice targets
	for i = 1, 4 do
		local target = makePart({
			Name = "PracticeTarget" .. i,
			Size = Vector3.new(3, 5, 1),
			Position = Vector3.new(325, 2.5, -15 + i * 8),
			Color = Color3.fromRGB(200, 60, 50),
			Material = Enum.Material.SmoothPlastic,
			Parent = spec,
		})
		target:SetAttribute("IsTarget", true)
		target:SetAttribute("HP", 100)

		-- Target stand
		makePart({
			Name = "TargetStand" .. i,
			Size = Vector3.new(1, 4, 1),
			Position = Vector3.new(325, 2, -15 + i * 8),
			Color = Color3.fromRGB(60, 60, 65),
			Material = Enum.Material.Metal,
			Parent = spec,
		})
	end

	-- Spectator spawn
	local specSpawn = Instance.new("SpawnLocation")
	specSpawn.Name = "SpectatorSpawn"
	specSpawn.Position = Vector3.new(300, 1, 0)
	specSpawn.Size = Vector3.new(6, 1, 6)
	specSpawn.Anchored = true
	specSpawn.CanCollide = false
	specSpawn.Transparency = 1
	specSpawn.Enabled = false  -- not a default spawn
	specSpawn.Parent = spec

	return spec
end

-- ============ TRAINING ARENA ============
-- Standalone NPC training zone the player teleports into via the lobby's
-- TrainingArenaPortal. Inside: weapon picker on entry (UI driven by
-- TrainingService), 6 stationary dummy NPCs in the corners (no AI, just
-- targets), and an exit pad that teleports back to the lobby.
function MAP.buildTrainingArena(parent)
	local zone = Instance.new("Folder")
	zone.Name = "TrainingArena"
	zone.Parent = parent

	local CENTER = Vector3.new(500, 0, 0)  -- offset clear of LastZone Arena (z=-400)

	-- Floor
	makePart({
		Name = "TrainingFloor",
		Size = Vector3.new(120, 2, 120),
		Position = CENTER + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(40, 38, 50),
		Material = Enum.Material.Slate,
		Parent = zone,
	})

	-- Walls (4 sides) with red neon accent strip near the floor
	local walls = {
		{ Vector3.new(120, 25, 2), Vector3.new(0, 11.5, 61) },
		{ Vector3.new(120, 25, 2), Vector3.new(0, 11.5, -61) },
		{ Vector3.new(2, 25, 120), Vector3.new(61, 11.5, 0) },
		{ Vector3.new(2, 25, 120), Vector3.new(-61, 11.5, 0) },
	}
	for i, w in ipairs(walls) do
		makePart({
			Name = "TrainingWall" .. i,
			Size = w[1],
			Position = CENTER + w[2],
			Color = Color3.fromRGB(35, 30, 40),
			Material = Enum.Material.Concrete,
			Parent = zone,
		})
	end

	-- Red accent strips at floor level on each long wall (cinematic neon look)
	for i, side in ipairs({ -60, 60 }) do
		local strip = makePart({
			Name = "TrainingAccent" .. i,
			Size = Vector3.new(120, 0.3, 0.3),
			Position = CENTER + Vector3.new(0, 0.5, side),
			Color = Color3.fromRGB(255, 50, 40),
			Material = Enum.Material.Neon,
			Parent = zone,
		})
		addLight(strip, Color3.fromRGB(255, 50, 40), 1, 25)
	end

	-- Ceiling lights (4 across the room for visibility)
	for i = -1, 1, 2 do
		for j = -1, 1, 2 do
			local light = makePart({
				Name = string.format("TrainingCeilLight_%d_%d", i, j),
				Size = Vector3.new(4, 0.5, 4),
				Position = CENTER + Vector3.new(i * 35, 22, j * 35),
				Color = Color3.fromRGB(255, 220, 200),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				Parent = zone,
			})
			addSpotLight(light, Color3.fromRGB(255, 220, 200), 1.5, 40, 70)
		end
	end

	-- Title sign on far wall: "TRAINING ARENA"
	local titleSign = makePart({
		Name = "TrainingTitleSign",
		Size = Vector3.new(50, 8, 1),
		Position = CENTER + Vector3.new(0, 14, -59),
		Color = Color3.fromRGB(20, 20, 25),
		Material = Enum.Material.SmoothPlastic,
		Parent = zone,
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front  -- visible from +Z side (player entering)
	sg.Parent = titleSign
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "TRAINING ARENA"
	titleLabel.TextColor3 = Color3.fromRGB(255, 60, 50)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = sg

	-- Dummy NPC spawn markers in the corners (4) + 2 mid-room flanks for variety.
	-- NPCSystem.spawnTrainingDummies() reads these markers and spawns stationary NPCs.
	local dummySpawns = Instance.new("Folder")
	dummySpawns.Name = "DummySpawns"
	dummySpawns.Parent = zone

	local dummyPositions = {
		{ Type = "Patrol",  Pos = Vector3.new(-50, 1, -50) },
		{ Type = "Patrol",  Pos = Vector3.new( 50, 1, -50) },
		{ Type = "Armored", Pos = Vector3.new(-50, 1,  50) },
		{ Type = "Armored", Pos = Vector3.new( 50, 1,  50) },
		{ Type = "Elite",   Pos = Vector3.new(-30, 1,   0) },
		{ Type = "Elite",   Pos = Vector3.new( 30, 1,   0) },
	}
	for i, d in ipairs(dummyPositions) do
		local marker = Instance.new("Part")
		marker.Name = d.Type .. "Dummy" .. i
		marker.Size = Vector3.new(2, 0.2, 2)
		marker.Position = CENTER + d.Pos
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = dummySpawns
		marker:SetAttribute("EnemyType", d.Type)
	end

	-- Player entry spawn (TrainingService teleports here on portal touch)
	local entry = Instance.new("Part")
	entry.Name = "TrainingEntry"
	entry.Size = Vector3.new(4, 0.2, 4)
	entry.Position = CENTER + Vector3.new(0, 1, 50)
	entry.Anchored = true
	entry.CanCollide = false
	entry.Transparency = 1
	entry.Parent = zone

	-- Exit pad (player touches → teleport back to lobby). Visible green pad
	-- in the corner near entry, with a "BACK TO LOBBY" sign above it.
	local exitPad = makePart({
		Name = "TrainingExitPad",
		Size = Vector3.new(8, 0.5, 8),
		Position = CENTER + Vector3.new(50, 0.25, 50),
		Color = Color3.fromRGB(180, 50, 40),
		Material = Enum.Material.Neon,
		Parent = zone,
	})
	addLight(exitPad, Color3.fromRGB(255, 80, 60), 1.5, 15)
	local exitGui = Instance.new("SurfaceGui")
	exitGui.Face = Enum.NormalId.Top
	exitGui.Parent = exitPad
	local exitLabel = Instance.new("TextLabel")
	exitLabel.Size = UDim2.new(1, 0, 1, 0)
	exitLabel.BackgroundTransparency = 1
	exitLabel.Text = "BACK TO LOBBY"
	exitLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	exitLabel.TextScaled = true
	exitLabel.Font = Enum.Font.GothamBold
	exitLabel.Parent = exitGui

	return zone
end

-- ============ 1v1 DUEL ARENAS ============
-- Builds every registered DuelMaps entry once at server start, each in its
-- own Folder under LastZone.DuelArenas.<MapId>, spaced far apart so future
-- maps never overlap each other or the rest of LastZone. DuelService just
-- looks these up by name at match time — nothing here is rebuilt per-duel.
function MAP.buildDuelArenas(parent)
	local duelArenas = Instance.new("Folder")
	duelArenas.Name = "DuelArenas"
	duelArenas.Parent = parent

	local SPACING = 300
	local BASE = Vector3.new(-500, 0, 0)  -- clear of Lobby/Arena/Spectator/TrainingArena
	for index, mapDef in ipairs(DuelMaps.list()) do
		local center = BASE - Vector3.new((index - 1) * SPACING, 0, 0)
		DuelArenaBuilder.build(mapDef.Id, duelArenas, center)
	end

	return duelArenas
end

-- ============ BUILD ALL ============
function MAP.buildAll()
	setupAtmosphere()

	-- Remove Studio's default template instances. Baseplate's top at y=0
	-- intercepts raycasts that traverse the lobby↔arena gap; default
	-- SpawnLocation competes with our LobbySpawn for first-spawn placement.
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local default = workspace:FindFirstChild(name)
		if default then default:Destroy() end
	end

	-- (#37 round 2) Defensive: if LastZone already exists from a prior script
	-- reload, destroy it first. Without this, Studio playtest cycles can
	-- accumulate multiple "LastZone" folders, and TrainingService binds its
	-- portal Touched signal to the FIRST one it finds — which may be empty
	-- because something else destroyed its children. Sweep clean every time.
	local existing = workspace:FindFirstChild("LastZone")
	if existing then existing:Destroy() end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "LastZone"
	mapFolder.Parent = workspace

	MAP.buildLobby(mapFolder)
	MAP.buildArena(mapFolder)
	MAP.buildSpectatorArea(mapFolder)
	MAP.buildTrainingArena(mapFolder)
	MAP.buildDuelArenas(mapFolder)

	print("[MapBuilder] Map generated successfully!")
	return mapFolder
end

-- Auto-run on server start
MAP.buildAll()

return MAP
