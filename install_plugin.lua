-- Run once in Studio (CommandBar: paste the loadstring OR drop into a Script in ServerScriptService and run).
-- This script copies the plugin source from D:/AI/src/plugins/FaceFit into ReplicatedStorage.Plugins.FaceFit.

local PLUGIN_SOURCE = "D:/AI/src/plugins/FaceFit"
local PLUGIN_DEST_PARENT = game:GetService("ReplicatedStorage"):FindFirstChild("Plugins")
	or game:GetService("ReplicatedStorage"):WaitForChild("Plugins")

if not PLUGIN_DEST_PARENT then
	local f = Instance.new("Folder")
	f.Name = "Plugins"
	f.Parent = game:GetService("ReplicatedStorage")
	PLUGIN_DEST_PARENT = f
end

-- Implementation uses HttpService:GetAsync() to fetch raw source files in a real Studio plugin,
-- but for our dev workflow we instead expect the user to copy files via the filesystem.
-- This script is a marker; the real copy is done via:
--   cp -r D:/AI/src/plugins/FaceFit/* <studio-workspace>/ReplicatedStorage/Plugins/FaceFit/
--
-- After copying, also create the Plugin object:
print("[FaceFit] Copy source files manually, then run:")
print("local p = Instance.new('Plugin'); p.Name = 'FaceFit'; p.Parent = game.ReplicatedStorage.Plugins;")
print("print(p.Enabled) -- enable via Plugins Manager")