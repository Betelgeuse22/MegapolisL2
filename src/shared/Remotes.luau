--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local REMOTE_NAMES = {
	"RequestAttack",
	"UseSkill",
	"SelectTarget",
	"ToggleSoulshot",
	"ToggleAutoSoulshot",
	"RequestEnchantWeapon",
	"BuyShopItem",
	"EnchantResultFeedback",
	"CombatHitFeedback",
	"PlayerStatsUpdated",
	"ChangeClassOrRace",
	"SkillVFX",
	"CreateCharacter",
	"UnlockOrSwitchSubclass",
	"ProfileUpdated",
	"SendChatMessage",
	"MobAttackedPlayer",
	"UsePotion",
	"PotionVFX",
	"EquipItem",
	"UnequipItem",
	"SellBagItem",
	"SwapBagItems",
	"LootDropVFX",
	"OpenNpcWindow",
	"RequestNpcInteract",
	"PartyInvite",
	"PartyInviteReceived",
	"PartyRespond",
	"PartyLeave",
	"PartyUpdated",
	"RequestUBahnTeleport",
}

local function getOrCreateRemotesFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	else
		return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
end

local function getOrCreateRemoteEvent(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

local remotesFolder = getOrCreateRemotesFolder()

for _, remoteName in ipairs(REMOTE_NAMES) do
	getOrCreateRemoteEvent(remotesFolder, remoteName)
end

local Remotes = {
	Folder = remotesFolder,
	RequestAttack = getOrCreateRemoteEvent(remotesFolder, "RequestAttack"),
	UseSkill = getOrCreateRemoteEvent(remotesFolder, "UseSkill"),
	SelectTarget = getOrCreateRemoteEvent(remotesFolder, "SelectTarget"),
	ToggleSoulshot = getOrCreateRemoteEvent(remotesFolder, "ToggleSoulshot"),
	ToggleAutoSoulshot = getOrCreateRemoteEvent(remotesFolder, "ToggleAutoSoulshot"),
	RequestEnchantWeapon = getOrCreateRemoteEvent(remotesFolder, "RequestEnchantWeapon"),
	BuyShopItem = getOrCreateRemoteEvent(remotesFolder, "BuyShopItem"),
	EnchantResultFeedback = getOrCreateRemoteEvent(remotesFolder, "EnchantResultFeedback"),
	CombatHitFeedback = getOrCreateRemoteEvent(remotesFolder, "CombatHitFeedback"),
	PlayerStatsUpdated = getOrCreateRemoteEvent(remotesFolder, "PlayerStatsUpdated"),
	ChangeClassOrRace = getOrCreateRemoteEvent(remotesFolder, "ChangeClassOrRace"),
	SkillVFX = getOrCreateRemoteEvent(remotesFolder, "SkillVFX"),
	CreateCharacter = getOrCreateRemoteEvent(remotesFolder, "CreateCharacter"),
	UnlockOrSwitchSubclass = getOrCreateRemoteEvent(remotesFolder, "UnlockOrSwitchSubclass"),
	ProfileUpdated = getOrCreateRemoteEvent(remotesFolder, "ProfileUpdated"),
	SendChatMessage = getOrCreateRemoteEvent(remotesFolder, "SendChatMessage"),
	MobAttackedPlayer = getOrCreateRemoteEvent(remotesFolder, "MobAttackedPlayer"),
	UsePotion = getOrCreateRemoteEvent(remotesFolder, "UsePotion"),
	PotionVFX = getOrCreateRemoteEvent(remotesFolder, "PotionVFX"),
	EquipItem = getOrCreateRemoteEvent(remotesFolder, "EquipItem"),
	UnequipItem = getOrCreateRemoteEvent(remotesFolder, "UnequipItem"),
	SellBagItem = getOrCreateRemoteEvent(remotesFolder, "SellBagItem"),
	SwapBagItems = getOrCreateRemoteEvent(remotesFolder, "SwapBagItems"),
	LootDropVFX = getOrCreateRemoteEvent(remotesFolder, "LootDropVFX"),
	OpenNpcWindow = getOrCreateRemoteEvent(remotesFolder, "OpenNpcWindow"),
	RequestNpcInteract = getOrCreateRemoteEvent(remotesFolder, "RequestNpcInteract"),
	PartyInvite = getOrCreateRemoteEvent(remotesFolder, "PartyInvite"),
	PartyInviteReceived = getOrCreateRemoteEvent(remotesFolder, "PartyInviteReceived"),
	PartyRespond = getOrCreateRemoteEvent(remotesFolder, "PartyRespond"),
	PartyLeave = getOrCreateRemoteEvent(remotesFolder, "PartyLeave"),
	PartyUpdated = getOrCreateRemoteEvent(remotesFolder, "PartyUpdated"),
	RequestUBahnTeleport = getOrCreateRemoteEvent(remotesFolder, "RequestUBahnTeleport"),
}

return Remotes
