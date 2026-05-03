-- DailyQuestService.lua (ServerScriptService)
-- Per-player daily quest progress + claim. Resets at UTC midnight (lazy: checked on
-- recordEvent / load / claim, not via background timer).
--
-- DataStore: PlayerDailyQuests_v1
--   key = UserId
--   value = { Date = "2026-05-02", Progress = { questId = N, ... }, Claimed = { questId = true, ... } }
--
-- Quest definitions live in GameConfig.DAILY_QUESTS. Other server scripts call
-- DailyQuestService.recordEvent(player, eventType, count) — eventType strings
-- match GameConfig.DAILY_QUESTS[].EventType. Multiple quests on same eventType
-- get incremented in parallel.
--
-- Claim: client fires ClaimDailyQuest with questId; server validates progress
-- and pays via CurrencyService.addDailyReward (bypasses match cap).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local events = ReplicatedStorage:WaitForChild("GameEvents")

local DailyQuestService = {}

local store = DataStoreService:GetDataStore("PlayerDailyQuests_v1")
local data = {}  -- [player] = { Date = "...", Progress = {...}, Claimed = {...} }

local function todayUTC()
	return os.date("!%Y-%m-%d")
end

local function newEmptyState()
	return { Date = todayUTC(), Progress = {}, Claimed = {} }
end

-- Reset Progress + Claimed if Date drifted past today's UTC date.
-- Returns true if reset happened.
local function ensureFreshDay(entry)
	if entry.Date ~= todayUTC() then
		entry.Date = todayUTC()
		entry.Progress = {}
		entry.Claimed = {}
		return true
	end
	return false
end

local function pushUpdate(player)
	local entry = data[player]
	if not entry then return end
	local ev = events:FindFirstChild("DailyQuestUpdate")
	if ev then
		ev:FireClient(player, {
			Date = entry.Date,
			Progress = entry.Progress,
			Claimed = entry.Claimed,
		})
	end
end

local function loadPlayer(player)
	local entry = newEmptyState()
	local ok, result = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if ok and type(result) == "table" and type(result.Date) == "string" then
		entry.Date = result.Date
		entry.Progress = (type(result.Progress) == "table") and result.Progress or {}
		entry.Claimed = (type(result.Claimed) == "table") and result.Claimed or {}
	elseif not ok then
		warn("[DailyQuestService] Load failed for " .. player.Name .. ": " .. tostring(result))
	end
	ensureFreshDay(entry)  -- if loaded from yesterday, reset
	data[player] = entry
	pushUpdate(player)
	print(string.format("[DailyQuestService] Loaded %s (date=%s)", player.Name, entry.Date))
end

local function savePlayer(player)
	local entry = data[player]
	if not entry then return end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), entry)
	end)
	if not ok then
		warn("[DailyQuestService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DailyQuestService.getState(player)
	return data[player]
end

-- Record progress on every quest matching eventType.
-- count: amount to add (e.g. 1 per kill, 60 for 1 minute survived)
function DailyQuestService.recordEvent(player, eventType, count)
	local entry = data[player]
	if not entry then return end
	count = count or 1
	if count <= 0 then return end

	-- Lazy reset on day rollover (player might play across midnight)
	if ensureFreshDay(entry) then pushUpdate(player) end

	local changed = false
	for _, quest in ipairs(GameConfig.DAILY_QUESTS) do
		if quest.EventType == eventType then
			local current = entry.Progress[quest.Id] or 0
			-- Cap progress at target so the saved value stays bounded
			local newVal = math.min(current + count, quest.Target)
			if newVal ~= current then
				entry.Progress[quest.Id] = newVal
				changed = true
			end
		end
	end
	if changed then pushUpdate(player) end
end

-- Try to claim a quest reward. Returns success: bool, reason: string
-- Reasons: "ok" / "unknown" (bad questId) / "incomplete" / "claimed" / "noservice"
function DailyQuestService.tryClaim(player, questId)
	local entry = data[player]
	if not entry then return false, "noservice" end
	ensureFreshDay(entry)

	local quest = nil
	for _, q in ipairs(GameConfig.DAILY_QUESTS) do
		if q.Id == questId then quest = q; break end
	end
	if not quest then return false, "unknown" end
	if entry.Claimed[questId] then return false, "claimed" end
	local progress = entry.Progress[questId] or 0
	if progress < quest.Target then return false, "incomplete" end

	if not _G.CurrencyService or not _G.CurrencyService.addDailyReward then
		return false, "noservice"
	end
	_G.CurrencyService.addDailyReward(player, quest.Reward, "Daily: " .. quest.Name)
	entry.Claimed[questId] = true
	pushUpdate(player)
	print(string.format("[DailyQuest] %s claimed %s (+%d coins)", player.Name, questId, quest.Reward))
	return true, "ok"
end

-- ClaimDailyQuest RemoteEvent handler (client → server)
local ClaimDailyQuest = events:WaitForChild("ClaimDailyQuest")
local ClaimDailyQuestResult = events:WaitForChild("ClaimDailyQuestResult")
ClaimDailyQuest.OnServerEvent:Connect(function(player, questId)
	if type(questId) ~= "string" then return end
	local ok, reason = DailyQuestService.tryClaim(player, questId)
	ClaimDailyQuestResult:FireClient(player, ok, reason, questId)
end)

-- Initial-state query for clients (avoid DailyQuestUpdate subscribe race on join)
local GetDailyQuests = events:WaitForChild("GetDailyQuests")
GetDailyQuests.OnServerInvoke = function(player)
	local entry = data[player]
	if not entry then return { Date = todayUTC(), Progress = {}, Claimed = {} } end
	ensureFreshDay(entry)
	return { Date = entry.Date, Progress = entry.Progress, Claimed = entry.Claimed }
end

-- Lifecycle
Players.PlayerAdded:Connect(loadPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	data[player] = nil
end)

game:BindToClose(function()
	for player, _ in pairs(data) do savePlayer(player) end
end)

_G.DailyQuestService = DailyQuestService

return DailyQuestService
