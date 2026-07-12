-- ReloadLogic.spec.lua
-- Pure-logic tests for authoritative reload state transitions.

local ServerStorage = game:GetService("ServerStorage")
local ReloadLogic = require(ServerStorage:WaitForChild("ReloadLogic"))

return function()
	local function freshData(ammo, reserveAmmo)
		return {
			Ammo = ammo,
			ReserveAmmo = reserveAmmo == nil and 150 or reserveAmmo,
			Weapon = "Phantom Ranger",
			Eliminated = false,
			Reloading = false,
			ReloadToken = 0,
			ReloadEndsAt = 0,
		}
	end

	local rifle = {
		Type = "Rifle",
		MagSize = 30,
		ReloadTime = 2.5,
	}

	describe("reserve pickups", function()
		it("adds rounds without exceeding the magazine-based cap", function()
			local data = freshData(12, 440)

			expect(ReloadLogic.addReserve(data, rifle, 15, 15)).to.equal(10)
			expect(data.ReserveAmmo).to.equal(450)
			expect(ReloadLogic.addReserve(data, rifle, 15, 15)).to.equal(0)
			expect(data.ReserveAmmo).to.equal(450)
		end)

		it("rejects invalid amounts and weapons without magazines", function()
			local data = freshData(12, 10)

			expect(ReloadLogic.addReserve(data, rifle, 0, 15)).to.equal(0)
			expect(ReloadLogic.addReserve(data, { Type = "Knife" }, 15, 15)).to.equal(0)
			expect(data.ReserveAmmo).to.equal(10)
		end)
	end)

	describe("canStart", function()
		it("allows a partial magazine", function()
			expect(ReloadLogic.canStart(freshData(12), rifle)).to.equal(true)
		end)

		it("rejects full magazines, knives, eliminated players, and active reloads", function()
			expect(ReloadLogic.canStart(freshData(30), rifle)).to.equal(false)

			local knife = { Type = "Knife" }
			expect(ReloadLogic.canStart(freshData(0), knife)).to.equal(false)

			local eliminated = freshData(12)
			eliminated.Eliminated = true
			expect(ReloadLogic.canStart(eliminated, rifle)).to.equal(false)

			local active = freshData(12)
			active.Reloading = true
			expect(ReloadLogic.canStart(active, rifle)).to.equal(false)
		end)

		it("rejects empty reserves and invalid weapon timing config", function()
			expect(ReloadLogic.canStart(freshData(12, 0), rifle)).to.equal(false)
			expect(ReloadLogic.canStart(freshData(12), {
				Type = "Rifle",
				MagSize = 0,
				ReloadTime = 2.5,
			})).to.equal(false)
			expect(ReloadLogic.canStart(freshData(12), {
				Type = "Rifle",
				MagSize = 30,
				ReloadTime = 0,
			})).to.equal(false)
		end)
	end)

	describe("start and complete", function()
		it("records an authoritative token, weapon, duration, and end time", function()
			local data = freshData(12)
			local operation = ReloadLogic.start(data, rifle, 100)

			expect(operation.Token).to.equal(1)
			expect(operation.Weapon).to.equal("Phantom Ranger")
			expect(operation.Duration).to.equal(2.5)
			expect(operation.EndsAt).to.equal(102.5)
			expect(data.Reloading).to.equal(true)
		end)

		it("fills the magazine only for the matching operation", function()
			local data = freshData(12)
			local operation = ReloadLogic.start(data, rifle, 100)

			expect(ReloadLogic.complete(data, operation, rifle)).to.equal(true)
			expect(data.Ammo).to.equal(30)
			expect(data.ReserveAmmo).to.equal(132)
			expect(data.Reloading).to.equal(false)
			expect(data.ReloadEndsAt).to.equal(0)
		end)

		it("loads a partial magazine when reserve ammo is low", function()
			local data = freshData(12, 5)
			local operation = ReloadLogic.start(data, rifle, 100)

			expect(ReloadLogic.complete(data, operation, rifle)).to.equal(true)
			expect(data.Ammo).to.equal(17)
			expect(data.ReserveAmmo).to.equal(0)
		end)

		it("rejects completion after elimination", function()
			local data = freshData(12)
			local operation = ReloadLogic.start(data, rifle, 100)
			data.Eliminated = true

			expect(ReloadLogic.complete(data, operation, rifle)).to.equal(false)
			expect(data.Ammo).to.equal(12)
		end)

		it("rejects stale tokens and weapon changes", function()
			local staleData = freshData(12)
			local staleOperation = ReloadLogic.start(staleData, rifle, 100)
			staleData.ReloadToken = staleData.ReloadToken + 1
			expect(ReloadLogic.complete(staleData, staleOperation, rifle)).to.equal(false)

			local changedData = freshData(12)
			local changedOperation = ReloadLogic.start(changedData, rifle, 100)
			changedData.Weapon = "Wraith Scout"
			expect(ReloadLogic.complete(changedData, changedOperation, rifle)).to.equal(false)
		end)
	end)

	describe("cancel", function()
		it("invalidates the operation without changing ammo", function()
			local data = freshData(12)
			local operation = ReloadLogic.start(data, rifle, 100)

			expect(ReloadLogic.cancel(data)).to.equal(true)
			expect(data.Ammo).to.equal(12)
			expect(data.Reloading).to.equal(false)
			expect(ReloadLogic.complete(data, operation, rifle)).to.equal(false)
		end)

		it("returns false while idle but still invalidates stale tokens", function()
			local data = freshData(12)
			local token = data.ReloadToken

			expect(ReloadLogic.cancel(data)).to.equal(false)
			expect(data.ReloadToken).to.equal(token + 1)
		end)

		it("keeps an old operation invalid after a new reload starts", function()
			local data = freshData(12)
			local oldOperation = ReloadLogic.start(data, rifle, 100)
			ReloadLogic.cancel(data)
			local newOperation = ReloadLogic.start(data, rifle, 200)

			expect(ReloadLogic.complete(data, oldOperation, rifle)).to.equal(false)
			expect(ReloadLogic.complete(data, newOperation, rifle)).to.equal(true)
		end)
	end)
end
