--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18nFolder = Shared:WaitForChild("i18n")

local I18n = require(I18nFolder:WaitForChild("I18n"))
local Remotes = require(Shared:WaitForChild("Remotes"))

type MobOverheadEntry = {
	model: Model,
	billboard: BillboardGui,
	nameLabel: TextLabel,
	statusLabel: TextLabel,
	hpFill: Frame,
	stunRingPart: Part?,
}

local VFXController = {}

local overheadEntries: { [Model]: MobOverheadEntry } = {}
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

local function formatOverheadName(mobModel: Model): string
	local nameKey = (mobModel:GetAttribute("NameKey") :: string?) or mobModel.Name
	local level = (mobModel:GetAttribute("Level") :: number?) or 1
	local localizedName = I18n.t(nameKey)
	local localizedLevel = I18n.t("UI_LEVEL", { lv = level })
	return string.format("%s [%s]", localizedName, localizedLevel)
end

local function updateOverheadHp(entry: MobOverheadEntry)
	local currentHp = (entry.model:GetAttribute("CurrentHP") :: number?) or 0
	local maxHp = math.max(1, (entry.model:GetAttribute("MaxHP") :: number?) or 1)
	local ratio = math.clamp(currentHp / maxHp, 0, 1)

	TweenService:Create(
		entry.hpFill,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(ratio, 1) }
	):Play()
end

local function updateMobStatusVisuals(entry: MobOverheadEntry)
	local mobModel = entry.model
	local isStunned = mobModel:GetAttribute("IsStunned") == true
	local isSpoiled = mobModel:GetAttribute("IsSpoiled") == true
	local canSweep = mobModel:GetAttribute("CanSweep") == true

	if isStunned then
		entry.statusLabel.Visible = true
		entry.statusLabel.Text = "★ " .. I18n.t("UI_STUNNED") .. " ★"
		entry.statusLabel.TextColor3 = Color3.fromRGB(255, 230, 55)

		if not entry.stunRingPart then
			local head = mobModel:FindFirstChild("Head") :: BasePart?
			if head then
				local starRing = Instance.new("Part")
				starRing.Name = "StunStarsRing"
				starRing.Size = Vector3.new(2.2, 0.2, 2.2)
				starRing.Color = Color3.fromRGB(255, 225, 40)
				starRing.Material = Enum.Material.Neon
				starRing.Transparency = 0.25
				starRing.Anchored = true
				starRing.CanCollide = false
				starRing.CanQuery = false
				starRing.CanTouch = false
				starRing.Parent = mobModel
				entry.stunRingPart = starRing
			end
		end
	elseif isSpoiled or canSweep then
		entry.statusLabel.Visible = true
		entry.statusLabel.Text = "◆ " .. I18n.t("MSG_SPOIL_SUCCESS") .. " ◆"
		entry.statusLabel.TextColor3 = Color3.fromRGB(0, 235, 255)
		if entry.stunRingPart then
			entry.stunRingPart:Destroy()
			entry.stunRingPart = nil
		end
	else
		entry.statusLabel.Visible = false
		if entry.stunRingPart then
			entry.stunRingPart:Destroy()
			entry.stunRingPart = nil
		end
	end

	-- Lineage 2 Spoil Corpse Neon Blue Glow when dead and spoiled (CanSweep == true)
	local hp = (mobModel:GetAttribute("CurrentHP") :: number?) or 0
	local showBlueCorpseGlow = canSweep or (hp <= 0 and isSpoiled)
	local existingSweepHighlight = mobModel:FindFirstChild("SpoilCorpseHighlight")
	if showBlueCorpseGlow then
		if not existingSweepHighlight then
			local highlight = Instance.new("Highlight")
			highlight.Name = "SpoilCorpseHighlight"
			highlight.Adornee = mobModel
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillColor = Color3.fromRGB(0, 175, 255)
			highlight.OutlineColor = Color3.fromRGB(110, 245, 255)
			highlight.FillTransparency = 0.25
			highlight.OutlineTransparency = 0.0
			highlight.Parent = mobModel
		end
	else
		if existingSweepHighlight then
			existingSweepHighlight:Destroy()
		end
	end
end

local function setupMobOverhead(mobModel: Model)
	if overheadEntries[mobModel] then
		return
	end
	if mobModel:GetAttribute("IsMob") ~= true then
		return
	end

	local head = mobModel:WaitForChild("Head", 5)
	if not head or not head:IsA("BasePart") then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MobOverheadGui"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(185, 54)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 95
	billboard.Parent = head

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 16)
	statusLabel.Position = UDim2.fromOffset(0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBlack
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = Color3.fromRGB(255, 230, 55)
	statusLabel.TextStrokeColor3 = Color3.fromRGB(10, 12, 18)
	statusLabel.TextStrokeTransparency = 0.1
	statusLabel.Visible = false
	statusLabel.Text = ""
	statusLabel.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Position = UDim2.fromOffset(0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(10, 12, 18)
	nameLabel.TextStrokeTransparency = 0.15
	nameLabel.Text = formatOverheadName(mobModel)
	nameLabel.Parent = billboard

	local hpBarBg = Instance.new("Frame")
	hpBarBg.Name = "HPBarBg"
	hpBarBg.Size = UDim2.new(0.78, 0, 0, 7)
	hpBarBg.Position = UDim2.new(0.11, 0, 0, 39)
	hpBarBg.BackgroundColor3 = Color3.fromRGB(22, 24, 32)
	hpBarBg.BorderSizePixel = 0
	hpBarBg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 3)
	bgCorner.Parent = hpBarBg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(5, 5, 10)
	bgStroke.Thickness = 1
	bgStroke.Parent = hpBarBg

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.BackgroundColor3 = Color3.fromRGB(220, 48, 48)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBarBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = hpFill

	local entry: MobOverheadEntry = {
		model = mobModel,
		billboard = billboard,
		nameLabel = nameLabel,
		statusLabel = statusLabel,
		hpFill = hpFill,
		stunRingPart = nil,
	}
	overheadEntries[mobModel] = entry

	updateOverheadHp(entry)
	updateMobStatusVisuals(entry)

	mobModel:GetAttributeChangedSignal("CurrentHP"):Connect(function()
		updateOverheadHp(entry)
		updateMobStatusVisuals(entry)
	end)
	mobModel:GetAttributeChangedSignal("IsStunned"):Connect(function()
		updateMobStatusVisuals(entry)
	end)
	mobModel:GetAttributeChangedSignal("IsSpoiled"):Connect(function()
		updateMobStatusVisuals(entry)
	end)
	mobModel:GetAttributeChangedSignal("CanSweep"):Connect(function()
		updateMobStatusVisuals(entry)
	end)

	mobModel.AncestryChanged:Connect(function(_, parent: Instance?)
		if not parent then
			overheadEntries[mobModel] = nil
		end
	end)
end

local function flashMobHighlight(targetModel: Model, isCrit: boolean, usedSoulshot: boolean?)
	if targetModel:GetAttribute("CanSweep") == true then
		return
	end

	local existing = targetModel:FindFirstChild("HitFlashHighlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "HitFlashHighlight"
	highlight.Adornee = targetModel
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	if usedSoulshot then
		highlight.FillColor = if isCrit then Color3.fromRGB(100, 250, 255) else Color3.fromRGB(0, 225, 255)
		highlight.OutlineColor = Color3.fromRGB(185, 255, 255)
		highlight.FillTransparency = 0.2
		highlight.OutlineTransparency = 0.0
	else
		highlight.FillColor = if isCrit then Color3.fromRGB(255, 80, 50) else Color3.fromRGB(255, 255, 255)
		highlight.OutlineColor = Color3.fromRGB(255, 180, 120)
		highlight.FillTransparency = 0.35
		highlight.OutlineTransparency = 0.2
	end
	highlight.Parent = targetModel

	task.delay(0.14, function()
		if highlight.Parent then
			highlight:Destroy()
		end
	end)
end

local function spawnFloatingTextAtAdornee(adornee: BasePart, text: string, color: Color3, textSize: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FloatingCombatText"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(220, 46)
	local randomX = (math.random() - 0.5) * 2.2
	local startOffset = Vector3.new(randomX, 4.4, 0)
	billboard.StudsOffset = startOffset
	billboard.AlwaysOnTop = true
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeColor3 = Color3.fromRGB(10, 10, 14)
	label.TextStrokeTransparency = 0.05
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.Parent = billboard

	local tweenInfo = TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(billboard, tweenInfo, {
		StudsOffset = startOffset + Vector3.new(0, 3.2, 0),
	}):Play()

	TweenService:Create(label, tweenInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(0.92, function()
		if billboard.Parent then
			billboard:Destroy()
		end
	end)
end

local function spawnFloatingCombatText(targetModel: Model, damage: number, isCrit: boolean, isMiss: boolean)
	local head = targetModel:FindFirstChild("Head") :: BasePart?
	local adornee = head or getMobRootPart(targetModel)
	if not adornee then
		return
	end

	if isMiss then
		spawnFloatingTextAtAdornee(adornee, I18n.t("UI_MISS"), Color3.fromRGB(185, 195, 210), 16)
	elseif isCrit then
		spawnFloatingTextAtAdornee(
			adornee,
			string.format("%s %d", I18n.t("UI_CRIT"), damage),
			Color3.fromRGB(255, 145, 35),
			24
		)
	else
		spawnFloatingTextAtAdornee(adornee, tostring(damage), Color3.fromRGB(255, 255, 255), 18)
	end
end

local function createExpandingRingVFX(center: Vector3, maxRadius: number, color: Color3, duration: number)
	local part = Instance.new("Part")
	part.Name = "SkillRingVFX"
	part.Shape = Enum.PartType.Cylinder
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.2
	part.Size = Vector3.new(0.25, 2, 2)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = Workspace

	TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.25, maxRadius * 2, maxRadius * 2),
			Transparency = 1,
		}
	):Play()

	task.delay(duration + 0.05, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

local function findWeaponBladePart(weaponModel: Model): BasePart?
	local candidates = {
		"CleaverBlade",
		"HeatedEdge",
		"BatonShaft",
		"StunTip",
		"HarvesterRod",
		"LaserHook",
		"Handle",
	}
	for _, partName in ipairs(candidates) do
		local found = weaponModel:FindFirstChild(partName)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return weaponModel.PrimaryPart or weaponModel:FindFirstChildWhichIsA("BasePart")
end

function VFXController.ApplyWeaponEnchantVisuals(character: Model)
	local weaponModel = character:FindFirstChild("EquippedClassWeapon")
	if not weaponModel or not weaponModel:IsA("Model") then
		return
	end

	if character:GetAttribute("HasWeapon") == false then
		return
	end

	local enchantLevel = (character:GetAttribute("WeaponEnchant") :: number?)
		or (weaponModel:GetAttribute("WeaponEnchant") :: number?)
		or 0

	local bladePart = findWeaponBladePart(weaponModel)
	if not bladePart then
		return
	end

	local existingHighlight = weaponModel:FindFirstChild("WeaponEnchantHighlight") :: Highlight?
	local existingLight = bladePart:FindFirstChild("WeaponEnchantLight") :: PointLight?
	local existingParticles = bladePart:FindFirstChild("WeaponEnchantParticles") :: ParticleEmitter?
	local trail = weaponModel:FindFirstChild("WeaponTrail") :: Trail?

	-- +0 to +3: No extra glow (standard weapon look)
	if enchantLevel <= 3 then
		if existingHighlight then
			existingHighlight:Destroy()
		end
		if existingLight then
			existingLight:Destroy()
		end
		if existingParticles then
			existingParticles:Destroy()
		end
		if trail then
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		end
		return
	end

	local glowColor: Color3
	local secondaryColor: Color3
	local fillTrans: number
	local outlineTrans: number
	local lightBrightness: number
	local lightRange: number
	local particleRate: number
	local particleSpeed: NumberRange

	if enchantLevel <= 6 then
		-- +4 to +6: Soft Silver-White glow (Color3.fromRGB(220, 240, 255))
		glowColor = Color3.fromRGB(220, 240, 255)
		secondaryColor = Color3.fromRGB(255, 255, 255)
		fillTrans = 0.42
		outlineTrans = 0.12
		lightBrightness = 1.5
		lightRange = 6.5
		particleRate = 14
		particleSpeed = NumberRange.new(1.2, 2.5)
	elseif enchantLevel <= 9 then
		-- +7 to +9: Intense Deep Blue electric glow (Color3.fromRGB(0, 140, 255)) + rising sparks
		glowColor = Color3.fromRGB(0, 140, 255)
		secondaryColor = Color3.fromRGB(130, 225, 255)
		fillTrans = 0.25
		outlineTrans = 0.0
		lightBrightness = 2.6
		lightRange = 9.5
		particleRate = 36
		particleSpeed = NumberRange.new(2.5, 5.0)
	elseif enchantLevel <= 15 then
		-- +10 to +15: Fiery Orange/Gold glow (Color3.fromRGB(255, 130, 0)) + strong light
		glowColor = Color3.fromRGB(255, 130, 0)
		secondaryColor = Color3.fromRGB(255, 230, 95)
		fillTrans = 0.18
		outlineTrans = 0.0
		lightBrightness = 3.8
		lightRange = 12.5
		particleRate = 58
		particleSpeed = NumberRange.new(3.2, 6.5)
	else
		-- +16: Overcharged Blood-Red Neon aura (Color3.fromRGB(255, 20, 40)) + bright crimson trail!
		glowColor = Color3.fromRGB(255, 20, 40)
		secondaryColor = Color3.fromRGB(255, 110, 130)
		fillTrans = 0.08
		outlineTrans = 0.0
		lightBrightness = 5.2
		lightRange = 16.0
		particleRate = 90
		particleSpeed = NumberRange.new(4.5, 8.5)
	end

	local highlight = existingHighlight or Instance.new("Highlight")
	highlight.Name = "WeaponEnchantHighlight"
	highlight.Adornee = weaponModel
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = glowColor
	highlight.OutlineColor = secondaryColor
	highlight.FillTransparency = fillTrans
	highlight.OutlineTransparency = outlineTrans
	highlight.Parent = weaponModel

	local pointLight = existingLight or Instance.new("PointLight")
	pointLight.Name = "WeaponEnchantLight"
	pointLight.Color = glowColor
	pointLight.Brightness = lightBrightness
	pointLight.Range = lightRange
	pointLight.Parent = bladePart

	local particles = existingParticles or Instance.new("ParticleEmitter")
	particles.Name = "WeaponEnchantParticles"
	particles.Color = ColorSequence.new(glowColor, secondaryColor)
	particles.LightEmission = 1.0
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if enchantLevel >= 16 then 0.42 else 0.26),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	particles.Lifetime = NumberRange.new(0.28, 0.55)
	particles.Rate = particleRate
	particles.Speed = particleSpeed
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.Acceleration = Vector3.new(0, 6.5, 0)
	particles.Parent = bladePart

	if trail then
		trail.Color = ColorSequence.new(glowColor, secondaryColor)
	end
end

function VFXController.PlaySoulshotBurstVFX(targetModel: Model?, attackerCharacter: Model?)
	local cyanColor = Color3.fromRGB(0, 240, 255)
	local whiteCyan = Color3.fromRGB(190, 255, 255)

	-- 1. Crisp cyan electric flash on the weapon blade/tip
	local charModel = attackerCharacter or localPlayer.Character
	if charModel then
		local weaponModel = charModel:FindFirstChild("EquippedClassWeapon")
		if weaponModel and weaponModel:IsA("Model") then
			local blade = findWeaponBladePart(weaponModel)
			if blade then
				local weaponFlash = Instance.new("Part")
				weaponFlash.Name = "SoulshotWeaponFlash"
				weaponFlash.Shape = Enum.PartType.Ball
				weaponFlash.Material = Enum.Material.Neon
				weaponFlash.Color = cyanColor
				weaponFlash.Transparency = 0.15
				weaponFlash.Size = Vector3.new(1.1, 1.1, 1.1)
				weaponFlash.CFrame = blade.CFrame
				weaponFlash.Anchored = true
				weaponFlash.CanCollide = false
				weaponFlash.CanQuery = false
				weaponFlash.CanTouch = false
				weaponFlash.Parent = Workspace

				local flashLight = Instance.new("PointLight")
				flashLight.Color = cyanColor
				flashLight.Brightness = 4.0
				flashLight.Range = 9
				flashLight.Parent = weaponFlash

				TweenService:Create(
					weaponFlash,
					TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Size = Vector3.new(3.2, 3.2, 3.2),
						Transparency = 1,
					}
				):Play()

				task.delay(0.24, function()
					if weaponFlash.Parent then
						weaponFlash:Destroy()
					end
				end)
			end
		end
	end

	-- 2. Crisp cyan electric ring & spark burst on the target mob
	if targetModel and targetModel.Parent then
		local root = getMobRootPart(targetModel)
		if root then
			createExpandingRingVFX(root.Position, 4.8, cyanColor, 0.28)

			local burstPart = Instance.new("Part")
			burstPart.Name = "SoulshotMobBurst"
			burstPart.Shape = Enum.PartType.Ball
			burstPart.Material = Enum.Material.Neon
			burstPart.Color = whiteCyan
			burstPart.Transparency = 0.2
			burstPart.Size = Vector3.new(1.4, 1.4, 1.4)
			burstPart.CFrame = root.CFrame
			burstPart.Anchored = true
			burstPart.CanCollide = false
			burstPart.CanQuery = false
			burstPart.CanTouch = false
			burstPart.Parent = Workspace

			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(whiteCyan, cyanColor)
			emitter.LightEmission = 1.0
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Lifetime = NumberRange.new(0.18, 0.32)
			emitter.Speed = NumberRange.new(12, 22)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Rate = 0
			emitter.Parent = burstPart
			emitter:Emit(16)

			TweenService:Create(
				burstPart,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = Vector3.new(4.2, 4.2, 4.2),
					Transparency = 1,
				}
			):Play()

			task.delay(0.35, function()
				if burstPart.Parent then
					burstPart:Destroy()
				end
			end)
		end
	end
end

local function createBeamConeVFX(origin: Vector3, direction: Vector3, range: number, color: Color3, isFire: boolean)
	local flatDir = Vector3.new(direction.X, 0, direction.Z)
	local unitDir = if flatDir.Magnitude > 0.05 then flatDir.Unit else Vector3.new(0, 0, -1)
	local midPoint = origin + unitDir * (range * 0.5)

	local beamPart = Instance.new("Part")
	beamPart.Name = if isFire then "FlambeConeVFX" else "WaterCannonBeamVFX"
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = color
	beamPart.Transparency = 0.25
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.CanQuery = false
	beamPart.CanTouch = false
	beamPart.Size = if isFire then Vector3.new(2.5, 2.2, range) else Vector3.new(2.2, 2.2, range)
	beamPart.CFrame = CFrame.lookAt(midPoint, origin + unitDir * range)
	beamPart.Parent = Workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, if isFire then 3.2 else 2.0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Lifetime = NumberRange.new(0.25, 0.45)
	particles.Rate = 90
	particles.Speed = NumberRange.new(18, 28)
	particles.SpreadAngle = if isFire then Vector2.new(28, 15) else Vector2.new(8, 8)
	particles.Parent = beamPart

	TweenService:Create(
		beamPart,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = if isFire then Vector3.new(9.5, 3.2, range) else Vector3.new(4.2, 2.8, range),
			Transparency = 1,
		}
	):Play()

	task.delay(0.45, function()
		if beamPart.Parent then
			beamPart:Destroy()
		end
	end)
end

local function createTracerBeamVFX(p0: Vector3, p1: Vector3, color: Color3, thickness: number?, lifetime: number?)
	local dist = (p1 - p0).Magnitude
	if dist < 0.2 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "TracerBeamVFX"
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.15
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local th = thickness or 0.22
	part.Size = Vector3.new(th, th, dist)
	part.CFrame = CFrame.lookAt((p0 + p1) * 0.5, p1)
	part.Parent = Workspace

	local lt = lifetime or 0.15
	task.delay(lt, function()
		if part and part.Parent then
			part:Destroy()
		end
	end)
end

local function attachPlayerBuffVFX(player: Player, color: Color3, duration: number, isShield: boolean)
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local auraPart = Instance.new("Part")
	auraPart.Name = "PlayerSkillBuffVFX"
	auraPart.Shape = if isShield then Enum.PartType.Ball else Enum.PartType.Cylinder
	auraPart.Material = Enum.Material.ForceField
	auraPart.Color = color
	auraPart.Transparency = 0.35
	auraPart.Size = if isShield then Vector3.new(6.8, 6.8, 6.8) else Vector3.new(0.4, 5.2, 5.2)
	auraPart.CanCollide = false
	auraPart.CanQuery = false
	auraPart.CanTouch = false
	auraPart.Massless = true
	auraPart.Anchored = false
	auraPart.CFrame = if isShield
		then rootPart.CFrame
		else (rootPart.CFrame * CFrame.new(0, -2.4, 0) * CFrame.Angles(0, 0, math.rad(90)))
	auraPart.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = auraPart
	weld.Parent = auraPart

	task.delay(duration, function()
		if auraPart.Parent then
			auraPart:Destroy()
		end
	end)
end

local function handleSkillVFX(skillId: string, casterPlayer: Player, payload: { [string]: any }?)
	local data = payload or {}
	local usedSoulshot = data.usedSoulshot == true
	if usedSoulshot then
		local targetModel = data.targetModel :: Model?
		VFXController.PlaySoulshotBurstVFX(targetModel, casterPlayer.Character)
	end

	if skillId == "SKILL_MEGAPHONE_AGGRO" then
		local origin = (data.origin :: Vector3?)
			or (if casterPlayer.Character and casterPlayer.Character.PrimaryPart
				then casterPlayer.Character.PrimaryPart.Position
				else Vector3.zero)
		local radius = (data.radius :: number?) or 20
		createExpandingRingVFX(origin, radius, Color3.fromRGB(255, 55, 65), 0.55)
	elseif skillId == "SKILL_WATER_CANNON" then
		local origin = (data.origin :: Vector3?) or Vector3.zero
		local direction = (data.direction :: Vector3?) or Vector3.new(0, 0, -1)
		local range = (data.range :: number?) or 22
		createBeamConeVFX(origin, direction, range, Color3.fromRGB(30, 175, 255), false)
	elseif skillId == "SKILL_FLAMBE" then
		local origin = (data.origin :: Vector3?) or Vector3.zero
		local direction = (data.direction :: Vector3?) or Vector3.new(0, 0, -1)
		local range = (data.range :: number?) or 18
		createBeamConeVFX(origin, direction, range, Color3.fromRGB(255, 110, 25), true)
	elseif skillId == "SKILL_RIOT_SHIELD" then
		local duration = (data.duration :: number?) or 8
		attachPlayerBuffVFX(casterPlayer, Color3.fromRGB(45, 165, 255), duration, true)
	elseif skillId == "SKILL_FRIDAY_RUSH" then
		local duration = (data.duration :: number?) or 10
		attachPlayerBuffVFX(casterPlayer, Color3.fromRGB(255, 60, 45), duration, false)
	elseif skillId == "SKILL_MONOPOLY" then
		local duration = (data.duration :: number?) or 15
		attachPlayerBuffVFX(casterPlayer, Color3.fromRGB(255, 215, 55), duration, false)
	elseif skillId == "SKILL_SPOIL" then
		local targetModel = data.targetModel :: Model?
		local statusKey = (data.statusKey :: string?) or "MSG_SPOIL_SUCCESS"
		if targetModel then
			local root = getMobRootPart(targetModel)
			if root then
				createExpandingRingVFX(root.Position, 5.5, Color3.fromRGB(0, 235, 255), 0.4)
			end
			local head = (targetModel:FindFirstChild("Head") :: BasePart?) or root
			if head then
				spawnFloatingTextAtAdornee(head, I18n.t(statusKey), Color3.fromRGB(0, 240, 255), 20)
			end
		end
	elseif skillId == "SKILL_SWEEP" then
		local targetPos = (data.targetPosition :: Vector3?) or Vector3.zero
		local tokens = (data.tokens :: number?) or 1
		local cash = (data.cash :: number?) or 10
		createExpandingRingVFX(targetPos, 6.5, Color3.fromRGB(0, 200, 255), 0.45)

		if casterPlayer.Character then
			local head = casterPlayer.Character:FindFirstChild("Head") :: BasePart?
			if head then
				local text = I18n.t("MSG_SWEEP_REWARD", { tokens = tokens, cash = cash })
				spawnFloatingTextAtAdornee(head, text, Color3.fromRGB(80, 255, 185), 19)
			end
		end
	elseif skillId == "RANGED_AUTO_ATTACK" or skillId == "DRONE_LASER_FIRE" then
		local origin = (data.origin :: Vector3?)
			or (if casterPlayer.Character and casterPlayer.Character.PrimaryPart
				then casterPlayer.Character.PrimaryPart.Position + Vector3.new(0, 1.5, 0)
				else Vector3.zero)
		local targetPos = (data.targetPosition :: Vector3?)
		if not targetPos and data.targetModel then
			local tRoot = (data.targetModel:FindFirstChild("HumanoidRootPart") or data.targetModel:FindFirstChild("Head")) :: BasePart?
			if tRoot then
				targetPos = tRoot.Position
			end
		end
		if origin and targetPos then
			local beamColor = if skillId == "DRONE_LASER_FIRE"
				then Color3.fromRGB(0, 245, 255)
				else Color3.fromRGB(255, 215, 60)
			createTracerBeamVFX(origin, targetPos, beamColor, 0.22, 0.14)
			createExpandingRingVFX(targetPos, 2.5, beamColor, 0.22)
		end
	elseif skillId == "SKILL_INSTANT_HEAL" or skillId == "FLOATING_HEAL" then
		local targetModel = data.targetModel :: Model?
		local healAmt = (data.healAmount :: number?) or (data.amount :: number?) or 120
		if targetModel then
			local head = (targetModel:FindFirstChild("Head") :: BasePart?)
				or (targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?)
			if head then
				spawnFloatingTextAtAdornee(head, "+" .. tostring(healAmt) .. " HP", Color3.fromRGB(80, 255, 120), 22)
				createExpandingRingVFX(head.Position, 4.0, Color3.fromRGB(80, 255, 120), 0.35)
			end
		end
	elseif skillId == "SKILL_MANA_RECHARGE" then
		local origin = (data.origin :: Vector3?)
			or (if casterPlayer.Character and casterPlayer.Character.PrimaryPart
				then casterPlayer.Character.PrimaryPart.Position
				else Vector3.zero)
		local radius = (data.radius :: number?) or 25
		createExpandingRingVFX(origin, radius, Color3.fromRGB(0, 220, 255), 0.5)
		if casterPlayer.Character then
			local head = casterPlayer.Character:FindFirstChild("Head") :: BasePart?
			if head then
				spawnFloatingTextAtAdornee(head, "+MP RECHARGE", Color3.fromRGB(0, 220, 255), 20)
			end
		end
	elseif
		skillId == "SKILL_SONG_SUBWAY_WIND"
		or skillId == "SKILL_DANCE_OVERDRIVE"
		or skillId == "SKILL_CHANT_STRIKE"
		or skillId == "SKILL_MASTERWORK_POLISH"
		or skillId == "SKILL_SERVOMOTOR_OVERCLOCK"
		or skillId == "SKILL_SANITARY_DOME"
	then
		local origin = (data.origin :: Vector3?)
			or (if casterPlayer.Character and casterPlayer.Character.PrimaryPart
				then casterPlayer.Character.PrimaryPart.Position
				else Vector3.zero)
		local radius = (data.radius :: number?) or 30
		local auraColor = if skillId == "SKILL_SANITARY_DOME"
			then Color3.fromRGB(80, 255, 180)
			elseif skillId == "SKILL_SONG_SUBWAY_WIND" then Color3.fromRGB(0, 230, 255)
			elseif skillId == "SKILL_DANCE_OVERDRIVE" then Color3.fromRGB(255, 65, 95)
			elseif skillId == "SKILL_CHANT_STRIKE" then Color3.fromRGB(255, 215, 45)
			elseif skillId == "SKILL_MASTERWORK_POLISH" then Color3.fromRGB(255, 155, 45)
			else Color3.fromRGB(0, 240, 255)
		createExpandingRingVFX(origin, radius, auraColor, 0.6)
		attachPlayerBuffVFX(casterPlayer, auraColor, (data.duration :: number?) or 20, false)
	else
		local targetPos = (data.targetPosition :: Vector3?)
		if targetPos then
			createExpandingRingVFX(targetPos, 4.5, Color3.fromRGB(255, 210, 95), 0.32)
		end
	end
end

function VFXController.PlayPotionVFX(character: Model, potionType: string, amountRestored: number)
	if not character or not character.Parent then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local isHp = (potionType == "HP")
	local mainColor = if isHp then Color3.fromRGB(65, 250, 120) else Color3.fromRGB(0, 215, 255)
	local secondaryColor = if isHp then Color3.fromRGB(190, 255, 210) else Color3.fromRGB(180, 245, 255)

	-- Rising neon ring + vertical sparkle burst around the player
	local ringPart = Instance.new("Part")
	ringPart.Name = "PotionAuraRingVFX"
	ringPart.Shape = Enum.PartType.Cylinder
	ringPart.Material = Enum.Material.Neon
	ringPart.Color = mainColor
	ringPart.Transparency = 0.18
	ringPart.Anchored = true
	ringPart.CanCollide = false
	ringPart.CanQuery = false
	ringPart.CanTouch = false
	ringPart.Size = Vector3.new(0.28, 3.6, 3.6)
	ringPart.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ringPart.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(secondaryColor, mainColor)
	emitter.LightEmission = 1.0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	emitter.Lifetime = NumberRange.new(0.32, 0.55)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, 14, 0)
	emitter.Rate = 0
	emitter.Parent = ringPart
	emitter:Emit(20)

	TweenService:Create(
		ringPart,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Size = Vector3.new(0.18, 5.4, 5.4),
			Transparency = 1,
		}
	):Play()

	task.delay(0.55, function()
		if ringPart.Parent then
			ringPart:Destroy()
		end
	end)

	-- Floating "+X HP" (green) or "+X MP" (cyan) text above player head
	local head = (character:FindFirstChild("Head") :: BasePart?) or rootPart
	local text = if isHp
		then string.format("+%d %s", amountRestored, I18n.t("UI_HP"))
		else string.format("+%d %s", amountRestored, I18n.t("UI_MP"))
	spawnFloatingTextAtAdornee(head, text, mainColor, 19)
end

function VFXController.PlayClickDestinationVFX(hitPosition: Vector3, isNpcClick: boolean?)
	local ringColor = if isNpcClick then Color3.fromRGB(255, 215, 75) else Color3.fromRGB(0, 235, 255)
	local innerColor = if isNpcClick then Color3.fromRGB(255, 245, 175) else Color3.fromRGB(185, 250, 255)

	local ringPart = Instance.new("Part")
	ringPart.Name = "L2ClickMoveRingVFX"
	ringPart.Shape = Enum.PartType.Cylinder
	ringPart.Material = Enum.Material.Neon
	ringPart.Color = ringColor
	ringPart.Transparency = 0.15
	ringPart.Anchored = true
	ringPart.CanCollide = false
	ringPart.CanQuery = false
	ringPart.CanTouch = false
	ringPart.CastShadow = false
	ringPart.Size = Vector3.new(0.10, 3.1, 3.1)
	ringPart.CFrame = CFrame.new(hitPosition + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ringPart.Parent = Workspace

	local centerPin = Instance.new("Part")
	centerPin.Name = "L2ClickMoveCenterVFX"
	centerPin.Shape = Enum.PartType.Ball
	centerPin.Material = Enum.Material.Neon
	centerPin.Color = innerColor
	centerPin.Transparency = 0.1
	centerPin.Anchored = true
	centerPin.CanCollide = false
	centerPin.CanQuery = false
	centerPin.CanTouch = false
	centerPin.CastShadow = false
	centerPin.Size = Vector3.new(0.65, 0.65, 0.65)
	centerPin.CFrame = CFrame.new(hitPosition + Vector3.new(0, 0.18, 0))
	centerPin.Parent = Workspace

	TweenService:Create(
		ringPart,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.08, 0.35, 0.35),
			Transparency = 1,
		}
	):Play()

	TweenService:Create(
		centerPin,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.15, 1.4, 0.15),
			Transparency = 1,
		}
	):Play()

	task.delay(0.58, function()
		if ringPart.Parent then
			ringPart:Destroy()
		end
		if centerPin.Parent then
			centerPin:Destroy()
		end
	end)
end

function VFXController.Init()
	if initialized then
		return
	end
	initialized = true

	local activeMobsFolder = Workspace:WaitForChild("ActiveMobs")

	for _, child in ipairs(activeMobsFolder:GetChildren()) do
		if child:IsA("Model") then
			task.spawn(setupMobOverhead, child)
		end
	end

	activeMobsFolder.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			task.spawn(setupMobOverhead, child)
		end
	end)

	I18n.OnLanguageChanged.Event:Connect(function()
		for _, entry in pairs(overheadEntries) do
			if entry.model.Parent then
				entry.nameLabel.Text = formatOverheadName(entry.model)
				updateMobStatusVisuals(entry)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local angle = os.clock() * 4.5
		for _, entry in pairs(overheadEntries) do
			local ring = entry.stunRingPart
			if ring and ring.Parent then
				local head = entry.model:FindFirstChild("Head") :: BasePart?
				if head then
					ring.CFrame = CFrame.new(head.Position + Vector3.new(0, 1.45, 0))
						* CFrame.Angles(math.rad(12), angle, 0)
				end
			end
		end
	end)

	local function watchPlayerCharacterEnchant(player: Player)
		local function bindChar(char: Model)
			task.defer(function()
				VFXController.ApplyWeaponEnchantVisuals(char)
			end)
			char:GetAttributeChangedSignal("WeaponEnchant"):Connect(function()
				VFXController.ApplyWeaponEnchantVisuals(char)
			end)
			char:GetAttributeChangedSignal("HasWeapon"):Connect(function()
				VFXController.ApplyWeaponEnchantVisuals(char)
			end)
			char.ChildAdded:Connect(function(child: Instance)
				if child.Name == "EquippedClassWeapon" then
					task.wait(0.05)
					VFXController.ApplyWeaponEnchantVisuals(char)
				end
			end)
		end

		if player.Character then
			bindChar(player.Character)
		end
		player.CharacterAdded:Connect(bindChar)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayerCharacterEnchant(player)
	end
	Players.PlayerAdded:Connect(watchPlayerCharacterEnchant)

	Remotes.CombatHitFeedback.OnClientEvent:Connect(
		function(
			targetModel: Model,
			damage: number,
			isCrit: boolean,
			isMiss: boolean,
			usedSoulshot: boolean?,
			attackerPlayer: Player?
		)
			if typeof(targetModel) == "Instance" and targetModel:IsA("Model") then
				if not isMiss then
					flashMobHighlight(targetModel, isCrit, usedSoulshot)
					if usedSoulshot == true then
						local attackerChar = if attackerPlayer then attackerPlayer.Character else localPlayer.Character
						VFXController.PlaySoulshotBurstVFX(targetModel, attackerChar)
					end
				end
				spawnFloatingCombatText(targetModel, damage, isCrit, isMiss)
			end
		end
	)

	Remotes.SkillVFX.OnClientEvent:Connect(handleSkillVFX)

	Remotes.PotionVFX.OnClientEvent:Connect(function(character: Model, potionType: string, amountRestored: number)
		if typeof(character) == "Instance" and character:IsA("Model") and type(potionType) == "string" then
			VFXController.PlayPotionVFX(character, potionType, tonumber(amountRestored) or 0)
		end
	end)

	Remotes.LootDropVFX.OnClientEvent:Connect(function(itemNameKey: string, qty: number, grade: string?)
		local character = localPlayer.Character
		if not character then
			return
		end
		local head = (character:FindFirstChild("Head") :: BasePart?)
			or (character:FindFirstChild("HumanoidRootPart") :: BasePart?)
		if not head then
			return
		end
		local localizedItem = I18n.t(tostring(itemNameKey or ""))
		local countNum = tonumber(qty) or 1
		local text = if countNum > 1
			then string.format("★ +%d %s", countNum, localizedItem)
			else string.format("★ %s [%s]", localizedItem, tostring(grade or "NG"))
		local dropColor = if grade == "D"
			then Color3.fromRGB(255, 215, 65)
			else Color3.fromRGB(115, 255, 145)
		spawnFloatingTextAtAdornee(head, text, dropColor, 18)
	end)
end

return VFXController
