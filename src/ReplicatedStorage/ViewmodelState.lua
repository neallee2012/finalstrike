-- ViewmodelState.lua (ReplicatedStorage ModuleScript)
-- Local-only coordination between WeaponClient and FirstPersonViewmodel.

local recoilEvent = Instance.new("BindableEvent")
local activeMuzzle = nil

local ViewmodelState = {}

function ViewmodelState.EmitRecoil(weaponType)
	recoilEvent:Fire(weaponType)
end

function ViewmodelState.OnRecoil(callback)
	return recoilEvent.Event:Connect(callback)
end

function ViewmodelState.SetActiveMuzzle(muzzle)
	activeMuzzle = muzzle
end

function ViewmodelState.GetActiveMuzzle()
	if activeMuzzle and activeMuzzle.Parent then
		return activeMuzzle
	end
	return nil
end

return ViewmodelState
