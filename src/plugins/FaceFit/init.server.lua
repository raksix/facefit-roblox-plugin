--!strict
-- FaceFit — Plugin entry point (consolidated single-file build)
--
-- ============================================================================
-- WHY THIS IS ONE BIG FILE
-- ============================================================================
-- Roblox Studio's plugin folder loader exhibits a bug with subfolder `.lua`
-- files: every `.lua` file becomes a Folder whose child is a generic Script,
-- and that Script auto-runs with the wrong `script.Parent` (the Folder, not
-- the Plugin), so `require(script.Parent.services.FaceMapper)` and friends
-- error out with "X is not a valid member of Plugin" the moment Studio reads
-- the plugin folder. Confirmed in the error log:
--
--   "services is not a valid member of Plugin user_FaceFit/DockWidgetGui/DockWidget.client.lua"
--   "TestEZ is not a valid member of Plugin user_FaceFit/tests/run_tests.client.lua"
--
-- To dodge this entirely, the plugin folder contains ONLY `init.server.lua`.
-- Every other Script/LocalScript/ModuleScript lives as a Lua string constant
-- here and is materialised at runtime via `Instance.new(...):set .Source`.
-- The runtime tree is:
--
--   DockWidgetPluginGui (FaceFitDock)
--   ├── FaceMapper       (ModuleScript)
--   ├── ImageProcessor   (ModuleScript)
--   ├── GhostRenderer    (ModuleScript)
--   ├── DecalApplier     (ModuleScript)
--   ├── RequestPreview   (BindableEvent)
--   ├── RequestApply     (BindableEvent)
--   ├── DockWidget       (LocalScript — main docked UI)
--   └── PreviewModal     (LocalScript — listens for RequestPreview, pops a float GUI)
--
-- When the user first opens the dock, init.server.lua builds this whole tree
-- from the string constants below. No more Folder+Script noise in the console.
-- ============================================================================

local Plugin = script.Parent

if not Plugin:IsA("Plugin") then
	warn("[FaceFit] script.Parent is a " .. Plugin.ClassName .. ", not a Plugin. Skipping toolbar registration.")
	return
end

-- ============================================================================
-- Source constants — every other script the plugin needs, inlined as strings.
-- `script.Parent` for the runtime scripts is the DockWidgetPluginGui, so they
-- look services up via `script.Parent:FindFirstChild("X")` rather than going
-- through nested Folder paths.
-- ============================================================================

local FACEMAPPER_SRC = [[
--!strict
-- FaceMapper — pure data for Roblox face texture regions.

local FaceMapper = {}

export type HeadType = "R6" | "R15"
export type Resolution = number
export type FaceRegion = {
	x: number,
	y: number,
	width: number,
	height: number,
	centerX: number,
	centerY: number,
}

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
	if head == nil then
		return "R15"
	end
	if head.ClassName == "MeshPart" then
		return "R15"
	end
	return "R6"
end

return FaceMapper
]]

local IMAGEPROCESSOR_SRC = [[
--!strict
-- ImageProcessor — pure Luau helpers for canvas state math.

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

ImageProcessor.ZOOM_MIN = ZOOM_MIN
ImageProcessor.ZOOM_MAX = ZOOM_MAX
ImageProcessor.GRID_PX = GRID_PX

return ImageProcessor
]]

local DECALAPPLIER_SRC = [[
--!strict
-- DecalApplier — applies an uploaded face texture as a Decal to the target Head.

local DecalApplier = {}

export type HeadType = "R6" | "R15"
export type ApplyMode = "replace" | "new"

function DecalApplier.apply(
	targetHead: BasePart,
	assetId: string,
	headType: HeadType,
	mode: ApplyMode
): Decal
	assert(typeof(targetHead) == "Instance" and targetHead:IsA("BasePart"), "targetHead must be a BasePart")
	assert(targetHead.Name == "Head", "target must be named 'Head' (got: " .. targetHead.Name .. ")")
	assert(typeof(assetId) == "string" and assetId ~= "", "assetId must be non-empty string")

	for _, child in targetHead:GetChildren() do
		if child:IsA("Decal") and child.Name:match("^FaceFit") then
			if mode == "replace" then
				child:Destroy()
			end
		end
	end

	local decal = Instance.new("Decal")
	decal.Name = "FaceFit_" .. os.time()
	decal.Texture = "rbxassetid://" .. assetId

	if headType == "R6" then
		decal.Face = Enum.NormalId.Front
		decal.Parent = targetHead
	else
		local attachment = targetHead:FindFirstChild("FaceCenterAttachment")
		if attachment and attachment:IsA("Attachment") then
			decal.Parent = attachment
		else
			decal.Face = Enum.NormalId.Front
			decal.Parent = targetHead
		end
	end

	return decal
end

function DecalApplier.getSelectedHead(): BasePart?
	local selected = Selection:Get()
	for _, item in selected do
		if typeof(item) == "Instance" and item:IsA("BasePart") and item.Name == "Head" then
			return item
		end
	end
	return nil
end

return DecalApplier
]]

local GHOSTRENDERER_SRC = [[
--!strict
-- GhostRenderer — produces a ghost-template image (EditableImage) for the
-- current headType/resolution. Caller wraps the return with
-- Content.fromObject(asset) and assigns to ImageLabel.ImageContent.

local AssetService = game:GetService("AssetService")
local FaceMapper = require(script.Parent:FindFirstChild("FaceMapper")) :: any

local GhostRenderer = {}

export type GhostImage = any

local FILL_TRANSPARENCY = 60 / 255
local BORDER_TRANSPARENCY = 180 / 255
local WHITE = Color3.fromRGB(255, 255, 255)
local COMBINE = Enum.ImageCombineType.Overwrite

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

	-- Border (4 thin rectangles)
	asset:DrawRectangle(Vector2.new(region.x - 1, region.y - 1), Vector2.new(region.width + 2, 2), WHITE, BORDER_TRANSPARENCY, COMBINE)
	asset:DrawRectangle(Vector2.new(region.x - 1, region.y + region.height - 1), Vector2.new(region.width + 2, 2), WHITE, BORDER_TRANSPARENCY, COMBINE)
	asset:DrawRectangle(Vector2.new(region.x - 1, region.y - 1), Vector2.new(2, region.height + 2), WHITE, BORDER_TRANSPARENCY, COMBINE)
	asset:DrawRectangle(Vector2.new(region.x + region.width - 1, region.y - 1), Vector2.new(2, region.height + 2), WHITE, BORDER_TRANSPARENCY, COMBINE)

	return asset
end

return GhostRenderer
]]

local DOCKWIDGET_SRC = [[
--!strict
-- FaceFit DockWidget — main editor UI.

local FaceMapper = require(script.Parent:FindFirstChild("FaceMapper")) :: any
local ImageProcessor = require(script.Parent:FindFirstChild("ImageProcessor")) :: any
local GhostRenderer = require(script.Parent:FindFirstChild("GhostRenderer")) :: any
local DecalApplier = require(script.Parent:FindFirstChild("DecalApplier")) :: any

local gui = script.Parent -- the DockWidgetPluginGui

local state = {
	userImage = nil :: any,
	headType = "R15" :: any,
	resolution = 512 :: any,
	position = { offsetX = 0, offsetY = 0, zoom = 1, rotation = 0, snapEnabled = true } :: any,
}

state.headType = FaceMapper.getDefaultHeadType(nil)

local RequestPreview = script.Parent:WaitForChild("RequestPreview", 5) :: BindableEvent
local RequestApply = script.Parent:WaitForChild("RequestApply", 5) :: BindableEvent

local function applyFromState(s: any)
	if not s.userImage then
		warn("FaceFit: Önce bir resim seç.")
		return
	end
	local assetId = s.userImage :: string
	local target = DecalApplier.getSelectedHead()
	if not target then
		warn("FaceFit: Lütfen bir Head seçin.")
		return
	end
	local ok, err = pcall(function()
		DecalApplier.apply(target, assetId, s.headType, "replace")
	end)
	if ok then
		print("FaceFit: Decal applied to", target:GetFullName())
	else
		warn("FaceFit: Apply failed:", err)
	end
end

RequestApply.Event:Connect(applyFromState)

local function updateCanvas()
	local frame = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Canvas")
	if not frame then return end
	local userImage = frame:FindFirstChild("UserImage")
	if userImage and userImage:IsA("ImageLabel") and state.userImage then
		userImage.Image = "rbxassetid://" .. tostring(state.userImage)
	end
end

local renderGhost: () -> ()

local function buildUI()
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local main = Instance.new("ScrollingFrame")
	main.Name = "Main"
	main.Size = UDim2.new(1, 0, 1, 0)
	main.BackgroundTransparency = 1
	main.ScrollBarThickness = 4
	main.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = main

	-- Image picker
	local pickBtn = Instance.new("TextButton")
	pickBtn.Name = "PickImage"
	pickBtn.Text = "Resim Seç"
	pickBtn.Size = UDim2.new(1, -10, 0, 32)
	pickBtn.LayoutOrder = 1
	pickBtn.Parent = main
	pickBtn.MouseButton1Click:Connect(function()
		local plugin = plugin
		if not plugin then return end
		local assetId = plugin:PromptImportAsset({"png", "jpg", "jpeg"})
		if assetId and assetId > 0 then
			state.userImage = tostring(assetId)
			updateCanvas()
			pickBtn.Text = "Resim seçildi: " .. state.userImage
		end
	end)

	-- Head type radio
	local headLabel = Instance.new("TextLabel")
	headLabel.Text = "Head Tipi:"
	headLabel.Size = UDim2.new(1, -10, 0, 18)
	headLabel.BackgroundTransparency = 1
	headLabel.TextXAlignment = Enum.TextXAlignment.Left
	headLabel.LayoutOrder = 2
	headLabel.Parent = main

	local headRadio = Instance.new("Frame")
	headRadio.Name = "HeadRadio"
	headRadio.Size = UDim2.new(1, -10, 0, 28)
	headRadio.BackgroundTransparency = 1
	headRadio.LayoutOrder = 3
	headRadio.Parent = main

	local r6 = Instance.new("TextButton")
	r6.Text = "R6"
	r6.Size = UDim2.new(0.5, -2, 1, 0)
	r6.Position = UDim2.new(0, 0, 0, 0)
	r6.BackgroundColor3 = state.headType == "R6" and Color3.fromRGB(60, 130, 200) or Color3.fromRGB(60, 60, 60)
	r6.TextColor3 = Color3.new(1, 1, 1)
	r6.Parent = headRadio

	local r15 = Instance.new("TextButton")
	r15.Text = "R15"
	r15.Size = UDim2.new(0.5, -2, 1, 0)
	r15.Position = UDim2.new(0.5, 2, 0, 0)
	r15.BackgroundColor3 = state.headType == "R15" and Color3.fromRGB(60, 130, 200) or Color3.fromRGB(60, 60, 60)
	r15.TextColor3 = Color3.new(1, 1, 1)
	r15.Parent = headRadio

	r6.MouseButton1Click:Connect(function()
		state.headType = "R6"
		r6.BackgroundColor3 = Color3.fromRGB(60, 130, 200)
		r15.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		renderGhost()
	end)
	r15.MouseButton1Click:Connect(function()
		state.headType = "R15"
		r15.BackgroundColor3 = Color3.fromRGB(60, 130, 200)
		r6.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		renderGhost()
	end)

	-- Resolution
	local resLabel = Instance.new("TextLabel")
	resLabel.Text = "Çözünürlük:"
	resLabel.Size = UDim2.new(1, -10, 0, 18)
	resLabel.BackgroundTransparency = 1
	resLabel.TextXAlignment = Enum.TextXAlignment.Left
	resLabel.LayoutOrder = 4
	resLabel.Parent = main

	local resDropdown = Instance.new("TextButton")
	resDropdown.Text = tostring(state.resolution) .. "x" .. tostring(state.resolution)
	resDropdown.Size = UDim2.new(1, -10, 0, 28)
	resDropdown.LayoutOrder = 5
	resDropdown.Parent = main
	resDropdown.MouseButton1Click:Connect(function()
		if state.resolution == 512 then
			state.resolution = 1024
		else
			state.resolution = 512
		end
		resDropdown.Text = tostring(state.resolution) .. "x" .. tostring(state.resolution)
		renderGhost()
	end)

	-- Canvas: ghost (bottom) + user image (top)
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, -10, 0, 300)
	canvas.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	canvas.BackgroundTransparency = 0
	canvas.LayoutOrder = 6
	canvas.Parent = main

	local ghostImage = Instance.new("ImageLabel")
	ghostImage.Name = "GhostImage"
	ghostImage.Size = UDim2.new(1, 0, 1, 0)
	ghostImage.BackgroundTransparency = 1
	ghostImage.ImageTransparency = 0
	ghostImage.ScaleType = Enum.ScaleType.Stretch
	ghostImage.ZIndex = 1
	ghostImage.Parent = canvas

	local userImage = Instance.new("ImageLabel")
	userImage.Name = "UserImage"
	userImage.Size = UDim2.new(1, 0, 1, 0)
	userImage.BackgroundTransparency = 1
	userImage.ScaleType = Enum.ScaleType.Stretch
	userImage.ZIndex = 2
	userImage.Parent = canvas

	renderGhost = function()
		local asset = GhostRenderer.render(state.headType, state.resolution)
		ghostImage.ImageContent = Content.fromObject(asset)
	end
	renderGhost()

	-- Sliders
	local function makeSlider(label: string, key: string, min: number, max: number, order: number): TextLabel
		local lbl = Instance.new("TextLabel")
		lbl.Text = label .. ": 0"
		lbl.Size = UDim2.new(1, -10, 0, 18)
		lbl.BackgroundTransparency = 1
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.LayoutOrder = order
		lbl.Parent = main

		local slider = Instance.new("TextButton")
		slider.Text = "[—————●—————]"
		slider.Size = UDim2.new(1, -10, 0, 20)
		slider.LayoutOrder = order + 1
		slider.Parent = main

		slider.MouseButton1Click:Connect(function()
			local current = (state.position :: any)[key] :: number
			local step = (max - min) / 20
			(state.position :: any)[key] = math.clamp(current + step, min, max)
			state.position = ImageProcessor.clampPosition(state.position, state.resolution)
			lbl.Text = label .. ": " .. tostring(math.floor((state.position :: any)[key] * 100) / 100)
			slider.Text = "["
			for i = 1, 20 do
				local v = min + (max - min) * (i / 20)
				if v < (state.position :: any)[key] then
					slider.Text = slider.Text .. "●"
				else
					slider.Text = slider.Text .. "—"
				end
			end
			slider.Text = slider.Text .. "]"
		end)

		slider.MouseButton2Click:Connect(function()
			local current = (state.position :: any)[key] :: number
			local step = (max - min) / 20
			(state.position :: any)[key] = math.clamp(current - step, min, max)
			state.position = ImageProcessor.clampPosition(state.position, state.resolution)
			lbl.Text = label .. ": " .. tostring(math.floor((state.position :: any)[key] * 100) / 100)
		end)
		return lbl
	end

	makeSlider("Zoom", "zoom", 0.25, 4, 7)
	makeSlider("Offset X", "offsetX", -256, 256, 9)
	makeSlider("Offset Y", "offsetY", -256, 256, 11)
	makeSlider("Rotation", "rotation", -180, 180, 13)

	-- Snap toggle
	local snapToggle = Instance.new("TextButton")
	snapToggle.Text = state.position.snapEnabled and "Grid Snap: AÇIK" or "Grid Snap: KAPALI"
	snapToggle.Size = UDim2.new(1, -10, 0, 28)
	snapToggle.LayoutOrder = 15
	snapToggle.Parent = main
	snapToggle.MouseButton1Click:Connect(function()
		state.position.snapEnabled = not state.position.snapEnabled
		snapToggle.Text = state.position.snapEnabled and "Grid Snap: AÇIK" or "Grid Snap: KAPALI"
	end)

	-- Reset
	local resetBtn = Instance.new("TextButton")
	resetBtn.Text = "Reset"
	resetBtn.Size = UDim2.new(1, -10, 0, 28)
	resetBtn.LayoutOrder = 16
	resetBtn.Parent = main
	resetBtn.MouseButton1Click:Connect(function()
		state.position = { offsetX = 0, offsetY = 0, zoom = 1, rotation = 0, snapEnabled = state.position.snapEnabled }
	end)

	-- Preview
	local previewBtn = Instance.new("TextButton")
	previewBtn.Text = "Preview"
	previewBtn.Size = UDim2.new(1, -10, 0, 28)
	previewBtn.LayoutOrder = 17
	previewBtn.Parent = main
	previewBtn.MouseButton1Click:Connect(function()
		if not state.userImage then
			warn("FaceFit: Önce bir resim seç.")
			return
		end
		RequestPreview:Fire(state)
	end)

	-- Apply
	local applyBtn = Instance.new("TextButton")
	applyBtn.Text = "Upload & Apply"
	applyBtn.Size = UDim2.new(1, -10, 0, 32)
	applyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	applyBtn.TextColor3 = Color3.new(1, 1, 1)
	applyBtn.LayoutOrder = 18
	applyBtn.Parent = main
	applyBtn.MouseButton1Click:Connect(function()
		RequestApply:Fire(state)
	end)
end

buildUI()
]]

local PREVIEWMODAL_SRC = [[
--!strict
-- FaceFit PreviewModal — opens a floating dock with the picked image applied
-- to a temporary Head, so the user can see the result before applying.

local DecalApplier = require(script.Parent:FindFirstChild("DecalApplier")) :: any

local dockGui = script.Parent
local RequestPreview = dockGui:WaitForChild("RequestPreview", 5) :: BindableEvent
local RequestApply = dockGui:WaitForChild("RequestApply", 5) :: BindableEvent

local modal: DockWidgetPluginGui? = nil
local testHead: BasePart? = nil

local function cleanup()
	if testHead then
		testHead:Destroy()
		testHead = nil
	end
end

local function closeModal()
	cleanup()
	if modal then
		modal:Destroy()
		modal = nil
	end
end

local function buildModal(state: any)
	cleanup()
	local plugin = plugin
	if not plugin then return end

	modal = plugin:CreateDockWidgetPluginGui(
		"FaceFitPreview",
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 360, 420, 360, 420)
	)
	modal.Title = "FaceFit — Önizleme"

	local modalContent = Instance.new("ScreenGui")
	modalContent.Parent = modal

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.Parent = modalContent

	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Size = UDim2.new(1, -20, 1, -80)
	viewportFrame.Position = UDim2.new(0, 10, 0, 10)
	viewportFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	viewportFrame.Parent = bg

	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	camera.CFrame = CFrame.new(Vector3.new(0, 2, 4), Vector3.new(0, 1.5, 0))
	viewportFrame.CurrentCamera = camera

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 10
	light.Parent = viewportFrame

	-- Test Head: clone from existing R15 template if R15, otherwise synthesise
	local template
	if state.headType == "R6" then
		template = game.ReplicatedStorage:FindFirstChild("ZombieTemplate")
			and game.ReplicatedStorage.ZombieTemplate:FindFirstChild("ZombieBase")
			and game.ReplicatedStorage.ZombieTemplate.ZombieBase:FindFirstChild("Head")
	end
	if not template then
		template = Instance.new("Part")
		template.Name = "Head"
		template.Size = Vector3.new(2, 1, 1)
		template.Color = Color3.fromRGB(200, 180, 160)
	end
	testHead = template:Clone()
	testHead.Parent = viewportFrame

	if state.userImage then
		local ok, err = pcall(function()
			DecalApplier.apply(testHead :: any, state.userImage, state.headType, "replace")
		end)
		if not ok then
			warn("FaceFit preview: decal apply failed:", err)
		end
	end

	local applyBtn = Instance.new("TextButton")
	applyBtn.Text = "Apply to Selected Head"
	applyBtn.Size = UDim2.new(0.48, 0, 0, 36)
	applyBtn.Position = UDim2.new(0.02, 0, 1, -46)
	applyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	applyBtn.TextColor3 = Color3.new(1, 1, 1)
	applyBtn.Parent = bg
	applyBtn.MouseButton1Click:Connect(function()
		RequestApply:Fire(state)
		closeModal()
	end)

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Text = "Cancel"
	cancelBtn.Size = UDim2.new(0.48, 0, 0, 36)
	cancelBtn.Position = UDim2.new(0.5, 0, 1, -46)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
	cancelBtn.TextColor3 = Color3.new(1, 1, 1)
	cancelBtn.Parent = bg
	cancelBtn.MouseButton1Click:Connect(closeModal)
end

RequestPreview.Event:Connect(buildModal)
]]

-- ============================================================================
-- Toolbar setup
-- ============================================================================

local toolbar = Plugin:CreateToolbar("FaceFit")
local toggleButton = toolbar:CreateButton(
	"FaceFitToggle",
	"FaceFit dock widget'ı aç/kapat",
	"rbxassetid://6031763426"
)

local dockWidgetGui: DockWidgetPluginGui? = nil

local function openDock()
	if not dockWidgetGui then
		dockWidgetGui = Plugin:CreateDockWidgetPluginGui(
			"FaceFitDock",
			DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 320, 600, 320, 200)
		)
		dockWidgetGui.Title = "FaceFit"

		-- Service ModuleScripts (created first so DockWidget.client.lua can require them).
		local function createModule(name: string, source: string): ModuleScript
			local m = Instance.new("ModuleScript")
			m.Name = name
			m.Source = source
			m.Parent = dockWidgetGui
			return m
		end

		createModule("FaceMapper", FACEMAPPER_SRC)
		createModule("ImageProcessor", IMAGEPROCESSOR_SRC)
		createModule("GhostRenderer", GHOSTRENDERER_SRC)
		createModule("DecalApplier", DECALAPPLIER_SRC)

		-- BindableEvents for cross-LocalScript communication.
		local requestPreview = Instance.new("BindableEvent")
		requestPreview.Name = "RequestPreview"
		requestPreview.Parent = dockWidgetGui

		local requestApply = Instance.new("BindableEvent")
		requestApply.Name = "RequestApply"
		requestApply.Parent = dockWidgetGui

		-- DockWidget LocalScript — main UI
		local dockScript = Instance.new("LocalScript")
		dockScript.Name = "DockWidget"
		dockScript.Source = DOCKWIDGET_SRC
		dockScript.Parent = dockWidgetGui

		-- PreviewModal LocalScript — opens a floating dock on RequestPreview
		local previewScript = Instance.new("LocalScript")
		previewScript.Name = "PreviewModal"
		previewScript.Source = PREVIEWMODAL_SRC
		previewScript.Parent = dockWidgetGui
	end
	dockWidgetGui.Enabled = not dockWidgetGui.Enabled
end

toggleButton.Click:Connect(openDock)

Plugin.Unloading:Connect(function()
	if dockWidgetGui then
		dockWidgetGui:Destroy()
		dockWidgetGui = nil
	end
end)
