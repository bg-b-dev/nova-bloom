-- NOVA BLOOM rules and data, shared by the server (state) and the client (drawing).

local Config = {}

Config.FONT = Enum.Font.FredokaOne
Config.HULLS = 3
Config.COMBO_WINDOW = 3
Config.BOSS_PHASES = 3
Config.LOOP_SPEED_STEP = 0.25

Config.Palette = {
	background = Color3.fromHex("12162B"),
	panel = Color3.fromHex("1E2547"),
	amber = Color3.fromHex("FFB534"),
	teal = Color3.fromHex("3DDBC4"),
	coral = Color3.fromHex("F0596B"),
	sky = Color3.fromHex("5BC8F0"),
	lavender = Color3.fromHex("8E93D6"),
	green = Color3.fromHex("5FD35F"),
	text = Color3.fromHex("F4EEDC"),
}

Config.Modes = { "CAMPAIGN", "ENDLESS" }
Config.ModeLines = { "3 SECTORS · BOSS", "LOOPS · SPEED UP" }

Config.EnemyOrder = { "Drifter", "Weaver", "Monarch" }
Config.Enemies = {
	Drifter = { name = "DRIFTER", line = "flies straight", color = "coral", core = "amber", petals = 5, points = 20, radius = 22, speed = 190, wave = 0 },
	Weaver = { name = "WEAVER", line = "waves and aims", color = "amber", core = "sky", petals = 3, points = 40, radius = 22, speed = 130, wave = 70, fireEvery = 2.4, bulletSpeed = 230 },
	Monarch = { name = "ASH MONARCH", line = "boss · 3 phases", color = "lavender", core = "amber", petals = 8, innerPetals = 6, points = 500, radius = 100, boss = true },
}

Config.Sectors = {
	{ name = "CORAL SHOALS", accent = "coral", stars = 1, enemy = "Drifter", goal = "CLEAR 15 DRIFTERS · KEEP THE COMBO ALIVE", killTarget = 15, spawnEvery = 0.7, spawns = { "Drifter" } },
	{ name = "SOLAR ORCHARD", accent = "amber", stars = 3, enemy = "Weaver", goal = "CLEAR 18 WEAVERS · DODGE THE AIMED SHOTS", killTarget = 18, spawnEvery = 0.85, spawns = { "Weaver", "Weaver", "Drifter" } },
	{ name = "AURORA THRONE", accent = "teal", stars = 5, enemy = "Monarch", goal = "BREAK THE ASH MONARCH · KEEP THE COMBO ALIVE", bossHealth = 600, spawnEvery = 1, spawns = { "Drifter", "Weaver" } },
}

Config.Powers = {
	{ name = "PETAL SPREAD", combo = 10, color = "green" },
	{ name = "COMET LANCE", combo = 25, color = "sky" },
	{ name = "SUPERNOVA", combo = 50, color = "amber", banked = true },
}

Config.Ranks = {
	{ letter = "D", name = "SEEDLING", score = 0 },
	{ letter = "C", name = "SPROUT", score = 4000 },
	{ letter = "B", name = "BUD", score = 12000 },
	{ letter = "A", name = "BLOSSOM", score = 25000 },
	{ letter = "S", name = "FULL BLOOM", score = 40000 },
}

function Config.rankForScore(score)
	local best = Config.Ranks[1]
	for _, rank in Config.Ranks do
		if score >= rank.score then
			best = rank
		end
	end
	return best
end

function Config.bossPhase(health, maxHealth)
	local phases = Config.BOSS_PHASES
	return math.clamp(phases - math.ceil(health / maxHealth * phases) + 1, 1, phases)
end

return Config
