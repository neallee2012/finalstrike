-- ViewmodelController.lua (StarterPlayerScripts)
-- First-person quality-of-life: force arms visible.
--
-- LockFirstPerson hides body parts via LocalTransparencyModifier; we re-set
-- the arm parts to 0 each frame so the player sees their own hands holding
-- the gun.
--
-- Server-side off-hand IK is currently disabled in WeaponMeshes (#56) because
-- its rigid grip solver dragged character RootParts. This script only keeps
-- the real character arms visible in first-person; it does not restore the
-- two-hand pose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ARM_PARTS = {
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
}

local function watchCharacter(char)
	local arms = {}
	for _, name in ipairs(ARM_PARTS) do
		local p = char:WaitForChild(name, 5)
		if p then table.insert(arms, p) end
	end

	local conn = RunService.RenderStepped:Connect(function()
		if player.CameraMode == Enum.CameraMode.LockFirstPerson then
			for _, p in ipairs(arms) do
				p.LocalTransparencyModifier = 0
			end
		end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then conn:Disconnect() end
	end)
end

if player.Character then watchCharacter(player.Character) end
player.CharacterAdded:Connect(watchCharacter)
