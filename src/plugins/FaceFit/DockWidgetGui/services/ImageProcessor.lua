--!strict
-- ImageProcessor — Pure Luau helpers for canvas state math.
-- The full rendering pipeline uses Roblox EditableImage and is tested in Play mode.

local ImageProcessor = {}

export type FacePosition = {
	offsetX: number,
	offsetY: number,
	zoom: number,
	rotation: number,
	snapEnabled: boolean,
}

local ZOOM_MIN = 0.25
local ZOOM_MAX = 4.0
local GRID_PX = 16

function ImageProcessor.clampZoom(zoom: number): number
	return math.clamp(zoom, ZOOM_MIN, ZOOM_MAX)
end

function ImageProcessor.snapToGrid(value: number, grid: number): number
	if grid <= 0 then
		return value
	end
	return math.round(value / grid) * grid
end

function ImageProcessor.wrapRotation(degrees: number): number
	local d = degrees % 360
	if d > 180 then
		d = d - 360
	elseif d < -180 then
		d = d + 360
	end
	return d
end

function ImageProcessor.clampPosition(pos: FacePosition, resolution: number): FacePosition
	local halfRes = resolution / 2
	local newPos: FacePosition = {
		offsetX = math.clamp(pos.offsetX, -halfRes, halfRes),
		offsetY = math.clamp(pos.offsetY, -halfRes, halfRes),
		zoom = ImageProcessor.clampZoom(pos.zoom),
		rotation = ImageProcessor.wrapRotation(pos.rotation),
		snapEnabled = pos.snapEnabled,
	}
	if newPos.snapEnabled then
		newPos.offsetX = ImageProcessor.snapToGrid(newPos.offsetX, GRID_PX)
		newPos.offsetY = ImageProcessor.snapToGrid(newPos.offsetY, GRID_PX)
	end
	return newPos
end

-- Constants exposed for the rendering layer to read without hard-coding.
ImageProcessor.ZOOM_MIN = ZOOM_MIN
ImageProcessor.ZOOM_MAX = ZOOM_MAX
ImageProcessor.GRID_PX = GRID_PX

return ImageProcessor