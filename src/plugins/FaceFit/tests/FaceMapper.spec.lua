--!strict
-- TestEZ spec for FaceMapper

return function()
	local FaceMapper = require(script.Parent.Parent.DockWidgetGui.services.FaceMapper)

	describe("FaceMapper.getRegion", function()
		it("returns R6 512 face region", function()
			local r = FaceMapper.getRegion("R6", 512)
			expect(r.width).to.equal(256)
			expect(r.height).to.equal(256)
			expect(r.centerX).to.equal(256)
			expect(r.centerY).to.equal(256)
		end)

		it("returns R15 512 face region", function()
			local r = FaceMapper.getRegion("R15", 512)
			expect(r.width).to.equal(256)
			expect(r.height).to.equal(256)
			expect(r.centerX).to.equal(256)
			expect(r.centerY).to.equal(200)
		end)

		it("returns R6 1024 face region (scaled)", function()
			local r = FaceMapper.getRegion("R6", 1024)
			expect(r.width).to.equal(512)
			expect(r.height).to.equal(512)
			expect(r.centerX).to.equal(512)
			expect(r.centerY).to.equal(512)
		end)

		it("returns R15 1024 face region (scaled)", function()
			local r = FaceMapper.getRegion("R15", 1024)
			expect(r.width).to.equal(512)
			expect(r.height).to.equal(512)
			expect(r.centerX).to.equal(512)
			expect(r.centerY).to.equal(400)
		end)
	end)

	describe("FaceMapper.getDefaultHeadType", function()
		it("returns R15 for MeshPart", function()
			-- Mock minimal BasePart-like object
			local fakeMeshPart = { ClassName = "MeshPart", Name = "Head" }
			expect(FaceMapper.getDefaultHeadType(fakeMeshPart :: any)).to.equal("R15")
		end)

		it("returns R6 for Part (non-mesh)", function()
			local fakePart = { ClassName = "Part", Name = "Head" }
			expect(FaceMapper.getDefaultHeadType(fakePart :: any)).to.equal("R6")
		end)

		it("returns R15 default when head is nil", function()
			expect(FaceMapper.getDefaultHeadType(nil)).to.equal("R15")
		end)
	end)
end