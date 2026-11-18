--!strict

export type RaceId = "RACE_LAW" | "RACE_STREET" | "RACE_CORP" | "RACE_WORKER" | "RACE_NIGHT"

export type RaceData = {
	id: RaceId,
	nameKey: string,
	hpMult: number,
	atkSpdMult: number,
	critMult: number,
	moveSpeedMult: number,
	stunResist: number,
}

local RacesConfig: { [string]: RaceData } = {
	RACE_LAW = {
		id = "RACE_LAW",
		nameKey = "RACE_LAW",
		hpMult = 1.15,
		atkSpdMult = 1.00,
		critMult = 1.00,
		moveSpeedMult = 1.00,
		stunResist = 0.25,
	},
	RACE_STREET = {
		id = "RACE_STREET",
		nameKey = "RACE_STREET",
		hpMult = 0.95,
		atkSpdMult = 1.12,
		critMult = 1.20,
		moveSpeedMult = 1.10,
		stunResist = 0.05,
	},
	RACE_CORP = {
		id = "RACE_CORP",
		nameKey = "RACE_CORP",
		hpMult = 0.90,
		atkSpdMult = 1.15,
		critMult = 1.15,
		moveSpeedMult = 1.02,
		stunResist = 0.05,
	},
	RACE_WORKER = {
		id = "RACE_WORKER",
		nameKey = "RACE_WORKER",
		hpMult = 1.25,
		atkSpdMult = 0.95,
		critMult = 0.95,
		moveSpeedMult = 0.98,
		stunResist = 0.30,
	},
	RACE_NIGHT = {
		id = "RACE_NIGHT",
		nameKey = "RACE_NIGHT",
		hpMult = 1.00,
		atkSpdMult = 1.10,
		critMult = 1.25,
		moveSpeedMult = 1.06,
		stunResist = 0.10,
	},
}

return RacesConfig
