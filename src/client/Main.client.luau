-- Client entry: draws the backdrop, sends the player's input to the server,
-- and applies each server state to the screens and the play field.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Screens = require(script.Parent:WaitForChild("Screens"))
local Arena = require(script.Parent:WaitForChild("Arena"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inputRemote = remotes:WaitForChild("Input")
local stateRemote = remotes:WaitForChild("State")

local palette = Ui.palette
local DESIGN_SIZE = Vector2.new(1280, 720)
local MENU_BLOOM = 0.7
local SECTOR_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local NEBULAE = {
	{ x = 0.78, y = 0.2, size = 0.6, color = "lavender", turn = 40 },
	{ x = 0.16, y = 0.74, size = 0.55, color = "teal", turn = 220 },
	{ x = 0.5, y = 0.06, size = 0.45, color = "coral", turn = 100 },
	{ x = 0.9, y = 0.86, size = 0.4, color = "sky", turn = 300 },
	{ x = 0.38, y = 0.5, size = 0.38, color = "amber", turn = 160 },
}

local selection = { sector = 1, mode = 1 }
local state = { screen = "title", best = 0, combo = 0 }
local nebulae = {}

local function sendInput(action, ...)
	inputRemote:FireServer(action, ...)
end

local function buildBackdrop(gui)
	local backdrop = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.TINT, BorderSizePixel = 0 }, gui)
	Ui.gradient(backdrop, palette.background:Lerp(palette.lavender, 0.14), palette.background:Lerp(Color3.new(0, 0, 0), 0.3), 60)
	for _, spec in NEBULAE do
		local cloud = Ui.make("Frame", {
			AnchorPoint = Ui.CENTER,
			Position = UDim2.fromScale(spec.x, spec.y),
			Size = UDim2.fromScale(spec.size, spec.size),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundColor3 = palette[spec.color],
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
		}, backdrop)
		Ui.round(cloud)
		Ui.make("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = spec.turn }, cloud)
		table.insert(nebulae, cloud)
	end
	for _ = 1, 90 do
		local size = math.random(2, 4)
		local dust = Ui.make("Frame", {
			Position = UDim2.fromScale(math.random(), math.random()),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = palette.text,
			BackgroundTransparency = 0.3 + math.random() * 0.5,
			BorderSizePixel = 0,
		}, backdrop)
		Ui.round(dust)
	end
end

local function tintBackdrop(bloom)
	for _, cloud in nebulae do
		Ui.tween(cloud, 0.6, { BackgroundTransparency = 0.9 - 0.32 * bloom })
	end
end

local function bloomLevel(newState)
	if newState.screen ~= "play" then
		return MENU_BLOOM
	end
	return math.clamp(newState.combo / 40 + newState.kills / 120, 0, 1)
end

local function buildRoot(gui)
	local root = Ui.make("Frame", { AnchorPoint = Ui.CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DESIGN_SIZE.X, DESIGN_SIZE.Y), BackgroundTransparency = 1 }, gui)
	local scale = Ui.make("UIScale", {}, root)
	local camera = workspace.CurrentCamera
	local function fitRootToViewport()
		scale.Scale = math.min(camera.ViewportSize.X / DESIGN_SIZE.X, camera.ViewportSize.Y / DESIGN_SIZE.Y)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitRootToViewport)
	fitRootToViewport()
	return root
end

local actions = {}

function actions.selectSector(index)
	selection.sector = index
	Screens.renderTitle(selection, state.best)
end

function actions.selectMode(index)
	selection.mode = index
	Screens.renderTitle(selection, state.best)
end

function actions.toggleMode()
	actions.selectMode(selection.mode % #Config.Modes + 1)
end

function actions.launch()
	sendInput("Launch", selection.sector, selection.mode)
end

function actions.openMenu()
	sendInput("Menu")
end

function actions.fireSupernova()
	sendInput("Supernova")
end

local keyActions = {
	title = { [Enum.KeyCode.Tab] = actions.toggleMode, [Enum.KeyCode.Return] = actions.launch },
	play = { [Enum.KeyCode.Space] = actions.fireSupernova },
	debrief = { [Enum.KeyCode.Return] = actions.launch, [Enum.KeyCode.M] = actions.openMenu },
}
for index, key in SECTOR_KEYS do
	keyActions.title[key] = function()
		actions.selectSector(index)
	end
end

local function handleKey(input)
	local action = keyActions[state.screen][input.KeyCode]
	if action then
		action()
	end
end

local eventFeedback = {
	launch = function(newState)
		Arena.enterSector(newState, true)
	end,
	sector = function(newState)
		local sector = Config.Sectors[newState.sector]
		Arena.enterSector(newState, false)
		Screens.announce(`SECTOR {newState.sector} · {sector.name}`, palette[sector.accent])
	end,
	kill = function(newState, points)
		Arena.showKill(points, newState.combo)
	end,
	bossHit = function(_, damage)
		Arena.showBossHit(damage)
	end,
	hullHit = Arena.showHullHit,
	supernova = Arena.detonateSupernova,
	debrief = Screens.renderDebrief,
}

local function announceNewPowers(previousCombo, combo)
	for _, power in Config.Powers do
		if previousCombo < power.combo and combo >= power.combo then
			Screens.announce(`{power.name} ONLINE`, palette[power.color])
		end
	end
end

local function applyServerState(newState, event, detail)
	local previousCombo = state.combo
	state = newState
	local feedback = eventFeedback[event]
	if feedback then
		feedback(newState, detail)
	end
	announceNewPowers(previousCombo, newState.combo)
	Screens.show(newState.screen)
	Screens.renderTitle(selection, newState.best)
	Screens.renderHud(newState)
	tintBackdrop(bloomLevel(newState))
end

local function stepFrame(dt)
	if state.screen == "play" then
		Arena.step(math.min(dt, 0.05), state)
		Screens.renderClock(state, workspace:GetServerTimeNow())
	end
end

pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

local gui = Ui.make("ScreenGui", { Name = "NovaBloom", ResetOnSpawn = false, IgnoreGuiInset = true }, Players.LocalPlayer:WaitForChild("PlayerGui"))
buildBackdrop(gui)
local screens = Screens.build(buildRoot(gui), actions)
Arena.build(screens.play, sendInput)
Screens.renderTitle(selection, state.best)
Screens.show(state.screen)
tintBackdrop(MENU_BLOOM)

stateRemote.OnClientEvent:Connect(applyServerState)
UserInputService.InputBegan:Connect(handleKey)
RunService.RenderStepped:Connect(stepFrame)
