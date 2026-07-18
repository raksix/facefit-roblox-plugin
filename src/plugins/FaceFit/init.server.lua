--!strict
-- FaceFit — Plugin entry point (server context)
-- See: docs/superpowers/specs/2026-07-19-facefit-plugin-design.md
--
-- NOTE: For development scaffolding inside the place, the parent folder
-- (ReplicatedStorage.Plugins.FaceFit) is a Folder, not a real Plugin instance.
-- Studio blocks `Instance.new("Plugin")` so the real install must go through
-- Studio's Plugin Manager (Plugins folder or marketplace .rbxm).
-- This script guards on `IsA("Plugin")` so it no-ops in dev scaffold mode
-- and runs the toolbar logic only when installed as a real plugin.

local Plugin = script.Parent -- The Plugin instance (or Folder scaffold)

if not Plugin:IsA("Plugin") then
	warn(
		"[FaceFit] script.Parent is a "
			.. Plugin.ClassName
			.. ", not a Plugin. Skipping toolbar registration. "
			.. "Install via Studio Plugin Manager for full functionality."
	)
	return
end

local toolbar = Plugin:CreateToolbar("FaceFit")
local toggleButton = toolbar:CreateButton(
	"FaceFitToggle",
	"FaceFit dock widget'ı aç/kapat",
	"rbxassetid://6031763426" -- placeholder icon, replace in polish task
)

local dockWidgetGui: DockWidgetPluginGui? = nil

local function openDock()
	if not dockWidgetGui then
		dockWidgetGui = Plugin:CreateDockWidgetPluginGui(
			"FaceFitDock",
			DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 320, 600, 320, 200)
		)
		dockWidgetGui.Title = "FaceFit"
		-- The DockWidget LocalScript lives under script.Parent.DockWidgetGui and is
		-- auto-attached by Studio when this DockWidgetPluginGui is enabled. It is
		-- created in Task 4, so we do NOT eagerly look it up here (that lookup would
		-- error before the click handler ever fires if the LocalScript is absent).
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