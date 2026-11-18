--!strict

export type DropEntry = {
	itemId: string,
	minQty: number,
	maxQty: number,
	chance: number, -- 0.0 to 1.0
}

export type LootTableEntry = {
	itemId: string,
	chance: number, -- 0.0 to 1.0
	minQty: number?,
	maxQty: number?,
}

export type MobData = {
	id: string,
	nameKey: string,
	locationId: string,
	level: number,
	maxHp: number,
	pDef: number,
	mDef: number,
	atk: number,
	isAggressive: boolean,
	isSocial: boolean,
	aggroRange: number,
	respawnTime: number,
	expReward: number,
	cashReward: number,
	isRaidBoss: boolean?,
	dropList: { DropEntry },
	spoilList: { DropEntry },
	lootTable: { LootTableEntry }?,
}

local MobsConfig: { [string]: MobData } = {
	SleepingCommuter = {
		id = "SleepingCommuter",
		nameKey = "MOB_SLEEPING_COMMUTER",
		locationId = "LOC_CENTRAL_STATION",
		level = 1,
		maxHp = 80,
		pDef = 12,
		mDef = 10,
		atk = 8,
		isAggressive = false,
		isSocial = false,
		aggroRange = 0,
		respawnTime = 8,
		expReward = 25,
		cashReward = 15,
		isRaidBoss = false,
		dropList = {
			{ itemId = "CrumpledTicket", minQty = 1, maxQty = 2, chance = 0.70 },
			{ itemId = "PlasticBottle", minQty = 1, maxQty = 1, chance = 0.35 },
		},
		spoilList = {
			{ itemId = "CopperWire", minQty = 1, maxQty = 2, chance = 0.65 },
		},
		lootTable = {
			{ itemId = "HpPotions", chance = 0.25, minQty = 1, maxQty = 1 },
			{ itemId = "ARM_RUBBER_BOOTS", chance = 0.15, minQty = 1, maxQty = 1 },
			{ itemId = "ACC_TOKEN_RING", chance = 0.12, minQty = 1, maxQty = 1 },
			{ itemId = "ARM_CARGO_PANTS", chance = 0.10, minQty = 1, maxQty = 1 },
		},
	},

	CanCollector = {
		id = "CanCollector",
		nameKey = "MOB_CAN_COLLECTOR",
		locationId = "LOC_CENTRAL_STATION",
		level = 3,
		maxHp = 150,
		pDef = 20,
		mDef = 16,
		atk = 15,
		isAggressive = false,
		isSocial = true,
		aggroRange = 12,
		respawnTime = 10,
		expReward = 60,
		cashReward = 35,
		isRaidBoss = false,
		dropList = {
			{ itemId = "AluminumCan", minQty = 1, maxQty = 3, chance = 0.75 },
			{ itemId = "TornGloves", minQty = 1, maxQty = 1, chance = 0.15 },
		},
		spoilList = {
			{ itemId = "RecycledMetal", minQty = 1, maxQty = 2, chance = 0.60 },
		},
		lootTable = {
			{ itemId = "EnergyShots", chance = 0.30, minQty = 20, maxQty = 20 },
			{ itemId = "ARM_COMMUTER_JACKET", chance = 0.14, minQty = 1, maxQty = 1 },
			{ itemId = "ACC_METRO_WATCH", chance = 0.12, minQty = 1, maxQty = 1 },
			{ itemId = "MpPotions", chance = 0.20, minQty = 1, maxQty = 1 },
		},
	},

	StationAlchemist = {
		id = "StationAlchemist",
		nameKey = "MOB_STATION_ALCHEMIST",
		locationId = "LOC_CENTRAL_STATION",
		level = 5,
		maxHp = 240,
		pDef = 26,
		mDef = 35,
		atk = 24,
		isAggressive = true,
		isSocial = true,
		aggroRange = 18,
		respawnTime = 12,
		expReward = 110,
		cashReward = 65,
		isRaidBoss = false,
		dropList = {
			{ itemId = "MysteryReagent", minQty = 1, maxQty = 2, chance = 0.55 },
			{ itemId = "GlassVial", minQty = 1, maxQty = 3, chance = 0.65 },
			{ itemId = "CheapStimpack", minQty = 1, maxQty = 1, chance = 0.25 },
		},
		spoilList = {
			{ itemId = "RefinedSolvent", minQty = 1, maxQty = 2, chance = 0.50 },
		},
		lootTable = {
			{ itemId = "ACC_ALCHEMIST_CHAIN", chance = 0.15, minQty = 1, maxQty = 1 },
			{ itemId = "ARM_TACTICAL_PANTS", chance = 0.12, minQty = 1, maxQty = 1 },
			{ itemId = "EnchantScrolls", chance = 0.08, minQty = 1, maxQty = 1 },
			{ itemId = "MpPotions", chance = 0.30, minQty = 2, maxQty = 2 },
		},
	},

	CardboardKnight = {
		id = "CardboardKnight",
		nameKey = "MOB_CARDBOARD_KNIGHT",
		locationId = "LOC_CENTRAL_STATION",
		level = 7,
		maxHp = 400,
		pDef = 55,
		mDef = 30,
		atk = 34,
		isAggressive = false,
		isSocial = true,
		aggroRange = 15,
		respawnTime = 15,
		expReward = 180,
		cashReward = 100,
		isRaidBoss = false,
		dropList = {
			{ itemId = "ReinforcedCardboard", minQty = 1, maxQty = 3, chance = 0.70 },
			{ itemId = "DuctTapeRoll", minQty = 1, maxQty = 2, chance = 0.45 },
			{ itemId = "TrashCanLidShield", minQty = 1, maxQty = 1, chance = 0.08 },
		},
		spoilList = {
			{ itemId = "IndustrialAdhesive", minQty = 1, maxQty = 2, chance = 0.55 },
		},
		lootTable = {
			{ itemId = "ARM_STEEL_BOOTS", chance = 0.15, minQty = 1, maxQty = 1 },
			{ itemId = "ARM_INSPECTOR_VEST", chance = 0.12, minQty = 1, maxQty = 1 },
			{ itemId = "EnchantScrolls", chance = 0.10, minQty = 1, maxQty = 1 },
		},
	},

	TicketInspector = {
		id = "TicketInspector",
		nameKey = "MOB_TICKET_INSPECTOR",
		locationId = "LOC_CENTRAL_STATION",
		level = 9,
		maxHp = 580,
		pDef = 68,
		mDef = 50,
		atk = 48,
		isAggressive = true,
		isSocial = true,
		aggroRange = 22,
		respawnTime = 18,
		expReward = 290,
		cashReward = 160,
		isRaidBoss = false,
		dropList = {
			{ itemId = "ValidatorDevice", minQty = 1, maxQty = 1, chance = 0.30 },
			{ itemId = "InspectorBadge", minQty = 1, maxQty = 1, chance = 0.40 },
			{ itemId = "StunBatonNG", minQty = 1, maxQty = 1, chance = 0.05 },
		},
		spoilList = {
			{ itemId = "LithiumBattery", minQty = 1, maxQty = 2, chance = 0.50 },
		},
		lootTable = {
			{ itemId = "ARM_INSPECTOR_VEST", chance = 0.15, minQty = 1, maxQty = 1 },
			{ itemId = "ACC_ALCHEMIST_CHAIN", chance = 0.15, minQty = 1, maxQty = 1 },
			{ itemId = "EnchantScrolls", chance = 0.15, minQty = 1, maxQty = 1 },
		},
	},

	PlatformBaron = {
		id = "PlatformBaron",
		nameKey = "MOB_PLATFORM_BARON",
		locationId = "LOC_CENTRAL_STATION",
		level = 10,
		maxHp = 6500,
		pDef = 140,
		mDef = 110,
		atk = 125,
		isAggressive = true,
		isSocial = true,
		aggroRange = 30,
		respawnTime = 300,
		expReward = 3500,
		cashReward = 2500,
		isRaidBoss = true,
		dropList = {
			{ itemId = "BaronSignetRing", minQty = 1, maxQty = 1, chance = 0.35 },
			{ itemId = "GoldenTurnstileKey", minQty = 1, maxQty = 1, chance = 0.50 },
			{ itemId = "HeavyCrowbarD", minQty = 1, maxQty = 1, chance = 0.15 },
			{ itemId = "MetroPassBundle", minQty = 3, maxQty = 8, chance = 1.00 },
		},
		spoilList = {
			{ itemId = "HighGradeSteel", minQty = 2, maxQty = 5, chance = 0.85 },
		},
		lootTable = {
			{ itemId = "WPN_BARON_ELITE", chance = 0.50, minQty = 1, maxQty = 1 },
			{ itemId = "ARM_BARON_COAT", chance = 0.50, minQty = 1, maxQty = 1 },
			{ itemId = "ACC_BARON_SIGNET", chance = 0.50, minQty = 1, maxQty = 1 },
			{ itemId = "EnchantScrolls", chance = 1.00, minQty = 3, maxQty = 3 },
		},
	},
}

return MobsConfig
