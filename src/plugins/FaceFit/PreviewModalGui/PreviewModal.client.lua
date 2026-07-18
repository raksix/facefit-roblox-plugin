--!strict
-- FaceFit PreviewModal — 3D preview before apply (LocalScript, client context).
-- Triggered by DockWidget's RequestPreview BindableEvent.

local FaceMapper = require(script.Parent.Parent.DockWidgetGui.services.FaceMapper)
local DecalApplier = require(script.Parent.Parent.DockWidgetGui.services.DecalApplier)

local dockGui = script.Parent.Parent.DockWidgetGui
local RequestPreview = dockGui:FindFirstChild("RequestPreview") :: BindableEvent

local modal: DockWidgetPluginGui? = nil
local modalContent: ScreenGui? = nil
local viewportFrame: ViewportFrame? = nil
local testHead: BasePart? = nil
local currentState: any = nil

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
	modalContent = nil
	viewportFrame = nil
end

local function buildModal(state: any)
	cleanup()

	local plugin = plugin -- LocalScript implicit global
	if not plugin then return end

	modal = plugin:CreateDockWidgetPluginGui(
		"FaceFitPreview",
		DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 360, 420, 360, 420)
	)
	modal.Title = "FaceFit — Önizleme"

	modalContent = Instance.new("ScreenGui")
	modalContent.Parent = modal

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BorderSizePixel = 0
	bg.Parent = modalContent

	-- ViewportFrame
	viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Size = UDim2.new(1, -20, 1, -80)
	viewportFrame.Position = UDim2.new(0, 10, 0, 10)
	viewportFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	viewportFrame.Parent = bg

	-- Camera
	local camera = Instance.new("Camera")
	camera.FieldOfView = 50
	camera.CFrame = CFrame.new(Vector3.new(0, 2, 4), Vector3.new(0, 1.5, 0))
	viewportFrame.CurrentCamera = camera

	-- Lighting
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 10
	light.Parent = viewportFrame

	-- Test Head: clone from existing template
	local template
	if state.headType == "R6" then
		template = game.ReplicatedStorage:FindFirstChild("ZombieTemplate")
			and game.ReplicatedStorage.ZombieTemplate:FindFirstChild("ZombieBase")
			and game.ReplicatedStorage.ZombieTemplate.ZombieBase:FindFirstChild("Head")
	end
	if not template then
		-- Fallback: synthesize a simple Part as a Head
		template = Instance.new("Part")
		template.Name = "Head"
		template.Size = Vector3.new(2, 1, 1)
		template.Color = Color3.fromRGB(200, 180, 160)
	end
	testHead = template:Clone()
	testHead.Parent = viewportFrame

	-- Apply a temporary Decal to test head using the user's image
	if state.userImage then
		local ok, err = pcall(function()
			DecalApplier.apply(testHead :: any, state.userImage, state.headType, "replace")
		end)
		if not ok then
			warn("FaceFit preview: decal apply failed:", err)
		end
	end

	-- Apply / Cancel buttons
	local applyBtn = Instance.new("TextButton")
	applyBtn.Text = "Apply to Selected Head"
	applyBtn.Size = UDim2.new(0.48, 0, 0, 36)
	applyBtn.Position = UDim2.new(0.02, 0, 1, -46)
	applyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
	applyBtn.TextColor3 = Color3.new(1, 1, 1)
	applyBtn.Parent = bg
	applyBtn.MouseButton1Click:Connect(function()
		local target = DecalApplier.getSelectedHead()
		if not target then
			warn("FaceFit: Head seçili değil.")
			return
		end
		-- TODO: trigger upload flow (Task 9 wires this through DockWidget state)
		print("FaceFit: Apply queued for selected Head:", target:GetFullName())
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
