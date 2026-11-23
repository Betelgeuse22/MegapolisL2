--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local WorldBuilderService = {}

local initialized = false
local SPAWN_Y_OFFSET = 3

local function getWorkspaceSpawnLocation(): BasePart?
	local spawnObj = Workspace:FindFirstChild("SpawnLocation") or Workspace:WaitForChild("SpawnLocation", 5)
	if spawnObj and spawnObj:IsA("BasePart") then
		return spawnObj
	end
	return nil
end

local function teleportCharacterToSpawnLocation(character: Model)
	local spawnLoc = getWorkspaceSpawnLocation()
	if not spawnLoc then
		return
	end

	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not rootPart or not character.Parent then
		return
	end

	local targetPos = spawnLoc.Position + Vector3.new(0, SPAWN_Y_OFFSET, 0)
	character:PivotTo(CFrame.new(targetPos))
end

local function setupPlayerSpawn()
	-- Remove any legacy procedural WorldMap folder if present
	local legacyWorldMap = Workspace:FindFirstChild("WorldMap")
	if legacyWorldMap then
		legacyWorldMap:Destroy()
	end

	local spawnLoc = getWorkspaceSpawnLocation()
	if not spawnLoc then
		warn("[WorldBuilderService] workspace.SpawnLocation not found; skipping custom spawn teleport.")
	end

	local function bindPlayerSpawn(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			task.defer(function()
				teleportCharacterToSpawnLocation(character)
			end)
		end)

		if player.Character then
			task.defer(function()
				local char = player.Character
				if char then
					teleportCharacterToSpawnLocation(char)
				end
			end)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayerSpawn(player)
	end
	Players.PlayerAdded:Connect(bindPlayerSpawn)
end

function WorldBuilderService.GetSafeSpawnPosition(): Vector3?
	local spawnLoc = getWorkspaceSpawnLocation()
	if not spawnLoc then
		return nil
	end
	return spawnLoc.Position + Vector3.new(0, SPAWN_Y_OFFSET, 0)
end

function WorldBuilderService.Init()
	if initialized then
		return
	end
	initialized = true

	-- Procedural map generation is disabled: use Studio map geometry in workspace.Map
	setupPlayerSpawn()

	-- Preserve NPC click-to-interact handler for Studio-placed NPCs in Workspace.NPCs
	Remotes.RequestNpcInteract.OnServerEvent:Connect(function(player: Player, npcModelArg: any)
		local npcsFolder = Workspace:FindFirstChild("NPCs")
		if not npcsFolder then
			return
		end
		if typeof(npcModelArg) ~= "Instance" or not npcModelArg:IsA("Model") then
			return
		end
		if npcModelArg.Parent ~= npcsFolder or npcModelArg:GetAttribute("IsNPC") ~= true then
			return
		end
		local windowType = npcModelArg:GetAttribute("NpcWindowType")
		if type(windowType) ~= "string" then
			return
		end
		local character = player.Character
		local playerRoot = if character then (character:FindFirstChild("HumanoidRootPart") :: BasePart?) else nil
		local npcRoot = npcModelArg.PrimaryPart or (npcModelArg:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if playerRoot and npcRoot then
			local dist = ((playerRoot.Position - npcRoot.Position) * Vector3.new(1, 0, 1)).Magnitude
			if dist <= 22 then
				Remotes.OpenNpcWindow:FireClient(player, windowType)
			end
		end
	end)
end

return WorldBuilderService
