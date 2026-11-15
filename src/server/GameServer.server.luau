-- The server owns each player's mission: mode, sector, score, combo, hulls and best score.
-- The client only sends input events. Each event is checked here before it changes the state.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local KILL_GAP = 0.03
local BOSS_HIT_GAP = 0.12
local HULL_HIT_GAP = 1

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local inputRemote = Instance.new("RemoteEvent")
inputRemote.Name = "Input"
inputRemote.Parent = remotes
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local sessions = {}
local storeOpened, bestStore = pcall(DataStoreService.GetDataStore, DataStoreService, "NovaBloomBest")

local function serverTime()
	return workspace:GetServerTimeNow()
end

local function loadBestScore(player)
	if not storeOpened then
		return 0
	end
	local loaded, best = pcall(bestStore.GetAsync, bestStore, tostring(player.UserId))
	return if loaded and type(best) == "number" then best else 0
end

local function saveBestScore(player, score)
	if storeOpened then
		pcall(bestStore.SetAsync, bestStore, tostring(player.UserId), score)
	end
end

local function newSession(best)
	return {
		screen = "title", mode = 1, sector = 1, loop = 0,
		score = 0, combo = 0, maxCombo = 0, comboEndsAt = 0,
		hulls = Config.HULLS, kills = 0, sectorKills = 0, shots = 0, hits = 0,
		bossHealth = 0, bossMax = 0, supernovaReady = false,
		startedAt = 0, duration = 0, best = best, won = false, newBest = false,
		lastKill = 0, lastBossHit = 0, lastHullHit = 0,
	}
end

local function sendState(player, event, detail)
	stateRemote:FireClient(player, sessions[player], event, detail)
end

local function enterSector(session, index)
	local bossHealth = Config.Sectors[index].bossHealth
	session.sector = index
	session.sectorKills = 0
	session.bossMax = if bossHealth then bossHealth * (1 + session.loop * Config.LOOP_SPEED_STEP) else 0
	session.bossHealth = session.bossMax
end

local function launchMission(player, session, sectorIndex, modeIndex)
	if not Config.Sectors[sectorIndex] or not Config.Modes[modeIndex] then
		return
	end
	local mission = newSession(session.best)
	mission.screen = "play"
	mission.mode = modeIndex
	mission.startedAt = serverTime()
	enterSector(mission, sectorIndex)
	sessions[player] = mission
	sendState(player, "launch")
end

local function endMission(player, session, won, reason)
	session.screen = "debrief"
	session.won = won
	session.reason = reason
	session.duration = serverTime() - session.startedAt
	session.rank = Config.rankForScore(session.score)
	session.newBest = session.score > session.best
	if session.newBest then
		session.best = session.score
		saveBestScore(player, session.score)
	end
	sendState(player, "debrief")
end

local function advanceSector(player, session)
	local nextIndex = session.sector + 1
	if nextIndex > #Config.Sectors then
		if Config.Modes[session.mode] == "CAMPAIGN" then
			endMission(player, session, true, "ASH MONARCH DEFEATED")
			return
		end
		session.loop += 1
		nextIndex = 1
	end
	enterSector(session, nextIndex)
	sendState(player, "sector")
end

local function breakCombo(session)
	session.combo = 0
	session.comboEndsAt = 0
end

local function scoreComboKill(session, points)
	session.kills += 1
	session.combo += 1
	session.maxCombo = math.max(session.maxCombo, session.combo)
	session.comboEndsAt = serverTime() + Config.COMBO_WINDOW
	session.supernovaReady = session.supernovaReady or session.combo >= Config.Powers[#Config.Powers].combo
	local gained = points * session.combo
	session.score += gained
	return gained
end

local function countHit(session)
	session.hits = math.min(session.hits + 1, session.shots)
end

local function recordShot(_, session)
	session.shots += 1
end

local function recordKill(player, session, kind)
	local enemy = Config.Enemies[kind]
	local now = serverTime()
	if not enemy or enemy.boss or now - session.lastKill < KILL_GAP then
		return
	end
	session.lastKill = now
	session.sectorKills += 1
	countHit(session)
	sendState(player, "kill", scoreComboKill(session, enemy.points))
	local target = Config.Sectors[session.sector].killTarget
	if target and session.sectorKills >= target then
		advanceSector(player, session)
	end
end

local function recordBossHit(player, session)
	local now = serverTime()
	if session.bossHealth <= 0 or now - session.lastBossHit < BOSS_HIT_GAP then
		return
	end
	session.lastBossHit = now
	countHit(session)
	local damage = 4 + math.min(session.combo, 50) // 10
	session.bossHealth = math.max(0, session.bossHealth - damage)
	session.score += damage * 10
	if session.bossHealth > 0 then
		sendState(player, "bossHit", damage)
		return
	end
	sendState(player, "kill", scoreComboKill(session, Config.Enemies.Monarch.points))
	advanceSector(player, session)
end

local function recordHullHit(player, session)
	local now = serverTime()
	if now - session.lastHullHit < HULL_HIT_GAP then
		return
	end
	session.lastHullHit = now
	session.hulls -= 1
	breakCombo(session)
	if session.hulls <= 0 then
		endMission(player, session, false, "HULL LOST")
	else
		sendState(player, "hullHit")
	end
end

local function fireSupernova(player, session)
	if session.supernovaReady then
		session.supernovaReady = false
		sendState(player, "supernova")
	end
end

local function returnToMenu(player, session)
	session.screen = "title"
	sendState(player)
end

local playHandlers = { Shot = recordShot, Kill = recordKill, BossHit = recordBossHit, HullHit = recordHullHit, Supernova = fireSupernova }
local menuHandlers = { Launch = launchMission, Menu = returnToMenu }

local function handleInput(player, action, ...)
	local session = sessions[player]
	if not session or type(action) ~= "string" then
		return
	end
	local handler = if session.screen == "play" then playHandlers[action] else menuHandlers[action]
	if handler then
		handler(player, session, ...)
	end
end

local function expireCombos()
	local now = serverTime()
	for player, session in sessions do
		if session.screen == "play" and session.combo > 0 and now >= session.comboEndsAt then
			breakCombo(session)
			sendState(player, "comboLost")
		end
	end
end

local function startSession(player)
	sessions[player] = newSession(loadBestScore(player))
	sendState(player)
end

local function closeSession(player)
	sessions[player] = nil
end

inputRemote.OnServerEvent:Connect(handleInput)
RunService.Heartbeat:Connect(expireCombos)
Players.PlayerAdded:Connect(startSession)
Players.PlayerRemoving:Connect(closeSession)
for _, player in Players:GetPlayers() do
	task.spawn(startSession, player)
end
