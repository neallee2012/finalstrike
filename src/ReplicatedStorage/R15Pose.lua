-- R15Pose.lua (ReplicatedStorage ModuleScript)
-- Procedural upper-body poses for R15 AnimationConstraint and Motor6D rigs.
-- It only writes existing animation-joint Transform values, never creates a
-- physics constraint, and never writes HumanoidRootPart.

local RunService = game:GetService("RunService")

local R15Pose = {}
local Controller = {}
Controller.__index = Controller

local JOINT_PAIRS = {
	["RightUpperArm|UpperTorso"] = "RightShoulder",
	["RightLowerArm|RightUpperArm"] = "RightElbow",
	["RightHand|RightLowerArm"] = "RightWrist",
	["LeftUpperArm|UpperTorso"] = "LeftShoulder",
	["LeftLowerArm|LeftUpperArm"] = "LeftElbow",
	["LeftHand|LeftLowerArm"] = "LeftWrist",
}

local TRACKED_JOINTS = {}
for _, jointName in pairs(JOINT_PAIRS) do
	TRACKED_JOINTS[jointName] = true
end

local function angles(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function pairKey(first, second)
	if first < second then return first .. "|" .. second end
	return second .. "|" .. first
end

local function getConstraintJointName(constraint)
	local attachment0 = constraint.Attachment0
	local attachment1 = constraint.Attachment1
	local part0 = attachment0 and attachment0.Parent
	local part1 = attachment1 and attachment1.Parent
	if not part0 or not part1 then return nil end
	return JOINT_PAIRS[pairKey(part0.Name, part1.Name)]
end

R15Pose.Poses = {
	TwoHandHold = {
		RightShoulder = angles(-55, 0, 10),
		RightElbow = angles(-25, 0, 0),
		LeftShoulder = angles(-65, -10, -25),
		LeftElbow = angles(-55, 0, 0),
		LeftWrist = angles(0, 15, 0),
	},
	NPCAim = {
		RightShoulder = angles(-75, 0, 5),
		RightElbow = angles(-15, 0, 0),
		LeftShoulder = angles(-72, -5, -18),
		LeftElbow = angles(-45, 0, 0),
		LeftWrist = angles(0, 10, 0),
	},
	NPCFire = {
		RightShoulder = CFrame.new(0, 0, 0.06) * angles(-68, 0, 7),
		RightElbow = angles(-22, 0, 0),
		LeftShoulder = angles(-68, -5, -18),
		LeftElbow = angles(-48, 0, 0),
		LeftWrist = angles(0, 10, 0),
	},
	ReloadEject = {
		RightShoulder = angles(-30, 0, 15),
		RightElbow = angles(-55, 0, 0),
		LeftShoulder = angles(-70, -15, -35),
		LeftElbow = angles(-75, 0, 0),
		LeftWrist = angles(15, 15, -10),
	},
	ReloadInsert = {
		RightShoulder = angles(-35, 0, 12),
		RightElbow = angles(-48, 0, 0),
		LeftShoulder = angles(-55, -12, -28),
		LeftElbow = angles(-65, 0, 0),
		LeftWrist = angles(-10, 10, 5),
	},
	ReloadRack = {
		RightShoulder = angles(-58, 0, 8),
		RightElbow = angles(-30, 0, 0),
		LeftShoulder = angles(-78, -5, -12),
		LeftElbow = angles(-38, 0, 0),
		LeftWrist = angles(0, 20, 0),
	},
}

function R15Pose.new(character)
	local self = setmetatable({
		Character = character,
		Joints = {},
		Current = {},
		Target = {},
		BlendSpeed = math.huge,
		BlendRemaining = 0,
		Active = false,
		Destroyed = false,
	}, Controller)

	local motorFallbacks = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and TRACKED_JOINTS[descendant.Name] then
			motorFallbacks[descendant.Name] = descendant
		elseif descendant:IsA("AnimationConstraint") then
			local jointName = getConstraintJointName(descendant)
			if jointName then
				self.Joints[jointName] = descendant
			end
		end
	end
	for name, motor in pairs(motorFallbacks) do
		if not self.Joints[name] then self.Joints[name] = motor end
	end
	for name in pairs(self.Joints) do
		self.Current[name] = CFrame.new()
		self.Target[name] = CFrame.new()
	end

	self.StepConnection = RunService.PreSimulation:Connect(function(dt)
		if self.Destroyed or not self.Active then return end
		local alpha = (self.BlendRemaining <= dt or self.BlendSpeed == math.huge)
			and 1
			or (1 - math.exp(-self.BlendSpeed * dt))
		for name, joint in pairs(self.Joints) do
			if joint.Parent then
				local current = self.Current[name]:Lerp(self.Target[name], alpha)
				self.Current[name] = current
				joint.Transform = current
			end
		end
		self.BlendRemaining = math.max(0, self.BlendRemaining - dt)
		self.Active = self.BlendRemaining > 0
	end)

	self.AncestryConnection = character.AncestryChanged:Connect(function(_, parent)
		if not parent then self:Destroy() end
	end)

	return self
end

function Controller:IsSupported()
	return self.Joints.RightShoulder ~= nil and self.Joints.LeftShoulder ~= nil
end

function Controller:SetPose(pose, blendTime)
	if self.Destroyed then return end
	self.BlendRemaining = math.max(blendTime or 0, 0)
	self.BlendSpeed = self.BlendRemaining > 0 and (5 / self.BlendRemaining) or math.huge
	self.Active = true
	for name in pairs(self.Joints) do
		self.Target[name] = pose[name] or CFrame.new()
	end
end

function Controller:Reset(blendTime)
	self:SetPose({}, blendTime)
end

function Controller:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.StepConnection then self.StepConnection:Disconnect() end
	if self.AncestryConnection then self.AncestryConnection:Disconnect() end
	for _, joint in pairs(self.Joints) do
		if joint.Parent then joint.Transform = CFrame.new() end
	end
end

return R15Pose
