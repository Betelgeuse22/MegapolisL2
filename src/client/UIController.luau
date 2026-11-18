--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local I18nFolder = Shared:WaitForChild("i18n")

local GameConstants = require(Configs:WaitForChild("GameConstants"))
local ItemsConfig = require(Configs:WaitForChild("ItemsConfig"))
local ClassesConfig = require(Configs:WaitForChild("ClassesConfig"))
local RacesConfig = require(Configs:WaitForChild("RacesConfig"))
local SkillsConfig = require(Configs:WaitForChild("SkillsConfig"))
local I18n = require(I18nFolder:WaitForChild("I18n"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TargetController = require(script.Parent:WaitForChild("TargetController"))
local CombatController = require(script.Parent:WaitForChild("CombatController"))

local localPlayer = Players.LocalPlayer

local UIController = {}

local L2_BG_COLOR = Color3.fromRGB(16, 19, 27)
local L2_PANEL_COLOR = Color3.fromRGB(22, 26, 36)
local L2_GOLD_BORDER = Color3.fromRGB(175, 145, 85)
local L2_SUB_BORDER = Color3.fromRGB(95, 82, 55)

local RADAR_WORLD_RADIUS = 85

local playerState = {
	level = 1,
	exp = 0,
	maxExp = GameConstants.GetRequiredExp(1),
	cash = 0,
	hp = 180,
	maxHp = 180,
	mp = 100,
	maxMp = 100,
	raceId = "RACE_LAW",
	classId = "RiotPolice",
	trashTokens = 0,
	initialized = false,
}

type SavedClassProgressClient = {
	Level: number,
	Exp: number,
	HP: number,
	MP: number,
}

type ClientProfileData = {
	IsCharacterCreated: boolean,
	Gender: string,
	RaceId: string,
	CurrentClassId: string,
	UnlockedClasses: { [string]: boolean },
	ClassProgress: { [string]: SavedClassProgressClient },
	BossKills: {
		PlatformBaron: number,
		BlackFridayGolem: number,
		NightclubKing: number,
		InflationArchitect: number,
	},
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
	EquippedItems: {
		Weapon: string?,
		Chest: string?,
		Legs: string?,
		Boots: string?,
		Accessory1: string?,
		Accessory2: string?,
	},
	InventoryBag: { string },
	Karma: number,
	PvpKills: number,
	PkKills: number,
}

local clientProfile: ClientProfileData = {
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

local selectedCreationRace: RacesConfig.RaceId = "RACE_LAW"
local selectedCreationClass: string = "RiotPolice"
local selectedCreationGender: string = "Male"

type HotbarSlotKey = "1" | "Q" | "E" | "R" | "F"

type HotbarSlotUI = {
	slot: HotbarSlotKey,
	button: TextButton,
	nameLabel: TextLabel,
	mpLabel: TextLabel,
	cooldownOverlay: Frame,
	cooldownText: TextLabel,
}

local HOTBAR_SLOT_KEYS: { HotbarSlotKey } = { "1", "Q", "E", "R", "F" }
local PLAYABLE_CLASS_IDS = {
	"RiotPolice",
	"Paramedic",
	"SubwayRocker",
	"UnionBoss",
	"RecycleHunter",
	"StreetfoodCrafter",
	"HellsSousChef",
	"ExpressCourier",
	"HeavyBouncer",
	"ParkingInspector",
	"HeavyBuilder",
	"FullstackCyberMage",
	"UrbanAlchemist",
	"DroneOperator",
}
local RACE_IDS: { RacesConfig.RaceId } = {
	"RACE_LAW",
	"RACE_STREET",
	"RACE_CORP",
	"RACE_WORKER",
	"RACE_NIGHT",
}

local CLASS_SKILL_SLOTS_ORDER = { "Q", "E", "R", "F" }

-- 2. Top-Left Player Status Frame Elements
local hudLevelBadge: TextLabel
local hudPlayerNameLabel: TextLabel
local hudClassRaceSubtitle: TextLabel
local hudHpFill: Frame
local hudHpText: TextLabel
local hudMpFill: Frame
local hudMpText: TextLabel
local hudExpFill: Frame
local hudExpText: TextLabel
local hudZoneBadgeFrame: Frame
local hudZoneBadgeStroke: UIStroke
local hudZoneBadgeLabel: TextLabel

-- 2B. Left-Side Lineage 2 Party & PvP Elements (Grouped into 1 table to save top-level registers)
type PartyMemberItem = {
	name: string,
	classId: string,
	level: number,
	hp: number,
	maxHp: number,
	mp: number,
	maxMp: number,
	isLeader: boolean,
	isBot: boolean,
	model: Model?,
}

type PartyMemberRowUI = {
	button: TextButton,
	stroke: UIStroke,
	nameLabel: TextLabel,
	classLabel: TextLabel,
	hpFill: Frame,
	hpText: TextLabel,
	mpFill: Frame,
}

local partyPvpUI = {
	hudPvpKarmaBadge = nil :: any,
	partyWindowFrame = nil :: any,
	partyHeaderLabel = nil :: any,
	partyLeaveBtn = nil :: any,
	partyRows = {} :: { PartyMemberRowUI },
	partyMembersState = {} :: { PartyMemberItem },
	partyInvitePopupFrame = nil :: any,
	partyInviteLabel = nil :: any,
	partyInviteAcceptBtn = nil :: any,
	partyInviteDeclineBtn = nil :: any,
	targetPartyInviteBtn = nil :: any,
	pvpForceButton = nil :: any,
	pvpForceStroke = nil :: any,
	pvpForceLabel = nil :: any,
}

-- 3. Top-Center Target Status Frame Elements
local targetFrame: Frame
local targetNameLabel: TextLabel
local targetStatusTag: TextLabel
local targetHpFill: Frame
local targetHpValueLabel: TextLabel
local targetMpFill: Frame
local targetMpValueLabel: TextLabel

-- 4. Top-Right Minimap / Radar Elements
local minimapLocationLabel: TextLabel
local minimapCanvas: Frame
local minimapCoordsLabel: TextLabel
local radarDotsByMob: { [Model]: Frame } = {}

-- 5. Bottom-Left Lineage 2 Chat & System Combat Log Elements
local chatScrollFrame: ScrollingFrame
local chatListLayout: UIListLayout
local chatInputBox: TextBox
local chatLogCount = 0

-- 6. Bottom-Center Skill Hotbar & Soulshot Slot [Z] + Potion Slots [2][3] + Floating Tooltip
local hotbarSlots: { HotbarSlotUI } = {}
local soulshotButton: TextButton
local soulshotStroke: UIStroke
local soulshotStatusBadge: TextLabel
local soulshotTitleLabel: TextLabel
local soulshotCountLabel: TextLabel
local hpPotionButton: TextButton
local hpPotionTitleLabel: TextLabel
local hpPotionCountLabel: TextLabel
local hpPotionCooldownOverlay: Frame
local hpPotionCooldownText: TextLabel
local mpPotionButton: TextButton
local mpPotionTitleLabel: TextLabel
local mpPotionCountLabel: TextLabel
local mpPotionCooldownOverlay: Frame
local mpPotionCooldownText: TextLabel
local hpPotionReadyAt = 0
local mpPotionReadyAt = 0
local hotbarTooltipFrame: Frame
local tooltipTitleLabel: TextLabel
local tooltipStatsLabel: TextLabel
local tooltipDescLabel: TextLabel
local hoveredHotbarSlot: string? = nil

-- 7. Bottom-Right Menu Buttons & Modals
local btnInventory: TextButton
local btnJob: TextButton
local btnStats: TextButton
local btnLang: TextButton

type PaperdollSlotCellUI = {
	slotName: string,
	emptyGlyph: string,
	button: TextButton,
	gradient: UIGradient,
	stroke: UIStroke,
	glyphLabel: TextLabel,
	topLeftBadge: TextLabel,
	topRightBadge: TextLabel,
}

type BagGridEntry = {
	kind: "Stackable" | "Equipment" | "Quest",
	id: string,
	bagIndex: number?,
	quantity: number?,
	titleText: string,
	metaText: string,
	bonusesText: string,
	descText: string,
	grade: string?,
	sellPrice: number?,
}

type BagGridCellUI = {
	cellIndex: number,
	button: TextButton,
	gradient: UIGradient,
	stroke: UIStroke,
	glyphLabel: TextLabel,
	topLeftBadge: TextLabel,
	topRightBadge: TextLabel,
	bottomRightBadge: TextLabel,
}

local TOTAL_L2_GRID_SLOTS = 54

local inventoryModal: Frame
local inventoryTitleLabel: TextLabel
local inventoryCloseBtn: TextButton
local paperdollCells: { [string]: PaperdollSlotCellUI } = {}
local invGearBonusesSummaryLabel: TextLabel
local invTabDefaultBtn: TextButton
local invTabQuestBtn: TextButton
local invTabWorkshopBtn: TextButton
local invSlotCounterLabel: TextLabel
local bagGridContainer: Frame
local workshopTabContainer: Frame
local bagGridCells: { BagGridCellUI } = {}
local currentGridEntries: { [number]: BagGridEntry } = {}
local activeInventoryTab: "Default" | "Quest" | "Workshop" = "Default"
local selectedGridCellIndex: number? = nil
local lastClickedCellIndex: number? = nil
local lastClickedCellTime = 0

local invSelectedItemLabel: TextLabel
local invActionEquipBtn: TextButton
local invActionSellBtn: TextButton
local invAdenaLabel: TextLabel

local itemTooltipFrame: Frame
local itemTooltipTitleLabel: TextLabel
local itemTooltipMetaLabel: TextLabel
local itemTooltipBonusesLabel: TextLabel
local itemTooltipDescLabel: TextLabel
local hoveredTooltipData: {
	title: string,
	titleColor: Color3,
	meta: string,
	bonuses: string,
	desc: string,
}? = nil

-- Grouped Workshop, Enchant, Stats, Job & Character Creation UI state (saves 50+ top-level registers)
local workshopUI = {
	invShopHeaderLabel = nil :: any,
	shopBuyShotsBtn = nil :: any,
	shopBuyScrollCashBtn = nil :: any,
	shopTradeScrollTokensBtn = nil :: any,
	shopBuyHpPotionsBtn = nil :: any,
	shopBuyMpPotionsBtn = nil :: any,
	shopBuyNewWeaponBtn = nil :: any,
	invEnchantHeaderLabel = nil :: any,
	enchantWeaponCard = nil :: any,
	enchantWeaponCardStroke = nil :: any,
	enchantWeaponNameLabel = nil :: any,
	enchantAtkBonusLabel = nil :: any,
	enchantNextChanceLabel = nil :: any,
	enchantFeedbackLabel = nil :: any,
	enchantWeaponBtn = nil :: any,
	lastEnchantFeedbackText = nil :: string?,
	lastEnchantFeedbackColor = nil :: Color3?,
	statsModal = nil :: any,
	statsTitleLabel = nil :: any,
	statsCloseBtn = nil :: any,
	statsContentLabel = nil :: any,
	-- Multi-Window Focus, Dragging & Item Drag-and-Drop State
	MobsConfig = require(Configs:WaitForChild("MobsConfig")) :: { [string]: any },
	windowFocusOrder = {} :: { Frame },
	bringWindowToFront = nil :: ((targetModal: Frame) -> ())?,
	draggingWindow = nil :: Frame?,
	windowDragStartMouse = Vector2.zero,
	windowDragStartPos = Vector2.zero,
	leftPaperdollPanel = nil :: Frame?,
	dragGhostFrame = nil :: Frame?,
	dragGhostGrad = nil :: UIGradient?,
	dragGhostStroke = nil :: UIStroke?,
	dragGhostGlyph = nil :: TextLabel?,
	dragGhostGrade = nil :: TextLabel?,
	draggedCellIndex = nil :: number?,
	dragStartMousePos = Vector2.zero,
	isDraggingItem = false,
}

local jobUI = {
	jobModalFrame = nil :: any,
	jobModalTitle = nil :: any,
	jobCloseBtn = nil :: any,
	jobLockedRaceBanner = nil :: any,
	jobDossierHeaderLabel = nil :: any,
	jobDossierHintLabel = nil :: any,
	jobLevelChecklistLabel = nil :: any,
	jobBossChecklistLabels = {} :: { [string]: TextLabel },
	classButtons = {} :: { [string]: TextButton },
	jobClassSkillsHeaderLabel = nil :: any,
	jobClassSkillsValueLabel = nil :: any,
	previewedJobClassId = "RiotPolice",
}

local creationUI = {
	charCreationScreen = nil :: any,
	charCreateTitleLabel = nil :: any,
	charCreateSubtitleLabel = nil :: any,
	charCreateLangBtn = nil :: any,
	charRaceHeaderLabel = nil :: any,
	charClassHeaderLabel = nil :: any,
	charGenderHeaderLabel = nil :: any,
	creationMaleBtn = nil :: any,
	creationFemaleBtn = nil :: any,
	charRacePassiveHeaderLabel = nil :: any,
	charRacePassiveValueLabel = nil :: any,
	charClassSkillsHeaderLabel = nil :: any,
	charClassSkillsValueLabel = nil :: any,
	charCreateConfirmBtn = nil :: any,
	creationRaceButtons = {} :: { [string]: TextButton },
	creationClassButtons = {} :: { [string]: TextButton },
}

local targetHpSignalConn: RBXScriptConnection? = nil
local targetSpoilSignalConn: RBXScriptConnection? = nil
local targetStunSignalConn: RBXScriptConnection? = nil
local initialized = false

local function disableDefaultRobloxChat()
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
			end)
			if ok then
				break
			end
			task.wait(0.25)
		end
	end)
end

local function styleL2Frame(frame: GuiObject, cornerRadius: number, borderColor: Color3, borderThickness: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, cornerRadius)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = borderColor
	stroke.Thickness = borderThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

local function getMaxReachedLevelFromProfile(): number
	local maxLv = playerState.level
	for _, entry in pairs(clientProfile.ClassProgress) do
		if entry.Level > maxLv then
			maxLv = entry.Level
		end
	end
	return maxLv
end

local function getBossKillsForId(bossId: string): number
	local killsMap = clientProfile.BossKills :: any
	return (killsMap[bossId] :: number?) or 0
end

local function areAllSubclassConditionsMet(): boolean
	if getMaxReachedLevelFromProfile() < GameConstants.SUBCLASS_REQUIRED_LEVEL then
		return false
	end
	for _, bossReq in ipairs(GameConstants.SUBCLASS_REQUIRED_BOSSES) do
		if getBossKillsForId(bossReq.id) < bossReq.requiredKills then
			return false
		end
	end
	return true
end

local function formatRacePassiveText(raceId: RacesConfig.RaceId): string
	local r = RacesConfig[raceId] or RacesConfig.RACE_LAW
	return I18n.t("UI_PASSIVE_FORMAT", {
		hp = math.floor(r.hpMult * 100 + 0.5),
		atkSpd = math.floor(r.atkSpdMult * 100 + 0.5),
		crit = math.floor(r.critMult * 100 + 0.5),
		move = math.floor(r.moveSpeedMult * 100 + 0.5),
		stun = math.floor(r.stunResist * 100 + 0.5),
	})
end

local function formatClassSkillPreviewText(classId: string): string
	local cData = ClassesConfig[classId] or ClassesConfig.RiotPolice
	local headerLine = I18n.t("UI_ROLE_FORMAT", {
		role = cData.role,
		weapon = cData.weaponType,
		hp = cData.baseHpBonus,
		pdef = cData.basePDef,
	})

	local lines = { headerLine, "" }
	for _, slotKey in ipairs(CLASS_SKILL_SLOTS_ORDER) do
		local skillId = cData.skillSlots[slotKey]
		local sData = if skillId then SkillsConfig[skillId] else nil
		if sData then
			local sName = I18n.t(sData.nameKey)
			local sDesc = I18n.t(sData.descKey)
			table.insert(lines, string.format("[%s] %s — %s", slotKey, sName, sDesc))
		end
	end

	return table.concat(lines, "\n")
end

function UIController.AddSystemLog(message: string, color: Color3)
	if not chatScrollFrame then
		return
	end

	chatLogCount += 1
	local entry = Instance.new("TextLabel")
	entry.Name = "LogEntry_" .. tostring(chatLogCount)
	entry.LayoutOrder = chatLogCount
	entry.Size = UDim2.new(1, -8, 0, 0)
	entry.AutomaticSize = Enum.AutomaticSize.Y
	entry.BackgroundTransparency = 1
	entry.Font = Enum.Font.GothamMedium
	entry.TextSize = 12
	entry.TextWrapped = true
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.TextYAlignment = Enum.TextYAlignment.Top
	entry.TextColor3 = color
	entry.TextStrokeColor3 = Color3.fromRGB(6, 8, 12)
	entry.TextStrokeTransparency = 0.25
	entry.Text = message
	entry.Parent = chatScrollFrame

	local children = chatScrollFrame:GetChildren()
	if #children > 65 then
		for _, child in ipairs(children) do
			if child:IsA("TextLabel") then
				child:Destroy()
				break
			end
		end
	end

	task.defer(function()
		if chatScrollFrame and chatListLayout then
			chatScrollFrame.CanvasSize = UDim2.fromOffset(0, chatListLayout.AbsoluteContentSize.Y + 8)
			chatScrollFrame.CanvasPosition = Vector2.new(0, math.max(0, chatListLayout.AbsoluteContentSize.Y))
		end
	end)
end

local function getTargetNameColor(mobLevel: number, playerLevel: number): Color3
	local diff = mobLevel - playerLevel
	if diff <= 2 then
		return Color3.fromRGB(220, 255, 220)
	elseif diff == 3 or diff == 4 then
		return Color3.fromRGB(255, 230, 80)
	elseif diff >= 5 and diff <= 8 then
		return Color3.fromRGB(255, 110, 180)
	else
		return Color3.fromRGB(255, 45, 45)
	end
end

local function getPlayerNameStatusInfo(): (string, Color3, number, number, number)
	local karma = (localPlayer:GetAttribute("Karma") :: number?) or clientProfile.Karma or 0
	local pvpKills = (localPlayer:GetAttribute("PvpKills") :: number?) or clientProfile.PvpKills or 0
	local pkKills = (localPlayer:GetAttribute("PkKills") :: number?) or clientProfile.PkKills or 0
	local isFlagged = (localPlayer:GetAttribute("IsPvpFlagged") == true)

	if karma > 0 then
		return I18n.t("UI_NAME_RED", { karma = karma }), Color3.fromRGB(255, 35, 35), karma, pvpKills, pkKills
	elseif isFlagged then
		return I18n.t("UI_NAME_PURPLE"), Color3.fromRGB(185, 85, 255), karma, pvpKills, pkKills
	else
		return I18n.t("UI_NAME_WHITE"), Color3.fromRGB(245, 240, 225), karma, pvpKills, pkKills
	end
end

local function refreshTargetFrame()
	local target = TargetController.GetTarget()
	if not target or not target.Parent then
		targetFrame.Visible = false
		return
	end

	targetFrame.Visible = true

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local isPartyBot = target:GetAttribute("IsPartyBot") == true
	local isPvpTarget = target:GetAttribute("IsPvpTarget") == true or (targetPlayer ~= nil and targetPlayer ~= localPlayer)

	local mobLevel = (target:GetAttribute("Level") :: number?)
		or (if targetPlayer then ((targetPlayer:GetAttribute("Level") :: number?) or 1) else 1)

	local currentHp = 0
	local maxHp = 1
	if targetPlayer then
		local hum = target:FindFirstChildOfClass("Humanoid")
		currentHp = if hum then math.max(0, math.floor(hum.Health + 0.5)) else 0
		maxHp = if hum then math.max(1, math.floor(hum.MaxHealth + 0.5)) else 1
	else
		currentHp = math.max(0, (target:GetAttribute("CurrentHP") :: number?) or 0)
		maxHp = math.max(1, (target:GetAttribute("MaxHP") :: number?) or 1)
	end

	local isSpoiled = target:GetAttribute("IsSpoiled") == true or target:GetAttribute("CanSweep") == true
	local isStunned = target:GetAttribute("IsStunned") == true

	local displayName: string
	if targetPlayer then
		displayName = targetPlayer.DisplayName
	elseif target:GetAttribute("BotDisplayName") then
		displayName = tostring(target:GetAttribute("BotDisplayName"))
	else
		local nameKey = (target:GetAttribute("NameKey") :: string?) or target.Name
		displayName = I18n.t(nameKey)
	end

	local localizedLevel = I18n.t("UI_LEVEL", { lv = mobLevel })
	targetNameLabel.Text = string.format("%s  •  %s", displayName, localizedLevel)

	local targetKarma = (target:GetAttribute("Karma") :: number?)
		or (if targetPlayer then ((targetPlayer:GetAttribute("Karma") :: number?) or 0) else 0)
	local targetFlagged = (target:GetAttribute("IsPvpFlagged") == true)
		or (if targetPlayer then (targetPlayer:GetAttribute("IsPvpFlagged") == true) else false)

	if isPartyBot then
		targetNameLabel.TextColor3 = Color3.fromRGB(115, 225, 255)
	elseif isPvpTarget then
		if targetKarma > 0 then
			targetNameLabel.TextColor3 = Color3.fromRGB(255, 35, 35)
		elseif targetFlagged then
			targetNameLabel.TextColor3 = Color3.fromRGB(185, 85, 255)
		else
			targetNameLabel.TextColor3 = Color3.fromRGB(245, 245, 255)
		end
	else
		targetNameLabel.TextColor3 = getTargetNameColor(mobLevel, playerState.level)
	end

	local isMob = (target:GetAttribute("IsMob") == true)
		or (target:GetAttribute("MobId") ~= nil)
		or (workshopUI.MobsConfig[target.Name] ~= nil)
	local canInviteTarget = (not isMob)
		and ((targetPlayer ~= nil and targetPlayer ~= localPlayer) or isPvpTarget or isPartyBot)

	if partyPvpUI.targetPartyInviteBtn then
		if canInviteTarget then
			partyPvpUI.targetPartyInviteBtn.Visible = true
			partyPvpUI.targetPartyInviteBtn.Text = I18n.t("UI_PARTY_INVITE_BTN")
			targetFrame.Size = UDim2.fromOffset(320, 98)
		else
			partyPvpUI.targetPartyInviteBtn.Visible = false
			targetFrame.Size = UDim2.fromOffset(320, 76)
		end
	end

	if isStunned then
		targetStatusTag.Visible = true
		targetStatusTag.Text = "★ " .. I18n.t("UI_STUNNED")
		targetStatusTag.TextColor3 = Color3.fromRGB(255, 230, 65)
	elseif isSpoiled then
		targetStatusTag.Visible = true
		targetStatusTag.Text = "◆ " .. I18n.t("MSG_SPOIL_SUCCESS")
		targetStatusTag.TextColor3 = Color3.fromRGB(0, 235, 255)
	elseif isPvpTarget and targetKarma > 0 then
		targetStatusTag.Visible = true
		targetStatusTag.Text = "☠ PK (" .. tostring(targetKarma) .. ")"
		targetStatusTag.TextColor3 = Color3.fromRGB(255, 55, 55)
	elseif isPvpTarget and targetFlagged then
		targetStatusTag.Visible = true
		targetStatusTag.Text = "⚔ PvP FLAG"
		targetStatusTag.TextColor3 = Color3.fromRGB(205, 115, 255)
	else
		targetStatusTag.Visible = false
	end

	local hpRatio = math.clamp(currentHp / maxHp, 0, 1)
	TweenService:Create(
		targetHpFill,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(hpRatio, 1) }
	):Play()
	targetHpValueLabel.Text = string.format("%d / %d (%.0f%%)", currentHp, maxHp, hpRatio * 100)

	local maxMp = (target:GetAttribute("MaxMP") :: number?) or (mobLevel * 40 + 60)
	local currentMp = (target:GetAttribute("MP") :: number?) or (if currentHp > 0 then maxMp else 0)
	local mpRatio = if maxMp > 0 then math.clamp(currentMp / maxMp, 0, 1) else 0
	targetMpFill.Size = UDim2.fromScale(mpRatio, 1)
	targetMpValueLabel.Text = string.format("%s: %d / %d", I18n.t("UI_MP"), currentMp, maxMp)
end

local function getEnchantTierColor(enchantLv: number): Color3
	if enchantLv <= 3 then
		return Color3.fromRGB(235, 240, 250)
	elseif enchantLv <= 6 then
		return Color3.fromRGB(220, 240, 255)
	elseif enchantLv <= 9 then
		return Color3.fromRGB(65, 185, 255)
	elseif enchantLv <= 15 then
		return Color3.fromRGB(255, 155, 35)
	else
		return Color3.fromRGB(255, 45, 65)
	end
end

local function refreshSoulshotSlot()
	if not soulshotButton then
		return
	end
	soulshotTitleLabel.Text = I18n.t("UI_SOULSHOT_SLOT_TITLE")
	soulshotCountLabel.Text = "x" .. tostring(clientProfile.EnergyShots)

	local isActive = clientProfile.AutoSoulshot == true and clientProfile.EnergyShots > 0
	if clientProfile.AutoSoulshot then
		soulshotStatusBadge.Text = I18n.t("UI_SOULSHOT_AUTO_ON")
		soulshotStatusBadge.TextColor3 = if isActive
			then Color3.fromRGB(95, 255, 135)
			else Color3.fromRGB(255, 195, 85)
		soulshotButton.BackgroundColor3 = if isActive
			then Color3.fromRGB(24, 42, 38)
			else Color3.fromRGB(32, 28, 24)
		soulshotCountLabel.TextColor3 = if clientProfile.EnergyShots > 0
			then Color3.fromRGB(130, 245, 255)
			else Color3.fromRGB(255, 95, 95)
	else
		soulshotStatusBadge.Text = I18n.t("UI_SOULSHOT_AUTO_OFF")
		soulshotStatusBadge.TextColor3 = Color3.fromRGB(145, 150, 165)
		soulshotButton.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
		soulshotStroke.Color = Color3.fromRGB(75, 80, 92)
		soulshotCountLabel.TextColor3 = Color3.fromRGB(175, 185, 200)
	end
end

local function refreshPotionSlots()
	if hpPotionButton and hpPotionTitleLabel and hpPotionCountLabel then
		hpPotionTitleLabel.Text = I18n.t("UI_HP_POTION_SLOT_TITLE")
		hpPotionCountLabel.Text = "x" .. tostring(clientProfile.HpPotions)
		hpPotionCountLabel.TextColor3 = if clientProfile.HpPotions > 0
			then Color3.fromRGB(115, 255, 145)
			else Color3.fromRGB(255, 95, 95)
		hpPotionButton.BackgroundColor3 = if clientProfile.HpPotions > 0
			then Color3.fromRGB(42, 20, 26)
			else Color3.fromRGB(24, 20, 22)
	end

	if mpPotionButton and mpPotionTitleLabel and mpPotionCountLabel then
		mpPotionTitleLabel.Text = I18n.t("UI_MP_POTION_SLOT_TITLE")
		mpPotionCountLabel.Text = "x" .. tostring(clientProfile.MpPotions)
		mpPotionCountLabel.TextColor3 = if clientProfile.MpPotions > 0
			then Color3.fromRGB(110, 225, 255)
			else Color3.fromRGB(255, 95, 95)
		mpPotionButton.BackgroundColor3 = if clientProfile.MpPotions > 0
			then Color3.fromRGB(18, 30, 52)
			else Color3.fromRGB(20, 22, 28)
	end
end

local function refreshHotbarTooltip()
	if not hotbarTooltipFrame then
		return
	end
	if not hoveredHotbarSlot then
		hotbarTooltipFrame.Visible = false
		return
	end

	local slot = hoveredHotbarSlot
	if slot == "1" then
		tooltipTitleLabel.Text = string.format("[1] %s", I18n.t("UI_BASIC_ATTACK"))
		tooltipStatsLabel.Text = I18n.t("UI_TOOLTIP_STATS", {
			mp = 0,
			cd = "0.5",
			range = "7.5",
		})
		tooltipDescLabel.Text = I18n.t("UI_BASIC_ATTACK_DESC")
		hotbarTooltipFrame.Visible = true
	elseif slot == "Z" then
		local stateText = if clientProfile.AutoSoulshot
			then I18n.t("UI_SOULSHOT_AUTO_ON")
			else I18n.t("UI_SOULSHOT_AUTO_OFF")
		tooltipTitleLabel.Text = string.format("[Z] %s (%s)", I18n.t("UI_SOULSHOT_SLOT_TITLE"), stateText)
		tooltipStatsLabel.Text = I18n.t("UI_TOOLTIP_SOULSHOT_STATS", {
			count = clientProfile.EnergyShots,
		})
		tooltipDescLabel.Text = I18n.t("UI_SOULSHOT_DESC")
		hotbarTooltipFrame.Visible = true
	elseif slot == "2" then
		local healAmt = math.max(
			GameConstants.HP_POTION_MIN_HEAL,
			math.floor(playerState.maxHp * GameConstants.HP_POTION_HEAL_PERCENT + 0.5)
		)
		tooltipTitleLabel.Text = string.format("[2] %s", I18n.t("UI_HP_POTION_SLOT_TITLE"))
		tooltipStatsLabel.Text = I18n.t("UI_TOOLTIP_HP_POTION_STATS", {
			heal = healAmt,
			cd = string.format("%.1f", GameConstants.POTION_COOLDOWN),
			count = clientProfile.HpPotions,
		})
		tooltipDescLabel.Text = I18n.t("UI_HP_POTION_DESC")
		hotbarTooltipFrame.Visible = true
	elseif slot == "3" then
		local restoreAmt = math.max(
			GameConstants.MP_POTION_MIN_RESTORE,
			math.floor(playerState.maxMp * GameConstants.MP_POTION_RESTORE_PERCENT + 0.5)
		)
		tooltipTitleLabel.Text = string.format("[3] %s", I18n.t("UI_MP_POTION_SLOT_TITLE"))
		tooltipStatsLabel.Text = I18n.t("UI_TOOLTIP_MP_POTION_STATS", {
			restore = restoreAmt,
			cd = string.format("%.1f", GameConstants.POTION_COOLDOWN),
			count = clientProfile.MpPotions,
		})
		tooltipDescLabel.Text = I18n.t("UI_MP_POTION_DESC")
		hotbarTooltipFrame.Visible = true
	elseif slot == "PVP" then
		local statusStr, _, karma, pvpKills, pkKills = getPlayerNameStatusInfo()
		tooltipTitleLabel.Text = I18n.t("UI_PVP_TOOLTIP_TITLE")
		tooltipStatsLabel.Text = I18n.t("UI_PVP_TOOLTIP_STATS", {
			status = statusStr,
			karma = karma,
			pvp = pvpKills,
			pk = pkKills,
		})
		tooltipDescLabel.Text = I18n.t("UI_PVP_TOOLTIP_DESC")
		hotbarTooltipFrame.Visible = true
	else
		local skillData = CombatController.GetSkillForSlot(slot)
		if not skillData then
			hotbarTooltipFrame.Visible = false
			return
		end
		local rangeStr: string
		if skillData.targetType == "SelfBuff" then
			rangeStr = I18n.t("UI_RANGE_SELF")
		elseif
			skillData.id == "SKILL_BATON_STUN"
			or skillData.id == "SKILL_SLICE_DICE"
			or skillData.id == "SKILL_IRON_PAN"
		then
			rangeStr = "8"
		else
			rangeStr = tostring(skillData.range)
		end

		tooltipTitleLabel.Text = string.format("[%s] %s", slot, I18n.t(skillData.nameKey))
		tooltipStatsLabel.Text = I18n.t("UI_TOOLTIP_STATS", {
			mp = skillData.mpCost,
			cd = tostring(skillData.cooldown),
			range = rangeStr,
		})
		tooltipDescLabel.Text = I18n.t(skillData.descKey)
		hotbarTooltipFrame.Visible = true
	end
end

local function refreshPartyWindow()
	if not partyPvpUI.partyWindowFrame then
		return
	end

	local otherCount = #partyPvpUI.partyMembersState
	if otherCount < 1 then
		partyPvpUI.partyWindowFrame.Visible = false
		return
	end

	partyPvpUI.partyWindowFrame.Visible = true
	partyPvpUI.partyWindowFrame.Size = UDim2.fromOffset(275, 32 + otherCount * 52 + 34)
	partyPvpUI.partyHeaderLabel.Text = I18n.t("UI_PARTY_HEADER", { count = otherCount + 1 })
	partyPvpUI.partyLeaveBtn.Text = I18n.t("UI_PARTY_LEAVE_BTN")

	local curTarget = TargetController.GetTarget()

	for idx = 1, 5 do
		local rowUi = partyPvpUI.partyRows[idx]
		local member = partyPvpUI.partyMembersState[idx]
		if rowUi then
			if member then
				rowUi.button.Visible = true
				local crownPrefix = if member.isLeader then "👑 " elseif member.isBot then "🤖 " else "• "
				rowUi.nameLabel.Text = string.format("%s%s [Ур.%d]", crownPrefix, member.name, member.level)

				local cData = ClassesConfig[member.classId]
				local cName = if cData then I18n.t(cData.nameKey) else member.classId
				rowUi.classLabel.Text = cName

				local hpRatio = math.clamp(member.hp / math.max(1, member.maxHp), 0, 1)
				rowUi.hpFill.Size = UDim2.fromScale(hpRatio, 1)
				rowUi.hpText.Text = string.format("%d/%d", member.hp, member.maxHp)

				local mpRatio = math.clamp(member.mp / math.max(1, member.maxMp), 0, 1)
				rowUi.mpFill.Size = UDim2.fromScale(mpRatio, 1)

				local isSelected = (curTarget ~= nil and member.model == curTarget)
				rowUi.stroke.Color = if isSelected
					then Color3.fromRGB(0, 235, 255)
					else L2_SUB_BORDER
				rowUi.stroke.Thickness = if isSelected then 1.8 else 1.0
			else
				rowUi.button.Visible = false
			end
		end
	end
end

local function refreshPvpToggleVisuals()
	if not partyPvpUI.pvpForceButton or not partyPvpUI.pvpForceStroke or not partyPvpUI.pvpForceLabel then
		return
	end
	local isForceOn = CombatController.IsForcePvpActive()
	if isForceOn then
		partyPvpUI.pvpForceLabel.Text = I18n.t("UI_PVP_BTN_ON")
		partyPvpUI.pvpForceLabel.TextColor3 = Color3.fromRGB(255, 225, 255)
		partyPvpUI.pvpForceButton.BackgroundColor3 = Color3.fromRGB(92, 26, 128)
		partyPvpUI.pvpForceStroke.Color = Color3.fromRGB(215, 105, 255)
		partyPvpUI.pvpForceStroke.Thickness = 2.0
	else
		partyPvpUI.pvpForceLabel.Text = I18n.t("UI_PVP_BTN_OFF")
		partyPvpUI.pvpForceLabel.TextColor3 = Color3.fromRGB(190, 198, 215)
		partyPvpUI.pvpForceButton.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
		partyPvpUI.pvpForceStroke.Color = L2_SUB_BORDER
		partyPvpUI.pvpForceStroke.Thickness = 1.2
	end
end

local function refreshHotbarLabels()
	for _, slotUi in ipairs(hotbarSlots) do
		if slotUi.slot == "1" then
			slotUi.nameLabel.Text = I18n.t("UI_BASIC_ATTACK")
			slotUi.mpLabel.Text = I18n.t("UI_MP_COST", { mp = 0 })
		else
			local skillData = CombatController.GetSkillForSlot(slotUi.slot)
			if skillData then
				slotUi.nameLabel.Text = I18n.t(skillData.nameKey)
				slotUi.mpLabel.Text = I18n.t("UI_MP_COST", { mp = skillData.mpCost })
			else
				slotUi.nameLabel.Text = "-"
				slotUi.mpLabel.Text = ""
			end
		end
	end
	refreshSoulshotSlot()
	refreshPotionSlots()
	refreshPvpToggleVisuals()
	refreshHotbarTooltip()
end

local function refreshCharacterCreationScreen()
	if not creationUI.charCreationScreen then
		return
	end

	creationUI.charCreateTitleLabel.Text = I18n.t("UI_CHAR_CREATE_TITLE")
	creationUI.charCreateSubtitleLabel.Text = I18n.t("UI_CHAR_CREATE_SUBTITLE")
	creationUI.charCreateLangBtn.Text = I18n.t("UI_BTN_LANG", { lang = string.upper(I18n.GetLanguage()) })
	creationUI.charRaceHeaderLabel.Text = I18n.t("UI_CHAR_SELECT_RACE")
	creationUI.charClassHeaderLabel.Text = I18n.t("UI_CHAR_SELECT_CLASS")
	creationUI.charGenderHeaderLabel.Text = I18n.t("UI_GENDER")
	creationUI.charRacePassiveHeaderLabel.Text = I18n.t("UI_CHAR_RACE_PASSIVES")
	creationUI.charClassSkillsHeaderLabel.Text = I18n.t("UI_CHAR_CLASS_SKILLS")
	creationUI.charCreateConfirmBtn.Text = I18n.t("UI_CHAR_CREATE_BTN")

	local isMaleSelected = (selectedCreationGender == "Male")
	creationUI.creationMaleBtn.Text = (if isMaleSelected then "▶  ♂ " else "♂ ") .. I18n.t("UI_GENDER_MALE")
	creationUI.creationMaleBtn.BackgroundColor3 = if isMaleSelected
		then Color3.fromRGB(45, 110, 195)
		else Color3.fromRGB(26, 31, 44)

	local isFemaleSelected = (selectedCreationGender == "Female")
	creationUI.creationFemaleBtn.Text = (if isFemaleSelected then "▶  ♀ " else "♀ ") .. I18n.t("UI_GENDER_FEMALE")
	creationUI.creationFemaleBtn.BackgroundColor3 = if isFemaleSelected
		then Color3.fromRGB(175, 65, 135)
		else Color3.fromRGB(26, 31, 44)

	for raceId, btn in pairs(creationUI.creationRaceButtons) do
		local rData = RacesConfig[raceId :: RacesConfig.RaceId]
		if rData then
			local isSelected = (selectedCreationRace == raceId)
			btn.Text = if isSelected then ("▶  " .. I18n.t(rData.nameKey)) else I18n.t(rData.nameKey)
			btn.BackgroundColor3 = if isSelected
				then Color3.fromRGB(45, 130, 90)
				else Color3.fromRGB(26, 31, 44)
		end
	end

	for classId, btn in pairs(creationUI.creationClassButtons) do
		local cData = ClassesConfig[classId]
		if cData then
			local isSelected = (selectedCreationClass == classId)
			local labelText = string.format("%s (%s)", I18n.t(cData.nameKey), cData.role)
			btn.Text = if isSelected then ("▶  " .. labelText) else labelText
			btn.BackgroundColor3 = if isSelected
				then Color3.fromRGB(50, 110, 195)
				else Color3.fromRGB(26, 31, 44)
		end
	end

	creationUI.charRacePassiveValueLabel.Text = formatRacePassiveText(selectedCreationRace)
	creationUI.charClassSkillsValueLabel.Text = formatClassSkillPreviewText(selectedCreationClass)
end

local function computeClientGearBonuses(): (number, number, number, number, number)
	local atkBonus = 0
	local pDefBonus = 0
	local mDefBonus = 0
	local maxHpBonus = 0
	local maxMpBonus = 0

	local eq = clientProfile.EquippedItems
	if eq then
		for _, slotName in ipairs(ItemsConfig.EQUIPMENT_SLOTS) do
			local itemId = (eq :: any)[slotName] :: string?
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

local function formatItemBonusesLine(itemData: ItemsConfig.ItemData): string
	local parts: { string } = {}
	local b = itemData.bonuses
	if b.atk and b.atk > 0 then
		table.insert(parts, string.format("+%d P.Atk", b.atk))
	end
	if b.pDef and b.pDef > 0 then
		table.insert(parts, string.format("+%d P.Def", b.pDef))
	end
	if b.mDef and b.mDef > 0 then
		table.insert(parts, string.format("+%d M.Def", b.mDef))
	end
	if b.maxHp and b.maxHp > 0 then
		table.insert(parts, string.format("+%d %s", b.maxHp, I18n.t("UI_HP")))
	end
	if b.maxMp and b.maxMp > 0 then
		table.insert(parts, string.format("+%d %s", b.maxMp, I18n.t("UI_MP")))
	end
	return table.concat(parts, "  •  ")
end

local function refreshItemTooltip()
	if not itemTooltipFrame then
		return
	end
	if not hoveredTooltipData or not inventoryModal or not inventoryModal.Visible then
		itemTooltipFrame.Visible = false
		return
	end

	itemTooltipTitleLabel.Text = hoveredTooltipData.title
	itemTooltipTitleLabel.TextColor3 = hoveredTooltipData.titleColor
	itemTooltipMetaLabel.Text = hoveredTooltipData.meta
	itemTooltipBonusesLabel.Text = hoveredTooltipData.bonuses
	itemTooltipDescLabel.Text = hoveredTooltipData.desc
	itemTooltipFrame.Visible = true
end

local function buildTooltipDataForItemData(itemData: ItemsConfig.ItemData, isPaperdollSlot: boolean): {
	title: string,
	titleColor: Color3,
	meta: string,
	bonuses: string,
	desc: string,
}
	local slotNameKey = ItemsConfig.SLOT_NAME_KEYS[itemData.slot] or "UI_SLOT_WEAPON"
	local isEquippedWeapon = (itemData.slot == "Weapon" and clientProfile.EquippedItems.Weapon == itemData.id)
	local enchantSuffix = if isEquippedWeapon and clientProfile.WeaponEnchant > 0
		then string.format(" [+%d]", clientProfile.WeaponEnchant)
		else ""

	local hintLine = if isPaperdollSlot
		then I18n.t("UI_INV_HINT_PAPERDOLL")
		else I18n.t("UI_INV_HINT_INTERACT")

	return {
		title = string.format("[%s] %s%s", itemData.grade, I18n.t(itemData.nameKey), enchantSuffix),
		titleColor = if itemData.grade == "D"
			then Color3.fromRGB(95, 215, 255)
			else Color3.fromRGB(245, 235, 185),
		meta = I18n.t("UI_ITEM_TOOLTIP_META", {
			grade = itemData.grade,
			slot = I18n.t(slotNameKey),
			reqLv = itemData.reqLevel,
			price = itemData.sellPrice,
		}),
		bonuses = formatItemBonusesLine(itemData),
		desc = I18n.t(itemData.descKey) .. "\n" .. hintLine,
	}
end

local function executeBagGridEntryDoubleClick(entry: BagGridEntry)
	if entry.kind == "Equipment" and entry.bagIndex then
		Remotes.EquipItem:FireServer(entry.bagIndex)
	elseif entry.id == "EnchantScrolls" then
		if clientProfile.HasWeapon then
			activeInventoryTab = "Workshop"
			Remotes.RequestEnchantWeapon:FireServer()
		else
			UIController.AddSystemLog(I18n.t("LOG_ENCHANT_NO_WEAPON"), Color3.fromRGB(255, 95, 95))
		end
	elseif entry.id == "HpPotions" then
		Remotes.UsePotion:FireServer("HP")
	elseif entry.id == "MpPotions" then
		Remotes.UsePotion:FireServer("MP")
	elseif entry.id == "EnergyShots" then
		Remotes.ToggleAutoSoulshot:FireServer()
	end
end

local function refreshInventoryFooter()
	if not invSelectedItemLabel or not invActionEquipBtn or not invActionSellBtn or not invAdenaLabel then
		return
	end

	invAdenaLabel.Text = string.format("🪙 $%d   |   ♻ %d", playerState.cash, playerState.trashTokens)

	local selEntry = if selectedGridCellIndex then currentGridEntries[selectedGridCellIndex] else nil
	if not selEntry then
		invSelectedItemLabel.Text = I18n.t("UI_INV_NO_SELECTION")
		invSelectedItemLabel.TextColor3 = Color3.fromRGB(145, 155, 175)
		invActionEquipBtn.Visible = false
		invActionSellBtn.Visible = false
		return
	end

	invSelectedItemLabel.Text = selEntry.titleText
	invSelectedItemLabel.TextColor3 = if selEntry.grade == "D"
		then Color3.fromRGB(105, 220, 255)
		else Color3.fromRGB(245, 235, 190)

	if selEntry.kind == "Equipment" and selEntry.bagIndex then
		invActionEquipBtn.Visible = true
		invActionEquipBtn.Text = I18n.t("UI_BTN_EQUIP")
		invActionEquipBtn.BackgroundColor3 = Color3.fromRGB(38, 125, 78)

		invActionSellBtn.Visible = true
		invActionSellBtn.Text = I18n.t("UI_BTN_SELL", { price = selEntry.sellPrice or 10 })
	elseif selEntry.id == "EnchantScrolls" then
		invActionEquipBtn.Visible = true
		invActionEquipBtn.Text = I18n.t("UI_BTN_USE_SCROLL")
		invActionEquipBtn.BackgroundColor3 = Color3.fromRGB(175, 125, 28)
		invActionSellBtn.Visible = false
	elseif selEntry.id == "HpPotions" or selEntry.id == "MpPotions" then
		invActionEquipBtn.Visible = true
		invActionEquipBtn.Text = I18n.t("UI_BTN_EQUIP")
		invActionEquipBtn.BackgroundColor3 = Color3.fromRGB(38, 115, 145)
		invActionSellBtn.Visible = false
	else
		invActionEquipBtn.Visible = false
		invActionSellBtn.Visible = false
	end
end

local function refreshInventoryPaperdollAndBag()
	if not inventoryModal then
		return
	end

	local gearAtk, gearPDef, gearMDef, gearHp, gearMp = computeClientGearBonuses()
	local hasWeapon = (clientProfile.EquippedItems.Weapon ~= nil)
	local enchantBonus = if hasWeapon then GameConstants.GetWeaponEnchantAtkBonus(clientProfile.WeaponEnchant) else 0

	local eqMap = clientProfile.EquippedItems :: { [string]: string? }
	for slotName, cellUi in pairs(paperdollCells) do
		local itemId = eqMap[slotName]
		local itemData = ItemsConfig.GetItem(itemId)
		if itemData then
			local style = ItemsConfig.GetItemVisualStyle(itemData.id)
			cellUi.gradient.Color = ColorSequence.new(style.tintTop, style.tintBottom)
			cellUi.stroke.Color = if itemData.grade == "D"
				then Color3.fromRGB(95, 205, 255)
				else style.borderColor
			cellUi.stroke.Thickness = if itemData.grade == "D" then 1.6 else 1.2
			cellUi.glyphLabel.Text = style.glyph
			cellUi.glyphLabel.TextColor3 = style.glyphColor
			cellUi.glyphLabel.TextTransparency = 0

			if slotName == "Weapon" and clientProfile.WeaponEnchant > 0 then
				cellUi.topLeftBadge.Visible = true
				cellUi.topLeftBadge.Text = "+" .. tostring(clientProfile.WeaponEnchant)
				cellUi.topLeftBadge.TextColor3 = getEnchantTierColor(clientProfile.WeaponEnchant)
			else
				cellUi.topLeftBadge.Visible = false
			end

			cellUi.topRightBadge.Visible = true
			cellUi.topRightBadge.Text = itemData.grade
			cellUi.topRightBadge.TextColor3 = if itemData.grade == "D"
				then Color3.fromRGB(95, 220, 255)
				else Color3.fromRGB(205, 210, 225)
		else
			cellUi.gradient.Color = ColorSequence.new(Color3.fromRGB(20, 22, 30), Color3.fromRGB(11, 13, 18))
			cellUi.stroke.Color = Color3.fromRGB(68, 60, 44)
			cellUi.stroke.Thickness = 1.0
			cellUi.glyphLabel.Text = cellUi.emptyGlyph
			cellUi.glyphLabel.TextColor3 = Color3.fromRGB(85, 92, 110)
			cellUi.glyphLabel.TextTransparency = 0.45
			cellUi.topLeftBadge.Visible = false
			cellUi.topRightBadge.Visible = false
		end
	end

	if invGearBonusesSummaryLabel then
		invGearBonusesSummaryLabel.Text = I18n.t("UI_GEAR_BONUSES_SUMMARY", {
			atk = gearAtk + enchantBonus,
			pdef = gearPDef,
			mdef = gearMDef,
			hp = gearHp,
			mp = gearMp,
		})
	end

	-- Update Top Tabs & Visibility
	if invTabDefaultBtn and invTabQuestBtn and invTabWorkshopBtn then
		invTabDefaultBtn.Text = I18n.t("UI_INV_TAB_DEFAULT")
		invTabQuestBtn.Text = I18n.t("UI_INV_TAB_QUEST")
		invTabWorkshopBtn.Text = I18n.t("UI_INV_TAB_WORKSHOP")

		invTabDefaultBtn.BackgroundColor3 = if activeInventoryTab == "Default"
			then Color3.fromRGB(62, 52, 32)
			else Color3.fromRGB(22, 25, 34)
		invTabDefaultBtn.TextColor3 = if activeInventoryTab == "Default"
			then Color3.fromRGB(255, 230, 125)
			else Color3.fromRGB(175, 185, 205)

		invTabQuestBtn.BackgroundColor3 = if activeInventoryTab == "Quest"
			then Color3.fromRGB(62, 52, 32)
			else Color3.fromRGB(22, 25, 34)
		invTabQuestBtn.TextColor3 = if activeInventoryTab == "Quest"
			then Color3.fromRGB(255, 230, 125)
			else Color3.fromRGB(175, 185, 205)

		invTabWorkshopBtn.BackgroundColor3 = if activeInventoryTab == "Workshop"
			then Color3.fromRGB(62, 52, 32)
			else Color3.fromRGB(22, 25, 34)
		invTabWorkshopBtn.TextColor3 = if activeInventoryTab == "Workshop"
			then Color3.fromRGB(115, 240, 255)
			else Color3.fromRGB(175, 185, 205)
	end

	if bagGridContainer and workshopTabContainer then
		bagGridContainer.Visible = (activeInventoryTab ~= "Workshop")
		workshopTabContainer.Visible = (activeInventoryTab == "Workshop")
	end

	-- Build entries for the 54-slot 9x6 L2 square grid
	table.clear(currentGridEntries)
	local occupiedCount = 0

	local function pushGridEntry(entry: BagGridEntry)
		if occupiedCount < TOTAL_L2_GRID_SLOTS then
			occupiedCount += 1
			currentGridEntries[occupiedCount] = entry
		end
	end

	if activeInventoryTab == "Quest" then
		if playerState.trashTokens > 0 then
			pushGridEntry({
				kind = "Quest",
				id = "TrashTokens",
				quantity = playerState.trashTokens,
				titleText = string.format("%s (x%d)", I18n.t("UI_TRASH_TOKENS"), playerState.trashTokens),
				metaText = "Quest / Spoil Token",
				bonusesText = "5x -> +1 " .. I18n.t("UI_ENCHANT_SCROLLS"),
				descText = I18n.t("UI_TRASH_TOKENS_DESC"),
				grade = "NG",
			})
		end

		for _, bossReq in ipairs(GameConstants.SUBCLASS_REQUIRED_BOSSES) do
			local kills = getBossKillsForId(bossReq.id)
			pushGridEntry({
				kind = "Quest",
				id = "QuestTrophy",
				quantity = kills,
				titleText = string.format("%s (%d/%d)", I18n.t(bossReq.nameKey), kills, bossReq.requiredKills),
				metaText = string.format("Tier %d Raid Dossier (Lv.%d)", bossReq.tier, bossReq.level),
				bonusesText = if kills >= bossReq.requiredKills then "✓ COMPLETED" else "In Progress",
				descText = I18n.t("UI_SUBCLASS_HINT"),
				grade = if kills >= bossReq.requiredKills then "D" else "NG",
			})
		end
	else
		-- Tab 1 ("Default"): Stackable items first (just like Lineage 2), followed by equipment in InventoryBag
		if clientProfile.EnchantScrolls > 0 then
			pushGridEntry({
				kind = "Stackable",
				id = "EnchantScrolls",
				quantity = clientProfile.EnchantScrolls,
				titleText = string.format("%s (x%d)", I18n.t("UI_ENCHANT_SCROLLS"), clientProfile.EnchantScrolls),
				metaText = "Scroll: Enchant Weapon  |  Safe +3 / Max +16",
				bonusesText = "+5 P.Atk (+1..+3), +12 P.Atk (+4..+16)",
				descText = I18n.t("UI_ENCHANT_SCROLL_DESC"),
				grade = "D",
			})
		end

		if clientProfile.EnergyShots > 0 then
			pushGridEntry({
				kind = "Stackable",
				id = "EnergyShots",
				quantity = clientProfile.EnergyShots,
				titleText = string.format("%s (x%d)", I18n.t("UI_ENERGY_SHOTS"), clientProfile.EnergyShots),
				metaText = I18n.t("UI_TOOLTIP_SOULSHOT_STATS", { count = clientProfile.EnergyShots }),
				bonusesText = "x2.0 Damage Multiplier",
				descText = I18n.t("UI_SOULSHOT_DESC"),
				grade = "NG",
			})
		end

		if clientProfile.HpPotions > 0 then
			local healAmt = math.max(
				GameConstants.HP_POTION_MIN_HEAL,
				math.floor(playerState.maxHp * GameConstants.HP_POTION_HEAL_PERCENT + 0.5)
			)
			pushGridEntry({
				kind = "Stackable",
				id = "HpPotions",
				quantity = clientProfile.HpPotions,
				titleText = string.format("%s (x%d)", I18n.t("UI_HP_POTIONS"), clientProfile.HpPotions),
				metaText = I18n.t("UI_TOOLTIP_HP_POTION_STATS", {
					heal = healAmt,
					cd = string.format("%.1f", GameConstants.POTION_COOLDOWN),
					count = clientProfile.HpPotions,
				}),
				bonusesText = string.format("+%d %s (35%%)", healAmt, I18n.t("UI_HP")),
				descText = I18n.t("UI_HP_POTION_DESC"),
				grade = "NG",
			})
		end

		if clientProfile.MpPotions > 0 then
			local restoreAmt = math.max(
				GameConstants.MP_POTION_MIN_RESTORE,
				math.floor(playerState.maxMp * GameConstants.MP_POTION_RESTORE_PERCENT + 0.5)
			)
			pushGridEntry({
				kind = "Stackable",
				id = "MpPotions",
				quantity = clientProfile.MpPotions,
				titleText = string.format("%s (x%d)", I18n.t("UI_MP_POTIONS"), clientProfile.MpPotions),
				metaText = I18n.t("UI_TOOLTIP_MP_POTION_STATS", {
					restore = restoreAmt,
					cd = string.format("%.1f", GameConstants.POTION_COOLDOWN),
					count = clientProfile.MpPotions,
				}),
				bonusesText = string.format("+%d %s (35%%)", restoreAmt, I18n.t("UI_MP")),
				descText = I18n.t("UI_MP_POTION_DESC"),
				grade = "NG",
			})
		end

		if clientProfile.CrystalShards > 0 then
			pushGridEntry({
				kind = "Stackable",
				id = "CrystalShards",
				quantity = clientProfile.CrystalShards,
				titleText = string.format("%s (x%d)", I18n.t("UI_CRYSTAL_SHARDS"), clientProfile.CrystalShards),
				metaText = "Material / Crystallization Residue",
				bonusesText = "Craft & Upgrade Material",
				descText = I18n.t("UI_CRYSTAL_SHARDS_DESC"),
				grade = "NG",
			})
		end

		if playerState.cash > 0 then
			pushGridEntry({
				kind = "Stackable",
				id = "Cash",
				quantity = playerState.cash,
				titleText = string.format("%s ($%d)", I18n.t("UI_CASH"), playerState.cash),
				metaText = "Currency / Adena",
				bonusesText = string.format("$%d", playerState.cash),
				descText = I18n.t("UI_CASH_DESC"),
				grade = "NG",
			})
		end

		for bagIdx, itemId in ipairs(clientProfile.InventoryBag) do
			local itemData = ItemsConfig.GetItem(itemId)
			if itemData then
				local tData = buildTooltipDataForItemData(itemData, false)
				pushGridEntry({
					kind = "Equipment",
					id = itemData.id,
					bagIndex = bagIdx,
					quantity = 1,
					titleText = tData.title,
					metaText = tData.meta,
					bonusesText = tData.bonuses,
					descText = tData.desc,
					grade = itemData.grade,
					sellPrice = itemData.sellPrice,
				})
			end
		end
	end

	if selectedGridCellIndex and not currentGridEntries[selectedGridCellIndex] then
		selectedGridCellIndex = nil
	end

	if invSlotCounterLabel then
		invSlotCounterLabel.Text = string.format("(%d/%d)", occupiedCount, TOTAL_L2_GRID_SLOTS)
	end

	-- Update all 54 square cells in-place
	for idx = 1, TOTAL_L2_GRID_SLOTS do
		local cellUi = bagGridCells[idx]
		if cellUi then
			local entry = currentGridEntries[idx]
			local isSelected = (selectedGridCellIndex == idx) and (entry ~= nil)

			if entry then
				local style = ItemsConfig.GetItemVisualStyle(entry.id)
				cellUi.gradient.Color = ColorSequence.new(style.tintTop, style.tintBottom)
				if isSelected then
					cellUi.stroke.Color = Color3.fromRGB(255, 225, 75)
					cellUi.stroke.Thickness = 2.0
				elseif entry.grade == "D" then
					cellUi.stroke.Color = Color3.fromRGB(95, 205, 255)
					cellUi.stroke.Thickness = 1.5
				else
					cellUi.stroke.Color = style.borderColor
					cellUi.stroke.Thickness = 1.1
				end

				cellUi.glyphLabel.Visible = true
				cellUi.glyphLabel.Text = style.glyph
				cellUi.glyphLabel.TextColor3 = style.glyphColor

				cellUi.topLeftBadge.Visible = false

				if entry.kind == "Equipment" and entry.grade then
					cellUi.topRightBadge.Visible = true
					cellUi.topRightBadge.Text = entry.grade
					cellUi.topRightBadge.TextColor3 = if entry.grade == "D"
						then Color3.fromRGB(95, 225, 255)
						else Color3.fromRGB(205, 210, 225)
				else
					cellUi.topRightBadge.Visible = false
				end

				if entry.kind == "Stackable" or entry.kind == "Quest" then
					local qty = entry.quantity or 0
					cellUi.bottomRightBadge.Visible = true
					if entry.id == "Cash" then
						cellUi.bottomRightBadge.Text = if qty >= 10000
							then string.format("$%.1fk", qty / 1000)
							else ("$" .. tostring(qty))
						cellUi.bottomRightBadge.TextColor3 = Color3.fromRGB(255, 225, 95)
					else
						cellUi.bottomRightBadge.Text = "x" .. tostring(qty)
						cellUi.bottomRightBadge.TextColor3 = Color3.fromRGB(240, 245, 255)
					end
				else
					cellUi.bottomRightBadge.Visible = false
				end
			else
				-- Empty dark recessed L2 grid slot
				cellUi.gradient.Color = ColorSequence.new(Color3.fromRGB(16, 18, 25), Color3.fromRGB(10, 12, 17))
				cellUi.stroke.Color = Color3.fromRGB(46, 42, 34)
				cellUi.stroke.Thickness = 1.0
				cellUi.glyphLabel.Visible = false
				cellUi.topLeftBadge.Visible = false
				cellUi.topRightBadge.Visible = false
				cellUi.bottomRightBadge.Visible = false
			end
		end
	end

	refreshInventoryFooter()
	refreshItemTooltip()
end

local function refreshModals()
	jobUI.jobModalTitle.Text = I18n.t("UI_CHANGE_CLASS")
	jobUI.jobCloseBtn.Text = I18n.t("UI_CLOSE")

	local raceData = RacesConfig[playerState.raceId :: RacesConfig.RaceId] or RacesConfig.RACE_LAW
	jobUI.jobLockedRaceBanner.Text = string.format(
		"🔒 %s  •  %s",
		I18n.t("UI_LOCKED_RACE_LABEL", { race = I18n.t(raceData.nameKey) }),
		formatRacePassiveText(raceData.id)
	)

	jobUI.jobDossierHeaderLabel.Text = I18n.t("UI_SUBCLASS_DOSSIER")
	jobUI.jobDossierHintLabel.Text = I18n.t("UI_SUBCLASS_HINT")

	local maxReachedLevel = getMaxReachedLevelFromProfile()
	local reqLv = GameConstants.SUBCLASS_REQUIRED_LEVEL
	local lvMet = maxReachedLevel >= reqLv
	local lvIcon = if lvMet then "[✓] " else "[✗] "
	jobUI.jobLevelChecklistLabel.Text = lvIcon .. I18n.t("UI_DOSSIER_MAIN_LEVEL", {
		cur = maxReachedLevel,
		req = reqLv,
	})
	jobUI.jobLevelChecklistLabel.TextColor3 = if lvMet
		then Color3.fromRGB(110, 245, 140)
		else Color3.fromRGB(255, 200, 90)

	for _, bossReq in ipairs(GameConstants.SUBCLASS_REQUIRED_BOSSES) do
		local bossLabel = jobUI.jobBossChecklistLabels[bossReq.id]
		if bossLabel then
			local curKills = getBossKillsForId(bossReq.id)
			local met = curKills >= bossReq.requiredKills
			local icon = if met then "[✓] " else "[✗] "
			bossLabel.Text = icon .. I18n.t("UI_DOSSIER_BOSS_TIER", {
				tier = bossReq.tier,
				boss = I18n.t(bossReq.nameKey),
				lv = bossReq.level,
				cur = curKills,
				req = bossReq.requiredKills,
			})
			bossLabel.TextColor3 = if met
				then Color3.fromRGB(110, 245, 140)
				else Color3.fromRGB(245, 115, 115)
		end
	end

	local canUnlockNewSubclass = areAllSubclassConditionsMet()

	for classId, btn in pairs(jobUI.classButtons) do
		local classData = ClassesConfig[classId]
		if classData then
			local isActive = (playerState.classId == classId)
			local isUnlocked = isActive or (clientProfile.UnlockedClasses[classId] == true)
			local savedProg = clientProfile.ClassProgress[classId]
			local classLv = if isActive
				then playerState.level
				elseif savedProg then savedProg.Level
				else 1

			local tagText = ""
			if isActive then
				tagText = I18n.t("UI_CLASS_TAG_ACTIVE", { lv = classLv })
				btn.BackgroundColor3 = Color3.fromRGB(50, 115, 195)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.AutoButtonColor = true
			elseif isUnlocked then
				tagText = I18n.t("UI_CLASS_TAG_UNLOCKED", { lv = classLv })
				btn.BackgroundColor3 = Color3.fromRGB(36, 78, 62)
				btn.TextColor3 = Color3.fromRGB(235, 255, 240)
				btn.AutoButtonColor = true
			elseif canUnlockNewSubclass then
				tagText = I18n.t("UI_CLASS_TAG_CAN_UNLOCK")
				btn.BackgroundColor3 = Color3.fromRGB(145, 108, 32)
				btn.TextColor3 = Color3.fromRGB(255, 245, 200)
				btn.AutoButtonColor = true
			else
				tagText = I18n.t("UI_CLASS_TAG_LOCKED")
				btn.BackgroundColor3 = Color3.fromRGB(24, 22, 28)
				btn.TextColor3 = Color3.fromRGB(145, 135, 145)
				btn.AutoButtonColor = false
			end

			btn.Text = string.format("%s (%s)\n%s", I18n.t(classData.nameKey), classData.role, tagText)
		end
	end

	local previewClassData = ClassesConfig[jobUI.previewedJobClassId] or ClassesConfig[playerState.classId] or ClassesConfig.RiotPolice
	if jobUI.jobClassSkillsHeaderLabel and jobUI.jobClassSkillsValueLabel then
		jobUI.jobClassSkillsHeaderLabel.Text = I18n.t("UI_JOB_SKILLS_PREVIEW_HEADER", {
			class = I18n.t(previewClassData.nameKey),
		})
		jobUI.jobClassSkillsValueLabel.Text = formatClassSkillPreviewText(previewClassData.id)
	end

	inventoryTitleLabel.Text = I18n.t("UI_MODAL_INVENTORY")
	inventoryCloseBtn.Text = I18n.t("UI_CLOSE")
	local classData = ClassesConfig[playerState.classId] or ClassesConfig.RiotPolice

	local gearAtk, gearPDef, gearMDef = computeClientGearBonuses()
	local equippedWeaponId = clientProfile.EquippedItems.Weapon
	local equippedWeaponData = ItemsConfig.GetItem(equippedWeaponId)
	local hasWeapon = (equippedWeaponData ~= nil)
	clientProfile.HasWeapon = hasWeapon

	local enchantLv = if hasWeapon then clientProfile.WeaponEnchant else 0
	local enchantAtkBonus = if hasWeapon then GameConstants.GetWeaponEnchantAtkBonus(enchantLv) else 0
	local basePlusClassAtk = 28 + (playerState.level - 1) * 7 + classData.baseAtkBonus
	local pAtk = if hasWeapon
		then (basePlusClassAtk + gearAtk + enchantAtkBonus)
		else math.max(1, math.floor(basePlusClassAtk * GameConstants.BARE_FIST_ATK_MULTIPLIER + 0.5))

	refreshInventoryPaperdollAndBag()

	workshopUI.invShopHeaderLabel.Text = I18n.t("UI_INV_SECTION_SHOP")
	workshopUI.shopBuyShotsBtn.Text = I18n.t("UI_SHOP_BUY_SHOTS")
	workshopUI.shopBuyScrollCashBtn.Text = I18n.t("UI_SHOP_BUY_SCROLL_CASH")
	workshopUI.shopTradeScrollTokensBtn.Text = I18n.t("UI_SHOP_TRADE_SCROLL_TOKENS")
	if workshopUI.shopBuyHpPotionsBtn then
		workshopUI.shopBuyHpPotionsBtn.Text = I18n.t("UI_SHOP_BUY_HP_POTIONS")
	end
	if workshopUI.shopBuyMpPotionsBtn then
		workshopUI.shopBuyMpPotionsBtn.Text = I18n.t("UI_SHOP_BUY_MP_POTIONS")
	end
	workshopUI.shopBuyNewWeaponBtn.Text = I18n.t("UI_SHOP_BUY_NEW_WEAPON")
	workshopUI.shopBuyNewWeaponBtn.BackgroundColor3 = if not hasWeapon
		then Color3.fromRGB(45, 145, 85)
		else Color3.fromRGB(36, 44, 58)

	workshopUI.invEnchantHeaderLabel.Text = I18n.t("UI_INV_SECTION_ENCHANT")

	if not hasWeapon or not equippedWeaponData then
		workshopUI.enchantWeaponNameLabel.Text = I18n.t("UI_WEAPON_BROKEN_NAME")
		workshopUI.enchantWeaponNameLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		workshopUI.enchantWeaponCardStroke.Color = Color3.fromRGB(220, 50, 55)
		workshopUI.enchantAtkBonusLabel.Text = I18n.t("UI_ENCHANT_ATK_BARE_FIST", {
			totalAtk = pAtk,
		})
		workshopUI.enchantAtkBonusLabel.TextColor3 = Color3.fromRGB(255, 145, 145)
		workshopUI.enchantNextChanceLabel.Text = I18n.t("UI_ENCHANT_NO_WEAPON_CHANCE")
		workshopUI.enchantNextChanceLabel.TextColor3 = Color3.fromRGB(255, 200, 85)

		workshopUI.enchantWeaponBtn.Text = I18n.t("UI_BTN_ENCHANT_NO_WEAPON")
		workshopUI.enchantWeaponBtn.BackgroundColor3 = Color3.fromRGB(58, 32, 36)
		workshopUI.enchantWeaponBtn.TextColor3 = Color3.fromRGB(185, 155, 160)
		workshopUI.enchantWeaponBtn.AutoButtonColor = false
	else
		local tierColor = getEnchantTierColor(enchantLv)
		workshopUI.enchantWeaponNameLabel.Text = string.format(
			"⚔️ [%s] %s [+%d]",
			equippedWeaponData.grade,
			I18n.t(equippedWeaponData.nameKey),
			enchantLv
		)
		workshopUI.enchantWeaponNameLabel.TextColor3 = tierColor
		workshopUI.enchantWeaponCardStroke.Color = if enchantLv >= 4 then tierColor else L2_GOLD_BORDER

		workshopUI.enchantAtkBonusLabel.Text = I18n.t("UI_ENCHANT_ATK_BONUS", {
			atk = gearAtk + enchantAtkBonus,
			totalAtk = pAtk,
		})
		workshopUI.enchantAtkBonusLabel.TextColor3 = Color3.fromRGB(130, 240, 255)

		if enchantLv >= GameConstants.MAX_ENCHANT_LEVEL then
			workshopUI.enchantNextChanceLabel.Text = I18n.t("UI_ENCHANT_MAX_TAG")
			workshopUI.enchantNextChanceLabel.TextColor3 = Color3.fromRGB(255, 80, 95)
		else
			local nextLv = enchantLv + 1
			local chancePct = math.floor(GameConstants.GetEnchantSuccessChance(enchantLv) * 100 + 0.5)
			local safetyTag = if nextLv <= GameConstants.SAFE_ENCHANT_MAX
				then I18n.t("UI_ENCHANT_SAFE_TAG")
				else I18n.t("UI_ENCHANT_RISK_TAG")
			workshopUI.enchantNextChanceLabel.Text = I18n.t("UI_ENCHANT_NEXT_CHANCE", {
				nextLv = nextLv,
				chance = chancePct,
				safety = safetyTag,
			})
			workshopUI.enchantNextChanceLabel.TextColor3 = if nextLv <= GameConstants.SAFE_ENCHANT_MAX
				then Color3.fromRGB(115, 245, 145)
				else Color3.fromRGB(255, 200, 85)
		end

		workshopUI.enchantWeaponBtn.Text = I18n.t("UI_BTN_ENCHANT_WEAPON")
		workshopUI.enchantWeaponBtn.BackgroundColor3 = Color3.fromRGB(175, 125, 28)
		workshopUI.enchantWeaponBtn.TextColor3 = Color3.fromRGB(255, 250, 225)
		workshopUI.enchantWeaponBtn.AutoButtonColor = true
	end

	if workshopUI.lastEnchantFeedbackText and workshopUI.lastEnchantFeedbackColor then
		workshopUI.enchantFeedbackLabel.Text = workshopUI.lastEnchantFeedbackText
		workshopUI.enchantFeedbackLabel.TextColor3 = workshopUI.lastEnchantFeedbackColor
	else
		workshopUI.enchantFeedbackLabel.Text = I18n.t("UI_ENCHANT_STATUS_READY")
		workshopUI.enchantFeedbackLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
	end

	workshopUI.statsTitleLabel.Text = I18n.t("UI_MODAL_STATS")
	if workshopUI.statsCloseBtn:IsA("TextButton") then
		workshopUI.statsCloseBtn.Text = I18n.t("UI_CLOSE")
	end
	local pDef = (localPlayer:GetAttribute("PDef") :: number?) or (classData.basePDef + gearPDef)
	local mDef = (localPlayer:GetAttribute("MDef") :: number?) or (20 + (playerState.level - 1) * 3 + gearMDef)
	local critRate = math.floor(20 * raceData.critMult + 0.5)
	local atkSpd = math.floor(300 * raceData.atkSpdMult + 0.5)
	local moveSpd = math.floor(16 * raceData.moveSpeedMult * 10 + 0.5) / 10
	local nameStatusStr, _, karmaVal, pvpKillsVal, pkKillsVal = getPlayerNameStatusInfo()

	workshopUI.statsContentLabel.Text = string.format(
		"• %s  |  %s (%s)\n• %s: %d / %d\n• %s: %d / %d\n• %s: %d\n• %s: %d\n• %s: %d\n• %s: %d%%\n• %s: %d\n• %s: %.1f\n────────────────────────\n• %s: %s\n• %s: %d\n• %s: %d / %d",
		I18n.t("UI_LEVEL", { lv = playerState.level }),
		I18n.t(classData.nameKey),
		I18n.t(raceData.nameKey),
		I18n.t("UI_HP"),
		playerState.hp,
		playerState.maxHp,
		I18n.t("UI_MP"),
		playerState.mp,
		playerState.maxMp,
		I18n.t("UI_STAT_ATK"),
		pAtk,
		I18n.t("UI_STAT_PDEF"),
		pDef,
		I18n.t("UI_STAT_MDEF"),
		mDef,
		I18n.t("UI_STAT_CRIT"),
		critRate,
		I18n.t("UI_STAT_ATKSPD"),
		atkSpd,
		I18n.t("UI_STAT_MOVESPD"),
		moveSpd,
		I18n.t("UI_NAME_STATUS_LABEL"),
		nameStatusStr,
		I18n.t("UI_STAT_KARMA"),
		karmaVal,
		I18n.t("UI_STAT_PVP_PK"),
		pvpKillsVal,
		pkKillsVal
	)

	refreshCharacterCreationScreen()
end

local function refreshPlayerHud()
	hudLevelBadge.Text = tostring(playerState.level)
	local _, nameColor, karmaVal, pvpKillsVal, pkKillsVal = getPlayerNameStatusInfo()
	hudPlayerNameLabel.Text = localPlayer.DisplayName
	hudPlayerNameLabel.TextColor3 = nameColor

	if partyPvpUI.hudPvpKarmaBadge then
		if karmaVal > 0 then
			partyPvpUI.hudPvpKarmaBadge.Text = string.format("☠ PK:%d • Карма:%d", pkKillsVal, karmaVal)
			partyPvpUI.hudPvpKarmaBadge.TextColor3 = Color3.fromRGB(255, 65, 65)
		elseif localPlayer:GetAttribute("IsPvpFlagged") == true then
			partyPvpUI.hudPvpKarmaBadge.Text = string.format("⚔ PvP ФЛАГ • %d/%d", pvpKillsVal, pkKillsVal)
			partyPvpUI.hudPvpKarmaBadge.TextColor3 = Color3.fromRGB(205, 115, 255)
		else
			partyPvpUI.hudPvpKarmaBadge.Text = string.format("PvP:%d | PK:%d", pvpKillsVal, pkKillsVal)
			partyPvpUI.hudPvpKarmaBadge.TextColor3 = Color3.fromRGB(175, 190, 215)
		end
	end

	local classData = ClassesConfig[playerState.classId]
	local raceData = RacesConfig[playerState.raceId :: RacesConfig.RaceId]
	local className = if classData then I18n.t(classData.nameKey) else playerState.classId
	local raceName = if raceData then I18n.t(raceData.nameKey) else playerState.raceId
	hudClassRaceSubtitle.Text = string.format("%s • %s", className, raceName)

	local hpRatio = math.clamp(playerState.hp / math.max(1, playerState.maxHp), 0, 1)
	TweenService:Create(
		hudHpFill,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(hpRatio, 1) }
	):Play()
	hudHpText.Text = string.format("%s: %d / %d (%.0f%%)", I18n.t("UI_HP"), playerState.hp, playerState.maxHp, hpRatio * 100)

	local mpRatio = math.clamp(playerState.mp / math.max(1, playerState.maxMp), 0, 1)
	TweenService:Create(
		hudMpFill,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(mpRatio, 1) }
	):Play()
	hudMpText.Text = string.format("%s: %d / %d (%.0f%%)", I18n.t("UI_MP"), playerState.mp, playerState.maxMp, mpRatio * 100)

	local expRatio = math.clamp(playerState.exp / math.max(1, playerState.maxExp), 0, 1)
	local expPercent = expRatio * 100
	TweenService:Create(
		hudExpFill,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(expRatio, 1) }
	):Play()
	hudExpText.Text = string.format("%s: %.1f%% (%d / %d)", I18n.t("UI_EXP"), expPercent, playerState.exp, playerState.maxExp)

	minimapLocationLabel.Text = I18n.t("LOC_CENTRAL_STATION")
	chatInputBox.PlaceholderText = I18n.t("UI_CHAT_PLACEHOLDER")

	btnInventory.Text = I18n.t("UI_BTN_INVENTORY")
	btnJob.Text = I18n.t("UI_BTN_JOB")
	btnStats.Text = I18n.t("UI_BTN_STATS")
	btnLang.Text = I18n.t("UI_BTN_LANG", { lang = string.upper(I18n.GetLanguage()) })

	refreshHotbarLabels()
	refreshPartyWindow()
	refreshModals()
end

local function toggleModal(targetModal: Frame)
	if creationUI.charCreationScreen and creationUI.charCreationScreen.Visible then
		return
	end
	local willShow = not targetModal.Visible
	if not willShow and targetModal == inventoryModal then
		hoveredTooltipData = nil
		if itemTooltipFrame then
			itemTooltipFrame.Visible = false
		end
	end
	targetModal.Visible = willShow
	if willShow then
		if targetModal == jobUI.jobModalFrame then
			jobUI.previewedJobClassId = playerState.classId
		end
		if workshopUI.bringWindowToFront then
			workshopUI.bringWindowToFront(targetModal)
		end
		refreshModals()
	end
end

local function buildInterface()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local existingGui = playerGui:FindFirstChild("MegapolisL2_HUD")
	if existingGui then
		existingGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MegapolisL2_HUD"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- =====================================================================
	-- 2. TOP-LEFT: PLAYER STATUS FRAME (Position = UDim2.new(0, 16, 0, 58))
	-- =====================================================================
	local playerStatusFrame = Instance.new("Frame")
	playerStatusFrame.Name = "PlayerStatusFrame"
	playerStatusFrame.Position = UDim2.new(0, 16, 0, 58)
	playerStatusFrame.Size = UDim2.fromOffset(275, 108)
	playerStatusFrame.BackgroundColor3 = L2_BG_COLOR
	playerStatusFrame.BackgroundTransparency = 0.08
	playerStatusFrame.BorderSizePixel = 0
	playerStatusFrame.Parent = screenGui
	styleL2Frame(playerStatusFrame, 5, L2_GOLD_BORDER, 1.6)

	local levelBadgeBg = Instance.new("Frame")
	levelBadgeBg.Name = "LevelBadge"
	levelBadgeBg.Size = UDim2.fromOffset(30, 30)
	levelBadgeBg.Position = UDim2.fromOffset(8, 8)
	levelBadgeBg.BackgroundColor3 = Color3.fromRGB(32, 28, 20)
	levelBadgeBg.BorderSizePixel = 0
	levelBadgeBg.Parent = playerStatusFrame
	styleL2Frame(levelBadgeBg, 4, L2_GOLD_BORDER, 1.2)

	hudLevelBadge = Instance.new("TextLabel")
	hudLevelBadge.Size = UDim2.fromScale(1, 1)
	hudLevelBadge.BackgroundTransparency = 1
	hudLevelBadge.Font = Enum.Font.GothamBlack
	hudLevelBadge.TextSize = 15
	hudLevelBadge.TextColor3 = Color3.fromRGB(255, 220, 95)
	hudLevelBadge.Text = "1"
	hudLevelBadge.Parent = levelBadgeBg

	hudPlayerNameLabel = Instance.new("TextLabel")
	hudPlayerNameLabel.Name = "PlayerName"
	hudPlayerNameLabel.Size = UDim2.new(1, -135, 0, 16)
	hudPlayerNameLabel.Position = UDim2.fromOffset(44, 7)
	hudPlayerNameLabel.BackgroundTransparency = 1
	hudPlayerNameLabel.Font = Enum.Font.GothamBold
	hudPlayerNameLabel.TextSize = 14
	hudPlayerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	hudPlayerNameLabel.TextColor3 = Color3.fromRGB(245, 240, 225)
	hudPlayerNameLabel.Text = localPlayer.DisplayName
	hudPlayerNameLabel.Parent = playerStatusFrame

	partyPvpUI.hudPvpKarmaBadge = Instance.new("TextLabel")
	partyPvpUI.hudPvpKarmaBadge.Name = "PvpKarmaBadge"
	partyPvpUI.hudPvpKarmaBadge.Size = UDim2.fromOffset(92, 16)
	partyPvpUI.hudPvpKarmaBadge.AnchorPoint = Vector2.new(1, 0)
	partyPvpUI.hudPvpKarmaBadge.Position = UDim2.new(1, -8, 0, 7)
	partyPvpUI.hudPvpKarmaBadge.BackgroundTransparency = 1
	partyPvpUI.hudPvpKarmaBadge.Font = Enum.Font.GothamBlack
	partyPvpUI.hudPvpKarmaBadge.TextSize = 10
	partyPvpUI.hudPvpKarmaBadge.TextXAlignment = Enum.TextXAlignment.Right
	partyPvpUI.hudPvpKarmaBadge.TextColor3 = Color3.fromRGB(175, 190, 215)
	partyPvpUI.hudPvpKarmaBadge.Text = "PvP:0 | PK:0"
	partyPvpUI.hudPvpKarmaBadge.Parent = playerStatusFrame

	hudClassRaceSubtitle = Instance.new("TextLabel")
	hudClassRaceSubtitle.Name = "ClassRaceSubtitle"
	hudClassRaceSubtitle.Size = UDim2.new(1, -50, 0, 14)
	hudClassRaceSubtitle.Position = UDim2.fromOffset(44, 23)
	hudClassRaceSubtitle.BackgroundTransparency = 1
	hudClassRaceSubtitle.Font = Enum.Font.GothamMedium
	hudClassRaceSubtitle.TextSize = 11
	hudClassRaceSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	hudClassRaceSubtitle.TextColor3 = Color3.fromRGB(205, 180, 120)
	hudClassRaceSubtitle.Parent = playerStatusFrame

	-- HP Bar (Red)
	local hpBarBg = Instance.new("Frame")
	hpBarBg.Name = "HPBarBg"
	hpBarBg.Size = UDim2.new(1, -16, 0, 18)
	hpBarBg.Position = UDim2.fromOffset(8, 44)
	hpBarBg.BackgroundColor3 = Color3.fromRGB(42, 14, 18)
	hpBarBg.BorderSizePixel = 0
	hpBarBg.Parent = playerStatusFrame
	styleL2Frame(hpBarBg, 3, L2_SUB_BORDER, 1)

	hudHpFill = Instance.new("Frame")
	hudHpFill.Name = "HPFill"
	hudHpFill.Size = UDim2.fromScale(1, 1)
	hudHpFill.BackgroundColor3 = Color3.fromRGB(195, 36, 42)
	hudHpFill.BorderSizePixel = 0
	hudHpFill.Parent = hpBarBg

	hudHpText = Instance.new("TextLabel")
	hudHpText.Size = UDim2.fromScale(1, 1)
	hudHpText.BackgroundTransparency = 1
	hudHpText.Font = Enum.Font.GothamBold
	hudHpText.TextSize = 11
	hudHpText.TextColor3 = Color3.fromRGB(255, 255, 255)
	hudHpText.TextStrokeTransparency = 0.2
	hudHpText.Parent = hpBarBg

	-- MP Bar (Blue)
	local mpBarBg = Instance.new("Frame")
	mpBarBg.Name = "MPBarBg"
	mpBarBg.Size = UDim2.new(1, -16, 0, 16)
	mpBarBg.Position = UDim2.fromOffset(8, 66)
	mpBarBg.BackgroundColor3 = Color3.fromRGB(14, 24, 48)
	mpBarBg.BorderSizePixel = 0
	mpBarBg.Parent = playerStatusFrame
	styleL2Frame(mpBarBg, 3, L2_SUB_BORDER, 1)

	hudMpFill = Instance.new("Frame")
	hudMpFill.Name = "MPFill"
	hudMpFill.Size = UDim2.fromScale(1, 1)
	hudMpFill.BackgroundColor3 = Color3.fromRGB(35, 105, 210)
	hudMpFill.BorderSizePixel = 0
	hudMpFill.Parent = mpBarBg

	hudMpText = Instance.new("TextLabel")
	hudMpText.Size = UDim2.fromScale(1, 1)
	hudMpText.BackgroundTransparency = 1
	hudMpText.Font = Enum.Font.GothamBold
	hudMpText.TextSize = 10
	hudMpText.TextColor3 = Color3.fromRGB(235, 245, 255)
	hudMpText.TextStrokeTransparency = 0.2
	hudMpText.Parent = mpBarBg

	-- EXP Bar (Thin silver/purple bar at bottom)
	local expBarBg = Instance.new("Frame")
	expBarBg.Name = "EXPBarBg"
	expBarBg.Size = UDim2.new(1, -16, 0, 13)
	expBarBg.Position = UDim2.fromOffset(8, 86)
	expBarBg.BackgroundColor3 = Color3.fromRGB(24, 20, 36)
	expBarBg.BorderSizePixel = 0
	expBarBg.Parent = playerStatusFrame
	styleL2Frame(expBarBg, 3, L2_SUB_BORDER, 1)

	hudExpFill = Instance.new("Frame")
	hudExpFill.Name = "EXPFill"
	hudExpFill.Size = UDim2.fromScale(0, 1)
	hudExpFill.BackgroundColor3 = Color3.fromRGB(165, 130, 225)
	hudExpFill.BorderSizePixel = 0
	hudExpFill.Parent = expBarBg

	hudExpText = Instance.new("TextLabel")
	hudExpText.Size = UDim2.fromScale(1, 1)
	hudExpText.BackgroundTransparency = 1
	hudExpText.Font = Enum.Font.GothamBold
	hudExpText.TextSize = 9
	hudExpText.TextColor3 = Color3.fromRGB(235, 230, 255)
	hudExpText.TextStrokeTransparency = 0.2
	hudExpText.Parent = expBarBg

	-- Lineage 2 Zone Indicator Badge (Peace Zone vs Combat Zone) below Player Status Frame
	hudZoneBadgeFrame = Instance.new("Frame")
	hudZoneBadgeFrame.Name = "ZoneIndicatorBadge"
	hudZoneBadgeFrame.Position = UDim2.new(0, 16, 0, 170)
	hudZoneBadgeFrame.Size = UDim2.fromOffset(275, 24)
	hudZoneBadgeFrame.BackgroundColor3 = Color3.fromRGB(16, 38, 24)
	hudZoneBadgeFrame.BackgroundTransparency = 0.08
	hudZoneBadgeFrame.BorderSizePixel = 0
	hudZoneBadgeFrame.Parent = screenGui

	local zbCorner = Instance.new("UICorner")
	zbCorner.CornerRadius = UDim.new(0, 4)
	zbCorner.Parent = hudZoneBadgeFrame

	hudZoneBadgeStroke = Instance.new("UIStroke")
	hudZoneBadgeStroke.Color = Color3.fromRGB(75, 235, 125)
	hudZoneBadgeStroke.Thickness = 1.4
	hudZoneBadgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hudZoneBadgeStroke.Parent = hudZoneBadgeFrame

	hudZoneBadgeLabel = Instance.new("TextLabel")
	hudZoneBadgeLabel.Name = "ZoneLabel"
	hudZoneBadgeLabel.Size = UDim2.fromScale(1, 1)
	hudZoneBadgeLabel.BackgroundTransparency = 1
	hudZoneBadgeLabel.Font = Enum.Font.GothamBlack
	hudZoneBadgeLabel.TextSize = 11
	hudZoneBadgeLabel.TextColor3 = Color3.fromRGB(115, 255, 150)
	hudZoneBadgeLabel.TextStrokeTransparency = 0.2
	hudZoneBadgeLabel.Text = I18n.t("UI_ZONE_PEACE")
	hudZoneBadgeLabel.Parent = hudZoneBadgeFrame

	-- =====================================================================
	-- 2B. LEFT-SIDE LINEAGE 2 PARTY WINDOW (Below Zone Badge, Visible when >= 2 members)
	-- =====================================================================
	do
		partyPvpUI.partyWindowFrame = Instance.new("Frame")
		partyPvpUI.partyWindowFrame.Name = "L2PartyWindowFrame"
		partyPvpUI.partyWindowFrame.Position = UDim2.new(0, 16, 0, 200)
		partyPvpUI.partyWindowFrame.Size = UDim2.fromOffset(275, 190)
		partyPvpUI.partyWindowFrame.BackgroundColor3 = L2_BG_COLOR
		partyPvpUI.partyWindowFrame.BackgroundTransparency = 0.08
		partyPvpUI.partyWindowFrame.BorderSizePixel = 0
		partyPvpUI.partyWindowFrame.Visible = false
		partyPvpUI.partyWindowFrame.Parent = screenGui
		styleL2Frame(partyPvpUI.partyWindowFrame, 5, L2_GOLD_BORDER, 1.6)

		partyPvpUI.partyHeaderLabel = Instance.new("TextLabel")
		partyPvpUI.partyHeaderLabel.Name = "PartyHeader"
		partyPvpUI.partyHeaderLabel.Size = UDim2.new(1, -16, 0, 22)
		partyPvpUI.partyHeaderLabel.Position = UDim2.fromOffset(8, 5)
		partyPvpUI.partyHeaderLabel.BackgroundTransparency = 1
		partyPvpUI.partyHeaderLabel.Font = Enum.Font.GothamBlack
		partyPvpUI.partyHeaderLabel.TextSize = 12
		partyPvpUI.partyHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		partyPvpUI.partyHeaderLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		partyPvpUI.partyHeaderLabel.Text = "Группа / Party (2/5)"
		partyPvpUI.partyHeaderLabel.Parent = partyPvpUI.partyWindowFrame

		table.clear(partyPvpUI.partyRows)
		for rowIdx = 1, 5 do
			local yPos = 29 + (rowIdx - 1) * 52
			local rowBtn = Instance.new("TextButton")
			rowBtn.Name = "PartyMemberRow_" .. tostring(rowIdx)
			rowBtn.Size = UDim2.new(1, -16, 0, 48)
			rowBtn.Position = UDim2.fromOffset(8, yPos)
			rowBtn.BackgroundColor3 = L2_PANEL_COLOR
			rowBtn.BorderSizePixel = 0
			rowBtn.Text = ""
			rowBtn.AutoButtonColor = true
			rowBtn.Visible = false
			rowBtn.Parent = partyPvpUI.partyWindowFrame

			local rCorner = Instance.new("UICorner")
			rCorner.CornerRadius = UDim.new(0, 4)
			rCorner.Parent = rowBtn

			local rStroke = Instance.new("UIStroke")
			rStroke.Color = L2_SUB_BORDER
			rStroke.Thickness = 1.0
			rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rStroke.Parent = rowBtn

			local mName = Instance.new("TextLabel")
			mName.Name = "MemberName"
			mName.Size = UDim2.new(0.62, -6, 0, 16)
			mName.Position = UDim2.fromOffset(6, 3)
			mName.BackgroundTransparency = 1
			mName.Font = Enum.Font.GothamBold
			mName.TextSize = 11
			mName.TextXAlignment = Enum.TextXAlignment.Left
			mName.TextColor3 = Color3.fromRGB(240, 245, 255)
			mName.TextTruncate = Enum.TextTruncate.AtEnd
			mName.Parent = rowBtn

			local mClass = Instance.new("TextLabel")
			mClass.Name = "MemberClass"
			mClass.Size = UDim2.new(0.38, -6, 0, 16)
			mClass.AnchorPoint = Vector2.new(1, 0)
			mClass.Position = UDim2.new(1, -6, 0, 3)
			mClass.BackgroundTransparency = 1
			mClass.Font = Enum.Font.GothamMedium
			mClass.TextSize = 10
			mClass.TextXAlignment = Enum.TextXAlignment.Right
			mClass.TextColor3 = Color3.fromRGB(205, 185, 125)
			mClass.TextTruncate = Enum.TextTruncate.AtEnd
			mClass.Parent = rowBtn

			-- Red HP Bar
			local mHpBg = Instance.new("Frame")
			mHpBg.Name = "MemberHPBg"
			mHpBg.Size = UDim2.new(1, -12, 0, 12)
			mHpBg.Position = UDim2.fromOffset(6, 21)
			mHpBg.BackgroundColor3 = Color3.fromRGB(40, 14, 18)
			mHpBg.BorderSizePixel = 0
			mHpBg.Parent = rowBtn
			styleL2Frame(mHpBg, 2, L2_SUB_BORDER, 0.8)

			local mHpFill = Instance.new("Frame")
			mHpFill.Name = "HPFill"
			mHpFill.Size = UDim2.fromScale(1, 1)
			mHpFill.BackgroundColor3 = Color3.fromRGB(195, 38, 44)
			mHpFill.BorderSizePixel = 0
			mHpFill.Parent = mHpBg

			local mHpTxt = Instance.new("TextLabel")
			mHpTxt.Size = UDim2.fromScale(1, 1)
			mHpTxt.BackgroundTransparency = 1
			mHpTxt.Font = Enum.Font.GothamBold
			mHpTxt.TextSize = 9
			mHpTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
			mHpTxt.TextStrokeTransparency = 0.2
			mHpTxt.Parent = mHpBg

			-- Blue MP Bar
			local mMpBg = Instance.new("Frame")
			mMpBg.Name = "MemberMPBg"
			mMpBg.Size = UDim2.new(1, -12, 0, 8)
			mMpBg.Position = UDim2.fromOffset(6, 36)
			mMpBg.BackgroundColor3 = Color3.fromRGB(14, 24, 48)
			mMpBg.BorderSizePixel = 0
			mMpBg.Parent = rowBtn
			styleL2Frame(mMpBg, 2, L2_SUB_BORDER, 0.8)

			local mMpFill = Instance.new("Frame")
			mMpFill.Name = "MPFill"
			mMpFill.Size = UDim2.fromScale(1, 1)
			mMpFill.BackgroundColor3 = Color3.fromRGB(38, 110, 215)
			mMpFill.BorderSizePixel = 0
			mMpFill.Parent = mMpBg

			rowBtn.Activated:Connect(function()
				local entry = partyPvpUI.partyMembersState[rowIdx]
				if entry and entry.model and entry.model.Parent then
					TargetController.SetTarget(entry.model)
					refreshPartyWindow()
				end
			end)

			partyPvpUI.partyRows[rowIdx] = {
				button = rowBtn,
				stroke = rStroke,
				nameLabel = mName,
				classLabel = mClass,
				hpFill = mHpFill,
				hpText = mHpTxt,
				mpFill = mMpFill,
			}
		end

		partyPvpUI.partyLeaveBtn = Instance.new("TextButton")
		partyPvpUI.partyLeaveBtn.Name = "PartyLeaveBtn"
		partyPvpUI.partyLeaveBtn.Size = UDim2.new(1, -16, 0, 24)
		partyPvpUI.partyLeaveBtn.AnchorPoint = Vector2.new(0, 1)
		partyPvpUI.partyLeaveBtn.Position = UDim2.new(0, 8, 1, -6)
		partyPvpUI.partyLeaveBtn.BackgroundColor3 = Color3.fromRGB(98, 28, 34)
		partyPvpUI.partyLeaveBtn.BorderSizePixel = 0
		partyPvpUI.partyLeaveBtn.Font = Enum.Font.GothamBold
		partyPvpUI.partyLeaveBtn.TextSize = 11
		partyPvpUI.partyLeaveBtn.TextColor3 = Color3.fromRGB(255, 235, 225)
		partyPvpUI.partyLeaveBtn.AutoButtonColor = true
		partyPvpUI.partyLeaveBtn.Text = I18n.t("UI_PARTY_LEAVE_BTN")
		partyPvpUI.partyLeaveBtn.Parent = partyPvpUI.partyWindowFrame
		styleL2Frame(partyPvpUI.partyLeaveBtn, 4, L2_SUB_BORDER, 1.0)

		partyPvpUI.partyLeaveBtn.Activated:Connect(function()
			Remotes.PartyLeave:FireServer()
		end)
	end

	-- =====================================================================
	-- 3. TOP-CENTER: TARGET STATUS FRAME
	-- =====================================================================
	targetFrame = Instance.new("Frame")
	targetFrame.Name = "TargetStatusFrame"
	targetFrame.AnchorPoint = Vector2.new(0.5, 0)
	targetFrame.Position = UDim2.new(0.5, 0, 0, 14)
	targetFrame.Size = UDim2.fromOffset(320, 76)
	targetFrame.BackgroundColor3 = L2_BG_COLOR
	targetFrame.BackgroundTransparency = 0.08
	targetFrame.BorderSizePixel = 0
	targetFrame.Visible = false
	targetFrame.Parent = screenGui
	styleL2Frame(targetFrame, 5, L2_GOLD_BORDER, 1.6)

	targetNameLabel = Instance.new("TextLabel")
	targetNameLabel.Name = "TargetName"
	targetNameLabel.Size = UDim2.new(1, -110, 0, 22)
	targetNameLabel.Position = UDim2.fromOffset(10, 5)
	targetNameLabel.BackgroundTransparency = 1
	targetNameLabel.Font = Enum.Font.GothamBold
	targetNameLabel.TextSize = 14
	targetNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetNameLabel.TextColor3 = Color3.fromRGB(220, 255, 220)
	targetNameLabel.TextStrokeTransparency = 0.2
	targetNameLabel.Parent = targetFrame

	targetStatusTag = Instance.new("TextLabel")
	targetStatusTag.Name = "TargetStatusTag"
	targetStatusTag.Size = UDim2.fromOffset(96, 20)
	targetStatusTag.AnchorPoint = Vector2.new(1, 0)
	targetStatusTag.Position = UDim2.new(1, -8, 0, 6)
	targetStatusTag.BackgroundTransparency = 1
	targetStatusTag.Font = Enum.Font.GothamBlack
	targetStatusTag.TextSize = 11
	targetStatusTag.TextXAlignment = Enum.TextXAlignment.Right
	targetStatusTag.TextColor3 = Color3.fromRGB(0, 235, 255)
	targetStatusTag.Visible = false
	targetStatusTag.Parent = targetFrame

	partyPvpUI.targetPartyInviteBtn = Instance.new("TextButton")
	partyPvpUI.targetPartyInviteBtn.Name = "TargetInvitePartyBtn"
	partyPvpUI.targetPartyInviteBtn.Size = UDim2.new(1, -16, 0, 20)
	partyPvpUI.targetPartyInviteBtn.Position = UDim2.fromOffset(8, 72)
	partyPvpUI.targetPartyInviteBtn.BackgroundColor3 = Color3.fromRGB(32, 95, 145)
	partyPvpUI.targetPartyInviteBtn.BorderSizePixel = 0
	partyPvpUI.targetPartyInviteBtn.Font = Enum.Font.GothamBold
	partyPvpUI.targetPartyInviteBtn.TextSize = 11
	partyPvpUI.targetPartyInviteBtn.TextColor3 = Color3.fromRGB(235, 250, 255)
	partyPvpUI.targetPartyInviteBtn.Visible = false
	partyPvpUI.targetPartyInviteBtn.Text = I18n.t("UI_PARTY_INVITE_BTN")
	partyPvpUI.targetPartyInviteBtn.Parent = targetFrame
	styleL2Frame(partyPvpUI.targetPartyInviteBtn, 3, L2_GOLD_BORDER, 1.0)

	partyPvpUI.targetPartyInviteBtn.Activated:Connect(function()
		local cur = TargetController.GetTarget()
		if not cur or not cur.Parent then
			return
		end
		if
			cur:GetAttribute("IsMob") == true
			or cur:GetAttribute("MobId") ~= nil
			or workshopUI.MobsConfig[cur.Name] ~= nil
		then
			return
		end
		local tPlr = Players:GetPlayerFromCharacter(cur)
		if tPlr and tPlr ~= localPlayer then
			Remotes.PartyInvite:FireServer(tPlr.Name)
		elseif cur:GetAttribute("IsPvpTarget") == true or cur:GetAttribute("IsPartyBot") == true then
			Remotes.PartyInvite:FireServer(cur)
		end
	end)

	-- Party Invitation Popup Banner (Below Target Frame)
	partyPvpUI.partyInvitePopupFrame = Instance.new("Frame")
	partyPvpUI.partyInvitePopupFrame.Name = "PartyInvitePopupFrame"
	partyPvpUI.partyInvitePopupFrame.AnchorPoint = Vector2.new(0.5, 0)
	partyPvpUI.partyInvitePopupFrame.Position = UDim2.new(0.5, 0, 0, 118)
	partyPvpUI.partyInvitePopupFrame.Size = UDim2.fromOffset(320, 62)
	partyPvpUI.partyInvitePopupFrame.BackgroundColor3 = L2_BG_COLOR
	partyPvpUI.partyInvitePopupFrame.BackgroundTransparency = 0.05
	partyPvpUI.partyInvitePopupFrame.BorderSizePixel = 0
	partyPvpUI.partyInvitePopupFrame.Visible = false
	partyPvpUI.partyInvitePopupFrame.ZIndex = 20
	partyPvpUI.partyInvitePopupFrame.Parent = screenGui
	styleL2Frame(partyPvpUI.partyInvitePopupFrame, 5, L2_GOLD_BORDER, 1.6)

	partyPvpUI.partyInviteLabel = Instance.new("TextLabel")
	partyPvpUI.partyInviteLabel.Size = UDim2.new(1, -16, 0, 24)
	partyPvpUI.partyInviteLabel.Position = UDim2.fromOffset(8, 5)
	partyPvpUI.partyInviteLabel.BackgroundTransparency = 1
	partyPvpUI.partyInviteLabel.Font = Enum.Font.GothamBold
	partyPvpUI.partyInviteLabel.TextSize = 12
	partyPvpUI.partyInviteLabel.TextColor3 = Color3.fromRGB(255, 230, 125)
	partyPvpUI.partyInviteLabel.ZIndex = 21
	partyPvpUI.partyInviteLabel.Parent = partyPvpUI.partyInvitePopupFrame

	partyPvpUI.partyInviteAcceptBtn = Instance.new("TextButton")
	partyPvpUI.partyInviteAcceptBtn.Size = UDim2.fromOffset(135, 24)
	partyPvpUI.partyInviteAcceptBtn.Position = UDim2.fromOffset(14, 32)
	partyPvpUI.partyInviteAcceptBtn.BackgroundColor3 = Color3.fromRGB(38, 125, 76)
	partyPvpUI.partyInviteAcceptBtn.BorderSizePixel = 0
	partyPvpUI.partyInviteAcceptBtn.Font = Enum.Font.GothamBold
	partyPvpUI.partyInviteAcceptBtn.TextSize = 11
	partyPvpUI.partyInviteAcceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	partyPvpUI.partyInviteAcceptBtn.ZIndex = 21
	partyPvpUI.partyInviteAcceptBtn.Text = I18n.t("UI_PARTY_ACCEPT")
	partyPvpUI.partyInviteAcceptBtn.Parent = partyPvpUI.partyInvitePopupFrame
	styleL2Frame(partyPvpUI.partyInviteAcceptBtn, 4, L2_SUB_BORDER, 1)

	partyPvpUI.partyInviteDeclineBtn = Instance.new("TextButton")
	partyPvpUI.partyInviteDeclineBtn.Size = UDim2.fromOffset(135, 24)
	partyPvpUI.partyInviteDeclineBtn.Position = UDim2.fromOffset(171, 32)
	partyPvpUI.partyInviteDeclineBtn.BackgroundColor3 = Color3.fromRGB(115, 36, 42)
	partyPvpUI.partyInviteDeclineBtn.BorderSizePixel = 0
	partyPvpUI.partyInviteDeclineBtn.Font = Enum.Font.GothamBold
	partyPvpUI.partyInviteDeclineBtn.TextSize = 11
	partyPvpUI.partyInviteDeclineBtn.TextColor3 = Color3.fromRGB(255, 235, 235)
	partyPvpUI.partyInviteDeclineBtn.ZIndex = 21
	partyPvpUI.partyInviteDeclineBtn.Text = I18n.t("UI_PARTY_DECLINE")
	partyPvpUI.partyInviteDeclineBtn.Parent = partyPvpUI.partyInvitePopupFrame
	styleL2Frame(partyPvpUI.partyInviteDeclineBtn, 4, L2_SUB_BORDER, 1)

	partyPvpUI.partyInviteAcceptBtn.Activated:Connect(function()
		partyPvpUI.partyInvitePopupFrame.Visible = false
		Remotes.PartyRespond:FireServer(true)
	end)
	partyPvpUI.partyInviteDeclineBtn.Activated:Connect(function()
		partyPvpUI.partyInvitePopupFrame.Visible = false
		Remotes.PartyRespond:FireServer(false)
	end)

	local targetHpBg = Instance.new("Frame")
	targetHpBg.Name = "TargetHPBarBg"
	targetHpBg.Size = UDim2.new(1, -16, 0, 18)
	targetHpBg.Position = UDim2.fromOffset(8, 30)
	targetHpBg.BackgroundColor3 = Color3.fromRGB(40, 14, 18)
	targetHpBg.BorderSizePixel = 0
	targetHpBg.Parent = targetFrame
	styleL2Frame(targetHpBg, 3, L2_SUB_BORDER, 1)

	targetHpFill = Instance.new("Frame")
	targetHpFill.Name = "TargetHPFill"
	targetHpFill.Size = UDim2.fromScale(1, 1)
	targetHpFill.BackgroundColor3 = Color3.fromRGB(195, 36, 42)
	targetHpFill.BorderSizePixel = 0
	targetHpFill.Parent = targetHpBg

	targetHpValueLabel = Instance.new("TextLabel")
	targetHpValueLabel.Size = UDim2.fromScale(1, 1)
	targetHpValueLabel.BackgroundTransparency = 1
	targetHpValueLabel.Font = Enum.Font.GothamBold
	targetHpValueLabel.TextSize = 11
	targetHpValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	targetHpValueLabel.TextStrokeTransparency = 0.2
	targetHpValueLabel.Parent = targetHpBg

	local targetMpBg = Instance.new("Frame")
	targetMpBg.Name = "TargetMPBarBg"
	targetMpBg.Size = UDim2.new(1, -16, 0, 14)
	targetMpBg.Position = UDim2.fromOffset(8, 52)
	targetMpBg.BackgroundColor3 = Color3.fromRGB(14, 24, 48)
	targetMpBg.BorderSizePixel = 0
	targetMpBg.Parent = targetFrame
	styleL2Frame(targetMpBg, 3, L2_SUB_BORDER, 1)

	targetMpFill = Instance.new("Frame")
	targetMpFill.Name = "TargetMPFill"
	targetMpFill.Size = UDim2.fromScale(1, 1)
	targetMpFill.BackgroundColor3 = Color3.fromRGB(35, 105, 210)
	targetMpFill.BorderSizePixel = 0
	targetMpFill.Parent = targetMpBg

	targetMpValueLabel = Instance.new("TextLabel")
	targetMpValueLabel.Size = UDim2.fromScale(1, 1)
	targetMpValueLabel.BackgroundTransparency = 1
	targetMpValueLabel.Font = Enum.Font.GothamBold
	targetMpValueLabel.TextSize = 10
	targetMpValueLabel.TextColor3 = Color3.fromRGB(235, 245, 255)
	targetMpValueLabel.TextStrokeTransparency = 0.2
	targetMpValueLabel.Parent = targetMpBg

	-- =====================================================================
	-- 4. TOP-RIGHT: MINIMAP / RADAR
	-- =====================================================================
	local minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "MinimapRadarFrame"
	minimapFrame.AnchorPoint = Vector2.new(1, 0)
	minimapFrame.Position = UDim2.new(1, -16, 0, 16)
	minimapFrame.Size = UDim2.fromOffset(170, 190)
	minimapFrame.BackgroundColor3 = L2_BG_COLOR
	minimapFrame.BackgroundTransparency = 0.08
	minimapFrame.BorderSizePixel = 0
	minimapFrame.Parent = screenGui
	styleL2Frame(minimapFrame, 5, L2_GOLD_BORDER, 1.6)

	minimapLocationLabel = Instance.new("TextLabel")
	minimapLocationLabel.Name = "LocationHeader"
	minimapLocationLabel.Size = UDim2.new(1, -10, 0, 22)
	minimapLocationLabel.Position = UDim2.fromOffset(5, 3)
	minimapLocationLabel.BackgroundTransparency = 1
	minimapLocationLabel.Font = Enum.Font.GothamBold
	minimapLocationLabel.TextSize = 12
	minimapLocationLabel.TextColor3 = Color3.fromRGB(240, 215, 140)
	minimapLocationLabel.Parent = minimapFrame

	minimapCanvas = Instance.new("Frame")
	minimapCanvas.Name = "RadarCanvas"
	minimapCanvas.Size = UDim2.fromOffset(152, 138)
	minimapCanvas.Position = UDim2.fromOffset(9, 26)
	minimapCanvas.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
	minimapCanvas.ClipsDescendants = true
	minimapCanvas.BorderSizePixel = 0
	minimapCanvas.Parent = minimapFrame
	styleL2Frame(minimapCanvas, 4, L2_SUB_BORDER, 1)

	local hLine = Instance.new("Frame")
	hLine.Size = UDim2.new(1, 0, 0, 1)
	hLine.Position = UDim2.fromScale(0, 0.5)
	hLine.BackgroundColor3 = Color3.fromRGB(35, 48, 65)
	hLine.BorderSizePixel = 0
	hLine.Parent = minimapCanvas

	local vLine = Instance.new("Frame")
	vLine.Size = UDim2.new(0, 1, 1, 0)
	vLine.Position = UDim2.fromScale(0.5, 0)
	vLine.BackgroundColor3 = Color3.fromRGB(35, 48, 65)
	vLine.BorderSizePixel = 0
	vLine.Parent = minimapCanvas

	local playerRadarDot = Instance.new("Frame")
	playerRadarDot.Name = "PlayerCenterDot"
	playerRadarDot.Size = UDim2.fromOffset(8, 8)
	playerRadarDot.AnchorPoint = Vector2.new(0.5, 0.5)
	playerRadarDot.Position = UDim2.fromScale(0.5, 0.5)
	playerRadarDot.BackgroundColor3 = Color3.fromRGB(110, 255, 145)
	playerRadarDot.BorderSizePixel = 0
	playerRadarDot.ZIndex = 3
	playerRadarDot.Parent = minimapCanvas
	local pDotCorner = Instance.new("UICorner")
	pDotCorner.CornerRadius = UDim.new(1, 0)
	pDotCorner.Parent = playerRadarDot

	minimapCoordsLabel = Instance.new("TextLabel")
	minimapCoordsLabel.Name = "CoordsFooter"
	minimapCoordsLabel.Size = UDim2.new(1, -10, 0, 20)
	minimapCoordsLabel.Position = UDim2.fromOffset(5, 166)
	minimapCoordsLabel.BackgroundTransparency = 1
	minimapCoordsLabel.Font = Enum.Font.GothamMedium
	minimapCoordsLabel.TextSize = 11
	minimapCoordsLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
	minimapCoordsLabel.Text = "X: 0  Z: 0"
	minimapCoordsLabel.Parent = minimapFrame

	-- =====================================================================
	-- 5. BOTTOM-LEFT: LINEAGE 2 CHAT & SYSTEM COMBAT LOG
	-- =====================================================================
	local chatFrame = Instance.new("Frame")
	chatFrame.Name = "L2ChatSystemLogFrame"
	chatFrame.AnchorPoint = Vector2.new(0, 1)
	chatFrame.Position = UDim2.new(0, 16, 1, -16)
	chatFrame.Size = UDim2.fromOffset(360, 185)
	chatFrame.BackgroundColor3 = L2_BG_COLOR
	chatFrame.BackgroundTransparency = 0.22
	chatFrame.BorderSizePixel = 0
	chatFrame.Parent = screenGui
	styleL2Frame(chatFrame, 5, L2_GOLD_BORDER, 1.5)

	chatScrollFrame = Instance.new("ScrollingFrame")
	chatScrollFrame.Name = "MessageList"
	chatScrollFrame.Size = UDim2.new(1, -12, 1, -38)
	chatScrollFrame.Position = UDim2.fromOffset(6, 6)
	chatScrollFrame.BackgroundTransparency = 1
	chatScrollFrame.BorderSizePixel = 0
	chatScrollFrame.ScrollBarThickness = 4
	chatScrollFrame.ScrollBarImageColor3 = L2_GOLD_BORDER
	chatScrollFrame.CanvasSize = UDim2.fromOffset(0, 0)
	chatScrollFrame.Parent = chatFrame

	chatListLayout = Instance.new("UIListLayout")
	chatListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatListLayout.Padding = UDim.new(0, 3)
	chatListLayout.Parent = chatScrollFrame

	local chatInputBg = Instance.new("Frame")
	chatInputBg.Name = "ChatInputBg"
	chatInputBg.Size = UDim2.new(1, -12, 0, 24)
	chatInputBg.Position = UDim2.new(0, 6, 1, -28)
	chatInputBg.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	chatInputBg.BackgroundTransparency = 0.1
	chatInputBg.BorderSizePixel = 0
	chatInputBg.Parent = chatFrame
	styleL2Frame(chatInputBg, 4, L2_SUB_BORDER, 1)

	chatInputBox = Instance.new("TextBox")
	chatInputBox.Name = "ChatInputBox"
	chatInputBox.Size = UDim2.new(1, -12, 1, 0)
	chatInputBox.Position = UDim2.fromOffset(6, 0)
	chatInputBox.BackgroundTransparency = 1
	chatInputBox.Font = Enum.Font.GothamMedium
	chatInputBox.TextSize = 12
	chatInputBox.TextXAlignment = Enum.TextXAlignment.Left
	chatInputBox.TextColor3 = Color3.fromRGB(245, 245, 245)
	chatInputBox.PlaceholderColor3 = Color3.fromRGB(130, 140, 160)
	chatInputBox.ClearTextOnFocus = false
	chatInputBox.Text = ""
	chatInputBox.Parent = chatInputBg

	chatInputBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			local trimmed = string.gsub(chatInputBox.Text, "^%s*(.-)%s*$", "%1")
			if #trimmed > 0 then
				UIController.AddSystemLog(
					string.format("[%s]: %s", localPlayer.DisplayName, trimmed),
					Color3.fromRGB(245, 245, 255)
				)
				Remotes.SendChatMessage:FireServer(trimmed)
				chatInputBox.Text = ""
			end
		end
	end)

	-- =====================================================================
	-- 6. BOTTOM-CENTER: SKILL HOTBAR (1, Q, E, R, F) + [Z] SOULSHOT SLOT
	-- =====================================================================
	hotbarTooltipFrame = Instance.new("Frame")
	hotbarTooltipFrame.Name = "HotbarSkillTooltip"
	hotbarTooltipFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarTooltipFrame.Position = UDim2.new(0.5, 0, 1, -100)
	hotbarTooltipFrame.Size = UDim2.fromOffset(510, 82)
	hotbarTooltipFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	hotbarTooltipFrame.BackgroundTransparency = 0.04
	hotbarTooltipFrame.BorderSizePixel = 0
	hotbarTooltipFrame.Visible = false
	hotbarTooltipFrame.ZIndex = 50
	hotbarTooltipFrame.Parent = screenGui
	styleL2Frame(hotbarTooltipFrame, 6, L2_GOLD_BORDER, 1.6)

	tooltipTitleLabel = Instance.new("TextLabel")
	tooltipTitleLabel.Name = "TooltipTitle"
	tooltipTitleLabel.Size = UDim2.new(1, -20, 0, 20)
	tooltipTitleLabel.Position = UDim2.fromOffset(10, 6)
	tooltipTitleLabel.BackgroundTransparency = 1
	tooltipTitleLabel.Font = Enum.Font.GothamBlack
	tooltipTitleLabel.TextSize = 13
	tooltipTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipTitleLabel.TextColor3 = Color3.fromRGB(255, 220, 95)
	tooltipTitleLabel.ZIndex = 51
	tooltipTitleLabel.Parent = hotbarTooltipFrame

	tooltipStatsLabel = Instance.new("TextLabel")
	tooltipStatsLabel.Name = "TooltipStats"
	tooltipStatsLabel.Size = UDim2.new(1, -20, 0, 16)
	tooltipStatsLabel.Position = UDim2.fromOffset(10, 26)
	tooltipStatsLabel.BackgroundTransparency = 1
	tooltipStatsLabel.Font = Enum.Font.GothamBold
	tooltipStatsLabel.TextSize = 11
	tooltipStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipStatsLabel.TextColor3 = Color3.fromRGB(135, 210, 255)
	tooltipStatsLabel.ZIndex = 51
	tooltipStatsLabel.Parent = hotbarTooltipFrame

	tooltipDescLabel = Instance.new("TextLabel")
	tooltipDescLabel.Name = "TooltipDesc"
	tooltipDescLabel.Size = UDim2.new(1, -20, 0, 34)
	tooltipDescLabel.Position = UDim2.fromOffset(10, 44)
	tooltipDescLabel.BackgroundTransparency = 1
	tooltipDescLabel.Font = Enum.Font.GothamMedium
	tooltipDescLabel.TextSize = 11
	tooltipDescLabel.TextWrapped = true
	tooltipDescLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipDescLabel.TextYAlignment = Enum.TextYAlignment.Top
	tooltipDescLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	tooltipDescLabel.ZIndex = 51
	tooltipDescLabel.Parent = hotbarTooltipFrame

	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "SkillHotbar"
	hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarFrame.Position = UDim2.new(0.5, 0, 1, -16)
	hotbarFrame.Size = UDim2.fromOffset(796, 78)
	hotbarFrame.BackgroundColor3 = L2_BG_COLOR
	hotbarFrame.BackgroundTransparency = 0.08
	hotbarFrame.BorderSizePixel = 0
	hotbarFrame.Parent = screenGui
	styleL2Frame(hotbarFrame, 6, L2_GOLD_BORDER, 1.6)

	for index, slotKey in ipairs(HOTBAR_SLOT_KEYS) do
		local xOffset = 8 + (index - 1) * 86
		local slotBtn = Instance.new("TextButton")
		slotBtn.Name = "Slot_" .. slotKey
		slotBtn.Size = UDim2.fromOffset(80, 62)
		slotBtn.Position = UDim2.fromOffset(xOffset, 8)
		slotBtn.BackgroundColor3 = L2_PANEL_COLOR
		slotBtn.BorderSizePixel = 0
		slotBtn.Text = ""
		slotBtn.AutoButtonColor = true
		slotBtn.Parent = hotbarFrame
		styleL2Frame(slotBtn, 4, L2_SUB_BORDER, 1.2)

		local keyBadge = Instance.new("TextLabel")
		keyBadge.Name = "KeyBadge"
		keyBadge.Size = UDim2.fromOffset(20, 16)
		keyBadge.Position = UDim2.fromOffset(4, 4)
		keyBadge.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		keyBadge.Font = Enum.Font.GothamBlack
		keyBadge.TextSize = 11
		keyBadge.TextColor3 = Color3.fromRGB(255, 215, 85)
		keyBadge.Text = slotKey
		keyBadge.Parent = slotBtn
		local bCorner = Instance.new("UICorner")
		bCorner.CornerRadius = UDim.new(0, 3)
		bCorner.Parent = keyBadge

		local mpLabel = Instance.new("TextLabel")
		mpLabel.Name = "MPLabel"
		mpLabel.Size = UDim2.fromOffset(50, 14)
		mpLabel.AnchorPoint = Vector2.new(1, 0)
		mpLabel.Position = UDim2.new(1, -4, 0, 5)
		mpLabel.BackgroundTransparency = 1
		mpLabel.Font = Enum.Font.GothamBold
		mpLabel.TextSize = 9
		mpLabel.TextXAlignment = Enum.TextXAlignment.Right
		mpLabel.TextColor3 = Color3.fromRGB(95, 175, 255)
		mpLabel.Parent = slotBtn

		local skillNameLabel = Instance.new("TextLabel")
		skillNameLabel.Name = "SkillName"
		skillNameLabel.Size = UDim2.new(1, -8, 0, 36)
		skillNameLabel.Position = UDim2.fromOffset(4, 22)
		skillNameLabel.BackgroundTransparency = 1
		skillNameLabel.Font = Enum.Font.GothamBold
		skillNameLabel.TextSize = 10
		skillNameLabel.TextWrapped = true
		skillNameLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
		skillNameLabel.Text = slotKey
		skillNameLabel.Parent = slotBtn

		local cdOverlay = Instance.new("Frame")
		cdOverlay.Name = "CooldownOverlay"
		cdOverlay.Size = UDim2.fromScale(1, 0)
		cdOverlay.AnchorPoint = Vector2.new(0, 1)
		cdOverlay.Position = UDim2.fromScale(0, 1)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
		cdOverlay.BackgroundTransparency = 0.28
		cdOverlay.BorderSizePixel = 0
		cdOverlay.Visible = false
		cdOverlay.Parent = slotBtn

		local cdText = Instance.new("TextLabel")
		cdText.Name = "CooldownText"
		cdText.Size = UDim2.fromScale(1, 1)
		cdText.BackgroundTransparency = 1
		cdText.Font = Enum.Font.GothamBlack
		cdText.TextSize = 16
		cdText.TextColor3 = Color3.fromRGB(255, 225, 90)
		cdText.TextStrokeTransparency = 0.1
		cdText.Visible = false
		cdText.Text = ""
		cdText.Parent = slotBtn

		slotBtn.Activated:Connect(function()
			if slotKey == "1" then
				CombatController.RequestBasicAttack()
			else
				CombatController.UseSkillSlot(slotKey :: "Q" | "E" | "R" | "F")
			end
		end)

		slotBtn.MouseEnter:Connect(function()
			hoveredHotbarSlot = slotKey
			refreshHotbarTooltip()
		end)

		slotBtn.MouseLeave:Connect(function()
			if hoveredHotbarSlot == slotKey then
				hoveredHotbarSlot = nil
				refreshHotbarTooltip()
			end
		end)

		table.insert(hotbarSlots, {
			slot = slotKey,
			button = slotBtn,
			nameLabel = skillNameLabel,
			mpLabel = mpLabel,
			cooldownOverlay = cdOverlay,
			cooldownText = cdText,
		})
	end

	-- Divider between Skill Slots and [Z] Soulshot Slot
	local ssDivider = Instance.new("Frame")
	ssDivider.Name = "SoulshotDivider"
	ssDivider.Size = UDim2.fromOffset(2, 54)
	ssDivider.Position = UDim2.fromOffset(438, 12)
	ssDivider.BackgroundColor3 = L2_SUB_BORDER
	ssDivider.BorderSizePixel = 0
	ssDivider.Parent = hotbarFrame

	-- Lineage 2 Iconic [Z] Soulshot / Energy Shots Auto-Toggle Slot
	soulshotButton = Instance.new("TextButton")
	soulshotButton.Name = "Slot_Soulshot_Z"
	soulshotButton.Size = UDim2.fromOffset(84, 62)
	soulshotButton.Position = UDim2.fromOffset(444, 8)
	soulshotButton.BackgroundColor3 = Color3.fromRGB(24, 42, 38)
	soulshotButton.BorderSizePixel = 0
	soulshotButton.Text = ""
	soulshotButton.AutoButtonColor = true
	soulshotButton.Parent = hotbarFrame

	local ssCorner = Instance.new("UICorner")
	ssCorner.CornerRadius = UDim.new(0, 4)
	ssCorner.Parent = soulshotButton

	soulshotStroke = Instance.new("UIStroke")
	soulshotStroke.Color = Color3.fromRGB(95, 255, 135)
	soulshotStroke.Thickness = 2.0
	soulshotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	soulshotStroke.Parent = soulshotButton

	local ssKeyBadge = Instance.new("TextLabel")
	ssKeyBadge.Name = "KeyBadge"
	ssKeyBadge.Size = UDim2.fromOffset(20, 16)
	ssKeyBadge.Position = UDim2.fromOffset(4, 4)
	ssKeyBadge.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	ssKeyBadge.Font = Enum.Font.GothamBlack
	ssKeyBadge.TextSize = 11
	ssKeyBadge.TextColor3 = Color3.fromRGB(0, 240, 255)
	ssKeyBadge.Text = "Z"
	ssKeyBadge.Parent = soulshotButton
	local ssbCorner = Instance.new("UICorner")
	ssbCorner.CornerRadius = UDim.new(0, 3)
	ssbCorner.Parent = ssKeyBadge

	soulshotStatusBadge = Instance.new("TextLabel")
	soulshotStatusBadge.Name = "AutoStatusBadge"
	soulshotStatusBadge.Size = UDim2.fromOffset(54, 14)
	soulshotStatusBadge.AnchorPoint = Vector2.new(1, 0)
	soulshotStatusBadge.Position = UDim2.new(1, -4, 0, 5)
	soulshotStatusBadge.BackgroundTransparency = 1
	soulshotStatusBadge.Font = Enum.Font.GothamBlack
	soulshotStatusBadge.TextSize = 9
	soulshotStatusBadge.TextXAlignment = Enum.TextXAlignment.Right
	soulshotStatusBadge.TextColor3 = Color3.fromRGB(95, 255, 135)
	soulshotStatusBadge.Text = "AUTO ON"
	soulshotStatusBadge.Parent = soulshotButton

	soulshotTitleLabel = Instance.new("TextLabel")
	soulshotTitleLabel.Name = "SoulshotTitle"
	soulshotTitleLabel.Size = UDim2.new(1, -8, 0, 18)
	soulshotTitleLabel.Position = UDim2.fromOffset(4, 22)
	soulshotTitleLabel.BackgroundTransparency = 1
	soulshotTitleLabel.Font = Enum.Font.GothamBold
	soulshotTitleLabel.TextSize = 10
	soulshotTitleLabel.TextColor3 = Color3.fromRGB(235, 245, 255)
	soulshotTitleLabel.Text = "Shots"
	soulshotTitleLabel.Parent = soulshotButton

	soulshotCountLabel = Instance.new("TextLabel")
	soulshotCountLabel.Name = "SoulshotCount"
	soulshotCountLabel.Size = UDim2.new(1, -8, 0, 20)
	soulshotCountLabel.Position = UDim2.fromOffset(4, 39)
	soulshotCountLabel.BackgroundTransparency = 1
	soulshotCountLabel.Font = Enum.Font.GothamBlack
	soulshotCountLabel.TextSize = 13
	soulshotCountLabel.TextColor3 = Color3.fromRGB(130, 245, 255)
	soulshotCountLabel.Text = "x150"
	soulshotCountLabel.Parent = soulshotButton

	soulshotButton.Activated:Connect(function()
		Remotes.ToggleAutoSoulshot:FireServer()
	end)

	soulshotButton.MouseEnter:Connect(function()
		hoveredHotbarSlot = "Z"
		refreshHotbarTooltip()
	end)

	soulshotButton.MouseLeave:Connect(function()
		if hoveredHotbarSlot == "Z" then
			hoveredHotbarSlot = nil
			refreshHotbarTooltip()
		end
	end)

	-- Helper to build Consumable Potion Slots ([2] HP Potion & [3] MP Potion)
	local function createPotionSlot(
		name: string,
		keyText: string,
		xPos: number,
		bgColor: Color3,
		borderColor: Color3,
		badgeColor: Color3,
		potionType: "HP" | "MP"
	): (TextButton, TextLabel, TextLabel, Frame, TextLabel)
		local pBtn = Instance.new("TextButton")
		pBtn.Name = name
		pBtn.Size = UDim2.fromOffset(80, 62)
		pBtn.Position = UDim2.fromOffset(xPos, 8)
		pBtn.BackgroundColor3 = bgColor
		pBtn.BorderSizePixel = 0
		pBtn.Text = ""
		pBtn.AutoButtonColor = true
		pBtn.Parent = hotbarFrame
		styleL2Frame(pBtn, 4, borderColor, 1.5)

		local pKeyBadge = Instance.new("TextLabel")
		pKeyBadge.Name = "KeyBadge"
		pKeyBadge.Size = UDim2.fromOffset(20, 16)
		pKeyBadge.Position = UDim2.fromOffset(4, 4)
		pKeyBadge.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
		pKeyBadge.Font = Enum.Font.GothamBlack
		pKeyBadge.TextSize = 11
		pKeyBadge.TextColor3 = badgeColor
		pKeyBadge.Text = keyText
		pKeyBadge.Parent = pBtn
		local pkCorner = Instance.new("UICorner")
		pkCorner.CornerRadius = UDim.new(0, 3)
		pkCorner.Parent = pKeyBadge

		local pTypeTag = Instance.new("TextLabel")
		pTypeTag.Name = "PotionTypeTag"
		pTypeTag.Size = UDim2.fromOffset(48, 14)
		pTypeTag.AnchorPoint = Vector2.new(1, 0)
		pTypeTag.Position = UDim2.new(1, -4, 0, 5)
		pTypeTag.BackgroundTransparency = 1
		pTypeTag.Font = Enum.Font.GothamBlack
		pTypeTag.TextSize = 9
		pTypeTag.TextXAlignment = Enum.TextXAlignment.Right
		pTypeTag.TextColor3 = badgeColor
		pTypeTag.Text = if potionType == "HP" then "+35% HP" else "+35% MP"
		pTypeTag.Parent = pBtn

		local pTitle = Instance.new("TextLabel")
		pTitle.Name = "PotionTitle"
		pTitle.Size = UDim2.new(1, -8, 0, 18)
		pTitle.Position = UDim2.fromOffset(4, 22)
		pTitle.BackgroundTransparency = 1
		pTitle.Font = Enum.Font.GothamBold
		pTitle.TextSize = 10
		pTitle.TextColor3 = Color3.fromRGB(235, 245, 255)
		pTitle.Text = potionType
		pTitle.Parent = pBtn

		local pCount = Instance.new("TextLabel")
		pCount.Name = "PotionCount"
		pCount.Size = UDim2.new(1, -8, 0, 20)
		pCount.Position = UDim2.fromOffset(4, 39)
		pCount.BackgroundTransparency = 1
		pCount.Font = Enum.Font.GothamBlack
		pCount.TextSize = 13
		pCount.TextColor3 = badgeColor
		pCount.Text = "x10"
		pCount.Parent = pBtn

		local cdOverlay = Instance.new("Frame")
		cdOverlay.Name = "CooldownOverlay"
		cdOverlay.Size = UDim2.fromScale(1, 0)
		cdOverlay.AnchorPoint = Vector2.new(0, 1)
		cdOverlay.Position = UDim2.fromScale(0, 1)
		cdOverlay.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
		cdOverlay.BackgroundTransparency = 0.28
		cdOverlay.BorderSizePixel = 0
		cdOverlay.Visible = false
		cdOverlay.Parent = pBtn

		local cdText = Instance.new("TextLabel")
		cdText.Name = "CooldownText"
		cdText.Size = UDim2.fromScale(1, 1)
		cdText.BackgroundTransparency = 1
		cdText.Font = Enum.Font.GothamBlack
		cdText.TextSize = 16
		cdText.TextColor3 = Color3.fromRGB(255, 225, 90)
		cdText.TextStrokeTransparency = 0.1
		cdText.Visible = false
		cdText.Text = ""
		cdText.Parent = pBtn

		pBtn.Activated:Connect(function()
			Remotes.UsePotion:FireServer(potionType)
		end)

		pBtn.MouseEnter:Connect(function()
			hoveredHotbarSlot = keyText
			refreshHotbarTooltip()
		end)

		pBtn.MouseLeave:Connect(function()
			if hoveredHotbarSlot == keyText then
				hoveredHotbarSlot = nil
				refreshHotbarTooltip()
			end
		end)

		return pBtn, pTitle, pCount, cdOverlay, cdText
	end

	hpPotionButton, hpPotionTitleLabel, hpPotionCountLabel, hpPotionCooldownOverlay, hpPotionCooldownText =
		createPotionSlot(
			"Slot_Potion_HP_2",
			"2",
			536,
			Color3.fromRGB(42, 20, 26),
			Color3.fromRGB(215, 70, 85),
			Color3.fromRGB(115, 255, 145),
			"HP"
		)

	mpPotionButton, mpPotionTitleLabel, mpPotionCountLabel, mpPotionCooldownOverlay, mpPotionCooldownText =
		createPotionSlot(
			"Slot_Potion_MP_3",
			"3",
			622,
			Color3.fromRGB(18, 30, 52),
			Color3.fromRGB(55, 155, 245),
			Color3.fromRGB(110, 225, 255),
			"MP"
		)

	-- Lineage 2 Force-Attack / PvP Toggle Slot ([Left Ctrl] or Click)
	partyPvpUI.pvpForceButton = Instance.new("TextButton")
	partyPvpUI.pvpForceButton.Name = "Slot_PvpForce_Ctrl"
	partyPvpUI.pvpForceButton.Size = UDim2.fromOffset(80, 62)
	partyPvpUI.pvpForceButton.Position = UDim2.fromOffset(708, 8)
	partyPvpUI.pvpForceButton.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
	partyPvpUI.pvpForceButton.BorderSizePixel = 0
	partyPvpUI.pvpForceButton.Text = ""
	partyPvpUI.pvpForceButton.AutoButtonColor = true
	partyPvpUI.pvpForceButton.Parent = hotbarFrame

	local pvpCorner = Instance.new("UICorner")
	pvpCorner.CornerRadius = UDim.new(0, 4)
	pvpCorner.Parent = partyPvpUI.pvpForceButton

	partyPvpUI.pvpForceStroke = Instance.new("UIStroke")
	partyPvpUI.pvpForceStroke.Color = L2_SUB_BORDER
	partyPvpUI.pvpForceStroke.Thickness = 1.2
	partyPvpUI.pvpForceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	partyPvpUI.pvpForceStroke.Parent = partyPvpUI.pvpForceButton

	local pvpKeyBadge = Instance.new("TextLabel")
	pvpKeyBadge.Name = "KeyBadge"
	pvpKeyBadge.Size = UDim2.fromOffset(34, 15)
	pvpKeyBadge.Position = UDim2.fromOffset(4, 4)
	pvpKeyBadge.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	pvpKeyBadge.Font = Enum.Font.GothamBlack
	pvpKeyBadge.TextSize = 9
	pvpKeyBadge.TextColor3 = Color3.fromRGB(215, 130, 255)
	pvpKeyBadge.Text = "CTRL"
	pvpKeyBadge.Parent = partyPvpUI.pvpForceButton
	local pvpbCorner = Instance.new("UICorner")
	pvpbCorner.CornerRadius = UDim.new(0, 3)
	pvpbCorner.Parent = pvpKeyBadge

	partyPvpUI.pvpForceLabel = Instance.new("TextLabel")
	partyPvpUI.pvpForceLabel.Name = "PvpLabel"
	partyPvpUI.pvpForceLabel.Size = UDim2.new(1, -8, 0, 36)
	partyPvpUI.pvpForceLabel.Position = UDim2.fromOffset(4, 22)
	partyPvpUI.pvpForceLabel.BackgroundTransparency = 1
	partyPvpUI.pvpForceLabel.Font = Enum.Font.GothamBlack
	partyPvpUI.pvpForceLabel.TextSize = 10
	partyPvpUI.pvpForceLabel.TextWrapped = true
	partyPvpUI.pvpForceLabel.TextColor3 = Color3.fromRGB(190, 198, 215)
	partyPvpUI.pvpForceLabel.Text = I18n.t("UI_PVP_BTN_OFF")
	partyPvpUI.pvpForceLabel.Parent = partyPvpUI.pvpForceButton

	partyPvpUI.pvpForceButton.Activated:Connect(function()
		CombatController.TogglePvpForceMode()
		refreshPvpToggleVisuals()
		refreshHotbarTooltip()
	end)

	partyPvpUI.pvpForceButton.MouseEnter:Connect(function()
		hoveredHotbarSlot = "PVP"
		refreshHotbarTooltip()
	end)

	partyPvpUI.pvpForceButton.MouseLeave:Connect(function()
		if hoveredHotbarSlot == "PVP" then
			hoveredHotbarSlot = nil
			refreshHotbarTooltip()
		end
	end)

	-- =====================================================================
	-- 7. BOTTOM-RIGHT: SYSTEM & INVENTORY MENU BUTTONS (2x2 Grid, Positioned at Bottom Edge)
	-- =====================================================================
	local menuBarFrame = Instance.new("Frame")
	menuBarFrame.Name = "SystemMenuButtons"
	menuBarFrame.AnchorPoint = Vector2.new(1, 1)
	menuBarFrame.Position = UDim2.new(1, -12, 1, -2)
	menuBarFrame.Size = UDim2.fromOffset(236, 56)
	menuBarFrame.BackgroundColor3 = L2_BG_COLOR
	menuBarFrame.BackgroundTransparency = 0.08
	menuBarFrame.BorderSizePixel = 0
	menuBarFrame.Parent = screenGui
	styleL2Frame(menuBarFrame, 6, L2_GOLD_BORDER, 1.6)

	local function createMenuButton(name: string, pos: UDim2): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.fromOffset(108, 22)
		btn.Position = pos
		btn.BackgroundColor3 = L2_PANEL_COLOR
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = Color3.fromRGB(240, 225, 185)
		btn.AutoButtonColor = true
		btn.Parent = menuBarFrame
		styleL2Frame(btn, 4, L2_SUB_BORDER, 1.1)
		return btn
	end

	btnInventory = createMenuButton("BtnInventory", UDim2.fromOffset(8, 4))
	btnJob = createMenuButton("BtnJob", UDim2.fromOffset(120, 4))
	btnStats = createMenuButton("BtnStats", UDim2.fromOffset(8, 29))
	btnLang = createMenuButton("BtnLang", UDim2.fromOffset(120, 29))

	-- =====================================================================
	-- MODALS: [I] Inventory, [C] Stats, [J] Job & Subclass Dossier
	-- (Multi-Window + Draggable by TitleBar + Floating Item Drag Ghost)
	-- =====================================================================
	do
		local ghost = Instance.new("Frame")
		ghost.Name = "ItemDragGhostPreview"
		ghost.Size = UDim2.fromOffset(46, 46)
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		ghost.BackgroundTransparency = 0.1
		ghost.BorderSizePixel = 0
		ghost.Visible = false
		ghost.ZIndex = 95
		ghost.Parent = screenGui

		local gCorner = Instance.new("UICorner")
		gCorner.CornerRadius = UDim.new(0, 4)
		gCorner.Parent = ghost

		local gGrad = Instance.new("UIGradient")
		gGrad.Rotation = 90
		gGrad.Parent = ghost

		local gStroke = Instance.new("UIStroke")
		gStroke.Color = Color3.fromRGB(255, 225, 85)
		gStroke.Thickness = 2.0
		gStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		gStroke.Parent = ghost

		local gGlyph = Instance.new("TextLabel")
		gGlyph.Size = UDim2.fromScale(1, 1)
		gGlyph.BackgroundTransparency = 1
		gGlyph.Font = Enum.Font.GothamBlack
		gGlyph.TextSize = 21
		gGlyph.TextColor3 = Color3.fromRGB(255, 255, 255)
		gGlyph.ZIndex = 96
		gGlyph.Parent = ghost

		local gGrade = Instance.new("TextLabel")
		gGrade.Size = UDim2.fromOffset(22, 13)
		gGrade.AnchorPoint = Vector2.new(1, 0)
		gGrade.Position = UDim2.new(1, -2, 0, 1)
		gGrade.BackgroundTransparency = 1
		gGrade.Font = Enum.Font.GothamBlack
		gGrade.TextSize = 9
		gGrade.TextXAlignment = Enum.TextXAlignment.Right
		gGrade.TextColor3 = Color3.fromRGB(95, 225, 255)
		gGrade.ZIndex = 97
		gGrade.Parent = ghost

		workshopUI.dragGhostFrame = ghost
		workshopUI.dragGhostGrad = gGrad
		workshopUI.dragGhostStroke = gStroke
		workshopUI.dragGhostGlyph = gGlyph
		workshopUI.dragGhostGrade = gGrade
	end

	table.clear(workshopUI.windowFocusOrder)

	workshopUI.bringWindowToFront = function(targetModal: Frame)
		if not targetModal then
			return
		end
		local orderList = workshopUI.windowFocusOrder
		for i = #orderList, 1, -1 do
			if orderList[i] == targetModal then
				table.remove(orderList, i)
			end
		end
		table.insert(orderList, targetModal)

		for idx, winFrame in ipairs(orderList) do
			local baseZ = 10 + (idx - 1) * 20
			winFrame.ZIndex = baseZ
			winFrame.LayoutOrder = idx
			for _, desc in ipairs(winFrame:GetDescendants()) do
				if desc:IsA("GuiObject") then
					local origOffset = desc:GetAttribute("BaseZOffset") :: number?
					if origOffset == nil then
						origOffset = math.clamp(desc.ZIndex - 10, 1, 18)
						desc:SetAttribute("BaseZOffset", origOffset)
					end
					desc.ZIndex = baseZ + origOffset
				end
			end
		end
	end

	local function createBaseModal(name: string, size: UDim2, defaultPos: UDim2?): (Frame, TextLabel, TextButton)
		local modal = Instance.new("Frame")
		modal.Name = name
		modal.Size = size
		modal.AnchorPoint = Vector2.new(0.5, 0.5)
		modal.Position = defaultPos or UDim2.fromScale(0.5, 0.5)
		modal.BackgroundColor3 = L2_BG_COLOR
		modal.BackgroundTransparency = 0.04
		modal.BorderSizePixel = 0
		modal.Visible = false
		modal.Active = true
		modal.ZIndex = 10
		modal.Parent = screenGui
		styleL2Frame(modal, 7, L2_GOLD_BORDER, 2)
		table.insert(workshopUI.windowFocusOrder, modal)

		modal.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
			then
				if workshopUI.bringWindowToFront then
					workshopUI.bringWindowToFront(modal)
				end
			end
		end)

		local titleBarBg = Instance.new("Frame")
		titleBarBg.Name = "TitleBarDragHandle"
		titleBarBg.Size = UDim2.new(1, -96, 0, 38)
		titleBarBg.Position = UDim2.fromOffset(4, 4)
		titleBarBg.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
		titleBarBg.BackgroundTransparency = 0.35
		titleBarBg.BorderSizePixel = 0
		titleBarBg.Active = true
		titleBarBg.ZIndex = 11
		titleBarBg.Parent = modal
		local tbCorner = Instance.new("UICorner")
		tbCorner.CornerRadius = UDim.new(0, 5)
		tbCorner.Parent = titleBarBg

		titleBarBg.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if workshopUI.bringWindowToFront then
					workshopUI.bringWindowToFront(modal)
				end
				workshopUI.draggingWindow = modal
				workshopUI.windowDragStartMouse = Vector2.new(input.Position.X, input.Position.Y)
				local absPos = modal.AbsolutePosition
				local absSize = modal.AbsoluteSize
				workshopUI.windowDragStartPos = Vector2.new(
					absPos.X + absSize.X * modal.AnchorPoint.X,
					absPos.Y + absSize.Y * modal.AnchorPoint.Y
				)
			end
		end)

		local title = Instance.new("TextLabel")
		title.Name = "WindowTitleLabel"
		title.Size = UDim2.new(1, -20, 0, 28)
		title.Position = UDim2.fromOffset(10, 5)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 16
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(255, 220, 105)
		title.ZIndex = 12
		title.Parent = titleBarBg

		local closeBtn = Instance.new("TextButton")
		closeBtn.Name = "WindowCloseBtn"
		closeBtn.Size = UDim2.fromOffset(76, 26)
		closeBtn.AnchorPoint = Vector2.new(1, 0)
		closeBtn.Position = UDim2.new(1, -12, 0, 10)
		closeBtn.BackgroundColor3 = Color3.fromRGB(135, 38, 42)
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 12
		closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		closeBtn.AutoButtonColor = true
		closeBtn.ZIndex = 14
		closeBtn.Parent = modal
		styleL2Frame(closeBtn, 4, L2_SUB_BORDER, 1)

		closeBtn.Activated:Connect(function()
			modal.Visible = false
		end)

		return modal, title, closeBtn
	end

	-- =====================================================================
	-- [I] LINEAGE 2 HIGH FIVE INVENTORY WINDOW (PAPERDOLL + 9x6 BAG GRID)
	-- =====================================================================
	inventoryModal, inventoryTitleLabel, inventoryCloseBtn =
		createBaseModal("InventoryModal", UDim2.fromOffset(644, 436), UDim2.new(0.56, 0, 0.48, 0))

	inventoryCloseBtn.Activated:Connect(function()
		hoveredTooltipData = nil
		if itemTooltipFrame then
			itemTooltipFrame.Visible = false
		end
	end)

	-- Floating L2 Item Tooltip inside Inventory
	itemTooltipFrame = Instance.new("Frame")
	itemTooltipFrame.Name = "ItemHoverTooltip"
	itemTooltipFrame.Size = UDim2.fromOffset(420, 102)
	itemTooltipFrame.AnchorPoint = Vector2.new(0.5, 1)
	itemTooltipFrame.Position = UDim2.new(0.5, 0, 0, -6)
	itemTooltipFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	itemTooltipFrame.BackgroundTransparency = 0.03
	itemTooltipFrame.BorderSizePixel = 0
	itemTooltipFrame.Visible = false
	itemTooltipFrame.ZIndex = 45
	itemTooltipFrame.Parent = inventoryModal
	styleL2Frame(itemTooltipFrame, 5, L2_GOLD_BORDER, 1.6)

	itemTooltipTitleLabel = Instance.new("TextLabel")
	itemTooltipTitleLabel.Size = UDim2.new(1, -20, 0, 20)
	itemTooltipTitleLabel.Position = UDim2.fromOffset(10, 5)
	itemTooltipTitleLabel.BackgroundTransparency = 1
	itemTooltipTitleLabel.Font = Enum.Font.GothamBlack
	itemTooltipTitleLabel.TextSize = 13
	itemTooltipTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemTooltipTitleLabel.TextColor3 = Color3.fromRGB(255, 220, 95)
	itemTooltipTitleLabel.ZIndex = 46
	itemTooltipTitleLabel.Parent = itemTooltipFrame

	itemTooltipMetaLabel = Instance.new("TextLabel")
	itemTooltipMetaLabel.Size = UDim2.new(1, -20, 0, 16)
	itemTooltipMetaLabel.Position = UDim2.fromOffset(10, 25)
	itemTooltipMetaLabel.BackgroundTransparency = 1
	itemTooltipMetaLabel.Font = Enum.Font.GothamBold
	itemTooltipMetaLabel.TextSize = 11
	itemTooltipMetaLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemTooltipMetaLabel.TextColor3 = Color3.fromRGB(185, 200, 225)
	itemTooltipMetaLabel.ZIndex = 46
	itemTooltipMetaLabel.Parent = itemTooltipFrame

	itemTooltipBonusesLabel = Instance.new("TextLabel")
	itemTooltipBonusesLabel.Size = UDim2.new(1, -20, 0, 18)
	itemTooltipBonusesLabel.Position = UDim2.fromOffset(10, 42)
	itemTooltipBonusesLabel.BackgroundTransparency = 1
	itemTooltipBonusesLabel.Font = Enum.Font.GothamBold
	itemTooltipBonusesLabel.TextSize = 11
	itemTooltipBonusesLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemTooltipBonusesLabel.TextColor3 = Color3.fromRGB(115, 250, 155)
	itemTooltipBonusesLabel.ZIndex = 46
	itemTooltipBonusesLabel.Parent = itemTooltipFrame

	itemTooltipDescLabel = Instance.new("TextLabel")
	itemTooltipDescLabel.Size = UDim2.new(1, -20, 0, 36)
	itemTooltipDescLabel.Position = UDim2.fromOffset(10, 60)
	itemTooltipDescLabel.BackgroundTransparency = 1
	itemTooltipDescLabel.Font = Enum.Font.GothamMedium
	itemTooltipDescLabel.TextSize = 10
	itemTooltipDescLabel.TextWrapped = true
	itemTooltipDescLabel.TextXAlignment = Enum.TextXAlignment.Left
	itemTooltipDescLabel.TextYAlignment = Enum.TextYAlignment.Top
	itemTooltipDescLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
	itemTooltipDescLabel.ZIndex = 46
	itemTooltipDescLabel.Parent = itemTooltipFrame

	-- =====================================================================
	-- LEFT PANEL: CLASSIC L2 PAPERDOLL 3-COLUMN SLOT GRID (166 px width)
	-- =====================================================================
	local leftPaperdollPanel = Instance.new("Frame")
	leftPaperdollPanel.Name = "L2PaperdollPanel"
	leftPaperdollPanel.Size = UDim2.fromOffset(166, 382)
	leftPaperdollPanel.Position = UDim2.fromOffset(10, 44)
	leftPaperdollPanel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	leftPaperdollPanel.BorderSizePixel = 0
	leftPaperdollPanel.ZIndex = 11
	leftPaperdollPanel.Parent = inventoryModal
	styleL2Frame(leftPaperdollPanel, 5, Color3.fromRGB(125, 102, 62), 1.3)
	workshopUI.leftPaperdollPanel = leftPaperdollPanel

	local function createPaperdollCell(
		cellName: string,
		xPos: number,
		yPos: number,
		emptySilhouette: string,
		activeSlotName: string?
	)
		local btn = Instance.new("TextButton")
		btn.Name = "Paperdoll_" .. cellName
		btn.Size = UDim2.fromOffset(46, 46)
		btn.Position = UDim2.fromOffset(xPos, yPos)
		btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = activeSlotName ~= nil
		btn.ZIndex = 12
		btn.Parent = leftPaperdollPanel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = btn

		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Color = ColorSequence.new(
			if activeSlotName then Color3.fromRGB(22, 25, 34) else Color3.fromRGB(14, 16, 22),
			Color3.fromRGB(9, 10, 15)
		)
		grad.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = if activeSlotName
			then Color3.fromRGB(85, 72, 48)
			else Color3.fromRGB(38, 35, 28)
		stroke.Thickness = 1.0
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		local glyphLbl = Instance.new("TextLabel")
		glyphLbl.Name = "Glyph"
		glyphLbl.Size = UDim2.fromScale(1, 1)
		glyphLbl.BackgroundTransparency = 1
		glyphLbl.Font = Enum.Font.GothamBlack
		glyphLbl.TextSize = 20
		glyphLbl.TextColor3 = Color3.fromRGB(75, 82, 98)
		glyphLbl.TextTransparency = if activeSlotName then 0.45 else 0.72
		glyphLbl.Text = emptySilhouette
		glyphLbl.ZIndex = 13
		glyphLbl.Parent = btn

		local tlBadge = Instance.new("TextLabel")
		tlBadge.Name = "TopLeftEnchant"
		tlBadge.Size = UDim2.fromOffset(26, 13)
		tlBadge.Position = UDim2.fromOffset(2, 1)
		tlBadge.BackgroundTransparency = 1
		tlBadge.Font = Enum.Font.GothamBlack
		tlBadge.TextSize = 9
		tlBadge.TextXAlignment = Enum.TextXAlignment.Left
		tlBadge.TextColor3 = Color3.fromRGB(255, 220, 85)
		tlBadge.TextStrokeTransparency = 0.15
		tlBadge.Visible = false
		tlBadge.ZIndex = 14
		tlBadge.Parent = btn

		local trBadge = Instance.new("TextLabel")
		trBadge.Name = "TopRightGrade"
		trBadge.Size = UDim2.fromOffset(22, 13)
		trBadge.AnchorPoint = Vector2.new(1, 0)
		trBadge.Position = UDim2.new(1, -2, 0, 1)
		trBadge.BackgroundTransparency = 1
		trBadge.Font = Enum.Font.GothamBlack
		trBadge.TextSize = 9
		trBadge.TextXAlignment = Enum.TextXAlignment.Right
		trBadge.TextColor3 = Color3.fromRGB(95, 220, 255)
		trBadge.TextStrokeTransparency = 0.15
		trBadge.Visible = false
		trBadge.ZIndex = 14
		trBadge.Parent = btn

		if activeSlotName then
			local slotKey = activeSlotName
			local function unequipThisSlot()
				local eqMap = clientProfile.EquippedItems :: { [string]: string? }
				if eqMap[slotKey] then
					Remotes.UnequipItem:FireServer(slotKey)
				end
			end

			btn.Activated:Connect(unequipThisSlot)
			btn.MouseButton2Click:Connect(unequipThisSlot)

			btn.MouseEnter:Connect(function()
				local eqMap = clientProfile.EquippedItems :: { [string]: string? }
				local eqId = eqMap[slotKey]
				local itemData = ItemsConfig.GetItem(eqId)
				if itemData then
					hoveredTooltipData = buildTooltipDataForItemData(itemData, true)
				else
					local slotNameKey = ItemsConfig.SLOT_NAME_KEYS[slotKey] or "UI_SLOT_WEAPON"
					hoveredTooltipData = {
						title = string.format("%s %s", I18n.t(slotNameKey), I18n.t("UI_SLOT_EMPTY")),
						titleColor = Color3.fromRGB(165, 175, 195),
						meta = I18n.t(slotNameKey),
						bonuses = "-",
						desc = I18n.t("UI_INV_HINT_INTERACT"),
					}
				end
				refreshItemTooltip()
			end)

			btn.MouseLeave:Connect(function()
				hoveredTooltipData = nil
				refreshItemTooltip()
			end)

			paperdollCells[slotKey] = {
				slotName = slotKey,
				emptyGlyph = emptySilhouette,
				button = btn,
				gradient = grad,
				stroke = stroke,
				glyphLabel = glyphLbl,
				topLeftBadge = tlBadge,
				topRightBadge = trBadge,
			}
		end
	end

	local function createPaperdollDivider(yPos: number)
		local div = Instance.new("Frame")
		div.Size = UDim2.new(1, -16, 0, 1)
		div.Position = UDim2.fromOffset(8, yPos)
		div.BackgroundColor3 = Color3.fromRGB(115, 95, 58)
		div.BorderSizePixel = 0
		div.ZIndex = 12
		div.Parent = leftPaperdollPanel
	end

	-- Block 1: Armor Block (3x3 Grid)
	-- Row 1: Hair1 | Head | Hair2
	createPaperdollCell("Hair1", 10, 8, "👑", nil)
	createPaperdollCell("Head", 60, 8, "🪖", nil)
	createPaperdollCell("Hair2", 110, 8, "🎭", nil)
	-- Row 2: Underwear | Chest (Active) | Cloak
	createPaperdollCell("Underwear", 10, 58, "👕", nil)
	createPaperdollCell("Chest", 60, 58, "🧥", "Chest")
	createPaperdollCell("Cloak", 110, 58, "🧣", nil)
	-- Row 3: Gloves | Legs (Active) | Boots (Active)
	createPaperdollCell("Gloves", 10, 108, "🧤", nil)
	createPaperdollCell("Legs", 60, 108, "👖", "Legs")
	createPaperdollCell("Boots", 110, 108, "🥾", "Boots")

	createPaperdollDivider(159)

	-- Block 2: Weapon Block (1x3 Grid: Weapon [Active] | Belt | Shield)
	createPaperdollCell("Weapon", 10, 165, "⚔", "Weapon")
	createPaperdollCell("Belt", 60, 165, "🎗", nil)
	createPaperdollCell("Shield", 110, 165, "🛡", nil)

	createPaperdollDivider(216)

	-- Block 3: Jewelry Block (2x3 Grid)
	-- Row 1: Earring1 | Accessory1 (Necklace/Watch Active) | Earring2
	createPaperdollCell("Earring1", 10, 222, "✧", nil)
	createPaperdollCell("Accessory1", 60, 222, "⌚", "Accessory1")
	createPaperdollCell("Earring2", 110, 222, "✧", nil)
	-- Row 2: Accessory2 (Ring Active) | Bracelet | Ring2
	createPaperdollCell("Accessory2", 10, 272, "💍", "Accessory2")
	createPaperdollCell("Bracelet", 60, 272, "⚙", nil)
	createPaperdollCell("Ring2", 110, 272, "💍", nil)

	createPaperdollDivider(323)

	invGearBonusesSummaryLabel = Instance.new("TextLabel")
	invGearBonusesSummaryLabel.Name = "GearBonusesSummary"
	invGearBonusesSummaryLabel.Size = UDim2.new(1, -14, 0, 50)
	invGearBonusesSummaryLabel.Position = UDim2.fromOffset(7, 327)
	invGearBonusesSummaryLabel.BackgroundTransparency = 1
	invGearBonusesSummaryLabel.Font = Enum.Font.GothamBold
	invGearBonusesSummaryLabel.TextSize = 10
	invGearBonusesSummaryLabel.TextWrapped = true
	invGearBonusesSummaryLabel.TextXAlignment = Enum.TextXAlignment.Center
	invGearBonusesSummaryLabel.TextYAlignment = Enum.TextYAlignment.Center
	invGearBonusesSummaryLabel.TextColor3 = Color3.fromRGB(120, 245, 155)
	invGearBonusesSummaryLabel.ZIndex = 12
	invGearBonusesSummaryLabel.Parent = leftPaperdollPanel

	-- =====================================================================
	-- RIGHT PANEL: L2 TABS + 9x6 SQUARE BAG GRID + WORKSHOP + ADENA BAR
	-- =====================================================================
	local rightBagPanel = Instance.new("Frame")
	rightBagPanel.Name = "L2BagAndTabsPanel"
	rightBagPanel.Size = UDim2.fromOffset(448, 382)
	rightBagPanel.Position = UDim2.fromOffset(184, 44)
	rightBagPanel.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
	rightBagPanel.BorderSizePixel = 0
	rightBagPanel.ZIndex = 11
	rightBagPanel.Parent = inventoryModal
	styleL2Frame(rightBagPanel, 5, Color3.fromRGB(125, 102, 62), 1.3)

	local function createInventoryTabBtn(name: string, xPos: number, width: number): TextButton
		local tBtn = Instance.new("TextButton")
		tBtn.Name = name
		tBtn.Size = UDim2.fromOffset(width, 24)
		tBtn.Position = UDim2.fromOffset(xPos, 6)
		tBtn.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
		tBtn.BorderSizePixel = 0
		tBtn.Font = Enum.Font.GothamBold
		tBtn.TextSize = 11
		tBtn.TextColor3 = Color3.fromRGB(215, 220, 235)
		tBtn.AutoButtonColor = true
		tBtn.ZIndex = 12
		tBtn.Parent = rightBagPanel
		styleL2Frame(tBtn, 4, L2_SUB_BORDER, 1.1)
		return tBtn
	end

	invTabDefaultBtn = createInventoryTabBtn("TabDefault", 8, 114)
	invTabQuestBtn = createInventoryTabBtn("TabQuest", 126, 78)
	invTabWorkshopBtn = createInventoryTabBtn("TabWorkshop", 208, 162)

	invTabDefaultBtn.Activated:Connect(function()
		activeInventoryTab = "Default"
		selectedGridCellIndex = nil
		refreshModals()
	end)
	invTabQuestBtn.Activated:Connect(function()
		activeInventoryTab = "Quest"
		selectedGridCellIndex = nil
		refreshModals()
	end)
	invTabWorkshopBtn.Activated:Connect(function()
		activeInventoryTab = "Workshop"
		hoveredTooltipData = nil
		refreshModals()
	end)

	invSlotCounterLabel = Instance.new("TextLabel")
	invSlotCounterLabel.Name = "SlotCounter"
	invSlotCounterLabel.Size = UDim2.fromOffset(66, 24)
	invSlotCounterLabel.AnchorPoint = Vector2.new(1, 0)
	invSlotCounterLabel.Position = UDim2.new(1, -8, 0, 6)
	invSlotCounterLabel.BackgroundTransparency = 1
	invSlotCounterLabel.Font = Enum.Font.GothamBlack
	invSlotCounterLabel.TextSize = 11
	invSlotCounterLabel.TextXAlignment = Enum.TextXAlignment.Right
	invSlotCounterLabel.TextColor3 = Color3.fromRGB(225, 200, 125)
	invSlotCounterLabel.Text = "(0/54)"
	invSlotCounterLabel.ZIndex = 12
	invSlotCounterLabel.Parent = rightBagPanel

	-- 9x6 Square Grid Container (54 Cells)
	bagGridContainer = Instance.new("Frame")
	bagGridContainer.Name = "BagSquareGridContainer"
	bagGridContainer.Size = UDim2.fromOffset(432, 292)
	bagGridContainer.Position = UDim2.fromOffset(8, 34)
	bagGridContainer.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	bagGridContainer.BorderSizePixel = 0
	bagGridContainer.ZIndex = 12
	bagGridContainer.Parent = rightBagPanel
	styleL2Frame(bagGridContainer, 4, Color3.fromRGB(72, 62, 42), 1)

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingLeft = UDim.new(0, 4)
	gridPad.Parent = bagGridContainer

	local bagUIGrid = Instance.new("UIGridLayout")
	bagUIGrid.CellSize = UDim2.fromOffset(44, 44)
	bagUIGrid.CellPadding = UDim2.fromOffset(3, 3)
	bagUIGrid.FillDirectionMaxCells = 9
	bagUIGrid.SortOrder = Enum.SortOrder.LayoutOrder
	bagUIGrid.Parent = bagGridContainer

	for cellIdx = 1, TOTAL_L2_GRID_SLOTS do
		local cBtn = Instance.new("TextButton")
		cBtn.Name = "GridCell_" .. tostring(cellIdx)
		cBtn.LayoutOrder = cellIdx
		cBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		cBtn.BorderSizePixel = 0
		cBtn.Text = ""
		cBtn.AutoButtonColor = true
		cBtn.ZIndex = 13
		cBtn.Parent = bagGridContainer

		local cCorner = Instance.new("UICorner")
		cCorner.CornerRadius = UDim.new(0, 3)
		cCorner.Parent = cBtn

		local cGrad = Instance.new("UIGradient")
		cGrad.Rotation = 90
		cGrad.Color = ColorSequence.new(Color3.fromRGB(16, 18, 25), Color3.fromRGB(10, 12, 17))
		cGrad.Parent = cBtn

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = Color3.fromRGB(46, 42, 34)
		cStroke.Thickness = 1.0
		cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cStroke.Parent = cBtn

		local cGlyph = Instance.new("TextLabel")
		cGlyph.Name = "Glyph"
		cGlyph.Size = UDim2.fromScale(1, 1)
		cGlyph.BackgroundTransparency = 1
		cGlyph.Font = Enum.Font.GothamBlack
		cGlyph.TextSize = 19
		cGlyph.TextColor3 = Color3.fromRGB(235, 240, 250)
		cGlyph.Visible = false
		cGlyph.ZIndex = 14
		cGlyph.Parent = cBtn

		local tlBadge = Instance.new("TextLabel")
		tlBadge.Name = "TopLeftBadge"
		tlBadge.Size = UDim2.fromOffset(24, 12)
		tlBadge.Position = UDim2.fromOffset(2, 1)
		tlBadge.BackgroundTransparency = 1
		tlBadge.Font = Enum.Font.GothamBlack
		tlBadge.TextSize = 8
		tlBadge.TextXAlignment = Enum.TextXAlignment.Left
		tlBadge.TextColor3 = Color3.fromRGB(255, 220, 85)
		tlBadge.TextStrokeTransparency = 0.15
		tlBadge.Visible = false
		tlBadge.ZIndex = 15
		tlBadge.Parent = cBtn

		local trBadge = Instance.new("TextLabel")
		trBadge.Name = "TopRightBadge"
		trBadge.Size = UDim2.fromOffset(20, 12)
		trBadge.AnchorPoint = Vector2.new(1, 0)
		trBadge.Position = UDim2.new(1, -2, 0, 1)
		trBadge.BackgroundTransparency = 1
		trBadge.Font = Enum.Font.GothamBlack
		trBadge.TextSize = 8
		trBadge.TextXAlignment = Enum.TextXAlignment.Right
		trBadge.TextColor3 = Color3.fromRGB(95, 225, 255)
		trBadge.TextStrokeTransparency = 0.15
		trBadge.Visible = false
		trBadge.ZIndex = 15
		trBadge.Parent = cBtn

		local brBadge = Instance.new("TextLabel")
		brBadge.Name = "BottomRightQty"
		brBadge.Size = UDim2.new(1, -4, 0, 12)
		brBadge.AnchorPoint = Vector2.new(1, 1)
		brBadge.Position = UDim2.new(1, -2, 1, -1)
		brBadge.BackgroundTransparency = 1
		brBadge.Font = Enum.Font.GothamBlack
		brBadge.TextSize = 9
		brBadge.TextXAlignment = Enum.TextXAlignment.Right
		brBadge.TextColor3 = Color3.fromRGB(240, 245, 255)
		brBadge.TextStrokeTransparency = 0.1
		brBadge.Visible = false
		brBadge.ZIndex = 15
		brBadge.Parent = cBtn

		cBtn.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local entry = currentGridEntries[cellIdx]
				if entry then
					workshopUI.draggedCellIndex = cellIdx
					workshopUI.dragStartMousePos = Vector2.new(input.Position.X, input.Position.Y)
					workshopUI.isDraggingItem = false
				end
			end
		end)

		cBtn.Activated:Connect(function()
			if workshopUI.isDraggingItem then
				return
			end
			local entry = currentGridEntries[cellIdx]
			if not entry then
				selectedGridCellIndex = nil
				refreshInventoryPaperdollAndBag()
				return
			end

			local now = os.clock()
			if lastClickedCellIndex == cellIdx and (now - lastClickedCellTime) <= 0.38 then
				lastClickedCellIndex = nil
				lastClickedCellTime = 0
				executeBagGridEntryDoubleClick(entry)
				return
			end

			lastClickedCellIndex = cellIdx
			lastClickedCellTime = now
			selectedGridCellIndex = cellIdx
			refreshInventoryPaperdollAndBag()
		end)

		cBtn.MouseButton2Click:Connect(function()
			local entry = currentGridEntries[cellIdx]
			if entry then
				selectedGridCellIndex = cellIdx
				executeBagGridEntryDoubleClick(entry)
			end
		end)

		cBtn.MouseEnter:Connect(function()
			local entry = currentGridEntries[cellIdx]
			if entry then
				hoveredTooltipData = {
					title = entry.titleText,
					titleColor = if entry.grade == "D"
						then Color3.fromRGB(95, 215, 255)
						else Color3.fromRGB(245, 235, 185),
					meta = entry.metaText,
					bonuses = entry.bonusesText,
					desc = entry.descText,
				}
			else
				hoveredTooltipData = nil
			end
			refreshItemTooltip()
		end)

		cBtn.MouseLeave:Connect(function()
			hoveredTooltipData = nil
			refreshItemTooltip()
		end)

		bagGridCells[cellIdx] = {
			cellIndex = cellIdx,
			button = cBtn,
			gradient = cGrad,
			stroke = cStroke,
			glyphLabel = cGlyph,
			topLeftBadge = tlBadge,
			topRightBadge = trBadge,
			bottomRightBadge = brBadge,
		}
	end

	-- Tab 3 Container: Weapon Enchanting Workshop + Express Kiosk
	workshopTabContainer = Instance.new("Frame")
	workshopTabContainer.Name = "WorkshopAndKioskContainer"
	workshopTabContainer.Size = UDim2.fromOffset(432, 292)
	workshopTabContainer.Position = UDim2.fromOffset(8, 34)
	workshopTabContainer.BackgroundColor3 = Color3.fromRGB(12, 15, 22)
	workshopTabContainer.BorderSizePixel = 0
	workshopTabContainer.Visible = false
	workshopTabContainer.ZIndex = 12
	workshopTabContainer.Parent = rightBagPanel
	styleL2Frame(workshopTabContainer, 4, Color3.fromRGB(72, 62, 42), 1)

	-- Left Half of Workshop Tab: Weapon Enchanting Anvil
	do
		local enchantCol = Instance.new("Frame")
		enchantCol.Name = "EnchantSubCol"
		enchantCol.Size = UDim2.fromOffset(208, 280)
		enchantCol.Position = UDim2.fromOffset(6, 6)
		enchantCol.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
		enchantCol.BorderSizePixel = 0
		enchantCol.ZIndex = 13
		enchantCol.Parent = workshopTabContainer
		styleL2Frame(enchantCol, 4, L2_SUB_BORDER, 1)

		workshopUI.invEnchantHeaderLabel = Instance.new("TextLabel")
		workshopUI.invEnchantHeaderLabel.Size = UDim2.new(1, -12, 0, 20)
		workshopUI.invEnchantHeaderLabel.Position = UDim2.fromOffset(6, 6)
		workshopUI.invEnchantHeaderLabel.BackgroundTransparency = 1
		workshopUI.invEnchantHeaderLabel.Font = Enum.Font.GothamBlack
		workshopUI.invEnchantHeaderLabel.TextSize = 11
		workshopUI.invEnchantHeaderLabel.TextXAlignment = Enum.TextXAlignment.Center
		workshopUI.invEnchantHeaderLabel.TextColor3 = Color3.fromRGB(255, 220, 105)
		workshopUI.invEnchantHeaderLabel.ZIndex = 14
		workshopUI.invEnchantHeaderLabel.Parent = enchantCol

		workshopUI.enchantWeaponCard = Instance.new("Frame")
		workshopUI.enchantWeaponCard.Name = "WeaponPreviewCard"
		workshopUI.enchantWeaponCard.Size = UDim2.new(1, -14, 0, 118)
		workshopUI.enchantWeaponCard.Position = UDim2.fromOffset(7, 30)
		workshopUI.enchantWeaponCard.BackgroundColor3 = Color3.fromRGB(10, 13, 19)
		workshopUI.enchantWeaponCard.BorderSizePixel = 0
		workshopUI.enchantWeaponCard.ZIndex = 14
		workshopUI.enchantWeaponCard.Parent = enchantCol

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 5)
		cardCorner.Parent = workshopUI.enchantWeaponCard

		workshopUI.enchantWeaponCardStroke = Instance.new("UIStroke")
		workshopUI.enchantWeaponCardStroke.Color = L2_GOLD_BORDER
		workshopUI.enchantWeaponCardStroke.Thickness = 1.6
		workshopUI.enchantWeaponCardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		workshopUI.enchantWeaponCardStroke.Parent = workshopUI.enchantWeaponCard

		workshopUI.enchantWeaponNameLabel = Instance.new("TextLabel")
		workshopUI.enchantWeaponNameLabel.Size = UDim2.new(1, -12, 0, 32)
		workshopUI.enchantWeaponNameLabel.Position = UDim2.fromOffset(6, 6)
		workshopUI.enchantWeaponNameLabel.BackgroundTransparency = 1
		workshopUI.enchantWeaponNameLabel.Font = Enum.Font.GothamBlack
		workshopUI.enchantWeaponNameLabel.TextSize = 11
		workshopUI.enchantWeaponNameLabel.TextWrapped = true
		workshopUI.enchantWeaponNameLabel.TextXAlignment = Enum.TextXAlignment.Center
		workshopUI.enchantWeaponNameLabel.TextColor3 = Color3.fromRGB(255, 235, 140)
		workshopUI.enchantWeaponNameLabel.ZIndex = 15
		workshopUI.enchantWeaponNameLabel.Parent = workshopUI.enchantWeaponCard

		workshopUI.enchantAtkBonusLabel = Instance.new("TextLabel")
		workshopUI.enchantAtkBonusLabel.Size = UDim2.new(1, -12, 0, 24)
		workshopUI.enchantAtkBonusLabel.Position = UDim2.fromOffset(6, 42)
		workshopUI.enchantAtkBonusLabel.BackgroundTransparency = 1
		workshopUI.enchantAtkBonusLabel.Font = Enum.Font.GothamBold
		workshopUI.enchantAtkBonusLabel.TextSize = 10
		workshopUI.enchantAtkBonusLabel.TextWrapped = true
		workshopUI.enchantAtkBonusLabel.TextXAlignment = Enum.TextXAlignment.Center
		workshopUI.enchantAtkBonusLabel.TextColor3 = Color3.fromRGB(130, 240, 255)
		workshopUI.enchantAtkBonusLabel.ZIndex = 15
		workshopUI.enchantAtkBonusLabel.Parent = workshopUI.enchantWeaponCard

		workshopUI.enchantNextChanceLabel = Instance.new("TextLabel")
		workshopUI.enchantNextChanceLabel.Size = UDim2.new(1, -12, 0, 42)
		workshopUI.enchantNextChanceLabel.Position = UDim2.fromOffset(6, 70)
		workshopUI.enchantNextChanceLabel.BackgroundTransparency = 1
		workshopUI.enchantNextChanceLabel.Font = Enum.Font.GothamBold
		workshopUI.enchantNextChanceLabel.TextSize = 10
		workshopUI.enchantNextChanceLabel.TextWrapped = true
		workshopUI.enchantNextChanceLabel.TextXAlignment = Enum.TextXAlignment.Center
		workshopUI.enchantNextChanceLabel.TextColor3 = Color3.fromRGB(115, 245, 145)
		workshopUI.enchantNextChanceLabel.ZIndex = 15
		workshopUI.enchantNextChanceLabel.Parent = workshopUI.enchantWeaponCard

		workshopUI.enchantFeedbackLabel = Instance.new("TextLabel")
		workshopUI.enchantFeedbackLabel.Name = "EnchantResultBanner"
		workshopUI.enchantFeedbackLabel.Size = UDim2.new(1, -14, 0, 56)
		workshopUI.enchantFeedbackLabel.Position = UDim2.fromOffset(7, 156)
		workshopUI.enchantFeedbackLabel.BackgroundTransparency = 1
		workshopUI.enchantFeedbackLabel.Font = Enum.Font.GothamBold
		workshopUI.enchantFeedbackLabel.TextSize = 10
		workshopUI.enchantFeedbackLabel.TextWrapped = true
		workshopUI.enchantFeedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
		workshopUI.enchantFeedbackLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
		workshopUI.enchantFeedbackLabel.ZIndex = 14
		workshopUI.enchantFeedbackLabel.Parent = enchantCol

		workshopUI.enchantWeaponBtn = Instance.new("TextButton")
		workshopUI.enchantWeaponBtn.Name = "EnchantWeaponActionBtn"
		workshopUI.enchantWeaponBtn.Size = UDim2.new(1, -14, 0, 48)
		workshopUI.enchantWeaponBtn.Position = UDim2.fromOffset(7, 222)
		workshopUI.enchantWeaponBtn.BackgroundColor3 = Color3.fromRGB(175, 125, 28)
		workshopUI.enchantWeaponBtn.BorderSizePixel = 0
		workshopUI.enchantWeaponBtn.Font = Enum.Font.GothamBlack
		workshopUI.enchantWeaponBtn.TextSize = 11
		workshopUI.enchantWeaponBtn.TextWrapped = true
		workshopUI.enchantWeaponBtn.TextColor3 = Color3.fromRGB(255, 250, 225)
		workshopUI.enchantWeaponBtn.AutoButtonColor = true
		workshopUI.enchantWeaponBtn.ZIndex = 14
		workshopUI.enchantWeaponBtn.Parent = enchantCol
		styleL2Frame(workshopUI.enchantWeaponBtn, 5, Color3.fromRGB(255, 225, 115), 1.6)

		workshopUI.enchantWeaponBtn.Activated:Connect(function()
			if not clientProfile.HasWeapon then
				return
			end
			Remotes.RequestEnchantWeapon:FireServer()
		end)

		-- Right Half of Workshop Tab: Express Kiosk / Shop
		local kioskCol = Instance.new("Frame")
		kioskCol.Name = "KioskSubCol"
		kioskCol.Size = UDim2.fromOffset(206, 280)
		kioskCol.Position = UDim2.fromOffset(220, 6)
		kioskCol.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
		kioskCol.BorderSizePixel = 0
		kioskCol.ZIndex = 13
		kioskCol.Parent = workshopTabContainer
		styleL2Frame(kioskCol, 4, L2_SUB_BORDER, 1)

		workshopUI.invShopHeaderLabel = Instance.new("TextLabel")
		workshopUI.invShopHeaderLabel.Size = UDim2.new(1, -12, 0, 20)
		workshopUI.invShopHeaderLabel.Position = UDim2.fromOffset(6, 6)
		workshopUI.invShopHeaderLabel.BackgroundTransparency = 1
		workshopUI.invShopHeaderLabel.Font = Enum.Font.GothamBlack
		workshopUI.invShopHeaderLabel.TextSize = 11
		workshopUI.invShopHeaderLabel.TextXAlignment = Enum.TextXAlignment.Center
		workshopUI.invShopHeaderLabel.TextColor3 = Color3.fromRGB(115, 240, 255)
		workshopUI.invShopHeaderLabel.ZIndex = 14
		workshopUI.invShopHeaderLabel.Parent = kioskCol

		local function createKioskButton(name: string, yPos: number, bgColor: Color3): TextButton
			local btn = Instance.new("TextButton")
			btn.Name = name
			btn.Size = UDim2.new(1, -14, 0, 36)
			btn.Position = UDim2.fromOffset(7, yPos)
			btn.BackgroundColor3 = bgColor
			btn.BorderSizePixel = 0
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 10
			btn.TextWrapped = true
			btn.TextColor3 = Color3.fromRGB(245, 250, 255)
			btn.AutoButtonColor = true
			btn.ZIndex = 14
			btn.Parent = kioskCol
			styleL2Frame(btn, 4, L2_GOLD_BORDER, 1.0)
			return btn
		end

		workshopUI.shopBuyHpPotionsBtn = createKioskButton("BuyHpPotionsBtn", 30, Color3.fromRGB(78, 28, 38))
		workshopUI.shopBuyMpPotionsBtn = createKioskButton("BuyMpPotionsBtn", 70, Color3.fromRGB(24, 46, 86))
		workshopUI.shopBuyShotsBtn = createKioskButton("BuyEnergyShotsBtn", 110, Color3.fromRGB(24, 62, 82))
		workshopUI.shopBuyScrollCashBtn = createKioskButton("BuyScrollCashBtn", 150, Color3.fromRGB(68, 52, 24))
		workshopUI.shopTradeScrollTokensBtn = createKioskButton("TradeScrollTokensBtn", 190, Color3.fromRGB(28, 70, 56))
		workshopUI.shopBuyNewWeaponBtn = createKioskButton("BuyNewWeaponBtn", 232, Color3.fromRGB(45, 145, 85))

		workshopUI.shopBuyShotsBtn.Activated:Connect(function()
			Remotes.BuyShopItem:FireServer("EnergyShots")
		end)
		workshopUI.shopBuyScrollCashBtn.Activated:Connect(function()
			Remotes.BuyShopItem:FireServer("EnchantScroll")
		end)
		workshopUI.shopTradeScrollTokensBtn.Activated:Connect(function()
			Remotes.BuyShopItem:FireServer("EnchantScrollTokens")
		end)
		workshopUI.shopBuyHpPotionsBtn.Activated:Connect(function()
			Remotes.BuyShopItem:FireServer("HpPotions")
		end)
		workshopUI.shopBuyMpPotionsBtn.Activated:Connect(function()
			Remotes.BuyShopItem:FireServer("MpPotions")
		end)
		workshopUI.shopBuyNewWeaponBtn.Activated:Connect(function()
			Remotes.BuyShopItem:FireServer("NewWeapon")
		end)
	end

	-- Bottom Footer Bar inside Right Panel (Selected Item Actions + L2 Adena Bar)
	local invFooterBar = Instance.new("Frame")
	invFooterBar.Name = "L2InventoryFooterBar"
	invFooterBar.Size = UDim2.fromOffset(432, 44)
	invFooterBar.Position = UDim2.fromOffset(8, 331)
	invFooterBar.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	invFooterBar.BorderSizePixel = 0
	invFooterBar.ZIndex = 12
	invFooterBar.Parent = rightBagPanel
	styleL2Frame(invFooterBar, 4, Color3.fromRGB(85, 72, 46), 1)

	invSelectedItemLabel = Instance.new("TextLabel")
	invSelectedItemLabel.Name = "SelectedItemLabel"
	invSelectedItemLabel.Size = UDim2.fromOffset(162, 36)
	invSelectedItemLabel.Position = UDim2.fromOffset(8, 4)
	invSelectedItemLabel.BackgroundTransparency = 1
	invSelectedItemLabel.Font = Enum.Font.GothamBold
	invSelectedItemLabel.TextSize = 10
	invSelectedItemLabel.TextWrapped = true
	invSelectedItemLabel.TextXAlignment = Enum.TextXAlignment.Left
	invSelectedItemLabel.TextColor3 = Color3.fromRGB(145, 155, 175)
	invSelectedItemLabel.ZIndex = 13
	invSelectedItemLabel.Parent = invFooterBar

	invActionEquipBtn = Instance.new("TextButton")
	invActionEquipBtn.Name = "FooterEquipBtn"
	invActionEquipBtn.Size = UDim2.fromOffset(66, 30)
	invActionEquipBtn.Position = UDim2.fromOffset(172, 7)
	invActionEquipBtn.BackgroundColor3 = Color3.fromRGB(38, 125, 78)
	invActionEquipBtn.Font = Enum.Font.GothamBold
	invActionEquipBtn.TextSize = 10
	invActionEquipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	invActionEquipBtn.Visible = false
	invActionEquipBtn.ZIndex = 13
	invActionEquipBtn.Parent = invFooterBar
	styleL2Frame(invActionEquipBtn, 4, L2_SUB_BORDER, 1)

	invActionEquipBtn.Activated:Connect(function()
		local selEntry = if selectedGridCellIndex then currentGridEntries[selectedGridCellIndex] else nil
		if selEntry then
			executeBagGridEntryDoubleClick(selEntry)
		end
	end)

	invActionSellBtn = Instance.new("TextButton")
	invActionSellBtn.Name = "FooterSellBtn"
	invActionSellBtn.Size = UDim2.fromOffset(72, 30)
	invActionSellBtn.Position = UDim2.fromOffset(242, 7)
	invActionSellBtn.BackgroundColor3 = Color3.fromRGB(125, 38, 44)
	invActionSellBtn.Font = Enum.Font.GothamBold
	invActionSellBtn.TextSize = 10
	invActionSellBtn.TextColor3 = Color3.fromRGB(255, 240, 215)
	invActionSellBtn.Visible = false
	invActionSellBtn.ZIndex = 13
	invActionSellBtn.Parent = invFooterBar
	styleL2Frame(invActionSellBtn, 4, L2_SUB_BORDER, 1)

	invActionSellBtn.Activated:Connect(function()
		local selEntry = if selectedGridCellIndex then currentGridEntries[selectedGridCellIndex] else nil
		if selEntry and selEntry.kind == "Equipment" and selEntry.bagIndex then
			Remotes.SellBagItem:FireServer(selEntry.bagIndex)
		end
	end)

	invAdenaLabel = Instance.new("TextLabel")
	invAdenaLabel.Name = "AdenaCounter"
	invAdenaLabel.Size = UDim2.fromOffset(110, 36)
	invAdenaLabel.AnchorPoint = Vector2.new(1, 0.5)
	invAdenaLabel.Position = UDim2.new(1, -8, 0.5, 0)
	invAdenaLabel.BackgroundTransparency = 1
	invAdenaLabel.Font = Enum.Font.GothamBlack
	invAdenaLabel.TextSize = 11
	invAdenaLabel.TextWrapped = true
	invAdenaLabel.TextXAlignment = Enum.TextXAlignment.Right
	invAdenaLabel.TextColor3 = Color3.fromRGB(255, 220, 85)
	invAdenaLabel.ZIndex = 13
	invAdenaLabel.Parent = invFooterBar

	workshopUI.statsModal, workshopUI.statsTitleLabel, workshopUI.statsCloseBtn =
		createBaseModal("StatsModal", UDim2.fromOffset(390, 315), UDim2.new(0.22, 0, 0.45, 0))
	workshopUI.statsContentLabel = Instance.new("TextLabel")
	workshopUI.statsContentLabel.Size = UDim2.new(1, -28, 1, -56)
	workshopUI.statsContentLabel.Position = UDim2.fromOffset(14, 46)
	workshopUI.statsContentLabel.BackgroundTransparency = 1
	workshopUI.statsContentLabel.Font = Enum.Font.GothamMedium
	workshopUI.statsContentLabel.TextSize = 13
	workshopUI.statsContentLabel.TextXAlignment = Enum.TextXAlignment.Left
	workshopUI.statsContentLabel.TextYAlignment = Enum.TextYAlignment.Top
	workshopUI.statsContentLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
	workshopUI.statsContentLabel.ZIndex = 11
	workshopUI.statsContentLabel.Parent = workshopUI.statsModal

	-- =====================================================================
	-- [J] JOB & SUBCLASS DOSSIER MODAL (Gated Subclass Switching)
	-- =====================================================================
	do
		jobUI.jobModalFrame, jobUI.jobModalTitle, jobUI.jobCloseBtn =
			createBaseModal("JobSubclassModal", UDim2.fromOffset(610, 485), UDim2.new(0.46, 0, 0.50, 0))

		local raceBannerBg = Instance.new("Frame")
		raceBannerBg.Name = "LockedRaceBanner"
		raceBannerBg.Size = UDim2.new(1, -28, 0, 34)
		raceBannerBg.Position = UDim2.fromOffset(14, 44)
		raceBannerBg.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
		raceBannerBg.BorderSizePixel = 0
		raceBannerBg.ZIndex = 11
		raceBannerBg.Parent = jobUI.jobModalFrame
		styleL2Frame(raceBannerBg, 4, L2_SUB_BORDER, 1)

		jobUI.jobLockedRaceBanner = Instance.new("TextLabel")
		jobUI.jobLockedRaceBanner.Size = UDim2.new(1, -16, 1, 0)
		jobUI.jobLockedRaceBanner.Position = UDim2.fromOffset(8, 0)
		jobUI.jobLockedRaceBanner.BackgroundTransparency = 1
		jobUI.jobLockedRaceBanner.Font = Enum.Font.GothamBold
		jobUI.jobLockedRaceBanner.TextSize = 11
		jobUI.jobLockedRaceBanner.TextWrapped = true
		jobUI.jobLockedRaceBanner.TextXAlignment = Enum.TextXAlignment.Left
		jobUI.jobLockedRaceBanner.TextColor3 = Color3.fromRGB(235, 210, 130)
		jobUI.jobLockedRaceBanner.ZIndex = 12
		jobUI.jobLockedRaceBanner.Parent = raceBannerBg

		-- Left Column: Playable Classes (Main & Subclasses) inside ScrollingFrame
		local classScroll = Instance.new("ScrollingFrame")
		classScroll.Name = "PlayableClassListScroll"
		classScroll.Size = UDim2.fromOffset(240, 385)
		classScroll.Position = UDim2.fromOffset(14, 86)
		classScroll.BackgroundTransparency = 1
		classScroll.BorderSizePixel = 0
		classScroll.ScrollBarThickness = 5
		classScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 100, 130)
		classScroll.CanvasSize = UDim2.fromOffset(0, #PLAYABLE_CLASS_IDS * 66)
		classScroll.ZIndex = 11
		classScroll.Parent = jobUI.jobModalFrame

		for idx, classId in ipairs(PLAYABLE_CLASS_IDS) do
			local btn = Instance.new("TextButton")
			btn.Name = "ClassBtn_" .. classId
			btn.Size = UDim2.fromOffset(226, 60)
			btn.Position = UDim2.fromOffset(0, (idx - 1) * 64)
			btn.BackgroundColor3 = L2_PANEL_COLOR
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 12
			btn.TextWrapped = true
			btn.TextColor3 = Color3.fromRGB(240, 248, 255)
			btn.ZIndex = 11
			btn.Parent = classScroll
			styleL2Frame(btn, 5, L2_SUB_BORDER, 1.2)

			btn.MouseEnter:Connect(function()
				jobUI.previewedJobClassId = classId
				refreshModals()
			end)

			btn.Activated:Connect(function()
				jobUI.previewedJobClassId = classId
				refreshModals()
				local isUnlocked = (playerState.classId == classId) or (clientProfile.UnlockedClasses[classId] == true)
				if not isUnlocked and not areAllSubclassConditionsMet() then
					UIController.AddSystemLog(I18n.t("LOG_SUBCLASS_LOCKED"), Color3.fromRGB(255, 95, 95))
					return
				end
				Remotes.UnlockOrSwitchSubclass:FireServer(classId)
			end)

			jobUI.classButtons[classId] = btn
		end

		-- Right Column: Subclass Dossier Checklist Panel
		local dossierPanel = Instance.new("Frame")
		dossierPanel.Name = "SubclassDossierPanel"
		dossierPanel.Size = UDim2.fromOffset(334, 202)
		dossierPanel.Position = UDim2.fromOffset(262, 86)
		dossierPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		dossierPanel.BorderSizePixel = 0
		dossierPanel.ZIndex = 11
		dossierPanel.Parent = jobUI.jobModalFrame
		styleL2Frame(dossierPanel, 5, L2_GOLD_BORDER, 1.2)

		jobUI.jobDossierHeaderLabel = Instance.new("TextLabel")
		jobUI.jobDossierHeaderLabel.Size = UDim2.new(1, -20, 0, 22)
		jobUI.jobDossierHeaderLabel.Position = UDim2.fromOffset(10, 6)
		jobUI.jobDossierHeaderLabel.BackgroundTransparency = 1
		jobUI.jobDossierHeaderLabel.Font = Enum.Font.GothamBlack
		jobUI.jobDossierHeaderLabel.TextSize = 13
		jobUI.jobDossierHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		jobUI.jobDossierHeaderLabel.TextColor3 = Color3.fromRGB(255, 220, 105)
		jobUI.jobDossierHeaderLabel.ZIndex = 12
		jobUI.jobDossierHeaderLabel.Parent = dossierPanel

		jobUI.jobDossierHintLabel = Instance.new("TextLabel")
		jobUI.jobDossierHintLabel.Size = UDim2.new(1, -20, 0, 28)
		jobUI.jobDossierHintLabel.Position = UDim2.fromOffset(10, 28)
		jobUI.jobDossierHintLabel.BackgroundTransparency = 1
		jobUI.jobDossierHintLabel.Font = Enum.Font.GothamMedium
		jobUI.jobDossierHintLabel.TextSize = 10
		jobUI.jobDossierHintLabel.TextWrapped = true
		jobUI.jobDossierHintLabel.TextXAlignment = Enum.TextXAlignment.Left
		jobUI.jobDossierHintLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
		jobUI.jobDossierHintLabel.ZIndex = 12
		jobUI.jobDossierHintLabel.Parent = dossierPanel

		jobUI.jobLevelChecklistLabel = Instance.new("TextLabel")
		jobUI.jobLevelChecklistLabel.Name = "Check_MainLevel"
		jobUI.jobLevelChecklistLabel.Size = UDim2.new(1, -20, 0, 22)
		jobUI.jobLevelChecklistLabel.Position = UDim2.fromOffset(10, 58)
		jobUI.jobLevelChecklistLabel.BackgroundTransparency = 1
		jobUI.jobLevelChecklistLabel.Font = Enum.Font.GothamBold
		jobUI.jobLevelChecklistLabel.TextSize = 11
		jobUI.jobLevelChecklistLabel.TextXAlignment = Enum.TextXAlignment.Left
		jobUI.jobLevelChecklistLabel.TextColor3 = Color3.fromRGB(255, 200, 90)
		jobUI.jobLevelChecklistLabel.ZIndex = 12
		jobUI.jobLevelChecklistLabel.Parent = dossierPanel

		for idx, bossReq in ipairs(GameConstants.SUBCLASS_REQUIRED_BOSSES) do
			local bossRow = Instance.new("TextLabel")
			bossRow.Name = "Check_Boss_" .. bossReq.id
			bossRow.Size = UDim2.new(1, -20, 0, 24)
			bossRow.Position = UDim2.fromOffset(10, 84 + (idx - 1) * 28)
			bossRow.BackgroundTransparency = 1
			bossRow.Font = Enum.Font.GothamBold
			bossRow.TextSize = 11
			bossRow.TextWrapped = true
			bossRow.TextXAlignment = Enum.TextXAlignment.Left
			bossRow.TextColor3 = Color3.fromRGB(245, 115, 115)
			bossRow.ZIndex = 12
			bossRow.Parent = dossierPanel

			jobUI.jobBossChecklistLabels[bossReq.id] = bossRow
		end

		-- Bottom Panel inside [J] Job Modal: Class Skills & Mechanics Preview
		local jobSkillsBox = Instance.new("Frame")
		jobSkillsBox.Name = "JobClassSkillsBox"
		jobSkillsBox.Size = UDim2.new(1, -28, 0, 172)
		jobSkillsBox.Position = UDim2.fromOffset(14, 298)
		jobSkillsBox.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		jobSkillsBox.BorderSizePixel = 0
		jobSkillsBox.ZIndex = 11
		jobSkillsBox.Parent = jobUI.jobModalFrame
		styleL2Frame(jobSkillsBox, 5, L2_SUB_BORDER, 1.2)

		jobUI.jobClassSkillsHeaderLabel = Instance.new("TextLabel")
		jobUI.jobClassSkillsHeaderLabel.Size = UDim2.new(1, -20, 0, 22)
		jobUI.jobClassSkillsHeaderLabel.Position = UDim2.fromOffset(10, 6)
		jobUI.jobClassSkillsHeaderLabel.BackgroundTransparency = 1
		jobUI.jobClassSkillsHeaderLabel.Font = Enum.Font.GothamBlack
		jobUI.jobClassSkillsHeaderLabel.TextSize = 13
		jobUI.jobClassSkillsHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		jobUI.jobClassSkillsHeaderLabel.TextColor3 = Color3.fromRGB(255, 220, 105)
		jobUI.jobClassSkillsHeaderLabel.ZIndex = 12
		jobUI.jobClassSkillsHeaderLabel.Parent = jobSkillsBox

		jobUI.jobClassSkillsValueLabel = Instance.new("TextLabel")
		jobUI.jobClassSkillsValueLabel.Size = UDim2.new(1, -20, 1, -32)
		jobUI.jobClassSkillsValueLabel.Position = UDim2.fromOffset(10, 28)
		jobUI.jobClassSkillsValueLabel.BackgroundTransparency = 1
		jobUI.jobClassSkillsValueLabel.Font = Enum.Font.GothamMedium
		jobUI.jobClassSkillsValueLabel.TextSize = 11
		jobUI.jobClassSkillsValueLabel.TextWrapped = true
		jobUI.jobClassSkillsValueLabel.TextXAlignment = Enum.TextXAlignment.Left
		jobUI.jobClassSkillsValueLabel.TextYAlignment = Enum.TextYAlignment.Top
		jobUI.jobClassSkillsValueLabel.TextColor3 = Color3.fromRGB(225, 238, 255)
		jobUI.jobClassSkillsValueLabel.ZIndex = 12
		jobUI.jobClassSkillsValueLabel.Parent = jobSkillsBox
	end

	-- =====================================================================
	-- 8. FIRST-TIME CHARACTER CREATION SCREEN (Full-Screen Lineage 2 Style)
	-- =====================================================================
	do
		creationUI.charCreationScreen = Instance.new("Frame")
		creationUI.charCreationScreen.Name = "CharacterCreationScreen"
		creationUI.charCreationScreen.Size = UDim2.fromScale(1, 1)
		creationUI.charCreationScreen.Position = UDim2.fromScale(0, 0)
		creationUI.charCreationScreen.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
		creationUI.charCreationScreen.BackgroundTransparency = 0.04
		creationUI.charCreationScreen.BorderSizePixel = 0
		creationUI.charCreationScreen.Visible = false
		creationUI.charCreationScreen.Active = true
		creationUI.charCreationScreen.ZIndex = 30
		creationUI.charCreationScreen.Parent = screenGui

		local creationDialog = Instance.new("Frame")
		creationDialog.Name = "CreationDialog"
		creationDialog.Size = UDim2.fromOffset(680, 515)
		creationDialog.AnchorPoint = Vector2.new(0.5, 0.5)
		creationDialog.Position = UDim2.fromScale(0.5, 0.5)
		creationDialog.BackgroundColor3 = L2_BG_COLOR
		creationDialog.BorderSizePixel = 0
		creationDialog.ZIndex = 31
		creationDialog.Parent = creationUI.charCreationScreen
		styleL2Frame(creationDialog, 8, L2_GOLD_BORDER, 2.2)

		creationUI.charCreateTitleLabel = Instance.new("TextLabel")
		creationUI.charCreateTitleLabel.Size = UDim2.new(1, -150, 0, 28)
		creationUI.charCreateTitleLabel.Position = UDim2.fromOffset(20, 14)
		creationUI.charCreateTitleLabel.BackgroundTransparency = 1
		creationUI.charCreateTitleLabel.Font = Enum.Font.GothamBlack
		creationUI.charCreateTitleLabel.TextSize = 19
		creationUI.charCreateTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charCreateTitleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		creationUI.charCreateTitleLabel.ZIndex = 32
		creationUI.charCreateTitleLabel.Parent = creationDialog

		creationUI.charCreateSubtitleLabel = Instance.new("TextLabel")
		creationUI.charCreateSubtitleLabel.Size = UDim2.new(1, -150, 0, 18)
		creationUI.charCreateSubtitleLabel.Position = UDim2.fromOffset(20, 42)
		creationUI.charCreateSubtitleLabel.BackgroundTransparency = 1
		creationUI.charCreateSubtitleLabel.Font = Enum.Font.GothamMedium
		creationUI.charCreateSubtitleLabel.TextSize = 12
		creationUI.charCreateSubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charCreateSubtitleLabel.TextColor3 = Color3.fromRGB(195, 205, 225)
		creationUI.charCreateSubtitleLabel.ZIndex = 32
		creationUI.charCreateSubtitleLabel.Parent = creationDialog

		creationUI.charCreateLangBtn = Instance.new("TextButton")
		creationUI.charCreateLangBtn.Name = "CharCreateLangBtn"
		creationUI.charCreateLangBtn.Size = UDim2.fromOffset(110, 30)
		creationUI.charCreateLangBtn.AnchorPoint = Vector2.new(1, 0)
		creationUI.charCreateLangBtn.Position = UDim2.new(1, -18, 0, 16)
		creationUI.charCreateLangBtn.BackgroundColor3 = L2_PANEL_COLOR
		creationUI.charCreateLangBtn.Font = Enum.Font.GothamBold
		creationUI.charCreateLangBtn.TextSize = 12
		creationUI.charCreateLangBtn.TextColor3 = Color3.fromRGB(240, 225, 185)
		creationUI.charCreateLangBtn.ZIndex = 32
		creationUI.charCreateLangBtn.Parent = creationDialog
		styleL2Frame(creationUI.charCreateLangBtn, 4, L2_SUB_BORDER, 1.2)

		creationUI.charCreateLangBtn.Activated:Connect(function()
			local nextLang: I18n.Language = if I18n.GetLanguage() == "ru" then "en" else "ru"
			I18n.SetLanguage(nextLang)
		end)

		-- Left Section: 5 Races + Race Passive Modifiers
		creationUI.charRaceHeaderLabel = Instance.new("TextLabel")
		creationUI.charRaceHeaderLabel.Size = UDim2.fromOffset(295, 22)
		creationUI.charRaceHeaderLabel.Position = UDim2.fromOffset(20, 70)
		creationUI.charRaceHeaderLabel.BackgroundTransparency = 1
		creationUI.charRaceHeaderLabel.Font = Enum.Font.GothamBlack
		creationUI.charRaceHeaderLabel.TextSize = 14
		creationUI.charRaceHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charRaceHeaderLabel.TextColor3 = Color3.fromRGB(245, 215, 130)
		creationUI.charRaceHeaderLabel.ZIndex = 32
		creationUI.charRaceHeaderLabel.Parent = creationDialog

		for idx, raceId in ipairs(RACE_IDS) do
			local rBtn = Instance.new("TextButton")
			rBtn.Name = "CreateRace_" .. raceId
			rBtn.Size = UDim2.fromOffset(295, 36)
			rBtn.Position = UDim2.fromOffset(20, 98 + (idx - 1) * 42)
			rBtn.BackgroundColor3 = L2_PANEL_COLOR
			rBtn.Font = Enum.Font.GothamBold
			rBtn.TextSize = 13
			rBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
			rBtn.ZIndex = 32
			rBtn.Parent = creationDialog
			styleL2Frame(rBtn, 5, L2_SUB_BORDER, 1.1)

			rBtn.Activated:Connect(function()
				selectedCreationRace = raceId
				refreshCharacterCreationScreen()
			end)

			creationUI.creationRaceButtons[raceId] = rBtn
		end

		local racePassiveBox = Instance.new("Frame")
		racePassiveBox.Size = UDim2.fromOffset(295, 130)
		racePassiveBox.Position = UDim2.fromOffset(20, 314)
		racePassiveBox.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		racePassiveBox.BorderSizePixel = 0
		racePassiveBox.ZIndex = 32
		racePassiveBox.Parent = creationDialog
		styleL2Frame(racePassiveBox, 5, L2_SUB_BORDER, 1)

		creationUI.charRacePassiveHeaderLabel = Instance.new("TextLabel")
		creationUI.charRacePassiveHeaderLabel.Size = UDim2.new(1, -16, 0, 20)
		creationUI.charRacePassiveHeaderLabel.Position = UDim2.fromOffset(8, 6)
		creationUI.charRacePassiveHeaderLabel.BackgroundTransparency = 1
		creationUI.charRacePassiveHeaderLabel.Font = Enum.Font.GothamBold
		creationUI.charRacePassiveHeaderLabel.TextSize = 12
		creationUI.charRacePassiveHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charRacePassiveHeaderLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
		creationUI.charRacePassiveHeaderLabel.ZIndex = 33
		creationUI.charRacePassiveHeaderLabel.Parent = racePassiveBox

		creationUI.charRacePassiveValueLabel = Instance.new("TextLabel")
		creationUI.charRacePassiveValueLabel.Size = UDim2.new(1, -16, 1, -30)
		creationUI.charRacePassiveValueLabel.Position = UDim2.fromOffset(8, 26)
		creationUI.charRacePassiveValueLabel.BackgroundTransparency = 1
		creationUI.charRacePassiveValueLabel.Font = Enum.Font.GothamMedium
		creationUI.charRacePassiveValueLabel.TextSize = 11
		creationUI.charRacePassiveValueLabel.TextWrapped = true
		creationUI.charRacePassiveValueLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charRacePassiveValueLabel.TextYAlignment = Enum.TextYAlignment.Top
		creationUI.charRacePassiveValueLabel.TextColor3 = Color3.fromRGB(220, 235, 250)
		creationUI.charRacePassiveValueLabel.ZIndex = 33
		creationUI.charRacePassiveValueLabel.Parent = racePassiveBox

		-- Right Section: 3 Starting Professions + Gender Selector + Skill Kit Preview
		creationUI.charClassHeaderLabel = Instance.new("TextLabel")
		creationUI.charClassHeaderLabel.Size = UDim2.fromOffset(325, 22)
		creationUI.charClassHeaderLabel.Position = UDim2.fromOffset(335, 70)
		creationUI.charClassHeaderLabel.BackgroundTransparency = 1
		creationUI.charClassHeaderLabel.Font = Enum.Font.GothamBlack
		creationUI.charClassHeaderLabel.TextSize = 14
		creationUI.charClassHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charClassHeaderLabel.TextColor3 = Color3.fromRGB(245, 215, 130)
		creationUI.charClassHeaderLabel.ZIndex = 32
		creationUI.charClassHeaderLabel.Parent = creationDialog

		local createClassScroll = Instance.new("ScrollingFrame")
		createClassScroll.Name = "CreateClassScroll"
		createClassScroll.Size = UDim2.fromOffset(325, 118)
		createClassScroll.Position = UDim2.fromOffset(335, 94)
		createClassScroll.BackgroundTransparency = 1
		createClassScroll.BorderSizePixel = 0
		createClassScroll.ScrollBarThickness = 4
		createClassScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 100, 130)
		createClassScroll.CanvasSize = UDim2.fromOffset(0, #PLAYABLE_CLASS_IDS * 38)
		createClassScroll.ZIndex = 32
		createClassScroll.Parent = creationDialog

		for idx, classId in ipairs(PLAYABLE_CLASS_IDS) do
			local cBtn = Instance.new("TextButton")
			cBtn.Name = "CreateClass_" .. classId
			cBtn.Size = UDim2.fromOffset(305, 34)
			cBtn.Position = UDim2.fromOffset(0, (idx - 1) * 38)
			cBtn.BackgroundColor3 = L2_PANEL_COLOR
			cBtn.Font = Enum.Font.GothamBold
			cBtn.TextSize = 12
			cBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
			cBtn.ZIndex = 32
			cBtn.Parent = createClassScroll
			styleL2Frame(cBtn, 5, L2_SUB_BORDER, 1.1)

			cBtn.Activated:Connect(function()
				selectedCreationClass = classId
				refreshCharacterCreationScreen()
			end)

			creationUI.creationClassButtons[classId] = cBtn
		end

		-- Gender Selector Toggle ([ ♂ Мужской / Male ] & [ ♀ Женский / Female ])
		creationUI.charGenderHeaderLabel = Instance.new("TextLabel")
		creationUI.charGenderHeaderLabel.Size = UDim2.fromOffset(325, 20)
		creationUI.charGenderHeaderLabel.Position = UDim2.fromOffset(335, 218)
		creationUI.charGenderHeaderLabel.BackgroundTransparency = 1
		creationUI.charGenderHeaderLabel.Font = Enum.Font.GothamBlack
		creationUI.charGenderHeaderLabel.TextSize = 13
		creationUI.charGenderHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charGenderHeaderLabel.TextColor3 = Color3.fromRGB(245, 215, 130)
		creationUI.charGenderHeaderLabel.ZIndex = 32
		creationUI.charGenderHeaderLabel.Parent = creationDialog

		creationUI.creationMaleBtn = Instance.new("TextButton")
		creationUI.creationMaleBtn.Name = "CreateGender_Male"
		creationUI.creationMaleBtn.Size = UDim2.fromOffset(158, 34)
		creationUI.creationMaleBtn.Position = UDim2.fromOffset(335, 240)
		creationUI.creationMaleBtn.BackgroundColor3 = L2_PANEL_COLOR
		creationUI.creationMaleBtn.Font = Enum.Font.GothamBold
		creationUI.creationMaleBtn.TextSize = 13
		creationUI.creationMaleBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
		creationUI.creationMaleBtn.ZIndex = 32
		creationUI.creationMaleBtn.Parent = creationDialog
		styleL2Frame(creationUI.creationMaleBtn, 5, L2_SUB_BORDER, 1.1)

		creationUI.creationMaleBtn.Activated:Connect(function()
			selectedCreationGender = "Male"
			refreshCharacterCreationScreen()
		end)

		creationUI.creationFemaleBtn = Instance.new("TextButton")
		creationUI.creationFemaleBtn.Name = "CreateGender_Female"
		creationUI.creationFemaleBtn.Size = UDim2.fromOffset(158, 34)
		creationUI.creationFemaleBtn.Position = UDim2.fromOffset(502, 240)
		creationUI.creationFemaleBtn.BackgroundColor3 = L2_PANEL_COLOR
		creationUI.creationFemaleBtn.Font = Enum.Font.GothamBold
		creationUI.creationFemaleBtn.TextSize = 13
		creationUI.creationFemaleBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
		creationUI.creationFemaleBtn.ZIndex = 32
		creationUI.creationFemaleBtn.Parent = creationDialog
		styleL2Frame(creationUI.creationFemaleBtn, 5, L2_SUB_BORDER, 1.1)

		creationUI.creationFemaleBtn.Activated:Connect(function()
			selectedCreationGender = "Female"
			refreshCharacterCreationScreen()
		end)

		local classSkillsBox = Instance.new("Frame")
		classSkillsBox.Size = UDim2.fromOffset(325, 162)
		classSkillsBox.Position = UDim2.fromOffset(335, 282)
		classSkillsBox.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		classSkillsBox.BorderSizePixel = 0
		classSkillsBox.ZIndex = 32
		classSkillsBox.Parent = creationDialog
		styleL2Frame(classSkillsBox, 5, L2_SUB_BORDER, 1)

		creationUI.charClassSkillsHeaderLabel = Instance.new("TextLabel")
		creationUI.charClassSkillsHeaderLabel.Size = UDim2.new(1, -16, 0, 20)
		creationUI.charClassSkillsHeaderLabel.Position = UDim2.fromOffset(8, 6)
		creationUI.charClassSkillsHeaderLabel.BackgroundTransparency = 1
		creationUI.charClassSkillsHeaderLabel.Font = Enum.Font.GothamBold
		creationUI.charClassSkillsHeaderLabel.TextSize = 12
		creationUI.charClassSkillsHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charClassSkillsHeaderLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
		creationUI.charClassSkillsHeaderLabel.ZIndex = 33
		creationUI.charClassSkillsHeaderLabel.Parent = classSkillsBox

		creationUI.charClassSkillsValueLabel = Instance.new("TextLabel")
		creationUI.charClassSkillsValueLabel.Size = UDim2.new(1, -16, 1, -30)
		creationUI.charClassSkillsValueLabel.Position = UDim2.fromOffset(8, 26)
		creationUI.charClassSkillsValueLabel.BackgroundTransparency = 1
		creationUI.charClassSkillsValueLabel.Font = Enum.Font.GothamMedium
		creationUI.charClassSkillsValueLabel.TextSize = 11
		creationUI.charClassSkillsValueLabel.TextWrapped = true
		creationUI.charClassSkillsValueLabel.TextXAlignment = Enum.TextXAlignment.Left
		creationUI.charClassSkillsValueLabel.TextYAlignment = Enum.TextYAlignment.Top
		creationUI.charClassSkillsValueLabel.TextColor3 = Color3.fromRGB(220, 235, 250)
		creationUI.charClassSkillsValueLabel.ZIndex = 33
		creationUI.charClassSkillsValueLabel.Parent = classSkillsBox

		creationUI.charCreateConfirmBtn = Instance.new("TextButton")
		creationUI.charCreateConfirmBtn.Name = "ConfirmCreateCharacterBtn"
		creationUI.charCreateConfirmBtn.Size = UDim2.fromOffset(290, 44)
		creationUI.charCreateConfirmBtn.AnchorPoint = Vector2.new(0.5, 1)
		creationUI.charCreateConfirmBtn.Position = UDim2.new(0.5, 0, 1, -14)
		creationUI.charCreateConfirmBtn.BackgroundColor3 = Color3.fromRGB(45, 140, 85)
		creationUI.charCreateConfirmBtn.Font = Enum.Font.GothamBlack
		creationUI.charCreateConfirmBtn.TextSize = 16
		creationUI.charCreateConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		creationUI.charCreateConfirmBtn.ZIndex = 32
		creationUI.charCreateConfirmBtn.Parent = creationDialog
		styleL2Frame(creationUI.charCreateConfirmBtn, 6, L2_GOLD_BORDER, 1.8)

		creationUI.charCreateConfirmBtn.Activated:Connect(function()
			clientProfile.IsCharacterCreated = true
			clientProfile.Gender = selectedCreationGender
			clientProfile.RaceId = selectedCreationRace
			clientProfile.CurrentClassId = selectedCreationClass
			clientProfile.UnlockedClasses = {
				[selectedCreationClass] = true,
			}
			creationUI.charCreationScreen.Visible = false
			Remotes.CreateCharacter:FireServer(selectedCreationRace, selectedCreationClass, selectedCreationGender)
		end)
	end

	btnInventory.Activated:Connect(function()
		toggleModal(inventoryModal)
	end)
	btnJob.Activated:Connect(function()
		toggleModal(jobUI.jobModalFrame)
	end)
	btnStats.Activated:Connect(function()
		toggleModal(workshopUI.statsModal)
	end)
	btnLang.Activated:Connect(function()
		local nextLang: I18n.Language = if I18n.GetLanguage() == "ru" then "en" else "ru"
		I18n.SetLanguage(nextLang)
		UIController.AddSystemLog(I18n.t("LOG_LANG_CHANGED"), Color3.fromRGB(255, 225, 110))
	end)
end

local function updateRadarMinimap()
	local character = localPlayer.Character
	local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not playerRoot then
		return
	end

	local pPos = playerRoot.Position
	minimapCoordsLabel.Text = I18n.t("UI_COORDS", {
		x = math.floor(pPos.X + 0.5),
		z = math.floor(pPos.Z + 0.5),
	})

	if hudZoneBadgeFrame and hudZoneBadgeStroke and hudZoneBadgeLabel then
		local inSafe = GameConstants.IsInSafeZone(pPos)
		if inSafe then
			hudZoneBadgeFrame.BackgroundColor3 = Color3.fromRGB(16, 38, 24)
			hudZoneBadgeStroke.Color = Color3.fromRGB(75, 235, 125)
			hudZoneBadgeLabel.TextColor3 = Color3.fromRGB(115, 255, 150)
			hudZoneBadgeLabel.Text = I18n.t("UI_ZONE_PEACE")
		else
			hudZoneBadgeFrame.BackgroundColor3 = Color3.fromRGB(46, 18, 18)
			hudZoneBadgeStroke.Color = Color3.fromRGB(235, 95, 65)
			hudZoneBadgeLabel.TextColor3 = Color3.fromRGB(255, 165, 110)
			hudZoneBadgeLabel.Text = I18n.t("UI_ZONE_COMBAT")
		end
	end

	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return
	end

	local seenMobs: { [Model]: boolean } = {}

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsMob") == true then
			local hp = (child:GetAttribute("CurrentHP") :: number?) or 0
			local root = child.PrimaryPart or (child:FindFirstChild("HumanoidRootPart") :: BasePart?)
			if hp > 0 and root then
				seenMobs[child] = true
				local dot = radarDotsByMob[child]
				if not dot then
					dot = Instance.new("Frame")
					dot.Name = "MobDot_" .. child.Name
					dot.Size = UDim2.fromOffset(6, 6)
					dot.AnchorPoint = Vector2.new(0.5, 0.5)
					dot.BorderSizePixel = 0
					dot.ZIndex = 2
					dot.Parent = minimapCanvas
					local c = Instance.new("UICorner")
					c.CornerRadius = UDim.new(1, 0)
					c.Parent = dot
					radarDotsByMob[child] = dot
				end

				local isAggro = child:GetAttribute("IsAggressive") == true
				dot.BackgroundColor3 = if isAggro
					then Color3.fromRGB(255, 55, 55)
					else Color3.fromRGB(255, 220, 65)

				local dx = (root.Position.X - pPos.X) / (RADAR_WORLD_RADIUS * 2)
				local dz = (root.Position.Z - pPos.Z) / (RADAR_WORLD_RADIUS * 2)
				local normX = math.clamp(0.5 + dx, 0.05, 0.95)
				local normY = math.clamp(0.5 + dz, 0.05, 0.95)
				dot.Position = UDim2.fromScale(normX, normY)
			end
		end
	end

	for mobModel, dot in pairs(radarDotsByMob) do
		if not seenMobs[mobModel] then
			dot:Destroy()
			radarDotsByMob[mobModel] = nil
		end
	end
end

function UIController.Init()
	if initialized then
		return
	end
	initialized = true

	disableDefaultRobloxChat()
	buildInterface()
	refreshPlayerHud()
	refreshTargetFrame()

	UIController.AddSystemLog(I18n.t("LOG_SYS_WELCOME"), Color3.fromRGB(235, 215, 135))

	TargetController.OnTargetChanged.Event:Connect(function(newTarget: Model?)
		if targetHpSignalConn then
			targetHpSignalConn:Disconnect()
			targetHpSignalConn = nil
		end
		if targetSpoilSignalConn then
			targetSpoilSignalConn:Disconnect()
			targetSpoilSignalConn = nil
		end
		if targetStunSignalConn then
			targetStunSignalConn:Disconnect()
			targetStunSignalConn = nil
		end

		if newTarget then
			targetHpSignalConn = newTarget:GetAttributeChangedSignal("CurrentHP"):Connect(refreshTargetFrame)
			targetSpoilSignalConn = newTarget:GetAttributeChangedSignal("IsSpoiled"):Connect(refreshTargetFrame)
			targetStunSignalConn = newTarget:GetAttributeChangedSignal("IsStunned"):Connect(refreshTargetFrame)
		end
		refreshTargetFrame()
		refreshPartyWindow()
	end)

	I18n.OnLanguageChanged.Event:Connect(function()
		refreshPlayerHud()
		refreshTargetFrame()
	end)

	-- Draggable Windows by TitleBar & Item Drag-and-Drop System
	local function isPointInsideGui(pt: Vector2, guiObj: GuiObject?): boolean
		if not guiObj or not guiObj.Visible then
			return false
		end
		local pos = guiObj.AbsolutePosition
		local sz = guiObj.AbsoluteSize
		return pt.X >= pos.X and pt.X <= (pos.X + sz.X) and pt.Y >= pos.Y and pt.Y <= (pos.Y + sz.Y)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
		then
			local clickPt = Vector2.new(input.Position.X, input.Position.Y)
			local orderList = workshopUI.windowFocusOrder
			for i = #orderList, 1, -1 do
				local winFrame = orderList[i]
				if winFrame and winFrame.Visible and isPointInsideGui(clickPt, winFrame) then
					if workshopUI.bringWindowToFront then
						workshopUI.bringWindowToFront(winFrame)
					end
					break
				end
			end
		end

		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			toggleModal(inventoryModal)
		elseif input.KeyCode == Enum.KeyCode.J then
			toggleModal(jobUI.jobModalFrame)
		elseif input.KeyCode == Enum.KeyCode.C then
			toggleModal(workshopUI.statsModal)
		elseif input.KeyCode == Enum.KeyCode.Z then
			Remotes.ToggleAutoSoulshot:FireServer()
		elseif input.KeyCode == Enum.KeyCode.Two then
			Remotes.UsePotion:FireServer("HP")
		elseif input.KeyCode == Enum.KeyCode.Three then
			Remotes.UsePotion:FireServer("MP")
		end
	end)

	local function doesItemMatchPaperdollSlot(itemSlot: string, targetSlot: string): boolean
		if itemSlot == targetSlot then
			return true
		end
		if (itemSlot == "Accessory1" or itemSlot == "Accessory2") and (targetSlot == "Accessory1" or targetSlot == "Accessory2") then
			return true
		end
		return false
	end

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local mousePt = Vector2.new(input.Position.X, input.Position.Y)

		-- 1) Active Window TitleBar Dragging (Clamped to Screen Viewport)
		local dragWin = workshopUI.draggingWindow
		if dragWin and dragWin.Visible then
			local delta = mousePt - workshopUI.windowDragStartMouse
			local cam = Workspace.CurrentCamera
			local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
			local halfW = dragWin.AbsoluteSize.X * 0.5
			local halfH = dragWin.AbsoluteSize.Y * 0.5
			local targetX = math.clamp(workshopUI.windowDragStartPos.X + delta.X, halfW + 4, math.max(halfW + 4, vp.X - halfW - 4))
			local targetY = math.clamp(workshopUI.windowDragStartPos.Y + delta.Y, halfH + 4, math.max(halfH + 4, vp.Y - halfH - 4))
			dragWin.Position = UDim2.fromOffset(targetX, targetY)
			return
		end

		-- 2) Active Inventory Item Dragging & Drop Target Highlights
		local dragIdx = workshopUI.draggedCellIndex
		if dragIdx and inventoryModal and inventoryModal.Visible then
			local entry = currentGridEntries[dragIdx]
			if not entry then
				workshopUI.draggedCellIndex = nil
				workshopUI.isDraggingItem = false
				if workshopUI.dragGhostFrame then
					workshopUI.dragGhostFrame.Visible = false
				end
				return
			end

			if not workshopUI.isDraggingItem then
				if (mousePt - workshopUI.dragStartMousePos).Magnitude >= 6 then
					workshopUI.isDraggingItem = true
					local style = ItemsConfig.GetItemVisualStyle(entry.id)
					if workshopUI.dragGhostFrame and workshopUI.dragGhostGrad and workshopUI.dragGhostGlyph and workshopUI.dragGhostGrade then
						workshopUI.dragGhostGrad.Color = ColorSequence.new(style.tintTop, style.tintBottom)
						workshopUI.dragGhostGlyph.Text = style.glyph
						workshopUI.dragGhostGlyph.TextColor3 = style.glyphColor
						workshopUI.dragGhostGrade.Text = entry.grade or ""
						workshopUI.dragGhostGrade.Visible = (entry.grade ~= nil)
						workshopUI.dragGhostFrame.Visible = true
					end
					if itemTooltipFrame then
						itemTooltipFrame.Visible = false
					end
				end
			end

			if workshopUI.isDraggingItem and workshopUI.dragGhostFrame then
				workshopUI.dragGhostFrame.Position = UDim2.fromOffset(mousePt.X, mousePt.Y)

				local draggedItemData = if entry.kind == "Equipment" then ItemsConfig.GetItem(entry.id) else nil

				-- Highlight matching Paperdoll equipment slots
				for slotKey, pCell in pairs(paperdollCells) do
					local isMatch = draggedItemData ~= nil and doesItemMatchPaperdollSlot(draggedItemData.slot, slotKey)
					local isHovered = isPointInsideGui(mousePt, pCell.button)
					if isMatch and isHovered then
						pCell.stroke.Color = Color3.fromRGB(255, 240, 85)
						pCell.stroke.Thickness = 2.6
					elseif isMatch then
						pCell.stroke.Color = Color3.fromRGB(95, 255, 135)
						pCell.stroke.Thickness = 2.2
					else
						local eqMap = clientProfile.EquippedItems :: { [string]: string? }
						local eqData = ItemsConfig.GetItem(eqMap[slotKey])
						if eqData then
							local st = ItemsConfig.GetItemVisualStyle(eqData.id)
							pCell.stroke.Color = if eqData.grade == "D" then Color3.fromRGB(95, 205, 255) else st.borderColor
							pCell.stroke.Thickness = if eqData.grade == "D" then 1.6 else 1.2
						else
							pCell.stroke.Color = Color3.fromRGB(68, 60, 44)
							pCell.stroke.Thickness = 1.0
						end
					end
				end

				-- Highlight hovered Bag Grid cell
				for idx = 1, TOTAL_L2_GRID_SLOTS do
					local bCell = bagGridCells[idx]
					if bCell then
						if isPointInsideGui(mousePt, bCell.button) and idx ~= dragIdx then
							bCell.stroke.Color = Color3.fromRGB(255, 235, 85)
							bCell.stroke.Thickness = 2.4
						elseif idx == dragIdx then
							bCell.stroke.Color = Color3.fromRGB(0, 225, 255)
							bCell.stroke.Thickness = 2.0
						else
							local cEntry = currentGridEntries[idx]
							if cEntry then
								local st = ItemsConfig.GetItemVisualStyle(cEntry.id)
								bCell.stroke.Color = if cEntry.grade == "D" then Color3.fromRGB(95, 205, 255) else st.borderColor
								bCell.stroke.Thickness = if cEntry.grade == "D" then 1.5 else 1.1
							else
								bCell.stroke.Color = Color3.fromRGB(46, 42, 34)
								bCell.stroke.Thickness = 1.0
							end
						end
					end
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		if workshopUI.draggingWindow then
			workshopUI.draggingWindow = nil
		end

		local dragIdx = workshopUI.draggedCellIndex
		local wasDragging = workshopUI.isDraggingItem
		workshopUI.draggedCellIndex = nil
		workshopUI.isDraggingItem = false

		if workshopUI.dragGhostFrame then
			workshopUI.dragGhostFrame.Visible = false
		end

		if wasDragging and dragIdx and inventoryModal and inventoryModal.Visible then
			local mousePt = Vector2.new(input.Position.X, input.Position.Y)
			local draggedEntry = currentGridEntries[dragIdx]

			if draggedEntry and draggedEntry.kind == "Equipment" and draggedEntry.bagIndex then
				local fromBagIdx = draggedEntry.bagIndex
				local itemData = ItemsConfig.GetItem(draggedEntry.id)

				-- Check if dropped onto a matching Paperdoll Slot or inside the Paperdoll Panel
				local droppedOnPaperdoll = false
				for slotKey, pCell in pairs(paperdollCells) do
					if isPointInsideGui(mousePt, pCell.button) then
						if itemData and doesItemMatchPaperdollSlot(itemData.slot, slotKey) then
							droppedOnPaperdoll = true
						end
						break
					end
				end

				if not droppedOnPaperdoll and isPointInsideGui(mousePt, workshopUI.leftPaperdollPanel) then
					droppedOnPaperdoll = true
				end

				if droppedOnPaperdoll then
					if itemData and playerState.level < itemData.reqLevel then
						UIController.AddSystemLog(
							I18n.t("LOG_EQUIP_LOW_LEVEL", {
								item = I18n.t(itemData.nameKey),
								reqLv = itemData.reqLevel,
							}),
							Color3.fromRGB(255, 95, 95)
						)
					else
						Remotes.EquipItem:FireServer(fromBagIdx)
					end
					refreshInventoryPaperdollAndBag()
					return
				end

				-- Check if dropped onto another Bag Grid Cell to swap/move item inside InventoryBag
				for targetIdx = 1, TOTAL_L2_GRID_SLOTS do
					local bCell = bagGridCells[targetIdx]
					if bCell and targetIdx ~= dragIdx and isPointInsideGui(mousePt, bCell.button) then
						local targetEntry = currentGridEntries[targetIdx]
						local bag = clientProfile.InventoryBag
						if targetEntry and targetEntry.kind == "Equipment" and targetEntry.bagIndex then
							local toBagIdx = targetEntry.bagIndex
							if fromBagIdx >= 1 and fromBagIdx <= #bag and toBagIdx >= 1 and toBagIdx <= #bag and fromBagIdx ~= toBagIdx then
								bag[fromBagIdx], bag[toBagIdx] = bag[toBagIdx], bag[fromBagIdx]
								selectedGridCellIndex = targetIdx
								Remotes.SwapBagItems:FireServer(fromBagIdx, toBagIdx)
							end
						elseif not targetEntry and fromBagIdx >= 1 and fromBagIdx <= #bag and #bag >= 2 then
							local movedId = table.remove(bag, fromBagIdx)
							if movedId then
								table.insert(bag, movedId)
								Remotes.SwapBagItems:FireServer(fromBagIdx, #bag + 1)
							end
						end
						break
					end
				end
			end

			refreshInventoryPaperdollAndBag()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, slotUi in ipairs(hotbarSlots) do
			local rem, total = CombatController.GetSlotCooldownRemaining(slotUi.slot)
			if rem > 0.05 then
				slotUi.cooldownOverlay.Visible = true
				slotUi.cooldownText.Visible = true
				local ratio = math.clamp(rem / math.max(0.1, total), 0, 1)
				slotUi.cooldownOverlay.Size = UDim2.fromScale(1, ratio)
				slotUi.cooldownText.Text = string.format("%.1f", rem)
			else
				slotUi.cooldownOverlay.Visible = false
				slotUi.cooldownText.Visible = false
			end
		end

		if hpPotionCooldownOverlay and hpPotionCooldownText then
			local hpRem = math.max(0, hpPotionReadyAt - now)
			if hpRem > 0.05 then
				hpPotionCooldownOverlay.Visible = true
				hpPotionCooldownText.Visible = true
				local ratio = math.clamp(hpRem / GameConstants.POTION_COOLDOWN, 0, 1)
				hpPotionCooldownOverlay.Size = UDim2.fromScale(1, ratio)
				hpPotionCooldownText.Text = string.format("%.1f", hpRem)
			else
				hpPotionCooldownOverlay.Visible = false
				hpPotionCooldownText.Visible = false
			end
		end

		if mpPotionCooldownOverlay and mpPotionCooldownText then
			local mpRem = math.max(0, mpPotionReadyAt - now)
			if mpRem > 0.05 then
				mpPotionCooldownOverlay.Visible = true
				mpPotionCooldownText.Visible = true
				local ratio = math.clamp(mpRem / GameConstants.POTION_COOLDOWN, 0, 1)
				mpPotionCooldownOverlay.Size = UDim2.fromScale(1, ratio)
				mpPotionCooldownText.Text = string.format("%.1f", mpRem)
			else
				mpPotionCooldownOverlay.Visible = false
				mpPotionCooldownText.Visible = false
			end
		end

		if soulshotStroke then
			if clientProfile.AutoSoulshot and clientProfile.EnergyShots > 0 then
				local pulse = (math.sin(os.clock() * 6.0) + 1) * 0.5
				soulshotStroke.Color = Color3.fromRGB(65, 250, 130):Lerp(Color3.fromRGB(255, 220, 75), pulse)
			elseif clientProfile.AutoSoulshot then
				soulshotStroke.Color = Color3.fromRGB(185, 135, 55)
			else
				soulshotStroke.Color = Color3.fromRGB(75, 80, 92)
			end
		end

		refreshPvpToggleVisuals()
		updateRadarMinimap()
	end)

	-- Live PvP / Karma attribute listeners on LocalPlayer
	for _, attrName in ipairs({ "Karma", "IsPvpFlagged", "PvpKills", "PkKills" }) do
		localPlayer:GetAttributeChangedSignal(attrName):Connect(function()
			refreshPlayerHud()
		end)
	end

	-- Party Window & Invite Listeners (Excludes LocalPlayer and strictly filters out Mobs)
	Remotes.PartyUpdated.OnClientEvent:Connect(function(rawMembers: any)
		table.clear(partyPvpUI.partyMembersState)
		if type(rawMembers) == "table" then
			for _, m in ipairs(rawMembers) do
				if type(m) == "table" then
					local mModel = if typeof(m.model) == "Instance" and m.model:IsA("Model") then m.model else nil
					local mName = tostring(m.name or "Player")
					local isMobEntry = (mModel ~= nil and (mModel:GetAttribute("IsMob") == true or mModel:GetAttribute("MobId") ~= nil))
						or (mModel ~= nil and workshopUI.MobsConfig[mModel.Name] ~= nil)
						or (workshopUI.MobsConfig[mName] ~= nil)
					local isSelf = (not m.isBot)
						and (
							(mModel ~= nil and mModel == localPlayer.Character)
							or mName == localPlayer.Name
							or mName == localPlayer.DisplayName
						)
					if not isSelf and not isMobEntry then
						table.insert(partyPvpUI.partyMembersState, {
							name = mName,
							classId = tostring(m.classId or "RiotPolice"),
							level = tonumber(m.level) or 1,
							hp = tonumber(m.hp) or 100,
							maxHp = math.max(1, tonumber(m.maxHp) or 100),
							mp = tonumber(m.mp) or 100,
							maxMp = math.max(1, tonumber(m.maxMp) or 100),
							isLeader = m.isLeader == true,
							isBot = m.isBot == true,
							model = mModel,
						})
					end
				end
			end
		end
		refreshPartyWindow()
	end)

	Remotes.PartyInviteReceived.OnClientEvent:Connect(function(leaderName: any)
		if partyPvpUI.partyInvitePopupFrame and partyPvpUI.partyInviteLabel then
			partyPvpUI.partyInviteLabel.Text =
				I18n.t("UI_PARTY_INVITE_BANNER", { leader = tostring(leaderName or "Leader") })
			partyPvpUI.partyInviteAcceptBtn.Text = I18n.t("UI_PARTY_ACCEPT")
			partyPvpUI.partyInviteDeclineBtn.Text = I18n.t("UI_PARTY_DECLINE")
			partyPvpUI.partyInvitePopupFrame.Visible = true
		end
	end)

	-- Profile Snapshot Synchronization Listener
	Remotes.ProfileUpdated.OnClientEvent:Connect(function(profileSnapshot: any)
		if type(profileSnapshot) ~= "table" then
			return
		end

		clientProfile.IsCharacterCreated = profileSnapshot.IsCharacterCreated == true
		if type(profileSnapshot.Gender) == "string" then
			clientProfile.Gender = profileSnapshot.Gender
		end
		if type(profileSnapshot.RaceId) == "string" then
			clientProfile.RaceId = profileSnapshot.RaceId
			playerState.raceId = profileSnapshot.RaceId
		end
		if type(profileSnapshot.CurrentClassId) == "string" then
			clientProfile.CurrentClassId = profileSnapshot.CurrentClassId
			playerState.classId = profileSnapshot.CurrentClassId
		end
		if type(profileSnapshot.Cash) == "number" then
			clientProfile.Cash = profileSnapshot.Cash
			playerState.cash = profileSnapshot.Cash
		end
		if type(profileSnapshot.TrashTokens) == "number" then
			clientProfile.TrashTokens = profileSnapshot.TrashTokens
			playerState.trashTokens = profileSnapshot.TrashTokens
		end
		if type(profileSnapshot.HasWeapon) == "boolean" then
			local wasBroken = not clientProfile.HasWeapon
			clientProfile.HasWeapon = profileSnapshot.HasWeapon
			if wasBroken and clientProfile.HasWeapon then
				workshopUI.lastEnchantFeedbackText = nil
				workshopUI.lastEnchantFeedbackColor = nil
			end
		end
		if type(profileSnapshot.WeaponEnchant) == "number" then
			clientProfile.WeaponEnchant = profileSnapshot.WeaponEnchant
		end
		if type(profileSnapshot.EnergyShots) == "number" then
			clientProfile.EnergyShots = profileSnapshot.EnergyShots
		end
		if type(profileSnapshot.AutoSoulshot) == "boolean" then
			clientProfile.AutoSoulshot = profileSnapshot.AutoSoulshot
		end
		if type(profileSnapshot.EnchantScrolls) == "number" then
			clientProfile.EnchantScrolls = profileSnapshot.EnchantScrolls
		end
		if type(profileSnapshot.CrystalShards) == "number" then
			clientProfile.CrystalShards = profileSnapshot.CrystalShards
		end
		if type(profileSnapshot.HpPotions) == "number" then
			clientProfile.HpPotions = profileSnapshot.HpPotions
		end
		if type(profileSnapshot.MpPotions) == "number" then
			clientProfile.MpPotions = profileSnapshot.MpPotions
		end
		if type(profileSnapshot.Karma) == "number" then
			clientProfile.Karma = profileSnapshot.Karma
		end
		if type(profileSnapshot.PvpKills) == "number" then
			clientProfile.PvpKills = profileSnapshot.PvpKills
		end
		if type(profileSnapshot.PkKills) == "number" then
			clientProfile.PkKills = profileSnapshot.PkKills
		end
		if type(profileSnapshot.EquippedItems) == "table" then
			local rawEq = profileSnapshot.EquippedItems
			clientProfile.EquippedItems = {
				Weapon = if type(rawEq.Weapon) == "string" then rawEq.Weapon else nil,
				Chest = if type(rawEq.Chest) == "string" then rawEq.Chest else nil,
				Legs = if type(rawEq.Legs) == "string" then rawEq.Legs else nil,
				Boots = if type(rawEq.Boots) == "string" then rawEq.Boots else nil,
				Accessory1 = if type(rawEq.Accessory1) == "string" then rawEq.Accessory1 else nil,
				Accessory2 = if type(rawEq.Accessory2) == "string" then rawEq.Accessory2 else nil,
			}
			clientProfile.HasWeapon = (clientProfile.EquippedItems.Weapon ~= nil)
		end
		if type(profileSnapshot.InventoryBag) == "table" then
			local cleanBag: { string } = {}
			for _, id in ipairs(profileSnapshot.InventoryBag) do
				if type(id) == "string" then
					table.insert(cleanBag, id)
				end
			end
			clientProfile.InventoryBag = cleanBag
		end
		if type(profileSnapshot.UnlockedClasses) == "table" then
			clientProfile.UnlockedClasses = profileSnapshot.UnlockedClasses
		end
		if type(profileSnapshot.ClassProgress) == "table" then
			clientProfile.ClassProgress = profileSnapshot.ClassProgress
		end
		if type(profileSnapshot.BossKills) == "table" then
			clientProfile.BossKills = {
				PlatformBaron = tonumber(profileSnapshot.BossKills.PlatformBaron) or 0,
				BlackFridayGolem = tonumber(profileSnapshot.BossKills.BlackFridayGolem) or 0,
				NightclubKing = tonumber(profileSnapshot.BossKills.NightclubKing) or 0,
				InflationArchitect = tonumber(profileSnapshot.BossKills.InflationArchitect) or 0,
			}
		end

		if not clientProfile.IsCharacterCreated then
			inventoryModal.Visible = false
			jobUI.jobModalFrame.Visible = false
			workshopUI.statsModal.Visible = false
			creationUI.charCreationScreen.Visible = true
		else
			creationUI.charCreationScreen.Visible = false
		end

		refreshPlayerHud()
	end)

	-- Potion VFX Cooldown Sync Listener
	Remotes.PotionVFX.OnClientEvent:Connect(function(character: Model, potionType: string, _amountRestored: number)
		if character == localPlayer.Character then
			if potionType == "HP" then
				hpPotionReadyAt = os.clock() + GameConstants.POTION_COOLDOWN
			elseif potionType == "MP" then
				mpPotionReadyAt = os.clock() + GameConstants.POTION_COOLDOWN
			end
		end
	end)

	-- Interactive 3D NPC Window Opener Listener (Multi-Window Compatible)
	Remotes.OpenNpcWindow.OnClientEvent:Connect(function(windowType: string)
		if creationUI.charCreationScreen and creationUI.charCreationScreen.Visible then
			return
		end

		if windowType == "Workshop" then
			activeInventoryTab = "Workshop"
			inventoryModal.Visible = true
			if workshopUI.bringWindowToFront then
				workshopUI.bringWindowToFront(inventoryModal)
			end
			refreshModals()
		elseif windowType == "Job" then
			jobUI.previewedJobClassId = playerState.classId
			jobUI.jobModalFrame.Visible = true
			if workshopUI.bringWindowToFront then
				workshopUI.bringWindowToFront(jobUI.jobModalFrame)
			end
			refreshModals()
		end
	end)

	-- Enchant Result Visual Flash Listener
	Remotes.EnchantResultFeedback.OnClientEvent:Connect(
		function(success: boolean, newEnchantLevel: number, crystalsGained: number)
			clientProfile.WeaponEnchant = newEnchantLevel
			if success then
				clientProfile.HasWeapon = true
				workshopUI.lastEnchantFeedbackText = I18n.t("UI_ENCHANT_STATUS_SUCCESS", { lv = newEnchantLevel })
				workshopUI.lastEnchantFeedbackColor = Color3.fromRGB(95, 255, 140)
				if workshopUI.enchantWeaponBtn and workshopUI.enchantWeaponCard then
					workshopUI.enchantWeaponBtn.BackgroundColor3 = Color3.fromRGB(40, 195, 95)
					workshopUI.enchantWeaponCard.BackgroundColor3 = Color3.fromRGB(18, 52, 30)
					TweenService:Create(
						workshopUI.enchantWeaponBtn,
						TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Color3.fromRGB(175, 125, 28) }
					):Play()
					TweenService:Create(
						workshopUI.enchantWeaponCard,
						TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Color3.fromRGB(12, 15, 22) }
					):Play()
				end
			else
				clientProfile.HasWeapon = false
				clientProfile.EquippedItems.Weapon = nil
				workshopUI.lastEnchantFeedbackText = I18n.t("UI_ENCHANT_STATUS_FAIL", { crystals = crystalsGained })
				workshopUI.lastEnchantFeedbackColor = Color3.fromRGB(255, 85, 85)
				if workshopUI.enchantWeaponBtn and workshopUI.enchantWeaponCard then
					workshopUI.enchantWeaponBtn.BackgroundColor3 = Color3.fromRGB(215, 42, 48)
					workshopUI.enchantWeaponCard.BackgroundColor3 = Color3.fromRGB(62, 16, 20)
					TweenService:Create(
						workshopUI.enchantWeaponBtn,
						TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Color3.fromRGB(58, 32, 36) }
					):Play()
					TweenService:Create(
						workshopUI.enchantWeaponCard,
						TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundColor3 = Color3.fromRGB(12, 15, 22) }
					):Play()
				end
			end
			refreshModals()
		end
	)

	-- Server System Notification Listener
	Remotes.SendChatMessage.OnClientEvent:Connect(
		function(i18nKey: string, rawParams: { [string]: any }?, rgbList: { number }?)
			local params: { [string]: any } = {}
			if type(rawParams) == "table" then
				for k, v in pairs(rawParams) do
					params[k] = v
				end
				if type(rawParams.bossKey) == "string" then
					params.boss = I18n.t(rawParams.bossKey)
				end
				if type(rawParams.classKey) == "string" then
					params.class = I18n.t(rawParams.classKey)
				end
				if type(rawParams.raceKey) == "string" then
					params.race = I18n.t(rawParams.raceKey)
				end
				if type(rawParams.skillKey) == "string" then
					params.skill = I18n.t(rawParams.skillKey)
				end
				if type(rawParams.itemKey) == "string" then
					params.item = I18n.t(rawParams.itemKey)
				end
			end

			local color = Color3.fromRGB(235, 215, 135)
			if type(rgbList) == "table" and #rgbList >= 3 then
				color = Color3.fromRGB(rgbList[1] or 235, rgbList[2] or 215, rgbList[3] or 135)
			end

			UIController.AddSystemLog(I18n.t(i18nKey, params), color)
		end
	)

	-- System Combat Log Listeners
	Remotes.CombatHitFeedback.OnClientEvent:Connect(
		function(targetModel: Model, damage: number, isCrit: boolean, isMiss: boolean)
			if isMiss or typeof(targetModel) ~= "Instance" or not targetModel:IsA("Model") then
				return
			end
			local nameKey = (targetModel:GetAttribute("NameKey") :: string?) or targetModel.Name
			local mobName = I18n.t(nameKey)

			if isCrit then
				UIController.AddSystemLog(
					I18n.t("LOG_DMG_CRIT", { dmg = damage, target = mobName }),
					Color3.fromRGB(255, 215, 65)
				)
			else
				UIController.AddSystemLog(
					I18n.t("LOG_DMG_DEALT", { dmg = damage, target = mobName }),
					Color3.fromRGB(255, 165, 90)
				)
			end
		end
	)

	Remotes.SkillVFX.OnClientEvent:Connect(function(skillId: string, casterPlayer: Player, payload: { [string]: any }?)
		if casterPlayer ~= localPlayer then
			return
		end
		local data = payload or {}

		if skillId == "NO_TARGET" then
			if data.reason == "OUT_OF_CONE_OR_RANGE" then
				return
			end
			local failedId = (data.skillId :: string?) or ""
			local sData = SkillsConfig[failedId]
			local sName = if sData then I18n.t(sData.nameKey) else failedId
			UIController.AddSystemLog(I18n.t("LOG_NO_TARGET", { skill = sName }), Color3.fromRGB(255, 110, 110))
			return
		end

		local sData = SkillsConfig[skillId]
		local skillName = if sData then I18n.t(sData.nameKey) else skillId
		local targetModel = data.targetModel :: Model?
		local mobName = if targetModel
			then I18n.t((targetModel:GetAttribute("NameKey") :: string?) or targetModel.Name)
			else "Mob"

		if skillId == "SKILL_SPOIL" then
			UIController.AddSystemLog(
				I18n.t("LOG_SPOIL_SUCCESS_CHAT", { target = mobName }),
				Color3.fromRGB(0, 235, 255)
			)
		elseif skillId == "SKILL_SWEEP" then
			local tokens = (data.tokens :: number?) or 0
			local cash = (data.cash :: number?) or 0
			UIController.AddSystemLog(
				I18n.t("LOG_SWEEP_GAIN", { tokens = tokens, cash = cash }),
				Color3.fromRGB(0, 245, 220)
			)
		elseif data.damage and (data.damage :: number) > 0 then
			UIController.AddSystemLog(
				I18n.t("LOG_SKILL_DMG", {
					skill = skillName,
					dmg = data.damage :: number,
					target = mobName,
				}),
				Color3.fromRGB(255, 200, 75)
			)
		else
			UIController.AddSystemLog(
				I18n.t("LOG_SKILL_CAST", { skill = skillName }),
				Color3.fromRGB(255, 230, 105)
			)
		end
	end)

	Remotes.PlayerStatsUpdated.OnClientEvent:Connect(
		function(
			level: number,
			exp: number,
			maxExp: number,
			cash: number,
			hp: number,
			maxHp: number,
			raceId: string?,
			classId: string?,
			trashTokens: number?,
			mp: number?,
			maxMp: number?
		)
			if playerState.initialized then
				if hp < playerState.hp and maxHp == playerState.maxHp then
					local dmgTaken = playerState.hp - hp
					UIController.AddSystemLog(
						I18n.t("LOG_DMG_TAKEN", { dmg = dmgTaken }),
						Color3.fromRGB(255, 80, 80)
					)
				end

				local newClass = classId or playerState.classId
				local newRace = raceId or playerState.raceId
				if newClass ~= playerState.classId or newRace ~= playerState.raceId then
					local cData = ClassesConfig[newClass]
					local rData = RacesConfig[newRace :: RacesConfig.RaceId]
					UIController.AddSystemLog(
						I18n.t("LOG_CLASS_CHANGED", {
							class = if cData then I18n.t(cData.nameKey) else newClass,
							race = if rData then I18n.t(rData.nameKey) else newRace,
						}),
						Color3.fromRGB(255, 225, 95)
					)
				else
					local cashDiff = cash - playerState.cash
					local expDiff = exp - playerState.exp
					if level > playerState.level then
						UIController.AddSystemLog(
							I18n.t("LOG_LEVEL_UP", { lv = level }),
							Color3.fromRGB(120, 255, 140)
						)
					end
					if cashDiff > 0 and (expDiff > 0 or level > playerState.level) then
						local gainedExp = if expDiff > 0 then expDiff else exp
						UIController.AddSystemLog(
							I18n.t("LOG_REWARD_GAIN", { exp = gainedExp, cash = cashDiff }),
							Color3.fromRGB(110, 245, 145)
						)
					end
				end
			end

			playerState.initialized = true
			playerState.level = level
			playerState.exp = exp
			playerState.maxExp = maxExp
			playerState.cash = cash
			playerState.hp = hp
			playerState.maxHp = maxHp
			playerState.maxMp = maxMp or (100 + (level - 1) * 20)
			playerState.mp = mp or playerState.maxMp
			if raceId then
				playerState.raceId = raceId
			end
			if classId then
				playerState.classId = classId
			end
			if trashTokens ~= nil then
				playerState.trashTokens = trashTokens
			end
			refreshPlayerHud()
			refreshTargetFrame()
		end
	)
end

return UIController
