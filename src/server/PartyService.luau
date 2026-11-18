--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("configs")
local MobsConfig = require(Configs:WaitForChild("MobsConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

export type PartyMemberClientPayload = {
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

export type PartyMemberEntry = {
	isBot: boolean,
	player: Player?,
	botModel: Model?,
	ownerPlayer: Player?,
	name: string,
	classId: string,
	level: number,
}

export type PartyGroup = {
	id: number,
	leader: Player,
	members: { PartyMemberEntry },
}

type PendingInvite = {
	leader: Player,
	expiresAt: number,
}

local MAX_PARTY_SIZE = 5
local DEFAULT_PARTY_RADIUS = 85

local PartyService = {}

local partiesByPlayer: { [Player]: PartyGroup } = {}
local pendingInvites: { [Player]: PendingInvite } = {}
local nextPartyId = 1
local initialized = false
local botInviteHandler: ((inviter: Player, targetArg: any) -> boolean)? = nil

function PartyService.SetBotInviteHandler(handler: (inviter: Player, targetArg: any) -> boolean)
	botInviteHandler = handler
end

local function sendChat(player: Player, i18nKey: string, params: { [string]: any }?, r: number, g: number, b: number)
	Remotes.SendChatMessage:FireClient(player, i18nKey, params or {}, { r, g, b })
end

local function getModelRootPart(model: Model?): BasePart?
	if not model or not model.Parent then
		return nil
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso
	end
	return model:FindFirstChildWhichIsA("BasePart")
end

local function isMobModelOrName(model: Model?, nameStr: string?): boolean
	if model then
		if model:GetAttribute("IsMob") == true or model:GetAttribute("MobId") ~= nil or MobsConfig[model.Name] ~= nil then
			return true
		end
	end
	if nameStr and #nameStr > 0 then
		if MobsConfig[nameStr] ~= nil then
			return true
		end
		local lower = string.lower(string.gsub(nameStr, "^%s*(.-)%s*$", "%1"))
		for mobId, mobData in pairs(MobsConfig) do
			if string.lower(mobId) == lower or string.lower(mobData.nameKey) == lower then
				return true
			end
		end
	end
	return false
end

local function pruneInvalidMembers(party: PartyGroup)
	for idx = #party.members, 1, -1 do
		local m = party.members[idx]
		if m.isBot then
			if
				not m.botModel
				or not m.botModel.Parent
				or m.botModel:GetAttribute("IsPartyBot") ~= true
				or isMobModelOrName(m.botModel, m.name)
			then
				table.remove(party.members, idx)
			end
		else
			if not m.player or m.player.Parent ~= Players then
				table.remove(party.members, idx)
			end
		end
	end
end

function PartyService.BuildPartyPayload(party: PartyGroup, excludePlayer: Player?): { PartyMemberClientPayload }
	pruneInvalidMembers(party)
	local list: { PartyMemberClientPayload } = {}
	if #party.members < 2 then
		return list
	end

	for _, m in ipairs(party.members) do
		if m.isBot then
			local bot = m.botModel
			if bot and bot.Parent then
				local lv = (bot:GetAttribute("Level") :: number?) or m.level
				local cId = (bot:GetAttribute("ClassId") :: string?) or m.classId
				local hp = math.max(0, math.floor(((bot:GetAttribute("CurrentHP") :: number?) or 200) + 0.5))
				local maxHp = math.max(1, math.floor(((bot:GetAttribute("MaxHP") :: number?) or 200) + 0.5))
				local mp = math.max(0, math.floor(((bot:GetAttribute("MP") :: number?) or 120) + 0.5))
				local maxMp = math.max(1, math.floor(((bot:GetAttribute("MaxMP") :: number?) or 120) + 0.5))
				local dName = (bot:GetAttribute("BotDisplayName") :: string?) or m.name

				table.insert(list, {
					name = dName,
					classId = cId,
					level = lv,
					hp = hp,
					maxHp = maxHp,
					mp = mp,
					maxMp = maxMp,
					isLeader = false,
					isBot = true,
					model = bot,
				})
			end
		elseif m.player and m.player.Parent == Players and m.player ~= excludePlayer then
			local plr = m.player
			local char = plr.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			local lv = (plr:GetAttribute("Level") :: number?) or m.level
			local cId = (plr:GetAttribute("ClassId") :: string?) or m.classId
			local maxHp = if hum then math.max(1, math.floor(hum.MaxHealth + 0.5)) else 180
			local hp = if hum then math.max(0, math.floor(hum.Health + 0.5)) else maxHp
			local maxMp = math.max(1, (plr:GetAttribute("MaxMP") :: number?) or 100)
			local mp = math.clamp((plr:GetAttribute("MP") :: number?) or maxMp, 0, maxMp)

			table.insert(list, {
				name = plr.DisplayName,
				classId = cId,
				level = lv,
				hp = hp,
				maxHp = maxHp,
				mp = mp,
				maxMp = maxMp,
				isLeader = (party.leader == plr),
				isBot = false,
				model = char,
			})
		end
	end

	return list
end

function PartyService.BroadcastParty(party: PartyGroup)
	pruneInvalidMembers(party)

	-- If fewer than 2 members remain (or no real players remain), dissolve the party
	local realPlayers: { Player } = {}
	for _, m in ipairs(party.members) do
		if not m.isBot and m.player and m.player.Parent == Players then
			table.insert(realPlayers, m.player)
		end
	end

	if #party.members < 2 or #realPlayers == 0 then
		for _, plr in ipairs(realPlayers) do
			if partiesByPlayer[plr] == party then
				partiesByPlayer[plr] = nil
			end
			Remotes.PartyUpdated:FireClient(plr, {})
		end
		table.clear(party.members)
		return
	end

	-- Ensure leader is valid
	if not party.leader or party.leader.Parent ~= Players or partiesByPlayer[party.leader] ~= party then
		party.leader = realPlayers[1]
	end

	for _, plr in ipairs(realPlayers) do
		local payload = PartyService.BuildPartyPayload(party, plr)
		Remotes.PartyUpdated:FireClient(plr, payload)
	end
end

function PartyService.GetParty(player: Player): PartyGroup?
	return partiesByPlayer[player]
end

function PartyService.SyncPlayerParty(player: Player)
	local party = partiesByPlayer[player]
	if party then
		PartyService.BroadcastParty(party)
	else
		Remotes.PartyUpdated:FireClient(player, {})
	end
end

local function getOrCreatePartyForLeader(leader: Player): PartyGroup
	local existing = partiesByPlayer[leader]
	if existing then
		return existing
	end

	local partyId = nextPartyId
	nextPartyId += 1

	local newParty: PartyGroup = {
		id = partyId,
		leader = leader,
		members = {
			{
				isBot = false,
				player = leader,
				botModel = nil,
				ownerPlayer = nil,
				name = leader.DisplayName,
				classId = (leader:GetAttribute("ClassId") :: string?) or "RiotPolice",
				level = (leader:GetAttribute("Level") :: number?) or 1,
			},
		},
	}
	partiesByPlayer[leader] = newParty
	return newParty
end

function PartyService.AddBotCompanion(
	leader: Player,
	botModel: Model,
	displayName: string,
	classId: string,
	level: number
): boolean
	if not botModel or botModel:GetAttribute("IsPartyBot") ~= true or isMobModelOrName(botModel, displayName) then
		return false
	end

	local party = getOrCreatePartyForLeader(leader)
	pruneInvalidMembers(party)

	if #party.members >= MAX_PARTY_SIZE then
		sendChat(leader, "LOG_PARTY_FULL", {}, 255, 110, 110)
		return false
	end

	table.insert(party.members, {
		isBot = true,
		player = nil,
		botModel = botModel,
		ownerPlayer = leader,
		name = displayName,
		classId = classId,
		level = level,
	})

	PartyService.BroadcastParty(party)
	return true
end

function PartyService.RemoveBotsForPlayer(player: Player)
	local party = partiesByPlayer[player]
	if not party then
		return
	end

	for idx = #party.members, 1, -1 do
		local m = party.members[idx]
		if m.isBot and (m.ownerPlayer == player or party.leader == player) then
			if m.botModel and m.botModel.Parent then
				m.botModel:Destroy()
			end
			table.remove(party.members, idx)
		end
	end

	PartyService.BroadcastParty(party)
end

function PartyService.LeaveParty(player: Player)
	local party = partiesByPlayer[player]
	if not party then
		Remotes.PartyUpdated:FireClient(player, {})
		return
	end

	partiesByPlayer[player] = nil

	for idx = #party.members, 1, -1 do
		local m = party.members[idx]
		if m.player == player then
			table.remove(party.members, idx)
		elseif m.isBot and m.ownerPlayer == player then
			if m.botModel and m.botModel.Parent then
				m.botModel:Destroy()
			end
			table.remove(party.members, idx)
		end
	end

	Remotes.PartyUpdated:FireClient(player, {})
	sendChat(player, "LOG_PARTY_LEFT", {}, 215, 200, 140)
	PartyService.BroadcastParty(party)
end

local function findPlayerByNameQuery(inviter: Player, query: string): Player?
	local clean = string.lower(string.gsub(query, "^%s*(.-)%s*$", "%1"))
	if #clean == 0 then
		return nil
	end

	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= inviter then
			local uName = string.lower(candidate.Name)
			local dName = string.lower(candidate.DisplayName)
			if uName == clean or dName == clean or string.find(uName, clean, 1, true) == 1 or string.find(dName, clean, 1, true) == 1 then
				return candidate
			end
		end
	end
	return nil
end

function PartyService.InvitePlayer(inviter: Player, targetArg: any)
	local party = partiesByPlayer[inviter]
	if party then
		pruneInvalidMembers(party)
		if #party.members >= MAX_PARTY_SIZE then
			sendChat(inviter, "LOG_PARTY_FULL", {}, 255, 110, 110)
			return
		end
	end

	if typeof(targetArg) == "Instance" and targetArg:IsA("Model") then
		if isMobModelOrName(targetArg, targetArg.Name) then
			sendChat(inviter, "LOG_PARTY_TARGET_NOT_FOUND", { target = targetArg.Name }, 255, 140, 110)
			return
		end
		local modelPlr = Players:GetPlayerFromCharacter(targetArg)
		if modelPlr and modelPlr ~= inviter then
			if partiesByPlayer[modelPlr] ~= nil then
				sendChat(inviter, "LOG_PARTY_TARGET_NOT_FOUND", { target = modelPlr.DisplayName }, 255, 140, 110)
				return
			end
			pendingInvites[modelPlr] = {
				leader = inviter,
				expiresAt = os.clock() + 30,
			}
			sendChat(inviter, "LOG_PARTY_INVITE_SENT", { target = modelPlr.DisplayName }, 120, 235, 255)
			Remotes.PartyInviteReceived:FireClient(modelPlr, inviter.DisplayName)
			return
		elseif
			(targetArg:GetAttribute("IsPartyBot") == true or targetArg:GetAttribute("IsPvpTarget") == true)
			and botInviteHandler
			and botInviteHandler(inviter, targetArg)
		then
			return
		end
		sendChat(inviter, "LOG_PARTY_TARGET_NOT_FOUND", { target = targetArg.Name }, 255, 140, 110)
		return
	end

	local targetName = if type(targetArg) == "string" then targetArg else ""
	if isMobModelOrName(nil, targetName) then
		sendChat(inviter, "LOG_PARTY_TARGET_NOT_FOUND", { target = targetName }, 255, 140, 110)
		return
	end

	local targetPlayer = findPlayerByNameQuery(inviter, targetName)
	if not targetPlayer then
		if botInviteHandler and botInviteHandler(inviter, targetName) then
			return
		end
		sendChat(inviter, "LOG_PARTY_TARGET_NOT_FOUND", { target = if #targetName > 0 then targetName else "Target" }, 255, 140, 110)
		return
	end

	if partiesByPlayer[targetPlayer] ~= nil then
		sendChat(inviter, "LOG_PARTY_TARGET_NOT_FOUND", { target = targetPlayer.DisplayName }, 255, 140, 110)
		return
	end

	pendingInvites[targetPlayer] = {
		leader = inviter,
		expiresAt = os.clock() + 30,
	}

	sendChat(inviter, "LOG_PARTY_INVITE_SENT", { target = targetPlayer.DisplayName }, 120, 235, 255)
	Remotes.PartyInviteReceived:FireClient(targetPlayer, inviter.DisplayName)
end

function PartyService.RespondToInvite(player: Player, accept: boolean)
	local invite = pendingInvites[player]
	pendingInvites[player] = nil
	if not invite or not accept then
		return
	end

	if os.clock() > invite.expiresAt then
		return
	end

	local leader = invite.leader
	if not leader or leader.Parent ~= Players then
		return
	end

	if partiesByPlayer[player] ~= nil then
		return
	end

	local party = getOrCreatePartyForLeader(leader)
	pruneInvalidMembers(party)
	if #party.members >= MAX_PARTY_SIZE then
		sendChat(player, "LOG_PARTY_FULL", {}, 255, 110, 110)
		return
	end

	table.insert(party.members, {
		isBot = false,
		player = player,
		botModel = nil,
		ownerPlayer = nil,
		name = player.DisplayName,
		classId = (player:GetAttribute("ClassId") :: string?) or "RiotPolice",
		level = (player:GetAttribute("Level") :: number?) or 1,
	})
	partiesByPlayer[player] = party

	for _, m in ipairs(party.members) do
		if not m.isBot and m.player and m.player.Parent == Players then
			sendChat(m.player, "LOG_PARTY_JOINED", { member = player.DisplayName }, 115, 255, 160)
		end
	end

	PartyService.BroadcastParty(party)
end

function PartyService.GetNearbyPartyMembers(
	killer: Player,
	originPos: Vector3,
	maxRadius: number?
): ({ Player }, number)
	local radius = maxRadius or DEFAULT_PARTY_RADIUS
	local party = partiesByPlayer[killer]
	if not party then
		return { killer }, 1
	end

	pruneInvalidMembers(party)
	if #party.members < 2 then
		return { killer }, 1
	end

	local nearbyRealPlayers: { Player } = {}
	local totalNearbyCount = 0
	local killerIncluded = false

	for _, m in ipairs(party.members) do
		if m.isBot then
			local bot = m.botModel
			local hp = if bot then ((bot:GetAttribute("CurrentHP") :: number?) or 0) else 0
			local root = getModelRootPart(bot)
			if bot and hp > 0 and root then
				local dist = ((root.Position - originPos) * Vector3.new(1, 0, 1)).Magnitude
				if dist <= radius then
					totalNearbyCount += 1
				end
			end
		elseif m.player and m.player.Parent == Players then
			local plr = m.player
			if plr == killer then
				table.insert(nearbyRealPlayers, plr)
				totalNearbyCount += 1
				killerIncluded = true
			else
				local char = plr.Character
				local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
				local root = getModelRootPart(char)
				if hum and hum.Health > 0 and root then
					local dist = ((root.Position - originPos) * Vector3.new(1, 0, 1)).Magnitude
					if dist <= radius then
						table.insert(nearbyRealPlayers, plr)
						totalNearbyCount += 1
					end
				end
			end
		end
	end

	if not killerIncluded then
		table.insert(nearbyRealPlayers, 1, killer)
		totalNearbyCount += 1
	end

	return nearbyRealPlayers, totalNearbyCount
end

function PartyService.GetNearbyPartyEntities(
	caster: Player,
	originPos: Vector3,
	maxRadius: number?
): ({ Player }, { Model })
	local radius = maxRadius or DEFAULT_PARTY_RADIUS
	local party = partiesByPlayer[caster]
	if not party then
		return { caster }, {}
	end

	pruneInvalidMembers(party)
	if #party.members < 2 then
		return { caster }, {}
	end

	local nearbyPlayers: { Player } = {}
	local nearbyBots: { Model } = {}
	local casterIncluded = false

	for _, m in ipairs(party.members) do
		if m.isBot then
			local bot = m.botModel
			local hp = if bot then ((bot:GetAttribute("CurrentHP") :: number?) or 0) else 0
			local root = getModelRootPart(bot)
			if bot and bot.Parent and hp > 0 and root then
				local dist = ((root.Position - originPos) * Vector3.new(1, 0, 1)).Magnitude
				if dist <= radius then
					table.insert(nearbyBots, bot)
				end
			end
		elseif m.player and m.player.Parent == Players then
			local plr = m.player
			if plr == caster then
				table.insert(nearbyPlayers, plr)
				casterIncluded = true
			else
				local char = plr.Character
				local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
				local root = getModelRootPart(char)
				if hum and hum.Health > 0 and root then
					local dist = ((root.Position - originPos) * Vector3.new(1, 0, 1)).Magnitude
					if dist <= radius then
						table.insert(nearbyPlayers, plr)
					end
				end
			end
		end
	end

	if not casterIncluded then
		table.insert(nearbyPlayers, 1, caster)
	end

	return nearbyPlayers, nearbyBots
end

function PartyService.IsFriendlyPartyTarget(caster: Player, targetModel: Model?): (boolean, Player?, Model?)
	if not targetModel or not targetModel.Parent then
		return false, nil, nil
	end
	if caster.Character and targetModel == caster.Character then
		return true, caster, targetModel
	end
	if targetModel:GetAttribute("IsPartyBot") == true then
		local hp = (targetModel:GetAttribute("CurrentHP") :: number?) or 0
		if hp > 0 then
			return true, nil, targetModel
		end
	end
	local targetPlr = Players:GetPlayerFromCharacter(targetModel)
	if targetPlr and targetPlr.Parent == Players then
		local party = partiesByPlayer[caster]
		if party and partiesByPlayer[targetPlr] == party then
			return true, targetPlr, targetModel
		end
	end
	return false, nil, nil
end

function PartyService.Init()
	if initialized then
		return
	end
	initialized = true

	Remotes.PartyInvite.OnServerEvent:Connect(function(player: Player, targetArg: any)
		if type(targetArg) == "string" or (typeof(targetArg) == "Instance" and targetArg:IsA("Model")) then
			PartyService.InvitePlayer(player, targetArg)
		end
	end)

	Remotes.PartyRespond.OnServerEvent:Connect(function(player: Player, accept: any)
		PartyService.RespondToInvite(player, accept == true)
	end)

	Remotes.PartyLeave.OnServerEvent:Connect(function(player: Player)
		PartyService.LeaveParty(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		pendingInvites[player] = nil
		PartyService.LeaveParty(player)
	end)

	-- Periodic live HP/MP sync for all active parties
	task.spawn(function()
		while true do
			task.wait(0.5)
			local visited: { [PartyGroup]: boolean } = {}
			for _, party in pairs(partiesByPlayer) do
				if not visited[party] then
					visited[party] = true
					PartyService.BroadcastParty(party)
				end
			end
		end
	end)
end

return PartyService
