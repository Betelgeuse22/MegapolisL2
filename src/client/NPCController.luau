--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18nFolder = Shared:WaitForChild("i18n")
local I18n = require(I18nFolder:WaitForChild("I18n"))

local UIController = require(script.Parent:WaitForChild("UIController"))

local localPlayer = Players.LocalPlayer

local NPCController = {}

local PROMPT_NAME = "NPCInteractionPrompt"
local PROMPT_DISTANCE = 10
local AUTO_CLOSE_DISTANCE = 14
local DISTANCE_CHECK_INTERVAL = 0.1

type TrackedNpc = {
	model: Model,
	prompt: ProximityPrompt?,
	connections: { RBXScriptConnection },
}

local initialized = false
local watchedNpcsFolder: Instance? = nil
local trackedNpcs: { [Model]: TrackedNpc } = {}

local activeNpcModel: Model? = nil
local activeNpcRole: string? = nil
local distanceCheckAccumulator = 0

local function getNpcRole(npcModel: Model): string?
	local rawRole = npcModel:GetAttribute("NPCRole")
	if type(rawRole) == "string" and #rawRole > 0 then
		return rawRole
	end
	return nil
end

local function getLocalizedNpcName(npcModel: Model): string
	local lang = I18n.GetLanguage()
	local ruName = npcModel:GetAttribute("DisplayName_RU")
	local enName = npcModel:GetAttribute("DisplayName_EN")

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

	return npcModel.Name
end

local function getLocalizedActionText(role: string): string
	if role == "Merchant" then
		return I18n.t("UI_NPC_ACTION_MERCHANT")
	elseif role == "Blacksmith" then
		return I18n.t("UI_NPC_ACTION_BLACKSMITH")
	end
	return I18n.t("UI_NPC_ACTION_DEFAULT")
end

local function getPromptAnchorPart(npcModel: Model): BasePart?
	local hrp = npcModel:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	if npcModel.PrimaryPart then
		return npcModel.PrimaryPart
	end
	return nil
end

local function getNpcWorldPosition(npcModel: Model): Vector3
	local anchor = getPromptAnchorPart(npcModel)
	if anchor then
		return anchor.Position
	end
	return npcModel:GetPivot().Position
end

local function updatePromptTexts(entry: TrackedNpc)
	local prompt = entry.prompt
	if not prompt or not prompt.Parent then
		return
	end

	local role = getNpcRole(entry.model)
	if not role then
		prompt.Enabled = false
		return
	end

	prompt.Enabled = true
	prompt.ObjectText = getLocalizedNpcName(entry.model)
	prompt.ActionText = getLocalizedActionText(role)
end

local function onNpcTriggered(npcModel: Model)
	local role = getNpcRole(npcModel)
	if not role then
		return
	end

	if role == "Merchant" then
		if UIController.OpenNpcWindow("Merchant") then
			activeNpcModel = npcModel
			activeNpcRole = "Merchant"
		end
	elseif role == "Blacksmith" then
		if UIController.OpenNpcWindow("Blacksmith") then
			activeNpcModel = npcModel
			activeNpcRole = "Blacksmith"
		end
	end
end

local function ensureNpcPrompt(entry: TrackedNpc)
	local npcModel = entry.model
	local role = getNpcRole(npcModel)
	if not role then
		if entry.prompt then
			entry.prompt:Destroy()
			entry.prompt = nil
		end
		return
	end

	local anchorPart = getPromptAnchorPart(npcModel)
	if not anchorPart then
		return
	end

	if entry.prompt and entry.prompt.Parent == anchorPart then
		updatePromptTexts(entry)
		return
	end

	if entry.prompt then
		entry.prompt:Destroy()
		entry.prompt = nil
	end

	local existing = anchorPart:FindFirstChild(PROMPT_NAME)
	local prompt: ProximityPrompt
	if existing and existing:IsA("ProximityPrompt") then
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.Parent = anchorPart
	end

	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.ClickablePrompt = true
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton

	entry.prompt = prompt
	updatePromptTexts(entry)

	local triggeredConn = prompt.Triggered:Connect(function(triggeringPlayer: Player)
		if triggeringPlayer ~= localPlayer then
			return
		end
		onNpcTriggered(npcModel)
	end)
	table.insert(entry.connections, triggeredConn)
end

local function cleanupTrackedNpc(npcModel: Model)
	local entry = trackedNpcs[npcModel]
	if not entry then
		return
	end
	trackedNpcs[npcModel] = nil

	for _, conn in ipairs(entry.connections) do
		conn:Disconnect()
	end
	table.clear(entry.connections)

	if entry.prompt and entry.prompt.Parent then
		entry.prompt:Destroy()
	end
	entry.prompt = nil

	if activeNpcModel == npcModel then
		UIController.CloseNpcWindow(activeNpcRole)
		activeNpcModel = nil
		activeNpcRole = nil
	end
end

local function registerNpcInstance(instance: Instance)
	if not instance:IsA("Model") or trackedNpcs[instance] then
		return
	end

	local npcModel = instance
	local entry: TrackedNpc = {
		model = npcModel,
		prompt = nil,
		connections = {},
	}
	trackedNpcs[npcModel] = entry

	ensureNpcPrompt(entry)

	table.insert(
		entry.connections,
		npcModel:GetAttributeChangedSignal("NPCRole"):Connect(function()
			ensureNpcPrompt(entry)
		end)
	)
	table.insert(
		entry.connections,
		npcModel:GetAttributeChangedSignal("DisplayName_RU"):Connect(function()
			updatePromptTexts(entry)
		end)
	)
	table.insert(
		entry.connections,
		npcModel:GetAttributeChangedSignal("DisplayName_EN"):Connect(function()
			updatePromptTexts(entry)
		end)
	)
	table.insert(
		entry.connections,
		npcModel.ChildAdded:Connect(function(child: Instance)
			if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
				ensureNpcPrompt(entry)
			end
		end)
	)
	table.insert(
		entry.connections,
		npcModel:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
			ensureNpcPrompt(entry)
		end)
	)
	table.insert(
		entry.connections,
		npcModel.Destroying:Connect(function()
			cleanupTrackedNpc(npcModel)
		end)
	)
end

local function bindNpcsFolder(npcsFolder: Instance)
	if watchedNpcsFolder == npcsFolder then
		return
	end
	watchedNpcsFolder = npcsFolder

	for _, child in ipairs(npcsFolder:GetChildren()) do
		registerNpcInstance(child)
	end

	npcsFolder.ChildAdded:Connect(registerNpcInstance)
	npcsFolder.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Model") then
			cleanupTrackedNpc(child)
		end
	end)
end

local function watchWorkspaceMapNpcs()
	local function attachToMap(mapFolder: Instance)
		local existingNpcs = mapFolder:FindFirstChild("NPCs")
		if existingNpcs then
			bindNpcsFolder(existingNpcs)
		end

		mapFolder.ChildAdded:Connect(function(child: Instance)
			if child.Name == "NPCs" then
				bindNpcsFolder(child)
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

local function refreshAllPromptsLanguage()
	for _, entry in pairs(trackedNpcs) do
		updatePromptTexts(entry)
	end
end

local function checkActiveNpcDistance()
	local npcModel = activeNpcModel
	if not npcModel then
		return
	end

	if not UIController.IsNpcWindowOpen(activeNpcRole) then
		activeNpcModel = nil
		activeNpcRole = nil
		return
	end

	if not npcModel.Parent then
		UIController.CloseNpcWindow(activeNpcRole)
		activeNpcModel = nil
		activeNpcRole = nil
		return
	end

	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local playerRoot = if character then (character:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
	if not humanoid or humanoid.Health <= 0 or not playerRoot then
		UIController.CloseNpcWindow(activeNpcRole)
		activeNpcModel = nil
		activeNpcRole = nil
		return
	end

	local npcPos = getNpcWorldPosition(npcModel)
	local distance = (playerRoot.Position - npcPos).Magnitude
	if distance > AUTO_CLOSE_DISTANCE then
		UIController.CloseNpcWindow(activeNpcRole)
		activeNpcModel = nil
		activeNpcRole = nil
	end
end

function NPCController.Init()
	if initialized then
		return
	end
	initialized = true

	watchWorkspaceMapNpcs()

	I18n.OnLanguageChanged.Event:Connect(refreshAllPromptsLanguage)

	RunService.Heartbeat:Connect(function(dt: number)
		if not activeNpcModel then
			return
		end
		distanceCheckAccumulator += dt
		if distanceCheckAccumulator < DISTANCE_CHECK_INTERVAL then
			return
		end
		distanceCheckAccumulator = 0
		checkActiveNpcDistance()
	end)
end

return NPCController
