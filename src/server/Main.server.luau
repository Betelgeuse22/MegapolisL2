--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local I18nFolder = Shared:WaitForChild("i18n")

local GameConstants = require(Configs:WaitForChild("GameConstants"))
local MobsConfig = require(Configs:WaitForChild("MobsConfig"))
local I18n = require(I18nFolder:WaitForChild("I18n"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local WorldBuilderService = require(script.Parent:WaitForChild("WorldBuilderService"))
local MobSpawnerService = require(script.Parent:WaitForChild("MobSpawnerService"))
local PartyService = require(script.Parent:WaitForChild("PartyService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local SkillService = require(script.Parent:WaitForChild("SkillService"))
local UBahnService = require(script.Parent:WaitForChild("UBahnService"))
local GuardService = require(script.Parent:WaitForChild("GuardService"))

print("=== [MegapolisL2 Server Self-Test] ===")
print(string.format("Remotes initialized inside ReplicatedStorage.%s", Remotes.Folder.Name))

-- 1. Level Penalty self-test for Lv.1 player attacking Lv.1, Lv.5, Lv.6, Lv.8, and Lv.11 mobs
local attackerLevel = 1
local testTargetLevels = { 1, 5, 6, 8, 11 }

print("--- Level Penalty Self-Test (Attacker Lv.1) ---")
for _, targetLevel in ipairs(testTargetLevels) do
	local multiplier = GameConstants.CalculateLevelPenalty(attackerLevel, targetLevel)
	print(
		string.format(
			"Attacker Lv.%d -> Target Lv.%d (diff %+d): Multiplier = %.2f (%.0f%%)",
			attackerLevel,
			targetLevel,
			targetLevel - attackerLevel,
			multiplier,
			multiplier * 100
		)
	)
end

-- 2. Phase 2.5 Exponential MMORPG EXP Curve self-test
print("--- Exponential MMORPG EXP Curve (Lv 1, 10, 20, 30, 40, 50) ---")
for _, lv in ipairs({ 1, 10, 20, 30, 40, 50 }) do
	print(string.format("Lv.%d -> Required EXP = %d", lv, GameConstants.GetRequiredExp(lv)))
end

-- Sort Tier 1 mobs by level for clean console output
local sortedMobs: { MobsConfig.MobData } = {}
for _, mobData in pairs(MobsConfig) do
	table.insert(sortedMobs, mobData)
end
table.sort(sortedMobs, function(a: MobsConfig.MobData, b: MobsConfig.MobData): boolean
	return a.level < b.level
end)

-- 3. List all Tier 1 mobs in both EN and RU
print("--- Tier 1 Mobs (EN / RU) ---")
for _, mob in ipairs(sortedMobs) do
	local nameEn = I18n.t(mob.nameKey, nil, "en")
	local nameRu = I18n.t(mob.nameKey, nil, "ru")
	local lvEn = I18n.t("UI_LEVEL", { lv = mob.level }, "en")
	local lvRu = I18n.t("UI_LEVEL", { lv = mob.level }, "ru")
	local locEn = I18n.t(mob.locationId, nil, "en")
	local locRu = I18n.t(mob.locationId, nil, "en")
	locRu = I18n.t(mob.locationId, nil, "ru")
	local bossTag = if mob.isRaidBoss then " [RAID BOSS]" else ""

	print(
		string.format(
			"[%s]%s | EN: %s (%s) @ %s | RU: %s (%s) @ %s | HP: %d, P.Def: %d, M.Def: %d, ATK: %d",
			mob.id,
			bossTag,
			nameEn,
			lvEn,
			locEn,
			nameRu,
			lvRu,
			locRu,
			mob.maxHp,
			mob.pDef,
			mob.mDef,
			mob.atk
		)
	)
end

-- 4. Initialize Phase 0, 1, 2, 3, 3.5, 4A, 4B & Phase 4C Server Services
DataManager.Init()
WorldBuilderService.Init()
MobSpawnerService.Init()
PartyService.Init()
CombatService.Init()
SkillService.Init()
UBahnService.Init()
GuardService.Init()

print("=== [MegapolisL2 Server Phase 4C (Party System, AI Companions, PvP & PK Karma) Initialized] ===")
