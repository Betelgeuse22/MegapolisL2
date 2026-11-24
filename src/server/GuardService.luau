--!strict

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local GameConstants = require(Configs:WaitForChild("GameConstants"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))

local GuardService = {}

local PATROL_WALK_SPEED = 10
local CHASE_WALK_SPEED = 22
local PATROL_WAIT_MIN = 2.0
local PATROL_WAIT_MAX = 4.0
local AGGRO_RANGE = 50
local CHASE_LEASH_RANGE = 70
local ATTACK_RANGE = 6
local ATTACK_COOLDOWN = 0.8
local AGGRO_SCAN_INTERVAL = 0.5
local CHASE_STEP_INTERVAL = 0.2
local WAYPOINT_REACH_DIST = 4.0
local GUARD_MAX_HEALTH = 1_000_000_000

type GuardAgent = {
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	active: boolean,
	targetPlayer: Player?,
	lastAttackTime: number,
	lastWaypointPart: BasePart?,
	connections: { RBXScriptConnection },
}

local initialized = false
local guardsFolderRef: Instance? = nil
local waypointsFolderRef: Instance? = nil
local activeGuards: { [Model]: GuardAgent } = {}

local function getGuardRoot(guardModel: Model): BasePart?
	local hrp = guardModel:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	if guardModel.PrimaryPart then
		return guardModel.PrimaryPart
	end
	return nil
end

local function getPlayerPkKarma(player: Player): number
	local attrKarma = player:GetAttribute("Karma")
	if type(attrKarma) == "number" and attrKarma > 0 then
		return attrKarma
	end

	if player:GetAttribute("IsPK") == true then
		return 1
	end

	local character = player.Character
	if character then
		local charKarma = character:GetAttribute("Karma")
		if type(charKarma) == "number" and charKarma > 0 then
			return charKarma
		end
		if character:GetAttribute("IsPK") == true then
			return 1
		end
	end

	local ok, profile = pcall(function()
		return DataManager.GetProfile(player)
	end)
	if ok and type(profile) == "table" and type(profile.Karma) == "number" and profile.Karma > 0 then
		return profile.Karma
	end

	return 0
end

local function getAlivePlayerParts(player: Player): (Model?, Humanoid?, BasePart?)
	if player.Parent ~= Players then
		return nil, nil, nil
	end
	local character = player.Character
	if not character or not character.Parent then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return character, humanoid, rootPart
end

local function findNearestPkPlayer(originPos: Vector3, maxRange: number): (Player?, number)
	local bestPlayer: Player? = nil
	local bestDist = maxRange

	for _, player in ipairs(Players:GetPlayers()) do
		local karma = getPlayerPkKarma(player)
		if karma > 0 then
			local _, _, targetRoot = getAlivePlayerParts(player)
			if targetRoot then
				local dist = (targetRoot.Position - originPos).Magnitude
				if dist <= bestDist then
					bestDist = dist
					bestPlayer = player
				end
			end
		end
	end

	return bestPlayer, bestDist
end

local function hideWaypointInstance(inst: Instance)
	if inst:IsA("BasePart") then
		inst.Transparency = 1
		inst.CanCollide = false
		inst.CanQuery = false
	else
		for _, desc in ipairs(inst:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Transparency = 1
				desc.CanCollide = false
				desc.CanQuery = false
			end
		end
	end
end

local function collectGuardWaypoints(): { BasePart }
	local parts: { BasePart } = {}
	local folder = waypointsFolderRef
	if not folder or not folder.Parent then
		local mapFolder = Workspace:FindFirstChild("Map")
		folder = if mapFolder then mapFolder:FindFirstChild("GuardWaypoints") else nil
		waypointsFolderRef = folder
	end

	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
	end

	return parts
end

local function sampleRandomPointInSafeZone(referenceY: number): Vector3
	local mapFolder = Workspace:FindFirstChild("Map")
	local zonesFolder = if mapFolder then mapFolder:FindFirstChild("Zones") else nil
	local safeZone = if zonesFolder then zonesFolder:FindFirstChild("CentralStation_SafeZone") else nil

	if safeZone then
		local zonePart: BasePart? = nil
		if safeZone:IsA("BasePart") then
			zonePart = safeZone
		else
			local candidates: { BasePart } = {}
			for _, desc in ipairs(safeZone:GetDescendants()) do
				if desc:IsA("BasePart") then
					table.insert(candidates, desc)
				end
			end
			if #candidates > 0 then
				zonePart = candidates[math.random(1, #candidates)]
			end
		end

		if zonePart then
			local worldSample: Vector3
			if zonePart:IsA("Part") and zonePart.Shape == Enum.PartType.Cylinder then
				local radius = math.max(0, math.min(zonePart.Size.Y, zonePart.Size.Z) * 0.5 - 3)
				local angle = math.random() * math.pi * 2
				local dist = math.sqrt(math.random()) * radius
				worldSample = zonePart.CFrame:PointToWorldSpace(Vector3.new(0, math.cos(angle) * dist, math.sin(angle) * dist))
			else
				local halfX = math.max(0, zonePart.Size.X * 0.5 - 3)
				local halfZ = math.max(0, zonePart.Size.Z * 0.5 - 3)
				local localOffset = Vector3.new(
					(math.random() * 2 - 1) * halfX,
					0,
					(math.random() * 2 - 1) * halfZ
				)
				worldSample = zonePart.CFrame:PointToWorldSpace(localOffset)
			end
			return Vector3.new(worldSample.X, referenceY, worldSample.Z)
		end
	end

	-- Legacy GameConstants SafeZone bounds fallback
	local randX = (math.random() * 2 - 1) * math.max(10, GameConstants.SAFE_ZONE_HALF_SIZE - 8)
	local randZ = GameConstants.SAFE_ZONE_MIN_Z
		+ math.random() * math.max(10, GameConstants.SAFE_ZONE_MAX_Z - GameConstants.SAFE_ZONE_MIN_Z)
	return Vector3.new(randX, referenceY, randZ)
end

local function chooseNextPatrolDestination(agent: GuardAgent): Vector3
	local waypoints = collectGuardWaypoints()
	if #waypoints > 0 then
		local chosen = waypoints[math.random(1, #waypoints)]
		if #waypoints > 1 and chosen == agent.lastWaypointPart then
			for _ = 1, 5 do
				local candidate = waypoints[math.random(1, #waypoints)]
				if candidate ~= agent.lastWaypointPart then
					chosen = candidate
					break
				end
			end
		end
		agent.lastWaypointPart = chosen
		return chosen.Position
	end

	agent.lastWaypointPart = nil
	return sampleRandomPointInSafeZone(agent.rootPart.Position.Y)
end

local function makeGuardInvulnerableAndMobile(guardModel: Model, humanoid: Humanoid, rootPart: BasePart): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}

	-- Ensure HumanoidRootPart and limbs are unanchored so Humanoid can move
	rootPart.Anchored = false
	for _, desc in ipairs(guardModel:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored = false
		end
	end

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)

	-- Make Guard invulnerable
	humanoid.MaxHealth = GUARD_MAX_HEALTH
	humanoid.Health = GUARD_MAX_HEALTH
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.WalkSpeed = PATROL_WALK_SPEED

	guardModel:SetAttribute("IsGuard", true)
	guardModel:SetAttribute("IsInvulnerable", true)

	local healthConn = humanoid.HealthChanged:Connect(function(newHealth: number)
		if newHealth < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
	table.insert(connections, healthConn)

	return connections
end

local function sendGuardAggroWarning(targetPlayer: Player)
	Remotes.SendChatMessage:FireClient(
		targetPlayer,
		"LOG_GUARD_PK_AGGRO",
		{ player = targetPlayer.DisplayName },
		{ 255, 70, 70 }
	)
end

local function performGuardAttack(agent: GuardAgent, targetPlayer: Player, targetChar: Model, targetHum: Humanoid, targetRoot: BasePart)
	local guardPos = agent.rootPart.Position
	local flatLook = Vector3.new(targetRoot.Position.X, guardPos.Y, targetRoot.Position.Z)
	if (flatLook - guardPos).Magnitude > 0.1 then
		agent.rootPart.CFrame = CFrame.lookAt(guardPos, flatLook)
	end

	local damage = math.max(50, math.floor(targetHum.MaxHealth * 0.40 + 0.5))
	targetHum.Health = math.max(0, targetHum.Health - damage)

	Remotes.CombatHitFeedback:FireAllClients(targetChar, damage, true, false, true, nil)
	Remotes.MobAttackedPlayer:FireClient(targetPlayer, agent.model, damage)
end

local function acquirePkTargetIfNearby(agent: GuardAgent): boolean
	if agent.targetPlayer then
		return true
	end
	local foundPlayer = findNearestPkPlayer(agent.rootPart.Position, AGGRO_RANGE)
	if foundPlayer then
		agent.targetPlayer = foundPlayer
		agent.humanoid.WalkSpeed = CHASE_WALK_SPEED
		sendGuardAggroWarning(foundPlayer)
		return true
	end
	return false
end

local function runChaseLoop(agent: GuardAgent)
	agent.humanoid.WalkSpeed = CHASE_WALK_SPEED

	while agent.active and agent.model.Parent and agent.targetPlayer do
		local targetPlayer = agent.targetPlayer
		if not targetPlayer then
			break
		end

		local karma = getPlayerPkKarma(targetPlayer)
		local targetChar, targetHum, targetRoot = getAlivePlayerParts(targetPlayer)
		if karma <= 0 or not targetChar or not targetHum or not targetRoot then
			agent.targetPlayer = nil
			break
		end

		local dist = (targetRoot.Position - agent.rootPart.Position).Magnitude
		if dist > CHASE_LEASH_RANGE then
			agent.targetPlayer = nil
			break
		end

		if dist <= ATTACK_RANGE then
			agent.humanoid:MoveTo(agent.rootPart.Position)
			local now = os.clock()
			if (now - agent.lastAttackTime) >= ATTACK_COOLDOWN then
				agent.lastAttackTime = now
				performGuardAttack(agent, targetPlayer, targetChar, targetHum, targetRoot)
			end
		else
			agent.humanoid:MoveTo(targetRoot.Position)
		end

		task.wait(CHASE_STEP_INTERVAL)
	end

	agent.targetPlayer = nil
	if agent.humanoid and agent.humanoid.Parent then
		agent.humanoid.WalkSpeed = PATROL_WALK_SPEED
	end
end

local function moveAlongPointWithAggroWatch(agent: GuardAgent, targetPoint: Vector3, maxSeconds: number): boolean
	local deadline = os.clock() + maxSeconds
	local nextScanAt = os.clock()
	agent.humanoid:MoveTo(targetPoint)

	while agent.active and agent.model.Parent do
		local now = os.clock()
		if now >= nextScanAt then
			nextScanAt = now + AGGRO_SCAN_INTERVAL
			if acquirePkTargetIfNearby(agent) then
				return false
			end
		end

		local flatDelta = (agent.rootPart.Position - targetPoint) * Vector3.new(1, 0, 1)
		if flatDelta.Magnitude <= WAYPOINT_REACH_DIST then
			return true
		end

		if now >= deadline then
			return false
		end

		task.wait(0.15)
	end

	return false
end

local function patrolToDestination(agent: GuardAgent, destination: Vector3)
	agent.humanoid.WalkSpeed = PATROL_WALK_SPEED

	local path = PathfindingService:CreatePath({
		AgentRadius = 2.0,
		AgentHeight = 5.0,
		AgentCanJump = true,
		WaypointSpacing = 6,
	})

	local computedOk = pcall(function()
		path:ComputeAsync(agent.rootPart.Position, destination)
	end)

	if computedOk and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints > 0 then
			for i = 2, #waypoints do
				if not agent.active or not agent.model.Parent or agent.targetPlayer then
					return
				end

				local wp = waypoints[i]
				if wp.Action == Enum.PathWaypointAction.Jump then
					agent.humanoid.Jump = true
				end

				local segDist = (wp.Position - agent.rootPart.Position).Magnitude
				local segTimeout = math.clamp(segDist / math.max(1, PATROL_WALK_SPEED) + 2.5, 2.5, 10.0)
				local reached = moveAlongPointWithAggroWatch(agent, wp.Position, segTimeout)
				if agent.targetPlayer then
					return
				end
				if not reached then
					break
				end
			end
			return
		end
	end

	-- Fallback to direct Humanoid:MoveTo if PathfindingService failed
	local totalDist = (destination - agent.rootPart.Position).Magnitude
	local fallbackTimeout = math.clamp(totalDist / math.max(1, PATROL_WALK_SPEED) + 3.0, 3.0, 16.0)
	moveAlongPointWithAggroWatch(agent, destination, fallbackTimeout)
end

local function waitAtWaypointWithAggroWatch(agent: GuardAgent, duration: number)
	local endTime = os.clock() + duration
	while agent.active and agent.model.Parent and os.clock() < endTime do
		if acquirePkTargetIfNearby(agent) then
			return
		end
		local remaining = endTime - os.clock()
		if remaining <= 0 then
			break
		end
		task.wait(math.min(AGGRO_SCAN_INTERVAL, remaining))
	end
end

local function startGuardLoop(agent: GuardAgent)
	task.spawn(function()
		-- Slight stagger so multiple guards don't compute paths on the exact same frame
		task.wait(math.random() * 0.8)

		while agent.active and agent.model.Parent do
			if agent.targetPlayer or acquirePkTargetIfNearby(agent) then
				runChaseLoop(agent)
			else
				local destination = chooseNextPatrolDestination(agent)
				patrolToDestination(agent, destination)
				if agent.active and agent.model.Parent and not agent.targetPlayer then
					local pauseSec = PATROL_WAIT_MIN + math.random() * (PATROL_WAIT_MAX - PATROL_WAIT_MIN)
					waitAtWaypointWithAggroWatch(agent, pauseSec)
				end
			end
		end
	end)
end

local function cleanupGuard(guardModel: Model)
	local agent = activeGuards[guardModel]
	if not agent then
		return
	end
	agent.active = false
	agent.targetPlayer = nil
	activeGuards[guardModel] = nil

	for _, conn in ipairs(agent.connections) do
		conn:Disconnect()
	end
	table.clear(agent.connections)
end

local function registerGuard(instance: Instance)
	if not instance:IsA("Model") or activeGuards[instance] then
		return
	end

	local guardModel = instance
	local humanoid = guardModel:FindFirstChildOfClass("Humanoid")
	local rootPart = getGuardRoot(guardModel)
	if not humanoid or not rootPart then
		warn(string.format("[GuardService] Guard model '%s' is missing Humanoid or HumanoidRootPart.", guardModel.Name))
		return
	end

	local connections = makeGuardInvulnerableAndMobile(guardModel, humanoid, rootPart)
	local destroyConn = guardModel.Destroying:Connect(function()
		cleanupGuard(guardModel)
	end)
	table.insert(connections, destroyConn)

	local agent: GuardAgent = {
		model = guardModel,
		humanoid = humanoid,
		rootPart = rootPart,
		active = true,
		targetPlayer = nil,
		lastAttackTime = 0,
		lastWaypointPart = nil,
		connections = connections,
	}

	activeGuards[guardModel] = agent
	startGuardLoop(agent)
end

local function bindWaypointsFolder(folder: Instance)
	if waypointsFolderRef == folder then
		return
	end
	waypointsFolderRef = folder

	for _, child in ipairs(folder:GetChildren()) do
		hideWaypointInstance(child)
	end
	folder.ChildAdded:Connect(hideWaypointInstance)
end

local function bindGuardsFolder(folder: Instance)
	if guardsFolderRef == folder then
		return
	end
	guardsFolderRef = folder

	for _, child in ipairs(folder:GetChildren()) do
		registerGuard(child)
	end
	folder.ChildAdded:Connect(registerGuard)
	folder.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Model") then
			cleanupGuard(child)
		end
	end)
end

function GuardService.Init()
	if initialized then
		return
	end
	initialized = true

	local function attachToMap(mapFolder: Instance)
		local existingWaypoints = mapFolder:FindFirstChild("GuardWaypoints")
		if existingWaypoints then
			bindWaypointsFolder(existingWaypoints)
		end

		local existingGuards = mapFolder:FindFirstChild("Guards")
		if existingGuards then
			bindGuardsFolder(existingGuards)
		end

		mapFolder.ChildAdded:Connect(function(child: Instance)
			if child.Name == "GuardWaypoints" then
				bindWaypointsFolder(child)
			elseif child.Name == "Guards" then
				bindGuardsFolder(child)
			end
		end)
	end

	local mapFolder = Workspace:FindFirstChild("Map") or Workspace:WaitForChild("Map", 3)
	if mapFolder then
		attachToMap(mapFolder)
	else
		Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Map" then
				attachToMap(child)
			end
		end)
	end
end

return GuardService
