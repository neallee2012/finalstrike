-- DuelMaps.spec.lua
-- Pure-logic tests for the 1v1 duel map registry's tie-break vote resolver.
-- Uses resolveVoteFrom (an explicit idList parameter) rather than the real
-- registry so tests never mutate the shared DuelMaps.register() state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DuelMaps = require(ReplicatedStorage:WaitForChild("DuelMaps"))

return function()
	describe("resolveVoteFrom", function()
		it("returns nil for an empty candidate list", function()
			expect(DuelMaps.resolveVoteFrom({}, { A = 5 })).to.equal(nil)
			expect(DuelMaps.resolveVoteFrom(nil, { A = 5 })).to.equal(nil)
		end)

		it("is deterministic with a single candidate regardless of votes", function()
			expect(DuelMaps.resolveVoteFrom({ "OnlyMap" }, {})).to.equal("OnlyMap")
			expect(DuelMaps.resolveVoteFrom({ "OnlyMap" }, { OnlyMap = 2 })).to.equal("OnlyMap")
		end)

		it("picks the single clear leader deterministically", function()
			for _ = 1, 20 do
				expect(DuelMaps.resolveVoteFrom({ "A", "B" }, { A = 2, B = 1 })).to.equal("A")
			end
		end)

		it("never picks a candidate that isn't tied for the lead", function()
			for _ = 1, 200 do
				local winner = DuelMaps.resolveVoteFrom({ "A", "B", "C" }, { A = 3, B = 3, C = 1 })
				expect(winner == "A" or winner == "B").to.equal(true)
			end
		end)

		it("breaks ties across all tied leaders (statistical smoke test)", function()
			local seen = {}
			for _ = 1, 300 do
				local winner = DuelMaps.resolveVoteFrom({ "A", "B", "C" }, { A = 3, B = 3, C = 1 })
				seen[winner] = true
			end
			expect(seen.A).to.equal(true)
			expect(seen.B).to.equal(true)
		end)

		it("treats an all-zero vote (no one voted) as a full tie", function()
			local seen = {}
			for _ = 1, 300 do
				local winner = DuelMaps.resolveVoteFrom({ "A", "B" }, {})
				seen[winner] = true
			end
			expect(seen.A).to.equal(true)
			expect(seen.B).to.equal(true)
		end)
	end)

	describe("registry", function()
		it("registers the first map (BunkerCrossfire) with client-safe metadata", function()
			expect(DuelMaps.isValid("BunkerCrossfire")).to.equal(true)
			local def = DuelMaps.get("BunkerCrossfire")
			expect(def ~= nil).to.equal(true)
			expect(type(def.Name)).to.equal("string")
			expect(DuelMaps.defaultId()).to.equal("BunkerCrossfire")
		end)

		it("rejects unknown map ids", function()
			expect(DuelMaps.isValid("NotARealMap")).to.equal(false)
		end)
	end)
end
