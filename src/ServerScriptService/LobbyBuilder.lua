-- LobbyBuilder.lua (ServerScriptService/ModuleScript)
-- Generates the industrial bunker hub while preserving the direct runtime
-- children consumed by MatchManager and TrainingService.

local ServerStorage = game:GetService("ServerStorage")

local WeaponMeshes = require(ServerStorage:WaitForChild("WeaponMeshes"))

local LobbyBuilder = {}

local COLORS = {
	Black = Color3.fromRGB(10, 11, 14),
	Charcoal = Color3.fromRGB(24, 26, 31),
	DarkGray = Color3.fromRGB(38, 41, 48),
	Gray = Color3.fromRGB(65, 68, 76),
	White = Color3.fromRGB(242, 244, 248),
	WarmWhite = Color3.fromRGB(255, 232, 205),
	Red = Color3.fromRGB(235, 28, 38),
	DeepRed = Color3.fromRGB(92, 12, 18),
}

local function makeContainer(className, name, parent)
	local container = Instance.new(className)
	container.Name = name
	container.Parent = parent
	return container
end

local function makePart(parent, props)
	local part = Instance.new(props.ClassName or "Part")
	part.Name = props.Name or "MapPart"
	part.Size = props.Size or Vector3.new(1, 1, 1)
	part.CFrame = props.CFrame or CFrame.new()
	part.Color = props.Color or COLORS.Charcoal
	part.Material = props.Material or Enum.Material.Metal
	part.Anchored = props.Anchored ~= false
	part.CanCollide = props.CanCollide ~= false
	part.CanTouch = props.CanTouch ~= false
	part.CanQuery = props.CanQuery ~= false
	part.CastShadow = props.CastShadow ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = props.Transparency or 0
	part.Reflectance = props.Reflectance or 0
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = parent
	return part
end

local function addSurfaceLight(part, brightness, range, angle)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = COLORS.WarmWhite
	light.Brightness = brightness or 1.2
	light.Range = range or 20
	light.Angle = angle or 110
	light.Shadows = true
	light.Parent = part
	return light
end

local function addPointLight(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
	return light
end

local function addTextSurface(part, face, rows, pixelsPerStud)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignGui"
	surface.Face = face
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = pixelsPerStud or 45
	surface.Parent = part

	for _, row in ipairs(rows) do
		local label = Instance.new("TextLabel")
		label.Name = row.Name or "Label"
		label.Size = UDim2.new(1, 0, row.Height or 1, 0)
		label.Position = UDim2.new(0, 0, row.Y or 0, 0)
		label.BackgroundTransparency = 1
		label.Text = row.Text
		label.TextColor3 = row.Color or COLORS.White
		label.TextScaled = true
		label.Font = row.Font or Enum.Font.GothamBold
		label.TextStrokeColor3 = COLORS.Black
		label.TextStrokeTransparency = row.StrokeTransparency or 0.45
		label.Parent = surface
	end

	return surface
end

local function makeSign(parent, name, text, cframe, size, face, color)
	local sign = makePart(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = COLORS.Black,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	addTextSurface(sign, face, {
		{ Name = "Title", Text = text, Color = color or COLORS.White },
	}, 50)
	return sign
end

local function makeNeon(parent, name, size, cframe, color)
	return makePart(parent, {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color or COLORS.Red,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
	})
end

local function buildShell(lobby)
	local shell = makeContainer("Model", "Shell", lobby)
	local wallPanels = makeContainer("Model", "WallPanels", shell)
	local structures = makeContainer("Model", "StructuralFrames", shell)

	makePart(shell, {
		Name = "LobbyFloor",
		Size = Vector3.new(80, 2, 180),
		CFrame = CFrame.new(0, -1, 0),
		Color = COLORS.Charcoal,
		Material = Enum.Material.Metal,
		Reflectance = 0.08,
	})
	makePart(shell, {
		Name = "LobbyCeiling",
		Size = Vector3.new(80, 1, 180),
		CFrame = CFrame.new(0, 27.5, 0),
		Color = COLORS.Black,
		Material = Enum.Material.Metal,
	})
	makePart(wallPanels, {
		Name = "NearWall",
		Size = Vector3.new(80, 28, 2),
		CFrame = CFrame.new(0, 14, -90),
		Color = COLORS.Charcoal,
		Material = Enum.Material.Metal,
	})

	for _, side in ipairs({ -1, 1 }) do
		makePart(wallPanels, {
			Name = side < 0 and "LeftWall" or "RightWall",
			Size = Vector3.new(2, 28, 180),
			CFrame = CFrame.new(side * 40, 14, 0),
			Color = COLORS.Charcoal,
			Material = Enum.Material.Metal,
		})

		for index, z in ipairs({ -67.5, -22.5, 22.5, 67.5 }) do
			makePart(wallPanels, {
				Name = string.format("SidePanel_%d_%d", side, index),
				Size = Vector3.new(0.5, 20, 40),
				CFrame = CFrame.new(side * 38.75, 13, z),
				Color = index % 2 == 0 and COLORS.DarkGray or COLORS.Charcoal,
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
		end

		for index, z in ipairs({ -88, -30, 30, 88 }) do
			makePart(structures, {
				Name = string.format("WallColumn_%d_%d", side, index),
				Size = Vector3.new(5, 27, 3),
				CFrame = CFrame.new(side * 37, 13.5, z),
				Color = COLORS.Black,
				Material = Enum.Material.DiamondPlate,
			})
		end
	end

	makePart(wallPanels, {
		Name = "FarWallLeft",
		Size = Vector3.new(28, 28, 2),
		CFrame = CFrame.new(-26, 14, 90),
		Color = COLORS.Charcoal,
		Material = Enum.Material.Metal,
	})
	makePart(wallPanels, {
		Name = "FarWallRight",
		Size = Vector3.new(28, 28, 2),
		CFrame = CFrame.new(26, 14, 90),
		Color = COLORS.Charcoal,
		Material = Enum.Material.Metal,
	})
	makePart(wallPanels, {
		Name = "FarWallUpper",
		Size = Vector3.new(24, 14, 2),
		CFrame = CFrame.new(0, 21, 90),
		Color = COLORS.Charcoal,
		Material = Enum.Material.Metal,
	})

	for _, x in ipairs({ -36, -18, 18, 36 }) do
		makePart(structures, {
			Name = "CeilingRib",
			Size = Vector3.new(2, 2, 178),
			CFrame = CFrame.new(x, 26, 0),
			Color = COLORS.Black,
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
		})
	end

	return shell
end

local function buildFloorDetails(lobby)
	local details = makeContainer("Model", "FloorDetails", lobby)

	makePart(details, {
		Name = "CentralAisle",
		Size = Vector3.new(30, 0.18, 176),
		CFrame = CFrame.new(0, 0.1, -1),
		Color = Color3.fromRGB(18, 20, 25),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.12,
		CanCollide = false,
		CanTouch = false,
	})

	for _, x in ipairs({ -30, -15, 15, 30 }) do
		makeNeon(details, "FloorLane", Vector3.new(0.2, 0.08, 174), CFrame.new(x, 0.24, -1))
	end

	for _, z in ipairs({ -80, -60, -40, -20, 0, 20, 40, 60, 80 }) do
		makePart(details, {
			Name = "FloorSeam",
			Size = Vector3.new(78, 0.03, 0.12),
			CFrame = CFrame.new(0, 0.22, z),
			Color = COLORS.Black,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
		})
	end

	return details
end

local function buildLighting(lobby)
	local lighting = makeContainer("Model", "Lighting", lobby)

	for _, x in ipairs({ -28, 28 }) do
		local strip = makeNeon(
			lighting,
			"LongCeilingStrip",
			Vector3.new(2, 0.25, 168),
			CFrame.new(x, 26.85, 0),
			COLORS.White
		)
		addSurfaceLight(strip, 1.15, 22, 115)
	end

	for index, z in ipairs({ -60, -30, 0, 30, 60 }) do
		local fixture = makeNeon(
			lighting,
			"CenterFixture" .. index,
			Vector3.new(8, 0.25, 2.5),
			CFrame.new(0, 26.8, z),
			COLORS.White
		)
		addSurfaceLight(fixture, 1.25, 24, 105)
	end

	for _, side in ipairs({ -1, 1 }) do
		makeNeon(
			lighting,
			"CeilingEdgeRed",
			Vector3.new(0.25, 0.25, 170),
			CFrame.new(side * 38.5, 25.5, 0)
		)
		for _, z in ipairs({ -45, 0, 45 }) do
			makeNeon(
				lighting,
				"WallRedStrip",
				Vector3.new(0.3, 0.22, 30),
				CFrame.new(side * 38.45, 20.5, z)
			)
		end
	end

	return lighting
end

local function buildCentralDestination(lobby)
	local destination = makeContainer("Model", "CentralDestination", lobby)

	local sign = makePart(destination, {
		Name = "FinalStrikeSign",
		Size = Vector3.new(46, 12, 1),
		CFrame = CFrame.new(0, 21, 88.7),
		Color = COLORS.Black,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	addTextSurface(sign, Enum.NormalId.Front, {
		{ Name = "Final", Text = "FINAL", Color = COLORS.White, Height = 0.48, Y = 0.02, Font = Enum.Font.GothamBlack },
		{ Name = "Strike", Text = "STRIKE", Color = COLORS.Red, Height = 0.48, Y = 0.50, Font = Enum.Font.GothamBlack },
	}, 20)

	local doorFrame = makeContainer("Model", "DoorFrame", destination)
	makePart(doorFrame, {
		Name = "DoorVoid",
		Size = Vector3.new(16, 13, 1),
		CFrame = CFrame.new(0, 6.5, 89),
		Color = Color3.fromRGB(4, 5, 7),
		Material = Enum.Material.SmoothPlastic,
	})
	for _, x in ipairs({ -10, 10 }) do
		makePart(doorFrame, {
			Name = "DoorPillar",
			Size = Vector3.new(4, 15, 4),
			CFrame = CFrame.new(x, 7.5, 87.8),
			Color = COLORS.Black,
			Material = Enum.Material.DiamondPlate,
		})
	end
	makePart(doorFrame, {
		Name = "DoorHeader",
		Size = Vector3.new(24, 3, 4),
		CFrame = CFrame.new(0, 14.5, 87.8),
		Color = COLORS.Black,
		Material = Enum.Material.DiamondPlate,
	})

	for _, x in ipairs({ -8.2, 8.2 }) do
		makeNeon(doorFrame, "DoorNeonSide", Vector3.new(0.35, 12.5, 0.35), CFrame.new(x, 6.5, 85.7))
	end
	local topNeon = makeNeon(
		doorFrame,
		"DoorNeonTop",
		Vector3.new(16.75, 0.35, 0.35),
		CFrame.new(0, 12.75, 85.7)
	)
	addPointLight(topNeon, COLORS.Red, 1.2, 20)

	makeSign(
		doorFrame,
		"StartHint",
		"ENTER TO START",
		CFrame.new(0, 10.5, 88.35),
		Vector3.new(12, 1.5, 0.3),
		Enum.NormalId.Front,
		COLORS.White
	)

	local startPad = makePart(lobby, {
		Name = "StartMatchPad",
		Size = Vector3.new(14, 11, 2),
		CFrame = CFrame.new(0, 5.5, 85.5),
		Color = COLORS.Red,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		CanQuery = false,
		CastShadow = false,
	})

	return destination, startPad
end

local function buildBayFrame(parent, side, centerZ, name, label)
	local bay = makeContainer("Model", name, parent)
	local inwardFace = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
	local frameX = side * 36
	local backX = side * 38.7

	makePart(bay, {
		Name = "RecessFloor",
		Size = Vector3.new(8, 0.4, 18),
		CFrame = CFrame.new(side * 36, 0.2, centerZ),
		Color = COLORS.DarkGray,
		Material = Enum.Material.DiamondPlate,
	})
	makePart(bay, {
		Name = "RecessBack",
		Size = Vector3.new(0.8, 13, 16),
		CFrame = CFrame.new(backX, 6.5, centerZ),
		Color = COLORS.Black,
		Material = Enum.Material.SmoothPlastic,
	})

	for _, zOffset in ipairs({ -9, 9 }) do
		makePart(bay, {
			Name = "OuterPillar",
			Size = Vector3.new(5, 15, 2.5),
			CFrame = CFrame.new(frameX, 7.5, centerZ + zOffset),
			Color = COLORS.Black,
			Material = Enum.Material.DiamondPlate,
		})
		makePart(bay, {
			Name = "InnerPillar",
			Size = Vector3.new(2, 13, 1),
			CFrame = CFrame.new(side * 33.8, 6.5, centerZ + zOffset * 0.88),
			Color = COLORS.DarkGray,
			Material = Enum.Material.Metal,
		})
	end
	makePart(bay, {
		Name = "OuterHeader",
		Size = Vector3.new(5, 2.5, 20.5),
		CFrame = CFrame.new(frameX, 14.5, centerZ),
		Color = COLORS.Black,
		Material = Enum.Material.DiamondPlate,
	})
	makePart(bay, {
		Name = "InnerHeader",
		Size = Vector3.new(2, 1.5, 18),
		CFrame = CFrame.new(side * 33.8, 13.5, centerZ),
		Color = COLORS.DarkGray,
		Material = Enum.Material.Metal,
	})

	makeNeon(
		bay,
		"NeonTop",
		Vector3.new(0.35, 0.35, 16),
		CFrame.new(side * 32.7, 12.8, centerZ)
	)
	for _, zOffset in ipairs({ -7.8, 7.8 }) do
		makeNeon(
			bay,
			"NeonSide",
			Vector3.new(0.35, 12, 0.35),
			CFrame.new(side * 32.7, 6.7, centerZ + zOffset)
		)
	end

	makeSign(
		bay,
		"BaySign",
		label,
		CFrame.new(side * 33.1, 16.7, centerZ),
		Vector3.new(1, 3.2, 18),
		inwardFace,
		COLORS.White
	)

	local fixture = makeNeon(
		bay,
		"BayOverheadLight",
		Vector3.new(5, 0.22, 8),
		CFrame.new(side * 34.5, 13.1, centerZ),
		COLORS.White
	)
	addSurfaceLight(fixture, 1.0, 16, 100)
	addPointLight(fixture, COLORS.WarmWhite, 0.8, 16)

	return bay
end

local function addCrosshair(parent, side, centerZ, centerY)
	local x = side * 38.05
	local y = centerY or 6
	makePart(parent, {
		Name = "CrosshairCore",
		Size = Vector3.new(0.3, 1.4, 1.4),
		CFrame = CFrame.new(x, y, centerZ),
		Color = COLORS.DeepRed,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		CanTouch = false,
	})
	for _, yOffset in ipairs({ -2.1, 2.1 }) do
		makeNeon(
			parent,
			"CrosshairVertical",
			Vector3.new(0.32, 1.5, 0.22),
			CFrame.new(x - side * 0.05, y + yOffset, centerZ)
		)
	end
	for _, zOffset in ipairs({ -2.1, 2.1 }) do
		makeNeon(
			parent,
			"CrosshairHorizontal",
			Vector3.new(0.32, 0.22, 1.5),
			CFrame.new(x - side * 0.05, y, centerZ + zOffset)
		)
	end
end

local function addArenaCue(bay, side, centerZ, text)
	addCrosshair(bay, side, centerZ, 6.2)
	makeSign(
		bay,
		"ArenaCue",
		text,
		CFrame.new(side * 37.9, 2.3, centerZ),
		Vector3.new(0.35, 1.3, 7),
		side < 0 and Enum.NormalId.Right or Enum.NormalId.Left,
		COLORS.Red
	)
end

local function addStaticWeapon(parent, weaponName, cframe)
	local tool = WeaponMeshes.build(weaponName)
	if not tool then
		warn("[LobbyBuilder] Unable to build display weapon: " .. weaponName)
		return
	end

	local display = makeContainer("Model", weaponName .. "Display", parent)
	for _, child in ipairs(tool:GetChildren()) do
		child.Parent = display
	end
	tool:Destroy()

	local handle = display:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		display:Destroy()
		warn("[LobbyBuilder] Display weapon has no Handle: " .. weaponName)
		return
	end
	display.PrimaryPart = handle
	for _, item in ipairs(display:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.CastShadow = true
		end
	end
	display:PivotTo(cframe)
end

local function addWeaponWall(bay, side, centerZ, weaponNames)
	local x = side * 37.5
	local slots = {
		Vector3.new(x, 9, centerZ - 4.2),
		Vector3.new(x, 9, centerZ + 3.8),
		Vector3.new(x, 5, centerZ - 4.2),
		Vector3.new(x, 5, centerZ + 3.8),
	}
	for index, weaponName in ipairs(weaponNames) do
		addStaticWeapon(bay, weaponName, CFrame.new(slots[index]))
	end
end

local function addShopTerminal(bay, side, centerZ)
	local terminal = makePart(bay, {
		Name = "ShopTerminal",
		Size = Vector3.new(2.5, 4, 3),
		CFrame = CFrame.new(side * 31.5, 2, centerZ + 6),
		Color = COLORS.Black,
		Material = Enum.Material.Metal,
	})
	addTextSurface(
		terminal,
		side < 0 and Enum.NormalId.Right or Enum.NormalId.Left,
		{
			{ Name = "Key", Text = "B", Color = COLORS.Red, Height = 0.55, Y = 0.05, Font = Enum.Font.GothamBlack },
			{ Name = "Hint", Text = "OPEN SHOP", Color = COLORS.White, Height = 0.28, Y = 0.67 },
		},
		45
	)

	local cart = makeContainer("Model", "CartCue", bay)
	local x = side * 31.2
	makeNeon(cart, "CartBasket", Vector3.new(0.3, 1.6, 3.2), CFrame.new(x, 6.2, centerZ + 5.8))
	makeNeon(cart, "CartHandle", Vector3.new(0.3, 0.25, 1.3), CFrame.new(x, 7.3, centerZ + 7.8))
	for _, zOffset in ipairs({ 4.9, 6.8 }) do
		makePart(cart, {
			Name = "CartWheel",
			Size = Vector3.new(0.35, 0.65, 0.65),
			CFrame = CFrame.new(x, 5, centerZ + zOffset),
			Color = COLORS.White,
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
			CanTouch = false,
		})
	end
end

local function addLeaderboard(bay, side, centerZ)
	local board = makePart(bay, {
		Name = "LeaderboardBoard",
		Size = Vector3.new(0.8, 11, 15),
		CFrame = CFrame.new(side * 37.7, 6.4, centerZ),
		Color = Color3.fromRGB(7, 8, 11),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local face = side < 0 and Enum.NormalId.Right or Enum.NormalId.Left
	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardGui"
	surface.Face = face
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 45
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.92, 0, 0.16, 0)
	title.Position = UDim2.new(0.04, 0, 0.03, 0)
	title.BackgroundColor3 = COLORS.DeepRed
	title.BorderSizePixel = 0
	title.Text = "LEADERBOARDS"
	title.TextColor3 = COLORS.White
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.Parent = surface

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(0.9, 0, 0.09, 0)
	header.Position = UDim2.new(0.05, 0, 0.22, 0)
	header.BackgroundTransparency = 1
	header.Text = "RANK       PLAYER       WINS"
	header.TextColor3 = COLORS.Red
	header.TextScaled = true
	header.Font = Enum.Font.Code
	header.Parent = surface

	local names = { "VIPER", "STINGER", "PHANTOM", "THUNDER", "WRAITH", "FANG" }
	for index, playerName in ipairs(names) do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. index
		row.Size = UDim2.new(0.9, 0, 0.09, 0)
		row.Position = UDim2.new(0.05, 0, 0.30 + (index - 1) * 0.105, 0)
		row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(20, 22, 27) or Color3.fromRGB(13, 15, 19)
		row.BorderSizePixel = 0
		row.Text = string.format("%02d          %-8s        %03d", index, playerName, 124 - index * 11)
		row.TextColor3 = index == 1 and COLORS.Red or COLORS.White
		row.TextScaled = true
		row.Font = Enum.Font.Code
		row.Parent = surface
	end
end

local function buildBays(lobby)
	local bays = makeContainer("Folder", "Bays", lobby)
	local left = makeContainer("Folder", "LeftSide", bays)
	local right = makeContainer("Folder", "RightSide", bays)

	local npcBay = buildBayFrame(left, -1, -45, "NPCTrainingBay", "NPC TRAINING")
	addCrosshair(npcBay, -1, -45, 6.2)
	local trainingPortal = makePart(lobby, {
		Name = "TrainingArenaPortal",
		Size = Vector3.new(2, 12, 14),
		CFrame = CFrame.new(-32.5, 6, -45),
		Color = COLORS.Red,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		CanQuery = false,
		CastShadow = false,
	})

	local duelBay = buildBayFrame(left, -1, 0, "OneVsOneBay", "1V1 ARENA")
	addArenaCue(duelBay, -1, 0, "1V1 QUEUE")

	-- Touch to join the 1v1 duel queue; touch again to leave (DuelService owns
	-- the toggle logic, mirroring TrainingArenaPortal's touch-pad pattern).
	makePart(lobby, {
		Name = "DuelQueuePortal",
		Size = Vector3.new(2, 12, 14),
		CFrame = CFrame.new(-32.5, 6, 0),
		Color = COLORS.Red,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
		CanQuery = false,
		CastShadow = false,
	})

	-- Live queue count readout — DuelService updates CountLabel.Text directly.
	local queueSign = makePart(duelBay, {
		Name = "DuelQueueSign",
		Size = Vector3.new(0.3, 2, 6),
		CFrame = CFrame.new(-37.7, 5, 0),
		Color = COLORS.Black,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local queueGui = Instance.new("SurfaceGui")
	queueGui.Name = "QueueGui"
	queueGui.Face = Enum.NormalId.Right
	queueGui.LightInfluence = 0
	queueGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	queueGui.PixelsPerStud = 40
	queueGui.Parent = queueSign
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, 0, 1, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "1V1 QUEUE: 0/2"
	countLabel.TextColor3 = COLORS.White
	countLabel.TextScaled = true
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextStrokeTransparency = 0.5
	countLabel.Parent = queueGui

	local shopBay = buildBayFrame(left, -1, 45, "WeaponShopBay", "WEAPON SHOP")
	addWeaponWall(shopBay, -1, 45, {
		"Stinger Mk2",
		"Phantom Apex",
		"Thunder Guard",
		"Wraith Scout",
	})
	addShopTerminal(shopBay, -1, 45)

	local playerBay = buildBayFrame(right, 1, 45, "PlayerArenaBay", "PLAYER ARENA")
	addArenaCue(playerBay, 1, 45, "ARENA")

	local armoryBay = buildBayFrame(right, 1, 0, "ArmoryBay", "ARMORY")
	addWeaponWall(armoryBay, 1, 0, {
		"Viper Aurum",
		"Phantom Finale",
		"Thunder Crown",
		"Wraith Abyss",
	})

	local leaderboardBay = buildBayFrame(right, 1, -45, "LeaderboardsBay", "LEADERBOARDS")
	addLeaderboard(leaderboardBay, 1, -45)

	return bays, trainingPortal
end

local function buildProps(lobby)
	local props = makeContainer("Folder", "Props", lobby)

	local cratePositions = {
		Vector3.new(-28, 1.5, -72),
		Vector3.new(-28, 1, 72),
		Vector3.new(28, 1.5, -72),
		Vector3.new(28, 1, 72),
	}
	for index, position in ipairs(cratePositions) do
		makePart(props, {
			Name = "SupplyCrate" .. index,
			Size = index % 2 == 0 and Vector3.new(3, 2, 3) or Vector3.new(3, 3, 3),
			CFrame = CFrame.new(position),
			Color = Color3.fromRGB(49, 52, 45),
			Material = Enum.Material.WoodPlanks,
		})
	end

	for index, position in ipairs({
		Vector3.new(-27, 1.5, -68),
		Vector3.new(27, 1.5, 68),
	}) do
		makePart(props, {
			Name = "StorageBarrel" .. index,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
			Color = COLORS.DarkGray,
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
		})
	end

	return props
end

local function createLobbySpawn(lobby)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.CFrame = CFrame.new(0, 1, -72) * CFrame.Angles(0, math.rad(180), 0)
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobby
	return spawn
end

function LobbyBuilder.build(parent)
	local lobby = makeContainer("Folder", "Lobby", parent)

	buildShell(lobby)
	buildFloorDetails(lobby)
	buildLighting(lobby)
	buildCentralDestination(lobby)
	buildBays(lobby)
	buildProps(lobby)
	createLobbySpawn(lobby)

	print("[LobbyBuilder] Industrial bunker lobby generated")
	return lobby
end

return LobbyBuilder
