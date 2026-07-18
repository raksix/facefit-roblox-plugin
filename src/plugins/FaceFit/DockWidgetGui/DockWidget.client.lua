--!strict
-- FaceFit DockWidget — main editor UI (LocalScript, client context).
-- See: docs/superpowers/specs/2026-07-19-facefit-plugin-design.md

local FaceMapper = require(script.Parent.services.FaceMapper)
local ImageProcessor = require(script.Parent.services.ImageProcessor)

local gui = script.Parent -- The DockWidgetPluginGui (parent of this LocalScript)

-- === State ===
local state = {
	userImage = nil :: string?,        -- asset id of picked image (or nil)
	headType = nil :: FaceMapper.HeadType,
	resolution = nil :: FaceMapper.Resolution,
	position = {
		offsetX = 0,
		offsetY = 0,
		zoom = 1,
		rotation = 0,
		snapEnabled = true,
	} :: ImageProcessor.FacePosition,
}

-- Initial defaults
state.headType = FaceMapper.getDefaultHeadType(nil) -- "R15"
state.resolution = 512

-- === BindableEvents (consumed by PreviewModal) ===
local RequestPreview = Instance.new("BindableEvent")
RequestPreview.Name = "RequestPreview"
RequestPreview.Parent = gui

local RequestApply = Instance.new("BindableEvent")
RequestApply.Name = "RequestApply"
RequestApply.Parent = gui

-- === Helper: updateCanvas (declared before buildUI so it is in scope for the PickImage click handler) ===
local function updateCanvas()
	local canvas = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Canvas")
	if canvas and canvas:IsA("ImageLabel") and state.userImage then
		-- Set user image, ghost template overlaid in Task 5.
		canvas.Image = "rbxassetid://" .. tostring(state.userImage)
	end
end

-- === Helper: build UI ===
local function buildUI()
	-- Clear any existing children (re-entrancy safety)
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
		-- Plugin:PromptImportAsset() gives the user a file picker filtered to images.
		local plugin = plugin -- implicit `plugin` global in LocalScripts under a PluginGui
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
	r6.Text = "R6"; r6.Size = UDim2.new(0.5, -2, 1, 0); r6.Position = UDim2.new(0, 0, 0, 0)
	r6.BackgroundColor3 = state.headType == "R6" and Color3.fromRGB(60, 130, 200) or Color3.fromRGB(60, 60, 60)
	r6.TextColor3 = Color3.new(1, 1, 1)
	r6.Parent = headRadio

	local r15 = Instance.new("TextButton")
	r15.Text = "R15"; r15.Size = UDim2.new(0.5, -2, 1, 0); r15.Position = UDim2.new(0.5, 2, 0, 0)
	r15.BackgroundColor3 = state.headType == "R15" and Color3.fromRGB(60, 130, 200) or Color3.fromRGB(60, 60, 60)
	r15.TextColor3 = Color3.new(1, 1, 1)
	r15.Parent = headRadio

	r6.MouseButton1Click:Connect(function()
		state.headType = "R6"
		r6.BackgroundColor3 = Color3.fromRGB(60, 130, 200)
		r15.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	end)
	r15.MouseButton1Click:Connect(function()
		state.headType = "R15"
		r15.BackgroundColor3 = Color3.fromRGB(60, 130, 200)
		r6.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	end)

	-- Resolution dropdown
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
	end)

	-- Canvas
	local canvas = Instance.new("ImageLabel")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, -10, 0, 300)
	canvas.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	canvas.BackgroundTransparency = 0
	canvas.LayoutOrder = 6
	canvas.Parent = main
	canvas.Image = "" -- ghost template rendered at runtime in Task 5

	-- Sliders (zoom, offsetX, offsetY, rotation)
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
			-- Simple step-based slider; user can refine UX later.
			-- For now: clicking increases; right-click decreases.
			local current = (state.position :: any)[key] :: number
			local step = (max - min) / 20
			(state.position :: any)[key] = math.clamp(current + step, min, max)
			-- Re-clamp via service
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

	-- Grid snap toggle
	local snapToggle = Instance.new("TextButton")
	snapToggle.Text = state.position.snapEnabled and "Grid Snap: AÇIK" or "Grid Snap: KAPALI"
	snapToggle.Size = UDim2.new(1, -10, 0, 28)
	snapToggle.LayoutOrder = 15
	snapToggle.Parent = main
	snapToggle.MouseButton1Click:Connect(function()
		state.position.snapEnabled = not state.position.snapEnabled
		snapToggle.Text = state.position.snapEnabled and "Grid Snap: AÇIK" or "Grid Snap: KAPALI"
	end)

	-- Reset button
	local resetBtn = Instance.new("TextButton")
	resetBtn.Text = "Reset"
	resetBtn.Size = UDim2.new(1, -10, 0, 28)
	resetBtn.LayoutOrder = 16
	resetBtn.Parent = main
	resetBtn.MouseButton1Click:Connect(function()
		state.position = { offsetX = 0, offsetY = 0, zoom = 1, rotation = 0, snapEnabled = state.position.snapEnabled }
	end)

	-- Preview button
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

	-- Apply button
	local applyBtn = Instance.new("TextButton")
	applyBtn.Text = "Upload & Apply"
	applyBtn.Size = UDim2.new(1, -10, 0, 32)
	applyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	applyBtn.TextColor3 = Color3.new(1, 1, 1)
	applyBtn.LayoutOrder = 18
	applyBtn.Parent = main
	applyBtn.MouseButton1Click:Connect(function()
		if not state.userImage then
			warn("FaceFit: Önce bir resim seç.")
			return
		end
		RequestApply:Fire(state)
	end)
end

buildUI()
