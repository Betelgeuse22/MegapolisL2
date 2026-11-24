--!strict

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local I18nFolder = Shared:WaitForChild("i18n")

local I18n = require(I18nFolder:WaitForChild("I18n"))
local MobsConfig = require(Configs:WaitForChild("MobsConfig"))

local VFXController = require(script.Parent:WaitForChild("VFXController"))
local TargetController = require(script.Parent:WaitForChild("TargetController"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))
local UIController = require(script.Parent:WaitForChild("UIController"))
local NPCController = require(script.Parent:WaitForChild("NPCController"))
local UBahnController = require(script.Parent:WaitForChild("UBahnController"))

local sysOk, sysLocale = pcall(function(): string
	return LocalizationService.SystemLocaleId
end)
local rbxOk, rbxLocale = pcall(function(): string
	return LocalizationService.RobloxLocaleId
end)

local systemLocaleId = if sysOk and type(sysLocale) == "string" then sysLocale else "unknown"
local robloxLocaleId = if rbxOk and type(rbxLocale) == "string" then rbxLocale else "unknown"

print("=== [MegapolisL2 Client Initialization] ===")
print(string.format("SystemLocaleId: %s | RobloxLocaleId: %s", systemLocaleId, robloxLocaleId))

local detectedLang = I18n.GetLanguage()
print(I18n.t("UI_WELCOME", { lang = string.upper(detectedLang) }))

local sortedMobs: { MobsConfig.MobData } = {}
for _, mobData in pairs(MobsConfig) do
	table.insert(sortedMobs, mobData)
end
table.sort(sortedMobs, function(a: MobsConfig.MobData, b: MobsConfig.MobData): boolean
	return a.level < b.level
end)

print(string.format("--- Tier 1 Mobs (%s) ---", string.upper(detectedLang)))
for _, mob in ipairs(sortedMobs) do
	local localizedName = I18n.t(mob.nameKey)
	local localizedLevel = I18n.t("UI_LEVEL", { lv = mob.level })
	local localizedLocation = I18n.t(mob.locationId)
	local bossTag = if mob.isRaidBoss then " [RAID BOSS]" else ""

	print(string.format("%s (%s)%s - %s", localizedName, localizedLevel, bossTag, localizedLocation))
end

-- Initialize Phase 1 & Phase 2 Client Controllers
VFXController.Init()
TargetController.Init()
CombatController.Init()
UIController.Init()
NPCController.Init()
UBahnController.Init()

print("=== [MegapolisL2 Client Phase 0, Phase 1 & Phase 2 Initialized] ===")
