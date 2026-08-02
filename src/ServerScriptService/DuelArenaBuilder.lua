-- DuelArenaBuilder.lua (ServerScriptService ModuleScript)
-- Server-only builder lookup for 1v1 duel arenas. Companion to DuelMaps.lua
-- (which holds only client-safe metadata). Adding a new map = one builder
-- function here keyed by the map's Id, registered in `builders` below —
-- MapBuilder and DuelService never need to change.
--
-- Every builder must create, inside the Folder it's given:
--   - "SpawnA" and "SpawnB" (Parts, CFrame set, teleport targets)
--   - the arena's own geometry (floor/walls/cover), offset by the `center`
--     Vector3 it's given so multiple duel maps never overlap each other or
--     the rest of LastZone.

local DuelArenaBuilder = {}

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = props.Material or Enum.Material.Concrete
	p.Color = props.Color or Color3.fromRGB(50, 48, 55)
	p.Size = props.Size or Vector3.new(10, 1, 10)
	p.Position = props.Position or Vector3.new(0, 0, 0)
	p.Name = props.Name or "DuelPart"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Transparency then p.Transparency = props.Transparency end
	p.Parent = props.Parent
	return p
end

local function addLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 50, 40)
	light.Brightness = brightness or 1.5
	light.Range = range or 20
	light.Parent = parent
end

local function addSpotLight(parent, color, brightness, range, angle)
	local light = Instance.new("SpotLight")
	light.Color = color or Color3.fromRGB(255, 220, 200)
	light.Brightness = brightness or 1.5
	light.Range = range or 40
	light.Angle = angle or 70
	light.Face = Enum.NormalId.Bottom
	light.Parent = parent
end

local builders = {}

-- ============= Map 1: BunkerCrossfire =============
-- Symmetric 90x80 arena: raised, roofed spawn bunkers at the rear corners
-- with protected exits + close ramps, a central blocker that removes any
-- direct spawn-to-spawn shot, a dense mixed-height central cover cluster, a
-- single-lane left flank, and a right-side raised platform (with stairs)
-- fronted by cover so it isn't an uncontested high-ground lane.
builders.BunkerCrossfire = function(parent, center)
	local function pos(x, y, z)
		return center + Vector3.new(x, y, z)
	end

	makePart({
		Name = "DuelFloor",
		Size = Vector3.new(90, 2, 80),
		Position = pos(0, -1, 0),
		Color = Color3.fromRGB(40, 38, 45),
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	-- Boundary walls: rear (spawns), front, east, west
	local walls = {
		{ Size = Vector3.new(90, 20, 2), Offset = Vector3.new(0, 9, -40) },
		{ Size = Vector3.new(90, 20, 2), Offset = Vector3.new(0, 9, 40) },
		{ Size = Vector3.new(2, 20, 80), Offset = Vector3.new(45, 9, 0) },
		{ Size = Vector3.new(2, 20, 80), Offset = Vector3.new(-45, 9, 0) },
	}
	for i, w in ipairs(walls) do
		makePart({
			Name = "DuelWall" .. i,
			Size = w.Size,
			Position = pos(w.Offset.X, w.Offset.Y, w.Offset.Z),
			Color = Color3.fromRGB(35, 30, 40),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end

	-- ===== Spawn bunkers (raised, roofed, protected exit + close ramp) =====
	local function buildSpawnBunker(suffix, sideX)
		local cx = sideX * 36
		local gap = 6
		local wallHalf = 6

		makePart({
			Name = "BunkerFloor" .. suffix,
			Size = Vector3.new(18, 1, 16),
			Position = pos(cx, 4, -32),
			Color = Color3.fromRGB(45, 42, 50),
			Material = Enum.Material.DiamondPlate,
			Parent = parent,
		})
		makePart({
			Name = "BunkerRoof" .. suffix,
			Size = Vector3.new(18, 1, 16),
			Position = pos(cx, 9, -32),
			Color = Color3.fromRGB(20, 20, 25),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		-- Inner wall closes the side facing the arena interior, leaving only
		-- the front gap as the exit (note: "protected spawn exits").
		makePart({
			Name = "BunkerInnerWall" .. suffix,
			Size = Vector3.new(1, 5, 16),
			Position = pos(cx - sideX * 9, 6.5, -32),
			Color = Color3.fromRGB(30, 28, 35),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
		-- Front parapet with a center gap — the only way in or out.
		for _, offsetSign in ipairs({ -1, 1 }) do
			makePart({
				Name = "BunkerParapet" .. suffix .. offsetSign,
				Size = Vector3.new(wallHalf, 3, 1),
				Position = pos(cx + offsetSign * (gap / 2 + wallHalf / 2), 5.5, -24),
				Color = Color3.fromRGB(35, 30, 40),
				Material = Enum.Material.Concrete,
				Parent = parent,
			})
		end
		-- Ramp right at the exit gap so leaving spawn immediately reaches
		-- ground level (reference note #1: ramp close to spawn).
		local ramp = makePart({
			Name = "BunkerRamp" .. suffix,
			Size = Vector3.new(6, 1, 11),
			Position = pos(cx, 2.25, -18.5),
			Color = Color3.fromRGB(45, 42, 50),
			Material = Enum.Material.DiamondPlate,
			Parent = parent,
		})
		ramp.Orientation = Vector3.new(-20, 0, 0)

		-- Red warning light at the doorway (cinematic mood).
		local doorLight = makePart({
			Name = "BunkerDoorLight" .. suffix,
			Size = Vector3.new(4, 0.3, 0.3),
			Position = pos(cx, 7.2, -24.3),
			Color = Color3.fromRGB(255, 40, 30),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		addLight(doorLight, Color3.fromRGB(255, 40, 30), 1.5, 20)

		-- Teleport target — faces +Z (south), into the arena.
		local marker = Instance.new("Part")
		marker.Name = "Spawn" .. suffix
		marker.Size = Vector3.new(4, 0.2, 4)
		marker.CFrame = CFrame.new(pos(cx, 4.5, -32)) * CFrame.Angles(0, math.rad(180), 0)
		marker.Anchored = true
		marker.CanCollide = false
		marker.Transparency = 1
		marker.Parent = parent

		local sign = makePart({
			Name = "BunkerSign" .. suffix,
			Size = Vector3.new(10, 2, 0.3),
			Position = pos(cx, 10.5, -39),
			Color = Color3.fromRGB(10, 10, 14),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.LightInfluence = 0
		sg.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "SPAWN " .. suffix
		label.TextColor3 = Color3.fromRGB(255, 60, 50)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = sg
	end

	buildSpawnBunker("A", -1)
	buildSpawnBunker("B", 1)

	-- Guarantees no direct spawn-to-spawn shot: both spawn exits sit on the
	-- same Z line (-24), so one wide-enough blocker straddling that line
	-- between them removes the straight sightline regardless of eye height.
	makePart({
		Name = "CentralBlocker",
		Size = Vector3.new(24, 9, 6),
		Position = pos(0, 4.5, -24),
		Color = Color3.fromRGB(55, 50, 60),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})

	-- Dense, mixed-height central cover (reference note #3).
	local centralCover = {
		{ Size = Vector3.new(6, 3, 6), Pos = Vector3.new(-6, 1.5, -6) },
		{ Size = Vector3.new(6, 3, 6), Pos = Vector3.new(6, 1.5, -6) },
		{ Size = Vector3.new(4, 7, 4), Pos = Vector3.new(0, 3.5, 2) },
		{ Size = Vector3.new(10, 3, 3), Pos = Vector3.new(-10, 1.5, 10) },
		{ Size = Vector3.new(10, 3, 3), Pos = Vector3.new(10, 1.5, 10) },
		{ Size = Vector3.new(4, 6, 4), Pos = Vector3.new(-14, 3, -2) },
		{ Size = Vector3.new(4, 6, 4), Pos = Vector3.new(14, 3, -2) },
		{ Size = Vector3.new(5, 4, 5), Pos = Vector3.new(0, 2, 18) },
	}
	for i, c in ipairs(centralCover) do
		makePart({
			Name = "CentralCover" .. i,
			Size = c.Size,
			Position = pos(c.Pos.X, c.Pos.Y, c.Pos.Z),
			Color = Color3.fromRGB(55 + math.random(-8, 8), 50 + math.random(-8, 8), 60 + math.random(-8, 8)),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end

	-- Left flank: single readable lane (reference note #4 — keep it simple).
	local leftCover = {
		{ Size = Vector3.new(4, 5, 10), Pos = Vector3.new(-32, 2.5, -4) },
		{ Size = Vector3.new(4, 4, 8), Pos = Vector3.new(-30, 2, 14) },
		{ Size = Vector3.new(6, 3, 4), Pos = Vector3.new(-34, 1.5, 26) },
	}
	for i, c in ipairs(leftCover) do
		makePart({
			Name = "LeftCover" .. i,
			Size = c.Size,
			Position = pos(c.Pos.X, c.Pos.Y, c.Pos.Z),
			Color = Color3.fromRGB(50, 48, 55),
			Material = Enum.Material.Concrete,
			Parent = parent,
		})
	end

	-- Right-side raised platform with stairs, height-reduced and fronted by
	-- cover so it isn't a dominant one-way high-ground lane (reference note #2).
	-- Platform spans X 24..40, Z 7..21; the staircase approaches from the
	-- south (open floor) along the platform's own X-center, climbing to meet
	-- its south edge (Z=7) exactly on the last step.
	makePart({
		Name = "RightPlatform",
		Size = Vector3.new(16, 1, 14),
		Position = pos(32, 4, 14),
		Color = Color3.fromRGB(45, 42, 50),
		Material = Enum.Material.DiamondPlate,
		Parent = parent,
	})
	for step = 1, 6 do
		makePart({
			Name = "RightStair" .. step,
			Size = Vector3.new(4, 1, 2),
			Position = pos(32, step * 0.75, 6 - (6 - step) * 2),
			Color = Color3.fromRGB(45, 42, 50),
			Material = Enum.Material.DiamondPlate,
			Parent = parent,
		})
	end
	-- Offset to the southwest of the staircase lane (X 30..34) so it fronts
	-- the platform without blocking the climb.
	makePart({
		Name = "RightPlatformCover",
		Size = Vector3.new(6, 4, 3),
		Position = pos(24, 2, -3),
		Color = Color3.fromRGB(50, 48, 55),
		Material = Enum.Material.Concrete,
		Parent = parent,
	})

	-- Ceiling lights (visibility; matches TrainingArena convention).
	for i = -1, 1, 2 do
		for j = -1, 1, 2 do
			local light = makePart({
				Name = string.format("DuelCeilLight_%d_%d", i, j),
				Size = Vector3.new(4, 0.5, 4),
				Position = pos(i * 30, 22, j * 25),
				Color = Color3.fromRGB(255, 220, 200),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				Parent = parent,
			})
			addSpotLight(light, Color3.fromRGB(255, 220, 200), 1.5, 40, 70)
		end
	end

	-- Red accent strips along the side walls (cinematic warning-light mood).
	for i, side in ipairs({ -44, 44 }) do
		local strip = makePart({
			Name = "DuelAccent" .. i,
			Size = Vector3.new(0.3, 0.3, 80),
			Position = pos(side, 0.5, 0),
			Color = Color3.fromRGB(255, 50, 40),
			Material = Enum.Material.Neon,
			Parent = parent,
		})
		addLight(strip, Color3.fromRGB(255, 50, 40), 1, 25)
	end
end

-- Builds map `id` inside a fresh Folder parented to `parent`, offset by
-- `center`. Returns the Folder, or nil (with a warn) if no builder is
-- registered for that id.
function DuelArenaBuilder.build(id, parent, center)
	local builder = builders[id]
	if not builder then
		warn("[DuelArenaBuilder] No builder registered for map id: " .. tostring(id))
		return nil
	end

	local zone = Instance.new("Folder")
	zone.Name = id
	zone.Parent = parent
	builder(zone, center or Vector3.new(0, 0, 0))
	return zone
end

return DuelArenaBuilder
