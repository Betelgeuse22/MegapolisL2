--!strict

export type ClassRole =
	"Tank"
	| "Healer"
	| "Bard"
	| "Buffer"
	| "Spoiler"
	| "Crafter"
	| "MeleeDPS"
	| "Dagger"
	| "Destroyer"
	| "Archer"
	| "SiegeGunner"
	| "RangedDPS"
	| "Mage"
	| "Summoner"
	| "Support"

export type ClassData = {
	id: string,
	nameKey: string,
	role: ClassRole,
	isPlayableSprint2: boolean,
	attackRange: number,
	baseHp: number,
	baseMp: number,
	baseAtk: number,
	basePDef: number,
	baseMDef: number,
	critChance: number,
	baseHpBonus: number,
	baseAtkBonus: number,
	weaponType: string,
	skillSlots: { [string]: string }, -- "Q" | "E" | "R" | "F" -> skillId
}

local ClassesConfig: { [string]: ClassData } = {
	-- 1) RiotPolice (Tank, range 8)
	RiotPolice = {
		id = "RiotPolice",
		nameKey = "CLASS_RIOT_POLICE",
		role = "Tank",
		isPlayableSprint2 = true,
		attackRange = 8,
		baseHp = 220,
		baseMp = 100,
		baseAtk = 28,
		basePDef = 48,
		baseMDef = 28,
		critChance = 0.12,
		baseHpBonus = 80,
		baseAtkBonus = 0,
		weaponType = "PoliceBaton",
		skillSlots = {
			Q = "SKILL_BATON_STUN",
			E = "SKILL_MEGAPHONE_AGGRO",
			R = "SKILL_WATER_CANNON",
			F = "SKILL_RIOT_SHIELD",
		},
	},

	-- 2) Paramedic (Healer / Mana Recharger, range 36)
	Paramedic = {
		id = "Paramedic",
		nameKey = "CLASS_PARAMEDIC",
		role = "Healer",
		isPlayableSprint2 = true,
		attackRange = 36,
		baseHp = 155,
		baseMp = 180,
		baseAtk = 24,
		basePDef = 26,
		baseMDef = 38,
		critChance = 0.14,
		baseHpBonus = 30,
		baseAtkBonus = 4,
		weaponType = "Defibrillator",
		skillSlots = {
			Q = "SKILL_INSTANT_HEAL",
			E = "SKILL_MANA_RECHARGE",
			R = "SKILL_DEFIBRILLATOR",
			F = "SKILL_SANITARY_DOME",
		},
	},

	-- 3) SubwayRocker (Bard BD/SWS, range 8)
	SubwayRocker = {
		id = "SubwayRocker",
		nameKey = "CLASS_SUBWAY_ROCKER",
		role = "Bard",
		isPlayableSprint2 = true,
		attackRange = 8,
		baseHp = 175,
		baseMp = 140,
		baseAtk = 32,
		basePDef = 32,
		baseMDef = 30,
		critChance = 0.18,
		baseHpBonus = 45,
		baseAtkBonus = 6,
		weaponType = "ElectricGuitar",
		skillSlots = {
			Q = "SKILL_POWER_CHORD",
			E = "SKILL_SONG_SUBWAY_WIND",
			R = "SKILL_DANCE_OVERDRIVE",
			F = "SKILL_SHREDDING_SOLO",
		},
	},

	-- 4) UnionBoss (Party Buffer / Debuffer, range 25)
	UnionBoss = {
		id = "UnionBoss",
		nameKey = "CLASS_UNION_BOSS",
		role = "Buffer",
		isPlayableSprint2 = true,
		attackRange = 25,
		baseHp = 185,
		baseMp = 160,
		baseAtk = 30,
		basePDef = 34,
		baseMDef = 34,
		critChance = 0.16,
		baseHpBonus = 50,
		baseAtkBonus = 6,
		weaponType = "MegaphoneCane",
		skillSlots = {
			Q = "SKILL_BRIEFCASE_SMASH",
			E = "SKILL_CHANT_STRIKE",
			R = "SKILL_UNION_SANCTIONS",
			F = "SKILL_SEAL_OF_AUDIT",
		},
	},

	-- 5) RecycleHunter (Spoiler, range 8)
	RecycleHunter = {
		id = "RecycleHunter",
		nameKey = "CLASS_RECYCLE_HUNTER",
		role = "Spoiler",
		isPlayableSprint2 = true,
		attackRange = 8,
		baseHp = 175,
		baseMp = 115,
		baseAtk = 31,
		basePDef = 32,
		baseMDef = 24,
		critChance = 0.18,
		baseHpBonus = 35,
		baseAtkBonus = 4,
		weaponType = "HarvesterHook",
		skillSlots = {
			Q = "SKILL_SPOIL",
			E = "SKILL_SWEEP",
			R = "SKILL_CART_RAM",
			F = "SKILL_MONOPOLY",
		},
	},

	-- 6) StreetfoodCrafter (Crafter / AoE Bruiser, range 8)
	StreetfoodCrafter = {
		id = "StreetfoodCrafter",
		nameKey = "CLASS_STREETFOOD_CRAFTER",
		role = "Crafter",
		isPlayableSprint2 = true,
		attackRange = 8,
		baseHp = 195,
		baseMp = 125,
		baseAtk = 33,
		basePDef = 38,
		baseMDef = 26,
		critChance = 0.16,
		baseHpBonus = 55,
		baseAtkBonus = 6,
		weaponType = "ShawarmaSpatula",
		skillSlots = {
			Q = "SKILL_TENDERIZER_SLAM",
			E = "SKILL_DEPLOY_SHAWARMA_GRILL",
			R = "SKILL_PROPANE_BLAST",
			F = "SKILL_MASTERWORK_POLISH",
		},
	},

	-- 7) HellsSousChef (Melee Dualist, range 8)
	HellsSousChef = {
		id = "HellsSousChef",
		nameKey = "CLASS_SOUS_CHEF",
		role = "MeleeDPS",
		isPlayableSprint2 = true,
		attackRange = 8,
		baseHp = 165,
		baseMp = 110,
		baseAtk = 36,
		basePDef = 28,
		baseMDef = 22,
		critChance = 0.22,
		baseHpBonus = 25,
		baseAtkBonus = 9,
		weaponType = "CleaverPan",
		skillSlots = {
			Q = "SKILL_SLICE_DICE",
			E = "SKILL_IRON_PAN",
			R = "SKILL_FLAMBE",
			F = "SKILL_FRIDAY_RUSH",
		},
	},

	-- 8) ExpressCourier (Melee Dagger / Backstabber, range 8)
	ExpressCourier = {
		id = "ExpressCourier",
		nameKey = "CLASS_EXPRESS_COURIER",
		role = "Dagger",
		isPlayableSprint2 = true,
		attackRange = 8,
		baseHp = 145,
		baseMp = 115,
		baseAtk = 35,
		basePDef = 22,
		baseMDef = 22,
		critChance = 0.32,
		baseHpBonus = 15,
		baseAtkBonus = 8,
		weaponType = "BoxCutterDagger",
		skillSlots = {
			Q = "SKILL_BACKSTAB_DELIVERY",
			E = "SKILL_SHADOW_STEP",
			R = "SKILL_PEPPER_SPRAY",
			F = "SKILL_EXPRESS_OVERCLOCK",
		},
	},

	-- 9) HeavyBouncer (Melee Destroyer / Titan, range 9)
	HeavyBouncer = {
		id = "HeavyBouncer",
		nameKey = "CLASS_HEAVY_BOUNCER",
		role = "Destroyer",
		isPlayableSprint2 = true,
		attackRange = 9,
		baseHp = 235,
		baseMp = 95,
		baseAtk = 38,
		basePDef = 42,
		baseMDef = 22,
		critChance = 0.20,
		baseHpBonus = 85,
		baseAtkBonus = 10,
		weaponType = "VelvetStanchion",
		skillSlots = {
			Q = "SKILL_CRUSHING_HAYMAKER",
			E = "SKILL_BOUNCER_TOSS",
			R = "SKILL_ARMOR_BREAKER",
			F = "SKILL_BOUNCER_FRENZY",
		},
	},

	-- 10) ParkingInspector (Ranged Archer / Sniper, range 42)
	ParkingInspector = {
		id = "ParkingInspector",
		nameKey = "CLASS_PARKING_INSPECTOR",
		role = "Archer",
		isPlayableSprint2 = true,
		attackRange = 42,
		baseHp = 145,
		baseMp = 125,
		baseAtk = 37,
		basePDef = 24,
		baseMDef = 24,
		critChance = 0.28,
		baseHpBonus = 15,
		baseAtkBonus = 10,
		weaponType = "ScannerCrossbow",
		skillSlots = {
			Q = "SKILL_TICKET_SHOT",
			E = "SKILL_WHEEL_CLAMP_TRAP",
			R = "SKILL_TOW_CABLE_SNIPE",
			F = "SKILL_HAWKEYE_RADAR",
		},
	},

	-- 11) HeavyBuilder (Ranged Nailgunner / Siege Shooter, range 36)
	HeavyBuilder = {
		id = "HeavyBuilder",
		nameKey = "CLASS_HEAVY_BUILDER",
		role = "SiegeGunner",
		isPlayableSprint2 = true,
		attackRange = 36,
		baseHp = 180,
		baseMp = 120,
		baseAtk = 36,
		basePDef = 34,
		baseMDef = 24,
		critChance = 0.22,
		baseHpBonus = 45,
		baseAtkBonus = 9,
		weaponType = "PneumaticNailgun",
		skillSlots = {
			Q = "SKILL_REBAR_VOLLEY",
			E = "SKILL_WET_CEMENT_TRAP",
			R = "SKILL_CONCRETE_BUNKER_SHOT",
			F = "SKILL_SIEGE_SCAFFOLD",
		},
	},

	-- 12) FullstackCyberMage (Burst Nuker Mage, range 38)
	FullstackCyberMage = {
		id = "FullstackCyberMage",
		nameKey = "CLASS_FULLSTACK_CYBER_MAGE",
		role = "Mage",
		isPlayableSprint2 = true,
		attackRange = 38,
		baseHp = 135,
		baseMp = 200,
		baseAtk = 41,
		basePDef = 18,
		baseMDef = 38,
		critChance = 0.24,
		baseHpBonus = 0,
		baseAtkBonus = 13,
		weaponType = "CyberDeck",
		skillSlots = {
			Q = "SKILL_DDOS_BOLT",
			E = "SKILL_FIREWALL_BREACH",
			R = "SKILL_BSOD_NOVA",
			F = "SKILL_DEPLOY_ON_FRIDAY",
		},
	},

	-- 13) UrbanAlchemist (DoT / Vampiric Drain Mage, range 35)
	UrbanAlchemist = {
		id = "UrbanAlchemist",
		nameKey = "CLASS_URBAN_ALCHEMIST",
		role = "Mage",
		isPlayableSprint2 = true,
		attackRange = 35,
		baseHp = 150,
		baseMp = 185,
		baseAtk = 38,
		basePDef = 22,
		baseMDef = 36,
		critChance = 0.20,
		baseHpBonus = 15,
		baseAtkBonus = 11,
		weaponType = "NeonFlaskLauncher",
		skillSlots = {
			Q = "SKILL_ACID_FLASK",
			E = "SKILL_LIFE_DRAIN",
			R = "SKILL_TOXIC_SMOG",
			F = "SKILL_MUTAGEN_OVERDOSE",
		},
	},

	-- 14) DroneOperator (Summoner with Combat Drone, range 36)
	DroneOperator = {
		id = "DroneOperator",
		nameKey = "CLASS_DRONE_OPERATOR",
		role = "Summoner",
		isPlayableSprint2 = true,
		attackRange = 36,
		baseHp = 155,
		baseMp = 165,
		baseAtk = 34,
		basePDef = 25,
		baseMDef = 30,
		critChance = 0.22,
		baseHpBonus = 20,
		baseAtkBonus = 8,
		weaponType = "DroneController",
		skillSlots = {
			Q = "SKILL_TARGET_LASER",
			E = "SKILL_DEPLOY_COMBAT_DRONE",
			R = "SKILL_FPV_KAMIKAZE",
			F = "SKILL_SERVOMOTOR_OVERCLOCK",
		},
	},
}

return ClassesConfig
