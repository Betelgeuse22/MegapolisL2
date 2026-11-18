--!strict

export type EquipmentSlot = "Weapon" | "Chest" | "Legs" | "Boots" | "Accessory1" | "Accessory2"
export type ItemGrade = "NG" | "D"

export type ItemStatBonuses = {
	atk: number?,
	pDef: number?,
	mDef: number?,
	maxHp: number?,
	maxMp: number?,
}

export type ItemData = {
	id: string,
	nameKey: string,
	descKey: string,
	slot: EquipmentSlot,
	grade: ItemGrade,
	reqLevel: number,
	sellPrice: number,
	bonuses: ItemStatBonuses,
}

export type ItemVisualStyle = {
	glyph: string,
	subGlyph: string?,
	tintTop: Color3,
	tintBottom: Color3,
	glyphColor: Color3,
	borderColor: Color3,
}

local EQUIPMENT_SLOTS: { EquipmentSlot } = {
	"Weapon",
	"Chest",
	"Legs",
	"Boots",
	"Accessory1",
	"Accessory2",
}

local SLOT_NAME_KEYS: { [string]: string } = {
	Weapon = "UI_SLOT_WEAPON",
	Chest = "UI_SLOT_CHEST",
	Legs = "UI_SLOT_LEGS",
	Boots = "UI_SLOT_BOOTS",
	Accessory1 = "UI_SLOT_ACCESSORY1",
	Accessory2 = "UI_SLOT_ACCESSORY2",
}

local ITEMS_MAP: { [string]: ItemData } = {
	-- ====================================================
	-- WEAPONS (slot = "Weapon")
	-- ====================================================
	WPN_STARTER = {
		id = "WPN_STARTER",
		nameKey = "ITEM_WPN_STARTER",
		descKey = "ITEM_WPN_STARTER_DESC",
		slot = "Weapon",
		grade = "NG",
		reqLevel = 1,
		sellPrice = 35,
		bonuses = {
			atk = 12,
		},
	},
	WPN_BARON_ELITE = {
		id = "WPN_BARON_ELITE",
		nameKey = "ITEM_WPN_BARON_ELITE",
		descKey = "ITEM_WPN_BARON_ELITE_DESC",
		slot = "Weapon",
		grade = "D",
		reqLevel = 8,
		sellPrice = 240,
		bonuses = {
			atk = 28,
			maxHp = 40,
		},
	},

	-- ====================================================
	-- ARMOR: CHEST (slot = "Chest")
	-- ====================================================
	ARM_COMMUTER_JACKET = {
		id = "ARM_COMMUTER_JACKET",
		nameKey = "ITEM_ARM_COMMUTER_JACKET",
		descKey = "ITEM_ARM_COMMUTER_JACKET_DESC",
		slot = "Chest",
		grade = "NG",
		reqLevel = 1,
		sellPrice = 25,
		bonuses = {
			pDef = 10,
			maxHp = 35,
		},
	},
	ARM_INSPECTOR_VEST = {
		id = "ARM_INSPECTOR_VEST",
		nameKey = "ITEM_ARM_INSPECTOR_VEST",
		descKey = "ITEM_ARM_INSPECTOR_VEST_DESC",
		slot = "Chest",
		grade = "NG",
		reqLevel = 5,
		sellPrice = 85,
		bonuses = {
			pDef = 22,
			maxHp = 80,
		},
	},
	ARM_BARON_COAT = {
		id = "ARM_BARON_COAT",
		nameKey = "ITEM_ARM_BARON_COAT",
		descKey = "ITEM_ARM_BARON_COAT_DESC",
		slot = "Chest",
		grade = "D",
		reqLevel = 9,
		sellPrice = 260,
		bonuses = {
			pDef = 38,
			maxHp = 150,
		},
	},

	-- ====================================================
	-- ARMOR: LEGS (slot = "Legs")
	-- ====================================================
	ARM_CARGO_PANTS = {
		id = "ARM_CARGO_PANTS",
		nameKey = "ITEM_ARM_CARGO_PANTS",
		descKey = "ITEM_ARM_CARGO_PANTS_DESC",
		slot = "Legs",
		grade = "NG",
		reqLevel = 1,
		sellPrice = 20,
		bonuses = {
			pDef = 7,
			maxHp = 25,
		},
	},
	ARM_TACTICAL_PANTS = {
		id = "ARM_TACTICAL_PANTS",
		nameKey = "ITEM_ARM_TACTICAL_PANTS",
		descKey = "ITEM_ARM_TACTICAL_PANTS_DESC",
		slot = "Legs",
		grade = "NG",
		reqLevel = 5,
		sellPrice = 65,
		bonuses = {
			pDef = 15,
			maxHp = 55,
		},
	},

	-- ====================================================
	-- ARMOR: BOOTS (slot = "Boots")
	-- ====================================================
	ARM_RUBBER_BOOTS = {
		id = "ARM_RUBBER_BOOTS",
		nameKey = "ITEM_ARM_RUBBER_BOOTS",
		descKey = "ITEM_ARM_RUBBER_BOOTS_DESC",
		slot = "Boots",
		grade = "NG",
		reqLevel = 1,
		sellPrice = 15,
		bonuses = {
			pDef = 5,
			maxHp = 15,
		},
	},
	ARM_STEEL_BOOTS = {
		id = "ARM_STEEL_BOOTS",
		nameKey = "ITEM_ARM_STEEL_BOOTS",
		descKey = "ITEM_ARM_STEEL_BOOTS_DESC",
		slot = "Boots",
		grade = "NG",
		reqLevel = 5,
		sellPrice = 55,
		bonuses = {
			pDef = 12,
			maxHp = 40,
		},
	},

	-- ====================================================
	-- JEWELRY / ACCESSORIES (slot = "Accessory1" / "Accessory2")
	-- ====================================================
	ACC_METRO_WATCH = {
		id = "ACC_METRO_WATCH",
		nameKey = "ITEM_ACC_METRO_WATCH",
		descKey = "ITEM_ACC_METRO_WATCH_DESC",
		slot = "Accessory1",
		grade = "NG",
		reqLevel = 1,
		sellPrice = 25,
		bonuses = {
			mDef = 9,
			maxMp = 25,
		},
	},
	ACC_ALCHEMIST_CHAIN = {
		id = "ACC_ALCHEMIST_CHAIN",
		nameKey = "ITEM_ACC_ALCHEMIST_CHAIN",
		descKey = "ITEM_ACC_ALCHEMIST_CHAIN_DESC",
		slot = "Accessory1",
		grade = "NG",
		reqLevel = 5,
		sellPrice = 75,
		bonuses = {
			mDef = 18,
			maxMp = 50,
		},
	},
	ACC_TOKEN_RING = {
		id = "ACC_TOKEN_RING",
		nameKey = "ITEM_ACC_TOKEN_RING",
		descKey = "ITEM_ACC_TOKEN_RING_DESC",
		slot = "Accessory2",
		grade = "NG",
		reqLevel = 1,
		sellPrice = 20,
		bonuses = {
			mDef = 7,
			maxMp = 20,
		},
	},
	ACC_BARON_SIGNET = {
		id = "ACC_BARON_SIGNET",
		nameKey = "ITEM_ACC_BARON_SIGNET",
		descKey = "ITEM_ACC_BARON_SIGNET_DESC",
		slot = "Accessory2",
		grade = "D",
		reqLevel = 8,
		sellPrice = 210,
		bonuses = {
			mDef = 22,
			maxMp = 70,
		},
	},
}

local DEV_GEAR_IDS: { string } = {
	"WPN_BARON_ELITE",
	"ARM_COMMUTER_JACKET",
	"ARM_INSPECTOR_VEST",
	"ARM_BARON_COAT",
	"ARM_CARGO_PANTS",
	"ARM_TACTICAL_PANTS",
	"ARM_RUBBER_BOOTS",
	"ARM_STEEL_BOOTS",
	"ACC_METRO_WATCH",
	"ACC_ALCHEMIST_CHAIN",
	"ACC_TOKEN_RING",
	"ACC_BARON_SIGNET",
}

local VISUAL_STYLES: { [string]: ItemVisualStyle } = {
	-- Weapons (Crimson / Red-Bronze L2 Weapon Tint)
	WPN_STARTER = {
		glyph = "⚔",
		subGlyph = "NG",
		tintTop = Color3.fromRGB(76, 26, 28),
		tintBottom = Color3.fromRGB(28, 10, 12),
		glyphColor = Color3.fromRGB(240, 210, 175),
		borderColor = Color3.fromRGB(135, 95, 70),
	},
	WPN_BARON_ELITE = {
		glyph = "🗡",
		subGlyph = "★",
		tintTop = Color3.fromRGB(115, 28, 38),
		tintBottom = Color3.fromRGB(38, 10, 16),
		glyphColor = Color3.fromRGB(255, 225, 110),
		borderColor = Color3.fromRGB(95, 205, 255),
	},

	-- Chest Armor (Steel / Blue-Grey L2 Armor Tint)
	ARM_COMMUTER_JACKET = {
		glyph = "🧥",
		tintTop = Color3.fromRGB(36, 52, 74),
		tintBottom = Color3.fromRGB(16, 22, 34),
		glyphColor = Color3.fromRGB(215, 230, 250),
		borderColor = Color3.fromRGB(95, 115, 140),
	},
	ARM_INSPECTOR_VEST = {
		glyph = "🛡",
		tintTop = Color3.fromRGB(44, 68, 98),
		tintBottom = Color3.fromRGB(18, 28, 44),
		glyphColor = Color3.fromRGB(175, 225, 255),
		borderColor = Color3.fromRGB(110, 145, 185),
	},
	ARM_BARON_COAT = {
		glyph = "🦺",
		subGlyph = "★",
		tintTop = Color3.fromRGB(58, 86, 128),
		tintBottom = Color3.fromRGB(22, 32, 52),
		glyphColor = Color3.fromRGB(255, 225, 130),
		borderColor = Color3.fromRGB(95, 205, 255),
	},

	-- Legs Armor
	ARM_CARGO_PANTS = {
		glyph = "👖",
		tintTop = Color3.fromRGB(34, 48, 66),
		tintBottom = Color3.fromRGB(15, 20, 30),
		glyphColor = Color3.fromRGB(205, 220, 240),
		borderColor = Color3.fromRGB(90, 108, 130),
	},
	ARM_TACTICAL_PANTS = {
		glyph = "⛓",
		tintTop = Color3.fromRGB(42, 62, 88),
		tintBottom = Color3.fromRGB(18, 26, 40),
		glyphColor = Color3.fromRGB(185, 230, 255),
		borderColor = Color3.fromRGB(105, 140, 175),
	},

	-- Boots Armor
	ARM_RUBBER_BOOTS = {
		glyph = "🥾",
		tintTop = Color3.fromRGB(32, 46, 62),
		tintBottom = Color3.fromRGB(14, 20, 28),
		glyphColor = Color3.fromRGB(205, 215, 235),
		borderColor = Color3.fromRGB(88, 102, 125),
	},
	ARM_STEEL_BOOTS = {
		glyph = "👢",
		tintTop = Color3.fromRGB(45, 64, 90),
		tintBottom = Color3.fromRGB(18, 26, 38),
		glyphColor = Color3.fromRGB(210, 235, 255),
		borderColor = Color3.fromRGB(110, 140, 175),
	},

	-- Jewelry / Accessories (Teal / Gold L2 Accessory Tint)
	ACC_METRO_WATCH = {
		glyph = "⌚",
		tintTop = Color3.fromRGB(24, 66, 68),
		tintBottom = Color3.fromRGB(10, 28, 30),
		glyphColor = Color3.fromRGB(165, 245, 240),
		borderColor = Color3.fromRGB(85, 150, 145),
	},
	ACC_ALCHEMIST_CHAIN = {
		glyph = "📿",
		tintTop = Color3.fromRGB(32, 78, 82),
		tintBottom = Color3.fromRGB(12, 32, 36),
		glyphColor = Color3.fromRGB(190, 255, 250),
		borderColor = Color3.fromRGB(95, 175, 175),
	},
	ACC_TOKEN_RING = {
		glyph = "💍",
		tintTop = Color3.fromRGB(64, 54, 24),
		tintBottom = Color3.fromRGB(26, 22, 10),
		glyphColor = Color3.fromRGB(245, 215, 125),
		borderColor = Color3.fromRGB(145, 125, 70),
	},
	ACC_BARON_SIGNET = {
		glyph = "⚜",
		subGlyph = "★",
		tintTop = Color3.fromRGB(92, 68, 22),
		tintBottom = Color3.fromRGB(36, 26, 10),
		glyphColor = Color3.fromRGB(255, 230, 115),
		borderColor = Color3.fromRGB(95, 205, 255),
	},

	-- Stackable Consumables, Materials & Currencies
	EnchantScrolls = {
		glyph = "📜",
		tintTop = Color3.fromRGB(86, 66, 24),
		tintBottom = Color3.fromRGB(34, 24, 10),
		glyphColor = Color3.fromRGB(255, 230, 130),
		borderColor = Color3.fromRGB(185, 150, 75),
	},
	EnergyShots = {
		glyph = "⚡",
		tintTop = Color3.fromRGB(18, 68, 86),
		tintBottom = Color3.fromRGB(8, 26, 36),
		glyphColor = Color3.fromRGB(120, 245, 255),
		borderColor = Color3.fromRGB(70, 175, 210),
	},
	HpPotions = {
		glyph = "🧪",
		tintTop = Color3.fromRGB(24, 74, 42),
		tintBottom = Color3.fromRGB(10, 28, 16),
		glyphColor = Color3.fromRGB(115, 255, 145),
		borderColor = Color3.fromRGB(75, 175, 105),
	},
	MpPotions = {
		glyph = "💧",
		tintTop = Color3.fromRGB(22, 48, 88),
		tintBottom = Color3.fromRGB(10, 20, 38),
		glyphColor = Color3.fromRGB(115, 215, 255),
		borderColor = Color3.fromRGB(75, 145, 215),
	},
	CrystalShards = {
		glyph = "💎",
		tintTop = Color3.fromRGB(52, 74, 96),
		tintBottom = Color3.fromRGB(20, 30, 42),
		glyphColor = Color3.fromRGB(220, 245, 255),
		borderColor = Color3.fromRGB(135, 185, 225),
	},
	Cash = {
		glyph = "🪙",
		tintTop = Color3.fromRGB(88, 68, 18),
		tintBottom = Color3.fromRGB(36, 26, 8),
		glyphColor = Color3.fromRGB(255, 220, 85),
		borderColor = Color3.fromRGB(195, 160, 70),
	},
	TrashTokens = {
		glyph = "♻",
		tintTop = Color3.fromRGB(22, 72, 58),
		tintBottom = Color3.fromRGB(10, 28, 24),
		glyphColor = Color3.fromRGB(95, 250, 195),
		borderColor = Color3.fromRGB(75, 175, 140),
	},
	QuestTrophy = {
		glyph = "🏆",
		tintTop = Color3.fromRGB(78, 48, 24),
		tintBottom = Color3.fromRGB(32, 18, 10),
		glyphColor = Color3.fromRGB(255, 210, 95),
		borderColor = Color3.fromRGB(175, 135, 65),
	},
}

local DEFAULT_VISUAL_STYLE: ItemVisualStyle = {
	glyph = "◆",
	tintTop = Color3.fromRGB(34, 40, 54),
	tintBottom = Color3.fromRGB(16, 20, 28),
	glyphColor = Color3.fromRGB(215, 225, 240),
	borderColor = Color3.fromRGB(95, 82, 55),
}

local function getItem(itemId: string?): ItemData?
	if not itemId then
		return nil
	end
	return ITEMS_MAP[itemId]
end

local function getItemVisualStyle(itemIdOrKey: string?): ItemVisualStyle
	if not itemIdOrKey then
		return DEFAULT_VISUAL_STYLE
	end
	return VISUAL_STYLES[itemIdOrKey] or DEFAULT_VISUAL_STYLE
end

local ItemsConfig = {
	MAX_BAG_SLOTS = 54,
	EQUIPMENT_SLOTS = EQUIPMENT_SLOTS,
	SLOT_NAME_KEYS = SLOT_NAME_KEYS,
	Items = ITEMS_MAP,
	DEV_GEAR_IDS = DEV_GEAR_IDS,
	GetItem = getItem,
	GetItemVisualStyle = getItemVisualStyle,
}

return ItemsConfig
