--!strict
-- AssetUploader — uploads face textures through AssetService.
-- Returns the asset id on success; throws on failure.
--
-- API adaptation from the task brief:
-- EditableImage has no Save() method in the current Roblox API. Locally loaded
-- plugins upload an EditableImage with AssetService:CreateAssetAsync and
-- Enum.AssetType.Image. That API returns (CreateAssetResult, numeric asset id),
-- so the successful id is converted to a string to preserve upload()'s public
-- return type. PreloadAsync receives an ImageLabel that references the uploaded
-- asset because EditableImage is an Object, not a preloadable Instance.

local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")

local AssetUploader = {}

-- Numeric literal unions (`512 | 1024`) are not accepted by this Studio's
-- Luau parser, so the runtime assertion below enforces the supported values.
export type Resolution = number

function AssetUploader.upload(
	pixels: buffer,
	resolution: Resolution,
	onProgress: ((number) -> ())?
): string
	assert(typeof(pixels) == "buffer", "pixels must be a buffer")
	assert(resolution == 512 or resolution == 1024, "resolution must be 512 or 1024")

	if onProgress then
		onProgress(0)
	end

	-- Build EditableImage and import the RGBA pixel buffer.
	local size = Vector2.new(resolution, resolution)
	local asset = AssetService:CreateEditableImage({ Size = size })
	if not asset then
		error("AssetUploader: CreateEditableImage() failed (editable memory budget may be exhausted)")
	end

	-- Keep all work that needs the EditableImage inside pcall so the image is
	-- destroyed on API errors (or if a progress callback throws). Destroying it
	-- immediately reclaims the editable-memory budget after the upload finishes.
	local uploadOk, result, idOrUploadError = pcall(function()
		asset:WritePixelsBuffer(Vector2.zero, size, pixels)

		if onProgress then
			onProgress(0.3)
		end

		-- CreateAssetAsync is the current replacement for the brief's obsolete
		-- EditableImage:Save({ ImageFormat = Enum.ImageFormat.PNG }) call.
		return AssetService:CreateAssetAsync(asset, Enum.AssetType.Image)
	end)
	asset:Destroy()

	if not uploadOk then
		error(result, 0)
	end

	if result ~= Enum.CreateAssetResult.Success then
		error(
			string.format(
				"AssetUploader: CreateAssetAsync failed (%s): %s",
				result.Name,
				tostring(idOrUploadError)
			)
		)
	end

	if idOrUploadError == nil or idOrUploadError == "" then
		error("AssetUploader: CreateAssetAsync returned empty asset id")
	end
	local assetId = tostring(idOrUploadError)

	if onProgress then
		onProgress(0.7)
	end

	-- Yield briefly so ContentProvider picks up the uploaded image; this helps
	-- when the preview/apply flow immediately references the new asset id.
	local preloadTarget = Instance.new("ImageLabel")
	preloadTarget.Image = "rbxassetid://" .. assetId
	ContentProvider:PreloadAsync({ preloadTarget })
	preloadTarget:Destroy()

	if onProgress then
		onProgress(1)
	end
	return assetId
end

return AssetUploader
