-- NPCWeaponEffectsClient.lua (StarterPlayerScripts)
-- Renders muzzle flash + bullet tracer when an NPC fires (#20). Server fires
-- NPCFireWeapon RemoteEvent with (npcModel, muzzlePos, targetPos); each client
-- spawns purely local FX so dozens of NPCs in a fight don't replicate Parts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local events = ReplicatedStorage:WaitForChild("GameEvents")

local function spawnMuzzleFlash(pos)
	local flash = Instance.new("Part")
	flash.Size = Vector3.new(0.5, 0.5, 0.5)
	flash.CFrame = CFrame.new(pos)
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 220, 130)
	flash.Shape = Enum.PartType.Ball
	flash.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 110)
	light.Brightness = 6
	light.Range = 10
	light.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.08), {
		Transparency = 1,
		Size = Vector3.new(0.05, 0.05, 0.05),
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.08), { Brightness = 0 }):Play()
	Debris:AddItem(flash, 0.15)
end

local function spawnTracer(fromPos, toPos)
	-- Thin cylindrical beam from muzzle to target, fades out fast
	local diff = toPos - fromPos
	local length = diff.Magnitude
	if length < 0.5 then return end

	local tracer = Instance.new("Part")
	tracer.Size = Vector3.new(0.08, 0.08, length)
	tracer.CFrame = CFrame.lookAt(fromPos + diff * 0.5, toPos)
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 230, 140)
	tracer.Transparency = 0.3
	tracer.Parent = workspace

	TweenService:Create(tracer, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(tracer, 0.2)
end

events:WaitForChild("NPCFireWeapon").OnClientEvent:Connect(function(npcModel, muzzlePos, targetPos)
	-- npcModel param accepted for future per-NPC effects (sound by enemyType etc.)
	if not muzzlePos or not targetPos then return end
	spawnMuzzleFlash(muzzlePos)
	spawnTracer(muzzlePos, targetPos)
end)
