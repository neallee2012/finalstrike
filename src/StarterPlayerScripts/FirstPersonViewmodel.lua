-- FirstPersonViewmodel.lua (StarterPlayerScripts)
-- Local camera-space hands and weapon. Gameplay remains on the real Tool.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local ViewmodelState = require(ReplicatedStorage:WaitForChild("ViewmodelState"))
local ReloadStateChanged = ReplicatedStorage:WaitForChild("GameEvents")
	:WaitForChild("ReloadStateChanged")

local VIEWMODEL_NAME = "FinalStrikeViewModel"
local VIEWMODEL_RENDER_STEP = "FinalStrikeViewModelRender"
local WALL_CHECK_DISTANCE = 2.6
local FIRST_PERSON_ENTER_DISTANCE = 0.6
local FIRST_PERSON_EXIT_DISTANCE = 0.75
local VIEWMODEL_OFFSETS = {
	Pistol = CFrame.new(0.65, -0.62, -2)
		* CFrame.Angles(math.rad(-5), math.rad(8), 0),
	SMG = CFrame.new(0.55, -0.7, -2.65)
		* CFrame.Angles(math.rad(-4), math.rad(7), 0),
	Rifle = CFrame.new(0.55, -0.72, -3.1)
		* CFrame.Angles(math.rad(-4), math.rad(7), 0),
	Shotgun = CFrame.new(0.55, -0.72, -3.2)
		* CFrame.Angles(math.rad(-4), math.rad(7), 0),
	Sniper = CFrame.new(0.55, -0.72, -3.25)
		* CFrame.Angles(math.rad(-4), math.rad(7), 0),
	Minigun = CFrame.new(0.55, -0.75, -3.25)
		* CFrame.Angles(math.rad(-4), math.rad(7), 0),
	Knife = CFrame.new(0.65, -0.65, -2)
		* CFrame.Angles(math.rad(-5), math.rad(8), 0),
}
local DEFAULT_VIEWMODEL_OFFSET = VIEWMODEL_OFFSETS.Rifle
local MESH_FORWARD_ROTATION = CFrame.Angles(0, math.rad(180), 0)
local RIGHT_HAND_POSE = CFrame.new(0.12, -0.18, 0.08)
	* CFrame.Angles(math.rad(-90), 0, math.rad(4))
local LEFT_HAND_POSES = {
	Pistol = CFrame.new(-0.25, -0.2, 0.12)
		* CFrame.Angles(math.rad(-90), 0, math.rad(-18)),
	Knife = CFrame.new(-0.42, -0.28, 0.2)
		* CFrame.Angles(math.rad(-80), math.rad(-12), math.rad(-20)),
}
local DEFAULT_LEFT_HAND_POSE = CFrame.new(-0.08, 0.14, -1.28)
	* CFrame.Angles(math.rad(-90), 0, 0)
local ARM_PARTS = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
}
local INTERACTIVE_UIS = {
	ShopUI = true,
	DailyQuestUI = true,
	TrainingArenaUI = true,
}
local RECOIL_STRENGTH = {
	Pistol = 1.0,
	SMG = 0.55,
	Rifle = 0.75,
	Shotgun = 1.35,
	Sniper = 1.6,
	Minigun = 0.4,
	Knife = 0.3,
}

local viewmodel = nil
local sprintHeld = false
local reloadActive = false
local reloadStartedAt = 0
local reloadDuration = 0

local function expAlpha(speed, dt)
	return 1 - math.exp(-speed * dt)
end

local function makeMotor(name, part0, part1, c0, c1, parent)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0 or CFrame.new()
	motor.C1 = c1 or CFrame.new()
	motor.Parent = parent or part0
	return motor
end

local function preparePart(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.LocalTransparencyModifier = 0
end

local function cloneLimb(source, name, scale)
	if not source or not source:IsA("BasePart") then return nil end
	local limb = source:Clone()
	limb.Name = name
	limb.Size = source.Size * scale
	for _, descendant in ipairs(limb:GetDescendants()) do
		if descendant:IsA("JointInstance")
			or descendant:IsA("Constraint")
			or descendant:IsA("Attachment")
			or descendant:IsA("BaseScript")
		then
			descendant:Destroy()
		end
	end
	preparePart(limb)
	return limb
end

local function collectRealParts(character, tool)
	local armParts = {}
	for partName in pairs(ARM_PARTS) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			table.insert(armParts, part)
		end
	end

	local toolParts = {}
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(toolParts, descendant)
		end
	end
	return armParts, toolParts
end

local function setPartsHidden(parts, hidden)
	for _, part in ipairs(parts) do
		if part.Parent then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function isInteractiveUIOpen()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return false end
	for name in pairs(INTERACTIVE_UIS) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then
			return true
		end
	end
	return false
end

local function destroyViewmodel()
	if not viewmodel then return end
	setPartsHidden(viewmodel.RealArmParts, false)
	setPartsHidden(viewmodel.RealToolParts, false)
	ViewmodelState.SetActiveMuzzle(nil)
	if viewmodel.Model then viewmodel.Model:Destroy() end
	viewmodel = nil
end

local function convertWeaponWeldsToMotors(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if part0 and part1 then
				makeMotor(
					"Viewmodel" .. part1.Name,
					part0,
					part1,
					part0.CFrame:ToObjectSpace(part1.CFrame),
					CFrame.new(),
					part0
				)
			end
			descendant:Destroy()
		end
	end
end

local function buildViewmodel(character, sourceTool)
	destroyViewmodel()

	local camera = workspace.CurrentCamera
	local sourceHandle = sourceTool and sourceTool:FindFirstChild("Handle")
	local sourceRightHand = character and character:FindFirstChild("RightHand")
	local sourceLeftHand = character and character:FindFirstChild("LeftHand")
	if not camera
		or not sourceHandle
		or not sourceRightHand
		or not sourceLeftHand
	then
		return
	end
	local weaponConfig = GameConfig.WEAPONS[sourceTool.Name]
	local weaponType = weaponConfig and weaponConfig.Type or "Rifle"
	local viewmodelOffset = VIEWMODEL_OFFSETS[weaponType] or DEFAULT_VIEWMODEL_OFFSET
	local leftHandPose = LEFT_HAND_POSES[weaponType] or DEFAULT_LEFT_HAND_POSE

	local model = Instance.new("Model")
	model.Name = VIEWMODEL_NAME
	model:SetAttribute("SourceWeapon", sourceTool.Name)
	model:SetAttribute("WeaponType", weaponType)
	model:SetAttribute("PresentationName", sourceTool.Name)

	local root = Instance.new("Part")
	root.Name = "ViewmodelRoot"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Parent = model

	local toolClone = sourceTool:Clone()
	for _, child in ipairs(toolClone:GetChildren()) do
		child.Parent = model
	end
	toolClone:Destroy()

	local handle = model:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		model:Destroy()
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") and descendant ~= root then
			preparePart(descendant)
		end
	end
	convertWeaponWeldsToMotors(model)

	local rightHand = cloneLimb(sourceRightHand, "RightHand", 0.55)
	local leftHand = cloneLimb(sourceLeftHand, "LeftHand", 0.55)
	if not rightHand or not leftHand then
		model:Destroy()
		return
	end
	rightHand.Parent = model
	leftHand.Parent = model

	local weaponMotor = makeMotor(
		"WeaponMotor",
		root,
		handle,
		viewmodelOffset * MESH_FORWARD_ROTATION,
		CFrame.new(),
		root
	)
	makeMotor(
		"RightHandMotor",
		handle,
		rightHand,
		RIGHT_HAND_POSE,
		CFrame.new(),
		handle
	)
	local leftHandMotor = makeMotor(
		"LeftHandMotor",
		handle,
		leftHand,
		leftHandPose,
		CFrame.new(),
		handle
	)
	model.PrimaryPart = root
	model.Parent = camera
	model:PivotTo(camera.CFrame)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, model }
	local realArmParts, realToolParts = collectRealParts(character, sourceTool)

	ViewmodelState.SetActiveMuzzle(handle:FindFirstChild("Muzzle"))
	viewmodel = {
		Model = model,
		Root = root,
		WeaponMotor = weaponMotor,
		LeftHandMotor = leftHandMotor,
		SourceTool = sourceTool,
		Character = character,
		Camera = camera,
		Motion = CFrame.new(),
		LeftHandMotion = CFrame.new(),
		Sway = Vector2.new(),
		BobTime = 0,
		Recoil = 0,
		RecoilVelocity = 0,
		RayParams = rayParams,
		RealArmParts = realArmParts,
		RealToolParts = realToolParts,
	}
	setPartsHidden(realArmParts, true)
	setPartsHidden(realToolParts, true)
end

local function isFirstPerson(character)
	local camera = workspace.CurrentCamera
	local head = character and character:FindFirstChild("Head")
	if not camera or not head or isInteractiveUIOpen() then return false end
	local distanceThreshold = viewmodel
		and FIRST_PERSON_EXIT_DISTANCE
		or FIRST_PERSON_ENTER_DISTANCE
	-- Interactive menus release both locks before this frame is rendered.
	return player.CameraMode == Enum.CameraMode.LockFirstPerson
		or (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			and (camera.CFrame.Position - head.Position).Magnitude < distanceThreshold)
end

local function getReloadMotion()
	if not reloadActive or reloadDuration <= 0 then
		return CFrame.new(), CFrame.new()
	end

	local progress = math.clamp((os.clock() - reloadStartedAt) / reloadDuration, 0, 1)
	local lowered = CFrame.new(-0.18, -0.32, 0.22)
		* CFrame.Angles(math.rad(22), math.rad(-18), math.rad(-12))
	local rack = CFrame.new(0.12, -0.12, 0.12)
		* CFrame.Angles(math.rad(-10), math.rad(12), math.rad(8))
	local leftAway = CFrame.new(-0.35, -0.35, 0.15)
		* CFrame.Angles(math.rad(25), 0, math.rad(-20))

	if progress < 0.25 then
		local alpha = progress / 0.25
		return CFrame.new():Lerp(lowered, alpha), CFrame.new():Lerp(leftAway, alpha)
	elseif progress < 0.75 then
		local alpha = (progress - 0.25) / 0.5
		return lowered:Lerp(rack, alpha), leftAway
	end

	local alpha = (progress - 0.75) / 0.25
	return rack:Lerp(CFrame.new(), alpha), leftAway:Lerp(CFrame.new(), alpha)
end

local function updateViewmodel(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local sourceTool = character and character:FindFirstChildOfClass("Tool")
	local active = character
		and humanoid
		and humanoid.Health > 0
		and sourceTool
		and isFirstPerson(character)

	if not active then
		destroyViewmodel()
		return
	end
	if not viewmodel
		or viewmodel.Character ~= character
		or viewmodel.SourceTool ~= sourceTool
		or viewmodel.Camera ~= workspace.CurrentCamera
		or viewmodel.Model.Parent ~= workspace.CurrentCamera
	then
		buildViewmodel(character, sourceTool)
	end
	if not viewmodel then return end

	local camera = workspace.CurrentCamera
	viewmodel.Model:PivotTo(camera.CFrame)
	setPartsHidden(viewmodel.RealArmParts, true)
	setPartsHidden(viewmodel.RealToolParts, true)

	local moving = humanoid.MoveDirection.Magnitude > 0.1
		and humanoid.FloorMaterial ~= Enum.Material.Air
	local sprinting = sprintHeld and moving and not reloadActive
	local now = os.clock()
	local idle = CFrame.new(
		math.sin(now * 1.3) * 0.012,
		math.cos(now * 1.7) * 0.01,
		0
	) * CFrame.Angles(0, 0, math.sin(now * 1.1) * 0.004)

	local bob = CFrame.new()
	if moving then
		viewmodel.BobTime += dt * (sprinting and 13 or 9)
		bob = CFrame.new(
			math.cos(viewmodel.BobTime) * (sprinting and 0.045 or 0.025),
			math.abs(math.sin(viewmodel.BobTime)) * (sprinting and 0.055 or 0.032),
			0
		) * CFrame.Angles(
			math.sin(viewmodel.BobTime) * 0.018,
			0,
			math.cos(viewmodel.BobTime) * 0.025
		)
	end

	local sprintPose = sprinting
		and (CFrame.new(0.28, -0.32, 0.18)
			* CFrame.Angles(math.rad(-18), math.rad(28), math.rad(8)))
		or CFrame.new()
	local wallHit = workspace:Raycast(
		camera.CFrame.Position,
		camera.CFrame.LookVector * WALL_CHECK_DISTANCE,
		viewmodel.RayParams
	)
	local wallAlpha = wallHit
		and math.clamp(1 - (wallHit.Distance / WALL_CHECK_DISTANCE), 0, 1)
		or 0
	local wallPose = CFrame.new(0, -0.3 * wallAlpha, 1.8 * wallAlpha)
		* CFrame.Angles(math.rad(-45 * wallAlpha), 0, 0)

	local mouseDelta = UserInputService:GetMouseDelta()
	local swayTarget = Vector2.new(
		math.clamp(-mouseDelta.X * 0.0018, -0.05, 0.05),
		math.clamp(-mouseDelta.Y * 0.0018, -0.05, 0.05)
	)
	viewmodel.Sway = viewmodel.Sway:Lerp(swayTarget, expAlpha(18, dt))
	local sway = CFrame.Angles(viewmodel.Sway.Y, viewmodel.Sway.X, 0)

	viewmodel.RecoilVelocity += -viewmodel.Recoil * 70 * dt
	viewmodel.RecoilVelocity *= math.exp(-12 * dt)
	viewmodel.Recoil += viewmodel.RecoilVelocity * dt
	if math.abs(viewmodel.Recoil) < 0.0001
		and math.abs(viewmodel.RecoilVelocity) < 0.0001
	then
		viewmodel.Recoil = 0
		viewmodel.RecoilVelocity = 0
	end
	local recoil = CFrame.new(0, 0, viewmodel.Recoil * 0.1)
		* CFrame.Angles(math.rad(-viewmodel.Recoil * 4), 0, 0)

	local reloadPose, leftHandPose = getReloadMotion()
	local targetMotion = idle * bob * sprintPose * wallPose * reloadPose
	viewmodel.Motion = viewmodel.Motion:Lerp(targetMotion, expAlpha(14, dt))
	viewmodel.LeftHandMotion = viewmodel.LeftHandMotion:Lerp(
		leftHandPose,
		expAlpha(18, dt)
	)
	viewmodel.WeaponMotor.Transform = viewmodel.Motion * sway * recoil
	viewmodel.LeftHandMotor.Transform = viewmodel.LeftHandMotion
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprintHeld = false
	end
end)

ViewmodelState.OnRecoil(function(weaponType)
	if not viewmodel then return end
	local strength = RECOIL_STRENGTH[weaponType] or 0.7
	viewmodel.RecoilVelocity = math.clamp(
		viewmodel.RecoilVelocity + (7 * strength),
		-12,
		12
	)
end)

ReloadStateChanged.OnClientEvent:Connect(function(active, duration)
	reloadActive = active == true
	if reloadActive then
		reloadStartedAt = os.clock()
		reloadDuration = math.max(duration or 0, 0.1)
	else
		reloadDuration = 0
	end
end)

RunService:BindToRenderStep(
	VIEWMODEL_RENDER_STEP,
	Enum.RenderPriority.Camera.Value + 1,
	updateViewmodel
)
