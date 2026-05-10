-- CurrencyMath.spec.lua
-- Pure-logic tests for ServerStorage.CurrencyMath. Covers per-category caps,
-- total cap, and clamp behavior. No DataStore / Players / RemoteEvent dependencies.

local ServerStorage = game:GetService("ServerStorage")
local CurrencyMath = require(ServerStorage:WaitForChild("CurrencyMath"))

return function()
	-- Mirrors GameConfig.ECONOMY.MatchCaps; copied locally so tests don't break
	-- if config tuning changes.
	local caps = {
		NpcKills    = 300,
		Survival    = 200,
		PlayerKills = 600,
		MatchTotal  = 1500,
	}

	local function freshEarned()
		return { NpcKills = 0, Survival = 0, PlayerKills = 0, Total = 0 }
	end

	describe("computeAppliedAmount", function()
		it("returns 0 for non-positive amount", function()
			expect(CurrencyMath.computeAppliedAmount(caps, freshEarned(), 0, "NpcKills")).to.equal(0)
			expect(CurrencyMath.computeAppliedAmount(caps, freshEarned(), -5, "NpcKills")).to.equal(0)
		end)

		it("applies the full amount when no caps are hit", function()
			expect(CurrencyMath.computeAppliedAmount(caps, freshEarned(), 50, "NpcKills")).to.equal(50)
			expect(CurrencyMath.computeAppliedAmount(caps, freshEarned(), 50, nil)).to.equal(50)
		end)

		it("clamps to the per-category cap when partially full", function()
			local earned = freshEarned()
			earned.NpcKills = 290  -- 10 headroom under cap of 300
			earned.Total = 290
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 100, "NpcKills")).to.equal(10)
		end)

		it("returns 0 when category cap is exhausted", function()
			local earned = freshEarned()
			earned.NpcKills = 300
			earned.Total = 300
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 50, "NpcKills")).to.equal(0)
		end)

		it("clamps to the total cap when partially full", function()
			local earned = freshEarned()
			-- Total at 1480 (20 headroom under MatchTotal 1500); per-category clean
			earned.PlayerKills = 580  -- under PlayerKills cap of 600
			earned.Total = 1480
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 100, "PlayerKills")).to.equal(20)
		end)

		it("returns 0 when total cap is exhausted", function()
			local earned = freshEarned()
			earned.Total = 1500
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 100, "PlayerKills")).to.equal(0)
		end)

		it("ignores per-category cap when category is nil but still enforces total", function()
			local earned = freshEarned()
			earned.NpcKills = 300  -- category cap full, but caller passes nil
			earned.Total = 300
			-- nil category → category cap skipped; total cap has 1200 headroom
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 500, nil)).to.equal(500)
		end)

		it("ignores per-category cap for an unknown category string", function()
			-- caps doesn't have a "Loot" entry; category cap is skipped, total enforced
			local earned = freshEarned()
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 50, "Loot")).to.equal(50)
		end)

		it("takes the smaller of category and total caps when both are near", function()
			local earned = freshEarned()
			-- Category headroom: 300 - 280 = 20
			-- Total headroom: 1500 - 1490 = 10
			-- Smaller wins: 10
			earned.NpcKills = 280
			earned.Total = 1490
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 100, "NpcKills")).to.equal(10)
		end)

		it("handles exact-fit cap (amount == headroom)", function()
			local earned = freshEarned()
			earned.NpcKills = 290
			earned.Total = 290
			expect(CurrencyMath.computeAppliedAmount(caps, earned, 10, "NpcKills")).to.equal(10)
		end)
	end)
end
