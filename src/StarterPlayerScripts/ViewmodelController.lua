-- ViewmodelController.lua (StarterPlayerScripts)
-- First-person quality-of-life for the FPS view (#5):
--   1. Force arms visible — LockFirstPerson hides body parts via
--      LocalTransparencyModifier; we re-set arms to 0 each frame so the
--      player sees their own hands holding the gun.
--   2. LeftHand IK — when a Tool with a LeftGrip attachment is equipped, an
--      IKControl pins the LeftHand to that attachment so both hands appear
--      to grip the weapon (Pistol/Knife are single-handed and skip this).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ARM_PARTS = {
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
}

local function ensureLeftHandIK(char, tool)
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Tear down any previous IK before setting up new one
	local existing = humanoid:FindFirstChild("LeftHandIK")
	if existing then existing:Destroy() end

	if not tool then return end
	local handle = tool:FindFirstChild("Handle")
	if not handle then return end
	local leftGrip = handle:FindFirstChild("LeftGrip")
	if not leftGrip or not leftGrip:IsA("Attachment") then return end

	local leftHand = char:FindFirstChild("LeftHand")
	local leftUpperArm = char:FindFirstChild("LeftUpperArm")
	if not leftHand or not leftUpperArm then return end

	local ik = Instance.new("IKControl")
	ik.Name = "LeftHandIK"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = leftUpperArm
	ik.EndEffector = leftHand
	ik.Target = leftGrip  -- IKControl accepts Attachment targets
	ik.Weight = 1.0
	ik.Parent = humanoid
end

local function watchCharacter(char)
	-- Cache arm refs once
	local arms = {}
	for _, name in ipairs(ARM_PARTS) do
		local p = char:WaitForChild(name, 5)
		if p then table.insert(arms, p) end
	end

	-- Force arms visible every frame in first-person.
	-- (CameraScript sets LocalTransparencyModifier=1 on body parts under
	-- LockFirstPerson; we override the arms back to 0 here.)
	local conn = RunService.RenderStepped:Connect(function()
		if player.CameraMode == Enum.CameraMode.LockFirstPerson then
			for _, p in ipairs(arms) do
				p.LocalTransparencyModifier = 0
			end
		end
	end)
	-- Disconnect when this character despawns
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then conn:Disconnect() end
	end)

	-- Tool equip/unequip → rebuild IKControl
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			task.wait(0.1)  -- let server's grip weld settle before resolving attachments
			ensureLeftHandIK(char, c)
		end
	end)
	char.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then ensureLeftHandIK(char, nil) end
	end)

	-- Apply to any tool already equipped on character init (e.g. respawn into match)
	local existingTool = char:FindFirstChildOfClass("Tool")
	if existingTool then
		task.wait(0.1)
		ensureLeftHandIK(char, existingTool)
	end
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)
