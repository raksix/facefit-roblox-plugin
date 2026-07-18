--!strict
-- GhostRenderer — produces a ghost-template image showing the face bounding box.
-- Used as a semi-transparent overlay on the DockWidget canvas so users see where
-- the face region sits inside the full texture.
--
-- ============================================================================
-- ADAPTATIONS from the task brief
-- ============================================================================
-- The brief's reference code targeted an older draft of the Roblox
-- EditableImage API. The actual current Studio API differs in two ways:
--
--   1. EditableImage:DrawRectangle signature is:
--        DrawRectangle(position: Vector2, size: Vector2, color: Color3,
--                      transparency: number, combineType: ImageCombineType)
--      The brief used (position, size, r, g, b, alpha) — three ints and one
--      alpha byte are combined into a single Color3 + a 0..1 transparency.
--      We translate the brief's "60" (faint) and "180" (border) alpha bytes
--      to 0..1 transparency: 60/255 and 180/255.
--
--   2. EditableImage exposes NO GetContentId() method. The accepted way to
--      reference a runtime EditableImage is via Content.fromObject(asset) on
--      a Content-typed property such as ImageLabel.ImageContent. We therefore
--      return the EditableImage instance (typed here as GhostImage) rather
--      than a string asset URI. The caller in DockWidget.client.lua wraps
--      it: ghostImage.ImageContent = Content.fromObject(ghost).
--
-- Public contract from the brief was `render(headType, resolution) -> string`.
-- Kept the name + parameter shape; adapted the return type to match the real
-- API. ImageLabel.ImageContent works with the returned EditableImage directly.
--
-- No unit tests — the service depends on live Roblox EditableImage APIs and
-- is covered by manual Studio integration testing (per the SDD plan).
-- ============================================================================

local AssetService = game:GetService("AssetService")

local FaceMapper = require(script.Parent.FaceMapper)

local GhostRenderer = {}

-- Roblox EditableImage type aliased for clarity. Kept as `any` to avoid
-- pulling Roblox internal type names into this file's export surface.
export type GhostImage = any

-- The 0..255 alpha byte convention from the brief translated to the
-- DrawRectangle(transparency: 0..1) API:
local FILL_TRANSPARENCY = 60 / 255
local BORDER_TRANSPARENCY = 180 / 255

-- White tint used for both the faint face-region fill and the crisp border.
local WHITE = Color3.fromRGB(255, 255, 255)

local COMBINE = Enum.ImageCombineType.Overwrite

-- Creates an EditableImage with a faint white fill marking the face region
-- and a crisp border outlining it. Caller should wrap the return value with
-- Content.fromObject(asset) and assign to ImageLabel.ImageContent.
function GhostRenderer.render(headType: FaceMapper.HeadType, resolution: FaceMapper.Resolution): GhostImage
	local region = FaceMapper.getRegion(headType, resolution)
	local asset = AssetService:CreateEditableImage({ Size = Vector2.new(resolution, resolution) })

	-- Faint face-region fill
	asset:DrawRectangle(
		Vector2.new(region.x, region.y),
		Vector2.new(region.width, region.height),
		WHITE,
		FILL_TRANSPARENCY,
		COMBINE
	)

	-- Crisp 1-pixel-thick border around the face region. We split the border
	-- into 4 thin rectangles (top / bottom / left / right). Each is 2 px tall
	-- to match the "+2" padding the brief uses on width/height.

	-- Top
	asset:DrawRectangle(
		Vector2.new(region.x - 1, region.y - 1),
		Vector2.new(region.width + 2, 2),
		WHITE,
		BORDER_TRANSPARENCY,
		COMBINE
	)
	-- Bottom
	asset:DrawRectangle(
		Vector2.new(region.x - 1, region.y + region.height - 1),
		Vector2.new(region.width + 2, 2),
		WHITE,
		BORDER_TRANSPARENCY,
		COMBINE
	)
	-- Left
	asset:DrawRectangle(
		Vector2.new(region.x - 1, region.y - 1),
		Vector2.new(2, region.height + 2),
		WHITE,
		BORDER_TRANSPARENCY,
		COMBINE
	)
	-- Right
	asset:DrawRectangle(
		Vector2.new(region.x + region.width - 1, region.y - 1),
		Vector2.new(2, region.height + 2),
		WHITE,
		BORDER_TRANSPARENCY,
		COMBINE
	)

	return asset
end

return GhostRenderer
