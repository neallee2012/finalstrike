-- NPCSystem.lua (ServerScriptService)
-- R15 NPC enemy spawning, AI behavior, patrol, chase, attack, loot drops

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local NPCSystem = {}
local activeNPCs = {}

-- Build R15 NPC model from scratch
local function createR15NPC(enemyType, position)
	local config = GameConfig.ENEMIES[enemyType]
	if not config then return nil end

	local model = Instance.new("Model")
	model.Name = enemyType .. "NPC"

	-- R15 body parts
	local partDefs = {
		{ Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), Pos = Vector3.new(0, 3, 0), Transparency = 1 },
		{ Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), Pos = Vector3.new(0, 4.8, 0) },
		{ Name = "UpperTorso", Size = Vector3.new(2, 1.6, 1), Pos = Vector3.new(0, 3.8, 0) },
		{ Name = "LowerTorso", Size = Vector3.new(2, 0.4, 1), Pos = Vector3.new(0, 2.8, 0) },
		{ Name = "LeftUpperArm", Size = Vector3.new(1, 1.2, 1), Pos = Vector3.new(-1.5, 3.8, 0) },
		{ Name = "LeftLowerArm", Size = Vector3.new(1, 1.2, 1), Pos = Vector3.new(-1.5, 2.6, 0) },
		{ Name = "LeftHand", Size = Vector3.new(1, 0.3, 1), Pos = Vector3.new(-1.5, 1.85, 0) },
		{ Name = "RightUpperArm", Size = Vector3.new(1, 1.2, 1), Pos = Vector3.new(1.5, 3.8, 0) },
		{ Name = "RightLowerArm", Size = Vector3.new(1, 1.2, 1), Pos = Vector3.new(1.5, 2.6, 0) },
		{ Name = "RightHand", Size = Vector3.new(1, 0.3, 1), Pos = Vector3.new(1.5, 1.85, 0) },
		{ Name = "LeftUpperLeg", Size = Vector3.new(1, 1.3, 1), Pos = Vector3.new(-0.5, 1.65, 0) },
		{ Name = "LeftLowerLeg", Size = Vector3.new(1, 1.3, 1), Pos = Vector3.new(-0.5, 0.35, 0) },
		{ Name = "LeftFoot", Size = Vector3.new(1, 0.3, 1), Pos = Vector3.new(-0.5, -0.35, 0) },
		{ Name = "RightUpperLeg", Size = Vector3.new(1, 1.3, 1), Pos = Vector3.new(0.5, 1.65, 0) },
		{ Name = "RightLowerLeg", Size = Vector3.new(1, 1.3, 1), Pos = Vector3.new(0.5, 0.35, 0) },
		{ Name = "RightFoot", Size = Vector3.new(1, 0.3, 1), Pos = Vector3.new(0.5, -0.35, 0) },
	}

	for _, def in ipairs(partDefs) do
		local part = Instance.new("Part")
		part.Name = def.Name
		part.Size = def.Size
		part.Position = position + def.Pos
		part.Anchored = false
		part.CanCollide = (def.Name == "HumanoidRootPart" or def.Name == "Head" or
			def.Name == "UpperTorso" or def.Name == "LowerTorso")
		part.Color = config.Color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if def.Transparency then part.Transparency = def.Transparency end

		-- Elite gets glowing eyes via head neon
		if def.Name == "Head" and enemyType == "Elite" then
			part.Material = Enum.Material.SmoothPlastic
			-- Add face
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Parent = part
		end

		part.Parent = model
	end

	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")

	-- Humanoid (R15 rig type)
	-- HipHeight = (HRP local Y) - (Foot local Y) + (foot half-height)
	--           = 3 - (-0.35) + 0.15 = 3.5
	-- Without this, HRP rests on floor and feet sink ~2.35 below ground.
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 3.5
	humanoid.MaxHealth = config.HP
	humanoid.Health = config.HP
	humanoid.WalkSpeed = config.Speed
	humanoid.Parent = model

	-- Motor6D joints for R15.
	-- Parent = closer-to-root body part, Child = further. Joint forces:
	--   Child.CFrame = Parent.CFrame * C0 * C1:Inverse()
	-- Convention: C0 = (Child - Parent) translation in Parent's local space, C1 = identity.
	-- partDefs.Pos values (in spawn-local space, treating spawn as origin) drive these C0s.
	local joints = {
		-- Spine
		{ Name = "Root",          Parent = "HumanoidRootPart", Child = "LowerTorso",   C0 = CFrame.new(0,   -0.2, 0) },
		{ Name = "Waist",         Parent = "LowerTorso",       Child = "UpperTorso",   C0 = CFrame.new(0,    1.0, 0) },
		{ Name = "Neck",          Parent = "UpperTorso",       Child = "Head",         C0 = CFrame.new(0,    1.0, 0) },
		-- Left leg
		{ Name = "LeftHip",       Parent = "LowerTorso",       Child = "LeftUpperLeg", C0 = CFrame.new(-0.5, -1.15, 0) },
		{ Name = "LeftKnee",      Parent = "LeftUpperLeg",     Child = "LeftLowerLeg", C0 = CFrame.new(0,   -1.3, 0) },
		{ Name = "LeftAnkle",     Parent = "LeftLowerLeg",     Child = "LeftFoot",     C0 = CFrame.new(0,   -0.7, 0) },
		-- Right leg
		{ Name = "RightHip",      Parent = "LowerTorso",       Child = "RightUpperLeg",C0 = CFrame.new(0.5, -1.15, 0) },
		{ Name = "RightKnee",     Parent = "RightUpperLeg",    Child = "RightLowerLeg",C0 = CFrame.new(0,   -1.3, 0) },
		{ Name = "RightAnkle",    Parent = "RightLowerLeg",    Child = "RightFoot",    C0 = CFrame.new(0,   -0.7, 0) },
		-- Left arm
		{ Name = "LeftShoulder",  Parent = "UpperTorso",       Child = "LeftUpperArm", C0 = CFrame.new(-1.5, 0,   0) },
		{ Name = "LeftElbow",     Parent = "LeftUpperArm",     Child = "LeftLowerArm", C0 = CFrame.new(0,   -1.2, 0) },
		{ Name = "LeftWrist",     Parent = "LeftLowerArm",     Child = "LeftHand",     C0 = CFrame.new(0,   -0.75,0) },
		-- Right arm
		{ Name = "RightShoulder", Parent = "UpperTorso",       Child = "RightUpperArm",C0 = CFrame.new(1.5,  0,   0) },
		{ Name = "RightElbow",    Parent = "RightUpperArm",    Child = "RightLowerArm",C0 = CFrame.new(0,   -1.2, 0) },
		{ Name = "RightWrist",    Parent = "RightLowerArm",    Child = "RightHand",    C0 = CFrame.new(0,   -0.75,0) },
	}

	for _, j in ipairs(joints) do
		local parentPart = model:FindFirstChild(j.Parent)
		local childPart = model:FindFirstChild(j.Child)
		local motor = Instance.new("Motor6D")
		motor.Name = j.Name
		motor.Part0 = parentPart
		motor.Part1 = childPart
		motor.C0 = j.C0
		motor.C1 = CFrame.new()  -- identity
		motor.Parent = childPart
	end

	-- Set attributes
	model:SetAttribute("EnemyType", enemyType)
	model:SetAttribute("HP", config.HP)
	model:SetAttribute("MaxHP", config.HP)
	model:SetAttribute("Damage", config.Damage)
	model:SetAttribute("DetectRange", config.DetectRange)
	model:SetAttribute("AttackRange", config.AttackRange)
	model:SetAttribute("AttackRate", config.AttackRate)
	model:SetAttribute("State", "Idle")  -- Idle, Patrol, Chase, Attack

	return model
end

-- Loot drop on NPC death
local function dropLoot(npcModel)
	local enemyType = npcModel:GetAttribute("EnemyType")
	local config = GameConfig.ENEMIES[enemyType]
	if not config then return end

	local pos = npcModel.PrimaryPart and npcModel.PrimaryPart.Position or Vector3.new(0, 5, 0)

	-- Roll for each loot type
	for lootType, chance in pairs(config.LootTable) do
		if math.random() <= chance then
			local loot = Instance.new("Part")
			loot.Name = lootType .. "Pickup"
			loot.Anchored = true
			loot.CanCollide = false
			loot.Size = Vector3.new(2, 2, 2)
			loot.Position = pos + Vector3.new(math.random(-3, 3), 1, math.random(-3, 3))
			loot.Shape = Enum.PartType.Ball
			loot:SetAttribute("LootType", lootType)

			-- Color by type
			if lootType == "Ammo" then
				loot.Color = Color3.fromRGB(255, 200, 50)
				loot.Material = Enum.Material.Neon
			elseif lootType == "Medkit" then
				loot.Color = Color3.fromRGB(50, 255, 100)
				loot.Material = Enum.Material.Neon
			elseif lootType == "Coin" then
				loot.Color = Color3.fromRGB(255, 215, 0)
				loot.Material = Enum.Material.Neon
			elseif lootType == "Weapon" then
				loot.Color = Color3.fromRGB(150, 100, 255)
				loot.Material = Enum.Material.Neon
				-- Random weapon
				local weaponNames = {}
				for name, _ in pairs(GameConfig.WEAPONS) do
					table.insert(weaponNames, name)
				end
				loot:SetAttribute("WeaponName", weaponNames[math.random(#weaponNames)])
			end

			-- Glow
			local light = Instance.new("PointLight")
			light.Color = loot.Color
			light.Brightness = 1
			light.Range = 10
			light.Parent = loot

			loot.Parent = workspace

			-- Pickup logic
			loot.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player then return end

				local mm = _G.MatchManager
				if not mm then return end
				local data = mm.getPlayerData(player)
				if not data or data.Eliminated then return end

				if lootType == "Ammo" then
					data.Ammo = data.Ammo + GameConfig.LOOT.Ammo.Amount
					events.AmmoUpdate:FireClient(player, data.Ammo, 30)
				elseif lootType == "Medkit" then
					mm.healPlayer(player, GameConfig.LOOT.Medkit.Heal)
				elseif lootType == "Coin" then
					data.Coins = data.Coins + GameConfig.LOOT.Coin.Amount
				elseif lootType == "Weapon" then
					local weaponName = loot:GetAttribute("WeaponName")
					if weaponName then
						data.Weapon = weaponName
						events.EquipWeapon:FireClient(player, weaponName)
					end
				end

				events.LootPickedUp:FireClient(player, lootType, lootType == "Coin" and GameConfig.LOOT.Coin.Amount or 1)
				loot:Destroy()
			end)

			-- Auto-despawn after 60s
			task.delay(60, function()
				if loot and loot.Parent then loot:Destroy() end
			end)
		end
	end
end

-- NPC AI behavior loop
local function runNPCAI(npcModel)
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local config = GameConfig.ENEMIES[npcModel:GetAttribute("EnemyType")]
	local lastAttack = 0
	local patrolTarget = nil

	-- Listen for HP changes (damage from weapons)
	npcModel:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = npcModel:GetAttribute("HP")
		if hp <= 0 then
			npcModel:SetAttribute("State", "Dead")
			dropLoot(npcModel)

			-- Death effect
			events.NPCEliminated:FireAllClients(
				npcModel:GetAttribute("EnemyType"),
				npcModel.PrimaryPart and npcModel.PrimaryPart.Position or Vector3.new(0, 0, 0)
			)

			task.wait(0.5)
			npcModel:Destroy()

			-- Remove from active list
			for i, npc in ipairs(activeNPCs) do
				if npc == npcModel then
					table.remove(activeNPCs, i)
					break
				end
			end
		end
	end)

	-- AI loop
	while npcModel.Parent and humanoid.Health > 0 do
		local root = npcModel.PrimaryPart
		if not root then break end

		local closestPlayer = nil
		local closestDist = math.huge

		for _, player in ipairs(Players:GetPlayers()) do
			local mm = _G.MatchManager
			if mm then
				local data = mm.getPlayerData(player)
				if data and not data.Eliminated and player.Character then
					local charRoot = player.Character:FindFirstChild("HumanoidRootPart")
					if charRoot then
						local dist = (charRoot.Position - root.Position).Magnitude
						if dist < closestDist then
							closestDist = dist
							closestPlayer = player
						end
					end
				end
			end
		end

		local detectRange = npcModel:GetAttribute("DetectRange")
		local attackRange = npcModel:GetAttribute("AttackRange")

		if closestPlayer and closestDist <= detectRange then
			if closestDist <= attackRange then
				-- Attack
				npcModel:SetAttribute("State", "Attack")
				humanoid:MoveTo(root.Position)  -- stop

				if tick() - lastAttack >= npcModel:GetAttribute("AttackRate") then
					lastAttack = tick()
					local mm = _G.MatchManager
					if mm then
						mm.damagePlayer(closestPlayer, npcModel:GetAttribute("Damage"))
					end
				end
			else
				-- Chase
				npcModel:SetAttribute("State", "Chase")
				local targetPos = closestPlayer.Character.HumanoidRootPart.Position
				humanoid:MoveTo(targetPos)
			end
		else
			-- Patrol
			npcModel:SetAttribute("State", "Patrol")
			if not patrolTarget or (root.Position - patrolTarget).Magnitude < 5 then
				patrolTarget = root.Position + Vector3.new(
					math.random(-30, 30), 0, math.random(-30, 30)
				)
			end
			humanoid:MoveTo(patrolTarget)
		end

		task.wait(0.3)
	end
end

-- Spawn all NPCs from markers
function NPCSystem.spawnNPCs()
	local arena = workspace:FindFirstChild("LastZone") and workspace.LastZone:FindFirstChild("Arena")
	if not arena then return end

	local npcSpawns = arena:FindFirstChild("NPCSpawns")
	if not npcSpawns then return end

	for _, marker in ipairs(npcSpawns:GetChildren()) do
		local enemyType = marker:GetAttribute("EnemyType")
		if enemyType then
			local npc = createR15NPC(enemyType, marker.Position)
			if npc then
				npc.Parent = workspace
				table.insert(activeNPCs, npc)
				task.spawn(runNPCAI, npc)
			end
		end
	end

	print("[NPCSystem] Spawned", #activeNPCs, "NPCs")
end

-- Cleanup all NPCs
function NPCSystem.cleanup()
	for _, npc in ipairs(activeNPCs) do
		if npc.Parent then npc:Destroy() end
	end
	activeNPCs = {}
end

-- Listen for phase changes to spawn/cleanup
local PhaseChanged = events:WaitForChild("PhaseChanged")

-- We spawn NPCs when server enters PvE phase
-- Since PhaseChanged fires to clients, we use _G to detect phase from MatchManager
task.spawn(function()
	while true do
		task.wait(1)
		local mm = _G.MatchManager
		if mm and mm.CurrentPhase == GameConfig.PHASE.PVE and #activeNPCs == 0 then
			NPCSystem.spawnNPCs()
		elseif mm and mm.CurrentPhase == GameConfig.PHASE.LOBBY then
			if #activeNPCs > 0 then
				NPCSystem.cleanup()
			end
		end
	end
end)

return NPCSystem
