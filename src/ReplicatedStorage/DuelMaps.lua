-- DuelMaps.lua (ReplicatedStorage ModuleScript)
-- Small registry/interface for 1v1 duel arenas. Shared by server (DuelService,
-- MapBuilder) and client (DuelVoteUI) — contains only client-safe metadata,
-- never building code (that lives server-side in DuelArenaBuilder).
--
-- Adding a new map requires exactly two edits, nothing else:
--   1. One DuelMaps.register({ Id=..., Name=..., Description=... }) call below.
--   2. One builder function keyed by the same Id in DuelArenaBuilder.lua.
-- DuelService, the vote UI, and MapBuilder all iterate this registry generically
-- and never hardcode a map name/id.

local DuelMaps = {}

local order = {}   -- ordered list of Ids (registration order == vote UI order)
local maps = {}     -- [Id] = { Id, Name, Description }

function DuelMaps.register(def)
	assert(type(def) == "table" and type(def.Id) == "string", "DuelMaps.register requires a table with a string Id")
	if not maps[def.Id] then
		table.insert(order, def.Id)
	end
	maps[def.Id] = def
end

function DuelMaps.get(id)
	return maps[id]
end

function DuelMaps.isValid(id)
	return maps[id] ~= nil
end

-- Ordered list of registered map definitions (for vote UI listing).
function DuelMaps.list()
	local out = {}
	for _, id in ipairs(order) do
		table.insert(out, maps[id])
	end
	return out
end

-- Fallback map when nobody votes at all (still deterministic with 1 map).
function DuelMaps.defaultId()
	return order[1]
end

-- Pure tie-break resolver: `idList` is the ordered candidate list, `counts` is
-- { [id] = voteCount }. The single highest count wins; if multiple ids are
-- tied for the lead, the winner is chosen uniformly at random among them.
-- Exposed separately from resolveVote() so tests can exercise the tie-break
-- logic with an arbitrary candidate list instead of mutating the real registry.
function DuelMaps.resolveVoteFrom(idList, counts)
	if not idList or #idList == 0 then return nil end
	counts = counts or {}

	local best = -1
	local leaders = {}
	for _, id in ipairs(idList) do
		local count = counts[id] or 0
		if count > best then
			best = count
			leaders = { id }
		elseif count == best then
			table.insert(leaders, id)
		end
	end

	if #leaders == 1 then return leaders[1] end
	return leaders[math.random(1, #leaders)]
end

-- Resolves a vote using the real registered map order.
function DuelMaps.resolveVote(counts)
	return DuelMaps.resolveVoteFrom(order, counts)
end

-- ============= REGISTERED MAPS =============
-- Map 1 — from the CEO's reference blockout: symmetric bunker crossfire with
-- raised rear spawn bunkers, dense central cover, and a right-side platform.
DuelMaps.register({
	Id = "BunkerCrossfire",
	Name = "BUNKER CROSSFIRE",
	Description = "對稱掩體地圖：後方雙側出生碉堡、密集中央掩體、右側高台，無直線對狙。",
})

return DuelMaps
