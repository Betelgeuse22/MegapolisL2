--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")

local ClassesConfig = require(Configs:WaitForChild("ClassesConfig"))
local SkillsConfig = require(Configs:WaitForChild("SkillsConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TargetController = require(script.Parent:WaitForChild("TargetController"))
local VFXController = require(script.Parent:WaitForChild("VFXController"))

local ATTACK_INTERVAL = 0.50
local TARGET_ACQUIRE_RANGE = 60
local CORPSE_ACQUIRE_RANGE = 40
local BASIC_ATTACK_STOP_RANGE = 7.5
local MELEE_SKILL_STOP_RANGE = 8.0
local RANGED_SKILL_STOP_RANGE = 18.0
local CHASE_PATH_UPDATE_INTERVAL = 0.15

local localPlayer = Players.LocalPlayer

local CombatController = {}

export type PendingAction = {
	type: "Attack" | "Skill",
	slotKey: string?,
	target: Model,
}

local comboIndex = 1
local lastAttackSent = 0
local isHoldingLMB = false
local isHoldingAttackKey = false
local isAutoAttackingTarget = false
local initialized = false
local swingSequenceToken = 0

local pendingAction: PendingAction? = nil
local isAutoApproaching = false
local lastMoveToUpdate = 0

local isClickToMoving = false
local isDraggingGroundMove = false
local clickMoveDestination: Vector3? = nil
local pendingNpcTarget: Model? = nil
local lastDragMoveUpdate = 0
local lastDragRingVFXTime = 0
local NPC_INTERACT_RANGE = 12.0
local pvpToggleEnabled = false

function CombatController.GetPvpToggleEnabled(): boolean
	return pvpToggleEnabled
end

function CombatController.TogglePvpForceMode(): boolean
	pvpToggleEnabled = not pvpToggleEnabled
	return pvpToggleEnabled
end

function CombatController.IsForcePvpActive(): boolean
	if pvpToggleEnabled then
		return true
	end
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

local function getTargetCurrentHp(target: Model?): number
	if not target or not target.Parent then
		return 0
	end
	local attrHp = target:GetAttribute("CurrentHP") :: number?
	if attrHp ~= nil then
		return attrHp
	end
	local hum = target:FindFirstChildOfClass("Humanoid")
	return if hum then math.max(0, math.floor(hum.Health + 0.5)) else 0
end

local skillReadyTimestamps: { [string]: number } = {}
local slashAnimTrack: AnimationTrack? = nil
local cachedHumanoid: Humanoid? = nil
local cachedRightShoulderC0: { [Motor6D]: CFrame } = {}
local cachedTorsoJointC0: { [Motor6D]: CFrame } = {}

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

local function isInFrontCone(playerRoot: BasePart, mobRoot: BasePart): boolean
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

local function activateWeaponTrail(character: Model)
	VFXController.ApplyWeaponEnchantVisuals(character)
	local weaponModel = character:FindFirstChild("EquippedClassWeapon")
	if not weaponModel then
		return
	end
	local trail = weaponModel:FindFirstChild("WeaponTrail") :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(0.24, function()
			if trail.Parent then
				trail.Enabled = false
			end
		end)
	end
end

local function playStandardSlashAnimation(humanoid: Humanoid)
	if cachedHumanoid ~= humanoid then
		cachedHumanoid = humanoid
		slashAnimTrack = nil
	end

	if not slashAnimTrack then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://522635514"
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			slashAnimTrack = track
		end
	end

	if slashAnimTrack then
		pcall(function()
			slashAnimTrack:Play(0.05, 1, 1.35)
		end)
	end
end

function CombatController.PlayComboSwingVisual(comboStep: number)
	task.spawn(function()
		pcall(function()
			local character = localPlayer.Character
			if not character then
				return
			end

			activateWeaponTrail(character)

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				playStandardSlashAnimation(humanoid)
			end

			local rightShoulder = character:FindFirstChild("Right Shoulder", true) :: Motor6D?
				or character:FindFirstChild("RightShoulder", true) :: Motor6D?
			local torsoJoint = character:FindFirstChild("RootJoint", true) :: Motor6D?
				or character:FindFirstChild("Waist", true) :: Motor6D?

			if not rightShoulder and not torsoJoint then
				return
			end

			local baseShoulderC0: CFrame? = nil
			if rightShoulder then
				baseShoulderC0 = cachedRightShoulderC0[rightShoulder]
				if not baseShoulderC0 then
					baseShoulderC0 = rightShoulder.C0
					cachedRightShoulderC0[rightShoulder] = baseShoulderC0
				end
			end

			local baseTorsoC0: CFrame? = nil
			if torsoJoint then
				baseTorsoC0 = cachedTorsoJointC0[torsoJoint]
				if not baseTorsoC0 then
					baseTorsoC0 = torsoJoint.C0
					cachedTorsoJointC0[torsoJoint] = baseTorsoC0
				end
			end

			local swingAngles: CFrame
			if comboStep == 1 then
				swingAngles = CFrame.Angles(math.rad(85), math.rad(-25), math.rad(25))
			elseif comboStep == 2 then
				swingAngles = CFrame.Angles(math.rad(95), math.rad(30), math.rad(-30))
			else
				swingAngles = CFrame.Angles(math.rad(125), 0, math.rad(10))
			end

			local yaw = if comboStep == 1 then math.rad(18) elseif comboStep == 2 then math.rad(-18) else math.rad(24)
			local torsoAngles = CFrame.Angles(0, yaw, 0)

			swingSequenceToken += 1
			local myToken = swingSequenceToken

			-- Phase 1: Forward strike (0.10s) using RenderStepped CFrame:Lerp
			local strikeDuration = 0.10
			local t0 = os.clock()
			while true do
				if swingSequenceToken ~= myToken then
					return
				end
				local alpha = math.clamp((os.clock() - t0) / strikeDuration, 0, 1)
				if rightShoulder and rightShoulder.Parent and baseShoulderC0 then
					rightShoulder.C0 = baseShoulderC0:Lerp(baseShoulderC0 * swingAngles, alpha)
				end
				if torsoJoint and torsoJoint.Parent and baseTorsoC0 then
					torsoJoint.C0 = baseTorsoC0:Lerp(baseTorsoC0 * torsoAngles, alpha)
				end
				if alpha >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end

			-- Phase 2: Smooth recovery back to baseC0 (0.14s)
			local recoverDuration = 0.14
			local t1 = os.clock()
			while true do
				if swingSequenceToken ~= myToken then
					return
				end
				local alpha = math.clamp((os.clock() - t1) / recoverDuration, 0, 1)
				if rightShoulder and rightShoulder.Parent and baseShoulderC0 then
					rightShoulder.C0 = (baseShoulderC0 * swingAngles):Lerp(baseShoulderC0, alpha)
				end
				if torsoJoint and torsoJoint.Parent and baseTorsoC0 then
					torsoJoint.C0 = (baseTorsoC0 * torsoAngles):Lerp(baseTorsoC0, alpha)
				end
				if alpha >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
		end)
	end)
end

function CombatController.GetSkillForSlot(slot: string): SkillsConfig.SkillData?
	local classId = (localPlayer:GetAttribute("ClassId") :: string?) or "RiotPolice"
	local classData = ClassesConfig[classId] or ClassesConfig.RiotPolice
	local skillId = classData.skillSlots[slot]
	if not skillId then
		return nil
	end
	return SkillsConfig[skillId]
end

function CombatController.GetSlotCooldownRemaining(slot: string): (number, number)
	if slot == "1" then
		local rem = math.max(0, (lastAttackSent + ATTACK_INTERVAL) - os.clock())
		return rem, ATTACK_INTERVAL
	end
	local skillData = CombatController.GetSkillForSlot(slot)
	if not skillData then
		return 0, 1
	end
	local readyAt = skillReadyTimestamps[skillData.id] or 0
	local remaining = math.max(0, readyAt - os.clock())
	return remaining, skillData.cooldown
end

function CombatController.ResetSkillCooldown(skillId: string)
	skillReadyTimestamps[skillId] = 0
end

local function faceTargetHorizontally(rootPart: BasePart, targetRoot: BasePart)
	local playerPos = rootPart.Position
	local targetPos = targetRoot.Position
	local flatTargetPos = Vector3.new(targetPos.X, playerPos.Y, targetPos.Z)
	if (flatTargetPos - playerPos).Magnitude > 0.1 then
		rootPart.CFrame = CFrame.lookAt(playerPos, flatTargetPos)
	end
end

local function getHorizontalDistance(posA: Vector3, posB: Vector3): number
	return ((posB - posA) * Vector3.new(1, 0, 1)).Magnitude
end

local function getBasicAttackStopRange(): number
	local classId = if localPlayer then localPlayer:GetAttribute("ClassId") else nil
	if typeof(classId) == "string" and ClassesConfig[classId] then
		local r = ClassesConfig[classId].attackRange
		if r and r >= 15 then
			return math.max(8, r - 3)
		end
	end
	return BASIC_ATTACK_STOP_RANGE
end

local function getRequiredSkillRange(skillData: SkillsConfig.SkillData): number
	if skillData.targetType == "SelfBuff" or skillData.targetType == "PartyBuff" or skillData.targetType == "SelfAoE" then
		return 0
	end
	if skillData.targetType == "FriendlyOrSelf" then
		return 0
	end
	if skillData.range and skillData.range > 0 then
		return math.max(4, skillData.range - 2)
	end
	return MELEE_SKILL_STOP_RANGE
end

local function stopAutoApproach(humanoid: Humanoid?, playerRoot: BasePart?)
	if (isAutoApproaching or isClickToMoving) and humanoid and playerRoot then
		humanoid:MoveTo(playerRoot.Position)
	end
	isAutoApproaching = false
	pendingAction = nil
	isClickToMoving = false
	isDraggingGroundMove = false
	clickMoveDestination = nil
	pendingNpcTarget = nil
end

local function isManualMovementKeyPressed(): boolean
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.A)
		or UserInputService:IsKeyDown(Enum.KeyCode.S)
		or UserInputService:IsKeyDown(Enum.KeyCode.D)
end

local function executeSkillNow(
	slotKey: "Q" | "E" | "R" | "F",
	skillData: SkillsConfig.SkillData,
	playerRoot: BasePart,
	targetModel: Model?
)
	if targetModel then
		local targetRoot = getMobRootPart(targetModel)
		if targetRoot then
			faceTargetHorizontally(playerRoot, targetRoot)
		end
	end

	-- Start client UI skill cooldown ONLY when the skill actually fires
	skillReadyTimestamps[skillData.id] = os.clock() + skillData.cooldown

	-- 1. ALWAYS fire the remote to the server FIRST before playing any visual animation
	Remotes.UseSkill:FireServer(slotKey, targetModel, CombatController.IsForcePvpActive())

	-- 2. Play visual swing animation safely
	CombatController.PlayComboSwingVisual(comboIndex)
	comboIndex = (comboIndex % 3) + 1
end

local function executeAttackNow(playerRoot: BasePart, target: Model, targetRoot: BasePart)
	local now = os.clock()
	if (now - lastAttackSent) < ATTACK_INTERVAL then
		return
	end

	faceTargetHorizontally(playerRoot, targetRoot)
	if not isInFrontCone(playerRoot, targetRoot) then
		return
	end

	lastAttackSent = now

	-- 1. ALWAYS fire the remote to the server FIRST
	Remotes.RequestAttack:FireServer(target, CombatController.IsForcePvpActive())

	-- 2. Play visual swing animation safely
	CombatController.PlayComboSwingVisual(comboIndex)
	comboIndex = (comboIndex % 3) + 1
end

function CombatController.UseSkillSlot(slotKey: "Q" | "E" | "R" | "F")
	local skillData = CombatController.GetSkillForSlot(slotKey)
	if not skillData then
		return
	end

	local now = os.clock()
	local readyAt = skillReadyTimestamps[skillData.id] or 0
	if now < readyAt then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local playerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not playerRoot or humanoid.Health <= 0 then
		return
	end

	-- Self-buffs (SKILL_RIOT_SHIELD, SKILL_FRIDAY_RUSH, SKILL_MONOPOLY) and untargeted AoE (SKILL_MEGAPHONE_AGGRO) execute immediately without requiring a target
	if skillData.targetType == "SelfBuff" or skillData.targetType == "SelfAoE" then
		stopAutoApproach(humanoid, playerRoot)
		executeSkillNow(slotKey, skillData, playerRoot, TargetController.GetTarget())
		return
	end

	local targetModel = TargetController.GetTarget()
	local targetHp = getTargetCurrentHp(targetModel)

	if skillData.targetType == "DeadSpoiledTarget" then
		-- Exception: Keep auto-finding the nearest dead spoiled corpse ONLY for SKILL_SWEEP
		local isSpoiled = if targetModel
			then (targetModel:GetAttribute("IsSpoiled") == true or targetModel:GetAttribute("CanSweep") == true)
			else false
		if not targetModel or targetHp > 0 or not isSpoiled then
			targetModel = TargetController.AcquireNearestFrontalTarget(CORPSE_ACQUIRE_RANGE, true)
		end
		if not targetModel then
			Remotes.UseSkill:FireServer(slotKey, nil)
			return
		end
	else
		-- Strict Manual / Defensive Target Rule: Do NOT call AcquireNearestTarget if CurrentTarget is nil or dead!
		if not targetModel or targetHp <= 0 then
			Remotes.UseSkill:FireServer(slotKey, nil)
			return
		end
	end

	local targetRoot = getMobRootPart(targetModel)
	if not targetRoot then
		return
	end

	local requiredRange = getRequiredSkillRange(skillData)
	local flatDist = getHorizontalDistance(playerRoot.Position, targetRoot.Position)

	if flatDist <= requiredRange then
		-- Already within required range: stop auto-approach, rotate to face target, and fire skill immediately!
		stopAutoApproach(humanoid, playerRoot)
		executeSkillNow(slotKey, skillData, playerRoot, targetModel)
	else
		-- Out of range: queue pending skill action and auto-approach target without starting skill cooldown yet!
		pendingAction = {
			type = "Skill",
			slotKey = slotKey,
			target = targetModel,
		}
		isAutoApproaching = true
		lastMoveToUpdate = now
		humanoid:MoveTo(targetRoot.Position)
	end
end

local function tryPerformAttack()
	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local playerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not playerRoot or humanoid.Health <= 0 then
		return
	end

	local target = TargetController.GetTarget()
	local hp = getTargetCurrentHp(target)

	-- Strict Manual / Defensive Target Rule: Do NOT auto-acquire a target on basic Attack press if CurrentTarget is nil or dead!
	if not target or hp <= 0 then
		return
	end

	local targetRoot = getMobRootPart(target)
	if not targetRoot then
		return
	end

	local flatDist = getHorizontalDistance(playerRoot.Position, targetRoot.Position)
	if flatDist <= getBasicAttackStopRange() then
		-- Within 7.5 studs: stop auto-approach, face target, and attack if cooldown ready
		if isAutoApproaching then
			stopAutoApproach(humanoid, playerRoot)
		end
		executeAttackNow(playerRoot, target, targetRoot)
	else
		-- Out of range: start or continue auto-approaching target
		pendingAction = {
			type = "Attack",
			slotKey = nil,
			target = target,
		}
		isAutoApproaching = true
		local now = os.clock()
		if (now - lastMoveToUpdate) >= CHASE_PATH_UPDATE_INTERVAL then
			lastMoveToUpdate = now
			humanoid:MoveTo(targetRoot.Position)
		end
	end
end

function CombatController.RequestBasicAttack()
	isAutoAttackingTarget = true
	lastMoveToUpdate = 0
	tryPerformAttack()
end

function CombatController.Init()
	if initialized then
		return
	end
	initialized = true

	local function bindLocalCharacterWeaponEnchant(character: Model)
		task.defer(function()
			VFXController.ApplyWeaponEnchantVisuals(character)
		end)
		character:GetAttributeChangedSignal("WeaponEnchant"):Connect(function()
			VFXController.ApplyWeaponEnchantVisuals(character)
		end)
		character:GetAttributeChangedSignal("HasWeapon"):Connect(function()
			VFXController.ApplyWeaponEnchantVisuals(character)
		end)
		character.ChildAdded:Connect(function(child: Instance)
			if child.Name == "EquippedClassWeapon" then
				task.wait(0.05)
				VFXController.ApplyWeaponEnchantVisuals(character)
			end
		end)
	end

	if localPlayer.Character then
		bindLocalCharacterWeaponEnchant(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(bindLocalCharacterWeaponEnchant)

	Remotes.SkillVFX.OnClientEvent:Connect(function(skillId: string, casterPlayer: Player, payload: { [string]: any }?)
		if casterPlayer == localPlayer and skillId == "NO_TARGET" then
			local data = payload or {}
			local failedSkillId = data.skillId :: string?
			if failedSkillId then
				skillReadyTimestamps[failedSkillId] = 0
			end
		end
	end)

	-- Lineage 2 Two-Step Mouse Click Coordination:
	-- 1st Click on a mob (wasAlreadySelected == false): Select Target ONLY, stop any active attack/approach.
	-- 2nd Click on the SAME mob (wasAlreadySelected == true): Start auto-approach and attack!
	-- Click on empty ground (clickedMob == nil): Do NOT trigger an attack.
	TargetController.OnMobClicked.Event:Connect(function(clickedMob: Model?, wasAlreadySelected: boolean)
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

		if not clickedMob then
			-- Case C: Clicked on empty ground / non-mob -> do not trigger attack
			isHoldingLMB = false
			return
		end

		if not wasAlreadySelected then
			-- Case A: 1st Click on a new mob -> Select only, stop any active auto-attack or auto-approach
			isHoldingLMB = false
			isAutoAttackingTarget = false
			stopAutoApproach(humanoid, playerRoot)
			return
		end

		-- Case B: 2nd Click on the SAME mob that is ALREADY CurrentTarget -> Attack & Auto-Approach!
		local hp = getTargetCurrentHp(clickedMob)
		if hp > 0 then
			isClickToMoving = false
			isDraggingGroundMove = false
			clickMoveDestination = nil
			pendingNpcTarget = nil
			isHoldingLMB = true
			isAutoAttackingTarget = true
			lastMoveToUpdate = 0
			tryPerformAttack()
		end
	end)

	-- Lineage 2 Click-to-Move on Ground / Road / Platform
	TargetController.OnGroundClicked.Event:Connect(function(hitPos: Vector3)
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		isHoldingLMB = false
		isAutoAttackingTarget = false
		isAutoApproaching = false
		pendingAction = nil
		pendingNpcTarget = nil

		isClickToMoving = true
		isDraggingGroundMove = true
		clickMoveDestination = hitPos
		lastDragMoveUpdate = os.clock()
		lastDragRingVFXTime = os.clock()

		VFXController.PlayClickDestinationVFX(hitPos, false)
		humanoid:MoveTo(hitPos)
	end)

	-- Lineage 2 Click-on-NPC (Walk to NPC and open window within 12 studs)
	TargetController.OnNpcClicked.Event:Connect(function(npcModel: Model)
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if not humanoid or not playerRoot or humanoid.Health <= 0 then
			return
		end

		isHoldingLMB = false
		isAutoAttackingTarget = false
		isAutoApproaching = false
		pendingAction = nil
		isDraggingGroundMove = false

		local npcRoot = getMobRootPart(npcModel)
		if not npcRoot then
			return
		end

		VFXController.PlayClickDestinationVFX(npcRoot.Position, true)
		local flatDist = getHorizontalDistance(playerRoot.Position, npcRoot.Position)
		if flatDist <= NPC_INTERACT_RANGE then
			isClickToMoving = false
			pendingNpcTarget = nil
			humanoid:MoveTo(playerRoot.Position)
			Remotes.RequestNpcInteract:FireServer(npcModel)
		else
			isClickToMoving = true
			pendingNpcTarget = npcModel
			clickMoveDestination = npcRoot.Position
			lastDragMoveUpdate = os.clock()
			humanoid:MoveTo(npcRoot.Position)
		end
	end)

	TargetController.OnTargetChanged.Event:Connect(function(newTarget: Model?)
		if not newTarget then
			isHoldingLMB = false
			isAutoAttackingTarget = false
			local character = localPlayer.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			stopAutoApproach(humanoid, playerRoot)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.One then
			isHoldingAttackKey = true
			isAutoAttackingTarget = true
			lastMoveToUpdate = 0
			tryPerformAttack()
		elseif input.KeyCode == Enum.KeyCode.Q then
			CombatController.UseSkillSlot("Q")
		elseif input.KeyCode == Enum.KeyCode.E then
			CombatController.UseSkillSlot("E")
		elseif input.KeyCode == Enum.KeyCode.R then
			CombatController.UseSkillSlot("R")
		elseif input.KeyCode == Enum.KeyCode.F then
			CombatController.UseSkillSlot("F")
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isHoldingLMB = false
			isDraggingGroundMove = false
		elseif input.KeyCode == Enum.KeyCode.One then
			isHoldingAttackKey = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local playerRoot = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

		if isManualMovementKeyPressed() then
			isAutoAttackingTarget = false
			isClickToMoving = false
			isDraggingGroundMove = false
			clickMoveDestination = nil
			pendingNpcTarget = nil
			if isAutoApproaching then
				pendingAction = nil
				isAutoApproaching = false
				return
			end
		end

		-- Continuous Click-to-Move & NPC Walk-Up Handling
		if isClickToMoving and humanoid and playerRoot and humanoid.Health > 0 then
			local now = os.clock()
			if pendingNpcTarget then
				if not pendingNpcTarget.Parent then
					isClickToMoving = false
					pendingNpcTarget = nil
				else
					local npcRoot = getMobRootPart(pendingNpcTarget)
					if npcRoot then
						local distToNpc = getHorizontalDistance(playerRoot.Position, npcRoot.Position)
						if distToNpc <= NPC_INTERACT_RANGE then
							local reachedNpc = pendingNpcTarget
							isClickToMoving = false
							pendingNpcTarget = nil
							clickMoveDestination = nil
							humanoid:MoveTo(playerRoot.Position)
							Remotes.RequestNpcInteract:FireServer(reachedNpc)
						elseif (now - lastDragMoveUpdate) >= 0.15 then
							lastDragMoveUpdate = now
							humanoid:MoveTo(npcRoot.Position)
						end
					end
				end
			else
				-- Holding LMB while dragging mouse on ground continuously updates move destination
				if isDraggingGroundMove and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					if (now - lastDragMoveUpdate) >= 0.08 then
						lastDragMoveUpdate = now
						local hitKind, _, hitPos = TargetController.RaycastMouseWorld()
						if hitKind == "Ground" and hitPos then
							local prevDest = clickMoveDestination
							clickMoveDestination = hitPos
							humanoid:MoveTo(hitPos)
							if (now - lastDragRingVFXTime) >= 0.35 and (not prevDest or (hitPos - prevDest).Magnitude >= 3.0) then
								lastDragRingVFXTime = now
								VFXController.PlayClickDestinationVFX(hitPos, false)
							end
						end
					end
				end

				if clickMoveDestination then
					local distToDest = getHorizontalDistance(playerRoot.Position, clickMoveDestination)
					if distToDest <= 1.8 and not isDraggingGroundMove then
						isClickToMoving = false
						clickMoveDestination = nil
					elseif (now - lastDragMoveUpdate) >= 0.25 then
						lastDragMoveUpdate = now
						humanoid:MoveTo(clickMoveDestination)
					end
				end
			end
		end

		if isAutoApproaching and pendingAction ~= nil then
			if not humanoid or not playerRoot or humanoid.Health <= 0 then
				pendingAction = nil
				isAutoApproaching = false
				return
			end

			local queued = pendingAction
			local currentTarget = TargetController.GetTarget()
			-- Cancel if player manually cleared or changed target
			if currentTarget ~= queued.target or not queued.target.Parent then
				stopAutoApproach(humanoid, playerRoot)
				return
			end

			-- Verify target validity (alive, or spoiled corpse for SKILL_SWEEP)
			local targetHp = getTargetCurrentHp(queued.target)
			local isSweepSkill = false
			local skillData: SkillsConfig.SkillData? = nil
			if queued.type == "Skill" and queued.slotKey then
				skillData = CombatController.GetSkillForSlot(queued.slotKey)
				if skillData and skillData.targetType == "DeadSpoiledTarget" then
					isSweepSkill = true
				end
			end

			if isSweepSkill then
				local isSpoiled = queued.target:GetAttribute("IsSpoiled") == true
					or queued.target:GetAttribute("CanSweep") == true
				if targetHp > 0 or not isSpoiled then
					stopAutoApproach(humanoid, playerRoot)
					return
				end
			else
				if targetHp <= 0 then
					stopAutoApproach(humanoid, playerRoot)
					return
				end
			end

			local targetRoot = getMobRootPart(queued.target)
			if not targetRoot then
				stopAutoApproach(humanoid, playerRoot)
				return
			end

			local requiredRange = if queued.type == "Skill" and skillData
				then getRequiredSkillRange(skillData)
				else getBasicAttackStopRange()
			local flatDist = getHorizontalDistance(playerRoot.Position, targetRoot.Position)

			if flatDist <= requiredRange then
				-- Reached required range: stop moving, rotate to face target, and execute action!
				humanoid:MoveTo(playerRoot.Position)
				isAutoApproaching = false
				pendingAction = nil

				faceTargetHorizontally(playerRoot, targetRoot)

				if queued.type == "Skill" and queued.slotKey and skillData then
					local now = os.clock()
					local readyAt = skillReadyTimestamps[skillData.id] or 0
					if now >= readyAt then
						executeSkillNow(queued.slotKey :: "Q" | "E" | "R" | "F", skillData, playerRoot, queued.target)
					end
				else
					executeAttackNow(playerRoot, queued.target, targetRoot)
				end
			else
				-- Still out of range: continuously update MoveTo every 0.15s in case mob is moving
				local now = os.clock()
				if (now - lastMoveToUpdate) >= CHASE_PATH_UPDATE_INTERVAL then
					lastMoveToUpdate = now
					humanoid:MoveTo(targetRoot.Position)
				end
			end
		end

		-- Seamless continuous attack / re-chase if attacking CurrentTarget (2nd LMB click, holding LMB, or Key 1)
		if
			(isHoldingLMB or isHoldingAttackKey or isAutoAttackingTarget)
			and (not isAutoApproaching or (pendingAction and pendingAction.type == "Attack"))
		then
			tryPerformAttack()
		end
	end)
end

return CombatController
