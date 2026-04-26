-- MapBuilder.lua (ServerScriptService)
-- Procedural generation of lobby, arena, and spectator areas

local Lighting = game:GetService("Lighting")

local MAP = {}

-- Atmosphere setup: dark, cinematic, foggy with red accents
local function setupAtmosphere()
	Lighting.Ambient = Color3.fromRGB(30, 25, 35)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 35, 45)
	Lighting.Brightness = 0.5
	Lighting.ClockTime = 21  -- night
	Lighting.FogEnd = 400
	Lighting.FogStart = 50
	Lighting.FogColor = Color3.fromRGB(20, 15, 25)

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.35
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(40, 30, 50)
	atmo.Decay = Color3.fromRGB(60, 40, 70)
	atmo.Glare = 0.2
	atmo.Haze = 3
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 20
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 0.15
	cc.Saturation = -0.1
	cc.Brightness = -0.02
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
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = parent

	-- Floor
	makePart({
		Name = "LobbyFloor",
		Size = Vector3.new(80, 2, 80),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.Slate,
		Parent = lobby,
	})

	-- Walls
	local wallData = {
		{ Vector3.new(80, 20, 2), Vector3.new(0, 9, 41) },
		{ Vector3.new(80, 20, 2), Vector3.new(0, 9, -41) },
		{ Vector3.new(2, 20, 80), Vector3.new(41, 9, 0) },
		{ Vector3.new(2, 20, 80), Vector3.new(-41, 9, 0) },
	}
	for i, w in ipairs(wallData) do
		local wall = makePart({
			Name = "LobbyWall" .. i,
			Size = w[1],
			Position = w[2],
			Color = Color3.fromRGB(45, 40, 50),
			Material = Enum.Material.Concrete,
			Parent = lobby,
		})
		-- Red accent lights on walls
		local lightPart = makePart({
			Name = "WallLight" .. i,
			Size = Vector3.new(2, 1, 2),
			Position = w[2] + Vector3.new(0, 5, 0),
			Color = Color3.fromRGB(200, 40, 40),
			Material = Enum.Material.Neon,
			Parent = lobby,
		})
		addLight(lightPart, Color3.fromRGB(255, 60, 50), 1.5, 25)
	end

	-- Ceiling
	makePart({
		Name = "LobbyCeiling",
		Size = Vector3.new(80, 1, 80),
		Position = Vector3.new(0, 19.5, 0),
		Color = Color3.fromRGB(30, 30, 35),
		Material = Enum.Material.Concrete,
		Parent = lobby,
	})

	-- Central light fixture
	local centerLight = makePart({
		Name = "CenterLight",
		Size = Vector3.new(4, 1, 4),
		Position = Vector3.new(0, 18, 0),
		Color = Color3.fromRGB(255, 220, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Parent = lobby,
	})
	addSpotLight(centerLight, Color3.fromRGB(255, 220, 200), 2, 50, 60)

	-- Title sign
	local sign = Instance.new("Part")
	sign.Name = "TitleSign"
	sign.Anchored = true
	sign.Size = Vector3.new(30, 6, 1)
	sign.Position = Vector3.new(0, 12, -39)
	sign.Color = Color3.fromRGB(25, 25, 30)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Parent = lobby

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = sign
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "FINAL STRIKE"
	titleLabel.TextColor3 = Color3.fromRGB(255, 60, 50)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = sg

	-- Start match trigger pad
	local startPad = makePart({
		Name = "StartMatchPad",
		Size = Vector3.new(12, 0.5, 12),
		Position = Vector3.new(0, 0.25, 15),
		Color = Color3.fromRGB(0, 180, 80),
		Material = Enum.Material.Neon,
		Parent = lobby,
	})
	addLight(startPad, Color3.fromRGB(0, 255, 120), 1, 20)

	local padGui = Instance.new("SurfaceGui")
	padGui.Face = Enum.NormalId.Top
	padGui.Parent = startPad
	local padLabel = Instance.new("TextLabel")
	padLabel.Size = UDim2.new(1, 0, 1, 0)
	padLabel.BackgroundTransparency = 1
	padLabel.Text = "STEP HERE TO START"
	padLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	padLabel.TextScaled = true
	padLabel.Font = Enum.Font.GothamBold
	padLabel.Parent = padGui

	-- Spawn location in lobby
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Position = Vector3.new(0, 1, -10)
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Parent = lobby

	return lobby
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

	local spawnPositions = {
		{ Type = "Patrol", Pos = Vector3.new(50, 1, -360) },
		{ Type = "Patrol", Pos = Vector3.new(-70, 1, -440) },
		{ Type = "Patrol", Pos = Vector3.new(90, 1, -480) },
		{ Type = "Patrol", Pos = Vector3.new(-30, 1, -350) },
		{ Type = "Patrol", Pos = Vector3.new(20, 1, -520) },
		{ Type = "Armored", Pos = Vector3.new(0, 1, -400) },
		{ Type = "Armored", Pos = Vector3.new(-100, 1, -470) },
		{ Type = "Armored", Pos = Vector3.new(80, 1, -350) },
		{ Type = "Elite", Pos = Vector3.new(0, 1, -450) },
		{ Type = "Elite", Pos = Vector3.new(-50, 7, -400) },  -- on platform
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
		{ Type = "Weapon", Pos = Vector3.new(0, 1, -350) },
		{ Type = "Weapon", Pos = Vector3.new(-60, 7, -400) },
		{ Type = "Weapon", Pos = Vector3.new(100, 1, -450) },
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

-- ============ BUILD ALL ============
function MAP.buildAll()
	setupAtmosphere()

	-- Remove Studio's default Baseplate (2048×16×2048 at y=-8) — its top at y=0
	-- intercepts raycasts that traverse the lobby↔arena gap.
	local defaultBaseplate = workspace:FindFirstChild("Baseplate")
	if defaultBaseplate then defaultBaseplate:Destroy() end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = "LastZone"
	mapFolder.Parent = workspace

	MAP.buildLobby(mapFolder)
	MAP.buildArena(mapFolder)
	MAP.buildSpectatorArea(mapFolder)

	print("[MapBuilder] Map generated successfully!")
	return mapFolder
end

-- Auto-run on server start
MAP.buildAll()

return MAP
