--!strict
-- FaceMapper — Pure Luau logic for Roblox face texture regions.
-- Roblox face textures place the user image on the head's front face.
-- These constants encode the standard face bounding box per head type / resolution.

local FaceMapper = {}

export type HeadType = "R6" | "R15"
-- Numeric literal-type union (`512 | 1024`) is not accepted by this Studio's
-- Luau parser ("Expected type, got '512'"), so we use `number` and rely on the
-- REGIONS table lookup + assert to enforce the supported set at runtime.
export type Resolution = number
export type FaceRegion = {
	x: number,
	y: number,
	width: number,
	height: number,
	centerX: number,
	centerY: number,
}

-- Internal: standard face region per (headType, resolution).
-- Y-axis convention: Roblox image Y increases downward, so centerY values are
-- measured from top. R6 centers face at full image center; R15 face sits
-- slightly higher (because R15 head mesh's face attachment is upper-front).
local REGIONS: { [HeadType]: { [number]: FaceRegion } } = {
	R6 = {
		[512] = { x = 128, y = 128, width = 256, height = 256, centerX = 256, centerY = 256 },
		[1024] = { x = 256, y = 256, width = 512, height = 512, centerX = 512, centerY = 512 },
	},
	R15 = {
		[512] = { x = 128, y = 72, width = 256, height = 256, centerX = 256, centerY = 200 },
		[1024] = { x = 256, y = 144, width = 512, height = 512, centerX = 512, centerY = 400 },
	},
}

function FaceMapper.getRegion(headType: HeadType, resolution: Resolution): FaceRegion
	local entry = REGIONS[headType]
	assert(entry, "Unknown head type: " .. tostring(headType))
	local region = entry[resolution]
	assert(region, "Unsupported resolution: " .. tostring(resolution))
	return region
end

function FaceMapper.getDefaultHeadType(head: any?): HeadType
	-- The brief's tests mock BaseParts as plain Lua tables with a `ClassName`
	-- field, so we MUST accept both real Roblox Instances AND plain tables.
	-- Only the ClassName value is consulted; everything else is treated as R6.
	if head == nil then
		return "R15"
	end
	if head.ClassName == "MeshPart" then
		return "R15"
	end
	return "R6"
end

return FaceMapper