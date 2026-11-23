--!strict

local Workspace = game:GetService("Workspace")

export type GradeId = "NG" | "D" | "C" | "B" | "A"

export type GradeInfo = {
	id: GradeId,
	minLevel: number,
	maxLevel: number,
}

export type SubclassBossRequirement = {
	id: string,
	nameKey: string,
	tier: number,
	level: number,
	requiredKills: number,
}

local GameConstants = {}

GameConstants.MAX_LEVEL = 50
GameConstants.SUBCLASS_REQUIRED_LEVEL = 40
GameConstants.SUBCLASS_REQUIRED_KILLS = 3

-- Phase 3: Lineage 2 Weapon Enchanting & Soulshots ("Energy Shots")
GameConstants.SAFE_ENCHANT_MAX = 3
GameConstants.MAX_ENCHANT_LEVEL = 16
GameConstants.ENCHANT_ATK_BONUS_PER_LEVEL = 5
GameConstants.ENCHANT_ATK_BONUS_HIGH_LEVEL = 12
GameConstants.SOULSHOT_DAMAGE_MULTIPLIER = 2.0

-- Phase 3: Express Kiosk / Shop Prices
GameConstants.PRICE_ENERGY_SHOTS_PACK = 40
GameConstants.ENERGY_SHOTS_PACK_AMOUNT = 100
GameConstants.PRICE_ENCHANT_SCROLL_CASH = 120
GameConstants.PRICE_ENCHANT_SCROLL_TOKENS = 5
GameConstants.PRICE_NEW_WEAPON_CASH = 100
GameConstants.BARE_FIST_ATK_MULTIPLIER = 0.5
GameConstants.MELEE_ATTACK_RANGE = 10
GameConstants.FRONT_CONE_MIN_DOT = 0.5

-- Phase 3.5: HP & MP Recovery Potions
GameConstants.POTION_COOLDOWN = 5.0
GameConstants.HP_POTION_HEAL_PERCENT = 0.35
GameConstants.HP_POTION_MIN_HEAL = 80
GameConstants.MP_POTION_RESTORE_PERCENT = 0.35
GameConstants.MP_POTION_MIN_RESTORE = 50
GameConstants.PRICE_HP_POTION_PACK = 25
GameConstants.PRICE_MP_POTION_PACK = 25
GameConstants.POTION_PACK_AMOUNT = 5

-- Phase 4B Legacy Fallback Safe Zone Bounds (used only if workspace.Map.Zones.CentralStation_SafeZone is absent)
GameConstants.SAFE_ZONE_HALF_SIZE = 85
GameConstants.SAFE_ZONE_MIN_Z = -65
GameConstants.SAFE_ZONE_MAX_Z = 85

local cachedSafeZone: Instance? = nil

local function getCentralStationSafeZone(): Instance?
	if cachedSafeZone and cachedSafeZone.Parent then
		return cachedSafeZone
	end

	local mapFolder = Workspace:FindFirstChild("Map")
	if not mapFolder then
		return nil
	end
	local zonesFolder = mapFolder:FindFirstChild("Zones")
	if not zonesFolder then
		return nil
	end
	local safeZone = zonesFolder:FindFirstChild("CentralStation_SafeZone")
	if safeZone then
		cachedSafeZone = safeZone
		return safeZone
	end

	return nil
end

local function isPointInsideZonePart(part: BasePart, pos: Vector3, pad: number): boolean
	local localPos = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size * 0.5

	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		-- Roblox Cylinder axis is local X; circular cross-section lies in local Y-Z
		local radius = math.max(half.Y, half.Z) + pad
		local radialSq = localPos.Y * localPos.Y + localPos.Z * localPos.Z
		if radialSq > radius * radius then
			return false
		end
		if part.Size.X >= 12 then
			return math.abs(localPos.X) <= (half.X + pad)
		end
		return math.abs(localPos.X) <= (half.X + 60)
	end

	if math.abs(localPos.X) > (half.X + pad) or math.abs(localPos.Z) > (half.Z + pad) then
		return false
	end

	if part.Size.Y >= 12 then
		return math.abs(localPos.Y) <= (half.Y + pad)
	end

	return localPos.Y >= -(half.Y + 12) and localPos.Y <= (half.Y + 60)
end

local function isPointInsideZoneInstance(zone: Instance, pos: Vector3, pad: number): boolean
	if zone:IsA("BasePart") then
		return isPointInsideZonePart(zone, pos, pad)
	end
	for _, descendant in ipairs(zone:GetDescendants()) do
		if descendant:IsA("BasePart") and isPointInsideZonePart(descendant, pos, pad) then
			return true
		end
	end
	return false
end

function GameConstants.IsInSafeZone(pos: Vector3, margin: number?): boolean
	local pad = margin or 0
	local safeZone = getCentralStationSafeZone()
	if safeZone then
		if safeZone:GetAttribute("IsSafeZone") ~= true then
			return false
		end
		return isPointInsideZoneInstance(safeZone, pos, pad)
	end

	return math.abs(pos.X) <= (GameConstants.SAFE_ZONE_HALF_SIZE + pad)
		and pos.Z >= (GameConstants.SAFE_ZONE_MIN_Z - pad)
		and pos.Z <= (GameConstants.SAFE_ZONE_MAX_Z + pad)
end

function GameConstants.GetEnchantSuccessChance(currentLevel: number): number
	local lv = math.floor(currentLevel)
	if lv < 0 then
		return 1.00
	elseif lv <= 2 then
		-- 0, 1, 2 (going to +1, +2, +3): 100%
		return 1.00
	elseif lv <= 6 then
		-- 3..6 (going to +4..+7): 66%
		return 0.66
	elseif lv <= 10 then
		-- 7..10 (going to +8..+11): 50%
		return 0.50
	elseif lv <= 15 then
		-- 11..15 (going to +12..+16): 35%
		return 0.35
	else
		return 0.0
	end
end

function GameConstants.GetWeaponEnchantAtkBonus(enchantLevel: number): number
	local lv = math.clamp(math.floor(enchantLevel), 0, GameConstants.MAX_ENCHANT_LEVEL)
	if lv <= 0 then
		return 0
	elseif lv <= GameConstants.SAFE_ENCHANT_MAX then
		return lv * GameConstants.ENCHANT_ATK_BONUS_PER_LEVEL
	else
		local safeBonus = GameConstants.SAFE_ENCHANT_MAX * GameConstants.ENCHANT_ATK_BONUS_PER_LEVEL
		local overEnchantLevels = lv - GameConstants.SAFE_ENCHANT_MAX
		return safeBonus + overEnchantLevels * GameConstants.ENCHANT_ATK_BONUS_HIGH_LEVEL
	end
end

GameConstants.SUBCLASS_REQUIRED_BOSSES = {
	{
		id = "PlatformBaron",
		nameKey = "MOB_PLATFORM_BARON",
		tier = 1,
		level = 10,
		requiredKills = 3,
	},
	{
		id = "BlackFridayGolem",
		nameKey = "MOB_BLACK_FRIDAY_GOLEM",
		tier = 2,
		level = 20,
		requiredKills = 3,
	},
	{
		id = "NightclubKing",
		nameKey = "MOB_NIGHTCLUB_KING",
		tier = 3,
		level = 30,
		requiredKills = 3,
	},
	{
		id = "InflationArchitect",
		nameKey = "MOB_INFLATION_ARCHITECT",
		tier = 4,
		level = 40,
		requiredKills = 3,
	},
} :: { SubclassBossRequirement }

GameConstants.SUBCLASS_BOSS_BY_ID = {
	PlatformBaron = GameConstants.SUBCLASS_REQUIRED_BOSSES[1],
	BlackFridayGolem = GameConstants.SUBCLASS_REQUIRED_BOSSES[2],
	NightclubKing = GameConstants.SUBCLASS_REQUIRED_BOSSES[3],
	InflationArchitect = GameConstants.SUBCLASS_REQUIRED_BOSSES[4],
} :: { [string]: SubclassBossRequirement }

GameConstants.PARTY_EXP_BONUS = {
	[1] = 1.0,
	[2] = 1.1,
	[3] = 1.2,
	[4] = 1.3,
	[5] = 1.5,
} :: { [number]: number }

GameConstants.GRADES = {
	NG = { id = "NG", minLevel = 1, maxLevel = 10 },
	D = { id = "D", minLevel = 10, maxLevel = 20 },
	C = { id = "C", minLevel = 20, maxLevel = 30 },
	B = { id = "B", minLevel = 30, maxLevel = 40 },
	A = { id = "A", minLevel = 40, maxLevel = 50 },
} :: { [GradeId]: GradeInfo }

function GameConstants.GetRequiredExp(level: number): number
	local clampedLevel = math.clamp(math.floor(level), 1, GameConstants.MAX_LEVEL)
	local tierMult = 1.0
	if clampedLevel >= 40 then
		tierMult = 3.5
	elseif clampedLevel >= 30 then
		tierMult = 2.5
	elseif clampedLevel >= 20 then
		tierMult = 1.8
	elseif clampedLevel >= 10 then
		tierMult = 1.35
	else
		tierMult = 1.0
	end

	return math.floor(100 * (clampedLevel ^ 2.4) * tierMult)
end

function GameConstants.CalculateLevelPenalty(attackerLevel: number, targetLevel: number): number
	local diff = targetLevel - attackerLevel
	if diff <= 4 then
		return 1.0
	elseif diff == 5 then
		return 0.5
	elseif diff == 6 then
		return 0.4
	elseif diff == 7 then
		return 0.3
	elseif diff == 8 then
		return 0.2
	elseif diff == 9 then
		return 0.1
	else
		return 0.01
	end
end

return GameConstants
