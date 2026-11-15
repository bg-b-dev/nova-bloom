-- Styled GUI parts for NOVA BLOOM: panels, buttons, bars, labels and petal art.
-- All art is made from Frames with UICorner, UIStroke and UIGradient.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ui = {}
local palette = Config.Palette
local CENTER = Vector2.new(0.5, 0.5)
local TINT = Color3.new(1, 1, 1)
local DIM_STAR = palette.panel:Lerp(palette.lavender, 0.35):ToHex()

Ui.palette = palette
Ui.CENTER = CENTER
Ui.TINT = TINT

function Ui.make(className, properties, parent)
	local instance = Instance.new(className)
	for name, value in properties do
		instance[name] = value
	end
	instance.Parent = parent
	return instance
end

function Ui.tween(target, seconds, goals)
	local tween = TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

function Ui.round(target, radius)
	return Ui.make("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) }, target)
end

function Ui.stroke(target, color, thickness)
	return Ui.make("UIStroke", { Color = color, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, target)
end

function Ui.gradient(target, first, second, rotation)
	return Ui.make("UIGradient", { Color = ColorSequence.new(first, second), Rotation = rotation or 90 }, target)
end

function Ui.frame(parent, x, y, width, height, color, radius)
	local frame = Ui.make("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
	if radius then
		Ui.round(frame, if radius == true then nil else radius)
	end
	return frame
end

function Ui.shadow(parent, x, y, width, height, radius)
	local shadow = Ui.frame(parent, x, y + 6, width, height, Color3.new(0, 0, 0), radius)
	shadow.BackgroundTransparency = 0.65
	return shadow
end

function Ui.panel(parent, x, y, width, height, strokeColor, strokeThickness)
	Ui.shadow(parent, x, y, width, height, 18)
	local panel = Ui.frame(parent, x, y, width, height, TINT, 18)
	Ui.gradient(panel, palette.panel:Lerp(palette.lavender, 0.14), palette.panel:Lerp(palette.background, 0.5))
	Ui.stroke(panel, strokeColor or palette.lavender:Lerp(palette.panel, 0.5), strokeThickness)
	return panel
end

function Ui.label(parent, text, x, y, width, height, textSize, color, alignment)
	return Ui.make("TextLabel", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		Font = Config.FONT,
		TextSize = textSize,
		TextColor3 = color or palette.text,
		TextXAlignment = alignment or Enum.TextXAlignment.Center,
	}, parent)
end

function Ui.chip(parent, text, x, y, width, height, textSize, textColor, fillColor, strokeColor)
	local chip = Ui.label(parent, text, x, y, width, height, textSize, textColor)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = fillColor
	Ui.round(chip, height / 3)
	if strokeColor then
		Ui.stroke(chip, strokeColor, 2)
	end
	return chip
end

function Ui.gradientTitle(parent, text, y, textSize, first, second)
	local title = Ui.label(parent, text, 0, y, 1280, textSize + 12, textSize, TINT)
	local gradient = Ui.gradient(title, first, second, 0)
	Ui.make("UIStroke", { Color = palette.background, Thickness = 5 }, title)
	return title, gradient
end

function Ui.button(parent, text, x, y, width, height, first, second, onClick)
	Ui.shadow(parent, x, y, width, height, 22)
	local button = Ui.make("TextButton", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = TINT,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = text,
		Font = Config.FONT,
		TextSize = math.floor(height * 0.52),
		TextColor3 = palette.background,
	}, parent)
	Ui.round(button, 22)
	Ui.gradient(button, first, second)
	Ui.stroke(button, second:Lerp(palette.background, 0.35), 2)
	local highlight = Ui.frame(button, 12, 5, width - 24, height * 0.3, palette.text, true)
	highlight.BackgroundTransparency = 0.7
	button.MouseButton1Click:Connect(onClick)
	return button
end

function Ui.bar(parent, x, y, width, height, first, second)
	local track = Ui.frame(parent, x, y, width, height, palette.background, true)
	Ui.stroke(track, palette.lavender:Lerp(palette.background, 0.45), 2)
	local inset = Ui.make("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1 }, track)
	local fill = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TINT, BorderSizePixel = 0 }, inset)
	Ui.round(fill)
	Ui.gradient(fill, first, second, 0)
	local highlight = Ui.make("Frame", { Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -12, 0.3, 0), BackgroundColor3 = palette.text, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, fill)
	Ui.round(highlight)
	return fill
end

function Ui.setBar(fill, fraction)
	fill.Visible = fraction > 0.02
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
end

function Ui.petalFlower(parent, x, y, radius, petalColor, coreColor, petalCount)
	local flower = Ui.make("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		BackgroundTransparency = 1,
	}, parent)
	for index = 1, petalCount do
		local angle = index / petalCount * math.pi * 2
		local petal = Ui.make("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.25, 0.5 + math.sin(angle) * 0.25),
			Size = UDim2.fromScale(0.5, 0.3),
			Rotation = math.deg(angle),
			BackgroundColor3 = TINT,
			BorderSizePixel = 0,
		}, flower)
		Ui.round(petal)
		Ui.gradient(petal, petalColor:Lerp(palette.background, 0.25), petalColor, 0)
	end
	local core = Ui.make("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = coreColor,
		BorderSizePixel = 0,
	}, flower)
	Ui.round(core)
	return flower
end

function Ui.enemyIcon(parent, kind, x, y, radius)
	local enemy = Config.Enemies[kind]
	local icon = Ui.petalFlower(parent, x, y, radius, palette[enemy.color], palette[enemy.core], enemy.petals)
	if enemy.innerPetals then
		Ui.petalFlower(icon, radius, radius, radius * 0.55, palette[enemy.color]:Lerp(palette.text, 0.45), palette.coral, enemy.innerPetals)
	end
	return icon
end

function Ui.setStars(label, count, color)
	label.TextColor3 = color
	label.Text = `{string.rep("★ ", count)}<font color="#{DIM_STAR}">{string.rep("★ ", 5 - count)}</font>`
end

function Ui.starRow(parent, x, y, width, count, color, alignment)
	local label = Ui.label(parent, "", x, y, width, 30, 26, color, alignment)
	label.RichText = true
	Ui.setStars(label, count, color)
	return label
end

function Ui.floatText(parent, text, x, y, color, textSize)
	local label = Ui.label(parent, text, x - 90, y - 20, 180, 40, textSize, color)
	local outline = Ui.make("UIStroke", { Color = palette.background, Thickness = 3 }, label)
	Ui.tween(outline, 0.8, { Transparency = 1 })
	Ui.tween(label, 0.8, { Position = UDim2.fromOffset(x - 90, y - 76), TextTransparency = 1 }).Completed:Once(function()
		label:Destroy()
	end)
end

return Ui
