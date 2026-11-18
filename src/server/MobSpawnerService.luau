--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local GameConstants = require(Configs:WaitForChild("GameConstants"))
local MobsConfig = require(Configs:WaitForChild("MobsConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type ActiveMobState = {
	model: Model,
	mobData: MobsConfig.MobData,
	spawnPoint: BasePart,
	spawnPosition: Vector3,
	SpawnedAt: number,
	nextIdleRotateTime: number,
	currentHp: number,
	maxHp: number,
	isSpoiled: boolean,
	hateList: { [Instance]: number },
	lastAttackTime: number,
	stunnedUntil: number,
	pDefDebuffUntil: number,
	pDefMult: number,
	isDead: boolean,
	swept: boolean,
}

type OutfitColors = {
	skin: Color3,
	torso: Color3,
	legs: Color3,
	accent: Color3,
	scale: number,
}

local MOB_OUTFITS: { [string]: OutfitColors } = {
	SleepingCommuter = {
		skin = Color3.fromRGB(235, 200, 175),
		torso = Color3.fromRGB(110, 125, 145),
		legs = Color3.fromRGB(55, 65, 80),
		accent = Color3.fromRGB(180, 180, 195),
		scale = 1.0,
	},
	CanCollector = {
		skin = Color3.fromRGB(220, 185, 155),
		torso = Color3.fromRGB(95, 130, 85),
		legs = Color3.fromRGB(70, 60, 50),
		accent = Color3.fromRGB(190, 150, 70),
		scale = 1.0,
	},
	StationAlchemist = {
		skin = Color3.fromRGB(210, 225, 215),
		torso = Color3.fromRGB(120, 60, 165),
		legs = Color3.fromRGB(45, 35, 60),
		accent = Color3.fromRGB(80, 240, 150),
		scale = 1.05,
	},
	CardboardKnight = {
		skin = Color3.fromRGB(230, 195, 165),
		torso = Color3.fromRGB(185, 140, 85),
		legs = Color3.fromRGB(145, 105, 65),
		accent = Color3.fromRGB(210, 175, 115),
		scale = 1.12,
	},
	TicketInspector = {
		skin = Color3.fromRGB(235, 200, 175),
		torso = Color3.fromRGB(35, 55, 115),
		legs = Color3.fromRGB(25, 35, 65),
		accent = Color3.fromRGB(235, 195, 60),
		scale = 1.08,
	},
	PlatformBaron = {
		skin = Color3.fromRGB(225, 185, 160),
		torso = Color3.fromRGB(145, 25, 35),
		legs = Color3.fromRGB(30, 25, 30),
		accent = Color3.fromRGB(255, 205, 55),
		scale = 1.45,
	},
}

local BOOTSTRAP_MOB_IDS: { string } = {
	"SleepingCommuter",
	"CanCollector",
	"StationAlchemist",
	"CardboardKnight",
	"TicketInspector",
	"PlatformBaron",
}

local LEASH_DISTANCE = 80
local MELEE_ATTACK_RANGE = 6.5
local MELEE_ATTACK_COOLDOWN = 1.8
local AI_TICK_INTERVAL = 0.25
local SPAWN_GRACE_PERIOD_SEC = 5.0
local MOB_FOV_MIN_DOT = 0.25

local MobSpawnerService = {}

local activeMobStates: { [Model]: ActiveMobState } = {}
local lastCharacterSpawnTime: { [Player]: number } = {}
local initialized = false

local function getOrCreateFolder(name: string): Folder
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local function createLimb(name: string, size: Vector3, color: Color3, parent: Model): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Anchored = false
	part.Parent = parent
	return part
end

local function createMotor6D(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	return motor
end

function MobSpawnerService.GetMobRoot(mobModel: Model): BasePart?
	if mobModel.PrimaryPart then
		return mobModel.PrimaryPart
	end
	local hrp = mobModel:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	local torso = mobModel:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return mobModel:FindFirstChildWhichIsA("BasePart")
end

local function buildMobRig(mobData: MobsConfig.MobData, spawnPosition: Vector3): Model
	local outfit: OutfitColors = MOB_OUTFITS[mobData.id]
		or {
			skin = Color3.fromRGB(230, 200, 170),
			torso = Color3.fromRGB(100, 100, 120),
			legs = Color3.fromRGB(50, 50, 65),
			accent = Color3.fromRGB(180, 180, 180),
			scale = 1.0,
		}
	local s = outfit.scale

	local model = Instance.new("Model")
	model.Name = mobData.id

	local rootPart = createLimb("HumanoidRootPart", Vector3.new(2 * s, 2 * s, 1 * s), outfit.torso, model)
	rootPart.Transparency = 1
	rootPart.CanCollide = true

	local torso = createLimb("Torso", Vector3.new(2 * s, 2 * s, 1 * s), outfit.torso, model)
	torso.CanCollide = true

	local head = createLimb("Head", Vector3.new(1.25 * s, 1.25 * s, 1.25 * s), outfit.skin, model)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local collar = createLimb("AccentCollar", Vector3.new(2.08 * s, 0.35 * s, 1.08 * s), outfit.accent, model)
	local collarWeld = Instance.new("WeldConstraint")
	collarWeld.Part0 = torso
	collarWeld.Part1 = collar
	collarWeld.Parent = collar

	local leftArm = createLimb("Left Arm", Vector3.new(1 * s, 2 * s, 1 * s), outfit.skin, model)
	local rightArm = createLimb("Right Arm", Vector3.new(1 * s, 2 * s, 1 * s), outfit.skin, model)
	local leftLeg = createLimb("Left Leg", Vector3.new(1 * s, 2 * s, 1 * s), outfit.legs, model)
	local rightLeg = createLimb("Right Leg", Vector3.new(1 * s, 2 * s, 1 * s), outfit.legs, model)

	local spawnCFrame = CFrame.new(spawnPosition + Vector3.new(0, 3 * s, 0))
	rootPart.CFrame = spawnCFrame
	torso.CFrame = spawnCFrame
	collar.CFrame = spawnCFrame * CFrame.new(0, 0.75 * s, 0)
	head.CFrame = spawnCFrame * CFrame.new(0, 1.5 * s, 0)
	leftArm.CFrame = spawnCFrame * CFrame.new(-1.5 * s, 0, 0)
	rightArm.CFrame = spawnCFrame * CFrame.new(1.5 * s, 0, 0)
	leftLeg.CFrame = spawnCFrame * CFrame.new(-0.5 * s, -2 * s, 0)
	rightLeg.CFrame = spawnCFrame * CFrame.new(0.5 * s, -2 * s, 0)

	createMotor6D("RootJoint", rootPart, torso, CFrame.new(), CFrame.new())
	createMotor6D("Neck", torso, head, CFrame.new(0, 1 * s, 0), CFrame.new(0, -0.5 * s, 0))
	createMotor6D("LeftShoulder", torso, leftArm, CFrame.new(-1 * s, 0.5 * s, 0), CFrame.new(0.5 * s, 0.5 * s, 0))
	createMotor6D("RightShoulder", torso, rightArm, CFrame.new(1 * s, 0.5 * s, 0), CFrame.new(-0.5 * s, 0.5 * s, 0))
	createMotor6D("LeftHip", torso, leftLeg, CFrame.new(-1 * s, -1 * s, 0), CFrame.new(-0.5 * s, 1 * s, 0))
	createMotor6D("RightHip", torso, rightLeg, CFrame.new(1 * s, -1 * s, 0), CFrame.new(0.5 * s, 1 * s, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = mobData.maxHp
	humanoid.Health = mobData.maxHp
	humanoid.WalkSpeed = if mobData.isRaidBoss then 11 else 13
	humanoid.HipHeight = 0
	humanoid.Parent = model

	model.PrimaryPart = rootPart

	model:SetAttribute("IsMob", true)
	model:SetAttribute("MobId", mobData.id)
	model:SetAttribute("NameKey", mobData.nameKey)
	model:SetAttribute("Level", mobData.level)
	model:SetAttribute("MaxHP", mobData.maxHp)
	model:SetAttribute("CurrentHP", mobData.maxHp)
	model:SetAttribute("BasePDef", mobData.pDef)
	model:SetAttribute("PDef", mobData.pDef)
	model:SetAttribute("MDef", mobData.mDef)
	model:SetAttribute("Atk", mobData.atk)
	model:SetAttribute("IsAggressive", mobData.isAggressive)
	model:SetAttribute("AggroRange", mobData.aggroRange)
	model:SetAttribute("IsSpoiled", false)
	model:SetAttribute("CanSweep", false)
	model:SetAttribute("IsStunned", false)
	model:SetAttribute("SpawnPosition", spawnPosition)

	return model
end

local function playMobAttackSwing(mobModel: Model, targetPosition: Vector3)
	task.spawn(function()
		pcall(function()
			local rootPart = MobSpawnerService.GetMobRoot(mobModel)
			local torso = mobModel:FindFirstChild("Torso") :: BasePart?
			if not rootPart or not torso then
				return
			end

			local outfit = MOB_OUTFITS[mobModel.Name]
			local s = if outfit then outfit.scale else 1.0

			local rightShoulder = torso:FindFirstChild("RightShoulder") :: Motor6D?
				or torso:FindFirstChild("Right Shoulder") :: Motor6D?
			local rootJoint = rootPart:FindFirstChild("RootJoint") :: Motor6D?

			local flatTarget = Vector3.new(targetPosition.X, rootPart.Position.Y, targetPosition.Z)
			local dir = flatTarget - rootPart.Position
			if dir.Magnitude > 0.2 then
				local unitDir = dir.Unit
				local lungePos = rootPart.Position + unitDir * math.min(0.8, dir.Magnitude * 0.2)
				rootPart.CFrame = CFrame.lookAt(lungePos, flatTarget)
			end

			local baseShoulderC0 = CFrame.new(1 * s, 0.5 * s, 0)
			local strikeShoulderC0 = baseShoulderC0 * CFrame.Angles(math.rad(85), math.rad(-20), math.rad(-15))
			local strikeRootC0 = CFrame.Angles(math.rad(-8), math.rad(-16), 0)

			-- Direct C0 assignment without TweenService (since Motor6D.C0 is read-only for TweenService)
			for step = 1, 3 do
				local alpha = step / 3
				if rightShoulder and rightShoulder.Parent then
					rightShoulder.C0 = baseShoulderC0:Lerp(strikeShoulderC0, alpha)
				end
				if rootJoint and rootJoint.Parent then
					rootJoint.C0 = CFrame.new():Lerp(strikeRootC0, alpha)
				end
				task.wait(0.035)
			end

			for step = 1, 4 do
				local alpha = step / 4
				if rightShoulder and rightShoulder.Parent then
					rightShoulder.C0 = strikeShoulderC0:Lerp(baseShoulderC0, alpha)
				end
				if rootJoint and rootJoint.Parent then
					rootJoint.C0 = strikeRootC0:Lerp(CFrame.new(), alpha)
				end
				task.wait(0.04)
			end
		end)
	end)
end

type SectorSpawnSpec = {
	mobId: string,
	pos: Vector3,
}

local SECTOR_MOB_SPAWNS: { SectorSpawnSpec } = {
	-- South Avenue & Park Plaza (Lv. 1-3, Z = 130..210, X = -55..55, 28-35 studs apart)
	{ mobId = "SleepingCommuter", pos = Vector3.new(-48, 3, 132) },
	{ mobId = "SleepingCommuter", pos = Vector3.new(-16, 3, 140) },
	{ mobId = "SleepingCommuter", pos = Vector3.new(18, 3, 134) },
	{ mobId = "SleepingCommuter", pos = Vector3.new(50, 3, 142) },
	{ mobId = "CanCollector", pos = Vector3.new(-36, 3, 182) },
	{ mobId = "CanCollector", pos = Vector3.new(0, 3, 194) },
	{ mobId = "CanCollector", pos = Vector3.new(36, 3, 182) },

	-- West Industrial Cargo Yard (Lv. 5-7, X = -215..-130, Z = -45..65, 30+ studs apart)
	{ mobId = "StationAlchemist", pos = Vector3.new(-136, 3, -34) },
	{ mobId = "StationAlchemist", pos = Vector3.new(-142, 3, 8) },
	{ mobId = "StationAlchemist", pos = Vector3.new(-136, 3, 48) },
	{ mobId = "CardboardKnight", pos = Vector3.new(-188, 3, -36) },
	{ mobId = "CardboardKnight", pos = Vector3.new(-198, 3, 10) },
	{ mobId = "CardboardKnight", pos = Vector3.new(-188, 3, 52) },

	-- East Turnstile & Subway Concourse (Lv. 9, X = 130..215, Z = -45..65, 32+ studs apart)
	{ mobId = "TicketInspector", pos = Vector3.new(140, 3, -32) },
	{ mobId = "TicketInspector", pos = Vector3.new(172, 3, 10) },
	{ mobId = "TicketInspector", pos = Vector3.new(140, 3, 52) },

	-- North Rail Depot Arena (Lv. 10 Raid Boss PlatformBaron + 2x TicketInspector Guards, Z = -215..-160)
	{ mobId = "PlatformBaron", pos = Vector3.new(0, 3.5, -195) },
	{ mobId = "TicketInspector", pos = Vector3.new(-28, 3, -172) },
	{ mobId = "TicketInspector", pos = Vector3.new(28, 3, -172) },
}

local function bootstrapDefaultSpawns(spawnsFolder: Folder)
	-- Clear existing spawn points so updated sector coordinates take effect cleanly
	for _, child in ipairs(spawnsFolder:GetChildren()) do
		child:Destroy()
	end

	for index, spec in ipairs(SECTOR_MOB_SPAWNS) do
		local spawnPart = Instance.new("Part")
		spawnPart.Name = string.format("Spawn_%02d_%s", index, spec.mobId)
		spawnPart.Size = Vector3.new(2, 1, 2)
		spawnPart.Position = spec.pos
		spawnPart.Anchored = true
		spawnPart.CanCollide = false
		spawnPart.Transparency = 1
		spawnPart:SetAttribute("MobId", spec.mobId)
		spawnPart.Parent = spawnsFolder
	end
end

local function isPlayerAlive(player: Player): (boolean, Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character or not character.Parent then
		return false, nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return false, nil, nil, nil
	end
	return true, character, humanoid, rootPart
end

local function getTopHatedTarget(state: ActiveMobState): (Instance?, Player?, Model?, BasePart?, Humanoid?)
	local bestEntity: Instance? = nil
	local bestPlayer: Player? = nil
	local bestBotModel: Model? = nil
	local bestHate = 0
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil

	for entity, hate in pairs(state.hateList) do
		if entity:IsA("Player") then
			if entity.Parent == Players then
				local alive, _, hum, root = isPlayerAlive(entity)
				if alive and hum and root then
					if GameConstants.IsInSafeZone(root.Position) then
						state.hateList[entity] = nil
					elseif hate > bestHate then
						bestHate = hate
						bestEntity = entity
						bestPlayer = entity
						bestBotModel = nil
						bestRoot = root
						bestHum = hum
					end
				else
					state.hateList[entity] = nil
				end
			else
				state.hateList[entity] = nil
			end
		elseif entity:IsA("Model") then
			local botHp = (entity:GetAttribute("CurrentHP") :: number?) or 0
			local hum = entity:FindFirstChildOfClass("Humanoid")
			local root = MobSpawnerService.GetMobRoot(entity)
			if entity.Parent and botHp > 0 and hum and root then
				if GameConstants.IsInSafeZone(root.Position) then
					state.hateList[entity] = nil
				elseif hate > bestHate then
					bestHate = hate
					bestEntity = entity
					bestPlayer = nil
					bestBotModel = entity
					bestRoot = root
					bestHum = hum
				end
			else
				state.hateList[entity] = nil
			end
		else
			state.hateList[entity] = nil
		end
	end

	return bestEntity, bestPlayer, bestBotModel, bestRoot, bestHum
end

function MobSpawnerService.SpawnMobAt(spawnPoint: BasePart): Model?
	local mobIdAttr = spawnPoint:GetAttribute("MobId")
	if type(mobIdAttr) ~= "string" then
		return nil
	end

	local mobData = MobsConfig[mobIdAttr]
	if not mobData then
		warn(string.format("[MobSpawnerService] Unknown MobId '%s' on spawn point %s", mobIdAttr, spawnPoint.Name))
		return nil
	end

	local activeMobsFolder = getOrCreateFolder("ActiveMobs")
	local spawnPos = spawnPoint.Position
	local model = buildMobRig(mobData, spawnPos)
	model.Parent = activeMobsFolder

	local now = os.clock()
	local state: ActiveMobState = {
		model = model,
		mobData = mobData,
		spawnPoint = spawnPoint,
		spawnPosition = spawnPos,
		SpawnedAt = now,
		nextIdleRotateTime = now + (4.0 + math.random() * 2.0),
		currentHp = mobData.maxHp,
		maxHp = mobData.maxHp,
		isSpoiled = false,
		hateList = {},
		lastAttackTime = 0,
		stunnedUntil = 0,
		pDefDebuffUntil = 0,
		pDefMult = 1.0,
		isDead = false,
		swept = false,
	}

	activeMobStates[model] = state
	return model
end

function MobSpawnerService.GetMobState(mobModel: Model): ActiveMobState?
	return activeMobStates[mobModel]
end

function MobSpawnerService.GetAllActiveMobs(): { [Model]: ActiveMobState }
	return activeMobStates
end

function MobSpawnerService.FindNearestAliveMob(origin: Vector3, maxRange: number): Model?
	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return nil
	end

	local bestMob: Model? = nil
	local bestDist = maxRange

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsMob") == true then
			local state = activeMobStates[child]
			local hp = if state then state.currentHp else ((child:GetAttribute("CurrentHP") :: number?) or 0)
			if hp > 0 and (not state or not state.isDead) then
				local root = MobSpawnerService.GetMobRoot(child)
				if root then
					local dist = (root.Position - origin).Magnitude
					if dist <= bestDist then
						bestDist = dist
						bestMob = child
					end
				end
			end
		end
	end

	return bestMob
end

function MobSpawnerService.FindNearestSpoiledCorpse(origin: Vector3, maxRange: number): Model?
	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return nil
	end

	local bestCorpse: Model? = nil
	local bestDist = maxRange

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsMob") == true then
			local hp = (child:GetAttribute("CurrentHP") :: number?) or 0
			local isSpoiled = child:GetAttribute("IsSpoiled") == true
			local canSweep = child:GetAttribute("CanSweep") == true
			if hp <= 0 and (isSpoiled or canSweep) then
				local root = MobSpawnerService.GetMobRoot(child)
				if root then
					local dist = (root.Position - origin).Magnitude
					if dist <= bestDist then
						bestDist = dist
						bestCorpse = child
					end
				end
			end
		end
	end

	return bestCorpse
end

function MobSpawnerService.MarkMobSpoiled(mobModel: Model)
	local state = activeMobStates[mobModel]
	if state then
		state.isSpoiled = true
	end
	mobModel:SetAttribute("IsSpoiled", true)
end

function MobSpawnerService.AddHate(mobModel: Model, attackerEntity: Instance, amount: number)
	local state = activeMobStates[mobModel]
	if not state or state.isDead or not attackerEntity then
		return
	end
	local currentHate = state.hateList[attackerEntity] or 0
	state.hateList[attackerEntity] = currentHate + math.max(1, amount)

	local rootPart = MobSpawnerService.GetMobRoot(mobModel)
	if rootPart then
		for otherModel, otherState in pairs(activeMobStates) do
			if otherModel ~= mobModel and not otherState.isDead and otherState.mobData.isSocial then
				local otherRoot = MobSpawnerService.GetMobRoot(otherModel)
				if otherRoot then
					local dist = (otherRoot.Position - rootPart.Position).Magnitude
					if dist <= math.max(12, otherState.mobData.aggroRange) and next(otherState.hateList) == nil then
						otherState.hateList[attackerEntity] = 1
					end
				end
			end
		end
	end
end

function MobSpawnerService.StunMob(mobModel: Model, duration: number)
	local state = activeMobStates[mobModel]
	if not state or state.isDead then
		return
	end

	local untilTime = os.clock() + duration
	if untilTime > state.stunnedUntil then
		state.stunnedUntil = untilTime
	end
	mobModel:SetAttribute("IsStunned", true)

	local humanoid = mobModel:FindFirstChildOfClass("Humanoid")
	local rootPart = MobSpawnerService.GetMobRoot(mobModel)
	if humanoid and rootPart then
		humanoid:MoveTo(rootPart.Position)
	end
end

function MobSpawnerService.ApplyPDefDebuff(mobModel: Model, mult: number, duration: number)
	local state = activeMobStates[mobModel]
	if not state or state.isDead then
		return
	end
	state.pDefMult = mult
	state.pDefDebuffUntil = os.clock() + duration
	local newPDef = math.max(1, math.floor(state.mobData.pDef * mult + 0.5))
	mobModel:SetAttribute("PDef", newPDef)
end

function MobSpawnerService.KnockbackMob(mobModel: Model, sourcePosition: Vector3, distance: number)
	local state = activeMobStates[mobModel]
	if not state or state.isDead then
		return
	end

	local rootPart = MobSpawnerService.GetMobRoot(mobModel)
	if not rootPart then
		return
	end

	local flatDelta = Vector3.new(rootPart.Position.X - sourcePosition.X, 0, rootPart.Position.Z - sourcePosition.Z)
	local pushDir = if flatDelta.Magnitude > 0.05 then flatDelta.Unit else Vector3.new(0, 0, -1)
	local targetPos = rootPart.Position + pushDir * distance

	local humanoid = mobModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(targetPos)
	end

	mobModel:PivotTo(CFrame.lookAt(targetPos, Vector3.new(sourcePosition.X, targetPos.Y, sourcePosition.Z)))
end

function MobSpawnerService.SweepCorpse(mobModel: Model): (boolean, MobsConfig.MobData?)
	if not mobModel or not mobModel.Parent then
		return false, nil
	end

	local state = activeMobStates[mobModel]
	local isSpoiled = (state and state.isSpoiled) or (mobModel:GetAttribute("IsSpoiled") == true)
	local canSweep = mobModel:GetAttribute("CanSweep") == true
	local hp = if state then state.currentHp else ((mobModel:GetAttribute("CurrentHP") :: number?) or 0)

	if hp > 0 or (not isSpoiled and not canSweep) then
		return false, nil
	end
	if state and state.swept then
		return false, nil
	end

	local mobId = (mobModel:GetAttribute("MobId") :: string?) or mobModel.Name
	local mobData = if state then state.mobData else MobsConfig[mobId]
	if not mobData then
		return false, nil
	end

	if state then
		state.swept = true
	end
	mobModel:SetAttribute("CanSweep", false)
	mobModel:SetAttribute("IsSpoiled", false)

	activeMobStates[mobModel] = nil
	mobModel:Destroy()

	return true, mobData
end

function MobSpawnerService.HandleMobDeath(mobModel: Model)
	local state = activeMobStates[mobModel]
	if state and state.isDead then
		return
	end

	local isSpoiled = (state and state.isSpoiled) or (mobModel:GetAttribute("IsSpoiled") == true)
	if state then
		state.isDead = true
		state.currentHp = 0
		table.clear(state.hateList)
	end

	if isSpoiled then
		mobModel:SetAttribute("IsSpoiled", true)
		mobModel:SetAttribute("CanSweep", true)
	end
	mobModel:SetAttribute("CurrentHP", 0)
	mobModel:SetAttribute("IsStunned", false)

	local humanoid = mobModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end

	local rootPart = MobSpawnerService.GetMobRoot(mobModel)
	if rootPart then
		rootPart.Anchored = true
	end

	local corpseDuration = if isSpoiled then 8.0 else 2.0
	local spawnPoint = if state then state.spawnPoint else nil
	local respawnTime = if state then state.mobData.respawnTime else 10

	task.delay(corpseDuration, function()
		activeMobStates[mobModel] = nil
		if mobModel.Parent then
			mobModel:Destroy()
		end
	end)

	if spawnPoint then
		task.delay(respawnTime, function()
			if spawnPoint and spawnPoint.Parent then
				MobSpawnerService.SpawnMobAt(spawnPoint)
			end
		end)
	end
end

local function stepMobAI(state: ActiveMobState, now: number)
	local model = state.model
	if not model.Parent then
		activeMobStates[model] = nil
		return
	end

	if state.currentHp <= 0 or ((model:GetAttribute("CurrentHP") :: number?) or 0) <= 0 then
		if not state.isDead then
			MobSpawnerService.HandleMobDeath(model)
		end
		return
	end

	if state.pDefDebuffUntil > 0 and now >= state.pDefDebuffUntil then
		state.pDefDebuffUntil = 0
		state.pDefMult = 1.0
		model:SetAttribute("PDef", state.mobData.pDef)
	end

	local rootPart = MobSpawnerService.GetMobRoot(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then
		return
	end

	if now < state.stunnedUntil then
		if model:GetAttribute("IsStunned") ~= true then
			model:SetAttribute("IsStunned", true)
		end
		humanoid:MoveTo(rootPart.Position)
		return
	elseif model:GetAttribute("IsStunned") == true then
		model:SetAttribute("IsStunned", false)
	end

	local distFromSpawn = (rootPart.Position - state.spawnPosition).Magnitude
	local touchedSafeZone = GameConstants.IsInSafeZone(rootPart.Position)
		or (
			math.abs(rootPart.Position.X) <= (GameConstants.SAFE_ZONE_HALF_SIZE + 3)
			and rootPart.Position.Z >= (GameConstants.SAFE_ZONE_MIN_Z - 3)
			and rootPart.Position.Z <= (GameConstants.SAFE_ZONE_MAX_Z + 3)
		)
	if distFromSpawn > LEASH_DISTANCE or touchedSafeZone then
		table.clear(state.hateList)
		state.stunnedUntil = 0
		state.isSpoiled = false
		state.currentHp = state.mobData.maxHp
		model:SetAttribute("IsStunned", false)
		model:SetAttribute("IsSpoiled", false)
		model:SetAttribute("CanSweep", false)
		model:SetAttribute("CurrentHP", state.mobData.maxHp)
		model:SetAttribute("PDef", state.mobData.pDef)
		humanoid.Health = state.mobData.maxHp
		model:PivotTo(CFrame.new(state.spawnPosition + Vector3.new(0, 3.5, 0)))
		humanoid:MoveTo(state.spawnPosition)
		return
	end

	local topEntity, topPlayer, topBotModel, targetRoot, targetHum = getTopHatedTarget(state)

	-- Idle Look-Around Behavior while HateList is empty
	if not topEntity and state.mobData.isAggressive then
		if now >= state.nextIdleRotateTime then
			state.nextIdleRotateTime = now + (4.0 + math.random() * 2.0)
			local deltaAngle = math.rad(math.random(-135, 135))
			rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, deltaAngle, 0)
		end
	end

	-- Smart Passive Aggro: Rule A (5s Grace Period) + Rule B (120-deg FOV dot >= 0.25 + Player Movement) + Not in Safe Zone
	-- Red PK Players (Karma > 0) bypass spawn grace period and FOV/movement checks!
	if not topEntity and state.mobData.isAggressive and state.mobData.aggroRange > 0 then
		local mobGraceElapsed = (now - state.SpawnedAt) >= SPAWN_GRACE_PERIOD_SEC
		local closestDist = state.mobData.aggroRange
		local closestPlayer: Player? = nil
		local mobPos = rootPart.Position
		local flatMobLook = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local mobLookUnit = if flatMobLook.Magnitude > 0.05 then flatMobLook.Unit else Vector3.new(0, 0, -1)

		for _, player in ipairs(Players:GetPlayers()) do
			local playerKarma = (player:GetAttribute("Karma") :: number?) or 0
			local isPkCriminal = playerKarma > 0
			local playerSpawnedAt = lastCharacterSpawnTime[player] or 0
			if isPkCriminal or (mobGraceElapsed and (now - playerSpawnedAt) >= SPAWN_GRACE_PERIOD_SEC) then
				local alive, _, pHum, pRoot = isPlayerAlive(player)
				if alive and pHum and pRoot and not GameConstants.IsInSafeZone(pRoot.Position) then
					local d = (pRoot.Position - mobPos).Magnitude
					local maxRange = if isPkCriminal then math.max(closestDist, 28) else closestDist
					if d <= maxRange then
						if isPkCriminal then
							closestDist = d
							closestPlayer = player
						else
							-- 1) Field of View (FOV) Cone Check (dot >= 0.25)
							local flatToPlayer = (pRoot.Position - mobPos) * Vector3.new(1, 0, 1)
							local toPlayerUnit = if flatToPlayer.Magnitude > 0.05
								then flatToPlayer.Unit
								else mobLookUnit
							local dot = mobLookUnit:Dot(toPlayerUnit)

							-- 2) Player Movement Check (standing still does not trigger passive aggro)
							local horizSpeed = (pRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
							local isPlayerMoving = (pHum.MoveDirection.Magnitude > 0.05) or (horizSpeed > 1.2)

							if dot >= MOB_FOV_MIN_DOT and isPlayerMoving then
								closestDist = d
								closestPlayer = player
							end
						end
					end
				end
			end
		end

		if closestPlayer then
			state.hateList[closestPlayer] = 10
			topEntity, topPlayer, topBotModel, targetRoot, targetHum = getTopHatedTarget(state)
		end
	end

	if topEntity and targetRoot and targetHum then
		if GameConstants.IsInSafeZone(targetRoot.Position) then
			state.hateList[topEntity] = nil
			humanoid:MoveTo(state.spawnPosition)
			return
		end

		local distToTarget = (targetRoot.Position - rootPart.Position).Magnitude
		if distToTarget > MELEE_ATTACK_RANGE - 1.2 then
			humanoid:MoveTo(targetRoot.Position)
		else
			humanoid:MoveTo(rootPart.Position)
		end

		if distToTarget <= MELEE_ATTACK_RANGE and (now - state.lastAttackTime) >= MELEE_ATTACK_COOLDOWN then
			state.lastAttackTime = now

			if topPlayer then
				local playerPDef = (topPlayer:GetAttribute("PDef") :: number?) or 25
				local effectiveDamage = math.max(1, math.floor(state.mobData.atk * (100 / (100 + playerPDef)) + 0.5))
				targetHum:TakeDamage(effectiveDamage)
				Remotes.MobAttackedPlayer:FireClient(topPlayer, model, effectiveDamage)
			elseif topBotModel then
				local botPDef = (topBotModel:GetAttribute("PDef") :: number?) or 40
				local effectiveDamage = math.max(1, math.floor(state.mobData.atk * (100 / (100 + botPDef)) + 0.5))
				local curBotHp = (topBotModel:GetAttribute("CurrentHP") :: number?) or targetHum.Health
				local curBotMaxHp = (topBotModel:GetAttribute("MaxHP") :: number?) or targetHum.MaxHealth
				local nextBotHp = math.max(math.floor(curBotMaxHp * 0.20), curBotHp - effectiveDamage)
				topBotModel:SetAttribute("CurrentHP", nextBotHp)
				targetHum.Health = nextBotHp
			end

			playMobAttackSwing(model, targetRoot.Position)
		end
	end
end

function MobSpawnerService.Init()
	if initialized then
		return
	end
	initialized = true

	local function trackPlayerSpawn(player: Player)
		lastCharacterSpawnTime[player] = os.clock()
		player.CharacterAdded:Connect(function()
			lastCharacterSpawnTime[player] = os.clock()
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		trackPlayerSpawn(player)
	end
	Players.PlayerAdded:Connect(trackPlayerSpawn)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastCharacterSpawnTime[player] = nil
	end)

	local spawnsFolder = getOrCreateFolder("MobSpawns")
	getOrCreateFolder("ActiveMobs")

	bootstrapDefaultSpawns(spawnsFolder)

	for _, child in ipairs(spawnsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			MobSpawnerService.SpawnMobAt(child)
		end
	end

	task.spawn(function()
		while true do
			task.wait(AI_TICK_INTERVAL)
			local now = os.clock()
			for _, state in pairs(activeMobStates) do
				if not state.isDead then
					stepMobAI(state, now)
				end
			end
		end
	end)
end

return MobSpawnerService
