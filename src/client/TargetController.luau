--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local TAB_TARGET_RANGE = 60
local RAYCAST_DISTANCE = 380
local RECENT_ATTACKER_MEMORY_SEC = 15.0
local RECENT_ATTACKER_MAX_RANGE = 45.0

local localPlayer = Players.LocalPlayer

local TargetController = {}

local onTargetChangedEvent = Instance.new("BindableEvent")
onTargetChangedEvent.Name = "OnTargetChanged"
TargetController.OnTargetChanged = onTargetChangedEvent

local onMobClickedEvent = Instance.new("BindableEvent")
onMobClickedEvent.Name = "OnMobClicked"
TargetController.OnMobClicked = onMobClickedEvent

local onGroundClickedEvent = Instance.new("BindableEvent")
onGroundClickedEvent.Name = "OnGroundClicked"
TargetController.OnGroundClicked = onGroundClickedEvent

local onNpcClickedEvent = Instance.new("BindableEvent")
onNpcClickedEvent.Name = "OnNpcClicked"
TargetController.OnNpcClicked = onNpcClickedEvent

local currentTarget: Model? = nil
local targetRingPart: Part? = nil
local targetHpConn: RBXScriptConnection? = nil
local targetSweepConn: RBXScriptConnection? = nil
local targetAncestryConn: RBXScriptConnection? = nil
local recentAttackers: { [Model]: number } = {}
local lastCycleIndex = 0
local initialized = false

local function getMobRootPart(mobModel: Model): BasePart?
	if mobModel.PrimaryPart then
		return mobModel.PrimaryPart
	end
	local hrp = mobModel:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	local torso = mobModel:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return mobModel:FindFirstChildWhichIsA("BasePart")
end

local function ensureSelectionRing(): Part
	if targetRingPart and targetRingPart.Parent then
		return targetRingPart
	end

	local ring = Instance.new("Part")
	ring.Name = "L2TargetSelectionRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(0, 235, 255)
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.14, 4.6, 4.6)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = Workspace

	local adornment = Instance.new("CylinderHandleAdornment")
	adornment.Name = "CyanRingGlow"
	adornment.Adornee = ring
	adornment.CFrame = CFrame.Angles(0, math.rad(90), 0)
	adornment.InnerRadius = 1.95
	adornment.Radius = 2.35
	adornment.Height = 0.16
	adornment.Color3 = Color3.fromRGB(0, 245, 255)
	adornment.Transparency = 0.1
	adornment.AlwaysOnTop = false
	adornment.Parent = ring

	targetRingPart = ring
	return ring
end

local function hideSelectionRing()
	if targetRingPart then
		targetRingPart.Parent = nil
	end
end

local function isMobSelectable(mobModel: Model?): boolean
	if not mobModel or not mobModel.Parent then
		return false
	end

	local targetPlayer = Players:GetPlayerFromCharacter(mobModel)
	if targetPlayer then
		local hum = mobModel:FindFirstChildOfClass("Humanoid")
		return hum ~= nil and hum.Health > 0
	end

	local isMob = mobModel:GetAttribute("IsMob") == true
	local isPvpTarget = mobModel:GetAttribute("IsPvpTarget") == true
	local isPartyBot = mobModel:GetAttribute("IsPartyBot") == true
	if not isMob and not isPvpTarget and not isPartyBot then
		return false
	end

	local hp = (mobModel:GetAttribute("CurrentHP") :: number?) or 0
	if hp > 0 then
		return true
	end
	if mobModel:GetAttribute("CanSweep") == true or mobModel:GetAttribute("IsSpoiled") == true then
		return true
	end
	return false
end

local function disconnectTargetConnections()
	if targetHpConn then
		targetHpConn:Disconnect()
		targetHpConn = nil
	end
	if targetSweepConn then
		targetSweepConn:Disconnect()
		targetSweepConn = nil
	end
	if targetAncestryConn then
		targetAncestryConn:Disconnect()
		targetAncestryConn = nil
	end
end

local function findNextValidAttacker(excludeMob: Model?): Model?
	local character = localPlayer.Character
	local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not playerRoot then
		return nil
	end

	local now = os.clock()
	local bestAttacker: Model? = nil
	local bestDist = RECENT_ATTACKER_MAX_RANGE

	for mobModel, lastHitTime in pairs(recentAttackers) do
		if
			mobModel == excludeMob
			or not mobModel.Parent
			or mobModel:GetAttribute("IsMob") ~= true
			or (now - lastHitTime) > RECENT_ATTACKER_MEMORY_SEC
		then
			if not mobModel.Parent or (now - lastHitTime) > RECENT_ATTACKER_MEMORY_SEC then
				recentAttackers[mobModel] = nil
			end
		else
			local hp = (mobModel:GetAttribute("CurrentHP") :: number?) or 0
			if hp <= 0 then
				recentAttackers[mobModel] = nil
			else
				local mobRoot = getMobRootPart(mobModel)
				if mobRoot then
					local dist = (mobRoot.Position - playerRoot.Position).Magnitude
					if dist <= bestDist then
						bestDist = dist
						bestAttacker = mobModel
					end
				end
			end
		end
	end

	return bestAttacker
end

function TargetController.SetTarget(newTarget: Model?)
	if newTarget and not isMobSelectable(newTarget) then
		newTarget = nil
	end

	if currentTarget == newTarget then
		return
	end

	disconnectTargetConnections()
	currentTarget = newTarget

	if currentTarget then
		local activeTarget = currentTarget
		targetHpConn = activeTarget:GetAttributeChangedSignal("CurrentHP"):Connect(function()
			local hp = (activeTarget:GetAttribute("CurrentHP") :: number?) or 0
			if hp <= 0 and currentTarget == activeTarget then
				recentAttackers[activeTarget] = nil
				local isSpoiled = activeTarget:GetAttribute("IsSpoiled") == true
				local canSweep = activeTarget:GetAttribute("CanSweep") == true
				if not isSpoiled and not canSweep then
					-- Rule C: Immediately switch to next valid attacker (or nil if none)
					local nextAttacker = findNextValidAttacker(activeTarget)
					TargetController.SetTarget(nextAttacker)
				else
					-- Spoiled corpse: wait up to 1.5s or until CanSweep becomes false before switching to next attacker
					task.delay(1.5, function()
						if currentTarget == activeTarget then
							local nextAttacker = findNextValidAttacker(activeTarget)
							if nextAttacker then
								TargetController.SetTarget(nextAttacker)
							end
						end
					end)
				end
			end
		end)
		targetSweepConn = activeTarget:GetAttributeChangedSignal("CanSweep"):Connect(function()
			local hp = (activeTarget:GetAttribute("CurrentHP") :: number?) or 0
			local canSweep = activeTarget:GetAttribute("CanSweep") == true
			local isSpoiled = activeTarget:GetAttribute("IsSpoiled") == true
			if hp <= 0 and not canSweep and not isSpoiled and currentTarget == activeTarget then
				local nextAttacker = findNextValidAttacker(activeTarget)
				TargetController.SetTarget(nextAttacker)
			end
		end)
		targetAncestryConn = activeTarget.AncestryChanged:Connect(function(_, parent: Instance?)
			if not parent and currentTarget == activeTarget then
				recentAttackers[activeTarget] = nil
				local nextAttacker = findNextValidAttacker(activeTarget)
				TargetController.SetTarget(nextAttacker)
			end
		end)
	else
		hideSelectionRing()
	end

	Remotes.SelectTarget:FireServer(currentTarget)
	onTargetChangedEvent:Fire(currentTarget)
end

function TargetController.GetTarget(): Model?
	if currentTarget and not isMobSelectable(currentTarget) then
		TargetController.SetTarget(nil)
	end
	return currentTarget
end

function TargetController.IsInFrontCone(playerRoot: BasePart, mobRoot: BasePart): boolean
	local playerPos = playerRoot.Position
	local mobPos = mobRoot.Position
	local flatDiff = (mobPos - playerPos) * Vector3.new(1, 0, 1)
	if flatDiff.Magnitude <= 0.05 then
		return true
	end
	local toMob = flatDiff.Unit
	local flatLook = playerRoot.CFrame.LookVector * Vector3.new(1, 0, 1)
	local lookVec = if flatLook.Magnitude > 0.05 then flatLook.Unit else Vector3.new(0, 0, -1)
	local isInFrontCone = lookVec:Dot(toMob) >= 0.5
	return isInFrontCone
end

function TargetController.AcquireNearestTarget(maxRange: number?): Model?
	local searchRange = maxRange or 60
	local existing = TargetController.GetTarget()
	if existing then
		local existingHp = (existing:GetAttribute("CurrentHP") :: number?) or 0
		if existingHp > 0 then
			-- Target Lock Rule: If CurrentTarget is already valid and alive (CurrentHP > 0), return immediately
			return existing
		end
	end

	local character = localPlayer.Character
	local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not playerRoot then
		return nil
	end

	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return nil
	end

	local camera = Workspace.CurrentCamera
	local camLookFlat = if camera
		then (camera.CFrame.LookVector * Vector3.new(1, 0, 1))
		else Vector3.zero
	local camDir = if camLookFlat.Magnitude > 0.05 then camLookFlat.Unit else nil

	local bestConeMob: Model? = nil
	local bestConeDist = searchRange
	local bestFallbackMob: Model? = nil
	local bestFallbackDist = searchRange

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsMob") == true then
			local hp = (child:GetAttribute("CurrentHP") :: number?) or 0
			if hp > 0 then
				local mobRoot = getMobRootPart(child)
				if mobRoot then
					local flatDiff = (mobRoot.Position - playerRoot.Position) * Vector3.new(1, 0, 1)
					local dist = flatDiff.Magnitude
					local inCharCone = TargetController.IsInFrontCone(playerRoot, mobRoot)
					local inCamCone = false
					if camDir and flatDiff.Magnitude > 0.05 then
						inCamCone = camDir:Dot(flatDiff.Unit) >= 0.35
					end

					if (inCharCone or inCamCone) and dist <= bestConeDist then
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

	local bestMob = bestConeMob or bestFallbackMob
	if bestMob then
		TargetController.SetTarget(bestMob)
	end
	return bestMob
end

function TargetController.AcquireNearestFrontalTarget(maxRange: number, deadSpoiledOnly: boolean?): Model?
	if not deadSpoiledOnly then
		return TargetController.AcquireNearestTarget(maxRange)
	end

	local existing = TargetController.GetTarget()
	if existing then
		local existingHp = (existing:GetAttribute("CurrentHP") :: number?) or 0
		local isSpoiled = existing:GetAttribute("IsSpoiled") == true or existing:GetAttribute("CanSweep") == true
		if existingHp <= 0 and isSpoiled then
			return existing
		end
	end

	local character = localPlayer.Character
	local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not playerRoot then
		return nil
	end

	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return nil
	end

	local bestMob: Model? = nil
	local bestDist = maxRange

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsMob") == true then
			local hp = (child:GetAttribute("CurrentHP") :: number?) or 0
			local isSpoiled = child:GetAttribute("IsSpoiled") == true or child:GetAttribute("CanSweep") == true
			if hp <= 0 and isSpoiled then
				local mobRoot = getMobRootPart(child)
				if mobRoot then
					local dist = (mobRoot.Position - playerRoot.Position).Magnitude
					if dist <= bestDist then
						bestDist = dist
						bestMob = child
					end
				end
			end
		end
	end

	if bestMob then
		TargetController.SetTarget(bestMob)
	end
	return bestMob
end

local function findMobModelFromInstance(hitInstance: Instance?): Model?
	if not hitInstance then
		return nil
	end
	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")

	local current: Instance? = hitInstance
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local targetPlayer = Players:GetPlayerFromCharacter(current)
			if targetPlayer and targetPlayer ~= localPlayer then
				return current
			end
			if
				activeMobsFolder
				and current.Parent == activeMobsFolder
				and (
					current:GetAttribute("IsMob") == true
					or current:GetAttribute("IsPvpTarget") == true
					or current:GetAttribute("IsPartyBot") == true
				)
			then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

local function findNpcModelFromInstance(hitInstance: Instance?): Model?
	local npcsFolder = Workspace:FindFirstChild("NPCs")
	if not npcsFolder or not hitInstance then
		return nil
	end

	local current: Instance? = hitInstance
	while current and current ~= Workspace do
		if current:IsA("Model") and current.Parent == npcsFolder and current:GetAttribute("IsNPC") == true then
			return current
		end
		current = current.Parent
	end
	return nil
end

function TargetController.RaycastMouseWorld(): ("Mob" | "NPC" | "Ground" | "None", Model?, Vector3?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return "None", nil, nil
	end

	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignoreList: { Instance } = {}
	if localPlayer.Character then
		table.insert(ignoreList, localPlayer.Character)
	end
	if targetRingPart then
		table.insert(ignoreList, targetRingPart)
	end
	rayParams.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * RAYCAST_DISTANCE, rayParams)
	if not result or not result.Instance then
		return "None", nil, nil
	end

	local mobModel = findMobModelFromInstance(result.Instance)
	if mobModel and isMobSelectable(mobModel) then
		return "Mob", mobModel, result.Position
	end

	local npcModel = findNpcModelFromInstance(result.Instance)
	if npcModel then
		return "NPC", npcModel, result.Position
	end

	-- Walkable ground / floor / platform / road check (surface facing mostly upward)
	if result.Normal.Y >= 0.45 then
		return "Ground", nil, result.Position
	end

	return "Ground", nil, Vector3.new(result.Position.X, 0.5, result.Position.Z)
end

local function tryMouseTargetSelect()
	local hitKind, hitModel, hitPos = TargetController.RaycastMouseWorld()

	if hitKind == "Mob" and hitModel then
		local previousTarget = TargetController.GetTarget()
		local wasAlreadySelected = (previousTarget == hitModel)
		if not wasAlreadySelected then
			TargetController.SetTarget(hitModel)
		end
		onMobClickedEvent:Fire(hitModel, wasAlreadySelected)
		return
	end

	if hitKind == "NPC" and hitModel then
		onNpcClickedEvent:Fire(hitModel)
		return
	end

	if hitKind == "Ground" and hitPos then
		onMobClickedEvent:Fire(nil, false)
		onGroundClickedEvent:Fire(hitPos)
		return
	end

	onMobClickedEvent:Fire(nil, false)
end

local function cycleTabTarget()
	local character = localPlayer.Character
	local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not playerRoot then
		return
	end

	local activeMobsFolder = Workspace:FindFirstChild("ActiveMobs")
	if not activeMobsFolder then
		return
	end

	type Candidate = {
		model: Model,
		distance: number,
	}

	local candidates: { Candidate } = {}
	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") and isMobSelectable(child) then
			local mobRoot = getMobRootPart(child)
			if mobRoot then
				local dist = (mobRoot.Position - playerRoot.Position).Magnitude
				if dist <= TAB_TARGET_RANGE then
					table.insert(candidates, { model = child, distance = dist })
				end
			end
		end
	end

	if #candidates == 0 then
		return
	end

	table.sort(candidates, function(a: Candidate, b: Candidate): boolean
		return a.distance < b.distance
	end)

	lastCycleIndex = (lastCycleIndex % #candidates) + 1
	local chosen = candidates[lastCycleIndex].model
	if chosen == currentTarget and #candidates > 1 then
		lastCycleIndex = (lastCycleIndex % #candidates) + 1
		chosen = candidates[lastCycleIndex].model
	end

	TargetController.SetTarget(chosen)
	onMobClickedEvent:Fire(chosen, false)
end

function TargetController.Init()
	if initialized then
		return
	end
	initialized = true

	-- Defensive Auto-Target & Attacker Queue Listener
	Remotes.MobAttackedPlayer.OnClientEvent:Connect(function(mobModel: Model, _damage: number)
		if typeof(mobModel) ~= "Instance" or not mobModel:IsA("Model") then
			return
		end
		if mobModel:GetAttribute("IsMob") ~= true then
			return
		end
		local mobHp = (mobModel:GetAttribute("CurrentHP") :: number?) or 0
		if mobHp <= 0 then
			return
		end

		recentAttackers[mobModel] = os.clock()

		local cur = TargetController.GetTarget()
		local curHp = if cur then ((cur:GetAttribute("CurrentHP") :: number?) or 0) else 0
		-- Rule A (Empty Target): If CurrentTarget is nil or dead (curHp <= 0), immediately target the attacking mob!
		-- Rule B (Already Fighting Another Mob): If curHp > 0, do NOT switch yet; keep it in recentAttackers for Rule C.
		if not cur or curHp <= 0 then
			TargetController.SetTarget(mobModel)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tryMouseTargetSelect()
		elseif input.KeyCode == Enum.KeyCode.Tab then
			cycleTabTarget()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			TargetController.SetTarget(nil)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local target = currentTarget
		if not target or not isMobSelectable(target) then
			hideSelectionRing()
			return
		end

		local root = getMobRootPart(target)
		if not root then
			hideSelectionRing()
			return
		end

		local ring = ensureSelectionRing()
		if ring.Parent ~= Workspace then
			ring.Parent = Workspace
		end

		local footOffset = root.Size.Y * 1.5 - 0.08
		local ringPos = root.Position - Vector3.new(0, footOffset, 0)
		ring.CFrame = CFrame.new(ringPos) * CFrame.Angles(0, 0, math.rad(90))
	end)
end

return TargetController
