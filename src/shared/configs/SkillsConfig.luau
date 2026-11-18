--!strict

export type SkillSlot = "Q" | "E" | "R" | "F"

export type SkillTargetType =
	"SingleTarget"
	| "DeadSpoiledTarget"
	| "SelfAoE"
	| "FrontalCone"
	| "SelfBuff"
	| "PartyBuff"
	| "FriendlyOrSelf"

export type SkillData = {
	id: string,
	classId: string,
	slot: SkillSlot,
	nameKey: string,
	descKey: string,
	cooldown: number,
	range: number,
	mpCost: number,
	targetType: SkillTargetType,
	effectType: string?,
	damageMult: number?,
	hitCount: number?,
	stunDuration: number?,
	aggroBonus: number?,
	knockbackDist: number?,
	coneAngleDeg: number?,
	bleedDuration: number?,
	bleedTickMult: number?,
	pDefDebuffMult: number?,
	pDefDebuffDuration: number?,
	ignorePDefRatio: number?,
	lifestealRatio: number?,
	targetAoERadius: number?,
	healMaxHpRatio: number?,
	healFlat: number?,
	hotTickRatio: number?,
	hotDuration: number?,
	manaMaxMpRatio: number?,
	manaFlat: number?,
	cleanseDebuffs: boolean?,
	isTeleportBehind: boolean?,
	spawnsCombatDrone: boolean?,
	craftScrolls: number?,
	craftEnergyShots: number?,
	craftHpPotions: number?,
	buffDuration: number?,
	buffAtkMult: number?,
	buffPDefMult: number?,
	buffMDefMult: number?,
	buffMaxHpMult: number?,
	buffMaxMpMult: number?,
	buffWalkSpeedMult: number?,
	buffAtkSpdMult: number?,
	buffCritBonus: number?,
	buffCritDmgMult: number?,
	buffLifestealBonus: number?,
	buffCashMult: number?,
}

local SkillsConfig: { [string]: SkillData } = {
	-- ==========================================
	-- 1. RiotPolice (Tank, range 8)
	-- ==========================================
	SKILL_BATON_STUN = {
		id = "SKILL_BATON_STUN",
		classId = "RiotPolice",
		slot = "Q",
		nameKey = "SKILL_BATON_STUN",
		descKey = "SKILL_BATON_STUN_DESC",
		cooldown = 6.0,
		range = 8,
		mpCost = 12,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 1.40,
		stunDuration = 2.5,
	},

	SKILL_MEGAPHONE_AGGRO = {
		id = "SKILL_MEGAPHONE_AGGRO",
		classId = "RiotPolice",
		slot = "E",
		nameKey = "SKILL_MEGAPHONE_AGGRO",
		descKey = "SKILL_MEGAPHONE_AGGRO_DESC",
		cooldown = 10.0,
		range = 20,
		mpCost = 18,
		targetType = "SelfAoE",
		effectType = "TauntAoE",
		damageMult = 0.35,
		aggroBonus = 5000,
	},

	SKILL_WATER_CANNON = {
		id = "SKILL_WATER_CANNON",
		classId = "RiotPolice",
		slot = "R",
		nameKey = "SKILL_WATER_CANNON",
		descKey = "SKILL_WATER_CANNON_DESC",
		cooldown = 9.0,
		range = 22,
		mpCost = 22,
		targetType = "FrontalCone",
		effectType = "WaterCone",
		damageMult = 1.60,
		knockbackDist = 16,
		coneAngleDeg = 75,
	},

	SKILL_RIOT_SHIELD = {
		id = "SKILL_RIOT_SHIELD",
		classId = "RiotPolice",
		slot = "F",
		nameKey = "SKILL_RIOT_SHIELD",
		descKey = "SKILL_RIOT_SHIELD_DESC",
		cooldown = 18.0,
		range = 0,
		mpCost = 25,
		targetType = "SelfBuff",
		effectType = "ShieldWall",
		buffDuration = 8.0,
		buffPDefMult = 1.80, -- +80% PDef
		buffWalkSpeedMult = 0.65, -- -35% WalkSpeed
	},

	-- ==========================================
	-- 2. Paramedic (Healer / Mana Recharger, range 36)
	-- ==========================================
	SKILL_INSTANT_HEAL = {
		id = "SKILL_INSTANT_HEAL",
		classId = "Paramedic",
		slot = "Q",
		nameKey = "SKILL_INSTANT_HEAL",
		descKey = "SKILL_INSTANT_HEAL_DESC",
		cooldown = 4.5,
		range = 36,
		mpCost = 20,
		targetType = "FriendlyOrSelf",
		effectType = "InstantHeal",
		healMaxHpRatio = 0.35, -- +35% MaxHP
		healFlat = 120, -- +120 HP
	},

	SKILL_MANA_RECHARGE = {
		id = "SKILL_MANA_RECHARGE",
		classId = "Paramedic",
		slot = "E",
		nameKey = "SKILL_MANA_RECHARGE",
		descKey = "SKILL_MANA_RECHARGE_DESC",
		cooldown = 8.0,
		range = 25,
		mpCost = 15,
		targetType = "PartyBuff",
		effectType = "ManaRecharge",
		manaMaxMpRatio = 0.30, -- +30% MaxMP
		manaFlat = 60, -- +60 MP
	},

	SKILL_DEFIBRILLATOR = {
		id = "SKILL_DEFIBRILLATOR",
		classId = "Paramedic",
		slot = "R",
		nameKey = "SKILL_DEFIBRILLATOR",
		descKey = "SKILL_DEFIBRILLATOR_DESC",
		cooldown = 8.0,
		range = 36,
		mpCost = 22,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 2.10, -- 210% shock damage
		stunDuration = 1.5,
		cleanseDebuffs = true,
	},

	SKILL_SANITARY_DOME = {
		id = "SKILL_SANITARY_DOME",
		classId = "Paramedic",
		slot = "F",
		nameKey = "SKILL_SANITARY_DOME",
		descKey = "SKILL_SANITARY_DOME_DESC",
		cooldown = 18.0,
		range = 30,
		mpCost = 32,
		targetType = "PartyBuff",
		effectType = "SanitaryDome",
		healMaxHpRatio = 0.25, -- +25% MaxHP instant
		hotTickRatio = 0.04, -- +4% MaxHP per second
		hotDuration = 8.0, -- 8s HoT
	},

	-- ==========================================
	-- 3. SubwayRocker (Bard BD/SWS, range 8)
	-- ==========================================
	SKILL_POWER_CHORD = {
		id = "SKILL_POWER_CHORD",
		classId = "SubwayRocker",
		slot = "Q",
		nameKey = "SKILL_POWER_CHORD",
		descKey = "SKILL_POWER_CHORD_DESC",
		cooldown = 4.5,
		range = 8,
		mpCost = 14,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 1.65,
	},

	SKILL_SONG_SUBWAY_WIND = {
		id = "SKILL_SONG_SUBWAY_WIND",
		classId = "SubwayRocker",
		slot = "E",
		nameKey = "SKILL_SONG_SUBWAY_WIND",
		descKey = "SKILL_SONG_SUBWAY_WIND_DESC",
		cooldown = 16.0,
		range = 30,
		mpCost = 26,
		targetType = "PartyBuff",
		effectType = "PartySong",
		buffDuration = 30.0,
		buffPDefMult = 1.35, -- +35% P.Def
		buffMDefMult = 1.35, -- +35% M.Def
		buffWalkSpeedMult = 1.25, -- +25% WalkSpeed
	},

	SKILL_DANCE_OVERDRIVE = {
		id = "SKILL_DANCE_OVERDRIVE",
		classId = "SubwayRocker",
		slot = "R",
		nameKey = "SKILL_DANCE_OVERDRIVE",
		descKey = "SKILL_DANCE_OVERDRIVE_DESC",
		cooldown = 16.0,
		range = 30,
		mpCost = 26,
		targetType = "PartyBuff",
		effectType = "PartyDance",
		buffDuration = 30.0,
		buffAtkMult = 1.30, -- +30% Atk
		buffCritDmgMult = 1.35, -- +35% Crit Damage
	},

	SKILL_SHREDDING_SOLO = {
		id = "SKILL_SHREDDING_SOLO",
		classId = "SubwayRocker",
		slot = "F",
		nameKey = "SKILL_SHREDDING_SOLO",
		descKey = "SKILL_SHREDDING_SOLO_DESC",
		cooldown = 12.0,
		range = 18,
		mpCost = 24,
		targetType = "SelfAoE",
		effectType = "SonicBlastAoE",
		damageMult = 1.90,
		stunDuration = 2.0,
	},

	-- ==========================================
	-- 4. UnionBoss (Party Buffer / Debuffer, range 25)
	-- ==========================================
	SKILL_BRIEFCASE_SMASH = {
		id = "SKILL_BRIEFCASE_SMASH",
		classId = "UnionBoss",
		slot = "Q",
		nameKey = "SKILL_BRIEFCASE_SMASH",
		descKey = "SKILL_BRIEFCASE_SMASH_DESC",
		cooldown = 5.0,
		range = 25,
		mpCost = 15,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.55,
		lifestealRatio = 0.30, -- 30% HP lifesteal
	},

	SKILL_CHANT_STRIKE = {
		id = "SKILL_CHANT_STRIKE",
		classId = "UnionBoss",
		slot = "E",
		nameKey = "SKILL_CHANT_STRIKE",
		descKey = "SKILL_CHANT_STRIKE_DESC",
		cooldown = 20.0,
		range = 30,
		mpCost = 30,
		targetType = "PartyBuff",
		effectType = "PartyChant",
		buffDuration = 45.0,
		buffMaxHpMult = 1.25, -- +25% MaxHP
		buffMaxMpMult = 1.25, -- +25% MaxMP
		buffAtkMult = 1.25, -- +25% Atk
		buffCritBonus = 0.20, -- +20% CritChance
	},

	SKILL_UNION_SANCTIONS = {
		id = "SKILL_UNION_SANCTIONS",
		classId = "UnionBoss",
		slot = "R",
		nameKey = "SKILL_UNION_SANCTIONS",
		descKey = "SKILL_UNION_SANCTIONS_DESC",
		cooldown = 12.0,
		range = 18,
		mpCost = 22,
		targetType = "SelfAoE",
		effectType = "DebuffAoE",
		damageMult = 1.15,
		pDefDebuffMult = 0.70, -- -30% P.Def/M.Def
		pDefDebuffDuration = 12.0,
	},

	SKILL_SEAL_OF_AUDIT = {
		id = "SKILL_SEAL_OF_AUDIT",
		classId = "UnionBoss",
		slot = "F",
		nameKey = "SKILL_SEAL_OF_AUDIT",
		descKey = "SKILL_SEAL_OF_AUDIT_DESC",
		cooldown = 15.0,
		range = 20,
		mpCost = 28,
		targetType = "SelfAoE",
		effectType = "AuditRootAoE",
		damageMult = 1.80,
		stunDuration = 4.0, -- 4s heavy root/stun
	},

	-- ==========================================
	-- 5. RecycleHunter (Spoiler / Bounty Hunter, range 8)
	-- ==========================================
	SKILL_SPOIL = {
		id = "SKILL_SPOIL",
		classId = "RecycleHunter",
		slot = "Q",
		nameKey = "SKILL_SPOIL",
		descKey = "SKILL_SPOIL_DESC",
		cooldown = 3.5,
		range = 20,
		mpCost = 10,
		targetType = "SingleTarget",
		effectType = "Spoil",
		damageMult = 0.40,
	},

	SKILL_SWEEP = {
		id = "SKILL_SWEEP",
		classId = "RecycleHunter",
		slot = "E",
		nameKey = "SKILL_SWEEP",
		descKey = "SKILL_SWEEP_DESC",
		cooldown = 2.0,
		range = 20,
		mpCost = 8,
		targetType = "DeadSpoiledTarget",
		effectType = "Sweep",
	},

	SKILL_CART_RAM = {
		id = "SKILL_CART_RAM",
		classId = "RecycleHunter",
		slot = "R",
		nameKey = "SKILL_CART_RAM",
		descKey = "SKILL_CART_RAM_DESC",
		cooldown = 8.0,
		range = 20,
		mpCost = 18,
		targetType = "SingleTarget",
		effectType = "DashStrike",
		damageMult = 1.50,
		stunDuration = 1.5,
	},

	SKILL_MONOPOLY = {
		id = "SKILL_MONOPOLY",
		classId = "RecycleHunter",
		slot = "F",
		nameKey = "SKILL_MONOPOLY",
		descKey = "SKILL_MONOPOLY_DESC",
		cooldown = 22.0,
		range = 0,
		mpCost = 20,
		targetType = "SelfBuff",
		effectType = "SelfBuff",
		buffDuration = 15.0,
		buffCashMult = 1.25, -- +25% Cash & Drop reward
	},

	-- ==========================================
	-- 6. StreetfoodCrafter (Crafter / AoE Bruiser, range 8)
	-- ==========================================
	SKILL_TENDERIZER_SLAM = {
		id = "SKILL_TENDERIZER_SLAM",
		classId = "StreetfoodCrafter",
		slot = "Q",
		nameKey = "SKILL_TENDERIZER_SLAM",
		descKey = "SKILL_TENDERIZER_SLAM_DESC",
		cooldown = 5.0,
		range = 8,
		mpCost = 14,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 1.70,
		pDefDebuffMult = 0.80, -- -20% P.Def
		pDefDebuffDuration = 8.0,
	},

	SKILL_DEPLOY_SHAWARMA_GRILL = {
		id = "SKILL_DEPLOY_SHAWARMA_GRILL",
		classId = "StreetfoodCrafter",
		slot = "E",
		nameKey = "SKILL_DEPLOY_SHAWARMA_GRILL",
		descKey = "SKILL_DEPLOY_SHAWARMA_GRILL_DESC",
		cooldown = 18.0,
		range = 20,
		mpCost = 25,
		targetType = "SelfBuff",
		effectType = "FieldCraft",
		healMaxHpRatio = 0.25, -- Heals 25% HP
		craftScrolls = 1, -- +1 EnchantScroll
		craftEnergyShots = 50, -- +50 EnergyShots
		craftHpPotions = 2, -- +2 HpPotions
	},

	SKILL_PROPANE_BLAST = {
		id = "SKILL_PROPANE_BLAST",
		classId = "StreetfoodCrafter",
		slot = "R",
		nameKey = "SKILL_PROPANE_BLAST",
		descKey = "SKILL_PROPANE_BLAST_DESC",
		cooldown = 11.0,
		range = 18,
		mpCost = 22,
		targetType = "SelfAoE",
		effectType = "ExplosionAoE",
		damageMult = 2.30,
		knockbackDist = 14,
	},

	SKILL_MASTERWORK_POLISH = {
		id = "SKILL_MASTERWORK_POLISH",
		classId = "StreetfoodCrafter",
		slot = "F",
		nameKey = "SKILL_MASTERWORK_POLISH",
		descKey = "SKILL_MASTERWORK_POLISH_DESC",
		cooldown = 18.0,
		range = 30,
		mpCost = 26,
		targetType = "PartyBuff",
		effectType = "PartyPolish",
		buffDuration = 40.0,
		buffAtkMult = 1.20, -- +20% Atk
		buffPDefMult = 1.25, -- +25% P.Def
	},

	-- ==========================================
	-- 7. HellsSousChef (Melee Dualist, range 8)
	-- ==========================================
	SKILL_SLICE_DICE = {
		id = "SKILL_SLICE_DICE",
		classId = "HellsSousChef",
		slot = "Q",
		nameKey = "SKILL_SLICE_DICE",
		descKey = "SKILL_SLICE_DICE_DESC",
		cooldown = 5.0,
		range = 8,
		mpCost = 14,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 1.80,
		hitCount = 3,
		bleedDuration = 4.0,
		bleedTickMult = 0.25,
	},

	SKILL_IRON_PAN = {
		id = "SKILL_IRON_PAN",
		classId = "HellsSousChef",
		slot = "E",
		nameKey = "SKILL_IRON_PAN",
		descKey = "SKILL_IRON_PAN_DESC",
		cooldown = 8.0,
		range = 8,
		mpCost = 16,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 1.50,
		pDefDebuffMult = 0.75, -- -25% PDef
		pDefDebuffDuration = 6.0,
	},

	SKILL_FLAMBE = {
		id = "SKILL_FLAMBE",
		classId = "HellsSousChef",
		slot = "R",
		nameKey = "SKILL_FLAMBE",
		descKey = "SKILL_FLAMBE_DESC",
		cooldown = 9.0,
		range = 18,
		mpCost = 20,
		targetType = "FrontalCone",
		effectType = "FireCone",
		damageMult = 1.65,
		coneAngleDeg = 85,
	},

	SKILL_FRIDAY_RUSH = {
		id = "SKILL_FRIDAY_RUSH",
		classId = "HellsSousChef",
		slot = "F",
		nameKey = "SKILL_FRIDAY_RUSH",
		descKey = "SKILL_FRIDAY_RUSH_DESC",
		cooldown = 20.0,
		range = 0,
		mpCost = 24,
		targetType = "SelfBuff",
		effectType = "SelfBuff",
		buffDuration = 10.0,
		buffAtkSpdMult = 1.40, -- +40% AtkSpd
		buffCritBonus = 0.30, -- +30% CritRate
	},

	-- ==========================================
	-- 8. ExpressCourier (Melee Dagger / Backstabber, range 8)
	-- ==========================================
	SKILL_BACKSTAB_DELIVERY = {
		id = "SKILL_BACKSTAB_DELIVERY",
		classId = "ExpressCourier",
		slot = "Q",
		nameKey = "SKILL_BACKSTAB_DELIVERY",
		descKey = "SKILL_BACKSTAB_DELIVERY_DESC",
		cooldown = 5.5,
		range = 8,
		mpCost = 16,
		targetType = "SingleTarget",
		effectType = "Backstab",
		damageMult = 2.60,
		ignorePDefRatio = 0.40, -- Ignores 40% P.Def
	},

	SKILL_SHADOW_STEP = {
		id = "SKILL_SHADOW_STEP",
		classId = "ExpressCourier",
		slot = "E",
		nameKey = "SKILL_SHADOW_STEP",
		descKey = "SKILL_SHADOW_STEP_DESC",
		cooldown = 8.0,
		range = 28,
		mpCost = 18,
		targetType = "SingleTarget",
		effectType = "ShadowStep",
		damageMult = 1.40,
		isTeleportBehind = true,
	},

	SKILL_PEPPER_SPRAY = {
		id = "SKILL_PEPPER_SPRAY",
		classId = "ExpressCourier",
		slot = "R",
		nameKey = "SKILL_PEPPER_SPRAY",
		descKey = "SKILL_PEPPER_SPRAY_DESC",
		cooldown = 10.0,
		range = 10,
		mpCost = 20,
		targetType = "SingleTarget",
		effectType = "BlindStun",
		damageMult = 1.50,
		stunDuration = 3.5,
	},

	SKILL_EXPRESS_OVERCLOCK = {
		id = "SKILL_EXPRESS_OVERCLOCK",
		classId = "ExpressCourier",
		slot = "F",
		nameKey = "SKILL_EXPRESS_OVERCLOCK",
		descKey = "SKILL_EXPRESS_OVERCLOCK_DESC",
		cooldown = 18.0,
		range = 0,
		mpCost = 22,
		targetType = "SelfBuff",
		effectType = "SelfBuff",
		buffDuration = 15.0,
		buffWalkSpeedMult = 1.45, -- +45% WalkSpeed
		buffCritBonus = 0.40, -- +40% CritChance
	},

	-- ==========================================
	-- 9. HeavyBouncer (Melee Destroyer / Titan, range 9)
	-- ==========================================
	SKILL_CRUSHING_HAYMAKER = {
		id = "SKILL_CRUSHING_HAYMAKER",
		classId = "HeavyBouncer",
		slot = "Q",
		nameKey = "SKILL_CRUSHING_HAYMAKER",
		descKey = "SKILL_CRUSHING_HAYMAKER_DESC",
		cooldown = 5.5,
		range = 9,
		mpCost = 16,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 2.40,
	},

	SKILL_BOUNCER_TOSS = {
		id = "SKILL_BOUNCER_TOSS",
		classId = "HeavyBouncer",
		slot = "E",
		nameKey = "SKILL_BOUNCER_TOSS",
		descKey = "SKILL_BOUNCER_TOSS_DESC",
		cooldown = 9.0,
		range = 16,
		mpCost = 20,
		targetType = "SelfAoE",
		effectType = "GroundSlamAoE",
		damageMult = 1.95,
		stunDuration = 2.5,
	},

	SKILL_ARMOR_BREAKER = {
		id = "SKILL_ARMOR_BREAKER",
		classId = "HeavyBouncer",
		slot = "R",
		nameKey = "SKILL_ARMOR_BREAKER",
		descKey = "SKILL_ARMOR_BREAKER_DESC",
		cooldown = 8.5,
		range = 9,
		mpCost = 18,
		targetType = "SingleTarget",
		effectType = "MeleeStrike",
		damageMult = 2.10,
		pDefDebuffMult = 0.65, -- -35% P.Def
		pDefDebuffDuration = 8.0,
	},

	SKILL_BOUNCER_FRENZY = {
		id = "SKILL_BOUNCER_FRENZY",
		classId = "HeavyBouncer",
		slot = "F",
		nameKey = "SKILL_BOUNCER_FRENZY",
		descKey = "SKILL_BOUNCER_FRENZY_DESC",
		cooldown = 22.0,
		range = 0,
		mpCost = 26,
		targetType = "SelfBuff",
		effectType = "DestroyerFrenzy",
		buffDuration = 12.0,
		buffAtkMult = 2.20, -- +120% Atk
		buffLifestealBonus = 0.25, -- 25% Lifesteal
	},

	-- ==========================================
	-- 10. ParkingInspector (Ranged Archer / Sniper, range 42)
	-- ==========================================
	SKILL_TICKET_SHOT = {
		id = "SKILL_TICKET_SHOT",
		classId = "ParkingInspector",
		slot = "Q",
		nameKey = "SKILL_TICKET_SHOT",
		descKey = "SKILL_TICKET_SHOT_DESC",
		cooldown = 4.0,
		range = 42,
		mpCost = 14,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.85,
	},

	SKILL_WHEEL_CLAMP_TRAP = {
		id = "SKILL_WHEEL_CLAMP_TRAP",
		classId = "ParkingInspector",
		slot = "E",
		nameKey = "SKILL_WHEEL_CLAMP_TRAP",
		descKey = "SKILL_WHEEL_CLAMP_TRAP_DESC",
		cooldown = 8.5,
		range = 38,
		mpCost = 18,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.45,
		stunDuration = 3.0, -- 3s snare/root trap
		pDefDebuffMult = 0.80, -- -20% P.Def
		pDefDebuffDuration = 6.0,
	},

	SKILL_TOW_CABLE_SNIPE = {
		id = "SKILL_TOW_CABLE_SNIPE",
		classId = "ParkingInspector",
		slot = "R",
		nameKey = "SKILL_TOW_CABLE_SNIPE",
		descKey = "SKILL_TOW_CABLE_SNIPE_DESC",
		cooldown = 10.0,
		range = 42,
		mpCost = 24,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 2.75,
		ignorePDefRatio = 0.25,
	},

	SKILL_HAWKEYE_RADAR = {
		id = "SKILL_HAWKEYE_RADAR",
		classId = "ParkingInspector",
		slot = "F",
		nameKey = "SKILL_HAWKEYE_RADAR",
		descKey = "SKILL_HAWKEYE_RADAR_DESC",
		cooldown = 20.0,
		range = 0,
		mpCost = 24,
		targetType = "SelfBuff",
		effectType = "SelfBuff",
		buffDuration = 18.0,
		buffAtkMult = 1.35, -- +35% Atk
		buffCritBonus = 0.35, -- +35% CritChance
	},

	-- ==========================================
	-- 11. HeavyBuilder (Ranged Nailgunner / Siege Shooter, range 36)
	-- ==========================================
	SKILL_REBAR_VOLLEY = {
		id = "SKILL_REBAR_VOLLEY",
		classId = "HeavyBuilder",
		slot = "Q",
		nameKey = "SKILL_REBAR_VOLLEY",
		descKey = "SKILL_REBAR_VOLLEY_DESC",
		cooldown = 4.5,
		range = 36,
		mpCost = 15,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.95,
		hitCount = 3,
	},

	SKILL_WET_CEMENT_TRAP = {
		id = "SKILL_WET_CEMENT_TRAP",
		classId = "HeavyBuilder",
		slot = "E",
		nameKey = "SKILL_WET_CEMENT_TRAP",
		descKey = "SKILL_WET_CEMENT_TRAP_DESC",
		cooldown = 9.0,
		range = 34,
		mpCost = 18,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.50,
		stunDuration = 3.0, -- 3s cement root
		pDefDebuffMult = 0.75, -- -25% P.Def
		pDefDebuffDuration = 6.0,
	},

	SKILL_CONCRETE_BUNKER_SHOT = {
		id = "SKILL_CONCRETE_BUNKER_SHOT",
		classId = "HeavyBuilder",
		slot = "R",
		nameKey = "SKILL_CONCRETE_BUNKER_SHOT",
		descKey = "SKILL_CONCRETE_BUNKER_SHOT_DESC",
		cooldown = 10.0,
		range = 36,
		mpCost = 24,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 2.60,
		knockbackDist = 14,
	},

	SKILL_SIEGE_SCAFFOLD = {
		id = "SKILL_SIEGE_SCAFFOLD",
		classId = "HeavyBuilder",
		slot = "F",
		nameKey = "SKILL_SIEGE_SCAFFOLD",
		descKey = "SKILL_SIEGE_SCAFFOLD_DESC",
		cooldown = 20.0,
		range = 0,
		mpCost = 24,
		targetType = "SelfBuff",
		effectType = "SelfBuff",
		buffDuration = 16.0,
		buffAtkMult = 1.45, -- +45% Atk
		buffPDefMult = 1.40, -- +40% P.Def
		buffWalkSpeedMult = 0.80, -- -20% WalkSpeed
	},

	-- ==========================================
	-- 12. FullstackCyberMage (Burst Nuker Mage, range 38)
	-- ==========================================
	SKILL_DDOS_BOLT = {
		id = "SKILL_DDOS_BOLT",
		classId = "FullstackCyberMage",
		slot = "Q",
		nameKey = "SKILL_DDOS_BOLT",
		descKey = "SKILL_DDOS_BOLT_DESC",
		cooldown = 3.5,
		range = 38,
		mpCost = 16,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 2.05,
	},

	SKILL_FIREWALL_BREACH = {
		id = "SKILL_FIREWALL_BREACH",
		classId = "FullstackCyberMage",
		slot = "E",
		nameKey = "SKILL_FIREWALL_BREACH",
		descKey = "SKILL_FIREWALL_BREACH_DESC",
		cooldown = 7.5,
		range = 38,
		mpCost = 18,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.65,
		pDefDebuffMult = 0.65, -- -35% P.Def/M.Def
		pDefDebuffDuration = 8.0,
	},

	SKILL_BSOD_NOVA = {
		id = "SKILL_BSOD_NOVA",
		classId = "FullstackCyberMage",
		slot = "R",
		nameKey = "SKILL_BSOD_NOVA",
		descKey = "SKILL_BSOD_NOVA_DESC",
		cooldown = 11.0,
		range = 38,
		mpCost = 28,
		targetType = "SingleTarget",
		effectType = "TargetAoENuke",
		damageMult = 2.90, -- 290% BSOD Nova
		targetAoERadius = 14,
		stunDuration = 1.5,
	},

	SKILL_DEPLOY_ON_FRIDAY = {
		id = "SKILL_DEPLOY_ON_FRIDAY",
		classId = "FullstackCyberMage",
		slot = "F",
		nameKey = "SKILL_DEPLOY_ON_FRIDAY",
		descKey = "SKILL_DEPLOY_ON_FRIDAY_DESC",
		cooldown = 20.0,
		range = 0,
		mpCost = 15,
		targetType = "SelfBuff",
		effectType = "DeployFriday",
		buffDuration = 15.0,
		buffAtkMult = 1.65, -- +65% Atk
		manaMaxMpRatio = 0.25, -- +25% MP restore
	},

	-- ==========================================
	-- 13. UrbanAlchemist (DoT / Vampiric Drain Mage, range 35)
	-- ==========================================
	SKILL_ACID_FLASK = {
		id = "SKILL_ACID_FLASK",
		classId = "UrbanAlchemist",
		slot = "Q",
		nameKey = "SKILL_ACID_FLASK",
		descKey = "SKILL_ACID_FLASK_DESC",
		cooldown = 4.5,
		range = 35,
		mpCost = 15,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.60,
		bleedDuration = 5.0,
		bleedTickMult = 0.35,
		pDefDebuffMult = 0.75,
		pDefDebuffDuration = 6.0,
	},

	SKILL_LIFE_DRAIN = {
		id = "SKILL_LIFE_DRAIN",
		classId = "UrbanAlchemist",
		slot = "E",
		nameKey = "SKILL_LIFE_DRAIN",
		descKey = "SKILL_LIFE_DRAIN_DESC",
		cooldown = 6.5,
		range = 35,
		mpCost = 20,
		targetType = "SingleTarget",
		effectType = "LifeDrain",
		damageMult = 1.85,
		lifestealRatio = 0.50, -- 50% heal from damage dealt
	},

	SKILL_TOXIC_SMOG = {
		id = "SKILL_TOXIC_SMOG",
		classId = "UrbanAlchemist",
		slot = "R",
		nameKey = "SKILL_TOXIC_SMOG",
		descKey = "SKILL_TOXIC_SMOG_DESC",
		cooldown = 10.0,
		range = 20,
		mpCost = 24,
		targetType = "SelfAoE",
		effectType = "ToxicSmogAoE",
		damageMult = 2.10,
		bleedDuration = 5.0,
		bleedTickMult = 0.30,
	},

	SKILL_MUTAGEN_OVERDOSE = {
		id = "SKILL_MUTAGEN_OVERDOSE",
		classId = "UrbanAlchemist",
		slot = "F",
		nameKey = "SKILL_MUTAGEN_OVERDOSE",
		descKey = "SKILL_MUTAGEN_OVERDOSE_DESC",
		cooldown = 20.0,
		range = 0,
		mpCost = 24,
		targetType = "SelfBuff",
		effectType = "SelfBuff",
		buffDuration = 16.0,
		buffAtkMult = 1.40, -- +40% Atk
		buffAtkSpdMult = 1.30, -- +30% AtkSpd
		buffLifestealBonus = 0.25, -- +25% Lifesteal
	},

	-- ==========================================
	-- 14. DroneOperator (Summoner with Combat Drone, range 36)
	-- ==========================================
	SKILL_TARGET_LASER = {
		id = "SKILL_TARGET_LASER",
		classId = "DroneOperator",
		slot = "Q",
		nameKey = "SKILL_TARGET_LASER",
		descKey = "SKILL_TARGET_LASER_DESC",
		cooldown = 4.0,
		range = 36,
		mpCost = 14,
		targetType = "SingleTarget",
		effectType = "RangedProjectile",
		damageMult = 1.70,
		pDefDebuffMult = 0.80, -- -20% P.Def
		pDefDebuffDuration = 8.0,
	},

	SKILL_DEPLOY_COMBAT_DRONE = {
		id = "SKILL_DEPLOY_COMBAT_DRONE",
		classId = "DroneOperator",
		slot = "E",
		nameKey = "SKILL_DEPLOY_COMBAT_DRONE",
		descKey = "SKILL_DEPLOY_COMBAT_DRONE_DESC",
		cooldown = 12.0,
		range = 36,
		mpCost = 25,
		targetType = "SelfBuff",
		effectType = "DeployDrone",
		spawnsCombatDrone = true,
		buffDuration = 60.0,
		buffAtkMult = 1.15,
	},

	SKILL_FPV_KAMIKAZE = {
		id = "SKILL_FPV_KAMIKAZE",
		classId = "DroneOperator",
		slot = "R",
		nameKey = "SKILL_FPV_KAMIKAZE",
		descKey = "SKILL_FPV_KAMIKAZE_DESC",
		cooldown = 10.0,
		range = 36,
		mpCost = 24,
		targetType = "SingleTarget",
		effectType = "TargetAoENuke",
		damageMult = 2.65, -- 265% AoE explosion on target
		targetAoERadius = 14,
		stunDuration = 1.5,
	},

	SKILL_SERVOMOTOR_OVERCLOCK = {
		id = "SKILL_SERVOMOTOR_OVERCLOCK",
		classId = "DroneOperator",
		slot = "F",
		nameKey = "SKILL_SERVOMOTOR_OVERCLOCK",
		descKey = "SKILL_SERVOMOTOR_OVERCLOCK_DESC",
		cooldown = 18.0,
		range = 30,
		mpCost = 28,
		targetType = "PartyBuff",
		effectType = "PartyDroneOverclock",
		buffDuration = 35.0,
		buffCritBonus = 0.30, -- +30% CritChance
		buffAtkMult = 1.30, -- +30% Atk
	},
}

return SkillsConfig
