--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local GameConstants = require(Configs:WaitForChild("GameConstants"))
local ItemsConfig = require(Configs:WaitForChild("ItemsConfig"))

export type SavedClassProgress = {
	Level: number,
	Exp: number,
	HP: number,
	MP: number,
}

export type BossKillCounts = {
	PlatformBaron: number,
	BlackFridayGolem: number,
	NightclubKing: number,
	InflationArchitect: number,
}

export type EquippedItemsMap = {
	Weapon: string?,
	Chest: string?,
	Legs: string?,
	Boots: string?,
	Accessory1: string?,
	Accessory2: string?,
}

export type PlayerProfile = {
	IsCharacterCreated: boolean,
	Gender: string,
	RaceId: string,
	CurrentClassId: string,
	UnlockedClasses: { [string]: boolean },
	ClassProgress: { [string]: SavedClassProgress },
	BossKills: BossKillCounts,
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
	EquippedItems: EquippedItemsMap,
	InventoryBag: { string },
	Karma: number,
	PvpKills: number,
	PkKills: number,
}

local DATASTORE_NAME = "MegapolisL2_Profiles_v2_5"

local LEGACY_CLASS_ID_MAP: { [string]: string } = {
	Rocker = "SubwayRocker",
	Crafter = "StreetfoodCrafter",
	Courier = "ExpressCourier",
	Inspector = "ParkingInspector",
	Builder = "HeavyBuilder",
	CyberMage = "FullstackCyberMage",
	Alchemist = "UrbanAlchemist",
}

local function normalizeClassId(classId: string): string
	return LEGACY_CLASS_ID_MAP[classId] or classId
end

local DataManager = {}

local profileStore: GlobalDataStore? = nil
local activeProfiles: { [Player]: PlayerProfile } = {}
local memoryFallbackStore: { [string]: PlayerProfile } = {}
local initialized = false

local function getStore(): GlobalDataStore?
	if profileStore then
		return profileStore
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok and store then
		profileStore = store
		return store
	end
	return nil
end

local function createDefaultProfile(): PlayerProfile
	return {
		IsCharacterCreated = false,
		Gender = "Male",
		RaceId = "RACE_LAW",
		CurrentClassId = "RiotPolice",
		UnlockedClasses = {},
		ClassProgress = {},
		BossKills = {
			PlatformBaron = 0,
			BlackFridayGolem = 0,
			NightclubKing = 0,
			InflationArchitect = 0,
		},
		Cash = 0,
		TrashTokens = 0,
		HasWeapon = true,
		WeaponEnchant = 0,
		EnergyShots = 150,
		AutoSoulshot = true,
		EnchantScrolls = 5,
		CrystalShards = 0,
		HpPotions = 10,
		MpPotions = 10,
		EquippedItems = {
			Weapon = "WPN_STARTER",
			Chest = "ARM_COMMUTER_JACKET",
			Legs = nil,
			Boots = "ARM_RUBBER_BOOTS",
			Accessory1 = nil,
			Accessory2 = nil,
		},
		InventoryBag = {},
		Karma = 0,
		PvpKills = 0,
		PkKills = 0,
	}
end

local function deepCopyProfile(src: PlayerProfile): PlayerProfile
	local unlockedCopy: { [string]: boolean } = {}
	for k, v in pairs(src.UnlockedClasses) do
		unlockedCopy[k] = v == true
	end

	local progressCopy: { [string]: SavedClassProgress } = {}
	for k, v in pairs(src.ClassProgress) do
		progressCopy[k] = {
			Level = v.Level,
			Exp = v.Exp,
			HP = v.HP,
			MP = v.MP,
		}
	end

	local bagCopy: { string } = {}
	if type(src.InventoryBag) == "table" then
		for _, itemId in ipairs(src.InventoryBag) do
			if type(itemId) == "string" then
				table.insert(bagCopy, itemId)
			end
		end
	end

	local eq = src.EquippedItems or ({} :: EquippedItemsMap)

	return {
		IsCharacterCreated = src.IsCharacterCreated,
		Gender = src.Gender,
		RaceId = src.RaceId,
		CurrentClassId = src.CurrentClassId,
		UnlockedClasses = unlockedCopy,
		ClassProgress = progressCopy,
		BossKills = {
			PlatformBaron = src.BossKills.PlatformBaron or 0,
			BlackFridayGolem = src.BossKills.BlackFridayGolem or 0,
			NightclubKing = src.BossKills.NightclubKing or 0,
			InflationArchitect = src.BossKills.InflationArchitect or 0,
		},
		Cash = src.Cash,
		TrashTokens = src.TrashTokens,
		HasWeapon = src.HasWeapon,
		WeaponEnchant = src.WeaponEnchant,
		EnergyShots = src.EnergyShots,
		AutoSoulshot = src.AutoSoulshot,
		EnchantScrolls = src.EnchantScrolls,
		CrystalShards = src.CrystalShards,
		HpPotions = src.HpPotions,
		MpPotions = src.MpPotions,
		EquippedItems = {
			Weapon = eq.Weapon,
			Chest = eq.Chest,
			Legs = eq.Legs,
			Boots = eq.Boots,
			Accessory1 = eq.Accessory1,
			Accessory2 = eq.Accessory2,
		},
		InventoryBag = bagCopy,
		Karma = src.Karma or 0,
		PvpKills = src.PvpKills or 0,
		PkKills = src.PkKills or 0,
	}
end

local function sanitizeLoadedProfile(raw: any): PlayerProfile
	local profile = createDefaultProfile()
	if type(raw) ~= "table" then
		return profile
	end

	if type(raw.IsCharacterCreated) == "boolean" then
		profile.IsCharacterCreated = raw.IsCharacterCreated
	end
	if raw.Gender == "Female" or raw.Gender == "Male" then
		profile.Gender = raw.Gender
	end
	if type(raw.RaceId) == "string" then
		profile.RaceId = raw.RaceId
	end
	if type(raw.CurrentClassId) == "string" then
		profile.CurrentClassId = normalizeClassId(raw.CurrentClassId)
	end
	if type(raw.Cash) == "number" then
		profile.Cash = math.max(0, math.floor(raw.Cash))
	end
	if type(raw.TrashTokens) == "number" then
		profile.TrashTokens = math.max(0, math.floor(raw.TrashTokens))
	end
	if type(raw.HasWeapon) == "boolean" then
		profile.HasWeapon = raw.HasWeapon
	end
	if type(raw.WeaponEnchant) == "number" then
		profile.WeaponEnchant = math.clamp(math.floor(raw.WeaponEnchant), 0, GameConstants.MAX_ENCHANT_LEVEL)
	end
	if type(raw.EnergyShots) == "number" then
		profile.EnergyShots = math.max(0, math.floor(raw.EnergyShots))
	end
	if type(raw.AutoSoulshot) == "boolean" then
		profile.AutoSoulshot = raw.AutoSoulshot
	end
	if type(raw.EnchantScrolls) == "number" then
		profile.EnchantScrolls = math.max(0, math.floor(raw.EnchantScrolls))
	end
	if type(raw.CrystalShards) == "number" then
		profile.CrystalShards = math.max(0, math.floor(raw.CrystalShards))
	end
	if type(raw.HpPotions) == "number" then
		profile.HpPotions = math.max(0, math.floor(raw.HpPotions))
	end
	if type(raw.MpPotions) == "number" then
		profile.MpPotions = math.max(0, math.floor(raw.MpPotions))
	end
	if type(raw.Karma) == "number" then
		profile.Karma = math.max(0, math.floor(raw.Karma))
	end
	if type(raw.PvpKills) == "number" then
		profile.PvpKills = math.max(0, math.floor(raw.PvpKills))
	end
	if type(raw.PkKills) == "number" then
		profile.PkKills = math.max(0, math.floor(raw.PkKills))
	end

	if type(raw.EquippedItems) == "table" then
		local rawEq = raw.EquippedItems
		local sanitizedEq: EquippedItemsMap = {
			Weapon = nil,
			Chest = nil,
			Legs = nil,
			Boots = nil,
			Accessory1 = nil,
			Accessory2 = nil,
		}
		local sanitizedMap = sanitizedEq :: { [string]: string? }
		for _, slotName in ipairs(ItemsConfig.EQUIPMENT_SLOTS) do
			local candidateId = rawEq[slotName]
			if type(candidateId) == "string" then
				local itemData = ItemsConfig.GetItem(candidateId)
				if itemData and itemData.slot == slotName then
					sanitizedMap[slotName] = candidateId
				end
			end
		end
		profile.EquippedItems = sanitizedEq
		profile.HasWeapon = (profile.EquippedItems.Weapon ~= nil)
	else
		-- Backward compatibility for profiles saved before Phase 3.5
		if not profile.HasWeapon then
			profile.EquippedItems.Weapon = nil
		end
	end

	if type(raw.InventoryBag) == "table" then
		local bag: { string } = {}
		for _, itemId in ipairs(raw.InventoryBag) do
			if type(itemId) == "string" and ItemsConfig.GetItem(itemId) ~= nil then
				if #bag < ItemsConfig.MAX_BAG_SLOTS then
					table.insert(bag, itemId)
				end
			end
		end
		profile.InventoryBag = bag
	end

	if type(raw.UnlockedClasses) == "table" then
		for k, v in pairs(raw.UnlockedClasses) do
			if type(k) == "string" and v == true then
				profile.UnlockedClasses[normalizeClassId(k)] = true
			end
		end
	end

	if type(raw.ClassProgress) == "table" then
		for classId, entry in pairs(raw.ClassProgress) do
			if type(classId) == "string" and type(entry) == "table" then
				local normId = normalizeClassId(classId)
				local lv = math.clamp(math.floor(tonumber(entry.Level) or 1), 1, GameConstants.MAX_LEVEL)
				local exp = math.max(0, math.floor(tonumber(entry.Exp) or 0))
				local hp = math.max(1, math.floor(tonumber(entry.HP) or 180))
				local mp = math.max(0, math.floor(tonumber(entry.MP) or 100))
				profile.ClassProgress[normId] = {
					Level = lv,
					Exp = exp,
					HP = hp,
					MP = mp,
				}
			end
		end
	end

	if type(raw.BossKills) == "table" then
		profile.BossKills.PlatformBaron = math.max(0, math.floor(tonumber(raw.BossKills.PlatformBaron) or 0))
		profile.BossKills.BlackFridayGolem = math.max(0, math.floor(tonumber(raw.BossKills.BlackFridayGolem) or 0))
		profile.BossKills.NightclubKing = math.max(0, math.floor(tonumber(raw.BossKills.NightclubKing) or 0))
		profile.BossKills.InflationArchitect = math.max(0, math.floor(tonumber(raw.BossKills.InflationArchitect) or 0))
	end

	if profile.IsCharacterCreated and not profile.UnlockedClasses[profile.CurrentClassId] then
		profile.UnlockedClasses[profile.CurrentClassId] = true
	end

	return profile
end

local function getPlayerKey(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

function DataManager.LoadProfile(player: Player): PlayerProfile
	if activeProfiles[player] then
		return activeProfiles[player]
	end

	local key = getPlayerKey(player)
	local loadedRaw: any = nil

	local store = getStore()
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok and result ~= nil then
			loadedRaw = result
		end
	end

	if loadedRaw == nil and memoryFallbackStore[key] ~= nil then
		loadedRaw = deepCopyProfile(memoryFallbackStore[key])
	end

	local profile = sanitizeLoadedProfile(loadedRaw)
	activeProfiles[player] = profile
	memoryFallbackStore[key] = deepCopyProfile(profile)
	return profile
end

function DataManager.GetProfile(player: Player): PlayerProfile
	return activeProfiles[player] or DataManager.LoadProfile(player)
end

function DataManager.SaveProfile(player: Player)
	local profile = activeProfiles[player]
	if not profile then
		return
	end

	local key = getPlayerKey(player)
	local snapshot = deepCopyProfile(profile)
	memoryFallbackStore[key] = snapshot

	local store = getStore()
	if store then
		pcall(function()
			store:SetAsync(key, snapshot)
		end)
	end
end

function DataManager.ResetProfile(player: Player): PlayerProfile
	local fresh = createDefaultProfile()
	activeProfiles[player] = fresh
	DataManager.SaveProfile(player)
	return fresh
end

function DataManager.GetMaxReachedLevel(player: Player): number
	local profile = DataManager.GetProfile(player)
	local maxLv = 1
	for _, entry in pairs(profile.ClassProgress) do
		if entry.Level > maxLv then
			maxLv = entry.Level
		end
	end
	return maxLv
end

function DataManager.GetBossKillCount(player: Player, bossId: string): number
	local profile = DataManager.GetProfile(player)
	local killsTable = profile.BossKills :: any
	return (killsTable[bossId] :: number?) or 0
end

function DataManager.IncrementBossKill(player: Player, bossId: string): number
	local profile = DataManager.GetProfile(player)
	local killsTable = profile.BossKills :: any
	local current = (killsTable[bossId] :: number?) or 0
	local updated = current + 1
	killsTable[bossId] = updated
	return updated
end

function DataManager.AreSubclassRequirementsMet(player: Player): boolean
	local maxLv = DataManager.GetMaxReachedLevel(player)
	if maxLv < GameConstants.SUBCLASS_REQUIRED_LEVEL then
		return false
	end

	for _, bossReq in ipairs(GameConstants.SUBCLASS_REQUIRED_BOSSES) do
		local kills = DataManager.GetBossKillCount(player, bossReq.id)
		if kills < bossReq.requiredKills then
			return false
		end
	end

	return true
end

function DataManager.Init()
	if initialized then
		return
	end
	initialized = true

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			DataManager.LoadProfile(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		DataManager.SaveProfile(player)
		activeProfiles[player] = nil
	end)

	game:BindToClose(function()
		for player, _ in pairs(activeProfiles) do
			DataManager.SaveProfile(player)
		end
	end)
end

return DataManager
