--!strict

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local WorldBuilderService = {}

local initialized = false

local function createPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	canCollide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = if canCollide == nil then true else canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addPointLight(parent: Instance, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
end

local function addSurfaceSign(
	parent: BasePart,
	face: Enum.NormalId,
	titleText: string,
	subtitleText: string,
	titleColor: Color3,
	subtitleColor: Color3,
	bgColor: Color3?
)
	local sGui = Instance.new("SurfaceGui")
	sGui.Name = "SignGui_" .. face.Name
	sGui.Face = face
	sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sGui.PixelsPerStud = 32
	sGui.LightInfluence = 0.15
	sGui.Brightness = 1.2
	sGui.Parent = parent

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = bgColor or Color3.fromRGB(22, 24, 30)
	bg.BorderSizePixel = 0
	bg.Parent = sGui

	local stroke = Instance.new("UIStroke")
	stroke.Color = titleColor
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = bg

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -16, 0.55, 0)
	titleLbl.Position = UDim2.fromOffset(8, 5)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextScaled = true
	titleLbl.TextColor3 = titleColor
	titleLbl.Text = titleText
	titleLbl.Parent = bg

	local subLbl = Instance.new("TextLabel")
	subLbl.Size = UDim2.new(1, -16, 0.35, 0)
	subLbl.Position = UDim2.new(0, 8, 0.58, 0)
	subLbl.BackgroundTransparency = 1
	subLbl.Font = Enum.Font.GothamBold
	subLbl.TextScaled = true
	subLbl.TextColor3 = subtitleColor
	subLbl.Text = subtitleText
	subLbl.Parent = bg
end

local function buildStreetlamp(parent: Instance, pos: Vector3, lampColor: Color3)
	local model = Instance.new("Model")
	model.Name = "UrbanStreetlamp"
	model.Parent = parent

	createPart(
		"LampPedestal",
		Vector3.new(2.0, 2.2, 2.0),
		CFrame.new(pos + Vector3.new(0, 1.1, 0)),
		Color3.fromRGB(42, 44, 48),
		Enum.Material.Metal,
		model
	)
	createPart(
		"LampPole",
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(pos + Vector3.new(0, 9.1, 0)),
		Color3.fromRGB(34, 36, 40),
		Enum.Material.Metal,
		model
	)
	createPart(
		"LampCrossbar",
		Vector3.new(2.6, 0.4, 0.4),
		CFrame.new(pos + Vector3.new(0, 15.8, 0)),
		Color3.fromRGB(34, 36, 40),
		Enum.Material.Metal,
		model
	)
	local lantern = createPart(
		"LanternGlass",
		Vector3.new(1.5, 1.8, 1.5),
		CFrame.new(pos + Vector3.new(0, 16.8, 0)),
		lampColor,
		Enum.Material.Neon,
		model,
		false
	)
	addPointLight(lantern, lampColor, 1.8, 38)
end

local function buildBench(parent: Instance, cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = "PlazaBench"
	model.Parent = parent

	createPart(
		"Seat",
		Vector3.new(8.5, 0.4, 2.2),
		cframe * CFrame.new(0, 1.8, 0),
		Color3.fromRGB(112, 74, 44),
		Enum.Material.WoodPlanks,
		model
	)
	createPart(
		"Backrest",
		Vector3.new(8.5, 1.8, 0.35),
		cframe * CFrame.new(0, 2.8, -0.95),
		Color3.fromRGB(98, 64, 38),
		Enum.Material.WoodPlanks,
		model
	)
	createPart(
		"LegL",
		Vector3.new(0.5, 1.8, 2.0),
		cframe * CFrame.new(-3.4, 0.9, 0),
		Color3.fromRGB(36, 38, 42),
		Enum.Material.Metal,
		model
	)
	createPart(
		"LegR",
		Vector3.new(0.5, 1.8, 2.0),
		cframe * CFrame.new(3.4, 0.9, 0),
		Color3.fromRGB(36, 38, 42),
		Enum.Material.Metal,
		model
	)
end

local function buildParkTree(parent: Instance, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "CityParkTree"
	model.Parent = parent

	createPart(
		"PlanterCurb",
		Vector3.new(6.5, 1.0, 6.5),
		CFrame.new(pos + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(82, 84, 88),
		Enum.Material.Concrete,
		model
	)
	createPart(
		"Soil",
		Vector3.new(5.5, 1.1, 5.5),
		CFrame.new(pos + Vector3.new(0, 0.55, 0)),
		Color3.fromRGB(62, 46, 34),
		Enum.Material.Ground,
		model
	)
	createPart(
		"Trunk",
		Vector3.new(1.8, 11, 1.8),
		CFrame.new(pos + Vector3.new(0, 6.0, 0)),
		Color3.fromRGB(88, 62, 42),
		Enum.Material.Wood,
		model
	)
	createPart(
		"CanopyMain",
		Vector3.new(11, 8, 11),
		CFrame.new(pos + Vector3.new(0, 13.5, 0)),
		Color3.fromRGB(48, 86, 48),
		Enum.Material.Grass,
		model
	)
	createPart(
		"CanopyTop",
		Vector3.new(7.5, 5, 7.5),
		CFrame.new(pos + Vector3.new(0, 18.0, 0)),
		Color3.fromRGB(58, 102, 54),
		Enum.Material.Grass,
		model
	)
end

local function buildStoneBalustradeSegment(parent: Instance, cframe: CFrame, length: number)
	local model = Instance.new("Model")
	model.Name = "StoneBalustrade"
	model.Parent = parent

	local stoneColor = Color3.fromRGB(108, 110, 115)
	local ironColor = Color3.fromRGB(38, 40, 46)

	createPart(
		"LowStoneCurb",
		Vector3.new(length, 1.4, 1.6),
		cframe * CFrame.new(0, 0.7, 0),
		stoneColor,
		Enum.Material.Concrete,
		model
	)
	createPart(
		"TopIronRail",
		Vector3.new(length, 0.35, 0.45),
		cframe * CFrame.new(0, 3.8, 0),
		ironColor,
		Enum.Material.Metal,
		model
	)
	createPart(
		"MidIronRail",
		Vector3.new(length, 0.25, 0.35),
		cframe * CFrame.new(0, 2.6, 0),
		ironColor,
		Enum.Material.Metal,
		model
	)

	-- End Stone Pillars
	local half = length * 0.5
	createPart(
		"PillarLeft",
		Vector3.new(2.4, 4.6, 2.4),
		cframe * CFrame.new(-half, 2.3, 0),
		Color3.fromRGB(122, 124, 130),
		Enum.Material.Concrete,
		model
	)
	createPart(
		"PillarRight",
		Vector3.new(2.4, 4.6, 2.4),
		cframe * CFrame.new(half, 2.3, 0),
		Color3.fromRGB(122, 124, 130),
		Enum.Material.Concrete,
		model
	)
end

local function buildDirectionalSignpost(
	parent: Instance,
	pos: Vector3,
	facingTarget: Vector3,
	mainText: string,
	subText: string,
	accentColor: Color3
)
	local model = Instance.new("Model")
	model.Name = "SectorSignpost"
	model.Parent = parent

	local postCFrame = CFrame.lookAt(pos + Vector3.new(0, 4.5, 0), Vector3.new(facingTarget.X, pos.Y + 4.5, facingTarget.Z))
	createPart("Post", Vector3.new(0.65, 9, 0.65), postCFrame, Color3.fromRGB(42, 46, 54), Enum.Material.Metal, model)

	local board = createPart(
		"SignBoard",
		Vector3.new(12.5, 3.0, 0.45),
		postCFrame * CFrame.new(0, 3.6, 0),
		Color3.fromRGB(20, 24, 32),
		Enum.Material.Metal,
		model
	)
	addSurfaceSign(board, Enum.NormalId.Front, mainText, subText, accentColor, Color3.fromRGB(230, 235, 245))
	addSurfaceSign(board, Enum.NormalId.Back, mainText, subText, accentColor, Color3.fromRGB(230, 235, 245))
end

local function buildTrainCarModel(
	parent: Instance,
	centerPos: Vector3,
	bodyColor: Color3,
	stripeColor: Color3,
	isArmoredBossTrain: boolean?
)
	local model = Instance.new("Model")
	model.Name = if isArmoredBossTrain then "ArmoredBaronLocomotive" else "CommuterTrainCar"
	model.Parent = parent

	local carLength = 58
	local carWidth = 11.5
	local carHeight = 11.5

	-- Chassis & Bogies (Wheels)
	createPart(
		"Chassis",
		Vector3.new(carLength, 1.4, carWidth),
		CFrame.new(centerPos + Vector3.new(0, 2.2, 0)),
		Color3.fromRGB(32, 34, 38),
		Enum.Material.Metal,
		model
	)

	for _, xOff in ipairs({ -20, -14, 14, 20 }) do
		local wheelAxle = createPart(
			"WheelSet",
			Vector3.new(2.6, 2.6, carWidth + 0.4),
			CFrame.new(centerPos + Vector3.new(xOff, 1.3, 0)),
			Color3.fromRGB(24, 26, 30),
			Enum.Material.Metal,
			model
		)
		wheelAxle.Shape = Enum.PartType.Cylinder
	end

	-- Main Coach Body
	createPart(
		"CoachBody",
		Vector3.new(carLength, carHeight, carWidth),
		CFrame.new(centerPos + Vector3.new(0, 2.9 + carHeight * 0.5, 0)),
		bodyColor,
		Enum.Material.Metal,
		model
	)

	-- Accent Livery Stripe
	createPart(
		"LiveryStripe",
		Vector3.new(carLength + 0.2, 1.1, carWidth + 0.2),
		CFrame.new(centerPos + Vector3.new(0, 6.2, 0)),
		stripeColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)

	-- Lit Passenger Windows along both sides
	local winColor = if isArmoredBossTrain
		then Color3.fromRGB(255, 110, 75)
		else Color3.fromRGB(255, 230, 165)
	for xIdx = -3, 3 do
		if xIdx ~= 0 then
			createPart(
				"WindowBand_" .. tostring(xIdx),
				Vector3.new(5.2, 2.6, carWidth + 0.26),
				CFrame.new(centerPos + Vector3.new(xIdx * 7.5, 9.2, 0)),
				winColor,
				Enum.Material.Neon,
				model,
				false
			)
		end
	end

	-- Center Sliding Doors
	createPart(
		"SlidingDoorCenter",
		Vector3.new(5.6, 7.8, carWidth + 0.24),
		CFrame.new(centerPos + Vector3.new(0, 6.8, 0)),
		Color3.fromRGB(58, 64, 74),
		Enum.Material.Metal,
		model,
		false
	)

	-- Roof AC Units
	for _, xOff in ipairs({ -16, 0, 16 }) do
		createPart(
			"RoofACUnit",
			Vector3.new(8, 1.2, 6),
			CFrame.new(centerPos + Vector3.new(xOff, 2.9 + carHeight + 0.6, 0)),
			Color3.fromRGB(68, 72, 80),
			Enum.Material.Metal,
			model
		)
	end

	-- Headlights at ends
	createPart(
		"HeadlightsWest",
		Vector3.new(0.4, 1.2, 6.5),
		CFrame.new(centerPos + Vector3.new(-carLength * 0.5 - 0.1, 5.2, 0)),
		Color3.fromRGB(255, 240, 190),
		Enum.Material.Neon,
		model,
		false
	)
	createPart(
		"TaillightsEast",
		Vector3.new(0.4, 1.2, 6.5),
		CFrame.new(centerPos + Vector3.new(carLength * 0.5 + 0.1, 5.2, 0)),
		Color3.fromRGB(255, 65, 65),
		Enum.Material.Neon,
		model,
		false
	)
end

local function buildCitySkylineBuilding(
	parent: Instance,
	name: string,
	centerPos: Vector3,
	size: Vector3,
	wallColor: Color3,
	wallMaterial: Enum.Material,
	windowColor: Color3,
	signTitle: string?
)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local body = createPart(
		"BuildingMass",
		size,
		CFrame.new(centerPos + Vector3.new(0, size.Y * 0.5, 0)),
		wallColor,
		wallMaterial,
		model
	)

	createPart(
		"RoofCornice",
		Vector3.new(size.X + 2, 1.8, size.Z + 2),
		CFrame.new(centerPos + Vector3.new(0, size.Y + 0.9, 0)),
		Color3.fromRGB(48, 50, 56),
		Enum.Material.Concrete,
		model
	)

	local floors = math.max(2, math.floor((size.Y - 8) / 10))
	for f = 1, floors do
		local y = 4 + f * 9.5
		if y < size.Y - 3 then
			createPart(
				"WindowRow_" .. tostring(f),
				Vector3.new(size.X - 6, 3.2, size.Z + 0.3),
				CFrame.new(centerPos + Vector3.new(0, y, 0)),
				windowColor,
				Enum.Material.Neon,
				model,
				false
			)
			createPart(
				"WindowRowSide_" .. tostring(f),
				Vector3.new(size.X + 0.3, 3.2, size.Z - 6),
				CFrame.new(centerPos + Vector3.new(0, y, 0)),
				windowColor,
				Enum.Material.Neon,
				model,
				false
			)
		end
	end

	if signTitle then
		local signBoard = createPart(
			"RooftopSign",
			Vector3.new(math.min(34, size.X - 4), 5.0, 1.0),
			CFrame.new(centerPos + Vector3.new(0, size.Y + 4.2, 0)),
			Color3.fromRGB(18, 22, 30),
			Enum.Material.Metal,
			model
		)
		addSurfaceSign(
			signBoard,
			Enum.NormalId.Front,
			signTitle,
			"MEGAPOLIS DISTRICT",
			windowColor,
			Color3.fromRGB(225, 230, 240)
		)
		addSurfaceSign(
			signBoard,
			Enum.NormalId.Back,
			signTitle,
			"MEGAPOLIS DISTRICT",
			windowColor,
			Color3.fromRGB(225, 230, 240)
		)
	end

	return body
end

local function buildNpcHumanoidModel(
	npcFolder: Folder,
	npcName: string,
	pos: Vector3,
	lookAtPos: Vector3,
	displayName: string,
	roleSubtitle: string,
	torsoColor: Color3,
	legsColor: Color3,
	accentColor: Color3,
	windowType: string?,
	promptActionText: string?
): Model
	local model = Instance.new("Model")
	model.Name = npcName
	model:SetAttribute("IsNPC", true)
	if windowType then
		model:SetAttribute("NpcWindowType", windowType)
	end
	model.Parent = npcFolder

	local baseCFrame = CFrame.lookAt(pos + Vector3.new(0, 3, 0), Vector3.new(lookAtPos.X, pos.Y + 3, lookAtPos.Z))

	local rootPart = createPart(
		"HumanoidRootPart",
		Vector3.new(2, 2, 1),
		baseCFrame,
		torsoColor,
		Enum.Material.SmoothPlastic,
		model,
		true
	)
	rootPart.Transparency = 1

	local torso = createPart("Torso", Vector3.new(2, 2, 1), baseCFrame, torsoColor, Enum.Material.SmoothPlastic, model, true)

	local head = createPart(
		"Head",
		Vector3.new(1.25, 1.25, 1.25),
		baseCFrame * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(238, 205, 178),
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	createPart(
		"NpcHat",
		Vector3.new(1.42, 0.45, 1.42),
		baseCFrame * CFrame.new(0, 2.08, 0),
		accentColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)

	createPart(
		"ChestTrim",
		Vector3.new(1.85, 0.24, 1.06),
		baseCFrame * CFrame.new(0, 0.45, 0),
		accentColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)

	createPart(
		"Left Arm",
		Vector3.new(1, 2, 1),
		baseCFrame * CFrame.new(-1.5, 0, 0),
		torsoColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	createPart(
		"Right Arm",
		Vector3.new(1, 2, 1),
		baseCFrame * CFrame.new(1.5, 0, 0),
		torsoColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	createPart(
		"Left Leg",
		Vector3.new(1, 2, 1),
		baseCFrame * CFrame.new(-0.5, -2, 0),
		legsColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)
	createPart(
		"Right Leg",
		Vector3.new(1, 2, 1),
		baseCFrame * CFrame.new(0.5, -2, 0),
		legsColor,
		Enum.Material.SmoothPlastic,
		model,
		false
	)

	model.PrimaryPart = rootPart

	-- Overhead Lineage 2 NPC Nameplate (Gold Name + Green [NPC] Subtitle, MaxDistance = 85)
	local bGui = Instance.new("BillboardGui")
	bGui.Name = "NpcNameplate"
	bGui.Adornee = head
	bGui.Size = UDim2.fromOffset(210, 44)
	bGui.StudsOffset = Vector3.new(0, 2.6, 0)
	bGui.AlwaysOnTop = false
	bGui.MaxDistance = 85
	bGui.Parent = head

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "RoleSubtitle"
	subLabel.Size = UDim2.new(1, 0, 0, 17)
	subLabel.Position = UDim2.fromOffset(0, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextSize = 11
	subLabel.TextColor3 = Color3.fromRGB(115, 245, 140)
	subLabel.TextStrokeColor3 = Color3.fromRGB(8, 10, 14)
	subLabel.TextStrokeTransparency = 0.1
	subLabel.Text = roleSubtitle
	subLabel.Parent = bGui

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NpcName"
	nameLabel.Size = UDim2.new(1, 0, 0, 21)
	nameLabel.Position = UDim2.fromOffset(0, 17)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 95)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(8, 10, 14)
	nameLabel.TextStrokeTransparency = 0.1
	nameLabel.Text = displayName
	nameLabel.Parent = bGui

	if windowType then
		local targetWindow = windowType
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "NpcInteractPrompt"
		prompt.ObjectText = displayName
		prompt.ActionText = promptActionText or "Открыть / Open"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = torso

		prompt.Triggered:Connect(function(player: Player)
			Remotes.OpenNpcWindow:FireClient(player, targetWindow)
		end)

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 22
		clickDetector.Parent = model
		clickDetector.MouseClick:Connect(function(player: Player)
			Remotes.OpenNpcWindow:FireClient(player, targetWindow)
		end)
	end

	return model
end

local function setupAtmosphereAndBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(32, 35, 40)
		baseplate.Material = Enum.Material.Asphalt
		baseplate.Size = Vector3.new(680, 16, 680)
		baseplate.Position = Vector3.new(0, -8, 0)
	else
		createPart(
			"Baseplate",
			Vector3.new(680, 16, 680),
			CFrame.new(0, -8, 0),
			Color3.fromRGB(32, 35, 40),
			Enum.Material.Asphalt,
			Workspace
		)
	end

	Lighting.ClockTime = 18.8
	Lighting.Brightness = 1.9
	Lighting.Ambient = Color3.fromRGB(58, 62, 74)
	Lighting.OutdoorAmbient = Color3.fromRGB(76, 82, 98)
end

function WorldBuilderService.Init()
	if initialized then
		return
	end
	initialized = true

	setupAtmosphereAndBaseplate()

	local existingMap = Workspace:FindFirstChild("WorldMap")
	if existingMap then
		existingMap:Destroy()
	end
	local worldMap = Instance.new("Folder")
	worldMap.Name = "WorldMap"
	worldMap.Parent = Workspace

	local existingNpcs = Workspace:FindFirstChild("NPCs")
	if existingNpcs then
		existingNpcs:Destroy()
	end
	local npcsFolder = Instance.new("Folder")
	npcsFolder.Name = "NPCs"
	npcsFolder.Parent = Workspace

	-- =====================================================================
	-- 1. CENTRAL STATION FOUNTAIN PLAZA & GRAND TERMINAL BUILDING
	--    (Safe Zone: X in [-85, 85], Z in [-65, 85])
	-- =====================================================================
	local plazaFolder = Instance.new("Folder")
	plazaFolder.Name = "CentralStationPlaza"
	plazaFolder.Parent = worldMap

	-- Clean Stone/Slate Plaza Paving (No neon green strips!)
	createPart(
		"MainPlazaPaving",
		Vector3.new(170, 0.4, 150),
		CFrame.new(0, 0.2, 10),
		Color3.fromRGB(58, 62, 68),
		Enum.Material.Slate,
		plazaFolder
	)
	createPart(
		"InnerPlazaCourtyard",
		Vector3.new(110, 0.44, 92),
		CFrame.new(0, 0.22, 18),
		Color3.fromRGB(68, 72, 78),
		Enum.Material.Concrete,
		plazaFolder
	)

	-- Central City Fountain at (0, 0.4, 16)
	local fountainModel = Instance.new("Model")
	fountainModel.Name = "CentralCityFountain"
	fountainModel.Parent = plazaFolder

	local basinRim = createPart(
		"FountainBasinRim",
		Vector3.new(2.2, 22, 22),
		CFrame.new(0, 1.3, 16) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(98, 102, 110),
		Enum.Material.Concrete,
		fountainModel
	)
	basinRim.Shape = Enum.PartType.Cylinder

	local fountainWater = createPart(
		"FountainWater",
		Vector3.new(1.6, 19.2, 19.2),
		CFrame.new(0, 1.35, 16) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(48, 138, 190),
		Enum.Material.Glass,
		fountainModel
	)
	fountainWater.Shape = Enum.PartType.Cylinder
	fountainWater.Transparency = 0.22

	createPart(
		"FountainCenterPedestal",
		Vector3.new(5.2, 6.5, 5.2),
		CFrame.new(0, 3.6, 16),
		Color3.fromRGB(112, 116, 124),
		Enum.Material.Concrete,
		fountainModel
	)
	createPart(
		"FountainUpperBowl",
		Vector3.new(1.2, 9.5, 9.5),
		CFrame.new(0, 6.8, 16) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(108, 112, 120),
		Enum.Material.Concrete,
		fountainModel
	).Shape = Enum.PartType.Cylinder

	local fountainSpout = createPart(
		"FountainWaterSpout",
		Vector3.new(2.2, 4.2, 2.2),
		CFrame.new(0, 8.8, 16),
		Color3.fromRGB(155, 225, 255),
		Enum.Material.Neon,
		fountainModel,
		false
	)
	fountainSpout.Transparency = 0.35
	addPointLight(fountainSpout, Color3.fromRGB(145, 215, 255), 1.6, 28)

	-- Central SpawnLocation in front of the Fountain (0, 0.45, 38)
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "CentralStationSpawn"
	spawnLoc.Size = Vector3.new(12, 0.5, 12)
	spawnLoc.CFrame = CFrame.new(0, 0.28, 38)
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Neutral = true
	spawnLoc.Transparency = 1
	spawnLoc.Parent = plazaFolder

	-- Realistic Architectural Stone Balustrades & Iron Fences around the Plaza Perimeter
	-- South Perimeter (Z = 85, with wide 38-stud avenue gateway in center)
	buildStoneBalustradeSegment(plazaFolder, CFrame.new(-52, 0.4, 85), 64)
	buildStoneBalustradeSegment(plazaFolder, CFrame.new(52, 0.4, 85), 64)
	-- West Perimeter (X = -85, with 36-stud gateway to West Cargo Yard)
	buildStoneBalustradeSegment(plazaFolder, CFrame.new(-85, 0.4, -36) * CFrame.Angles(0, math.rad(90), 0), 54)
	buildStoneBalustradeSegment(plazaFolder, CFrame.new(-85, 0.4, 54) * CFrame.Angles(0, math.rad(90), 0), 58)
	-- East Perimeter (X = 85, with 36-stud gateway to East Concourse)
	buildStoneBalustradeSegment(plazaFolder, CFrame.new(85, 0.4, -36) * CFrame.Angles(0, math.rad(90), 0), 54)
	buildStoneBalustradeSegment(plazaFolder, CFrame.new(85, 0.4, 54) * CFrame.Angles(0, math.rad(90), 0), 58)

	-- =====================================================================
	-- GRAND CENTRAL TERMINAL BUILDING FACADE & CLOCK TOWER (Z = -46..-30)
	-- =====================================================================
	local terminalModel = Instance.new("Model")
	terminalModel.Name = "GrandStationTerminal"
	terminalModel.Parent = plazaFolder

	local brickColor = Color3.fromRGB(118, 66, 54)
	local stoneTrimColor = Color3.fromRGB(138, 134, 126)
	local roofSlateColor = Color3.fromRGB(42, 46, 54)
	local warmWinColor = Color3.fromRGB(255, 222, 155)

	-- Left & Right Terminal Wings + Center Hall with wide walkthrough archway (X = -14..14 open!)
	createPart(
		"TerminalWestWing",
		Vector3.new(54, 30, 16),
		CFrame.new(-46, 15.2, -38),
		brickColor,
		Enum.Material.Brick,
		terminalModel
	)
	createPart(
		"TerminalEastWing",
		Vector3.new(54, 30, 16),
		CFrame.new(46, 15.2, -38),
		brickColor,
		Enum.Material.Brick,
		terminalModel
	)
	-- Upper Bridge over the Center Archway (leaving 14-stud tall x 26-stud wide open portal underneath)
	createPart(
		"TerminalCenterUpperHeader",
		Vector3.new(38, 16, 18),
		CFrame.new(0, 22.2, -38),
		brickColor,
		Enum.Material.Brick,
		terminalModel
	)
	createPart(
		"ArchPillarLeft",
		Vector3.new(6, 14, 18),
		CFrame.new(-16, 7.2, -38),
		stoneTrimColor,
		Enum.Material.Concrete,
		terminalModel
	)
	createPart(
		"ArchPillarRight",
		Vector3.new(6, 14, 18),
		CFrame.new(16, 7.2, -38),
		stoneTrimColor,
		Enum.Material.Concrete,
		terminalModel
	)

	-- Lit Upper Windows on West & East Terminal Wings
	for _, xCenter in ipairs({ -58, -42, -28, 28, 42, 58 }) do
		createPart(
			"TerminalWindowLower",
			Vector3.new(7, 6, 16.4),
			CFrame.new(xCenter, 9.5, -38),
			warmWinColor,
			Enum.Material.Neon,
			terminalModel,
			false
		)
		createPart(
			"TerminalWindowUpper",
			Vector3.new(7, 6, 16.4),
			CFrame.new(xCenter, 20.5, -38),
			warmWinColor,
			Enum.Material.Neon,
			terminalModel,
			false
		)
	end

	-- Terminal Roof Cornice & Clock Tower
	createPart(
		"TerminalMainRoof",
		Vector3.new(150, 2.4, 20),
		CFrame.new(0, 31.4, -38),
		roofSlateColor,
		Enum.Material.Slate,
		terminalModel
	)
	createPart(
		"ClockTowerShaft",
		Vector3.new(22, 24, 16),
		CFrame.new(0, 44.5, -38),
		brickColor,
		Enum.Material.Brick,
		terminalModel
	)
	createPart(
		"ClockTowerRoof",
		Vector3.new(25, 3, 19),
		CFrame.new(0, 58.0, -38),
		roofSlateColor,
		Enum.Material.Slate,
		terminalModel
	)
	createPart(
		"ClockTowerSpire",
		Vector3.new(3, 12, 3),
		CFrame.new(0, 65.5, -38),
		Color3.fromRGB(185, 165, 95),
		Enum.Material.Metal,
		terminalModel
	)

	local clockFaceSouth = createPart(
		"ClockFaceSouth",
		Vector3.new(1.2, 10, 10),
		CFrame.new(0, 46, -29.8) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 240, 185),
		Enum.Material.Neon,
		terminalModel,
		false
	)
	clockFaceSouth.Shape = Enum.PartType.Cylinder

	-- Cantilevered South Plaza Canopy & Main Station Sign Board
	createPart(
		"SouthPlazaCanopy",
		Vector3.new(86, 1.4, 16),
		CFrame.new(0, 15.5, -22),
		roofSlateColor,
		Enum.Material.Metal,
		terminalModel
	)
	local stationSign = createPart(
		"StationFacadeSign",
		Vector3.new(54, 4.2, 1.0),
		CFrame.new(0, 18.2, -14.5),
		Color3.fromRGB(20, 24, 32),
		Enum.Material.Metal,
		terminalModel
	)
	addSurfaceSign(
		stationSign,
		Enum.NormalId.Front,
		"ЦЕНТРАЛЬНЫЙ ВОКЗАЛ • CENTRAL STATION",
		"MEGAPOLIS TRANSIT AUTHORITY",
		Color3.fromRGB(255, 215, 95),
		Color3.fromRGB(215, 225, 240)
	)

	-- Career Inspector Desk under the Terminal Archway (0, 0.4, -24)
	createPart(
		"InspectorDesk",
		Vector3.new(10, 3.4, 3.8),
		CFrame.new(0, 2.1, -26.5),
		Color3.fromRGB(48, 52, 62),
		Enum.Material.Metal,
		plazaFolder
	)

	-- =====================================================================
	-- REALISTIC URBAN BOOTHS FOR MERCHANT & BLACKSMITH (Spaced 104 studs apart!)
	-- =====================================================================
	-- Left Side: Street Convenience Kiosk at (-52, 0.4, 18)
	local kioskModel = Instance.new("Model")
	kioskModel.Name = "StreetConvenienceKiosk"
	kioskModel.Parent = plazaFolder

	createPart(
		"KioskBackWall",
		Vector3.new(4, 11, 18),
		CFrame.new(-62, 5.9, 18),
		Color3.fromRGB(42, 54, 68),
		Enum.Material.Metal,
		kioskModel
	)
	createPart(
		"KioskCounter",
		Vector3.new(4.5, 3.6, 16),
		CFrame.new(-55.5, 2.2, 18),
		Color3.fromRGB(58, 72, 88),
		Enum.Material.Metal,
		kioskModel
	)
	createPart(
		"KioskRoofAwning",
		Vector3.new(13, 1.2, 20),
		CFrame.new(-58, 11.8, 18),
		Color3.fromRGB(28, 86, 115),
		Enum.Material.Metal,
		kioskModel
	)
	local kioskSign = createPart(
		"KioskSignBoard",
		Vector3.new(1.0, 2.8, 16),
		CFrame.new(-51.8, 13.2, 18),
		Color3.fromRGB(18, 24, 34),
		Enum.Material.Metal,
		kioskModel
	)
	addSurfaceSign(
		kioskSign,
		Enum.NormalId.Right,
		"ЭКСПРЕСС-КИОСК • CITY KIOSK",
		"ЗЕЛЬЯ • ЭНЕРГЕТИКИ • СВИТКИ",
		Color3.fromRGB(115, 235, 255),
		Color3.fromRGB(235, 240, 250)
	)

	-- Right Side: Industrial Smithy & Mechanic Workshop Bay at (52, 0.4, 18)
	local smithyModel = Instance.new("Model")
	smithyModel.Name = "IndustrialSmithyBay"
	smithyModel.Parent = plazaFolder

	createPart(
		"SmithyBackWall",
		Vector3.new(4.5, 12, 18),
		CFrame.new(62, 6.4, 18),
		brickColor,
		Enum.Material.Brick,
		smithyModel
	)
	createPart(
		"SmithyRoof",
		Vector3.new(13, 1.2, 20),
		CFrame.new(58, 12.6, 18),
		roofSlateColor,
		Enum.Material.Metal,
		smithyModel
	)
	createPart(
		"SmithyAnvilBase",
		Vector3.new(3.2, 2.6, 4.4),
		CFrame.new(55, 1.7, 14),
		Color3.fromRGB(36, 38, 44),
		Enum.Material.Metal,
		smithyModel
	)
	local forgeHearth = createPart(
		"SmithyForgeCoals",
		Vector3.new(4.0, 2.4, 5.0),
		CFrame.new(58, 2.2, 22),
		Color3.fromRGB(255, 120, 35),
		Enum.Material.Neon,
		smithyModel
	)
	addPointLight(forgeHearth, Color3.fromRGB(255, 135, 45), 2.0, 26)

	local smithySign = createPart(
		"SmithySignBoard",
		Vector3.new(1.0, 2.8, 16),
		CFrame.new(51.8, 14.0, 18),
		Color3.fromRGB(24, 20, 18),
		Enum.Material.Metal,
		smithyModel
	)
	addSurfaceSign(
		smithySign,
		Enum.NormalId.Left,
		"МАСТЕРСКАЯ ЗАТОЧКИ • BLACKSMITH",
		"УЛУЧШЕНИЕ ОРУЖИЯ +1 .. +16",
		Color3.fromRGB(255, 195, 75),
		Color3.fromRGB(240, 230, 210)
	)

	-- Plaza Trees, Benches & Warm Vintage Streetlamps
	buildParkTree(plazaFolder, Vector3.new(-32, 0.4, 48))
	buildParkTree(plazaFolder, Vector3.new(32, 0.4, 48))
	buildParkTree(plazaFolder, Vector3.new(-32, 0.4, -6))
	buildParkTree(plazaFolder, Vector3.new(32, 0.4, -6))

	buildBench(plazaFolder, CFrame.new(-20, 0.4, 28) * CFrame.Angles(0, math.rad(180), 0))
	buildBench(plazaFolder, CFrame.new(20, 0.4, 28) * CFrame.Angles(0, math.rad(180), 0))
	buildBench(plazaFolder, CFrame.new(-20, 0.4, 4))
	buildBench(plazaFolder, CFrame.new(20, 0.4, 4))

	buildStreetlamp(plazaFolder, Vector3.new(-24, 0.4, 62), Color3.fromRGB(255, 220, 150))
	buildStreetlamp(plazaFolder, Vector3.new(24, 0.4, 62), Color3.fromRGB(255, 220, 150))
	buildStreetlamp(plazaFolder, Vector3.new(-24, 0.4, -14), Color3.fromRGB(255, 220, 150))
	buildStreetlamp(plazaFolder, Vector3.new(24, 0.4, -14), Color3.fromRGB(255, 220, 150))

	-- 4 Directional Exit Signposts at the Safe Zone Gateways
	buildDirectionalSignpost(
		plazaFolder,
		Vector3.new(-22, 0.4, 80),
		Vector3.new(-22, 0.4, 20),
		"▼ ЮГ: ПАРК И АЛЛЕЯ [Ур. 1-3]",
		"SOUTH: NOVICE AVENUE [Lv. 1-3]",
		Color3.fromRGB(125, 245, 150)
	)
	buildDirectionalSignpost(
		plazaFolder,
		Vector3.new(-80, 0.4, -4),
		Vector3.new(-20, 0.4, -4),
		"◄ ЗАПАД: ПРОМЗОНА И СКЛАДЫ [Ур. 5-7]",
		"WEST: INDUSTRIAL CARGO YARD [Lv. 5-7]",
		Color3.fromRGB(255, 215, 85)
	)
	buildDirectionalSignpost(
		plazaFolder,
		Vector3.new(80, 0.4, -4),
		Vector3.new(20, 0.4, -4),
		"► ВОСТОК: ПЕРРОН КОНТРОЛЯ [Ур. 9]",
		"EAST: TURNSTILE CONCOURSE [Lv. 9]",
		Color3.fromRGB(255, 150, 75)
	)
	buildDirectionalSignpost(
		plazaFolder,
		Vector3.new(22, 0.4, -60),
		Vector3.new(22, 0.4, 0),
		"▲ СЕВЕР: Ж/Д ДЕПО БОССА [Ур. 10]",
		"NORTH: PLATFORM BARON DEPOT [Lv. 10]",
		Color3.fromRGB(255, 85, 85)
	)

	-- =====================================================================
	-- 2. RAILWAY TRACKS, SLEEPERS, LEVEL CROSSING & TRAIN CARS (Z = -68..-145)
	-- =====================================================================
	local railwayFolder = Instance.new("Folder")
	railwayFolder.Name = "RailwayCorridor"
	railwayFolder.Parent = worldMap

	-- Yellow Safety Line along North Edge of Station Platform (Z = -64)
	createPart(
		"PlatformSafetyLine",
		Vector3.new(168, 0.45, 1.4),
		CFrame.new(0, 0.24, -64),
		Color3.fromRGB(235, 190, 45),
		Enum.Material.Concrete,
		railwayFolder
	)

	-- Gravel Ballast Trackbed running East-West
	createPart(
		"GravelTrackbed",
		Vector3.new(560, 0.25, 76),
		CFrame.new(0, 0.12, -106),
		Color3.fromRGB(52, 48, 46),
		Enum.Material.Slate,
		railwayFolder
	)

	-- Center Pedestrian Railway Crossing Walkway (X = -18..18, Z = -65..-148)
	createPart(
		"RailCrossingWalkway",
		Vector3.new(32, 0.38, 84),
		CFrame.new(0, 0.19, -106),
		Color3.fromRGB(68, 72, 78),
		Enum.Material.Concrete,
		railwayFolder
	)

	-- Twin Railway Tracks (Track 1 at Z = -88, Track 2 at Z = -124)
	for _, trackZ in ipairs({ -88, -124 }) do
		-- Steel Rails
		createPart(
			"SteelRailNorth",
			Vector3.new(540, 0.55, 0.45),
			CFrame.new(0, 0.45, trackZ - 3.6),
			Color3.fromRGB(145, 152, 162),
			Enum.Material.Metal,
			railwayFolder
		)
		createPart(
			"SteelRailSouth",
			Vector3.new(540, 0.55, 0.45),
			CFrame.new(0, 0.45, trackZ + 3.6),
			Color3.fromRGB(145, 152, 162),
			Enum.Material.Metal,
			railwayFolder
		)

		-- Wooden Sleepers (Ties) every 6 studs
		for xTie = -252, 252, 6 do
			createPart(
				"WoodSleeper",
				Vector3.new(1.8, 0.32, 10.5),
				CFrame.new(xTie, 0.24, trackZ),
				Color3.fromRGB(78, 54, 36),
				Enum.Material.WoodPlanks,
				railwayFolder
			)
		end
	end

	-- 2 Parked Commuter & Cargo Train Cars on the Tracks (outside the center crossing)
	buildTrainCarModel(
		railwayFolder,
		Vector3.new(-86, 0.5, -88),
		Color3.fromRGB(42, 58, 86),
		Color3.fromRGB(215, 175, 65),
		false
	)
	buildTrainCarModel(
		railwayFolder,
		Vector3.new(86, 0.5, -124),
		Color3.fromRGB(82, 42, 42),
		Color3.fromRGB(210, 215, 225),
		false
	)

	-- =====================================================================
	-- 3. FOUR SPACIOUS HUNTING SECTORS & CITY SKYLINE BUILDINGS
	-- =====================================================================
	-- SOUTH SECTOR: Novice Avenue & Park Plaza (Lv. 1-3, Z = 110..235)
	local southFolder = Instance.new("Folder")
	southFolder.Name = "SouthSector_NoviceAvenue"
	southFolder.Parent = worldMap

	createPart(
		"SouthBoulevardRoad",
		Vector3.new(130, 0.25, 145),
		CFrame.new(0, 0.12, 160),
		Color3.fromRGB(44, 48, 54),
		Enum.Material.Concrete,
		southFolder
	)
	buildParkTree(southFolder, Vector3.new(-58, 0.2, 125))
	buildParkTree(southFolder, Vector3.new(58, 0.2, 125))
	buildParkTree(southFolder, Vector3.new(-58, 0.2, 175))
	buildParkTree(southFolder, Vector3.new(58, 0.2, 175))
	buildBench(southFolder, CFrame.new(-34, 0.2, 158) * CFrame.Angles(0, math.rad(90), 0))
	buildBench(southFolder, CFrame.new(34, 0.2, 158) * CFrame.Angles(0, math.rad(-90), 0))
	buildStreetlamp(southFolder, Vector3.new(-38, 0.2, 118), Color3.fromRGB(255, 220, 145))
	buildStreetlamp(southFolder, Vector3.new(38, 0.2, 118), Color3.fromRGB(255, 220, 145))
	buildStreetlamp(southFolder, Vector3.new(-38, 0.2, 198), Color3.fromRGB(255, 220, 145))
	buildStreetlamp(southFolder, Vector3.new(38, 0.2, 198), Color3.fromRGB(255, 220, 145))

	-- WEST SECTOR: Industrial Cargo Yard (Lv. 5-7, X = -235..-115)
	local westFolder = Instance.new("Folder")
	westFolder.Name = "WestSector_CargoYard"
	westFolder.Parent = worldMap

	createPart(
		"WestConcreteYard",
		Vector3.new(130, 0.25, 140),
		CFrame.new(-170, 0.12, 10),
		Color3.fromRGB(48, 50, 54),
		Enum.Material.Concrete,
		westFolder
	)
	createPart(
		"CargoContainerRust",
		Vector3.new(14, 12, 32),
		CFrame.new(-165, 6.2, -52),
		Color3.fromRGB(132, 48, 38),
		Enum.Material.CorrodedMetal,
		westFolder
	)
	createPart(
		"CargoContainerNavy",
		Vector3.new(14, 12, 32),
		CFrame.new(-224, 6.2, 8),
		Color3.fromRGB(36, 62, 98),
		Enum.Material.Metal,
		westFolder
	)
	createPart(
		"CargoContainerGreen",
		Vector3.new(14, 12, 32),
		CFrame.new(-165, 6.2, 68),
		Color3.fromRGB(42, 78, 54),
		Enum.Material.Metal,
		westFolder
	)
	buildStreetlamp(westFolder, Vector3.new(-122, 0.2, -38), Color3.fromRGB(255, 215, 140))
	buildStreetlamp(westFolder, Vector3.new(-122, 0.2, 54), Color3.fromRGB(255, 215, 140))
	buildStreetlamp(westFolder, Vector3.new(-210, 0.2, -38), Color3.fromRGB(255, 215, 140))
	buildStreetlamp(westFolder, Vector3.new(-210, 0.2, 54), Color3.fromRGB(255, 215, 140))

	-- EAST SECTOR: Turnstile & Subway Concourse (Lv. 9, X = 115..235)
	local eastFolder = Instance.new("Folder")
	eastFolder.Name = "EastSector_TurnstileConcourse"
	eastFolder.Parent = worldMap

	createPart(
		"EastConcourseDeck",
		Vector3.new(130, 0.25, 140),
		CFrame.new(170, 0.12, 10),
		Color3.fromRGB(50, 54, 62),
		Enum.Material.Slate,
		eastFolder
	)
	for zIdx = -2, 2 do
		createPart(
			"TicketGate_" .. tostring(zIdx),
			Vector3.new(6, 4.0, 1.4),
			CFrame.new(118, 2.2, 10 + zIdx * 12),
			Color3.fromRGB(64, 70, 82),
			Enum.Material.Metal,
			eastFolder
		)
	end
	buildStreetlamp(eastFolder, Vector3.new(124, 0.2, -38), Color3.fromRGB(215, 235, 255))
	buildStreetlamp(eastFolder, Vector3.new(124, 0.2, 54), Color3.fromRGB(215, 235, 255))
	buildStreetlamp(eastFolder, Vector3.new(208, 0.2, -38), Color3.fromRGB(215, 235, 255))
	buildStreetlamp(eastFolder, Vector3.new(208, 0.2, 54), Color3.fromRGB(215, 235, 255))

	-- NORTH SECTOR: Rail Depot Boss Arena (Lv. 10 Raid Boss PlatformBaron, Z = -245..-150)
	local northFolder = Instance.new("Folder")
	northFolder.Name = "NorthSector_RaidBossDepot"
	northFolder.Parent = worldMap

	createPart(
		"BaronDepotPlaza",
		Vector3.new(136, 0.4, 96),
		CFrame.new(0, 0.2, -196),
		Color3.fromRGB(54, 42, 44),
		Enum.Material.Slate,
		northFolder
	)
	local turntableRing = createPart(
		"DepotTurntable",
		Vector3.new(0.55, 48, 48),
		CFrame.new(0, 0.28, -195) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(68, 52, 54),
		Enum.Material.Metal,
		northFolder
	)
	turntableRing.Shape = Enum.PartType.Cylinder

	buildTrainCarModel(
		northFolder,
		Vector3.new(0, 0.5, -234),
		Color3.fromRGB(95, 24, 28),
		Color3.fromRGB(235, 190, 65),
		true
	)

	buildStreetlamp(northFolder, Vector3.new(-46, 0.4, -162), Color3.fromRGB(255, 110, 85))
	buildStreetlamp(northFolder, Vector3.new(46, 0.4, -162), Color3.fromRGB(255, 110, 85))
	buildStreetlamp(northFolder, Vector3.new(-46, 0.4, -222), Color3.fromRGB(255, 110, 85))
	buildStreetlamp(northFolder, Vector3.new(46, 0.4, -222), Color3.fromRGB(255, 110, 85))

	-- =====================================================================
	-- 4. PERIMETER CITY SKYLINE BUILDINGS (Framing the 600x600 District)
	-- =====================================================================
	local skylineFolder = Instance.new("Folder")
	skylineFolder.Name = "CitySkylineBuildings"
	skylineFolder.Parent = worldMap

	buildCitySkylineBuilding(
		skylineFolder,
		"GrandHotelSouthWest",
		Vector3.new(-125, 0, 225),
		Vector3.new(75, 58, 42),
		Color3.fromRGB(92, 76, 68),
		Enum.Material.Brick,
		Color3.fromRGB(255, 225, 160),
		"HOTEL METROPOL"
	)
	buildCitySkylineBuilding(
		skylineFolder,
		"TransitTowerSouthEast",
		Vector3.new(125, 0, 225),
		Vector3.new(75, 68, 42),
		Color3.fromRGB(58, 66, 78),
		Enum.Material.Concrete,
		Color3.fromRGB(175, 225, 255),
		"MEGAPOLIS CORP"
	)
	buildCitySkylineBuilding(
		skylineFolder,
		"LogisticsWarehouseWest",
		Vector3.new(-265, 0, 10),
		Vector3.new(44, 38, 150),
		Color3.fromRGB(104, 58, 48),
		Enum.Material.Brick,
		Color3.fromRGB(255, 210, 135),
		"CARGO TERMINAL 4"
	)
	buildCitySkylineBuilding(
		skylineFolder,
		"ConcourseHallEast",
		Vector3.new(265, 0, 10),
		Vector3.new(44, 44, 150),
		Color3.fromRGB(64, 70, 82),
		Enum.Material.Concrete,
		Color3.fromRGB(165, 230, 255),
		"EAST EXPRESS LINE"
	)
	buildCitySkylineBuilding(
		skylineFolder,
		"RailDepotBuildingNorth",
		Vector3.new(0, 0, -272),
		Vector3.new(160, 42, 38),
		Color3.fromRGB(82, 48, 44),
		Enum.Material.Brick,
		Color3.fromRGB(255, 145, 95),
		"CENTRAL RAIL DEPOT"
	)

	-- =====================================================================
	-- 5. INTERACTIVE 3D NPCs ON THE PLAZA (Spaced 52+ studs apart!)
	-- =====================================================================
	buildNpcHumanoidModel(
		npcsFolder,
		"NPC_Merchant",
		Vector3.new(-50, 0.4, 18),
		Vector3.new(0, 0.4, 18),
		"Торговец Маркус / Merchant Marcus",
		"[NPC • Экспресс-Киоск / Shop]",
		Color3.fromRGB(24, 95, 130),
		Color3.fromRGB(28, 36, 48),
		Color3.fromRGB(0, 225, 255),
		"Workshop",
		"Киоск и Магазин / Open Shop"
	)

	buildNpcHumanoidModel(
		npcsFolder,
		"NPC_Blacksmith",
		Vector3.new(50, 0.4, 18),
		Vector3.new(0, 0.4, 18),
		"Мастер Заточки Гром / Blacksmith Grom",
		"[NPC • Мастерская Заточки / Enchant]",
		Color3.fromRGB(135, 58, 28),
		Color3.fromRGB(38, 30, 26),
		Color3.fromRGB(255, 165, 45),
		"Workshop",
		"Заточка Оружия / Enchant Weapon"
	)

	buildNpcHumanoidModel(
		npcsFolder,
		"NPC_JobMaster",
		Vector3.new(0, 0.4, -22),
		Vector3.new(0, 0.4, 16),
		"Инспектор Профессий / Career Inspector",
		"[NPC • Профессии и Саб-класс / Job]",
		Color3.fromRGB(48, 56, 125),
		Color3.fromRGB(26, 30, 48),
		Color3.fromRGB(255, 215, 75),
		"Job",
		"Профессии и Саб-класс / Job Dossier"
	)

	-- 2 Elite Station Guards at the South Plaza Gate & North Platform Crossing
	local guardNorth = buildNpcHumanoidModel(
		npcsFolder,
		"NPC_Guard_North",
		Vector3.new(-16, 0.4, -60),
		Vector3.new(-16, 0.4, -110),
		"Страж Перрона / Station Guard",
		"[NPC • Охрана Вокзала / Safe Zone Guard]",
		Color3.fromRGB(26, 44, 86),
		Color3.fromRGB(20, 26, 42),
		Color3.fromRGB(195, 170, 85),
		nil,
		nil
	)
	guardNorth:SetAttribute("NpcType", "Guard")
	guardNorth:SetAttribute("GuardHomePos", Vector3.new(-16, 3.4, -60))
	guardNorth:SetAttribute("GuardLookPos", Vector3.new(-16, 3.4, -110))
	createPart(
		"GuardHalberdNorth",
		Vector3.new(0.32, 7.5, 0.32),
		CFrame.new(-14.2, 4.2, -60.5),
		Color3.fromRGB(185, 195, 210),
		Enum.Material.Metal,
		guardNorth,
		false
	)

	local guardSouth = buildNpcHumanoidModel(
		npcsFolder,
		"NPC_Guard_South",
		Vector3.new(16, 0.4, 80),
		Vector3.new(16, 0.4, 130),
		"Страж Перрона / Station Guard",
		"[NPC • Охрана Вокзала / Safe Zone Guard]",
		Color3.fromRGB(26, 44, 86),
		Color3.fromRGB(20, 26, 42),
		Color3.fromRGB(195, 170, 85),
		nil,
		nil
	)
	guardSouth:SetAttribute("NpcType", "Guard")
	guardSouth:SetAttribute("GuardHomePos", Vector3.new(16, 3.4, 80))
	guardSouth:SetAttribute("GuardLookPos", Vector3.new(16, 3.4, 130))
	createPart(
		"GuardHalberdSouth",
		Vector3.new(0.32, 7.5, 0.32),
		CFrame.new(17.8, 4.2, 80.5),
		Color3.fromRGB(185, 195, 210),
		Enum.Material.Metal,
		guardSouth,
		false
	)

	-- Handle Click-to-Move Walk-Up NPC Interaction
	Remotes.RequestNpcInteract.OnServerEvent:Connect(function(player: Player, npcModelArg: any)
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
