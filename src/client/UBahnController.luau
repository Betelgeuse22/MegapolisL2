--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18nFolder = Shared:WaitForChild("i18n")
local I18n = require(I18nFolder:WaitForChild("I18n"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local localPlayer = Players.LocalPlayer

local UBahnController = {}

local initialized = false
local TRIGGER_CHECK_INTERVAL = 0.1

-- Lineage 2 MegapolisL2 UI Palette
local L2_BG_COLOR = Color3.fromRGB(16, 19, 27)
local L2_PANEL_COLOR = Color3.fromRGB(22, 26, 36)
local L2_ROW_COLOR = Color3.fromRGB(27, 32, 44)
local L2_ROW_HOVER = Color3.fromRGB(38, 45, 62)
local L2_ROW_LOCKED = Color3.fromRGB(22, 24, 32)
local L2_GOLD_BORDER = Color3.fromRGB(175, 145, 85)
local L2_SUB_BORDER = Color3.fromRGB(95, 82, 55)

type CategoryStyle = {
	color: Color3,
	labelKey: string,
	sortOrder: number,
}

local CATEGORY_STYLES: { [string]: CategoryStyle } = {
	safe = {
		color = Color3.fromRGB(62, 204, 113), -- Green
		labelKey = "UI_UBAHN_CAT_SAFE",
		sortOrder = 1,
	},
	farm = {
		color = Color3.fromRGB(245, 152, 46), -- Orange
		labelKey = "UI_UBAHN_CAT_FARM",
		sortOrder = 2,
	},
	rb = {
		color = Color3.fromRGB(230, 68, 68), -- Red
		labelKey = "UI_UBAHN_CAT_RB",
		sortOrder = 3,
	},
}

local DEFAULT_CATEGORY_STYLE: CategoryStyle = {
	color = Color3.fromRGB(150, 165, 190),
	labelKey = "UI_UBAHN_CAT_SAFE",
	sortOrder = 4,
}

type StationEntry = {
	folder: Folder,
	stationId: string,
	displayName: string,
	categoryKey: string,
	categoryStyle: CategoryStyle,
	minLevel: number,
}

-- Runtime state
local currentStationId: string? = nil
local dismissedStationId: string? = nil
local isMenuOpen = false
local checkAccumulator = 0
local watchedStations: { [Instance]: boolean } = {}
local watchedStationsFolder: Instance? = nil

-- UI references
local screenGui: ScreenGui
local mainFrame: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local closeButton: TextButton
local listScrollFrame: ScrollingFrame
local listLayout: UIListLayout
local emptyLabel: TextLabel
local footerHintLabel: TextLabel

local function hideStationPart(part: Instance)
	if (part.Name == "Trigger" or part.Name == "Arrival") and part:IsA("BasePart") then
		part.Transparency = 1
		part.CanCollide = false
	end
end

local function setupStationFolder(station: Instance)
	if not station:IsA("Folder") or watchedStations[station] then
		return
	end
	watchedStations[station] = true

	for _, child in ipairs(station:GetChildren()) do
		hideStationPart(child)
	end

	station.ChildAdded:Connect(hideStationPart)
	station.Destroying:Connect(function()
		watchedStations[station] = nil
	end)
end

local function bindStationsFolder(stationsFolder: Instance)
	if watchedStationsFolder == stationsFolder then
		return
	end
	watchedStationsFolder = stationsFolder

	for _, child in ipairs(stationsFolder:GetChildren()) do
		setupStationFolder(child)
	end

	stationsFolder.ChildAdded:Connect(setupStationFolder)
end

local function getStationsFolder(): Instance?
	local mapFolder = Workspace:FindFirstChild("Map")
	if not mapFolder then
		return nil
	end
	return mapFolder:FindFirstChild("UBahnStations")
end

local function watchWorkspaceMap()
	local function attachToMap(mapFolder: Instance)
		local existingStations = mapFolder:FindFirstChild("UBahnStations")
		if existingStations then
			bindStationsFolder(existingStations)
		end

		mapFolder.ChildAdded:Connect(function(child: Instance)
			if child.Name == "UBahnStations" then
				bindStationsFolder(child)
			end
		end)
	end

	local existingMap = Workspace:FindFirstChild("Map")
	if existingMap then
		attachToMap(existingMap)
	else
		Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Map" then
				attachToMap(child)
			end
		end)
	end
end

local function getLocalizedStationName(station: Instance): string
	local lang = I18n.GetLanguage()
	local ruName = station:GetAttribute("DisplayName_RU")
	local enName = station:GetAttribute("DisplayName_EN")

	if lang == "ru" then
		if type(ruName) == "string" and #ruName > 0 then
			return ruName
		end
		if type(enName) == "string" and #enName > 0 then
			return enName
		end
	else
		if type(enName) == "string" and #enName > 0 then
			return enName
		end
		if type(ruName) == "string" and #ruName > 0 then
			return ruName
		end
	end

	return station.Name
end

local function getCategoryStyle(station: Instance): (string, CategoryStyle)
	local rawCategory = station:GetAttribute("Category")
	if type(rawCategory) == "string" then
		local normalized = string.lower(rawCategory)
		local style = CATEGORY_STYLES[normalized]
		if style then
			return rawCategory, style
		end
	end
	return "Safe", DEFAULT_CATEGORY_STYLE
end

local function getPlayerLevel(): number
	local attrLv = localPlayer:GetAttribute("Level")
	if type(attrLv) == "number" then
		return math.max(1, math.floor(attrLv))
	end
	return 1
end

local function isPointInsidePart(part: BasePart, worldPos: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local halfSize = part.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X
		and math.abs(localPos.Y) <= halfSize.Y
		and math.abs(localPos.Z) <= halfSize.Z
end

local function detectCurrentStation(): string?
	local stationsFolder = getStationsFolder()
	if not stationsFolder then
		return nil
	end

	local character = localPlayer.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return nil
	end

	local rootPos = rootPart.Position
	for _, station in ipairs(stationsFolder:GetChildren()) do
		if station:IsA("Folder") then
			local trigger = station:FindFirstChild("Trigger")
			if trigger and trigger:IsA("BasePart") then
				if isPointInsidePart(trigger, rootPos) then
					return station.Name
				end
			end
		end
	end

	return nil
end

local function closeMenu()
	if not isMenuOpen then
		return
	end
	isMenuOpen = false
	if mainFrame then
		mainFrame.Visible = false
	end
end

local function clearStationRows()
	for _, child in ipairs(listScrollFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function rebuildStationList()
	if not mainFrame then
		return
	end

	titleLabel.Text = I18n.t("UI_UBAHN_TITLE")
	footerHintLabel.Text = I18n.t("UI_UBAHN_HINT")

	local stationsFolder = getStationsFolder()
	local currentStationDisplay = currentStationId or "-"
	if stationsFolder and currentStationId then
		local curFolder = stationsFolder:FindFirstChild(currentStationId)
		if curFolder then
			currentStationDisplay = getLocalizedStationName(curFolder)
		end
	end
	subtitleLabel.Text = I18n.t("UI_UBAHN_CURRENT_STATION", { station = currentStationDisplay })

	clearStationRows()

	local entries: { StationEntry } = {}
	if stationsFolder then
		for _, station in ipairs(stationsFolder:GetChildren()) do
			if station:IsA("Folder") and station.Name ~= currentStationId then
				local arrival = station:FindFirstChild("Arrival")
				if arrival and arrival:IsA("BasePart") then
					local catKey, catStyle = getCategoryStyle(station)
					local rawMinLv = station:GetAttribute("MinLevel")
					local minLevel = if type(rawMinLv) == "number" and rawMinLv > 1 then math.floor(rawMinLv) else 0

					table.insert(entries, {
						folder = station,
						stationId = station.Name,
						displayName = getLocalizedStationName(station),
						categoryKey = catKey,
						categoryStyle = catStyle,
						minLevel = minLevel,
					})
				end
			end
		end
	end

	table.sort(entries, function(a: StationEntry, b: StationEntry): boolean
		if a.categoryStyle.sortOrder ~= b.categoryStyle.sortOrder then
			return a.categoryStyle.sortOrder < b.categoryStyle.sortOrder
		end
		if a.minLevel ~= b.minLevel then
			return a.minLevel < b.minLevel
		end
		return a.displayName < b.displayName
	end)

	emptyLabel.Visible = (#entries == 0)
	emptyLabel.Text = I18n.t("UI_UBAHN_EMPTY")

	local playerLevel = getPlayerLevel()

	for index, entry in ipairs(entries) do
		local isLocked = entry.minLevel > 0 and playerLevel < entry.minLevel
		local catColor = entry.categoryStyle.color

		local rowBtn = Instance.new("TextButton")
		rowBtn.Name = "Station_" .. entry.stationId
		rowBtn.LayoutOrder = index
		rowBtn.Size = UDim2.new(1, -8, 0, 56)
		rowBtn.BackgroundColor3 = if isLocked then L2_ROW_LOCKED else L2_ROW_COLOR
		rowBtn.AutoButtonColor = false
		rowBtn.Text = ""
		rowBtn.Parent = listScrollFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = rowBtn

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = if isLocked then Color3.fromRGB(65, 65, 78) else catColor
		rowStroke.Transparency = if isLocked then 0.5 else 0.35
		rowStroke.Thickness = 1.2
		rowStroke.Parent = rowBtn

		-- Left category color accent strip
		local accentBar = Instance.new("Frame")
		accentBar.Name = "AccentBar"
		accentBar.Size = UDim2.new(0, 5, 1, -10)
		accentBar.Position = UDim2.new(0, 6, 0, 5)
		accentBar.BackgroundColor3 = catColor
		accentBar.BorderSizePixel = 0
		accentBar.Parent = rowBtn

		local accentCorner = Instance.new("UICorner")
		accentCorner.CornerRadius = UDim.new(0, 3)
		accentCorner.Parent = accentBar

		-- Station display name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "StationName"
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 20, 0, 7)
		nameLabel.Size = UDim2.new(1, -135, 0, 22)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.TextColor3 = if isLocked then Color3.fromRGB(150, 150, 165) else Color3.fromRGB(242, 244, 250)
		nameLabel.Text = entry.displayName
		nameLabel.Parent = rowBtn

		-- Category badge pill
		local badgeFrame = Instance.new("Frame")
		badgeFrame.Name = "CategoryBadge"
		badgeFrame.Position = UDim2.new(0, 20, 0, 32)
		badgeFrame.Size = UDim2.new(0, 86, 0, 18)
		badgeFrame.BackgroundColor3 = catColor
		badgeFrame.BackgroundTransparency = 0.8
		badgeFrame.BorderSizePixel = 0
		badgeFrame.Parent = rowBtn

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = badgeFrame

		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = catColor
		badgeStroke.Transparency = 0.25
		badgeStroke.Thickness = 1
		badgeStroke.Parent = badgeFrame

		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.BackgroundTransparency = 1
		badgeLabel.Size = UDim2.fromScale(1, 1)
		badgeLabel.Font = Enum.Font.GothamBold
		badgeLabel.TextSize = 11
		badgeLabel.TextColor3 = catColor
		badgeLabel.Text = I18n.t(entry.categoryStyle.labelKey)
		badgeLabel.Parent = badgeFrame

		-- Optional MinLevel label
		if entry.minLevel > 0 then
			local levelLabel = Instance.new("TextLabel")
			levelLabel.Name = "MinLevelLabel"
			levelLabel.BackgroundTransparency = 1
			levelLabel.Position = UDim2.new(0, 114, 0, 32)
			levelLabel.Size = UDim2.new(0, 110, 0, 18)
			levelLabel.Font = Enum.Font.GothamMedium
			levelLabel.TextSize = 12
			levelLabel.TextXAlignment = Enum.TextXAlignment.Left
			levelLabel.TextColor3 = if isLocked then Color3.fromRGB(240, 95, 95) else Color3.fromRGB(185, 195, 215)
			levelLabel.Text = I18n.t("UI_UBAHN_MIN_LEVEL", { lv = entry.minLevel })
			levelLabel.Parent = rowBtn
		end

		-- Right action pill
		local actionTag = Instance.new("TextLabel")
		actionTag.Name = "ActionTag"
		actionTag.Position = UDim2.new(1, -102, 0.5, -14)
		actionTag.Size = UDim2.new(0, 90, 0, 28)
		actionTag.BackgroundColor3 = if isLocked then Color3.fromRGB(45, 42, 50) else Color3.fromRGB(36, 44, 60)
		actionTag.Font = Enum.Font.GothamBold
		actionTag.TextSize = 12
		actionTag.TextColor3 = if isLocked then Color3.fromRGB(220, 100, 100) else L2_GOLD_BORDER
		actionTag.Text = if isLocked
			then I18n.t("UI_UBAHN_MIN_LEVEL", { lv = entry.minLevel })
			else I18n.t("UI_UBAHN_TELEPORT_BTN")
		actionTag.Parent = rowBtn

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 5)
		actionCorner.Parent = actionTag

		local actionStroke = Instance.new("UIStroke")
		actionStroke.Color = if isLocked then Color3.fromRGB(140, 65, 65) else L2_SUB_BORDER
		actionStroke.Thickness = 1
		actionStroke.Parent = actionTag

		rowBtn.MouseEnter:Connect(function()
			if not isLocked then
				rowBtn.BackgroundColor3 = L2_ROW_HOVER
				rowStroke.Transparency = 0
			end
		end)

		rowBtn.MouseLeave:Connect(function()
			rowBtn.BackgroundColor3 = if isLocked then L2_ROW_LOCKED else L2_ROW_COLOR
			rowStroke.Transparency = if isLocked then 0.5 else 0.35
		end)

		rowBtn.MouseButton1Click:Connect(function()
			Remotes.RequestUBahnTeleport:FireServer(entry.stationId)
			if not isLocked then
				closeMenu()
			end
		end)
	end

	listScrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end

local function openMenu()
	isMenuOpen = true
	rebuildStationList()
	if mainFrame then
		mainFrame.Visible = true
	end
end

local function buildUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MegapolisL2_UBahnUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "UBahnWindow"
	mainFrame.Size = UDim2.new(0, 440, 0, 430)
	mainFrame.Position = UDim2.new(0.5, -220, 0.5, -215)
	mainFrame.BackgroundColor3 = L2_BG_COLOR
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 8)
	mainCorner.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = L2_GOLD_BORDER
	mainStroke.Thickness = 1.6
	mainStroke.Parent = mainFrame

	-- Header
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 62)
	headerFrame.BackgroundColor3 = L2_PANEL_COLOR
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = headerFrame

	local headerDivider = Instance.new("Frame")
	headerDivider.Size = UDim2.new(1, 0, 0, 1)
	headerDivider.Position = UDim2.new(0, 0, 1, -1)
	headerDivider.BackgroundColor3 = L2_SUB_BORDER
	headerDivider.BorderSizePixel = 0
	headerDivider.Parent = headerFrame

	-- Blue "U" Metro Badge
	local metroBadge = Instance.new("TextLabel")
	metroBadge.Name = "MetroBadge"
	metroBadge.Size = UDim2.new(0, 34, 0, 34)
	metroBadge.Position = UDim2.new(0, 14, 0, 14)
	metroBadge.BackgroundColor3 = Color3.fromRGB(28, 92, 184)
	metroBadge.Font = Enum.Font.GothamBlack
	metroBadge.TextSize = 20
	metroBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	metroBadge.Text = "U"
	metroBadge.Parent = headerFrame

	local metroCorner = Instance.new("UICorner")
	metroCorner.CornerRadius = UDim.new(0, 6)
	metroCorner.Parent = metroBadge

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 58, 0, 10)
	titleLabel.Size = UDim2.new(1, -104, 0, 22)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = L2_GOLD_BORDER
	titleLabel.Text = I18n.t("UI_UBAHN_TITLE")
	titleLabel.Parent = headerFrame

	subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 58, 0, 34)
	subtitleLabel.Size = UDim2.new(1, -104, 0, 18)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 12
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	subtitleLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
	subtitleLabel.Text = ""
	subtitleLabel.Parent = headerFrame

	closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -42, 0, 16)
	closeButton.BackgroundColor3 = Color3.fromRGB(40, 30, 36)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 14
	closeButton.TextColor3 = Color3.fromRGB(235, 190, 190)
	closeButton.Text = "X"
	closeButton.Parent = headerFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(145, 75, 75)
	closeStroke.Thickness = 1
	closeStroke.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		dismissedStationId = currentStationId
		closeMenu()
	end)

	-- Scrollable Station List
	listScrollFrame = Instance.new("ScrollingFrame")
	listScrollFrame.Name = "StationList"
	listScrollFrame.Position = UDim2.new(0, 12, 0, 72)
	listScrollFrame.Size = UDim2.new(1, -24, 1, -110)
	listScrollFrame.BackgroundTransparency = 1
	listScrollFrame.BorderSizePixel = 0
	listScrollFrame.ScrollBarThickness = 5
	listScrollFrame.ScrollBarImageColor3 = L2_GOLD_BORDER
	listScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listScrollFrame.Parent = mainFrame

	listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = listScrollFrame

	emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Position = UDim2.new(0, 16, 0, 150)
	emptyLabel.Size = UDim2.new(1, -32, 0, 40)
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.TextSize = 14
	emptyLabel.TextColor3 = Color3.fromRGB(160, 168, 185)
	emptyLabel.TextWrapped = true
	emptyLabel.Visible = false
	emptyLabel.Parent = mainFrame

	-- Footer hint
	footerHintLabel = Instance.new("TextLabel")
	footerHintLabel.Name = "FooterHint"
	footerHintLabel.BackgroundTransparency = 1
	footerHintLabel.Position = UDim2.new(0, 14, 1, -30)
	footerHintLabel.Size = UDim2.new(1, -28, 0, 22)
	footerHintLabel.Font = Enum.Font.Gotham
	footerHintLabel.TextSize = 11
	footerHintLabel.TextColor3 = Color3.fromRGB(145, 152, 170)
	footerHintLabel.TextTruncate = Enum.TextTruncate.AtEnd
	footerHintLabel.Text = I18n.t("UI_UBAHN_HINT")
	footerHintLabel.Parent = mainFrame
end

local function updateTriggerState()
	local detectedStationId = detectCurrentStation()

	if detectedStationId ~= currentStationId then
		currentStationId = detectedStationId

		if currentStationId == nil then
			dismissedStationId = nil
			closeMenu()
		elseif currentStationId ~= dismissedStationId then
			openMenu()
		end
	elseif currentStationId ~= nil and not isMenuOpen and currentStationId ~= dismissedStationId then
		openMenu()
	end
end

function UBahnController.Init()
	if initialized then
		return
	end
	initialized = true

	watchWorkspaceMap()
	buildUI()

	RunService.Heartbeat:Connect(function(dt: number)
		checkAccumulator += dt
		if checkAccumulator < TRIGGER_CHECK_INTERVAL then
			return
		end
		checkAccumulator = 0
		updateTriggerState()
	end)

	I18n.OnLanguageChanged.Event:Connect(function()
		if isMenuOpen then
			rebuildStationList()
		end
	end)

	localPlayer:GetAttributeChangedSignal("Level"):Connect(function()
		if isMenuOpen then
			rebuildStationList()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and isMenuOpen then
			dismissedStationId = currentStationId
			closeMenu()
		end
	end)
end

return UBahnController
