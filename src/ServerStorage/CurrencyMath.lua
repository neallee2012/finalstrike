-- CurrencyMath.lua (ServerStorage/ModuleScript)
-- Pure cap-math for the bullet-coin economy. Extracted from CurrencyService so
-- it can be unit-tested without DataStore / Players / RemoteEvent side effects.
--
-- All functions are referentially transparent: same inputs → same outputs.
-- Mutations to the entry happen only on the entry the caller passes in.

local CurrencyMath = {}

-- Compute how many coins should actually be applied given the caps and the
-- player's current MatchEarned counters. Does NOT mutate inputs.
--
-- caps: { NpcKills, Survival, PlayerKills, MatchTotal }  (all numbers)
-- earned: { NpcKills, Survival, PlayerKills, Total }     (all numbers)
-- amount: number  (>= 0; caller checks)
-- category: "NpcKills" | "Survival" | "PlayerKills" | nil
--
-- Returns: appliedAmount  (>= 0; clamped by caps)
function CurrencyMath.computeAppliedAmount(caps, earned, amount, category)
	if amount <= 0 then return 0 end

	-- Per-category cap (only certain categories have one)
	if category and caps[category] then
		local headroom = caps[category] - earned[category]
		if headroom <= 0 then return 0 end
		amount = math.min(amount, headroom)
	end

	-- Per-match total cap (always enforced)
	local totalHeadroom = caps.MatchTotal - earned.Total
	if totalHeadroom <= 0 then return 0 end
	amount = math.min(amount, totalHeadroom)

	if amount <= 0 then return 0 end
	return amount
end

return CurrencyMath
