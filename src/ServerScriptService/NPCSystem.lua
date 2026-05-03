-- NPCSystem.lua (ServerScriptService)
-- R15 NPC enemy spawning, AI behavior, patrol, chase, attack, loot drops

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponMeshes = require(ServerStorage:WaitForChild("WeaponMeshes"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

-- NPC weapon loadout by enemy type (#20). Picks an existing GameConfig weapon
-- whose mesh fits the NPC's role (Patrol = pistol, Armored = SMG, Elite = rifle).
-- The weapon is purely visual + drives muzzle flash position; damage still
-- comes from GameConfig.ENEMIES[type].Damage in the AI loop.
local NPC_WEAPON = {
	Patrol  = "Viper Mk1",       -- pistol
	Armored = "Stinger Mk2",     -- SMG
	Elite   = "Phantom Ranger",  -- rifle
}

local NPCSystem = {}
local activeNPCs = {}

-- PathfindingService agent params tuned for the standard R15 character
-- (~2 stud wide, ~5 stud tall, default HipHeight ~2.2).
local PATH_AGENT = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentJumpHeight = 7,
	AgentMaxSlope = 45,
}
local PATH_RECOMPUTE_DIST = 8     -- recompute when target moves this far
local PATH_RECOMPUTE_INTERVAL = 1.5 -- or after this many seconds
local WAYPOINT_REACHED_DIST = 4   -- advance to next waypoint within this distance

-- Per-type body color overrides. Patrol uses GameConfig.ENEMIES[].Color directly;
-- Armored gets dark steel; Elite gets pitch black (eyes glow via PointLight on Head).
local BODY_COLORS = {
	Patrol  = nil,  -- use config.Color
	Armored = Color3.fromRGB(60, 60, 75),
	Elite   = Color3.fromRGB(20, 20, 25),
}

local function paintBody(desc, color)
	desc.HeadColor     = color
	desc.TorsoColor    = color
	desc.LeftArmColor  = color
	desc.RightArmColor = color
	desc.LeftLegColor  = color
	desc.RightLegColor = color
end

-- Build a Part welded rigidly to a body part. Welded so it follows animation;
-- Massless so it doesn't affect physics. CFrame is local-offset relative to host.
local function attach(host, name, size, color, material, localOffset)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.Massless = true
	part.CFrame = host.CFrame * localOffset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = host
	weld.Part1 = part
	weld.Parent = part
	part.Parent = host.Parent
	return part
end

-- Per-type silhouette accessories built from primitives. Welded to Head/UpperTorso
-- so they ride the R15 animation and visually distinguish each NPC archetype.
local function dressNPC(model, enemyType)
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if not (head and torso) then return end

	if enemyType == "Patrol" then
		-- Security cap: dark dome + visor
		attach(head, "Cap",   Vector3.new(1.4, 0.4, 1.4), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic, CFrame.new(0, 0.65, 0))
		attach(head, "Visor", Vector3.new(1.5, 0.15, 1.0), Color3.fromRGB(15, 15, 20), Enum.Material.SmoothPlastic, CFrame.new(0, 0.45, -0.4))
		-- Chest badge
		attach(torso, "Badge", Vector3.new(0.45, 0.55, 0.1), Color3.fromRGB(220, 200, 60), Enum.Material.Neon, CFrame.new(-0.55, 0.3, -0.55))
	elseif enemyType == "Armored" then
		-- Combat helmet: thick black wrap-around
		attach(head, "Helmet",       Vector3.new(1.6, 1.0, 1.6), Color3.fromRGB(40, 40, 48), Enum.Material.Metal, CFrame.new(0, 0.35, 0))
		attach(head, "HelmetVisor",  Vector3.new(1.65, 0.3, 0.5), Color3.fromRGB(20, 25, 35), Enum.Material.Glass, CFrame.new(0, 0.05, -0.6))
		-- Tactical vest: bulky chest plate + 2 pouches
		attach(torso, "Vest",     Vector3.new(2.3, 1.7, 1.3), Color3.fromRGB(45, 50, 60), Enum.Material.Metal, CFrame.new(0, 0, 0))
		attach(torso, "PouchL",   Vector3.new(0.6, 0.5, 0.4), Color3.fromRGB(35, 38, 45), Enum.Material.Fabric, CFrame.new(-0.7, -0.4, -0.7))
		attach(torso, "PouchR",   Vector3.new(0.6, 0.5, 0.4), Color3.fromRGB(35, 38, 45), Enum.Material.Fabric, CFrame.new(0.7, -0.4, -0.7))
		attach(torso, "Shoulder", Vector3.new(2.6, 0.5, 1.2), Color3.fromRGB(55, 60, 70), Enum.Material.Metal, CFrame.new(0, 0.7, 0))
	elseif enemyType == "Elite" then
		-- Hood: oversized dark cowl extending forward and down
		attach(head, "Hood",     Vector3.new(1.7, 1.5, 1.7), Color3.fromRGB(15, 15, 20), Enum.Material.Fabric, CFrame.new(0, 0.25, 0.1))
		attach(head, "HoodFront",Vector3.new(1.4, 0.4, 0.3), Color3.fromRGB(15, 15, 20), Enum.Material.Fabric, CFrame.new(0, -0.1, -0.7))
		-- Glowing chest sigil (red)
		attach(torso, "Sigil",   Vector3.new(0.8, 0.8, 0.1), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, CFrame.new(0, 0.2, -0.55))
		-- Cape on back
		local cape = attach(torso, "Cape", Vector3.new(2.2, 3.5, 0.15), Color3.fromRGB(20, 18, 25), Enum.Material.Fabric, CFrame.new(0, -0.6, 0.6))
		cape.Transparency = 0.05
	end
end

-- Build R15 NPC using Roblox's standard character mesh.
-- Players:CreateHumanoidModelFromDescription returns a fully rigged R15 model
-- with MeshPart body parts, default Animate LocalScript, and Motor6D joints —
-- so we don't have to maintain rigging code ourselves.
local function createR15NPC(enemyType, position)
	local config = GameConfig.ENEMIES[enemyType]
	if not config then return nil end

	local desc = Instance.new("HumanoidDescription")
	paintBody(desc, BODY_COLORS[enemyType] or config.Color)

	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = enemyType .. "NPC"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = config.HP
	humanoid.Health = config.HP
	humanoid.WalkSpeed = config.Speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- Threat glow on chest so NPCs read in the dark cinematic backdrop.
	local upperTorso = model:FindFirstChild("UpperTorso")
	if upperTorso then
		local glow = Instance.new("PointLight")
		glow.Name = "ThreatGlow"
		glow.Color = Color3.fromRGB(255, 40, 30)
		glow.Brightness = enemyType == "Elite" and 4 or 2
		glow.Range = enemyType == "Elite" and 22 or 14
		glow.Shadows = true
		glow.Parent = upperTorso
	end

	-- Elite gets a separate red eye glow on the head.
	if enemyType == "Elite" then
		local head = model:FindFirstChild("Head")
		if head then
			local eyes = Instance.new("PointLight")
			eyes.Name = "EyeGlow"
			eyes.Color = Color3.fromRGB(255, 60, 50)
			eyes.Brightness = 3
			eyes.Range = 8
			eyes.Parent = head
		end
	end

	-- Per-type silhouette accessories (helmet, vest, hood, etc.)
	dressNPC(model, enemyType)

	-- Equip a visible weapon Tool so players can see what each NPC type carries (#20).
	-- Weapon is purely visual: damage still comes from config.Damage in the AI loop.
	local weaponName = NPC_WEAPON[enemyType]
	if weaponName then
		local tool = WeaponMeshes.build(weaponName)
		if tool then
			tool.Parent = model  -- Tool parented to character auto-equips and grips in RightHand
		end
	end

	-- Position so feet land just above the floor; Humanoid HipHeight handles
	-- the rest. The marker sits at y=1 (above ArenaFloor at y=0); pivot the
	-- HRP ~3 stud higher so the rig has room to settle.
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))

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

	-- NPC kill bounty for the player who landed the killing blow.
	-- LastAttackerId is stamped by MatchManager.FireWeapon when an NPC takes damage.
	local lastAttackerId = npcModel:GetAttribute("LastAttackerId")
	if lastAttackerId and _G.CurrencyService then
		local killer = Players:GetPlayerByUserId(lastAttackerId)
		if killer then
			local rewards = GameConfig.ECONOMY.Rewards
			local amount = (enemyType == "Patrol" and rewards.KillPatrolNPC)
				or (enemyType == "Armored" and rewards.KillArmoredNPC)
				or (enemyType == "Elite" and rewards.KillEliteNPC)
				or 0
			if amount > 0 then
				local actual = _G.CurrencyService.addCoins(killer, amount, "NpcKills")
				if actual > 0 then
					print(string.format("[Reward] %s +%d coins (Killed %s NPC)", killer.Name, actual, enemyType))
				end
			end
			-- Quest progress (separate from coin reward — increments regardless of cap)
			if _G.DailyQuestService then
				_G.DailyQuestService.recordEvent(killer, "NpcKill", 1)
			end
		end
	end

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

	-- Pathfinding state for Chase mode
	local path = PathfindingService:CreatePath(PATH_AGENT)
	local waypoints, waypointIndex = nil, 1
	local lastTargetPos, lastComputeTime = nil, 0

	local function chaseWithPath(root, targetPos)
		local now = tick()
		local needRecompute = (not waypoints) or (not lastTargetPos)
			or (lastTargetPos - targetPos).Magnitude > PATH_RECOMPUTE_DIST
			or (now - lastComputeTime) > PATH_RECOMPUTE_INTERVAL
		if needRecompute then
			local ok = pcall(function() path:ComputeAsync(root.Position, targetPos) end)
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints()
				waypointIndex = 1
				lastTargetPos = targetPos
				lastComputeTime = now
			else
				waypoints = nil  -- fall back to direct MoveTo
			end
		end
		if waypoints and waypointIndex <= #waypoints then
			local wp = waypoints[waypointIndex]
			if (root.Position - wp.Position).Magnitude < WAYPOINT_REACHED_DIST then
				waypointIndex = waypointIndex + 1
				if waypointIndex > #waypoints then
					humanoid:MoveTo(targetPos)
					return
				end
				wp = waypoints[waypointIndex]
			end
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(wp.Position)
		else
			humanoid:MoveTo(targetPos)  -- pathfinding failed, just charge
		end
	end

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
					-- Fire visual flash + tracer to all clients (#20). Origin = NPC's
					-- weapon Muzzle attachment if present; falls back to Head position.
					local muzzlePos = root.Position + Vector3.new(0, 1.5, 0)  -- chest-level fallback
					local tool = npcModel:FindFirstChildOfClass("Tool")
					local handle = tool and tool:FindFirstChild("Handle")
					local muzzle = handle and handle:FindFirstChild("Muzzle")
					if muzzle then muzzlePos = muzzle.WorldPosition end
					local targetPos = closestPlayer.Character
						and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
						and closestPlayer.Character.HumanoidRootPart.Position
						or (root.Position + Vector3.new(0, 1.5, 0))
					events.NPCFireWeapon:FireAllClients(npcModel, muzzlePos, targetPos)
				end
			else
				-- Chase via PathfindingService so NPCs route around cover
				npcModel:SetAttribute("State", "Chase")
				local targetPos = closestPlayer.Character.HumanoidRootPart.Position
				chaseWithPath(root, targetPos)
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
