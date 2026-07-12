-- WeaponClient.lua (StarterPlayerScripts)
-- Client-side weapon input: shooting, reloading, aiming

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local R15Pose = require(ReplicatedStorage:WaitForChild("R15Pose"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local FireWeapon = events:WaitForChild("FireWeapon")
local ReloadWeapon = events:WaitForChild("ReloadWeapon")
local ReloadStateChanged = events:WaitForChild("ReloadStateChanged")

-- Look up the equipped weapon Tool's Muzzle attachment on the local character.
-- Returns nil if no Tool equipped or muzzle missing (e.g. first frame before
-- server attaches the Tool on respawn).
local function getMuzzle()
	local char = player.Character
	if not char then return nil end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then return nil end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return nil end
	return handle:FindFirstChild("Muzzle")
end

-- Quick muzzle flash at the gun barrel: bright sphere + PointLight, fade-out
-- in 0.08s. Local-only effect (each player sees their own).
local function spawnMuzzleFlash(muzzle)
	if not muzzle then return end
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(0.6, 0.6, 0.6)
	flash.CFrame = CFrame.new(muzzle.WorldPosition)
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 230, 140)
	flash.Shape = Enum.PartType.Ball
	flash.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 130)
	light.Brightness = 8
	light.Range = 12
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.08), { Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05) }):Play()
	TweenService:Create(light, TweenInfo.new(0.08), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.15)
end

local currentWeapon = GameConfig.STARTER_WEAPONS[1]
local canFire = true
local isReloading = false
local isFiring = false
local currentAmmo = 0
local reserveAmmo = 0
local magSize = 0
local reloadTrack = nil
local reloadAnimation = nil
local reloadPoseController = nil
local reloadGeneration = 0
local warnedReloadAnimationIds = {}
local warnedUnsupportedReloadPose = false

local RELOAD_POSE_PHASES = {
	{ Fraction = 0, Pose = R15Pose.Poses.ReloadEject },
	{ Fraction = 0.35, Pose = R15Pose.Poses.ReloadInsert },
	{ Fraction = 0.7, Pose = R15Pose.Poses.ReloadRack },
	{ Fraction = 0.9 },
}

local function stopReloadAnimation()
	reloadGeneration += 1
	if reloadTrack then
		reloadTrack:Stop(0.1)
		reloadTrack:Destroy()
		reloadTrack = nil
	end
	if reloadAnimation then
		reloadAnimation:Destroy()
		reloadAnimation = nil
	end
	if reloadPoseController then
		reloadPoseController:Destroy()
		reloadPoseController = nil
	end
end

local function warnReloadAnimationOnce(animationId, reason)
	if warnedReloadAnimationIds[animationId] then return end
	warnedReloadAnimationIds[animationId] = true
	warn(("Reload animation %d unavailable (%s); using procedural fallback")
		:format(animationId, reason))
end

task.spawn(function()
	for _, animationId in pairs(GameConfig.RELOAD_ANIMATION_IDS or {}) do
		if type(animationId) == "number" and animationId > 0 then
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. animationId
			local loaded, loadError = pcall(function()
				ContentProvider:PreloadAsync({ animation })
			end)
			animation:Destroy()
			if not loaded then
				warnReloadAnimationOnce(animationId, tostring(loadError))
			end
		end
	end
end)

local function playProceduralReload(duration, character, generation)
	if reloadGeneration ~= generation then return end

	local controller = R15Pose.new(character)
	if not controller:IsSupported() then
		controller:Destroy()
		if not warnedUnsupportedReloadPose then
			warnedUnsupportedReloadPose = true
			warn("Procedural reload pose requires an R15 character with both shoulder joints")
		end
		return
	end

	reloadPoseController = controller
	duration = math.max(duration, 0.1)
	local blendTime = math.min(0.12, duration * 0.1)
	controller:SetPose(RELOAD_POSE_PHASES[1].Pose, blendTime)

	task.spawn(function()
		local previousFraction = 0
		for index = 2, #RELOAD_POSE_PHASES do
			local phase = RELOAD_POSE_PHASES[index]
			task.wait(duration * (phase.Fraction - previousFraction))
			previousFraction = phase.Fraction

			if reloadGeneration ~= generation or reloadPoseController ~= controller then
				return
			end
			if phase.Pose then
				controller:SetPose(phase.Pose, blendTime)
			else
				controller:Reset(blendTime)
			end
		end
	end)
end

local function playReloadAnimation(duration, weaponName)
	stopReloadAnimation()
	local generation = reloadGeneration

	local config = GameConfig.WEAPONS[weaponName]
	local animationId = config
		and GameConfig.RELOAD_ANIMATION_IDS
		and GameConfig.RELOAD_ANIMATION_IDS[config.Type]

	local character = player.Character
	if not character then return end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if type(animationId) ~= "number" or animationId <= 0 or not animator then
		playProceduralReload(duration, character, generation)
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animationId
	local loaded, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not loaded then
		animation:Destroy()
		warnReloadAnimationOnce(animationId, tostring(trackOrError))
		playProceduralReload(duration, character, generation)
		return
	end

	local track = trackOrError
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false

	reloadAnimation = animation
	reloadTrack = track
	-- Start paused so asset-loading latency does not consume the reload clip.
	track:Play(0.1, 1, 0)

	-- Animation length can be zero until the asset finishes loading. Wait a
	-- bounded number of frames, then fit the clip to the authoritative duration.
	task.spawn(function()
		local startedAt = os.clock()
		for _ = 1, 60 do
			if reloadGeneration ~= generation or reloadTrack ~= track or track.Length > 0 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if reloadGeneration ~= generation or reloadTrack ~= track then return end

		if track.Length > 0 and duration > 0 then
			track:AdjustSpeed(track.Length / duration)
			return
		end

		track:Stop(0.05)
		track:Destroy()
		reloadTrack = nil
		if reloadAnimation == animation then
			animation:Destroy()
			reloadAnimation = nil
		end
		warnReloadAnimationOnce(animationId, "asset did not load within 60 frames")
		playProceduralReload(
			math.max(duration - (os.clock() - startedAt), 0.1),
			character,
			generation
		)
	end)
end

local function setReloadState(active, duration, weaponName)
	isReloading = active == true
	canFire = not isReloading
	if isReloading then
		playReloadAnimation(duration or 0, weaponName or currentWeapon)
	else
		stopReloadAnimation()
	end
end

-- Listen for weapon equip
events:WaitForChild("EquipWeapon").OnClientEvent:Connect(function(weaponName)
	if GameConfig.WEAPONS[weaponName] then
		setReloadState(false, 0, weaponName)
		currentWeapon = weaponName
		canFire = true
	end
end)

ReloadStateChanged.OnClientEvent:Connect(setReloadState)

events:WaitForChild("AmmoUpdate").OnClientEvent:Connect(function(magazine, reserve, maximum)
	currentAmmo = magazine
	reserveAmmo = reserve
	magSize = maximum
end)

player.CharacterAdded:Connect(function()
	setReloadState(false, 0, currentWeapon)
end)

local function fireWeapon()
	if not canFire or isReloading then return end

	local config = GameConfig.WEAPONS[currentWeapon]
	if not config then return end
	if config.Type ~= "Knife" and magSize > 0 and currentAmmo <= 0 then return end

	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	canFire = false

	-- Origin = gun muzzle if equipped, else head as fallback (e.g. first frame
	-- before server attaches weapon model on respawn).
	local muzzle = getMuzzle()
	local origin = muzzle and muzzle.WorldPosition or head.Position

	-- Two-stage aim (fixes #8): the muzzle is offset from the camera (right
	-- hand vs head/eye position), so firing FROM muzzle along the camera's ray
	-- direction puts shots noticeably off the crosshair. Instead:
	--   1. Cast from the camera along its forward vector to find what the
	--      crosshair is over (camera.CFrame.LookVector is always exactly the
	--      crosshair direction — more reliable than mouse.X/Y which can be
	--      off-by-GuiInset in first-person LockCenter mode).
	--   2. Aim from the muzzle TOWARD that point — bullets follow the crosshair
	--      regardless of muzzle offset.
	local cameraOrigin = camera.CFrame.Position
	local cameraDir = camera.CFrame.LookVector
	local aimParams = RaycastParams.new()
	aimParams.FilterType = Enum.RaycastFilterType.Exclude
	aimParams.FilterDescendantsInstances = { character }
	local maxRange = config.Range or 500
	local aimResult = workspace:Raycast(cameraOrigin, cameraDir * maxRange, aimParams)
	local targetPos = aimResult and aimResult.Position
		or (cameraOrigin + cameraDir * maxRange)
	local direction = (targetPos - origin).Unit

	-- Local muzzle flash for the local player (server's WeaponHit handles the
	-- impact spark; this is the gun-end of the shot).
	spawnMuzzleFlash(muzzle)

	if config.Type == "Knife" then
		-- Melee: short range check
		FireWeapon:FireServer(origin, direction, currentWeapon)
		task.delay(config.AttackRate, function()
			if not isReloading then canFire = true end
		end)
	else
		-- Ranged weapon
		FireWeapon:FireServer(origin, direction, currentWeapon)
		task.delay(config.FireRate, function()
			if not isReloading then canFire = true end
		end)
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = true
		fireWeapon()
	end

	if input.KeyCode == Enum.KeyCode.R then
		if not isReloading and reserveAmmo > 0 and currentAmmo < magSize then
			-- Block locally while waiting for the server's authoritative state
			-- response. A rejected request receives ReloadStateChanged(false).
			isReloading = true
			canFire = false
			ReloadWeapon:FireServer()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isFiring = false
	end
end)

-- Auto-fire for automatic weapons
RunService.Heartbeat:Connect(function()
	if isFiring and canFire and not isReloading then
		local config = GameConfig.WEAPONS[currentWeapon]
		if config and config.Auto then
			fireWeapon()
		end
	end
end)
