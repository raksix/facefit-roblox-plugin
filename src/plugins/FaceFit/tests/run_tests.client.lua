--!strict
-- TestEZ runner. Mirrored as ModuleScript so require() works from the command bar.
-- Wraps the run in pcall so that test failures don't propagate as module load
-- errors — they get surfaced via TestService:Error and the test reporter instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestEZ = require(script.Parent.TestEZ.init)

local TestBootstrap = TestEZ.TestBootstrap
local folder = script.Parent

local ok, results = pcall(function()
	return TestBootstrap:run({ folder })
end)

if ok and results then
	return ("%d passed, %d failed, %d skipped"):format(
		results.successCount,
		results.failureCount,
		results.skippedCount
	)
end
return ("error: %s"):format(tostring(results))