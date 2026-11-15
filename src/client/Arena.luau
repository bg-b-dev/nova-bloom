-- The play field: moves and draws the ship, shots, enemies, bullets and the boss.
-- It reports shots, kills and hits to the server. The server decides the score and the combo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local palette = Ui.palette
local FIELD_WIDTH, FIELD_HEIGHT = 1000, 400
local SHIP_SPEED = 380
local SHOT_SPEED = 760
local FIRE_INTERVAL = 0.16
local SHIELD_SECONDS = 2.5
local MAX_BLOOMS = 70
local SPREAD_ANGLES = { -0.16, 0, 0.16 }
local STRAIGHT_ANGLES = { 0 }
local BULLET_COLORS = { palette.coral, palette.amber, palette.green, palette.sky }
local MOVE_KEYS = {
	[Enum.KeyCode.W] = Vector2.new(0, -1),
	[Enum.KeyCode.S] = Vector2.new(0, 1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
}
local spreadPower, lancePower = Config.Powers[1], Config.Powers[2]

local Arena = {}
local field, ship, boss, bossTag, sendInput
local shots, enemies, bullets, blooms, killSpots = {}, {}, {}, {}, {}
local sector = Config.Sectors[1]
local speedScale = 1
local clock, fireCooldown, spawnCooldown, shieldedUntil = 0, 0, 0, 0

local function place(entity)
	entity.frame.Position = UDim2.fromOffset(entity.x, entity.y)
end

local function touches(first, second)
	local dx, dy = first.x - second.x, first.y - second.y
	local reach = first.radius + second.radius
	return dx * dx + dy * dy <= reach * reach
end

local function removeAll(list)
	for _, entity in list do
		entity.frame:Destroy()
	end
	table.clear(list)
end

local function sweep(list, stepEntity, dt)
	for index = #list, 1, -1 do
		local entity = list[index]
		if stepEntity(entity, dt) then
			entity.frame:Destroy()
			table.remove(list, index)
		else
			place(entity)
		end
	end
end

local function buildShip()
	local frame = Ui.make("CanvasGroup", { AnchorPoint = Ui.CENTER, Size = UDim2.fromOffset(88, 46), BackgroundTransparency = 1, ZIndex = 3 }, field)
	Ui.frame(frame, 2, 13, 20, 20, palette.coral, 5).Rotation = 45
	local hull = Ui.frame(frame, 14, 1, 72, 44, Ui.TINT, true)
	Ui.gradient(hull, palette.teal, palette.sky, 0)
	Ui.frame(frame, 46, 13, 20, 20, palette.text, true)
	return frame
end

local function spawnEnemy(kind)
	local stats = Config.Enemies[kind]
	local y = math.random(50, FIELD_HEIGHT - 50)
	local enemy = { kind = kind, stats = stats, x = FIELD_WIDTH + 30, y = y, baseY = y, radius = stats.radius, age = 0, fireCooldown = 1 }
	enemy.frame = Ui.enemyIcon(field, kind, enemy.x, y, stats.radius)
	table.insert(enemies, enemy)
end

local function spawnBoss()
	local stats = Config.Enemies.Monarch
	boss = { stats = stats, x = 740, y = FIELD_HEIGHT / 2, radius = stats.radius, age = 0, fireCooldown = 1.5, spin = 0 }
	boss.frame = Ui.enemyIcon(field, "Monarch", boss.x, boss.y, stats.radius)
	bossTag.Visible = true
end

local function fireBullet(x, y, angle, speed)
	local bullet = { x = x, y = y, vx = math.cos(angle) * speed, vy = math.sin(angle) * speed, radius = 8 }
	bullet.frame = Ui.make("Frame", {
		AnchorPoint = Ui.CENTER,
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = BULLET_COLORS[#bullets % #BULLET_COLORS + 1],
		BorderSizePixel = 0,
		ZIndex = 2,
	}, field)
	Ui.round(bullet.frame)
	Ui.stroke(bullet.frame, palette.background, 2)
	table.insert(bullets, bullet)
end

local function fireVolley(combo)
	local pierce = combo >= lancePower.combo
	for _, angle in if combo >= spreadPower.combo then SPREAD_ANGLES else STRAIGHT_ANGLES do
		local shot = { x = ship.x + 46, y = ship.y, vy = math.sin(angle) * SHOT_SPEED, radius = 9, pierce = pierce }
		shot.frame = Ui.make("Frame", {
			AnchorPoint = Ui.CENTER,
			Size = UDim2.fromOffset(if pierce then 74 else 54, 10),
			Rotation = math.deg(angle),
			BackgroundColor3 = if pierce then palette.sky else palette.teal,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, field)
		Ui.round(shot.frame)
		table.insert(shots, shot)
	end
	sendInput("Shot")
end

local function plantBloom(enemy)
	local frame = Ui.petalFlower(field, enemy.x, enemy.y, 10, palette[enemy.stats.color], palette.text, 5)
	frame.ZIndex = 0
	table.insert(blooms, { frame = frame })
	if #blooms > MAX_BLOOMS then
		table.remove(blooms, 1).frame:Destroy()
	end
end

local function rememberKillSpot(enemy)
	table.insert(killSpots, { x = enemy.x, y = enemy.y })
	if #killSpots > 12 then
		table.remove(killSpots, 1)
	end
end

local function hitShip()
	if clock < shieldedUntil then
		return false
	end
	shieldedUntil = clock + SHIELD_SECONDS
	sendInput("HullHit")
	return true
end

local function moveShip(dt)
	local direction = Vector2.zero
	for key, offset in MOVE_KEYS do
		if UserInputService:IsKeyDown(key) then
			direction += offset
		end
	end
	ship.x = math.clamp(ship.x + direction.X * SHIP_SPEED * dt, 50, FIELD_WIDTH * 0.6)
	ship.y = math.clamp(ship.y + direction.Y * SHIP_SPEED * dt, 30, FIELD_HEIGHT - 30)
	ship.frame.GroupTransparency = if clock < shieldedUntil then 0.5 else 0
	place(ship)
end

local function stepEnemy(enemy, dt)
	local stats = enemy.stats
	enemy.age += dt
	enemy.x -= stats.speed * speedScale * dt
	enemy.y = enemy.baseY + math.sin(enemy.age * 3) * stats.wave
	enemy.frame.Rotation = enemy.age * 70
	if stats.fireEvery and enemy.x > ship.x + 80 then
		enemy.fireCooldown -= dt
		if enemy.fireCooldown <= 0 then
			enemy.fireCooldown = stats.fireEvery
			fireBullet(enemy.x, enemy.y, math.atan2(ship.y - enemy.y, ship.x - enemy.x), stats.bulletSpeed * speedScale)
		end
	end
	return enemy.x < -40 or (touches(enemy, ship) and hitShip())
end

local function stepBullet(bullet, dt)
	bullet.x += bullet.vx * dt
	bullet.y += bullet.vy * dt
	local outside = bullet.x < -20 or bullet.x > FIELD_WIDTH + 20 or bullet.y < -20 or bullet.y > FIELD_HEIGHT + 20
	return outside or (touches(bullet, ship) and hitShip())
end

local function stepShot(shot, dt)
	shot.x += SHOT_SPEED * dt
	shot.y += shot.vy * dt
	local spent = shot.x > FIELD_WIDTH + 40
	for index = #enemies, 1, -1 do
		local enemy = enemies[index]
		if not spent and touches(shot, enemy) then
			plantBloom(enemy)
			rememberKillSpot(enemy)
			sendInput("Kill", enemy.kind)
			enemy.frame:Destroy()
			table.remove(enemies, index)
			spent = not shot.pierce
		end
	end
	if boss and not spent and not shot.hitBoss and touches(shot, boss) then
		shot.hitBoss = true
		sendInput("BossHit")
		spent = not shot.pierce
	end
	return spent
end

local function stepBoss(dt, state)
	local phase = Config.bossPhase(state.bossHealth, state.bossMax)
	boss.age += dt
	boss.y = FIELD_HEIGHT / 2 + 20 + math.sin(boss.age * 0.9) * 36
	boss.frame.Rotation = boss.age * 12
	place(boss)
	bossTag.Position = UDim2.fromOffset(boss.x - 100, boss.y - boss.radius - 46)
	boss.fireCooldown -= dt
	if boss.fireCooldown <= 0 then
		local count = 4 + phase * 3
		boss.fireCooldown = (2.6 - phase * 0.4) / speedScale
		boss.spin += 0.4
		for index = 1, count do
			fireBullet(boss.x, boss.y, boss.spin + index / count * math.pi * 2, 90 + phase * 25)
		end
	end
end

function Arena.build(parent, send)
	sendInput = send
	field = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.fromOffset(FIELD_WIDTH, FIELD_HEIGHT),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, parent)
	ship = { frame = buildShip(), x = 120, y = FIELD_HEIGHT / 2, radius = 18 }
	bossTag = Ui.chip(field, Config.Enemies.Monarch.name, 0, 0, 200, 34, 21, palette.coral, palette.panel, palette.coral)
	bossTag.ZIndex = 4
	bossTag.Visible = false
end

function Arena.enterSector(state, isNewMission)
	removeAll(shots)
	removeAll(enemies)
	removeAll(bullets)
	table.clear(killSpots)
	if boss then
		boss.frame:Destroy()
		boss = nil
	end
	bossTag.Visible = false
	if isNewMission then
		removeAll(blooms)
		ship.x, ship.y, shieldedUntil = 120, FIELD_HEIGHT / 2, 0
	end
	sector = Config.Sectors[state.sector]
	speedScale = 1 + state.loop * Config.LOOP_SPEED_STEP
	spawnCooldown = 1
	if sector.bossHealth then
		spawnBoss()
	end
end

function Arena.step(dt, state)
	clock += dt
	moveShip(dt)
	fireCooldown -= dt
	if fireCooldown <= 0 and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		fireCooldown = FIRE_INTERVAL
		fireVolley(state.combo)
	end
	spawnCooldown -= dt
	if spawnCooldown <= 0 then
		spawnCooldown = sector.spawnEvery / speedScale
		spawnEnemy(sector.spawns[math.random(#sector.spawns)])
	end
	if boss then
		stepBoss(dt, state)
	end
	sweep(enemies, stepEnemy, dt)
	sweep(bullets, stepBullet, dt)
	sweep(shots, stepShot, dt)
end

function Arena.showKill(points, combo)
	local spot = table.remove(killSpots, 1) or boss or ship
	Ui.floatText(field, `+{points}`, spot.x, spot.y, palette.amber, 32)
	Ui.floatText(field, `x{combo}!`, spot.x + 56, spot.y - 34, palette.coral, 26)
end

function Arena.showBossHit(damage)
	if boss then
		Ui.floatText(field, `+{damage * 10}`, boss.x - boss.radius + math.random(-30, 30), boss.y + math.random(-70, 70), palette.green, 28)
	end
end

function Arena.showHullHit()
	Ui.floatText(field, "HULL -1", ship.x + 20, ship.y - 30, palette.coral, 30)
end

function Arena.detonateSupernova()
	removeAll(bullets)
	local ring = Ui.make("Frame", { AnchorPoint = Ui.CENTER, Position = UDim2.fromOffset(ship.x, ship.y), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = palette.amber, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, field)
	Ui.round(ring)
	Ui.tween(ring, 0.9, { Size = UDim2.fromOffset(2200, 2200), BackgroundTransparency = 1 }).Completed:Once(function()
		ring:Destroy()
	end)
end

return Arena
