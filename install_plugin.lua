-- install_plugin.lua — FaceFit dev-scaffold setup (CommandBar / one-off Script)
--
-- What this script does (runs entirely inside Studio):
--   1. Ensures ReplicatedStorage.Plugins exists (creates a Folder if missing).
--   2. Ensures ReplicatedStorage.Plugins.FaceFit exists (creates a Folder if missing).
--   3. Ensures ReplicatedStorage.Plugins.FaceFit.DockWidgetGui exists (placeholder for Task 4).
--   4. Prints clear instructions for installing a REAL plugin (.rbxm) — because
--      `Instance.new("Plugin")` is BLOCKED by Studio. The dev scaffold only exists
--      so the source-on-disk mirrors what's in the DataModel for testing.
--
-- IMPORTANT — REAL PLUGIN INSTALL:
--   Studio cannot create a Plugin instance from script. To install FaceFit as a
--   real plugin with the toolbar button, do ONE of the following:
--
--     (a) Package the source folder and drop the .rbxm into:
--           <Studio install>/Plugins/
--         then enable it in:  File → Game Settings → Plugins (or the Plugins toolbar)
--
--     (b) Use  File → Save as Local Plugin  on a place that contains the source.
--
--     (c) Publish to Marketplace / Creator Store and install from there.
--
--   None of these are scriptable from inside a place. The dev scaffold below
--   keeps the source tree mirrored under ReplicatedStorage.Plugins.FaceFit so
--   the scripts can be edited from the filesystem and tested without a real
--   Plugin install (the init script's IsA("Plugin") guard short-circuits in dev).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolder(parent: Instance, name: string): Folder
	-- Use FindFirstChild, NOT WaitForChild — WaitForChild blocks indefinitely
	-- when the folder does not yet exist, so the create-if-missing branch
	-- below would never run.
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		warn(
			"[FaceFit] Expected a Folder at "
				.. existing:GetFullName()
				.. " but found a "
				.. existing.ClassName
				.. ". Leaving it in place; the scaffold may misbehave."
		)
		return existing :: any
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	print("[FaceFit] Created Folder " .. folder:GetFullName())
	return folder
end

local pluginsRoot = ensureFolder(ReplicatedStorage, "Plugins")
local faceFitRoot = ensureFolder(pluginsRoot, "FaceFit")
ensureFolder(faceFitRoot, "DockWidgetGui")

print("[FaceFit] Dev scaffold ready: " .. faceFitRoot:GetFullName())
print("[FaceFit] Dev scaffold mode only. The toolbar button will NOT appear until you")
print("[FaceFit] install a real .rbxm via Studio's Plugin Manager (see header comment).")
