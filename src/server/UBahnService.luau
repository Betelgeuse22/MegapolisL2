--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataManager = require(script.Parent:WaitForChild("DataManager"))

local UBahnService = {}

local initialized = false
local TELEPORT_COOLDOWN = 0.75
local ARRIVAL_OFFSET = Vector3.new(0, 3, 0)

local lastTeleportTimeByPlayer: { [Player]: number } = {}
local watchedStations: { [Instance]: boolean } = {}
local watchedStationsFolder: Instance? = nil

local function sendSystemMessage(player: Player, i18nKey: string, params: { [string]: string | number }?, color: { number })
	Remotes.SendChatMessage:FireClient(player, i18nKey, params or {}, color)
end

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

local function getPlayerLevel(player: Player): number
	local attrLevel = player:GetAttribute("Level")
	if type(attrLevel) == "number" then
		return math.max(1, math.floor(attrLevel))
	end

	local profile = DataManager.GetProfile(player)
	local classProgress = profile.ClassProgress[profile.CurrentClassId]
	if classProgress and type(classProgress.Level) == "number" then
		return math.max(1, math.floor(classProgress.Level))
	end

	return 1
end

local function getLocalizedStationNameForPlayer(player: Player, station: Instance): string
	local isRussian = string.sub(string.lower(player.LocaleId), 1, 2) == "ru"
	local ruName = station:GetAttribute("DisplayName_RU")
	local enName = station:GetAttribute("DisplayName_EN")

	if isRussian then
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

local function handleTeleportRequest(player: Player, stationIdArg: any)
	if type(stationIdArg) ~= "string" or #stationIdArg == 0 or #stationIdArg > 100 then
		return
	end

	local now = os.clock()
	local lastTime = lastTeleportTimeByPlayer[player]
	if lastTime and (now - lastTime) < TELEPORT_COOLDOWN then
		return
	end

	local stationsFolder = getStationsFolder()
	if not stationsFolder then
		sendSystemMessage(player, "LOG_UBAHN_NOT_FOUND", nil, { 255, 110, 110 })
		return
	end

	local targetStation = stationsFolder:FindFirstChild(stationIdArg)
	if not targetStation or not targetStation:IsA("Folder") then
		sendSystemMessage(player, "LOG_UBAHN_NOT_FOUND", nil, { 255, 110, 110 })
		return
	end

	local arrival = targetStation:FindFirstChild("Arrival")
	if not arrival or not arrival:IsA("BasePart") then
		sendSystemMessage(player, "LOG_UBAHN_NOT_FOUND", nil, { 255, 110, 110 })
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return
	end

	local minLevelAttr = targetStation:GetAttribute("MinLevel")
	local stationRuAttr = targetStation:GetAttribute("DisplayName_RU")
	local stationEnAttr = targetStation:GetAttribute("DisplayName_EN")
	local stationRu = if type(stationRuAttr) == "string" then stationRuAttr else ""
	local stationEn = if type(stationEnAttr) == "string" then stationEnAttr else ""

	if type(minLevelAttr) == "number" and minLevelAttr > 1 then
		local requiredLevel = math.floor(minLevelAttr)
		local currentLevel = getPlayerLevel(player)
		if currentLevel < requiredLevel then
			sendSystemMessage(player, "LOG_UBAHN_MIN_LEVEL", {
				station = getLocalizedStationNameForPlayer(player, targetStation),
				stationRu = stationRu,
				stationEn = stationEn,
				stationId = targetStation.Name,
				minLv = requiredLevel,
				curLv = currentLevel,
			}, { 255, 120, 100 })
			return
		end
	end

	lastTeleportTimeByPlayer[player] = now

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(arrival.CFrame + ARRIVAL_OFFSET)

	sendSystemMessage(player, "LOG_UBAHN_TELEPORTED", {
		station = getLocalizedStationNameForPlayer(player, targetStation),
		stationRu = stationRu,
		stationEn = stationEn,
		stationId = targetStation.Name,
	}, { 110, 225, 165 })
end

function UBahnService.Init()
	if initialized then
		return
	end
	initialized = true

	watchWorkspaceMap()

	Remotes.RequestUBahnTeleport.OnServerEvent:Connect(handleTeleportRequest)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastTeleportTimeByPlayer[player] = nil
	end)
end

return UBahnService
