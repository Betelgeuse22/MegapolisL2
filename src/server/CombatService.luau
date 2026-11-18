--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")

local GameConstants = require(Configs:WaitForChild("GameConstants"))
local ItemsConfig = require(Configs:WaitForChild("ItemsConfig"))
local MobsConfig = require(Configs:WaitForChild("MobsConfig"))
local RacesConfig = require(Configs:WaitForChild("RacesConfig"))
local ClassesConfig = require(Configs:WaitForChild("ClassesConfig"))
local SkillsConfig = require(Configs:WaitForChild("SkillsConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))
local MobSpawnerService = require(script.Parent:WaitForChild("MobSpawnerService"))
local PartyService = require(script.Parent:WaitForChild("PartyService"))

export type ClassProgressEntry = {
	Level: number,
	Exp: number,
	MaxExp: number,
	BaseAtk: number,
	BaseMaxHP: number,
}

export type PlayerCombatState = {
	Gender: string,
	RaceId: RacesConfig.RaceId,
	ClassId: string,
	Level: number,
	Exp: number,
	MaxExp: number,
	Cash: number,
	TrashTokens: number,
	HasWeapon: boolean,
	WeaponEnchant: number,
	EnergyShots: number,
	AutoSoulshot: boolean,
	EnchantScrolls: number,
	CrystalShards: number,
	HpPotions: number,
	MpPotions: number,
	BaseAtk: number,
	BaseMaxHP: number,
	CritRate: number,
	MaxHP: number,
	MP: number,
	MaxMP: number,
	PDef: number,
	MDef: number,
	AtkMult: number,
	PDefMult: number,
	MDefMult: number,
	MaxHpMult: number,
	MaxMpMult: number,
	AtkSpdMult: number,
	CritBonus: number,
	CritDmgMult: number,
	LifestealBonus: number,
	CashMult: number,
	WalkSpeedMult: number,
	ClassProgress: { [string]: ClassProgressEntry },
	SkillCooldowns: { [string]: number },
	SelectedTarget: Model?,
	LastAttackTime: number,
	LastHpPotionTime: number,
	LastMpPotionTime: number,
	Karma: number,
	PvpKills: number,
	PkKills: number,
	PvpFlagUntil: number,
	LastGuardStrikeTime: number,
}

local BASE_ATTACK_COOLDOWN = 0.42
local MELEE_ATTACK_RANGE = 12
local FRONT_CONE_MIN_DOT = 0.5
local SKILL_AUTO_TARGET_DISTANCE = 22
local BASE_WALK_SPEED = 16

-- Explicit ordered skill table per playable class (Index 1="Q", 2="E", 3="R", 4="F")
local CLASS_SKILL_ORDER: { [string]: { string } } = {
	RiotPolice = {
		"SKILL_BATON_STUN",
		"SKILL_MEGAPHONE_AGGRO",
		"SKILL_WATER_CANNON",
		"SKILL_RIOT_SHIELD",
	},
	Paramedic = {
		"SKILL_INSTANT_HEAL",
		"SKILL_MANA_RECHARGE",
		"SKILL_DEFIBRILLATOR",
		"SKILL_SANITARY_DOME",
	},
	SubwayRocker = {
		"SKILL_POWER_CHORD",
		"SKILL_SONG_SUBWAY_WIND",
		"SKILL_DANCE_OVERDRIVE",
		"SKILL_SHREDDING_SOLO",
	},
	UnionBoss = {
		"SKILL_BRIEFCASE_SMASH",
		"SKILL_CHANT_STRIKE",
		"SKILL_UNION_SANCTIONS",
		"SKILL_SEAL_OF_AUDIT",
	},
	RecycleHunter = {
		"SKILL_SPOIL",
		"SKILL_SWEEP",
		"SKILL_CART_RAM",
		"SKILL_MONOPOLY",
	},
	StreetfoodCrafter = {
		"SKILL_TENDERIZER_SLAM",
		"SKILL_DEPLOY_SHAWARMA_GRILL",
		"SKILL_PROPANE_BLAST",
		"SKILL_MASTERWORK_POLISH",
	},
	HellsSousChef = {
		"SKILL_SLICE_DICE",
		"SKILL_IRON_PAN",
		"SKILL_FLAMBE",
		"SKILL_FRIDAY_RUSH",
	},
	ExpressCourier = {
		"SKILL_BACKSTAB_DELIVERY",
		"SKILL_SHADOW_STEP",
		"SKILL_PEPPER_SPRAY",
		"SKILL_EXPRESS_OVERCLOCK",
	},
	HeavyBouncer = {
		"SKILL_CRUSHING_HAYMAKER",
		"SKILL_BOUNCER_TOSS",
		"SKILL_ARMOR_BREAKER",
		"SKILL_BOUNCER_FRENZY",
	},
	ParkingInspector = {
		"SKILL_TICKET_SHOT",
		"SKILL_WHEEL_CLAMP_TRAP",
		"SKILL_TOW_CABLE_SNIPE",
		"SKILL_HAWKEYE_RADAR",
	},
	HeavyBuilder = {
		"SKILL_REBAR_VOLLEY",
		"SKILL_WET_CEMENT_TRAP",
		"SKILL_CONCRETE_BUNKER_SHOT",
		"SKILL_SIEGE_SCAFFOLD",
	},
	FullstackCyberMage = {
		"SKILL_DDOS_BOLT",
		"SKILL_FIREWALL_BREACH",
		"SKILL_BSOD_NOVA",
		"SKILL_DEPLOY_ON_FRIDAY",
	},
	UrbanAlchemist = {
		"SKILL_ACID_FLASK",
		"SKILL_LIFE_DRAIN",
		"SKILL_TOXIC_SMOG",
		"SKILL_MUTAGEN_OVERDOSE",
	},
	DroneOperator = {
		"SKILL_TARGET_LASER",
		"SKILL_DEPLOY_COMBAT_DRONE",
		"SKILL_FPV_KAMIKAZE",
		"SKILL_SERVOMOTOR_OVERCLOCK",
	},
}

local SLOT_TO_INDEX: { [string]: number } = {
	Q = 1,
	E = 2,
	R = 3,
	F = 4,
}

local CombatService = {}

local droneDeployer: ((Player, number) -> ())? = nil

function CombatService.SetDroneDeployer(fn: (Player, number) -> ())
	droneDeployer = fn
end

local playerStates: { [Player]: PlayerCombatState } = {}
local initialized = false

local function computeBaseStatsForLevel(level: number): (number, number, number)
	local clamped = math.clamp(math.floor(level), 1, GameConstants.MAX_LEVEL)
	local baseAtk = 28 + (clamped - 1) * 7
	local baseMaxHp = 120 + (clamped - 1) * 25
	local maxExp = GameConstants.GetRequiredExp(clamped)
	return baseAtk, baseMaxHp, maxExp
end

local function getCharacterHealth(player: Player, fallbackMaxHp: number): (number, number)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return math.max(0, math.floor(humanoid.Health + 0.5)), math.max(1, math.floor(humanoid.MaxHealth + 0.5))
		end
	end
	return fallbackMaxHp, fallbackMaxHp
end

local function sendSystemChat(
	player: Player,
	i18nKey: string,
	params: { [string]: any }?,
	r: number,
	g: number,
	b: number
)
	Remotes.SendChatMessage:FireClient(player, i18nKey, params or {}, { r, g, b })
end

local function syncStateIntoProfile(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	local profile = DataManager.GetProfile(player)
	state.HasWeapon = (profile.EquippedItems.Weapon ~= nil)
	profile.Gender = state.Gender
	profile.RaceId = state.RaceId
	profile.CurrentClassId = state.ClassId
	profile.Cash = state.Cash
	profile.TrashTokens = state.TrashTokens
	profile.HasWeapon = state.HasWeapon
	profile.WeaponEnchant = state.WeaponEnchant
	profile.EnergyShots = state.EnergyShots
	profile.AutoSoulshot = state.AutoSoulshot
	profile.EnchantScrolls = state.EnchantScrolls
	profile.CrystalShards = state.CrystalShards
	profile.HpPotions = state.HpPotions
	profile.MpPotions = state.MpPotions
	profile.Karma = state.Karma
	profile.PvpKills = state.PvpKills
	profile.PkKills = state.PkKills

	local hp, _ = getCharacterHealth(player, state.MaxHP)
	if profile.IsCharacterCreated and profile.UnlockedClasses[state.ClassId] then
		profile.ClassProgress[state.ClassId] = {
			Level = state.Level,
			Exp = state.Exp,
			HP = math.max(1, hp),
			MP = state.MP,
		}
	end

	state.ClassProgress[state.ClassId] = {
		Level = state.Level,
		Exp = state.Exp,
		MaxExp = state.MaxExp,
		BaseAtk = state.BaseAtk,
		BaseMaxHP = state.BaseMaxHP,
	}
end

function CombatService.SyncProfile(player: Player)
	syncStateIntoProfile(player)
	local profile = DataManager.GetProfile(player)
	Remotes.ProfileUpdated:FireClient(player, profile)
end

local function createWeaponPart(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.Parent = parent
	return part
end

local function weldParts(part0: BasePart, part1: BasePart, offsetCFrame: CFrame)
	part1.CFrame = part0.CFrame * offsetCFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
end

function CombatService.ApplyCharacterGenderAndStyle(player: Player)
	local state = playerStates[player]
	local gender = if state and (state.Gender == "Female" or state.Gender == "Male") then state.Gender else "Male"
	local classId = if state then state.ClassId else "RiotPolice"

	player:SetAttribute("Gender", gender)

	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("Gender", gender)

	local existingStyle = character:FindFirstChild("EquippedGenderStyle")
	if existingStyle then
		existingStyle:Destroy()
	end

	-- Hide default Roblox hair accessories so procedural hairstyle looks crisp
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local accType = child.AccessoryType
			if accType == Enum.AccessoryType.Hair or accType == Enum.AccessoryType.Hat then
				local handle = child:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					handle.Transparency = 1
				end
			end
		end
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not torso then
		return
	end

	-- Optional R15 proportion adjustments
	if humanoid then
		local widthScale = humanoid:FindFirstChild("BodyWidthScale") :: NumberValue?
		local depthScale = humanoid:FindFirstChild("BodyDepthScale") :: NumberValue?
		if gender == "Female" then
			if widthScale then
				widthScale.Value = 0.88
			end
			if depthScale then
				depthScale.Value = 0.90
			end
		else
			if widthScale then
				widthScale.Value = 1.0
			end
			if depthScale then
				depthScale.Value = 1.0
			end
		end
	end

	local styleModel = Instance.new("Model")
	styleModel.Name = "EquippedGenderStyle"
	styleModel.Parent = character

	local jacketColor: Color3
	local accentColor: Color3
	local hairColor: Color3
	if classId == "RiotPolice" then
		jacketColor = if gender == "Female" then Color3.fromRGB(32, 52, 95) else Color3.fromRGB(24, 38, 72)
		accentColor = Color3.fromRGB(0, 215, 255)
		hairColor = if gender == "Female" then Color3.fromRGB(62, 38, 28) else Color3.fromRGB(35, 30, 28)
	elseif classId == "HellsSousChef" then
		jacketColor = if gender == "Female" then Color3.fromRGB(165, 32, 48) else Color3.fromRGB(135, 26, 36)
		accentColor = Color3.fromRGB(255, 165, 45)
		hairColor = if gender == "Female" then Color3.fromRGB(155, 52, 32) else Color3.fromRGB(75, 42, 28)
	else
		jacketColor = if gender == "Female" then Color3.fromRGB(28, 105, 92) else Color3.fromRGB(38, 82, 70)
		accentColor = Color3.fromRGB(0, 245, 200)
		hairColor = if gender == "Female" then Color3.fromRGB(225, 180, 82) else Color3.fromRGB(95, 70, 42)
	end

	if gender == "Female" then
		-- Sleeker feminine fitted jacket & waist cinch visual
		local upperVest = createWeaponPart(
			"FemaleFittedVest",
			Vector3.new(1.78, 1.05, 1.08),
			jacketColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		weldParts(torso, upperVest, CFrame.new(0, 0.32, 0))

		local waistBelt = createWeaponPart(
			"FemaleWaistCinch",
			Vector3.new(1.52, 0.34, 1.04),
			Color3.fromRGB(22, 24, 32),
			Enum.Material.SmoothPlastic,
			styleModel
		)
		weldParts(torso, waistBelt, CFrame.new(0, -0.32, 0))

		local beltBuckle = createWeaponPart(
			"FemaleBeltAccent",
			Vector3.new(0.42, 0.22, 1.08),
			accentColor,
			Enum.Material.Neon,
			styleModel
		)
		weldParts(torso, beltBuckle, CFrame.new(0, -0.32, 0))

		-- Procedural Female Hairstyle (Crown + Side Bangs + Flowing Ponytail welded to Head)
		local hairCrown = createWeaponPart(
			"FemaleHairCrown",
			Vector3.new(1.36, 0.85, 1.38),
			hairColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		local crownMesh = Instance.new("SpecialMesh")
		crownMesh.MeshType = Enum.MeshType.Sphere
		crownMesh.Parent = hairCrown
		weldParts(head, hairCrown, CFrame.new(0, 0.32, 0.04))

		local bangLeft = createWeaponPart(
			"FemaleBangLeft",
			Vector3.new(0.32, 0.72, 0.36),
			hairColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		weldParts(head, bangLeft, CFrame.new(-0.52, 0.02, -0.38) * CFrame.Angles(0, 0, math.rad(12)))

		local bangRight = createWeaponPart(
			"FemaleBangRight",
			Vector3.new(0.32, 0.72, 0.36),
			hairColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		weldParts(head, bangRight, CFrame.new(0.52, 0.02, -0.38) * CFrame.Angles(0, 0, math.rad(-12)))

		local ponytailRibbon = createWeaponPart(
			"FemalePonytailRibbon",
			Vector3.new(0.36, 0.24, 0.36),
			accentColor,
			Enum.Material.Neon,
			styleModel
		)
		weldParts(head, ponytailRibbon, CFrame.new(0, 0.24, 0.68))

		local ponytailUpper = createWeaponPart(
			"FemalePonytailUpper",
			Vector3.new(0.46, 1.15, 0.46),
			hairColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		local ptMesh1 = Instance.new("SpecialMesh")
		ptMesh1.MeshType = Enum.MeshType.Sphere
		ptMesh1.Parent = ponytailUpper
		weldParts(head, ponytailUpper, CFrame.new(0, -0.12, 0.92) * CFrame.Angles(math.rad(28), 0, 0))

		local ponytailLower = createWeaponPart(
			"FemalePonytailLower",
			Vector3.new(0.36, 0.95, 0.36),
			hairColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		local ptMesh2 = Instance.new("SpecialMesh")
		ptMesh2.MeshType = Enum.MeshType.Sphere
		ptMesh2.Parent = ponytailLower
		weldParts(head, ponytailLower, CFrame.new(0, -0.68, 1.12) * CFrame.Angles(math.rad(14), 0, 0))
	else
		-- Male Tactical Vest & Short Hair / Cap Styling
		local maleChestPlate = createWeaponPart(
			"MaleChestArmor",
			Vector3.new(2.06, 1.25, 1.12),
			jacketColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		weldParts(torso, maleChestPlate, CFrame.new(0, 0.22, 0))

		local maleChestStripe = createWeaponPart(
			"MaleChestStripe",
			Vector3.new(1.65, 0.16, 1.15),
			accentColor,
			Enum.Material.Neon,
			styleModel
		)
		weldParts(torso, maleChestStripe, CFrame.new(0, 0.38, 0))

		local maleHairCap = createWeaponPart(
			"MaleShortHair",
			Vector3.new(1.32, 0.52, 1.34),
			hairColor,
			Enum.Material.SmoothPlastic,
			styleModel
		)
		weldParts(head, maleHairCap, CFrame.new(0, 0.44, 0.02))
	end
end

function CombatService.UnequipClassWeapon(player: Player)
	player:SetAttribute("HasWeapon", false)
	player:SetAttribute("WeaponEnchant", 0)
	local character = player.Character
	if not character then
		return
	end
	character:SetAttribute("HasWeapon", false)
	character:SetAttribute("WeaponEnchant", 0)
	local existingWeapon = character:FindFirstChild("EquippedClassWeapon")
	if existingWeapon then
		existingWeapon:Destroy()
	end
end

function CombatService.EquipClassWeapon(player: Player, classId: string)
	local character = player.Character
	if not character then
		return
	end

	local existingWeapon = character:FindFirstChild("EquippedClassWeapon")
	if existingWeapon then
		existingWeapon:Destroy()
	end

	local state = playerStates[player]
	local hasWeapon = if state then state.HasWeapon else true
	player:SetAttribute("HasWeapon", hasWeapon)
	character:SetAttribute("HasWeapon", hasWeapon)

	if not hasWeapon then
		character:SetAttribute("WeaponEnchant", 0)
		return
	end

	local rightHand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	if not rightHand then
		return
	end

	local weaponModel = Instance.new("Model")
	weaponModel.Name = "EquippedClassWeapon"
	weaponModel.Parent = character

	local handle = createWeaponPart(
		"Handle",
		Vector3.new(0.28, 1.1, 0.28),
		Color3.fromRGB(30, 32, 38),
		Enum.Material.SmoothPlastic,
		weaponModel
	)
	weaponModel.PrimaryPart = handle

	local handOffset = if rightHand.Name == "RightHand"
		then CFrame.new(0, -0.15, -0.45) * CFrame.Angles(math.rad(-90), 0, 0)
		else CFrame.new(0, -0.95, -0.45) * CFrame.Angles(math.rad(-90), 0, 0)
	weldParts(rightHand, handle, handOffset)

	local tipOffset = Vector3.new(0, 2.2, 0)

	local classData = ClassesConfig[classId]
	local wType = if classData then classData.weaponType else "PoliceBaton"

	if wType == "PoliceBaton" or classId == "RiotPolice" then
		local guard = createWeaponPart(
			"Guard",
			Vector3.new(0.45, 0.16, 0.9),
			Color3.fromRGB(20, 22, 26),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, guard, CFrame.new(0, 0.45, 0.2))

		local shaft = createWeaponPart(
			"BatonShaft",
			Vector3.new(2.1, 0.32, 0.32),
			Color3.fromRGB(18, 20, 25),
			Enum.Material.SmoothPlastic,
			weaponModel
		)
		shaft.Shape = Enum.PartType.Cylinder
		weldParts(handle, shaft, CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)))

		local stunTip = createWeaponPart(
			"StunTip",
			Vector3.new(0.36, 0.25, 0.36),
			Color3.fromRGB(0, 210, 255),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, stunTip, CFrame.new(0, 2.45, 0))
		tipOffset = Vector3.new(0, 2.55, 0)
	elseif wType == "KitchenCleaver" or classId == "HellsSousChef" then
		local blade = createWeaponPart(
			"CleaverBlade",
			Vector3.new(0.14, 1.65, 0.95),
			Color3.fromRGB(200, 208, 220),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, blade, CFrame.new(0, 1.35, -0.18))

		local heatedEdge = createWeaponPart(
			"HeatedEdge",
			Vector3.new(0.16, 1.65, 0.15),
			Color3.fromRGB(255, 115, 30),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, heatedEdge, CFrame.new(0, 1.35, -0.62))
		tipOffset = Vector3.new(0, 2.25, -0.3)
	elseif wType == "Defibrillator" or classId == "Paramedic" then
		local paddle = createWeaponPart(
			"DefibPaddle",
			Vector3.new(0.35, 1.1, 0.8),
			Color3.fromRGB(245, 245, 250),
			Enum.Material.SmoothPlastic,
			weaponModel
		)
		weldParts(handle, paddle, CFrame.new(0, 1.1, 0))

		local shockFace = createWeaponPart(
			"ShockFace",
			Vector3.new(0.1, 0.9, 0.65),
			Color3.fromRGB(0, 255, 180),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, shockFace, CFrame.new(0.18, 1.1, 0))
		tipOffset = Vector3.new(0, 1.7, 0)
	elseif wType == "ElectricGuitar" or classId == "SubwayRocker" then
		local body = createWeaponPart(
			"GuitarBody",
			Vector3.new(0.25, 1.3, 1.1),
			Color3.fromRGB(180, 25, 35),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, body, CFrame.new(0, 0.8, -0.2))

		local neck = createWeaponPart(
			"GuitarNeck",
			Vector3.new(0.18, 1.8, 0.22),
			Color3.fromRGB(210, 195, 160),
			Enum.Material.Wood,
			weaponModel
		)
		weldParts(handle, neck, CFrame.new(0, 2.1, 0))

		local strings = createWeaponPart(
			"NeonStrings",
			Vector3.new(0.08, 1.7, 0.08),
			Color3.fromRGB(0, 230, 255),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, strings, CFrame.new(0, 2.1, -0.1))
		tipOffset = Vector3.new(0, 3.0, 0)
	elseif wType == "MegaphoneCane" or classId == "UnionBoss" then
		local shaft = createWeaponPart(
			"CaneShaft",
			Vector3.new(0.22, 2.2, 0.22),
			Color3.fromRGB(35, 28, 22),
			Enum.Material.Wood,
			weaponModel
		)
		weldParts(handle, shaft, CFrame.new(0, 1.2, 0))

		local horn = createWeaponPart(
			"MegaphoneHorn",
			Vector3.new(0.65, 0.8, 0.65),
			Color3.fromRGB(225, 180, 45),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, horn, CFrame.new(0, 2.4, 0))
		tipOffset = Vector3.new(0, 2.8, 0)
	elseif wType == "ShawarmaSpatula" or classId == "StreetfoodCrafter" then
		local rod = createWeaponPart(
			"SpatulaShaft",
			Vector3.new(0.18, 1.6, 0.18),
			Color3.fromRGB(160, 165, 175),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, rod, CFrame.new(0, 1.3, 0))

		local head = createWeaponPart(
			"SpatulaHead",
			Vector3.new(0.1, 0.8, 0.65),
			Color3.fromRGB(215, 220, 230),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, head, CFrame.new(0, 2.2, -0.1))

		local heatGlow = createWeaponPart(
			"HeatGlow",
			Vector3.new(0.12, 0.15, 0.65),
			Color3.fromRGB(255, 120, 20),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, heatGlow, CFrame.new(0, 2.6, -0.1))
		tipOffset = Vector3.new(0, 2.7, -0.1)
	elseif wType == "BoxCutterDagger" or classId == "ExpressCourier" then
		local blade = createWeaponPart(
			"DaggerBlade",
			Vector3.new(0.1, 1.2, 0.35),
			Color3.fromRGB(220, 225, 235),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, blade, CFrame.new(0, 1.0, -0.05))

		local edge = createWeaponPart(
			"RazorEdge",
			Vector3.new(0.12, 1.2, 0.08),
			Color3.fromRGB(255, 60, 60),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, edge, CFrame.new(0, 1.0, -0.2))
		tipOffset = Vector3.new(0, 1.7, -0.1)
	elseif wType == "VelvetStanchion" or classId == "HeavyBouncer" then
		local post = createWeaponPart(
			"StanchionPost",
			Vector3.new(0.35, 2.6, 0.35),
			Color3.fromRGB(210, 185, 75),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, post, CFrame.new(0, 1.4, 0))

		local ballTop = createWeaponPart(
			"StanchionCap",
			Vector3.new(0.7, 0.7, 0.7),
			Color3.fromRGB(240, 210, 90),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, ballTop, CFrame.new(0, 2.8, 0))
		tipOffset = Vector3.new(0, 3.2, 0)
	elseif wType == "ScannerCrossbow" or classId == "ParkingInspector" then
		local stock = createWeaponPart(
			"CrossbowStock",
			Vector3.new(0.28, 1.6, 0.35),
			Color3.fromRGB(45, 50, 60),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, stock, CFrame.new(0, 1.0, -0.3) * CFrame.Angles(math.rad(45), 0, 0))

		local bowArms = createWeaponPart(
			"BowArms",
			Vector3.new(1.8, 0.16, 0.22),
			Color3.fromRGB(255, 175, 20),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, bowArms, CFrame.new(0, 1.6, -0.7))
		tipOffset = Vector3.new(0, 1.8, -0.8)
	elseif wType == "PneumaticNailgun" or classId == "HeavyBuilder" then
		local body = createWeaponPart(
			"NailgunBody",
			Vector3.new(0.42, 1.3, 0.8),
			Color3.fromRGB(230, 140, 25),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, body, CFrame.new(0, 1.0, -0.2))

		local barrel = createWeaponPart(
			"NailgunBarrel",
			Vector3.new(0.2, 0.8, 0.2),
			Color3.fromRGB(30, 32, 36),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, barrel, CFrame.new(0, 1.8, -0.4))
		tipOffset = Vector3.new(0, 2.2, -0.4)
	elseif wType == "CyberDeck" or classId == "FullstackCyberMage" then
		local deck = createWeaponPart(
			"DeckChassis",
			Vector3.new(0.35, 1.2, 0.7),
			Color3.fromRGB(25, 28, 38),
			Enum.Material.SmoothPlastic,
			weaponModel
		)
		weldParts(handle, deck, CFrame.new(0, 0.8, 0))

		local screen = createWeaponPart(
			"MatrixScreen",
			Vector3.new(0.08, 0.9, 0.55),
			Color3.fromRGB(0, 255, 140),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, screen, CFrame.new(0.18, 0.8, 0))
		tipOffset = Vector3.new(0, 1.5, 0)
	elseif wType == "NeonFlaskLauncher" or classId == "UrbanAlchemist" then
		local tube = createWeaponPart(
			"FlaskTube",
			Vector3.new(0.35, 1.4, 0.35),
			Color3.fromRGB(50, 55, 65),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, tube, CFrame.new(0, 1.1, 0))

		local flask = createWeaponPart(
			"ToxicFlask",
			Vector3.new(0.55, 0.7, 0.55),
			Color3.fromRGB(140, 255, 0),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, flask, CFrame.new(0, 1.9, -0.15))
		tipOffset = Vector3.new(0, 2.3, -0.15)
	elseif wType == "DroneController" or classId == "DroneOperator" then
		local console = createWeaponPart(
			"ConsoleBody",
			Vector3.new(0.32, 1.1, 0.65),
			Color3.fromRGB(30, 35, 45),
			Enum.Material.SmoothPlastic,
			weaponModel
		)
		weldParts(handle, console, CFrame.new(0, 0.8, 0))

		local antenna = createWeaponPart(
			"CyberAntenna",
			Vector3.new(0.08, 0.9, 0.08),
			Color3.fromRGB(0, 220, 255),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, antenna, CFrame.new(0, 1.6, -0.2))
		tipOffset = Vector3.new(0, 2.1, -0.2)
	else
		local scannerBox = createWeaponPart(
			"ScannerBox",
			Vector3.new(0.42, 0.55, 0.52),
			Color3.fromRGB(50, 65, 80),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, scannerBox, CFrame.new(0, 0.65, 0))

		local rod = createWeaponPart(
			"HarvesterRod",
			Vector3.new(0.22, 1.45, 0.22),
			Color3.fromRGB(150, 165, 180),
			Enum.Material.Metal,
			weaponModel
		)
		weldParts(handle, rod, CFrame.new(0, 1.55, 0))

		local hook = createWeaponPart(
			"LaserHook",
			Vector3.new(0.2, 0.45, 0.85),
			Color3.fromRGB(0, 245, 200),
			Enum.Material.Neon,
			weaponModel
		)
		weldParts(handle, hook, CFrame.new(0, 2.2, -0.32))
		tipOffset = Vector3.new(0, 2.35, -0.45)
	end

	local att0 = Instance.new("Attachment")
	att0.Name = "TrailBase"
	att0.Position = Vector3.new(0, 0.4, 0)
	att0.Parent = handle

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailTip"
	att1.Position = tipOffset
	att1.Parent = handle

	local trail = Instance.new("Trail")
	trail.Name = "WeaponTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.Lifetime = 0.18
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = weaponModel

	local enchantLv = if state then state.WeaponEnchant else 0
	character:SetAttribute("WeaponEnchant", enchantLv)
	weaponModel:SetAttribute("WeaponEnchant", enchantLv)
end

local function computeEquippedGearBonuses(profile: DataManager.PlayerProfile?): (number, number, number, number, number)
	local atkBonus = 0
	local pDefBonus = 0
	local mDefBonus = 0
	local maxHpBonus = 0
	local maxMpBonus = 0

	if profile and profile.EquippedItems then
		local eqMap: { [string]: string? } = profile.EquippedItems :: any
		for _, slotName in ipairs(ItemsConfig.EQUIPMENT_SLOTS) do
			local itemId = eqMap[slotName]
			local itemData = ItemsConfig.GetItem(itemId)
			if itemData and itemData.bonuses then
				atkBonus += (itemData.bonuses.atk or 0)
				pDefBonus += (itemData.bonuses.pDef or 0)
				mDefBonus += (itemData.bonuses.mDef or 0)
				maxHpBonus += (itemData.bonuses.maxHp or 0)
				maxMpBonus += (itemData.bonuses.maxMp or 0)
			end
		end
	end

	return atkBonus, pDefBonus, mDefBonus, maxHpBonus, maxMpBonus
end

function CombatService.UpdateCharacterNametag(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	local isFlagged = state.PvpFlagUntil > os.clock()
	player:SetAttribute("Karma", state.Karma)
	player:SetAttribute("PvpKills", state.PvpKills)
	player:SetAttribute("PkKills", state.PkKills)
	player:SetAttribute("IsPvpFlagged", isFlagged)

	local character = player.Character
	if not character then
		return
	end

	character:SetAttribute("Karma", state.Karma)
	character:SetAttribute("PvpKills", state.PvpKills)
	character:SetAttribute("PkKills", state.PkKills)
	character:SetAttribute("IsPvpFlagged", isFlagged)
	character:SetAttribute("Level", state.Level)
	character:SetAttribute("ClassId", state.ClassId)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local headPart = character:FindFirstChild("Head")
	if not headPart or not headPart:IsA("BasePart") then
		return
	end

	local existingGui = headPart:FindFirstChild("PlayerL2NametagGui")
	local gui: BillboardGui
	if existingGui and existingGui:IsA("BillboardGui") then
		gui = existingGui
	else
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "PlayerL2NametagGui"
		newGui.Adornee = headPart
		newGui.Size = UDim2.fromOffset(210, 42)
		newGui.StudsOffset = Vector3.new(0, 2.8, 0)
		newGui.AlwaysOnTop = false
		newGui.MaxDistance = 95
		newGui.Parent = headPart

		local newStatusTag = Instance.new("TextLabel")
		newStatusTag.Name = "StatusTag"
		newStatusTag.Size = UDim2.new(1, 0, 0, 15)
		newStatusTag.Position = UDim2.fromOffset(0, 0)
		newStatusTag.BackgroundTransparency = 1
		newStatusTag.Font = Enum.Font.GothamBlack
		newStatusTag.TextSize = 11
		newStatusTag.TextStrokeColor3 = Color3.fromRGB(6, 8, 12)
		newStatusTag.TextStrokeTransparency = 0.1
		newStatusTag.Visible = false
		newStatusTag.Parent = newGui

		local newNameLbl = Instance.new("TextLabel")
		newNameLbl.Name = "NameLabel"
		newNameLbl.Size = UDim2.new(1, 0, 0, 20)
		newNameLbl.Position = UDim2.fromOffset(0, 16)
		newNameLbl.BackgroundTransparency = 1
		newNameLbl.Font = Enum.Font.GothamBold
		newNameLbl.TextSize = 13
		newNameLbl.TextStrokeColor3 = Color3.fromRGB(6, 8, 12)
		newNameLbl.TextStrokeTransparency = 0.1
		newNameLbl.Parent = newGui

		gui = newGui
	end

	local statusTagInst = gui:FindFirstChild("StatusTag")
	local nameLblInst = gui:FindFirstChild("NameLabel")
	local statusTag: TextLabel? = if statusTagInst and statusTagInst:IsA("TextLabel") then statusTagInst else nil
	local nameLbl: TextLabel? = if nameLblInst and nameLblInst:IsA("TextLabel") then nameLblInst else nil

	if state.Karma > 0 then
		if statusTag then
			statusTag.Visible = true
			statusTag.Text = string.format("☠ [PK • Карма: %d]", state.Karma)
			statusTag.TextColor3 = Color3.fromRGB(255, 55, 55)
		end
		if nameLbl then
			nameLbl.Text = string.format("%s [Ур.%d]", player.DisplayName, state.Level)
			nameLbl.TextColor3 = Color3.fromRGB(255, 35, 35)
		end
	elseif isFlagged then
		local remSec = math.max(1, math.ceil(state.PvpFlagUntil - os.clock()))
		if statusTag then
			statusTag.Visible = true
			statusTag.Text = string.format("⚔ [PvP ФЛАГ • %dс]", remSec)
			statusTag.TextColor3 = Color3.fromRGB(205, 115, 255)
		end
		if nameLbl then
			nameLbl.Text = string.format("%s [Ур.%d]", player.DisplayName, state.Level)
			nameLbl.TextColor3 = Color3.fromRGB(185, 85, 255)
		end
	else
		if statusTag then
			statusTag.Visible = false
		end
		if nameLbl then
			nameLbl.Text = string.format("%s [Ур.%d]", player.DisplayName, state.Level)
			nameLbl.TextColor3 = Color3.fromRGB(245, 245, 255)
		end
	end
end

function CombatService.RecalculateStats(player: Player, healToFull: boolean)
	local state = playerStates[player]
	if not state then
		return
	end

	local profile = DataManager.GetProfile(player)
	state.HasWeapon = (profile ~= nil and profile.EquippedItems ~= nil and profile.EquippedItems.Weapon ~= nil)
	profile.HasWeapon = state.HasWeapon

	local gearAtk, gearPDef, gearMDef, gearMaxHp, gearMaxMp = computeEquippedGearBonuses(profile)

	local raceData = RacesConfig[state.RaceId] or RacesConfig.RACE_LAW
	local classData = ClassesConfig[state.ClassId] or ClassesConfig.RiotPolice

	local computedMaxHp = math.floor((state.BaseMaxHP + classData.baseHpBonus + gearMaxHp) * raceData.hpMult * (state.MaxHpMult or 1.0) + 0.5)
	local computedPDef = math.floor((classData.basePDef + gearPDef) * state.PDefMult + 0.5)
	local computedMDef = math.floor((20 + (state.Level - 1) * 3 + gearMDef) * (state.MDefMult or 1.0) + 0.5)
	state.MaxHP = math.max(50, computedMaxHp)
	state.MaxMP = math.floor(((100 + (state.Level - 1) * 20) + gearMaxMp) * (state.MaxMpMult or 1.0) + 0.5)
	if healToFull then
		state.MP = state.MaxMP
	else
		state.MP = math.clamp(state.MP, 0, state.MaxMP)
	end
	state.PDef = math.max(1, computedPDef)
	state.MDef = math.max(1, computedMDef)

	local enchantBonus = if state.HasWeapon then GameConstants.GetWeaponEnchantAtkBonus(state.WeaponEnchant) else 0
	local effectiveAtk = if state.HasWeapon
		then (state.BaseAtk + classData.baseAtkBonus + gearAtk + enchantBonus)
		else math.max(1, math.floor((state.BaseAtk + classData.baseAtkBonus) * GameConstants.BARE_FIST_ATK_MULTIPLIER + 0.5))
	effectiveAtk = math.max(1, math.floor(effectiveAtk * (state.AtkMult or 1.0) + 0.5))

	player:SetAttribute("Level", state.Level)
	player:SetAttribute("Gender", state.Gender)
	player:SetAttribute("RaceId", state.RaceId)
	player:SetAttribute("ClassId", state.ClassId)
	player:SetAttribute("TrashTokens", state.TrashTokens)
	player:SetAttribute("HasWeapon", state.HasWeapon)
	player:SetAttribute("WeaponEnchant", state.WeaponEnchant)
	player:SetAttribute("EnergyShots", state.EnergyShots)
	player:SetAttribute("AutoSoulshot", state.AutoSoulshot)
	player:SetAttribute("EnchantScrolls", state.EnchantScrolls)
	player:SetAttribute("CrystalShards", state.CrystalShards)
	player:SetAttribute("HpPotions", state.HpPotions)
	player:SetAttribute("MpPotions", state.MpPotions)
	player:SetAttribute("Atk", effectiveAtk)
	player:SetAttribute("PDef", state.PDef)
	player:SetAttribute("MDef", state.MDef)
	player:SetAttribute("MP", state.MP)
	player:SetAttribute("MaxMP", state.MaxMP)
	player:SetAttribute("Karma", state.Karma)
	player:SetAttribute("PvpKills", state.PvpKills)
	player:SetAttribute("PkKills", state.PkKills)
	local isFlagged = state.PvpFlagUntil > os.clock()
	player:SetAttribute("IsPvpFlagged", isFlagged)

	local character = player.Character
	if character then
		character:SetAttribute("HasWeapon", state.HasWeapon)
		character:SetAttribute("WeaponEnchant", state.WeaponEnchant)
		character:SetAttribute("Level", state.Level)
		character:SetAttribute("ClassId", state.ClassId)
		character:SetAttribute("PDef", state.PDef)
		character:SetAttribute("Karma", state.Karma)
		character:SetAttribute("PvpKills", state.PvpKills)
		character:SetAttribute("PkKills", state.PkKills)
		character:SetAttribute("IsPvpFlagged", isFlagged)
		character:SetAttribute("MaxHP", state.MaxHP)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local prevMax = math.max(1, humanoid.MaxHealth)
			local prevRatio = math.clamp(humanoid.Health / prevMax, 0, 1)
			humanoid.MaxHealth = state.MaxHP
			if healToFull then
				humanoid.Health = state.MaxHP
			else
				humanoid.Health = math.max(1, math.floor(state.MaxHP * prevRatio + 0.5))
			end
			character:SetAttribute("CurrentHP", math.floor(humanoid.Health + 0.5))
			humanoid.WalkSpeed = BASE_WALK_SPEED * raceData.moveSpeedMult * state.WalkSpeedMult
		end
	end

	CombatService.UpdateCharacterNametag(player)
	CombatService.SyncPlayerStats(player)
end

function CombatService.SyncPlayerStats(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	local hp, maxHp = getCharacterHealth(player, state.MaxHP)
	Remotes.PlayerStatsUpdated:FireClient(
		player,
		state.Level,
		state.Exp,
		state.MaxExp,
		state.Cash,
		hp,
		maxHp,
		state.RaceId,
		state.ClassId,
		state.TrashTokens,
		state.MP,
		state.MaxMP
	)
end

local function setupPlayer(player: Player): PlayerCombatState
	if playerStates[player] then
		return playerStates[player]
	end

	local profile = DataManager.LoadProfile(player)
	local initialClass = if ClassesConfig[profile.CurrentClassId] and ClassesConfig[profile.CurrentClassId].isPlayableSprint2
		then profile.CurrentClassId
		else "RiotPolice"
	local initialRace: RacesConfig.RaceId = if RacesConfig[profile.RaceId :: RacesConfig.RaceId]
		then (profile.RaceId :: RacesConfig.RaceId)
		else "RACE_LAW"

	local savedEntry = profile.ClassProgress[initialClass]
	local startLevel = if savedEntry then math.clamp(savedEntry.Level, 1, GameConstants.MAX_LEVEL) else 1
	local startExp = if savedEntry then math.max(0, savedEntry.Exp) else 0
	local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(startLevel)

	local classProgressMap: { [string]: ClassProgressEntry } = {}
	for cId, cSaved in pairs(profile.ClassProgress) do
		local cLv = math.clamp(cSaved.Level, 1, GameConstants.MAX_LEVEL)
		local cAtk, cHp, cMaxExp = computeBaseStatsForLevel(cLv)
		classProgressMap[cId] = {
			Level = cLv,
			Exp = math.max(0, cSaved.Exp),
			MaxExp = cMaxExp,
			BaseAtk = cAtk,
			BaseMaxHP = cHp,
		}
	end
	if not classProgressMap[initialClass] then
		classProgressMap[initialClass] = {
			Level = startLevel,
			Exp = startExp,
			MaxExp = maxExp,
			BaseAtk = baseAtk,
			BaseMaxHP = baseMaxHp,
		}
	end

	local state: PlayerCombatState = {
		Gender = if profile.Gender == "Female" then "Female" else "Male",
		RaceId = initialRace,
		ClassId = initialClass,
		Level = startLevel,
		Exp = startExp,
		MaxExp = maxExp,
		Cash = profile.Cash,
		TrashTokens = profile.TrashTokens,
		HasWeapon = profile.HasWeapon,
		WeaponEnchant = profile.WeaponEnchant,
		EnergyShots = profile.EnergyShots,
		AutoSoulshot = profile.AutoSoulshot,
		EnchantScrolls = profile.EnchantScrolls,
		CrystalShards = profile.CrystalShards,
		HpPotions = profile.HpPotions,
		MpPotions = profile.MpPotions,
		BaseAtk = baseAtk,
		BaseMaxHP = baseMaxHp,
		CritRate = 0.20,
		MaxHP = 180,
		MP = if savedEntry and savedEntry.MP > 0 then savedEntry.MP else 100,
		MaxMP = 100 + (startLevel - 1) * 20,
		PDef = 45,
		MDef = 20,
		AtkMult = 1.0,
		PDefMult = 1.0,
		MDefMult = 1.0,
		MaxHpMult = 1.0,
		MaxMpMult = 1.0,
		AtkSpdMult = 1.0,
		CritBonus = 0.0,
		CritDmgMult = 1.0,
		LifestealBonus = 0.0,
		CashMult = 1.0,
		WalkSpeedMult = 1.0,
		ClassProgress = classProgressMap,
		SkillCooldowns = {},
		SelectedTarget = nil,
		LastAttackTime = 0,
		LastHpPotionTime = 0,
		LastMpPotionTime = 0,
		Karma = profile.Karma or 0,
		PvpKills = profile.PvpKills or 0,
		PkKills = profile.PkKills or 0,
		PvpFlagUntil = 0,
		LastGuardStrikeTime = 0,
	}
	playerStates[player] = state

	local function handleRedPlayerDeathPenalty(character: Model)
		local curState = playerStates[player]
		if not curState then
			return
		end
		local curProfile = DataManager.GetProfile(player)
		local hadKarma = curState.Karma > 0

		if hadKarma and #curProfile.InventoryBag > 0 and math.random() <= 0.50 then
			local dropIdx = math.random(1, #curProfile.InventoryBag)
			local droppedItemId = table.remove(curProfile.InventoryBag, dropIdx)
			if droppedItemId then
				local itemData = ItemsConfig.GetItem(droppedItemId)
				local itemKey = if itemData then itemData.nameKey else droppedItemId
				sendSystemChat(
					player,
					"LOG_PK_ITEM_DROPPED",
					{
						karma = curState.Karma,
						itemKey = itemKey,
					},
					255,
					55,
					55
				)

				-- Visual dropped loot box at PK death spot
				local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local dropBox = Instance.new("Part")
					dropBox.Name = "PKDroppedItemVisual"
					dropBox.Size = Vector3.new(1.4, 0.9, 1.4)
					dropBox.Color = Color3.fromRGB(255, 65, 65)
					dropBox.Material = Enum.Material.Neon
					dropBox.Anchored = true
					dropBox.CanCollide = false
					dropBox.CanQuery = false
					dropBox.CFrame = CFrame.new(hrp.Position.X, 0.5, hrp.Position.Z)
					dropBox.Parent = Workspace
					task.delay(6.0, function()
						if dropBox.Parent then
							dropBox:Destroy()
						end
					end)
				end
			end
		end

		-- Always clear Karma and PvP Flag upon death so Safe Zone Station Guards do not loop-kill on respawn
		if curState.Karma > 0 or curState.PvpFlagUntil > 0 then
			curState.Karma = 0
			curState.PvpFlagUntil = 0
			curProfile.Karma = 0
			player:SetAttribute("Karma", 0)
			player:SetAttribute("IsPvpFlagged", false)
			CombatService.UpdateCharacterNametag(player)
			CombatService.SyncProfile(player)
			DataManager.SaveProfile(player)
			if hadKarma then
				sendSystemChat(player, "LOG_DEV_PVP_CLEARED", {}, 120, 255, 165)
			end
		end
	end

	local function onCharacterReady(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			task.wait(0.1)
			character:SetAttribute("IsStunned", false)
			CombatService.ApplyCharacterGenderAndStyle(player)
			CombatService.EquipClassWeapon(player, state.ClassId)
			CombatService.RecalculateStats(player, true)
			CombatService.UpdateCharacterNametag(player)
			CombatService.SyncProfile(player)
			humanoid.HealthChanged:Connect(function()
				character:SetAttribute("CurrentHP", math.max(0, math.floor(humanoid.Health + 0.5)))
				CombatService.SyncPlayerStats(player)
			end)
			humanoid.Died:Connect(function()
				handleRedPlayerDeathPenalty(character)
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacterReady)
	if player.Character then
		task.spawn(onCharacterReady, player.Character)
	else
		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
	end

	-- Also send a delayed sync so client UIController listeners that connect shortly after PlayerAdded always receive the profile snapshot
	task.delay(0.5, function()
		if player.Parent == Players then
			CombatService.SyncPlayerStats(player)
			CombatService.SyncProfile(player)
		end
	end)

	return state
end

function CombatService.GetPlayerState(player: Player): PlayerCombatState
	return playerStates[player] or setupPlayer(player)
end

function CombatService.GetEffectiveAttackStats(player: Player): (number, number, number)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)
	local raceData = RacesConfig[state.RaceId] or RacesConfig.RACE_LAW
	local classData = ClassesConfig[state.ClassId] or ClassesConfig.RiotPolice

	local hasWpn = (profile.EquippedItems.Weapon ~= nil)
	state.HasWeapon = hasWpn

	local effectiveAtk: number
	if hasWpn then
		local gearAtk = computeEquippedGearBonuses(profile)
		local enchantBonus = GameConstants.GetWeaponEnchantAtkBonus(state.WeaponEnchant)
		effectiveAtk = state.BaseAtk + classData.baseAtkBonus + gearAtk + enchantBonus
	else
		-- Bare-fist damage: 50% base ATK and no weapon enchant bonus
		effectiveAtk = math.max(
			1,
			math.floor((state.BaseAtk + classData.baseAtkBonus) * GameConstants.BARE_FIST_ATK_MULTIPLIER + 0.5)
		)
	end
	effectiveAtk = math.max(1, math.floor(effectiveAtk * (state.AtkMult or 1.0) + 0.5))

	local effectiveCrit = math.clamp(state.CritRate * raceData.critMult + state.CritBonus, 0.05, 0.90)
	local effectiveAtkSpd = raceData.atkSpdMult * state.AtkSpdMult
	return effectiveAtk, effectiveCrit, effectiveAtkSpd
end

local function rollMobLootTable(player: Player, mobData: MobsConfig.MobData)
	local lootTable = mobData.lootTable
	if not lootTable then
		return
	end

	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	for _, entry in ipairs(lootTable) do
		if math.random() <= entry.chance then
			local minQty = entry.minQty or 1
			local maxQty = entry.maxQty or minQty
			local qty = if maxQty > minQty then math.random(minQty, maxQty) else minQty

			if entry.itemId == "HpPotions" then
				state.HpPotions += qty
				player:SetAttribute("HpPotions", state.HpPotions)
				sendSystemChat(player, "LOG_LOOT_CONSUMABLE", { itemKey = "UI_HP_POTIONS", qty = qty }, 115, 255, 145)
				Remotes.LootDropVFX:FireClient(player, "UI_HP_POTIONS", qty, "NG")
			elseif entry.itemId == "MpPotions" then
				state.MpPotions += qty
				player:SetAttribute("MpPotions", state.MpPotions)
				sendSystemChat(player, "LOG_LOOT_CONSUMABLE", { itemKey = "UI_MP_POTIONS", qty = qty }, 105, 225, 255)
				Remotes.LootDropVFX:FireClient(player, "UI_MP_POTIONS", qty, "NG")
			elseif entry.itemId == "EnergyShots" then
				state.EnergyShots += qty
				player:SetAttribute("EnergyShots", state.EnergyShots)
				sendSystemChat(player, "LOG_LOOT_CONSUMABLE", { itemKey = "UI_ENERGY_SHOTS", qty = qty }, 110, 245, 255)
				Remotes.LootDropVFX:FireClient(player, "UI_ENERGY_SHOTS", qty, "NG")
			elseif entry.itemId == "EnchantScrolls" then
				state.EnchantScrolls += qty
				player:SetAttribute("EnchantScrolls", state.EnchantScrolls)
				sendSystemChat(player, "LOG_LOOT_CONSUMABLE", { itemKey = "UI_ENCHANT_SCROLLS", qty = qty }, 255, 220, 85)
				Remotes.LootDropVFX:FireClient(player, "UI_ENCHANT_SCROLLS", qty, "D")
			else
				local itemData = ItemsConfig.GetItem(entry.itemId)
				if itemData then
					if #profile.InventoryBag < ItemsConfig.MAX_BAG_SLOTS then
						table.insert(profile.InventoryBag, itemData.id)
						local isDGrade = (itemData.grade == "D")
						sendSystemChat(
							player,
							"LOG_LOOT_EQUIPMENT",
							{
								itemKey = itemData.nameKey,
								grade = itemData.grade,
							},
							if isDGrade then 255 else 115,
							if isDGrade then 215 else 255,
							if isDGrade then 65 else 140
						)
						Remotes.LootDropVFX:FireClient(player, itemData.nameKey, 1, itemData.grade)
					else
						sendSystemChat(player, "LOG_BAG_FULL", {}, 255, 110, 110)
					end
				end
			end
		end
	end
end

function CombatService.AwardKillRewards(
	player: Player,
	mobId: string,
	mobLevel: number,
	partyBonusMult: number?,
	partyMemberCount: number?,
	rollLoot: boolean?
)
	local state = CombatService.GetPlayerState(player)
	local mobData = MobsConfig[mobId]
	if not mobData then
		return
	end

	local memberCount = math.max(1, partyMemberCount or 1)
	local bonusMult = partyBonusMult or 1.0
	local penalty = GameConstants.CalculateLevelPenalty(state.Level, mobLevel)

	local totalPartyExp = mobData.expReward * bonusMult * penalty
	local totalPartyCash = mobData.cashReward * bonusMult * state.CashMult

	local gainedExp = math.max(1, math.floor((totalPartyExp / memberCount) + 0.5))
	local gainedCash = math.max(1, math.floor((totalPartyCash / memberCount) + 0.5))

	state.Cash += gainedCash

	if memberCount >= 2 then
		local bonusPct = math.floor((bonusMult - 1.0) * 100 + 0.5)
		sendSystemChat(
			player,
			"LOG_PARTY_REWARD_SPLIT",
			{
				exp = gainedExp,
				cash = gainedCash,
				bonus = bonusPct,
				count = memberCount,
			},
			115,
			245,
			200
		)
	end

	-- Roll Mob & Raid Boss Loot Table
	if rollLoot ~= false then
		rollMobLootTable(player, mobData)
	end

	local leveledUp = false
	if state.Level < GameConstants.MAX_LEVEL then
		state.Exp += gainedExp
		while state.Level < GameConstants.MAX_LEVEL and state.Exp >= state.MaxExp do
			state.Exp -= state.MaxExp
			state.Level += 1
			local newAtk, newBaseHp, newMaxExp = computeBaseStatsForLevel(state.Level)
			state.BaseAtk = newAtk
			state.BaseMaxHP = newBaseHp
			state.MaxExp = newMaxExp
			leveledUp = true
		end
		if state.Level >= GameConstants.MAX_LEVEL then
			state.Level = GameConstants.MAX_LEVEL
			state.Exp = 0
		end
	else
		state.Exp = 0
	end

	syncStateIntoProfile(player)

	if leveledUp then
		CombatService.RecalculateStats(player, true)
		DataManager.SaveProfile(player)
	else
		CombatService.SyncPlayerStats(player)
	end
	CombatService.SyncProfile(player)
end

local function tryConsumeSoulshot(player: Player, state: PlayerCombatState): boolean
	-- Soulshots do not trigger on bare fists (when HasWeapon == false)
	if not state.HasWeapon then
		return false
	end
	if state.AutoSoulshot == true and state.EnergyShots > 0 then
		state.EnergyShots -= 1
		player:SetAttribute("EnergyShots", state.EnergyShots)
		CombatService.SyncProfile(player)
		return true
	end
	return false
end

-- Unified Authoritative Damage & Death Function used by BOTH LMB attacks and ALL Skills (and AI Companion Bots)
function CombatService.ApplyDamageToMob(
	attacker: Player,
	mobModel: Model,
	rawDamage: number,
	isSkill: boolean,
	preConsumedSoulshot: boolean?,
	attackerEntityOverride: Instance?
): (number, boolean, boolean)
	local state = CombatService.GetPlayerState(attacker)
	if not mobModel or not mobModel.Parent then
		return 0, false, false
	end

	local mobState = MobSpawnerService.GetMobState(mobModel)
	local currentHp = if mobState then mobState.currentHp else ((mobModel:GetAttribute("CurrentHP") :: number?) or 0)
	if currentHp <= 0 or (mobState and mobState.isDead) then
		return 0, false, false
	end

	local usedSoulshot = if preConsumedSoulshot ~= nil
		then preConsumedSoulshot
		else tryConsumeSoulshot(attacker, state)

	local mobLevel = (mobModel:GetAttribute("Level") :: number?) or 1
	local mobPDef = (mobModel:GetAttribute("PDef") :: number?) or 10
	local mobId = (mobModel:GetAttribute("MobId") :: string?) or mobModel.Name

	local _, effectiveCrit = CombatService.GetEffectiveAttackStats(attacker)
	local mitigated = rawDamage * (100 / (100 + mobPDef))

	local isCrit = math.random() < effectiveCrit
	if isCrit then
		mitigated *= 2.0
	end

	if usedSoulshot then
		mitigated *= GameConstants.SOULSHOT_DAMAGE_MULTIPLIER
	end

	local levelPenalty = GameConstants.CalculateLevelPenalty(state.Level, mobLevel)
	local finalDamage = math.max(1, math.floor(mitigated * levelPenalty + 0.5))

	local newHp = math.max(0, currentHp - finalDamage)
	if mobState then
		mobState.currentHp = newHp
	end
	mobModel:SetAttribute("CurrentHP", newHp)

	local mobHumanoid = mobModel:FindFirstChildOfClass("Humanoid")
	if mobHumanoid then
		mobHumanoid.Health = newHp
	end

	local hateSource: Instance = attackerEntityOverride or attacker
	MobSpawnerService.AddHate(mobModel, hateSource, if isSkill then finalDamage * 2 else finalDamage)
	Remotes.CombatHitFeedback:FireAllClients(mobModel, finalDamage, isCrit, false, usedSoulshot, attacker)

	local killed = false
	if newHp <= 0 then
		killed = true

		-- Karma Washing: Killing any normal mob while Karma > 0 washes away 60 Karma (clamped to 0)
		if state.Karma > 0 then
			state.Karma = math.max(0, state.Karma - 60)
			local profile = DataManager.GetProfile(attacker)
			profile.Karma = state.Karma
			CombatService.UpdateCharacterNametag(attacker)
			CombatService.SyncProfile(attacker)
			DataManager.SaveProfile(attacker)
			sendSystemChat(attacker, "LOG_KARMA_WASHED", { karma = state.Karma }, 120, 255, 165)
		end

		local mobRoot = MobSpawnerService.GetMobRoot(mobModel)
		local deathPos = if mobRoot then mobRoot.Position else Vector3.zero
		local nearbyPartyPlayers, totalNearbyPartyCount = PartyService.GetNearbyPartyMembers(attacker, deathPos, 85)

		-- Collect killer + all players on HateList + all nearby Party members BEFORE HandleMobDeath clears hateList
		local participants: { [Player]: boolean } = {
			[attacker] = true,
		}
		for _, partyPlr in ipairs(nearbyPartyPlayers) do
			if partyPlr.Parent == Players then
				participants[partyPlr] = true
			end
		end
		if mobState then
			for hatedEntity, hateAmount in pairs(mobState.hateList) do
				if hateAmount > 0 and hatedEntity:IsA("Player") and hatedEntity.Parent == Players then
					participants[hatedEntity] = true
				end
			end
		end

		MobSpawnerService.HandleMobDeath(mobModel)

		if totalNearbyPartyCount >= 2 then
			local partyBonusMult = 1.0 + 0.15 * (totalNearbyPartyCount - 1)
			for _, partyPlr in ipairs(nearbyPartyPlayers) do
				if partyPlr.Parent == Players then
					CombatService.AwardKillRewards(
						partyPlr,
						mobId,
						mobLevel,
						partyBonusMult,
						totalNearbyPartyCount,
						partyPlr == attacker
					)
				end
			end
		else
			CombatService.AwardKillRewards(attacker, mobId, mobLevel)
		end

		-- Subclass Raid Boss Kill Tracking (grants +1 BossKill credit to ALL nearby real players in the party)
		local bossReq = GameConstants.SUBCLASS_BOSS_BY_ID[mobId]
		if bossReq then
			for participant, _ in pairs(participants) do
				if participant.Parent == Players then
					local updatedKills = DataManager.IncrementBossKill(participant, mobId)
					sendSystemChat(
						participant,
						"LOG_BOSS_KILL_PROGRESS",
						{
							bossKey = bossReq.nameKey,
							cur = updatedKills,
							req = bossReq.requiredKills,
						},
						255,
						215,
						75
					)
					CombatService.SyncProfile(participant)
					DataManager.SaveProfile(participant)
				end
			end
		end
	end

	return finalDamage, killed, usedSoulshot
end

function CombatService.DealDamageToMob(
	player: Player,
	targetModel: Model,
	damageMultiplier: number,
	isSkill: boolean?
): (number, boolean, boolean)
	local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
	local rawDamage = effectiveAtk * damageMultiplier
	local finalDamage, killed = CombatService.ApplyDamageToMob(player, targetModel, rawDamage, isSkill == true)
	return finalDamage, false, killed
end

function CombatService.CreateCharacter(
	player: Player,
	raceId: string,
	startingClassId: string,
	genderArg: string?
)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	local validGender = if genderArg == "Female" then "Female" else "Male"
	local validRaceId: RacesConfig.RaceId = if RacesConfig[raceId :: RacesConfig.RaceId]
		then (raceId :: RacesConfig.RaceId)
		else "RACE_LAW"
	local validClassId = if ClassesConfig[startingClassId] and ClassesConfig[startingClassId].isPlayableSprint2
		then startingClassId
		else "RiotPolice"

	local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(1)

	state.Gender = validGender
	state.RaceId = validRaceId
	state.ClassId = validClassId
	state.Level = 1
	state.Exp = 0
	state.MaxExp = maxExp
	state.HasWeapon = true
	state.WeaponEnchant = 0
	state.BaseAtk = baseAtk
	state.BaseMaxHP = baseMaxHp
	state.PDefMult = 1.0
	state.AtkSpdMult = 1.0
	state.CritBonus = 0.0
	state.CashMult = 1.0
	state.WalkSpeedMult = 1.0
	table.clear(state.SkillCooldowns)

	state.ClassProgress = {
		[validClassId] = {
			Level = 1,
			Exp = 0,
			MaxExp = maxExp,
			BaseAtk = baseAtk,
			BaseMaxHP = baseMaxHp,
		},
	}

	profile.IsCharacterCreated = true
	profile.Gender = validGender
	profile.RaceId = validRaceId
	profile.CurrentClassId = validClassId
	profile.EquippedItems = {
		Weapon = "WPN_STARTER",
		Chest = "ARM_COMMUTER_JACKET",
		Legs = nil,
		Boots = "ARM_RUBBER_BOOTS",
		Accessory1 = nil,
		Accessory2 = nil,
	}
	profile.InventoryBag = {}
	profile.UnlockedClasses = {
		[validClassId] = true,
	}
	profile.ClassProgress = {
		[validClassId] = {
			Level = 1,
			Exp = 0,
			HP = state.MaxHP,
			MP = 100,
		},
	}

	CombatService.ApplyCharacterGenderAndStyle(player)
	CombatService.EquipClassWeapon(player, state.ClassId)
	CombatService.RecalculateStats(player, true)
	CombatService.SyncProfile(player)
	DataManager.SaveProfile(player)

	local cData = ClassesConfig[validClassId]
	local rData = RacesConfig[validRaceId]
	sendSystemChat(
		player,
		"LOG_CHAR_CREATED",
		{
			classKey = if cData then cData.nameKey else validClassId,
			raceKey = if rData then rData.nameKey else validRaceId,
		},
		120,
		255,
		150
	)
end

function CombatService.UnlockOrSwitchSubclass(player: Player, targetClassId: string)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	if not profile.IsCharacterCreated then
		return
	end

	local targetClassData = ClassesConfig[targetClassId]
	if not targetClassData or not targetClassData.isPlayableSprint2 then
		return
	end

	if state.ClassId == targetClassId and profile.UnlockedClasses[targetClassId] == true then
		CombatService.SyncProfile(player)
		return
	end

	-- Save current class progress before switching
	syncStateIntoProfile(player)

	local isAlreadyUnlocked = profile.UnlockedClasses[targetClassId] == true
	if not isAlreadyUnlocked then
		-- Verify Subclass Quest conditions: MaxReachedLevel >= 40 and all 4 BossKills >= 3
		if not DataManager.AreSubclassRequirementsMet(player) then
			sendSystemChat(player, "LOG_SUBCLASS_LOCKED", {}, 255, 95, 95)
			CombatService.SyncProfile(player)
			return
		end

		-- Unlock new Subclass at Lv. 1!
		profile.UnlockedClasses[targetClassId] = true
		local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(1)
		profile.ClassProgress[targetClassId] = {
			Level = 1,
			Exp = 0,
			HP = baseMaxHp,
			MP = 100,
		}
		state.ClassProgress[targetClassId] = {
			Level = 1,
			Exp = 0,
			MaxExp = maxExp,
			BaseAtk = baseAtk,
			BaseMaxHP = baseMaxHp,
		}

		sendSystemChat(
			player,
			"LOG_SUBCLASS_UNLOCKED",
			{
				classKey = targetClassData.nameKey,
			},
			115,
			255,
			145
		)
	end

	-- Switch to the unlocked class and restore its independent Level & EXP
	local savedProfileProgress = profile.ClassProgress[targetClassId]
	local restoredLevel = if savedProfileProgress
		then math.clamp(savedProfileProgress.Level, 1, GameConstants.MAX_LEVEL)
		else 1
	local restoredExp = if savedProfileProgress then math.max(0, savedProfileProgress.Exp) else 0
	local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(restoredLevel)

	state.ClassId = targetClassId
	profile.CurrentClassId = targetClassId
	state.Level = restoredLevel
	state.Exp = restoredExp
	state.MaxExp = maxExp
	state.BaseAtk = baseAtk
	state.BaseMaxHP = baseMaxHp

	state.PDefMult = 1.0
	state.AtkSpdMult = 1.0
	state.CritBonus = 0.0
	state.CashMult = 1.0
	state.WalkSpeedMult = 1.0
	table.clear(state.SkillCooldowns)

	CombatService.ApplyCharacterGenderAndStyle(player)
	CombatService.EquipClassWeapon(player, state.ClassId)
	CombatService.RecalculateStats(player, true)
	CombatService.SyncProfile(player)
	DataManager.SaveProfile(player)
end

-- Legacy remote handler routes through Subclass Quest Gating (no unrestricted race/class switching)
function CombatService.ChangeClassOrRace(player: Player, newClassId: string?, _newRaceId: string?)
	if newClassId then
		CombatService.UnlockOrSwitchSubclass(player, newClassId)
	end
end

function CombatService.ToggleAutoSoulshot(player: Player)
	local state = CombatService.GetPlayerState(player)
	state.AutoSoulshot = not state.AutoSoulshot
	player:SetAttribute("AutoSoulshot", state.AutoSoulshot)
	CombatService.SyncProfile(player)
	DataManager.SaveProfile(player)

	if state.AutoSoulshot then
		sendSystemChat(player, "LOG_SOULSHOT_ON", { count = state.EnergyShots }, 100, 245, 255)
	else
		sendSystemChat(player, "LOG_SOULSHOT_OFF", {}, 185, 195, 210)
	end
end

function CombatService.RequestEnchantWeapon(player: Player)
	local state = CombatService.GetPlayerState(player)
	if not state.HasWeapon then
		sendSystemChat(player, "LOG_ENCHANT_NO_WEAPON", {}, 255, 95, 95)
		return
	end
	if state.WeaponEnchant >= GameConstants.MAX_ENCHANT_LEVEL then
		sendSystemChat(player, "LOG_ENCHANT_MAX_REACHED", { max = GameConstants.MAX_ENCHANT_LEVEL }, 255, 215, 85)
		return
	end
	if state.EnchantScrolls <= 0 then
		sendSystemChat(player, "LOG_ENCHANT_NO_SCROLLS", {}, 255, 95, 95)
		return
	end

	local currentLevel = state.WeaponEnchant
	state.EnchantScrolls -= 1

	local successChance = GameConstants.GetEnchantSuccessChance(currentLevel)
	local isSuccess = math.random() <= successChance

	if isSuccess then
		state.WeaponEnchant = currentLevel + 1
		player:SetAttribute("WeaponEnchant", state.WeaponEnchant)
		if player.Character then
			player.Character:SetAttribute("WeaponEnchant", state.WeaponEnchant)
		end

		CombatService.RecalculateStats(player, false)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)

		Remotes.EnchantResultFeedback:FireClient(player, true, state.WeaponEnchant, 0)
		sendSystemChat(
			player,
			"LOG_ENCHANT_SUCCESS",
			{
				lv = state.WeaponEnchant,
				atk = GameConstants.GetWeaponEnchantAtkBonus(state.WeaponEnchant),
			},
			255,
			215,
			55
		)
	else
		local profile = DataManager.GetProfile(player)
		local crystals = currentLevel * 10
		profile.EquippedItems.Weapon = nil
		profile.HasWeapon = false
		state.HasWeapon = false
		state.WeaponEnchant = 0
		state.CrystalShards += crystals

		-- Remove 3D weapon model from character's right hand so character stands with empty hands
		CombatService.UnequipClassWeapon(player)

		CombatService.RecalculateStats(player, false)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)

		Remotes.EnchantResultFeedback:FireClient(player, false, 0, crystals)
		sendSystemChat(
			player,
			"LOG_ENCHANT_FAIL",
			{
				oldLv = currentLevel,
				crystals = crystals,
			},
			255,
			70,
			70
		)
	end
end

function CombatService.BuyShopItem(player: Player, itemType: string)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	if itemType == "NewWeapon" then
		if profile.EquippedItems.Weapon ~= nil then
			sendSystemChat(player, "LOG_SHOP_ALREADY_HAS_WEAPON", {}, 255, 200, 85)
			return
		end
		local price = GameConstants.PRICE_NEW_WEAPON_CASH
		if state.Cash < price then
			sendSystemChat(player, "LOG_SHOP_NO_FUNDS", { cost = price }, 255, 95, 95)
			return
		end
		state.Cash -= price
		profile.EquippedItems.Weapon = "WPN_STARTER"
		profile.HasWeapon = true
		state.HasWeapon = true
		state.WeaponEnchant = 0
		player:SetAttribute("HasWeapon", true)
		player:SetAttribute("WeaponEnchant", 0)
		if player.Character then
			player.Character:SetAttribute("HasWeapon", true)
			player.Character:SetAttribute("WeaponEnchant", 0)
		end

		CombatService.EquipClassWeapon(player, state.ClassId)
		CombatService.RecalculateStats(player, false)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(player, "LOG_SHOP_BOUGHT_WEAPON", { cost = price }, 115, 255, 150)
	elseif itemType == "EnergyShots" then
		local price = GameConstants.PRICE_ENERGY_SHOTS_PACK
		local amount = GameConstants.ENERGY_SHOTS_PACK_AMOUNT
		if state.Cash < price then
			sendSystemChat(player, "LOG_SHOP_NO_FUNDS", { cost = price }, 255, 95, 95)
			return
		end
		state.Cash -= price
		state.EnergyShots += amount
		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_SHOP_BOUGHT_SHOTS",
			{
				amount = amount,
				cost = price,
				total = state.EnergyShots,
			},
			110,
			245,
			155
		)
	elseif itemType == "EnchantScroll" or itemType == "EnchantScrollCash" then
		local price = GameConstants.PRICE_ENCHANT_SCROLL_CASH
		if state.Cash < price then
			sendSystemChat(player, "LOG_SHOP_NO_FUNDS", { cost = price }, 255, 95, 95)
			return
		end
		state.Cash -= price
		state.EnchantScrolls += 1
		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_SHOP_BOUGHT_SCROLL",
			{
				cost = price,
				total = state.EnchantScrolls,
			},
			255,
			220,
			90
		)
	elseif itemType == "EnchantScrollTokens" then
		local tokenCost = GameConstants.PRICE_ENCHANT_SCROLL_TOKENS
		if state.TrashTokens < tokenCost then
			sendSystemChat(player, "LOG_SHOP_NO_TOKENS", { cost = tokenCost }, 255, 95, 95)
			return
		end
		state.TrashTokens -= tokenCost
		state.EnchantScrolls += 1
		player:SetAttribute("TrashTokens", state.TrashTokens)
		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_SHOP_TRADED_SCROLL",
			{
				cost = tokenCost,
				total = state.EnchantScrolls,
			},
			100,
			245,
			210
		)
	elseif itemType == "HpPotions" then
		local price = GameConstants.PRICE_HP_POTION_PACK
		local amount = GameConstants.POTION_PACK_AMOUNT
		if state.Cash < price then
			sendSystemChat(player, "LOG_SHOP_NO_FUNDS", { cost = price }, 255, 95, 95)
			return
		end
		state.Cash -= price
		state.HpPotions += amount
		player:SetAttribute("HpPotions", state.HpPotions)
		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_SHOP_BOUGHT_HP_POTIONS",
			{
				amount = amount,
				cost = price,
				total = state.HpPotions,
			},
			115,
			255,
			145
		)
	elseif itemType == "MpPotions" then
		local price = GameConstants.PRICE_MP_POTION_PACK
		local amount = GameConstants.POTION_PACK_AMOUNT
		if state.Cash < price then
			sendSystemChat(player, "LOG_SHOP_NO_FUNDS", { cost = price }, 255, 95, 95)
			return
		end
		state.Cash -= price
		state.MpPotions += amount
		player:SetAttribute("MpPotions", state.MpPotions)
		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_SHOP_BOUGHT_MP_POTIONS",
			{
				amount = amount,
				cost = price,
				total = state.MpPotions,
			},
			95,
			225,
			255
		)
	end
end

function CombatService.UsePotion(player: Player, potionType: string)
	local state = CombatService.GetPlayerState(player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()

	if potionType == "HP" then
		if state.HpPotions <= 0 then
			sendSystemChat(player, "LOG_POTION_NONE", {}, 255, 95, 95)
			return
		end
		if (now - state.LastHpPotionTime) < GameConstants.POTION_COOLDOWN then
			return
		end
		local curHp = math.floor(humanoid.Health + 0.5)
		if curHp >= state.MaxHP then
			sendSystemChat(player, "LOG_HP_ALREADY_FULL", {}, 255, 200, 85)
			return
		end

		state.HpPotions -= 1
		state.LastHpPotionTime = now
		player:SetAttribute("HpPotions", state.HpPotions)

		local healAmount = math.max(
			GameConstants.HP_POTION_MIN_HEAL,
			math.floor(state.MaxHP * GameConstants.HP_POTION_HEAL_PERCENT + 0.5)
		)
		local newHp = math.min(state.MaxHP, curHp + healAmount)
		local actualRestored = math.max(1, newHp - curHp)
		humanoid.Health = newHp

		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)

		Remotes.PotionVFX:FireAllClients(character, "HP", actualRestored)
		sendSystemChat(
			player,
			"LOG_HP_POTION_USED",
			{
				amount = actualRestored,
				left = state.HpPotions,
			},
			110,
			255,
			145
		)
	elseif potionType == "MP" then
		if state.MpPotions <= 0 then
			sendSystemChat(player, "LOG_POTION_NONE", {}, 255, 95, 95)
			return
		end
		if (now - state.LastMpPotionTime) < GameConstants.POTION_COOLDOWN then
			return
		end
		if state.MP >= state.MaxMP then
			sendSystemChat(player, "LOG_MP_ALREADY_FULL", {}, 130, 215, 255)
			return
		end

		state.MpPotions -= 1
		state.LastMpPotionTime = now
		player:SetAttribute("MpPotions", state.MpPotions)

		local restoreAmount = math.max(
			GameConstants.MP_POTION_MIN_RESTORE,
			math.floor(state.MaxMP * GameConstants.MP_POTION_RESTORE_PERCENT + 0.5)
		)
		local prevMp = state.MP
		local newMp = math.min(state.MaxMP, prevMp + restoreAmount)
		local actualRestored = math.max(1, newMp - prevMp)
		state.MP = newMp
		player:SetAttribute("MP", state.MP)

		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)

		Remotes.PotionVFX:FireAllClients(character, "MP", actualRestored)
		sendSystemChat(
			player,
			"LOG_MP_POTION_USED",
			{
				amount = actualRestored,
				left = state.MpPotions,
			},
			95,
			225,
			255
		)
	end
end

function CombatService.EquipItem(player: Player, bagIndex: number)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	local idx = math.floor(tonumber(bagIndex) or 0)
	if idx < 1 or idx > #profile.InventoryBag then
		return
	end

	local itemId = profile.InventoryBag[idx]
	local itemData = ItemsConfig.GetItem(itemId)
	if not itemData then
		return
	end

	if state.Level < itemData.reqLevel then
		sendSystemChat(
			player,
			"LOG_EQUIP_REQ_LEVEL",
			{
				itemKey = itemData.nameKey,
				reqLv = itemData.reqLevel,
			},
			255,
			95,
			95
		)
		return
	end

	local slotName = itemData.slot
	local equippedMap = profile.EquippedItems :: { [string]: string? }
	local prevEquippedId = equippedMap[slotName]

	table.remove(profile.InventoryBag, idx)
	if prevEquippedId and ItemsConfig.GetItem(prevEquippedId) ~= nil then
		table.insert(profile.InventoryBag, idx, prevEquippedId)
	end

	equippedMap[slotName] = itemData.id
	state.HasWeapon = (profile.EquippedItems.Weapon ~= nil)
	profile.HasWeapon = state.HasWeapon

	if slotName == "Weapon" then
		CombatService.EquipClassWeapon(player, state.ClassId)
	end

	CombatService.RecalculateStats(player, false)
	CombatService.SyncProfile(player)
	DataManager.SaveProfile(player)

	sendSystemChat(
		player,
		"LOG_ITEM_EQUIPPED",
		{
			itemKey = itemData.nameKey,
			grade = itemData.grade,
		},
		115,
		255,
		150
	)
end

function CombatService.UnequipItem(player: Player, slotName: string)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	local isValidSlot = false
	for _, validSlot in ipairs(ItemsConfig.EQUIPMENT_SLOTS) do
		if validSlot == slotName then
			isValidSlot = true
			break
		end
	end
	if not isValidSlot then
		return
	end

	local equippedMap = profile.EquippedItems :: { [string]: string? }
	local equippedId = equippedMap[slotName]
	if not equippedId then
		return
	end

	if #profile.InventoryBag >= ItemsConfig.MAX_BAG_SLOTS then
		sendSystemChat(player, "LOG_BAG_FULL", {}, 255, 95, 95)
		return
	end

	local itemData = ItemsConfig.GetItem(equippedId)
	equippedMap[slotName] = nil
	table.insert(profile.InventoryBag, equippedId)

	state.HasWeapon = (profile.EquippedItems.Weapon ~= nil)
	profile.HasWeapon = state.HasWeapon

	if slotName == "Weapon" then
		CombatService.UnequipClassWeapon(player)
	end

	CombatService.RecalculateStats(player, false)
	CombatService.SyncProfile(player)
	DataManager.SaveProfile(player)

	if itemData then
		sendSystemChat(
			player,
			"LOG_ITEM_UNEQUIPPED",
			{
				itemKey = itemData.nameKey,
			},
			200,
			215,
			235
		)
	end
end

function CombatService.SellBagItem(player: Player, bagIndex: number)
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	local idx = math.floor(tonumber(bagIndex) or 0)
	if idx < 1 or idx > #profile.InventoryBag then
		return
	end

	local itemId = profile.InventoryBag[idx]
	local itemData = ItemsConfig.GetItem(itemId)
	if not itemData then
		return
	end

	table.remove(profile.InventoryBag, idx)
	local sellPrice = math.max(1, itemData.sellPrice)
	state.Cash += sellPrice

	CombatService.SyncPlayerStats(player)
	CombatService.SyncProfile(player)
	DataManager.SaveProfile(player)

	sendSystemChat(
		player,
		"LOG_ITEM_SOLD",
		{
			itemKey = itemData.nameKey,
			price = sellPrice,
		},
		120,
		245,
		155
	)
end

local clearBotsForPlayer: (player: Player) -> ()
local spawnPartyCompanionBot: (player: Player, classArg: string?, customDisplayName: string?) -> ()
local spawnPvpRivalBot: (player: Player, isFlaggedBot: boolean) -> ()

local function handleDeveloperChatCommand(player: Player, rawMessage: string): boolean
	local trimmed = string.gsub(rawMessage, "^%s*(.-)%s*$", "%1")
	if string.sub(trimmed, 1, 1) ~= "/" then
		return false
	end

	local parts = string.split(trimmed, " ")
	local cmd = string.lower(parts[1] or "")
	local state = CombatService.GetPlayerState(player)
	local profile = DataManager.GetProfile(player)

	if cmd == "/dev_sub" or cmd == "/dev_unlock" then
		local targetLv = math.max(state.Level, GameConstants.SUBCLASS_REQUIRED_LEVEL)
		local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(targetLv)
		state.Level = targetLv
		state.Exp = 0
		state.MaxExp = maxExp
		state.BaseAtk = baseAtk
		state.BaseMaxHP = baseMaxHp

		profile.IsCharacterCreated = true
		profile.UnlockedClasses[state.ClassId] = true
		profile.BossKills.PlatformBaron = math.max(3, profile.BossKills.PlatformBaron)
		profile.BossKills.BlackFridayGolem = math.max(3, profile.BossKills.BlackFridayGolem)
		profile.BossKills.NightclubKing = math.max(3, profile.BossKills.NightclubKing)
		profile.BossKills.InflationArchitect = math.max(3, profile.BossKills.InflationArchitect)

		CombatService.RecalculateStats(player, true)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(player, "LOG_DEV_SUB_READY", {}, 120, 255, 160)
		return true
	elseif cmd == "/dev_lv" then
		local lvArg = tonumber(parts[2])
		if not lvArg then
			return true
		end
		local targetLv = math.clamp(math.floor(lvArg), 1, GameConstants.MAX_LEVEL)
		local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(targetLv)
		state.Level = targetLv
		state.Exp = 0
		state.MaxExp = maxExp
		state.BaseAtk = baseAtk
		state.BaseMaxHP = baseMaxHp

		profile.IsCharacterCreated = true
		profile.UnlockedClasses[state.ClassId] = true

		CombatService.RecalculateStats(player, true)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_DEV_LEVEL_SET",
			{
				lv = targetLv,
				maxExp = maxExp,
			},
			120,
			255,
			160
		)
		return true
	elseif cmd == "/dev_items" then
		state.EnergyShots += 500
		state.EnchantScrolls += 20
		state.Cash += 2000
		state.HpPotions += 50
		state.MpPotions += 50

		CombatService.RecalculateStats(player, false)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_DEV_ITEMS",
			{
				shots = state.EnergyShots,
				scrolls = state.EnchantScrolls,
				cash = state.Cash,
				hpPotions = state.HpPotions,
				mpPotions = state.MpPotions,
			},
			120,
			255,
			160
		)
		return true
	elseif cmd == "/dev_gear" then
		local addedCount = 0
		for _, gearId in ipairs(ItemsConfig.DEV_GEAR_IDS) do
			if #profile.InventoryBag < ItemsConfig.MAX_BAG_SLOTS then
				table.insert(profile.InventoryBag, gearId)
				addedCount += 1
			end
		end

		CombatService.RecalculateStats(player, false)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(player, "LOG_DEV_GEAR", { count = addedCount }, 255, 220, 85)
		return true
	elseif cmd == "/dev_enchant" then
		local enchArg = tonumber(parts[2])
		if not enchArg then
			return true
		end
		local targetEnchant = math.clamp(math.floor(enchArg), 0, GameConstants.MAX_ENCHANT_LEVEL)
		if profile.EquippedItems.Weapon == nil then
			profile.EquippedItems.Weapon = "WPN_STARTER"
		end
		profile.HasWeapon = true
		state.HasWeapon = true
		state.WeaponEnchant = targetEnchant
		player:SetAttribute("HasWeapon", true)
		player:SetAttribute("WeaponEnchant", targetEnchant)
		if player.Character then
			player.Character:SetAttribute("HasWeapon", true)
			player.Character:SetAttribute("WeaponEnchant", targetEnchant)
			if not player.Character:FindFirstChild("EquippedClassWeapon") then
				CombatService.EquipClassWeapon(player, state.ClassId)
			end
		end

		CombatService.RecalculateStats(player, false)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(
			player,
			"LOG_DEV_ENCHANT",
			{
				lv = targetEnchant,
				atk = GameConstants.GetWeaponEnchantAtkBonus(targetEnchant),
			},
			255,
			215,
			75
		)
		return true
	elseif cmd == "/dev_reset" then
		local freshProfile = DataManager.ResetProfile(player)
		local baseAtk, baseMaxHp, maxExp = computeBaseStatsForLevel(1)

		state.Gender = freshProfile.Gender
		state.RaceId = "RACE_LAW"
		state.ClassId = "RiotPolice"
		state.Level = 1
		state.Exp = 0
		state.MaxExp = maxExp
		state.BaseAtk = baseAtk
		state.BaseMaxHP = baseMaxHp
		state.Cash = freshProfile.Cash
		state.TrashTokens = freshProfile.TrashTokens
		state.HasWeapon = freshProfile.HasWeapon
		state.WeaponEnchant = freshProfile.WeaponEnchant
		state.EnergyShots = freshProfile.EnergyShots
		state.AutoSoulshot = freshProfile.AutoSoulshot
		state.EnchantScrolls = freshProfile.EnchantScrolls
		state.CrystalShards = freshProfile.CrystalShards
		state.HpPotions = freshProfile.HpPotions
		state.MpPotions = freshProfile.MpPotions
		state.LastHpPotionTime = 0
		state.LastMpPotionTime = 0
		state.Karma = 0
		state.PvpKills = 0
		state.PkKills = 0
		state.PvpFlagUntil = 0
		state.ClassProgress = {}
		table.clear(state.SkillCooldowns)

		CombatService.ApplyCharacterGenderAndStyle(player)
		CombatService.EquipClassWeapon(player, state.ClassId)
		CombatService.RecalculateStats(player, true)
		Remotes.ProfileUpdated:FireClient(player, freshProfile)
		sendSystemChat(player, "LOG_DEV_RESET", {}, 255, 215, 95)
		return true
	elseif cmd == "/dev_bot" then
		spawnPartyCompanionBot(player, parts[2])
		return true
	elseif cmd == "/dev_clearbots" then
		clearBotsForPlayer(player)
		sendSystemChat(player, "LOG_DEV_BOTS_CLEARED", {}, 215, 200, 140)
		return true
	elseif cmd == "/dev_enemybot" then
		spawnPvpRivalBot(player, false)
		return true
	elseif cmd == "/dev_flagbot" then
		spawnPvpRivalBot(player, true)
		return true
	elseif cmd == "/dev_clearpvp" then
		state.Karma = 0
		state.PvpFlagUntil = 0
		profile.Karma = 0
		CombatService.UpdateCharacterNametag(player)
		CombatService.SyncProfile(player)
		DataManager.SaveProfile(player)
		sendSystemChat(player, "LOG_DEV_PVP_CLEARED", {}, 120, 255, 165)
		return true
	elseif cmd == "/invite" or cmd == "/party" then
		local argRest = ""
		if #parts >= 2 then
			argRest = table.concat(parts, " ", 2)
		end
		if #argRest > 0 then
			PartyService.InvitePlayer(player, argRest)
		elseif state.SelectedTarget and state.SelectedTarget.Parent then
			PartyService.InvitePlayer(player, state.SelectedTarget)
		else
			spawnPartyCompanionBot(player, nil)
		end
		return true
	end

	return false
end

local spawnedBotsByPlayer: { [Player]: { Model } } = {}
local botCounterByPlayer: { [Player]: number } = {}

local function getOrCreateActiveMobsFolder(): Folder
	local existing = Workspace:FindFirstChild("ActiveMobs")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ActiveMobs"
	folder.Parent = Workspace
	return folder
end

local function createBotCharacterRig(
	modelName: string,
	spawnPos: Vector3,
	torsoColor: Color3,
	legsColor: Color3,
	skinColor: Color3,
	classId: string
): (Model, BasePart, BasePart, Humanoid)
	local model = Instance.new("Model")
	model.Name = modelName

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.Anchored = true
	hrp.CFrame = CFrame.new(spawnPos + Vector3.new(0, 3.0, 0))
	hrp.Parent = model
	model.PrimaryPart = hrp

	local torso = createWeaponPart("Torso", Vector3.new(2.0, 2.0, 1.0), torsoColor, Enum.Material.SmoothPlastic, model)
	torso.CanQuery = true
	weldParts(hrp, torso, CFrame.identity)

	local head = createWeaponPart("Head", Vector3.new(1.25, 1.25, 1.25), skinColor, Enum.Material.SmoothPlastic, model)
	head.CanQuery = true
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head
	weldParts(torso, head, CFrame.new(0, 1.55, 0))

	local leftArm = createWeaponPart("Left Arm", Vector3.new(0.95, 1.9, 0.95), torsoColor, Enum.Material.SmoothPlastic, model)
	leftArm.CanQuery = true
	weldParts(torso, leftArm, CFrame.new(-1.48, 0.0, 0))

	local rightArm = createWeaponPart("Right Arm", Vector3.new(0.95, 1.9, 0.95), torsoColor, Enum.Material.SmoothPlastic, model)
	rightArm.CanQuery = true
	weldParts(torso, rightArm, CFrame.new(1.48, 0.0, 0))

	local leftLeg = createWeaponPart("Left Leg", Vector3.new(0.95, 1.9, 0.95), legsColor, Enum.Material.SmoothPlastic, model)
	leftLeg.CanQuery = true
	weldParts(torso, leftLeg, CFrame.new(-0.52, -1.95, 0))

	local rightLeg = createWeaponPart("Right Leg", Vector3.new(0.95, 1.9, 0.95), legsColor, Enum.Material.SmoothPlastic, model)
	rightLeg.CanQuery = true
	weldParts(torso, rightLeg, CFrame.new(0.52, -1.95, 0))

	-- Attach Class Weapon to Right Arm
	local weaponModel = Instance.new("Model")
	weaponModel.Name = "EquippedClassWeapon"
	weaponModel.Parent = model

	local handle = createWeaponPart("Handle", Vector3.new(0.28, 1.1, 0.28), Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic, weaponModel)
	weaponModel.PrimaryPart = handle
	weldParts(rightArm, handle, CFrame.new(0, -0.95, -0.45) * CFrame.Angles(math.rad(-90), 0, 0))

	if classId == "RiotPolice" then
		local shaft = createWeaponPart("BatonShaft", Vector3.new(2.1, 0.32, 0.32), Color3.fromRGB(18, 20, 25), Enum.Material.SmoothPlastic, weaponModel)
		shaft.Shape = Enum.PartType.Cylinder
		weldParts(handle, shaft, CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local stunTip = createWeaponPart("StunTip", Vector3.new(0.36, 0.25, 0.36), Color3.fromRGB(0, 210, 255), Enum.Material.Neon, weaponModel)
		weldParts(handle, stunTip, CFrame.new(0, 2.45, 0))
	elseif classId == "HellsSousChef" then
		local blade = createWeaponPart("CleaverBlade", Vector3.new(0.14, 1.65, 0.95), Color3.fromRGB(200, 208, 220), Enum.Material.Metal, weaponModel)
		weldParts(handle, blade, CFrame.new(0, 1.35, -0.18))
		local heatedEdge = createWeaponPart("HeatedEdge", Vector3.new(0.16, 1.65, 0.15), Color3.fromRGB(255, 115, 30), Enum.Material.Neon, weaponModel)
		weldParts(handle, heatedEdge, CFrame.new(0, 1.35, -0.62))
	else
		local rod = createWeaponPart("HarvesterRod", Vector3.new(0.22, 1.45, 0.22), Color3.fromRGB(150, 165, 180), Enum.Material.Metal, weaponModel)
		weldParts(handle, rod, CFrame.new(0, 1.55, 0))
		local hook = createWeaponPart("LaserHook", Vector3.new(0.2, 0.45, 0.85), Color3.fromRGB(0, 245, 200), Enum.Material.Neon, weaponModel)
		weldParts(handle, hook, CFrame.new(0, 2.2, -0.32))
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = 220
	humanoid.Health = 220
	humanoid.Parent = model

	return model, hrp, head, humanoid
end

clearBotsForPlayer = function(player: Player)
	PartyService.RemoveBotsForPlayer(player)
	PartyService.LeaveParty(player)

	local list = spawnedBotsByPlayer[player]
	if list then
		for _, botModel in ipairs(list) do
			if botModel and botModel.Parent then
				botModel:Destroy()
			end
		end
		table.clear(list)
	end
	botCounterByPlayer[player] = 0
end

spawnPartyCompanionBot = function(player: Player, classArg: string?, customDisplayName: string?)
	local state = CombatService.GetPlayerState(player)
	local character = player.Character
	local playerRoot = if character then (character:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
	local originPos = if playerRoot then playerRoot.Position else Vector3.new(0, 0.5, 22)

	local idx = (botCounterByPlayer[player] or 0) + 1
	botCounterByPlayer[player] = idx

	local chosenClass = "RiotPolice"
	if classArg then
		local lower = string.lower(classArg)
		if string.find(lower, "chef") or string.find(lower, "sous") then
			chosenClass = "HellsSousChef"
		elseif string.find(lower, "recycle") or string.find(lower, "hunter") or string.find(lower, "spoil") then
			chosenClass = "RecycleHunter"
		else
			chosenClass = "RiotPolice"
		end
	else
		local cycle = { "RiotPolice", "HellsSousChef", "RecycleHunter" }
		chosenClass = cycle[((idx - 1) % #cycle) + 1]
	end

	local botNamesByClass: { [string]: string } = {
		RiotPolice = "Напарник-ОМОН #" .. tostring(idx),
		HellsSousChef = "Адский Повар #" .. tostring(idx),
		RecycleHunter = "Спойлер-Охотник #" .. tostring(idx),
	}
	local displayName = if customDisplayName and #customDisplayName > 0
		then customDisplayName
		else (botNamesByClass[chosenClass] or ("AI-Напарник #" .. tostring(idx)))

	local torsoCol = if chosenClass == "RiotPolice"
		then Color3.fromRGB(32, 62, 118)
		elseif chosenClass == "HellsSousChef" then Color3.fromRGB(155, 36, 48)
		else Color3.fromRGB(34, 108, 92)

	local angle = math.rad(idx * 72)
	local offset = Vector3.new(math.cos(angle) * 6.5, 0, math.sin(angle) * 6.5)
	local spawnPos = Vector3.new(originPos.X + offset.X, 0.4, originPos.Z + offset.Z)

	local botModel, botRoot, botHead, botHumanoid = createBotCharacterRig(
		"PartyBot_" .. player.Name .. "_" .. tostring(idx),
		spawnPos,
		torsoCol,
		Color3.fromRGB(28, 32, 42),
		Color3.fromRGB(235, 198, 168),
		chosenClass
	)

	local maxHp = 200 + (state.Level - 1) * 32
	local maxMp = 120 + (state.Level - 1) * 20
	botHumanoid.MaxHealth = maxHp
	botHumanoid.Health = maxHp

	botModel:SetAttribute("IsPartyBot", true)
	botModel:SetAttribute("IsMob", false)
	botModel:SetAttribute("OwnerUserId", player.UserId)
	botModel:SetAttribute("BotDisplayName", displayName)
	botModel:SetAttribute("NameKey", displayName)
	botModel:SetAttribute("ClassId", chosenClass)
	botModel:SetAttribute("Level", state.Level)
	botModel:SetAttribute("CurrentHP", maxHp)
	botModel:SetAttribute("MaxHP", maxHp)
	botModel:SetAttribute("MP", maxMp)
	botModel:SetAttribute("MaxMP", maxMp)
	botModel:SetAttribute("PDef", 45 + (state.Level - 1) * 5)

	-- Overhead Light-Blue Party Nametag
	local bb = Instance.new("BillboardGui")
	bb.Name = "PartyBotOverheadGui"
	bb.Adornee = botHead
	bb.Size = UDim2.fromOffset(190, 50)
	bb.StudsOffset = Vector3.new(0, 3.0, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 95
	bb.Parent = botHead

	local tagLbl = Instance.new("TextLabel")
	tagLbl.Size = UDim2.new(1, 0, 0, 14)
	tagLbl.BackgroundTransparency = 1
	tagLbl.Font = Enum.Font.GothamBlack
	tagLbl.TextSize = 11
	tagLbl.TextColor3 = Color3.fromRGB(95, 225, 255)
	tagLbl.TextStrokeTransparency = 0.15
	tagLbl.Text = "★ [НАПАРНИК ПАТИ / PARTY]"
	tagLbl.Parent = bb

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0, 18)
	nameLbl.Position = UDim2.fromOffset(0, 14)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 12
	nameLbl.TextColor3 = Color3.fromRGB(145, 235, 255)
	nameLbl.TextStrokeTransparency = 0.15
	nameLbl.Text = string.format("%s [Ур.%d]", displayName, state.Level)
	nameLbl.Parent = bb

	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(0.76, 0, 0, 6)
	hpBg.Position = UDim2.new(0.12, 0, 0, 35)
	hpBg.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = bb
	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(85, 235, 135)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	botModel.Parent = getOrCreateActiveMobsFolder()

	local addedOk = PartyService.AddBotCompanion(player, botModel, displayName, chosenClass, state.Level)
	if not addedOk then
		botModel:Destroy()
		return
	end

	if not spawnedBotsByPlayer[player] then
		spawnedBotsByPlayer[player] = {}
	end
	table.insert(spawnedBotsByPlayer[player], botModel)

	local cData = ClassesConfig[chosenClass]
	sendSystemChat(
		player,
		"LOG_DEV_BOT_SPAWNED",
		{
			name = displayName,
			classKey = if cData then cData.nameKey else chosenClass,
		},
		110,
		235,
		255
	)

	-- AI Companion Follow & Combat Loop
	task.spawn(function()
		local lastBotAttackTime = 0
		local followAngle = angle
		while botModel.Parent and player.Parent == Players do
			task.wait(0.25)
			local ownerState = playerStates[player]
			if not ownerState then
				break
			end

			-- Keep bot level synced with owner
			if (botModel:GetAttribute("Level") :: number?) ~= ownerState.Level then
				local newMaxHp = 200 + (ownerState.Level - 1) * 32
				local newMaxMp = 120 + (ownerState.Level - 1) * 20
				botModel:SetAttribute("Level", ownerState.Level)
				botModel:SetAttribute("MaxHP", newMaxHp)
				botModel:SetAttribute("CurrentHP", newMaxHp)
				botModel:SetAttribute("MaxMP", newMaxMp)
				botModel:SetAttribute("MP", newMaxMp)
				nameLbl.Text = string.format("%s [Ур.%d]", displayName, ownerState.Level)
			end

			local curHp = (botModel:GetAttribute("CurrentHP") :: number?) or maxHp
			local curMaxHp = (botModel:GetAttribute("MaxHP") :: number?) or maxHp
			local curMp = (botModel:GetAttribute("MP") :: number?) or maxMp
			local curMaxMp = (botModel:GetAttribute("MaxMP") :: number?) or maxMp

			local ownerChar = player.Character
			local ownerRoot = if ownerChar then (ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
			local targetMob = ownerState.SelectedTarget
			local targetAliveMob: Model? = nil

			if targetMob and targetMob.Parent and targetMob:GetAttribute("IsMob") == true then
				local mHp = (targetMob:GetAttribute("CurrentHP") :: number?) or 0
				if mHp > 0 then
					targetAliveMob = targetMob
				end
			end

			if targetAliveMob then
				local mobRoot = MobSpawnerService.GetMobRoot(targetAliveMob)
				if mobRoot then
					local botPos = botRoot.Position
					local flatDiff = Vector3.new(mobRoot.Position.X - botPos.X, 0, mobRoot.Position.Z - botPos.Z)
					local dist = flatDiff.Magnitude

					if dist > 6.2 then
						local step = math.min(dist - 5.2, 4.8)
						local dir = if dist > 0.05 then flatDiff.Unit else Vector3.new(0, 0, -1)
						local nextPos = Vector3.new(botPos.X + dir.X * step, 3.4, botPos.Z + dir.Z * step)
						botRoot.CFrame = CFrame.lookAt(nextPos, Vector3.new(mobRoot.Position.X, nextPos.Y, mobRoot.Position.Z))
					else
						botRoot.CFrame = CFrame.lookAt(botPos, Vector3.new(mobRoot.Position.X, botPos.Y, mobRoot.Position.Z))
					end

					local now = os.clock()
					if dist <= 11.0 and (now - lastBotAttackTime) >= 1.3 then
						lastBotAttackTime = now
						local botAtk = 24 + (ownerState.Level - 1) * 6
						-- Register botModel as the actual hate/aggro source so the mob attacks the Bot unless the player out-damages it!
						CombatService.ApplyDamageToMob(player, targetAliveMob, botAtk, false, false, botModel)
						if chosenClass == "RiotPolice" then
							MobSpawnerService.AddHate(targetAliveMob, botModel, botAtk)
						end

						-- Broadcast companion class VFX every 2nd swing
						local vfxSkillId = if chosenClass == "RiotPolice"
							then "SKILL_BATON_STUN"
							elseif chosenClass == "HellsSousChef" then "SKILL_SLICE_DICE"
							else "SKILL_CART_RAM"
						Remotes.SkillVFX:FireAllClients(vfxSkillId, player, {
							targetModel = targetAliveMob,
							targetPosition = mobRoot.Position,
						})

						-- Spend a bit of MP on skill swing and sync overhead HP bar with actual mob retaliation HP
						local nextMp = if curMp > 15 then (curMp - 8) else curMaxMp
						botModel:SetAttribute("MP", nextMp)
						local latestHp = (botModel:GetAttribute("CurrentHP") :: number?) or curHp
						hpFill.Size = UDim2.fromScale(math.clamp(latestHp / math.max(1, curMaxHp), 0, 1), 1)
					end
				end
			elseif ownerRoot then
				local targetFollowPos = ownerRoot.Position + Vector3.new(math.cos(followAngle) * 7.0, 0, math.sin(followAngle) * 7.0)
				local botPos = botRoot.Position
				local flatDiff = Vector3.new(targetFollowPos.X - botPos.X, 0, targetFollowPos.Z - botPos.Z)
				local dist = flatDiff.Magnitude
				if dist > 1.8 then
					local step = math.min(dist, 4.5)
					local dir = flatDiff.Unit
					local nextPos = Vector3.new(botPos.X + dir.X * step, 3.4, botPos.Z + dir.Z * step)
					botRoot.CFrame = CFrame.lookAt(nextPos, Vector3.new(ownerRoot.Position.X, nextPos.Y, ownerRoot.Position.Z))
				end

				-- Regenerate companion HP & MP while out of combat
				if curHp < curMaxHp or curMp < curMaxMp then
					local nextHp = math.min(curMaxHp, curHp + 14)
					local nextMp = math.min(curMaxMp, curMp + 12)
					botModel:SetAttribute("CurrentHP", nextHp)
					botModel:SetAttribute("MP", nextMp)
					hpFill.Size = UDim2.fromScale(math.clamp(nextHp / math.max(1, curMaxHp), 0, 1), 1)
				end
			end
		end
	end)
end

local function updatePvpDummyOverheadGui(dummyModel: Model)
	local head = dummyModel:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local bb = head:FindFirstChild("PvpDummyOverheadGui") :: BillboardGui?
	if not bb then
		return
	end
	local statusTag = bb:FindFirstChild("StatusTag") :: TextLabel?
	local nameLbl = bb:FindFirstChild("NameLabel") :: TextLabel?
	local hpBg = bb:FindFirstChild("HPBg") :: Frame?
	local hpFill = if hpBg then (hpBg:FindFirstChild("HPFill") :: Frame?) else nil

	local isFlagged = dummyModel:GetAttribute("IsPvpFlagged") == true
	local karma = (dummyModel:GetAttribute("Karma") :: number?) or 0
	local lv = (dummyModel:GetAttribute("Level") :: number?) or 1
	local dName = (dummyModel:GetAttribute("BotDisplayName") :: string?) or "Тестовый Игрок"
	local curHp = math.max(0, (dummyModel:GetAttribute("CurrentHP") :: number?) or 0)
	local maxHp = math.max(1, (dummyModel:GetAttribute("MaxHP") :: number?) or 1)

	if hpFill then
		hpFill.Size = UDim2.fromScale(math.clamp(curHp / maxHp, 0, 1), 1)
	end

	if karma > 0 then
		if statusTag then
			statusTag.Visible = true
			statusTag.Text = string.format("☠ [PK • Карма: %d]", karma)
			statusTag.TextColor3 = Color3.fromRGB(255, 55, 55)
		end
		if nameLbl then
			nameLbl.Text = string.format("%s [Ур.%d]", dName, lv)
			nameLbl.TextColor3 = Color3.fromRGB(255, 35, 35)
		end
	elseif isFlagged then
		if statusTag then
			statusTag.Visible = true
			statusTag.Text = "⚔ [PvP ФЛАГ / FLAGGED]"
			statusTag.TextColor3 = Color3.fromRGB(205, 115, 255)
		end
		if nameLbl then
			nameLbl.Text = string.format("%s [Ур.%d]", dName, lv)
			nameLbl.TextColor3 = Color3.fromRGB(185, 85, 255)
		end
	else
		if statusTag then
			statusTag.Visible = true
			statusTag.Text = "[МИРНЫЙ ИГРОК / WHITE NAME]"
			statusTag.TextColor3 = Color3.fromRGB(215, 225, 240)
		end
		if nameLbl then
			nameLbl.Text = string.format("%s [Ур.%d]", dName, lv)
			nameLbl.TextColor3 = Color3.fromRGB(245, 245, 255)
		end
	end
end

spawnPvpRivalBot = function(player: Player, isFlaggedBot: boolean)
	local state = CombatService.GetPlayerState(player)
	local character = player.Character
	local playerRoot = if character then (character:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil

	-- Always spawn outside the Safe Zone so PvP and PK can be tested immediately!
	local spawnPos = Vector3.new(0, 0.4, 96)
	if playerRoot then
		local pPos = playerRoot.Position
		local flatLook = playerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
		local lookDir = if flatLook.Magnitude > 0.05 then flatLook.Unit else Vector3.new(0, 0, 1)
		local candidatePos = Vector3.new(pPos.X + lookDir.X * 10, 0.4, pPos.Z + lookDir.Z * 10)
		if not GameConstants.IsInSafeZone(candidatePos) then
			spawnPos = candidatePos
		else
			-- Player is inside Safe Zone: place rival right outside the nearest Safe Zone gate (South Gate Z = 96)
			spawnPos = Vector3.new(math.clamp(pPos.X, -28, 28), 0.4, 96)
		end
	end

	local idx = (botCounterByPlayer[player] or 0) + 1
	botCounterByPlayer[player] = idx

	local displayName = if isFlaggedBot
		then ("Флагнутый Соперник #" .. tostring(idx))
		else ("Тестовый Игрок #" .. tostring(idx))
	local nameKey = if isFlaggedBot then "MOB_PVP_FLAGGED_RIVAL" else "MOB_PVP_RIVAL"

	local dummyModel, dummyRoot, dummyHead, dummyHumanoid = createBotCharacterRig(
		"PvpRival_" .. player.Name .. "_" .. tostring(idx),
		spawnPos,
		if isFlaggedBot then Color3.fromRGB(98, 38, 135) else Color3.fromRGB(58, 68, 86),
		Color3.fromRGB(30, 34, 44),
		Color3.fromRGB(235, 198, 168),
		if isFlaggedBot then "HellsSousChef" else "RiotPolice"
	)

	local maxHp = 180 + (state.Level - 1) * 30
	dummyHumanoid.MaxHealth = maxHp
	dummyHumanoid.Health = maxHp

	dummyModel:SetAttribute("IsPvpTarget", true)
	dummyModel:SetAttribute("IsMob", false)
	dummyModel:SetAttribute("OwnerUserId", player.UserId)
	dummyModel:SetAttribute("BotDisplayName", displayName)
	dummyModel:SetAttribute("NameKey", nameKey)
	dummyModel:SetAttribute("Level", state.Level)
	dummyModel:SetAttribute("CurrentHP", maxHp)
	dummyModel:SetAttribute("MaxHP", maxHp)
	dummyModel:SetAttribute("PDef", 30 + (state.Level - 1) * 4)
	dummyModel:SetAttribute("Karma", 0)
	dummyModel:SetAttribute("IsPvpFlagged", isFlaggedBot)
	dummyModel:SetAttribute("FightsBack", isFlaggedBot)

	local bb = Instance.new("BillboardGui")
	bb.Name = "PvpDummyOverheadGui"
	bb.Adornee = dummyHead
	bb.Size = UDim2.fromOffset(205, 52)
	bb.StudsOffset = Vector3.new(0, 3.0, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 95
	bb.Parent = dummyHead

	local statusTag = Instance.new("TextLabel")
	statusTag.Name = "StatusTag"
	statusTag.Size = UDim2.new(1, 0, 0, 15)
	statusTag.BackgroundTransparency = 1
	statusTag.Font = Enum.Font.GothamBlack
	statusTag.TextSize = 11
	statusTag.TextStrokeTransparency = 0.15
	statusTag.Parent = bb

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLabel"
	nameLbl.Size = UDim2.new(1, 0, 0, 18)
	nameLbl.Position = UDim2.fromOffset(0, 15)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextStrokeTransparency = 0.15
	nameLbl.Parent = bb

	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBg"
	hpBg.Size = UDim2.new(0.76, 0, 0, 7)
	hpBg.Position = UDim2.new(0.12, 0, 0, 37)
	hpBg.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = bb

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = if isFlaggedBot then Color3.fromRGB(185, 85, 255) else Color3.fromRGB(220, 48, 48)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	updatePvpDummyOverheadGui(dummyModel)
	dummyModel:GetAttributeChangedSignal("CurrentHP"):Connect(function()
		updatePvpDummyOverheadGui(dummyModel)
	end)
	dummyModel:GetAttributeChangedSignal("IsPvpFlagged"):Connect(function()
		updatePvpDummyOverheadGui(dummyModel)
	end)

	dummyModel.Parent = getOrCreateActiveMobsFolder()

	if not spawnedBotsByPlayer[player] then
		spawnedBotsByPlayer[player] = {}
	end
	table.insert(spawnedBotsByPlayer[player], dummyModel)

	sendSystemChat(
		player,
		"LOG_DEV_ENEMYBOT_SPAWNED",
		{
			name = displayName,
			x = math.floor(spawnPos.X + 0.5),
			z = math.floor(spawnPos.Z + 0.5),
		},
		225,
		145,
		255
	)

	-- Optional counter-attack loop for /dev_flagbot
	if isFlaggedBot then
		task.spawn(function()
			while dummyModel.Parent and player.Parent == Players do
				task.wait(1.6)
				local curHp = (dummyModel:GetAttribute("CurrentHP") :: number?) or 0
				if curHp <= 0 or curHp >= maxHp then
					continue
				end
				local pChar = player.Character
				local pRoot = if pChar then (pChar:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
				local pHum = if pChar then pChar:FindFirstChildOfClass("Humanoid") else nil
				if pRoot and pHum and pHum.Health > 0 and not GameConstants.IsInSafeZone(pRoot.Position) then
					local dist = ((pRoot.Position - dummyRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
					if dist <= 14.0 then
						dummyRoot.CFrame = CFrame.lookAt(
							dummyRoot.Position,
							Vector3.new(pRoot.Position.X, dummyRoot.Position.Y, pRoot.Position.Z)
						)
						local dmg = math.max(8, 12 + (state.Level - 1) * 3)
						pHum.Health = math.max(1, pHum.Health - dmg)
						Remotes.MobAttackedPlayer:FireClient(player, dummyModel, dmg)
					end
				end
			end
		end)
	end
end

local function faceTargetHorizontallyServer(playerRoot: BasePart, mobRoot: BasePart)
	local playerPos = playerRoot.Position
	local targetPos = mobRoot.Position
	local flatTargetPos = Vector3.new(targetPos.X, playerPos.Y, targetPos.Z)
	if (flatTargetPos - playerPos).Magnitude > 0.1 then
		playerRoot.CFrame = CFrame.lookAt(playerPos, flatTargetPos)
	end
end

local function isMobInFrontCone(playerRoot: BasePart, mobRoot: BasePart): boolean
	local playerPos = playerRoot.Position
	local mobPos = mobRoot.Position
	local flatDiff = (mobPos - playerPos) * Vector3.new(1, 0, 1)
	if flatDiff.Magnitude <= 0.05 then
		return true
	end
	local toMob = flatDiff.Unit
	local flatLook = playerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	local lookVec = if flatLook.Magnitude > 0.05 then flatLook.Unit else Vector3.new(0, 0, -1)
	local isInFrontCone = lookVec:Dot(toMob) >= FRONT_CONE_MIN_DOT
	return isInFrontCone
end

local function findClosestMobInWorkspace(
	playerRoot: BasePart,
	maxRange: number,
	requireDeadSpoiled: boolean
): Model?
	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return nil
	end

	local origin = playerRoot.Position
	local bestConeMob: Model? = nil
	local bestConeDist = maxRange
	local bestFallbackMob: Model? = nil
	local bestFallbackDist = math.min(20, maxRange)

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsMob") == true then
			local mobState = MobSpawnerService.GetMobState(child)
			local hp = if mobState then mobState.currentHp else ((child:GetAttribute("CurrentHP") :: number?) or 0)
			local isSpoiled = (mobState and mobState.isSpoiled)
				or (child:GetAttribute("IsSpoiled") == true)
				or (child:GetAttribute("CanSweep") == true)

			local valid = if requireDeadSpoiled then (hp <= 0 and isSpoiled) else (hp > 0)
			if valid then
				local root = MobSpawnerService.GetMobRoot(child)
				if root then
					local dist = (root.Position - origin).Magnitude
					if dist <= bestConeDist and isMobInFrontCone(playerRoot, root) then
						bestConeDist = dist
						bestConeMob = child
					end
					if dist <= bestFallbackDist then
						bestFallbackDist = dist
						bestFallbackMob = child
					end
				end
			end
		end
	end

	return bestConeMob or bestFallbackMob
end

local function isPvpTargetModel(attacker: Player, cand: Model): boolean
	if cand:GetAttribute("IsPvpTarget") == true then
		return true
	end
	local targetPlayer = Players:GetPlayerFromCharacter(cand)
	if targetPlayer and targetPlayer ~= attacker then
		return true
	end
	return false
end

local function getTargetCurrentHp(cand: Model): number
	local targetPlayer = Players:GetPlayerFromCharacter(cand)
	if targetPlayer then
		local hum = cand:FindFirstChildOfClass("Humanoid")
		return if hum then math.max(0, math.floor(hum.Health + 0.5)) else 0
	end
	local mobState = MobSpawnerService.GetMobState(cand)
	if mobState then
		return mobState.currentHp
	end
	return (cand:GetAttribute("CurrentHP") :: number?) or 0
end

local function resolveAliveTarget(
	attacker: Player,
	_playerRoot: BasePart,
	passedTarget: any,
	stateTarget: Model?,
	_maxRange: number
): Model?
	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	local candidates = { passedTarget, stateTarget }

	-- Strict Target Rule: Only return an explicitly targeted alive Mob or PvP Target; never blindly auto-pick a nearby mob!
	for _, cand in ipairs(candidates) do
		if typeof(cand) == "Instance" and cand:IsA("Model") then
			if (not activeMobsFolder or cand.Parent == activeMobsFolder) and cand:GetAttribute("IsMob") == true then
				local hp = getTargetCurrentHp(cand)
				if hp > 0 then
					return cand
				end
			elseif isPvpTargetModel(attacker, cand) then
				local hp = getTargetCurrentHp(cand)
				if hp > 0 then
					return cand
				end
			end
		end
	end

	return nil
end

function CombatService.ApplyDamageToPvpTarget(
	attacker: Player,
	targetModel: Model,
	rawDamage: number,
	_isSkill: boolean,
	forcePvp: boolean?,
	preConsumedSoulshot: boolean?
): (number, boolean, boolean)
	local state = CombatService.GetPlayerState(attacker)
	local profile = DataManager.GetProfile(attacker)
	local attackerChar = attacker.Character
	local attackerRoot = if attackerChar then (attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
	local targetRoot = MobSpawnerService.GetMobRoot(targetModel)
	if not attackerRoot or not targetRoot or not targetModel.Parent then
		return 0, false, false
	end

	-- 1. Safe Zone Check: Block all PvP damage if EITHER attacker or target is inside the Safe Zone
	if GameConstants.IsInSafeZone(attackerRoot.Position) or GameConstants.IsInSafeZone(targetRoot.Position) then
		sendSystemChat(attacker, "LOG_PVP_PEACE_ZONE_BLOCK", {}, 255, 85, 85)
		return 0, false, false
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	local targetState = if targetPlayer then playerStates[targetPlayer] else nil

	local targetKarma = if targetState
		then targetState.Karma
		else ((targetModel:GetAttribute("Karma") :: number?) or 0)
	local targetIsFlagged = if targetState
		then (targetState.PvpFlagUntil > os.clock())
		else (targetModel:GetAttribute("IsPvpFlagged") == true)

	-- 2. Force-Attack Check: Attacking a White-named player/dummy requires [Left Ctrl] or [PvP: ON]
	local targetIsWhite = (targetKarma <= 0) and (not targetIsFlagged)
	if targetIsWhite and forcePvp ~= true then
		sendSystemChat(attacker, "LOG_PVP_HOLD_CTRL_HINT", {}, 255, 200, 85)
		return 0, false, false
	end

	local curHp = getTargetCurrentHp(targetModel)
	if curHp <= 0 then
		return 0, false, false
	end

	-- 3. Flagging Rule on Hit: Hitting a White-named or Purple-named player/rival immediately flags attacker Purple (30s)
	if targetKarma <= 0 then
		local wasAlreadyFlagged = (state.PvpFlagUntil > os.clock())
		state.PvpFlagUntil = os.clock() + 30.0
		CombatService.UpdateCharacterNametag(attacker)
		if not wasAlreadyFlagged and state.Karma <= 0 then
			sendSystemChat(attacker, "LOG_PVP_FLAG_ON", {}, 205, 115, 255)
		end
	end

	local usedSoulshot = if preConsumedSoulshot ~= nil
		then preConsumedSoulshot
		else tryConsumeSoulshot(attacker, state)

	local targetPDef = if targetState
		then targetState.PDef
		else ((targetModel:GetAttribute("PDef") :: number?) or 35)
	local _, effectiveCrit = CombatService.GetEffectiveAttackStats(attacker)

	local mitigated = rawDamage * (100 / (100 + targetPDef))
	local isCrit = math.random() < effectiveCrit
	if isCrit then
		mitigated *= 1.85
	end
	if usedSoulshot then
		mitigated *= GameConstants.SOULSHOT_DAMAGE_MULTIPLIER
	end

	local finalDamage = math.max(1, math.floor(mitigated + 0.5))
	local newHp = math.max(0, curHp - finalDamage)

	targetModel:SetAttribute("CurrentHP", newHp)
	local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
	if targetHum then
		targetHum.Health = newHp
	end
	if targetPlayer then
		CombatService.SyncPlayerStats(targetPlayer)
	end

	Remotes.CombatHitFeedback:FireAllClients(targetModel, finalDamage, isCrit, false, usedSoulshot, attacker)

	local killed = false
	if newHp <= 0 then
		killed = true
		local victimName = if targetPlayer
			then targetPlayer.DisplayName
			else ((targetModel:GetAttribute("BotDisplayName") :: string?) or targetModel.Name)

		-- 4. Kill Rules:
		-- If victim was Purple (IsPvpFlagged == true) or Red (Karma > 0): +1 PvpKills and 0 Karma (Clean PvP win!)
		-- If victim was White (IsPvpFlagged == false and Karma == 0): PK committed! +1 PkKills, +240 Karma, Red Name!
		if targetIsFlagged or targetKarma > 0 then
			state.PvpKills += 1
			profile.PvpKills = state.PvpKills
			CombatService.UpdateCharacterNametag(attacker)
			CombatService.SyncProfile(attacker)
			DataManager.SaveProfile(attacker)
			sendSystemChat(
				attacker,
				"LOG_PVP_CLEAN_KILL",
				{
					victim = victimName,
					pvp = state.PvpKills,
				},
				115,
				255,
				155
			)
		else
			state.PkKills += 1
			state.Karma += 240
			profile.PkKills = state.PkKills
			profile.Karma = state.Karma
			CombatService.UpdateCharacterNametag(attacker)
			CombatService.SyncProfile(attacker)
			DataManager.SaveProfile(attacker)

			-- Broadcast PK red warning to all players
			for _, plr in ipairs(Players:GetPlayers()) do
				sendSystemChat(
					plr,
					"LOG_PK_COMMITTED",
					{
						victim = victimName,
						karma = state.Karma,
						pk = state.PkKills,
					},
					255,
					45,
					45
				)
			end
		end

		-- If target is a spawned PvP Rival Dummy, play fall & clean up after 3s
		if not targetPlayer and targetModel:GetAttribute("IsPvpTarget") == true then
			task.delay(3.0, function()
				if targetModel.Parent then
					targetModel:Destroy()
				end
			end)
		end
	end

	return finalDamage, killed, usedSoulshot
end

local function resolveDeadSpoiledTarget(
	playerRoot: BasePart,
	passedTarget: any,
	stateTarget: Model?,
	maxRange: number
): Model?
	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	local candidates = { passedTarget, stateTarget }

	for _, cand in ipairs(candidates) do
		if typeof(cand) == "Instance" and cand:IsA("Model") then
			if (not activeMobsFolder or cand.Parent == activeMobsFolder) and cand:GetAttribute("IsMob") == true then
				local mobState = MobSpawnerService.GetMobState(cand)
				local hp = if mobState then mobState.currentHp else ((cand:GetAttribute("CurrentHP") :: number?) or 0)
				local isSpoiled = (mobState and mobState.isSpoiled)
					or (cand:GetAttribute("IsSpoiled") == true)
					or (cand:GetAttribute("CanSweep") == true)
				local root = MobSpawnerService.GetMobRoot(cand)
				if hp <= 0 and isSpoiled and root and (root.Position - playerRoot.Position).Magnitude <= maxRange then
					return cand
				end
			end
		end
	end

	return findClosestMobInWorkspace(playerRoot, maxRange, true)
end

local function resolveSkillDataForPlayer(state: PlayerCombatState, slotOrSkillId: any): SkillsConfig.SkillData?
	local keyStr = tostring(slotOrSkillId or "")
	local upperKey = string.upper(keyStr)

	-- 1. Map "Q" -> 1, "E" -> 2, "R" -> 3, "F" -> 4
	local slotIndex = SLOT_TO_INDEX[upperKey]
	if slotIndex then
		local classSkills = CLASS_SKILL_ORDER[state.ClassId] or CLASS_SKILL_ORDER.RiotPolice
		local skillId = classSkills[slotIndex]
		if skillId and SkillsConfig[skillId] then
			return SkillsConfig[skillId]
		end
	end

	-- 2. Check ClassesConfig.skillSlots table
	local classData = ClassesConfig[state.ClassId]
	if classData and classData.skillSlots[upperKey] then
		local mappedId = classData.skillSlots[upperKey]
		if SkillsConfig[mappedId] then
			return SkillsConfig[mappedId]
		end
	end

	-- 3. Direct skillId lookup
	if SkillsConfig[keyStr] then
		return SkillsConfig[keyStr]
	end

	return nil
end

local function handleRequestAttack(player: Player, targetModel: any, forcePvpArg: any)
	local state = CombatService.GetPlayerState(player)
	local forcePvp = (forcePvpArg == true)

	local character = player.Character
	if not character then
		return
	end
	local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
	local playerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not playerHumanoid or not playerRoot or playerHumanoid.Health <= 0 then
		return
	end

	local _, _, effectiveAtkSpd = CombatService.GetEffectiveAttackStats(player)
	local cooldown = BASE_ATTACK_COOLDOWN / math.max(0.5, effectiveAtkSpd)
	local now = os.clock()
	if (now - state.LastAttackTime) < cooldown then
		return
	end

	local classData = ClassesConfig[state.ClassId] or ClassesConfig.RiotPolice
	local maxAtkRange = math.max(MELEE_ATTACK_RANGE, classData.attackRange or 8)

	local resolvedTarget = resolveAliveTarget(player, playerRoot, targetModel, state.SelectedTarget, maxAtkRange)
	if not resolvedTarget then
		return
	end

	local mobRoot = MobSpawnerService.GetMobRoot(resolvedTarget)
	if not mobRoot then
		return
	end

	local dist = ((mobRoot.Position - playerRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
	if dist > maxAtkRange + 2 then
		return
	end

	-- Snap/align server playerRoot CFrame horizontally to face target so 1-frame client CFrame replication lag never causes a miss
	faceTargetHorizontallyServer(playerRoot, mobRoot)

	if not isMobInFrontCone(playerRoot, mobRoot) then
		return
	end

	state.LastAttackTime = now
	state.SelectedTarget = resolvedTarget

	local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
	if isPvpTargetModel(player, resolvedTarget) then
		CombatService.ApplyDamageToPvpTarget(player, resolvedTarget, effectiveAtk, false, forcePvp)
	else
		CombatService.ApplyDamageToMob(player, resolvedTarget, effectiveAtk, false)
	end

	if (classData.attackRange or 8) >= 20 then
		Remotes.SkillVFX:FireAllClients("RANGED_AUTO_ATTACK", player, {
			targetModel = resolvedTarget,
			targetPosition = mobRoot.Position,
			weaponType = classData.weaponType,
		})
	end
end

-- Single Authoritative Skill Execution Pipeline inside CombatService
function CombatService.ExecuteSkill(player: Player, slotOrSkillId: any, targetModelArg: any, forcePvpArg: any)
	local state = CombatService.GetPlayerState(player)
	local forcePvp = (forcePvpArg == true)

	local character = player.Character
	if not character then
		return
	end
	local playerHumanoid = character:FindFirstChildOfClass("Humanoid")
	local playerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not playerHumanoid or not playerRoot or playerHumanoid.Health <= 0 then
		return
	end

	local skillData = resolveSkillDataForPlayer(state, slotOrSkillId)
	if not skillData then
		warn("[CombatService] Could not resolve skill for", player.Name, "class:", state.ClassId, "slot:", slotOrSkillId)
		return
	end

	local now = os.clock()
	local readyAt = state.SkillCooldowns[skillData.id] or 0
	if now < readyAt then
		return
	end

	local searchRange = math.max(SKILL_AUTO_TARGET_DISTANCE, skillData.range)

	-- ====================================================
	-- 1. SKILL_SWEEP (DeadSpoiledTarget)
	-- ====================================================
	if skillData.targetType == "DeadSpoiledTarget" then
		local corpse = resolveDeadSpoiledTarget(playerRoot, targetModelArg, state.SelectedTarget, searchRange)
		if not corpse then
			Remotes.SkillVFX:FireClient(player, "NO_TARGET", player, {
				skillId = skillData.id,
			})
			return
		end

		local corpseRoot = MobSpawnerService.GetMobRoot(corpse)
		local corpsePos = if corpseRoot then corpseRoot.Position else playerRoot.Position
		local sweptOk, mobData = MobSpawnerService.SweepCorpse(corpse)
		if not sweptOk or not mobData then
			return
		end

		state.SkillCooldowns[skillData.id] = now + skillData.cooldown
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)

		local gainedTokens = math.max(1, math.floor((mobData.level * 2 + math.random(1, 3)) * state.CashMult + 0.5))
		local bonusCash = math.max(5, math.floor(mobData.cashReward * 0.85 * state.CashMult + 0.5))

		state.TrashTokens += gainedTokens
		state.Cash += bonusCash
		player:SetAttribute("TrashTokens", state.TrashTokens)

		-- Bonus 20% chance on SKILL_SWEEP to pull an extra Enchant Scroll or Crystal Shards
		if math.random() <= 0.20 then
			if math.random() <= 0.55 then
				state.EnchantScrolls += 1
				player:SetAttribute("EnchantScrolls", state.EnchantScrolls)
				sendSystemChat(player, "LOG_SWEEP_BONUS_DROP", { itemKey = "UI_ENCHANT_SCROLLS", qty = 1 }, 255, 220, 85)
				Remotes.LootDropVFX:FireClient(player, "UI_ENCHANT_SCROLLS", 1, "D")
			else
				state.CrystalShards += 5
				player:SetAttribute("CrystalShards", state.CrystalShards)
				sendSystemChat(player, "LOG_SWEEP_BONUS_DROP", { itemKey = "UI_CRYSTAL_SHARDS", qty = 5 }, 115, 245, 255)
				Remotes.LootDropVFX:FireClient(player, "UI_CRYSTAL_SHARDS", 5, "NG")
			end
		end

		CombatService.SyncPlayerStats(player)
		CombatService.SyncProfile(player)

		print(
			string.format(
				"[CombatService] SKILL_SWEEP harvested %s -> +%d TrashTokens, +$%d Cash",
				mobData.id,
				gainedTokens,
				bonusCash
			)
		)

		Remotes.SkillVFX:FireAllClients(skillData.id, player, {
			targetPosition = corpsePos,
			tokens = gainedTokens,
			cash = bonusCash,
		})
		return
	end

	-- ====================================================
	-- 2. SingleTarget Skills (Baton Stun, Slice & Dice, Iron Pan, Spoil, Cart Ram)
	-- ====================================================
	if skillData.targetType == "SingleTarget" then
		local allowedRange = math.max(MELEE_ATTACK_RANGE, skillData.range or 8)

		local targetMob = resolveAliveTarget(player, playerRoot, targetModelArg, state.SelectedTarget, allowedRange)
		if not targetMob then
			Remotes.SkillVFX:FireClient(player, "NO_TARGET", player, {
				skillId = skillData.id,
			})
			return
		end

		local mobRoot = MobSpawnerService.GetMobRoot(targetMob)
		if not mobRoot then
			return
		end

		local dist = ((mobRoot.Position - playerRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
		if dist > allowedRange + 2 then
			Remotes.SkillVFX:FireClient(player, "NO_TARGET", player, {
				skillId = skillData.id,
				reason = "OUT_OF_CONE_OR_RANGE",
			})
			sendSystemChat(
				player,
				"LOG_TARGET_OUT_OF_CONE",
				{
					skillKey = skillData.nameKey,
				},
				255,
				155,
				85
			)
			return
		end

		-- Snap/align server playerRoot CFrame horizontally to face targetMob before frontal cone check
		faceTargetHorizontallyServer(playerRoot, mobRoot)

		if not isMobInFrontCone(playerRoot, mobRoot) then
			Remotes.SkillVFX:FireClient(player, "NO_TARGET", player, {
				skillId = skillData.id,
				reason = "OUT_OF_CONE_OR_RANGE",
			})
			sendSystemChat(
				player,
				"LOG_TARGET_OUT_OF_CONE",
				{
					skillKey = skillData.nameKey,
				},
				255,
				155,
				85
			)
			return
		end

		state.SelectedTarget = targetMob
		state.SkillCooldowns[skillData.id] = now + skillData.cooldown

		-- Deduct MP and sync HUD
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)
		CombatService.SyncPlayerStats(player)

		local isPvpTarget = isPvpTargetModel(player, targetMob)
		if isPvpTarget then
			-- PvP SingleTarget Skill Execution
			local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
			local hits = skillData.hitCount or 1
			local perHitRawDamage = (effectiveAtk * (skillData.damageMult or 1.4)) / hits
			local usedSoulshot = tryConsumeSoulshot(player, state)

			local totalDealt, killed =
				CombatService.ApplyDamageToPvpTarget(player, targetMob, perHitRawDamage, true, forcePvp, usedSoulshot)
			if totalDealt <= 0 and not killed then
				-- Blocked by Peace Zone or Ctrl check: refund cooldown
				state.SkillCooldowns[skillData.id] = 0
				Remotes.SkillVFX:FireClient(player, "NO_TARGET", player, {
					skillId = skillData.id,
					reason = "OUT_OF_CONE_OR_RANGE",
				})
				return
			end
			if hits > 1 then
				for hitIndex = 2, hits do
					task.delay((hitIndex - 1) * 0.12, function()
						if targetMob.Parent then
							CombatService.ApplyDamageToPvpTarget(
								player,
								targetMob,
								perHitRawDamage,
								true,
								forcePvp,
								usedSoulshot
							)
						end
					end)
				end
			end

			Remotes.SkillVFX:FireAllClients(skillData.id, player, {
				targetModel = targetMob,
				targetPosition = mobRoot.Position,
				damage = totalDealt * hits,
				usedSoulshot = usedSoulshot,
			})
			return
		end

		-- SKILL_SPOIL
		if skillData.id == "SKILL_SPOIL" then
			local alreadySpoiled = targetMob:GetAttribute("IsSpoiled") == true
			MobSpawnerService.MarkMobSpoiled(targetMob)
			MobSpawnerService.AddHate(targetMob, player, 100)

			local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
			local dealt, _, usedSoulshot = CombatService.ApplyDamageToMob(
				player,
				targetMob,
				effectiveAtk * (skillData.damageMult or 0.45),
				true
			)

			local statusKey = if alreadySpoiled then "MSG_SPOIL_ALREADY" else "MSG_SPOIL_SUCCESS"
			print(string.format("[CombatService] SKILL_SPOIL on %s (dmg=%d, status=%s)", targetMob.Name, dealt, statusKey))

			Remotes.SkillVFX:FireAllClients(skillData.id, player, {
				targetModel = targetMob,
				statusKey = statusKey,
				damage = dealt,
				usedSoulshot = usedSoulshot,
			})
			return
		end

		-- Dash step for SKILL_CART_RAM
		if skillData.id == "SKILL_CART_RAM" and dist > 4.5 then
			local flatToMob = Vector3.new(mobRoot.Position.X - playerRoot.Position.X, 0, mobRoot.Position.Z - playerRoot.Position.Z)
			if flatToMob.Magnitude > 0.1 then
				local stepDist = math.max(0, dist - 4.0)
				local newPos = playerRoot.Position + flatToMob.Unit * stepDist
				playerRoot.CFrame = CFrame.lookAt(newPos, Vector3.new(mobRoot.Position.X, newPos.Y, mobRoot.Position.Z))
			end
		end

		-- Teleport behind target for Shadow Step
		if skillData.isTeleportBehind then
			local behindOffset = -mobRoot.CFrame.LookVector * 3.2
			local targetPos = mobRoot.Position + behindOffset
			playerRoot.CFrame = CFrame.lookAt(targetPos, mobRoot.Position)
		end

		local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
		local hits = skillData.hitCount or 1
		local perHitRawDamage = (effectiveAtk * (skillData.damageMult or 1.4)) / hits
		local usedSoulshot = tryConsumeSoulshot(player, state)

		local totalDealt = CombatService.ApplyDamageToMob(player, targetMob, perHitRawDamage, true, usedSoulshot)
		if hits > 1 then
			for hitIndex = 2, hits do
				task.delay((hitIndex - 1) * 0.12, function()
					if targetMob.Parent then
						CombatService.ApplyDamageToMob(player, targetMob, perHitRawDamage, true, usedSoulshot)
					end
				end)
			end
		end

		-- Lifesteal from skill or buff
		local totalLifesteal = (skillData.lifestealRatio or 0) + (state.LifestealBonus or 0)
		if totalLifesteal > 0 and totalDealt > 0 and playerHumanoid then
			local healAmount = math.floor(totalDealt * totalLifesteal + 0.5)
			if healAmount > 0 then
				playerHumanoid.Health = math.min(playerHumanoid.MaxHealth, playerHumanoid.Health + healAmount)
				character:SetAttribute("CurrentHP", math.floor(playerHumanoid.Health + 0.5))
				Remotes.SkillVFX:FireAllClients("FLOATING_HEAL", player, {
					targetModel = character,
					amount = healAmount,
				})
			end
		end

		-- Target AoE Explosion (e.g. FPV Kamikaze Strike)
		if skillData.targetAoERadius and skillData.targetAoERadius > 0 then
			local aoeRad = skillData.targetAoERadius
			for otherModel, otherState in pairs(MobSpawnerService.GetAllActiveMobs()) do
				if otherModel ~= targetMob and not otherState.isDead and otherModel.Parent then
					local oRoot = MobSpawnerService.GetMobRoot(otherModel)
					if oRoot and (oRoot.Position - mobRoot.Position).Magnitude <= aoeRad then
						CombatService.ApplyDamageToMob(player, otherModel, perHitRawDamage * 0.75, true, usedSoulshot)
					end
				end
			end
		end

		if skillData.stunDuration and skillData.stunDuration > 0 then
			MobSpawnerService.StunMob(targetMob, skillData.stunDuration)
		end

		if skillData.pDefDebuffMult and skillData.pDefDebuffDuration then
			MobSpawnerService.ApplyPDefDebuff(targetMob, skillData.pDefDebuffMult, skillData.pDefDebuffDuration)
		end

		if skillData.bleedDuration and skillData.bleedTickMult then
			local ticks = math.max(1, math.floor(skillData.bleedDuration))
			local tickMult = skillData.bleedTickMult
			task.spawn(function()
				for _ = 1, ticks do
					task.wait(1.0)
					if not targetMob.Parent then
						break
					end
					local hp = (targetMob:GetAttribute("CurrentHP") :: number?) or 0
					if hp <= 0 then
						break
					end
					local atkNow = CombatService.GetEffectiveAttackStats(player)
					CombatService.ApplyDamageToMob(player, targetMob, atkNow * tickMult, true, false)
				end
			end)
		end

		print(string.format("[CombatService] %s dealt %d damage to %s", skillData.id, totalDealt, targetMob.Name))

		Remotes.SkillVFX:FireAllClients(skillData.id, player, {
			targetModel = targetMob,
			targetPosition = mobRoot.Position,
			damage = totalDealt * hits,
			usedSoulshot = usedSoulshot,
		})
		return
	end

	-- ====================================================
	-- 2.5 FriendlyOrSelf Skills (Instant Heal)
	-- ====================================================
	if skillData.targetType == "FriendlyOrSelf" then
		state.SkillCooldowns[skillData.id] = now + skillData.cooldown
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)
		CombatService.SyncPlayerStats(player)

		local healTargetModel: Model = character
		if targetModelArg and PartyService.IsFriendlyPartyTarget(player, targetModelArg) then
			local targetRoot = targetModelArg:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot and (targetRoot.Position - playerRoot.Position).Magnitude <= (skillData.range or 36) then
				healTargetModel = targetModelArg
			end
		end

		local targetHumanoid = healTargetModel:FindFirstChildOfClass("Humanoid")
		if targetHumanoid and targetHumanoid.Health > 0 then
			local maxHp = targetHumanoid.MaxHealth
			local healRatio = skillData.healMaxHpRatio or 0.35
			local healFlat = skillData.healFlat or 120
			local healAmount = math.floor(maxHp * healRatio + healFlat + 0.5)
			targetHumanoid.Health = math.min(maxHp, targetHumanoid.Health + healAmount)
			healTargetModel:SetAttribute("CurrentHP", math.floor(targetHumanoid.Health + 0.5))

			Remotes.SkillVFX:FireAllClients(skillData.id, player, {
				targetModel = healTargetModel,
				healAmount = healAmount,
			})
		end
		return
	end

	-- ====================================================
	-- 2.6 PartyBuff Skills (Party Auras, Mana Recharge, AoE Heals)
	-- ====================================================
	if skillData.targetType == "PartyBuff" then
		state.SkillCooldowns[skillData.id] = now + skillData.cooldown
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)
		CombatService.SyncPlayerStats(player)

		local aoeRadius = skillData.range or 30
		local partyEntities = PartyService.GetNearbyPartyEntities(player, playerRoot.Position, aoeRadius)
		local duration = skillData.buffDuration or 30.0

		for _, entity in ipairs(partyEntities) do
			if entity:IsA("Player") then
				local mPlayer = entity :: Player
				local mState = playerStates[mPlayer]
				local mChar = mPlayer.Character
				local mHum = if mChar then mChar:FindFirstChildOfClass("Humanoid") else nil

				if mState and mChar and mHum and mHum.Health > 0 then
					-- Instant Heal
					if skillData.healMaxHpRatio or skillData.healFlat then
						local healAmt = math.floor(mHum.MaxHealth * (skillData.healMaxHpRatio or 0) + (skillData.healFlat or 0) + 0.5)
						if healAmt > 0 then
							mHum.Health = math.min(mHum.MaxHealth, mHum.Health + healAmt)
							mChar:SetAttribute("CurrentHP", math.floor(mHum.Health + 0.5))
						end
					end

					-- Mana Recharge
					if skillData.manaMaxMpRatio or skillData.manaFlat then
						local manaAmt = math.floor(mState.MaxMP * (skillData.manaMaxMpRatio or 0) + (skillData.manaFlat or 0) + 0.5)
						if manaAmt > 0 then
							mState.MP = math.min(mState.MaxMP, mState.MP + manaAmt)
							mPlayer:SetAttribute("MP", mState.MP)
							CombatService.SyncPlayerStats(mPlayer)
						end
					end

					-- Apply stat buffs
					local hasBuff = false
						if skillData.buffAtkMult then mState.AtkMult = skillData.buffAtkMult; hasBuff = true end
						if skillData.buffPDefMult then mState.PDefMult = skillData.buffPDefMult; hasBuff = true end
						if skillData.buffMDefMult then mState.MDefMult = skillData.buffMDefMult; hasBuff = true end
						if skillData.buffMaxHpMult then mState.MaxHpMult = skillData.buffMaxHpMult; hasBuff = true end
						if skillData.buffMaxMpMult then mState.MaxMpMult = skillData.buffMaxMpMult; hasBuff = true end
						if skillData.buffWalkSpeedMult then mState.WalkSpeedMult = skillData.buffWalkSpeedMult; hasBuff = true end
						if skillData.buffCritBonus then mState.CritBonus = skillData.buffCritBonus; hasBuff = true end
						if skillData.buffCritDmgMult then mState.CritDmgMult = skillData.buffCritDmgMult; hasBuff = true end

					if hasBuff then
						CombatService.RecalculateStats(mPlayer, false)
						task.delay(duration, function()
							local curState = playerStates[mPlayer]
							if curState then
								if skillData.buffAtkMult then curState.AtkMult = 1.0 end
								if skillData.buffPDefMult then curState.PDefMult = 1.0 end
								if skillData.buffMDefMult then curState.MDefMult = 1.0 end
								if skillData.buffMaxHpMult then curState.MaxHpMult = 1.0 end
								if skillData.buffMaxMpMult then curState.MaxMpMult = 1.0 end
								if skillData.buffWalkSpeedMult then curState.WalkSpeedMult = 1.0 end
								if skillData.buffCritBonus then curState.CritBonus = 0.0 end
								if skillData.buffCritDmgMult then curState.CritDmgMult = 1.0 end
								CombatService.RecalculateStats(mPlayer, false)
							end
						end)
					end

					-- HoT tick loop if skillData.hotTickRatio
					if skillData.hotTickRatio and skillData.hotDuration then
						local ticks = math.max(1, math.floor(skillData.hotDuration))
						local tickRatio = skillData.hotTickRatio
						task.spawn(function()
							for _ = 1, ticks do
								task.wait(1.0)
								if not mChar.Parent or mHum.Health <= 0 then break end
								local tickAmt = math.floor(mHum.MaxHealth * tickRatio + 0.5)
								mHum.Health = math.min(mHum.MaxHealth, mHum.Health + tickAmt)
								mChar:SetAttribute("CurrentHP", math.floor(mHum.Health + 0.5))
							end
						end)
					end
				end
			elseif entity:IsA("Model") then
				-- AI Party Companion Bot
				local botHum = entity:FindFirstChildOfClass("Humanoid")
				if botHum and botHum.Health > 0 then
					if skillData.healMaxHpRatio or skillData.healFlat then
						local healAmt = math.floor(botHum.MaxHealth * (skillData.healMaxHpRatio or 0) + (skillData.healFlat or 0) + 0.5)
						botHum.Health = math.min(botHum.MaxHealth, botHum.Health + healAmt)
						entity:SetAttribute("CurrentHP", math.floor(botHum.Health + 0.5))
					end
				end
			end
		end

		Remotes.SkillVFX:FireAllClients(skillData.id, player, {
			origin = playerRoot.Position,
			radius = aoeRadius,
			duration = duration,
		})
		return
	end

	-- ====================================================
	-- 3. SelfAoE Skills (SKILL_MEGAPHONE_AGGRO)
	-- ====================================================
	if skillData.targetType == "SelfAoE" then
		state.SkillCooldowns[skillData.id] = now + skillData.cooldown
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)
		CombatService.SyncPlayerStats(player)

		local origin = playerRoot.Position
		local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
		local aoeRange = math.max(25, skillData.range)
		local usedSoulshot = tryConsumeSoulshot(player, state)

		for mobModel, mobState in pairs(MobSpawnerService.GetAllActiveMobs()) do
			local mobRoot = MobSpawnerService.GetMobRoot(mobModel)
			if not mobState.isDead and mobRoot then
				local dist = (mobRoot.Position - origin).Magnitude
				if dist <= aoeRange then
					if skillData.aggroBonus and skillData.aggroBonus > 0 then
						MobSpawnerService.AddHate(mobModel, player, skillData.aggroBonus)
					end
					local mult = if skillData.damageMult and skillData.damageMult > 0 then skillData.damageMult else 0.5
					CombatService.ApplyDamageToMob(player, mobModel, effectiveAtk * mult, true, usedSoulshot)
				end
			end
		end

		Remotes.SkillVFX:FireAllClients(skillData.id, player, {
			origin = origin,
			radius = skillData.range,
			usedSoulshot = usedSoulshot,
		})
		return
	end

	-- ====================================================
	-- 4. FrontalCone / Beam Skills (SKILL_WATER_CANNON, SKILL_FLAMBE)
	-- ====================================================
	if skillData.targetType == "FrontalCone" then
		state.SkillCooldowns[skillData.id] = now + skillData.cooldown
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)
		CombatService.SyncPlayerStats(player)

		local aimMob = resolveAliveTarget(player, playerRoot, targetModelArg, state.SelectedTarget, skillData.range)
		if aimMob then
			state.SelectedTarget = aimMob
			local aimRoot = MobSpawnerService.GetMobRoot(aimMob)
			if aimRoot then
				faceTargetHorizontallyServer(playerRoot, aimRoot)
			end
		end

		local origin = playerRoot.Position
		local flatLook = playerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
		local lookVec = if flatLook.Magnitude > 0.05 then flatLook.Unit else Vector3.new(0, 0, -1)

		local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
		local rawSkillDamage = effectiveAtk * (skillData.damageMult or 1.60)
		local knockbackDistance = if skillData.id == "SKILL_WATER_CANNON"
			then 18
			else (skillData.knockbackDist or 0)
		local usedSoulshot = tryConsumeSoulshot(player, state)

		local primaryDamage = 0
		for mobModel, mobState in pairs(MobSpawnerService.GetAllActiveMobs()) do
			local mobRoot = MobSpawnerService.GetMobRoot(mobModel)
			if not mobState.isDead and mobRoot then
				local dist = (mobRoot.Position - origin).Magnitude
				-- Strictly restricted to skillData.range and frontal cone (lookVec:Dot(toMob) >= 0.5)
				if dist <= skillData.range and isMobInFrontCone(playerRoot, mobRoot) then
					local dealt, killed = CombatService.ApplyDamageToMob(player, mobModel, rawSkillDamage, true, usedSoulshot)
					if primaryDamage == 0 then
						primaryDamage = dealt
					end
					if not killed and knockbackDistance > 0 then
						MobSpawnerService.KnockbackMob(mobModel, origin, knockbackDistance)
					end
				end
			end
		end

		Remotes.SkillVFX:FireAllClients(skillData.id, player, {
			origin = origin,
			direction = lookVec,
			range = skillData.range,
			targetModel = aimMob,
			damage = primaryDamage,
			usedSoulshot = usedSoulshot,
		})
		return
	end

	-- ====================================================
	-- 5. SelfBuff Skills (SKILL_RIOT_SHIELD, SKILL_FRIDAY_RUSH, SKILL_MONOPOLY)
	-- ====================================================
	if skillData.targetType == "SelfBuff" then
		state.SkillCooldowns[skillData.id] = now + skillData.cooldown
		if state.MP < skillData.mpCost then
			state.MP = state.MaxMP
		end
		state.MP = math.max(0, state.MP - skillData.mpCost)

		local duration = skillData.buffDuration or 8.0
		local savedClassId = state.ClassId

		-- Field Craft (StreetfoodCrafter E: Deploy Shawarma Grill)
		if skillData.effectType == "FieldCraft" then
			if skillData.healMaxHpRatio and playerHumanoid then
				local healAmt = math.floor(playerHumanoid.MaxHealth * skillData.healMaxHpRatio + 0.5)
				playerHumanoid.Health = math.min(playerHumanoid.MaxHealth, playerHumanoid.Health + healAmt)
				character:SetAttribute("CurrentHP", math.floor(playerHumanoid.Health + 0.5))
			end
			if skillData.craftScrolls then
				state.EnchantScrolls += skillData.craftScrolls
				player:SetAttribute("EnchantScrolls", state.EnchantScrolls)
			end
			if skillData.craftEnergyShots then
				state.EnergyShots += skillData.craftEnergyShots
				player:SetAttribute("EnergyShots", state.EnergyShots)
			end
			if skillData.craftHpPotions then
				state.HpPotions += skillData.craftHpPotions
				player:SetAttribute("HpPotions", state.HpPotions)
			end
			sendSystemChat(player, "LOG_CRAFT_SUCCESS", {}, 115, 255, 145)
			CombatService.SyncPlayerStats(player)
			CombatService.SyncProfile(player)
		end

		-- Summoner Combat Drone (DroneOperator E)
		if skillData.spawnsCombatDrone and droneDeployer then
			droneDeployer(player, duration)
		end

		if skillData.buffAtkMult then
			state.AtkMult = skillData.buffAtkMult
		end
		if skillData.buffPDefMult then
			state.PDefMult = skillData.buffPDefMult
		end
		if skillData.buffMDefMult then
			state.MDefMult = skillData.buffMDefMult
		end
		if skillData.buffMaxHpMult then
			state.MaxHpMult = skillData.buffMaxHpMult
		end
		if skillData.buffMaxMpMult then
			state.MaxMpMult = skillData.buffMaxMpMult
		end
		if skillData.buffWalkSpeedMult then
			state.WalkSpeedMult = skillData.buffWalkSpeedMult
		end
		if skillData.buffAtkSpdMult then
			state.AtkSpdMult = skillData.buffAtkSpdMult
		end
		if skillData.buffCritBonus then
			state.CritBonus = skillData.buffCritBonus
		end
		if skillData.buffCritDmgMult then
			state.CritDmgMult = skillData.buffCritDmgMult
		end
		if skillData.buffLifestealBonus then
			state.LifestealBonus = skillData.buffLifestealBonus
		end
		if skillData.buffCashMult then
			state.CashMult = skillData.buffCashMult
		end

		CombatService.RecalculateStats(player, false)

		Remotes.SkillVFX:FireAllClients(skillData.id, player, {
			duration = duration,
		})

		task.delay(duration, function()
			local currentState = playerStates[player]
			if not currentState or currentState.ClassId ~= savedClassId then
				return
			end
			if skillData.buffAtkMult then
				currentState.AtkMult = 1.0
			end
			if skillData.buffPDefMult then
				currentState.PDefMult = 1.0
			end
			if skillData.buffMDefMult then
				currentState.MDefMult = 1.0
			end
			if skillData.buffMaxHpMult then
				currentState.MaxHpMult = 1.0
			end
			if skillData.buffMaxMpMult then
				currentState.MaxMpMult = 1.0
			end
			if skillData.buffWalkSpeedMult then
				currentState.WalkSpeedMult = 1.0
			end
			if skillData.buffAtkSpdMult then
				currentState.AtkSpdMult = 1.0
			end
			if skillData.buffCritBonus then
				currentState.CritBonus = 0.0
			end
			if skillData.buffCritDmgMult then
				currentState.CritDmgMult = 1.0
			end
			if skillData.buffLifestealBonus then
				currentState.LifestealBonus = 0.0
			end
			if skillData.buffCashMult then
				currentState.CashMult = 1.0
			end
			CombatService.RecalculateStats(player, false)
		end)
	end
end

function CombatService.Init()
	if initialized then
		return
	end
	initialized = true

	PartyService.SetBotInviteHandler(function(inviter: Player, targetArg: any): boolean
		local invState = playerStates[inviter]
		local candidateModel: Model? = nil

		if typeof(targetArg) == "Instance" and targetArg:IsA("Model") then
			if
				targetArg:GetAttribute("IsMob") == true
				or targetArg:GetAttribute("MobId") ~= nil
				or MobsConfig[targetArg.Name] ~= nil
			then
				return false
			end
			candidateModel = targetArg
		elseif type(targetArg) == "string" then
			local q = string.lower((string.gsub(targetArg, "^%s*(.-)%s*$", "%1")))
			if MobsConfig[targetArg] ~= nil then
				return false
			end
			for mobId, mobData in pairs(MobsConfig) do
				if string.lower(mobId) == q or string.lower(mobData.nameKey) == q then
					return false
				end
			end
			if q == "bot" or q == "companion" or q == "ai" then
				spawnPartyCompanionBot(inviter, nil)
				return true
			end
			if #q > 0 then
				local mobsFolder = Workspace:FindFirstChild("ActiveMobs")
				if mobsFolder then
					for _, child in ipairs(mobsFolder:GetChildren()) do
						if
							child:IsA("Model")
							and child:GetAttribute("IsMob") ~= true
							and (child:GetAttribute("IsPvpTarget") == true or child:GetAttribute("IsPartyBot") == true)
						then
							local mName = string.lower(child.Name)
							local bName = string.lower(tostring(child:GetAttribute("BotDisplayName") or ""))
							if mName == q or bName == q or string.find(mName, q, 1, true) or string.find(bName, q, 1, true) then
								candidateModel = child
								break
							end
						end
					end
				end
			elseif invState and invState.SelectedTarget and invState.SelectedTarget.Parent then
				local sel = invState.SelectedTarget
				if
					sel:GetAttribute("IsMob") ~= true
					and (sel:GetAttribute("IsPvpTarget") == true or sel:GetAttribute("IsPartyBot") == true)
				then
					candidateModel = sel
				end
			end
		end

		if candidateModel and candidateModel.Parent and candidateModel:GetAttribute("IsMob") ~= true then
			if candidateModel:GetAttribute("IsPvpTarget") == true then
				local rName = tostring(candidateModel:GetAttribute("BotDisplayName") or candidateModel.Name)
				candidateModel:Destroy()
				spawnPartyCompanionBot(inviter, nil, rName)
				return true
			elseif candidateModel:GetAttribute("IsPartyBot") == true then
				spawnPartyCompanionBot(inviter, nil)
				return true
			end
		end

		return false
	end)

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		clearBotsForPlayer(player)
		syncStateIntoProfile(player)
		DataManager.SaveProfile(player)
		playerStates[player] = nil
	end)

	Remotes.SelectTarget.OnServerEvent:Connect(function(player: Player, mobModel: any)
		local state = CombatService.GetPlayerState(player)
		if typeof(mobModel) == "Instance" and mobModel:IsA("Model") then
			if
				mobModel:GetAttribute("IsMob") == true
				or mobModel:GetAttribute("IsPartyBot") == true
				or isPvpTargetModel(player, mobModel)
			then
				state.SelectedTarget = mobModel
			else
				state.SelectedTarget = nil
			end
		else
			state.SelectedTarget = nil
		end
	end)

	Remotes.RequestAttack.OnServerEvent:Connect(handleRequestAttack)

	Remotes.UseSkill.OnServerEvent:Connect(function(player: Player, slotOrSkillId: any, targetModel: any, forcePvpArg: any)
		CombatService.ExecuteSkill(player, slotOrSkillId, targetModel, forcePvpArg)
	end)

	Remotes.ChangeClassOrRace.OnServerEvent:Connect(function(player: Player, classId: any, raceId: any)
		local cleanClass = if type(classId) == "string" then classId else nil
		local cleanRace = if type(raceId) == "string" then raceId else nil
		CombatService.ChangeClassOrRace(player, cleanClass, cleanRace)
	end)

	Remotes.CreateCharacter.OnServerEvent:Connect(
		function(player: Player, raceId: any, startingClassId: any, genderArg: any)
			local cleanRace = if type(raceId) == "string" then raceId else "RACE_LAW"
			local cleanClass = if type(startingClassId) == "string" then startingClassId else "RiotPolice"
			local cleanGender = if type(genderArg) == "string" then genderArg else "Male"
			CombatService.CreateCharacter(player, cleanRace, cleanClass, cleanGender)
		end
	)

	Remotes.UnlockOrSwitchSubclass.OnServerEvent:Connect(function(player: Player, targetClassId: any)
		if type(targetClassId) == "string" then
			CombatService.UnlockOrSwitchSubclass(player, targetClassId)
		end
	end)

	Remotes.ToggleAutoSoulshot.OnServerEvent:Connect(function(player: Player)
		CombatService.ToggleAutoSoulshot(player)
	end)

	Remotes.ToggleSoulshot.OnServerEvent:Connect(function(player: Player)
		CombatService.ToggleAutoSoulshot(player)
	end)

	Remotes.RequestEnchantWeapon.OnServerEvent:Connect(function(player: Player)
		CombatService.RequestEnchantWeapon(player)
	end)

	Remotes.BuyShopItem.OnServerEvent:Connect(function(player: Player, itemType: any)
		if type(itemType) == "string" then
			CombatService.BuyShopItem(player, itemType)
		end
	end)

	Remotes.UsePotion.OnServerEvent:Connect(function(player: Player, potionType: any)
		if type(potionType) == "string" then
			CombatService.UsePotion(player, potionType)
		end
	end)

	Remotes.EquipItem.OnServerEvent:Connect(function(player: Player, bagIndex: any)
		if type(bagIndex) == "number" then
			CombatService.EquipItem(player, bagIndex)
		end
	end)

	Remotes.UnequipItem.OnServerEvent:Connect(function(player: Player, slotName: any)
		if type(slotName) == "string" then
			CombatService.UnequipItem(player, slotName)
		end
	end)

	Remotes.SellBagItem.OnServerEvent:Connect(function(player: Player, bagIndex: any)
		if type(bagIndex) == "number" then
			CombatService.SellBagItem(player, bagIndex)
		end
	end)

	Remotes.SwapBagItems.OnServerEvent:Connect(function(player: Player, fromIdx: any, toIdx: any)
		if type(fromIdx) == "number" and type(toIdx) == "number" then
			local profile = DataManager.GetProfile(player)
			local bag = profile.InventoryBag
			local i = math.floor(fromIdx)
			local j = math.floor(toIdx)
			if i >= 1 and i <= #bag and j >= 1 and j <= #bag and i ~= j then
				bag[i], bag[j] = bag[j], bag[i]
				CombatService.SyncProfile(player)
				DataManager.SaveProfile(player)
			elseif i >= 1 and i <= #bag and j > #bag and #bag >= 2 then
				local item = table.remove(bag, i)
				if item then
					table.insert(bag, item)
					CombatService.SyncProfile(player)
					DataManager.SaveProfile(player)
				end
			end
		end
	end)

	Remotes.SendChatMessage.OnServerEvent:Connect(function(player: Player, rawMessage: any)
		if type(rawMessage) == "string" then
			handleDeveloperChatCommand(player, rawMessage)
		end
	end)

	-- Passive HP/MP regeneration & Safe Zone detection loop (tripled regen inside Safe Zone)
	task.spawn(function()
		local tickCounter = 0
		while true do
			task.wait(0.5)
			tickCounter += 1
			local isRegenTick = (tickCounter % 4 == 0) -- Every 2.0s

			for player, state in pairs(playerStates) do
				if player.Parent == Players then
					local character = player.Character
					local rootPart = if character
						then (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
						else nil
					local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil

					local isSafe = if rootPart then GameConstants.IsInSafeZone(rootPart.Position) else true
					player:SetAttribute("InSafeZone", isSafe)
					if character then
						character:SetAttribute("InSafeZone", isSafe)
					end

					-- Check PvP Flag expiration (30s Purple Name timer)
					local now = os.clock()
					if state.PvpFlagUntil > 0 then
						if now >= state.PvpFlagUntil then
							state.PvpFlagUntil = 0
							CombatService.UpdateCharacterNametag(player)
							if state.Karma <= 0 then
								sendSystemChat(player, "LOG_PVP_FLAG_OFF", {}, 215, 225, 245)
							end
						else
							-- Refresh remaining seconds on Purple overhead tag
							CombatService.UpdateCharacterNametag(player)
						end
					end

					-- Safe Zone Station Guard Aggro against Red PK Players (Karma > 0 within 45 studs of any Guard or inside Safe Zone)
					local npcsFolder = Workspace:FindFirstChild("NPCs")
					if state.Karma > 0 and humanoid and humanoid.Health > 0 and rootPart and character then
						if npcsFolder then
							local activeGuard: Model? = nil
							local activeGuardRoot: BasePart? = nil
							local bestDist = 9999

							for _, npcChild in ipairs(npcsFolder:GetChildren()) do
								if
									npcChild:IsA("Model")
									and (
										npcChild:GetAttribute("NpcType") == "Guard"
										or string.find(npcChild.Name, "Guard") ~= nil
									)
								then
									local gRoot = npcChild.PrimaryPart
										or (npcChild:FindFirstChild("HumanoidRootPart") :: BasePart?)
									if gRoot then
										local d = (gRoot.Position - rootPart.Position).Magnitude
										if d < bestDist then
											bestDist = d
											activeGuard = npcChild
											activeGuardRoot = gRoot
										end
									end
								end
							end

							if activeGuard and activeGuardRoot and (bestDist <= 45.0 or isSafe) then
								-- Physically turn and step Guard toward the Red PK Criminal
								local gPos = activeGuardRoot.Position
								local flatToPk = Vector3.new(rootPart.Position.X - gPos.X, 0, rootPart.Position.Z - gPos.Z)
								local distFlat = flatToPk.Magnitude
								local nextGuardPos = gPos
								if distFlat > 7.5 then
									local stepDir = flatToPk.Unit
									local stepLen = math.min(distFlat - 6.5, 4.5)
									nextGuardPos = Vector3.new(gPos.X + stepDir.X * stepLen, gPos.Y, gPos.Z + stepDir.Z * stepLen)
								end
								activeGuard:PivotTo(
									CFrame.lookAt(
										nextGuardPos,
										Vector3.new(rootPart.Position.X, nextGuardPos.Y, rootPart.Position.Z)
									)
								)

								if (now - state.LastGuardStrikeTime) >= 1.0 then
									state.LastGuardStrikeTime = now
									local strikeDmg = math.max(95, math.floor(state.MaxHP * 0.45 + 0.5))

									-- Brief stun/slow from Guard Halberd Shock
									character:SetAttribute("IsStunned", true)
									local origSpeed = humanoid.WalkSpeed
									humanoid.WalkSpeed = math.min(origSpeed, 6)
									task.delay(0.85, function()
										if character and character.Parent then
											character:SetAttribute("IsStunned", false)
										end
										if humanoid and humanoid.Parent and humanoid.Health > 0 then
											CombatService.RecalculateStats(player, false)
										end
									end)

									-- Visual Lightning / Baton Beam from Guard to Red PK Player
									local startPos = activeGuardRoot.Position + Vector3.new(0, 1.5, 0)
									local endPos = rootPart.Position + Vector3.new(0, 1.0, 0)
									local beamLen = (endPos - startPos).Magnitude
									if beamLen > 0.1 then
										local beamPart = Instance.new("Part")
										beamPart.Name = "GuardPunishLightning"
										beamPart.Size = Vector3.new(0.55, 0.55, beamLen)
										beamPart.Color = Color3.fromRGB(0, 225, 255)
										beamPart.Material = Enum.Material.Neon
										beamPart.Anchored = true
										beamPart.CanCollide = false
										beamPart.CanQuery = false
										beamPart.CFrame = CFrame.lookAt((startPos + endPos) * 0.5, endPos)
										beamPart.Parent = Workspace
										task.delay(0.32, function()
											if beamPart.Parent then
												beamPart:Destroy()
											end
										end)
									end

									sendSystemChat(
										player,
										"LOG_GUARD_PK_STRIKE",
										{
											player = player.DisplayName,
											karma = state.Karma,
											dmg = strikeDmg,
										},
										255,
										55,
										55
									)
									Remotes.CombatHitFeedback:FireAllClients(
										character,
										strikeDmg,
										true,
										false,
										true,
										nil
									)
									humanoid.Health = math.max(0, humanoid.Health - strikeDmg)
									CombatService.SyncPlayerStats(player)
								end
							end
						end
					elseif npcsFolder then
						-- Return Station Guards to their post if no Red PK player is nearby
						for _, npcChild in ipairs(npcsFolder:GetChildren()) do
							if
								npcChild:IsA("Model")
								and (
									npcChild:GetAttribute("NpcType") == "Guard"
									or string.find(npcChild.Name, "Guard") ~= nil
								)
							then
								local homePos = npcChild:GetAttribute("GuardHomePos") :: Vector3?
								local lookPos = npcChild:GetAttribute("GuardLookPos") :: Vector3?
								local gRoot = npcChild.PrimaryPart
									or (npcChild:FindFirstChild("HumanoidRootPart") :: BasePart?)
								if homePos and lookPos and gRoot and (gRoot.Position - homePos).Magnitude > 1.0 then
									npcChild:PivotTo(CFrame.lookAt(homePos, lookPos))
								end
							end
						end
					end

					if isRegenTick then
						local regenMult = if isSafe then 3 else 1
						local statsChanged = false

						if humanoid and humanoid.Health > 0 and humanoid.Health < state.MaxHP then
							local baseHpRegen = math.max(5, math.floor(state.MaxHP * 0.025 + 0.5))
							humanoid.Health = math.min(state.MaxHP, humanoid.Health + baseHpRegen * regenMult)
							statsChanged = true
						end

						if state.MP < state.MaxMP then
							state.MP = math.min(state.MaxMP, state.MP + (6 * regenMult))
							player:SetAttribute("MP", state.MP)
							statsChanged = true
						end

						if statsChanged then
							CombatService.SyncPlayerStats(player)
						end
					end
				end
			end
		end
	end)
end

return CombatService
