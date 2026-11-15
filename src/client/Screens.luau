-- Builds the three screens (title, play HUD, debrief) and renders the server state into them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local palette = Ui.palette
local LEFT = Enum.TextXAlignment.Left
local DIVIDER = palette.lavender:Lerp(palette.panel, 0.6)
local CHIP_COLORS = { "coral", "amber", "teal", "sky" }
local CHIP_WIDTHS = { 124, 124, 186, 104 }
local DECOR_FLOWERS = {
	{ 90, 140, "coral" }, { 1190, 120, "teal" }, { 112, 360, "green" },
	{ 1172, 330, "sky" }, { 60, 600, "amber" }, { 1220, 610, "lavender" },
}
local STAT_CARDS = {
	{ key = "score", title = "SCORE", color = "amber" },
	{ key = "kills", title = "KILLS", color = "text" },
	{ key = "maxCombo", title = "MAX COMBO", color = "coral" },
	{ key = "accuracy", title = "ACCURACY", color = "sky" },
	{ key = "time", title = "TIME", color = "green" },
}

local Screens = {}
local screens = {}
local view = { cards = {}, modes = {}, powers = {}, hulls = {}, stats = {} }
local curtain, shownScreen

local function formatScore(score)
	return (string.format("%07d", score):gsub("(%d)(%d%d%d)(%d%d%d)", "%1 %2 %3"))
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function accuracyPercent(state)
	return if state.shots > 0 then math.floor(state.hits / state.shots * 100) else 0
end

local function newScreen(root, name)
	local screen = Ui.make("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, root)
	screens[name] = screen
	return screen
end

local function scatterFlowers(screen)
	for _, spot in DECOR_FLOWERS do
		Ui.petalFlower(screen, spot[1], spot[2], 24, palette[spot[3]], palette.text, 6)
	end
end

local function buildCountChips(screen)
	local counts = { `{#Config.Sectors} SECTORS`, `{#Config.EnemyOrder} ENEMIES`, `{#Config.Powers} COMBO POWERS`, `{#Config.Modes} MODES` }
	local x = 350
	for index, text in counts do
		local color = palette[CHIP_COLORS[index]]
		Ui.chip(screen, text, x, 172, CHIP_WIDTHS[index], 32, 17, color, palette.panel, color)
		x += CHIP_WIDTHS[index] + 14
	end
end

local function buildSectorCard(screen, index, actions)
	local sector = Config.Sectors[index]
	local enemy = Config.Enemies[sector.enemy]
	local accent = palette[sector.accent]
	local card = Ui.make("TextButton", {
		Position = UDim2.fromOffset(140 + (index - 1) * 340, 234),
		Size = UDim2.fromOffset(320, 266),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}, screen)
	local panel = Ui.panel(card, 0, 0, 320, 258, accent, 2)
	Ui.frame(panel, 0, 0, 320, 10, accent, 5)
	Ui.label(panel, `SECTOR {index}`, 22, 20, 150, 22, 19, accent, LEFT)
	Ui.label(panel, sector.name, 22, 42, 290, 34, 29, palette.text, LEFT)
	local well = Ui.frame(panel, 116, 84, 88, 88, palette.background:Lerp(accent, 0.22), true)
	Ui.enemyIcon(well, sector.enemy, 44, 44, 34)
	Ui.label(panel, enemy.name, 0, 174, 320, 28, 24, accent)
	Ui.label(panel, string.upper(enemy.line), 0, 201, 320, 20, 16, palette.lavender)
	Ui.starRow(panel, 0, 222, 320, sector.stars, accent)
	local tag = Ui.chip(panel, "SELECTED", 212, 18, 94, 24, 14, palette.background, palette.coral)
	card.MouseButton1Click:Connect(function()
		actions.selectSector(index)
	end)
	view.cards[index] = { card = card, home = card.Position, stroke = panel:FindFirstChildOfClass("UIStroke"), tag = tag }
end

local function buildModeSwitch(screen, actions)
	Ui.label(screen, "MODE", 0, 512, 1280, 24, 19, palette.lavender)
	local track = Ui.frame(screen, 440, 540, 400, 52, palette.panel, true)
	Ui.stroke(track, DIVIDER, 2)
	view.modeThumb = Ui.frame(track, 4, 4, 196, 44, Ui.TINT, true)
	Ui.gradient(view.modeThumb, palette.teal, palette.sky, 0)
	for index, name in Config.Modes do
		local button = Ui.make("TextButton", {
			Position = UDim2.fromOffset(4 + (index - 1) * 196, 4),
			Size = UDim2.fromOffset(196, 44),
			BackgroundTransparency = 1,
			Text = name,
			Font = Config.FONT,
			TextSize = 26,
		}, track)
		button.MouseButton1Click:Connect(function()
			actions.selectMode(index)
		end)
		local line = Ui.label(screen, Config.ModeLines[index], 444 + (index - 1) * 196, 596, 196, 18, 14, palette.lavender)
		view.modes[index] = { button = button, line = line }
	end
end

local function buildTitle(screen, actions)
	scatterFlowers(screen)
	Ui.gradientTitle(screen, "NOVA BLOOM", 16, 112, palette.amber, palette.coral)
	Ui.label(screen, "MAKE DEAD SPACE BLOOM AGAIN", 0, 134, 1280, 30, 25, palette.lavender)
	buildCountChips(screen)
	for index in Config.Sectors do
		buildSectorCard(screen, index, actions)
	end
	buildModeSwitch(screen, actions)
	Ui.button(screen, "LAUNCH", 500, 624, 280, 62, palette.amber, palette.amber:Lerp(palette.coral, 0.4), actions.launch)
	view.best = Ui.label(screen, "BEST 0", 880, 638, 380, 36, 30, palette.teal, LEFT)
	Ui.label(screen, "[WASD] MOVE · [MOUSE] FIRE · [SPACE] SUPERNOVA · [1-3] SECTOR · [TAB] MODE · [ENTER] LAUNCH", 0, 694, 1280, 20, 15, palette.lavender)
end

local function buildLegend(screen)
	local legend = Ui.panel(screen, 1010, 112, 258, 432)
	Ui.label(legend, "THREATS", 20, 14, 220, 22, 18, palette.lavender, LEFT)
	for index, kind in Config.EnemyOrder do
		local enemy = Config.Enemies[kind]
		local color = palette[enemy.color]
		local rowY = 44 + (index - 1) * 58
		local well = Ui.frame(legend, 18, rowY, 46, 46, palette.background:Lerp(color, 0.22), true)
		Ui.enemyIcon(well, kind, 23, 23, 18)
		Ui.label(legend, enemy.name, 76, rowY - 2, 180, 28, if #enemy.name > 8 then 20 else 24, color, LEFT)
		Ui.label(legend, enemy.line, 76, rowY + 25, 180, 18, 16, palette.lavender, LEFT)
	end
	Ui.frame(legend, 20, 226, 218, 2, DIVIDER)
	Ui.label(legend, "COMBO POWERS", 20, 238, 220, 22, 18, palette.lavender, LEFT)
	for index, power in Config.Powers do
		local color = palette[power.color]
		local rowY = 270 + (index - 1) * 50
		view.powers[index] = {
			color = color,
			chip = Ui.chip(legend, `x{power.combo}`, 18, rowY, 52, 34, 18, color, palette.panel, color),
			name = Ui.label(legend, power.name, 82, rowY, 174, 34, 20, palette.lavender, LEFT),
		}
	end
end

local function buildBottomPanel(screen)
	local bottom = Ui.frame(screen, 0, 558, 1280, 162, Ui.TINT)
	Ui.gradient(bottom, palette.panel:Lerp(palette.lavender, 0.1), palette.background)
	Ui.gradient(Ui.frame(screen, 0, 555, 1280, 4, Ui.TINT), palette.teal, palette.sky, 0)
	Ui.label(bottom, "HULL", 40, 22, 120, 22, 19, palette.lavender, LEFT)
	for index = 1, Config.HULLS do
		local hull = Ui.frame(bottom, 40 + (index - 1) * 62, 66, 52, 52, Ui.TINT, true)
		Ui.gradient(hull, palette.teal, palette.sky, 0)
		Ui.stroke(hull, palette.teal, 3)
		view.hulls[index] = hull
	end
	Ui.frame(bottom, 270, 22, 2, 120, DIVIDER)
	view.sector = Ui.label(bottom, "", 296, 14, 560, 36, 29, palette.text, LEFT)
	view.sectorStars = Ui.starRow(bottom, 296, 56, 300, 1, palette.teal, LEFT)
	view.kills = Ui.label(bottom, "", 296, 102, 160, 34, 28, palette.sky, LEFT)
	view.accuracy = Ui.label(bottom, "", 458, 102, 230, 34, 28, palette.green, LEFT)
	view.time = Ui.label(bottom, "", 692, 102, 166, 34, 28, palette.lavender, LEFT)
	Ui.frame(bottom, 862, 22, 2, 120, DIVIDER)
	Ui.label(bottom, "SUPERNOVA", 890, 22, 200, 22, 19, palette.lavender, LEFT)
	view.supernova = Ui.bar(bottom, 890, 56, 360, 34, palette.amber, palette.coral)
	view.supernovaHint = Ui.label(bottom, "", 890, 104, 360, 28, 20, palette.amber)
end

local function buildHud(screen)
	local scorePanel = Ui.panel(screen, 420, 10, 440, 78)
	Ui.label(scorePanel, "SCORE", 0, 6, 440, 18, 16, palette.lavender)
	view.score = Ui.label(scorePanel, "", 0, 24, 440, 48, 42, palette.text)
	view.goal = Ui.label(screen, "", 200, 90, 880, 26, 21, palette.amber)
	local comboPanel = Ui.panel(screen, 1010, 10, 258, 90, palette.amber, 3)
	view.combo = Ui.label(comboPanel, "", 0, 6, 258, 46, 38, Ui.TINT)
	Ui.gradient(view.combo, palette.amber, palette.coral, 0)
	view.comboTimer = Ui.bar(comboPanel, 20, 58, 218, 20, palette.amber, palette.coral)
	buildLegend(screen)
	view.bossRow = Ui.make("Frame", { Position = UDim2.fromOffset(0, 510), Size = UDim2.fromOffset(1010, 40), BackgroundTransparency = 1 }, screen)
	view.phase = Ui.label(view.bossRow, "", 28, 4, 112, 30, 20, palette.coral, LEFT)
	view.bossBar = Ui.bar(view.bossRow, 142, 5, 810, 28, palette.coral, palette.coral:Lerp(palette.text, 0.4))
	view.bossPercent = Ui.label(view.bossRow, "", 958, 4, 50, 30, 19, palette.text, LEFT)
	buildBottomPanel(screen)
	view.banner = Ui.label(screen, "", 150, 122, 700, 46, 36, palette.text)
	Ui.make("UIStroke", { Color = palette.background, Thickness = 4 }, view.banner)
end

local function buildDebrief(screen, actions)
	scatterFlowers(screen)
	view.result, view.resultGradient = Ui.gradientTitle(screen, "", 22, 96, palette.teal, palette.sky)
	view.reason = Ui.label(screen, "", 0, 134, 1280, 32, 25, palette.text)
	for index, card in STAT_CARDS do
		local color = palette[card.color]
		local panel = Ui.panel(screen, 70 + (index - 1) * 232, 196, 212, 150)
		Ui.frame(panel, 70, 0, 72, 6, color, 3)
		Ui.label(panel, card.title, 0, 26, 212, 24, 21, palette.lavender)
		view.stats[card.key] = Ui.label(panel, "", 0, 64, 212, 62, 50, color)
	end
	local badge = Ui.panel(screen, 563, 376, 154, 154, palette.amber, 4)
	view.rank = Ui.label(badge, "", 0, 12, 154, 130, 112, Ui.TINT)
	Ui.gradient(view.rank, palette.amber, palette.coral)
	Ui.label(screen, "RANK", 760, 416, 200, 24, 21, palette.lavender, LEFT)
	view.rankName = Ui.label(screen, "", 760, 442, 400, 36, 30, palette.amber, LEFT)
	local letters = {}
	for index, rank in Config.Ranks do
		letters[index] = rank.letter
	end
	Ui.label(screen, table.concat(letters, " · "), 760, 482, 300, 22, 17, palette.lavender, LEFT)
	view.newBest = Ui.label(screen, "NEW BEST!", 0, 538, 1280, 36, 28, palette.amber)
	Ui.button(screen, "PLAY AGAIN", 360, 592, 300, 74, palette.amber, palette.amber:Lerp(palette.coral, 0.4), actions.launch)
	Ui.button(screen, "MENU", 690, 592, 230, 74, palette.lavender:Lerp(palette.text, 0.3), palette.lavender, actions.openMenu)
	Ui.label(screen, "[ENTER] PLAY AGAIN · [M] MENU", 0, 688, 1280, 20, 16, palette.lavender)
end

function Screens.build(root, actions)
	buildTitle(newScreen(root, "title"), actions)
	buildHud(newScreen(root, "play"))
	buildDebrief(newScreen(root, "debrief"), actions)
	curtain = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = palette.background, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10 }, root)
	return screens
end

function Screens.show(name)
	if shownScreen == name then
		return
	end
	shownScreen = name
	Ui.tween(curtain, 0.2, { BackgroundTransparency = 0 }).Completed:Once(function()
		for screenName, screen in screens do
			screen.Visible = screenName == shownScreen
		end
		Ui.tween(curtain, 0.3, { BackgroundTransparency = 1 })
	end)
end

function Screens.announce(text, color)
	view.banner.Text = text
	view.banner.TextColor3 = color
	view.banner.TextTransparency = 0
	view.banner.UIStroke.Transparency = 0
	Ui.tween(view.banner, 1.8, { TextTransparency = 1 })
	Ui.tween(view.banner.UIStroke, 1.8, { Transparency = 1 })
end

function Screens.renderTitle(selection, best)
	for index, card in view.cards do
		local selected = index == selection.sector
		card.tag.Visible = selected
		card.stroke.Thickness = if selected then 5 else 2
		Ui.tween(card.card, 0.15, { Position = card.home - UDim2.fromOffset(0, if selected then 14 else 0) })
	end
	Ui.tween(view.modeThumb, 0.15, { Position = UDim2.fromOffset(4 + (selection.mode - 1) * 196, 4) })
	for index, mode in view.modes do
		local active = index == selection.mode
		mode.button.TextColor3 = if active then palette.background else palette.lavender
		mode.line.TextColor3 = if active then palette.teal else palette.lavender
	end
	view.best.Text = `BEST {best}`
end

function Screens.renderHud(state)
	local sector = Config.Sectors[state.sector]
	local supernova = Config.Powers[#Config.Powers]
	view.score.Text = formatScore(state.score)
	view.goal.Text = sector.goal
	view.combo.Text = `COMBO x{state.combo}`
	for index, power in Config.Powers do
		local widget = view.powers[index]
		local lit = state.combo >= power.combo or (power.banked and state.supernovaReady)
		widget.chip.BackgroundColor3 = if lit then widget.color else palette.panel
		widget.chip.TextColor3 = if lit then palette.background else widget.color
		widget.name.TextColor3 = if lit then palette.text else palette.lavender
	end
	view.bossRow.Visible = state.bossMax > 0
	if state.bossMax > 0 then
		local fraction = state.bossHealth / state.bossMax
		Ui.setBar(view.bossBar, fraction)
		view.phase.Text = `PHASE {Config.bossPhase(state.bossHealth, state.bossMax)}/{Config.BOSS_PHASES}`
		view.bossPercent.Text = `{math.ceil(fraction * 100)}%`
	end
	for index, hull in view.hulls do
		hull.BackgroundTransparency = if index <= state.hulls then 0 else 0.9
	end
	view.sector.Text = `SECTOR {state.sector} · {sector.name}{if state.loop > 0 then ` · LOOP {state.loop + 1}` else ""}`
	Ui.setStars(view.sectorStars, sector.stars, palette[sector.accent])
	view.kills.Text = `KILLS {state.kills}`
	view.accuracy.Text = `ACCURACY {accuracyPercent(state)}%`
	Ui.setBar(view.supernova, if state.supernovaReady then 1 else state.combo / supernova.combo)
	view.supernovaHint.Text = if state.supernovaReady then "READY · PRESS SPACE" else `{state.combo} / {supernova.combo} · SPACE WHEN FULL`
end

function Screens.renderClock(state, now)
	Ui.setBar(view.comboTimer, (state.comboEndsAt - now) / Config.COMBO_WINDOW)
	view.time.Text = `TIME {formatTime(now - state.startedAt)}`
end

function Screens.renderDebrief(state)
	local first = if state.won then palette.teal else palette.coral
	local second = if state.won then palette.sky else palette.amber
	view.result.Text = if state.won then "SPACE IN BLOOM!" else "MISSION FAILED"
	view.resultGradient.Color = ColorSequence.new(first, second)
	view.reason.Text = `{state.reason} · SECTOR {state.sector}/{#Config.Sectors} · {Config.Modes[state.mode]}`
	view.stats.score.Text = string.format("%d", state.score):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	view.stats.kills.Text = tostring(state.kills)
	view.stats.maxCombo.Text = `x{state.maxCombo}`
	view.stats.accuracy.Text = `{accuracyPercent(state)}%`
	view.stats.time.Text = formatTime(state.duration)
	view.rank.Text = state.rank.letter
	view.rankName.Text = state.rank.name
	view.newBest.Visible = state.newBest
end

return Screens
