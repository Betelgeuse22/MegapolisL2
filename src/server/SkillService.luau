--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local MobsConfig = require(Shared:WaitForChild("configs"):WaitForChild("MobsConfig"))

local CombatService = require(script.Parent:WaitForChild("CombatService"))
local MobSpawnerService = require(script.Parent:WaitForChild("MobSpawnerService"))

local SkillService = {}

type DroneRecord = {
	model: Model,
	expireTime: number,
	conn: thread?,
}

local activeDrones: { [Player]: DroneRecord } = {}

local function removeDrone(player: Player)
	local record = activeDrones[player]
	if record then
		if record.model and record.model.Parent then
			record.model:Destroy()
		end
		activeDrones[player] = nil
	end
end

function SkillService.DeployDrone(player: Player, duration: number)
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	removeDrone(player)

	local droneModel = Instance.new("Model")
	droneModel.Name = "CombatDrone"
	droneModel.Parent = character

	local core = Instance.new("Part")
	core.Name = "DroneCore"
	core.Size = Vector3.new(1.2, 0.6, 1.2)
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.fromRGB(30, 36, 48)
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = droneModel
	droneModel.PrimaryPart = core

	local eye = Instance.new("Part")
	eye.Name = "DroneEye"
	eye.Size = Vector3.new(0.4, 0.4, 0.3)
	eye.Material = Enum.Material.Neon
	eye.Color = Color3.fromRGB(0, 240, 255)
	eye.CanCollide = false
	eye.CastShadow = false
	eye.Parent = droneModel

	local eyeWeld = Instance.new("WeldConstraint")
	eyeWeld.Part0 = core
	eyeWeld.Part1 = eye
	eye.CFrame = core.CFrame * CFrame.new(0, 0, -0.6)
	eyeWeld.Parent = core

	-- Thruster neon rings
	local thruster = Instance.new("Part")
	thruster.Name = "DroneThruster"
	thruster.Size = Vector3.new(0.6, 0.2, 0.6)
	thruster.Material = Enum.Material.Neon
	thruster.Color = Color3.fromRGB(0, 215, 255)
	thruster.CanCollide = false
	thruster.CastShadow = false
	thruster.Parent = droneModel

	local thrusterWeld = Instance.new("WeldConstraint")
	thrusterWeld.Part0 = core
	thrusterWeld.Part1 = thruster
	thruster.CFrame = core.CFrame * CFrame.new(0, -0.35, 0)
	thrusterWeld.Parent = core

	local weld = Instance.new("Weld")
	weld.Name = "DroneOffsetWeld"
	weld.Part0 = rootPart
	weld.Part1 = core
	weld.C0 = CFrame.new(2.4, 3.2, 1.6) * CFrame.Angles(0, math.rad(-15), 0)
	weld.Parent = core

	local now = os.clock()
	local expireTime = now + duration

	local loopThread = task.spawn(function()
		while task.wait(1.2) do
			local curRecord = activeDrones[player]
			if not curRecord or os.clock() >= curRecord.expireTime then
				break
			end
			if not player.Character or not player.Character.Parent then
				break
			end
			local pHum = player.Character:FindFirstChildOfClass("Humanoid")
			if not pHum or pHum.Health <= 0 then
				break
			end

			local state = CombatService.GetPlayerState(player)
			if not state or state.ClassId ~= "DroneOperator" then
				break
			end

			-- Find target: preferred SelectedTarget or nearest mob within 36 studs
			local targetMob: Model? = state.SelectedTarget
			if targetMob and not targetMob.Parent then
				targetMob = nil
			end
			if targetMob then
				local mHum = targetMob:FindFirstChildOfClass("Humanoid")
				local curHp = (targetMob:GetAttribute("CurrentHP") :: number?) or (if mHum then mHum.Health else 0)
				if curHp <= 0 then
					targetMob = nil
				end
			end

			if not targetMob then
				local nearestDist = 36
				for mModel, mState in pairs(MobSpawnerService.GetAllActiveMobs()) do
					if not mState.isDead and mModel.Parent then
						local mRoot = MobSpawnerService.GetMobRoot(mModel)
						if mRoot then
							local d = (mRoot.Position - rootPart.Position).Magnitude
							if d <= nearestDist then
								nearestDist = d
								targetMob = mModel
							end
						end
					end
				end
			end

			if targetMob and core and core.Parent then
				local effectiveAtk = CombatService.GetEffectiveAttackStats(player)
				local droneDmg = math.max(12, math.floor(effectiveAtk * 0.65 + 0.5))
				local dealt = CombatService.ApplyDamageToMob(player, targetMob, droneDmg, true, false)

				local mobRoot = MobSpawnerService.GetMobRoot(targetMob)
				if mobRoot then
					Remotes.SkillVFX:FireAllClients("DRONE_LASER_FIRE", player, {
						origin = core.Position,
						targetPosition = mobRoot.Position,
						targetModel = targetMob,
						damage = dealt,
					})
				end
			end
		end

		removeDrone(player)
	end)

	activeDrones[player] = {
		model = droneModel,
		expireTime = expireTime,
		conn = loopThread,
	}
end

function SkillService.Init()
	CombatService.Init()
	CombatService.SetDroneDeployer(SkillService.DeployDrone)

	Players.PlayerRemoving:Connect(function(player: Player)
		removeDrone(player)
	end)
end

return SkillService
