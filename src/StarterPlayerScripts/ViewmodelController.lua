-- ViewmodelController.lua (StarterPlayerScripts)
-- First-person quality-of-life: force arms visible.
--
-- LockFirstPerson hides body parts via LocalTransparencyModifier; we re-set
-- the arm parts to 0 each frame so the player sees their own hands holding
-- the gun.
--
-- The off-hand IK that pins LeftHand to the weapon's LeftGrip Attachment is
-- now created on the server (WeaponMeshes.attachLeftHandIK, called from
-- MatchManager.attachWeapon + NPCSystem). Server-side IKControl replicates
-- to every viewer, so NPCs and other players also show two-hand grip — the
-- previous client-only setup left them gripping one-handed (#39).

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
