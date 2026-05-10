-- Tests/Runner.server.lua (ServerScriptService.Tests.Runner)
-- TestEZ runner. Executes all *.spec ModuleScripts under Tests/ and prints results.
--
-- Setup (one-time, in Studio):
--   1. Install TestEZ: place the TestEZ ModuleScript in ReplicatedStorage.TestEZ
--      (download from https://github.com/Roblox/testez or use Wally/Rojo).
--   2. With this Runner script enabled (Disabled=false), playtest the game.
--      Output appears in the Studio Output panel.
--
-- Disabled by default — enable when you want to run tests. Tests don't auto-run
-- in production sessions, only when this script is enabled.
script.Disabled = true  -- flip to false in Studio to run tests

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestEZ = ReplicatedStorage:FindFirstChild("TestEZ")
if not TestEZ then
	warn("[Tests.Runner] TestEZ not found in ReplicatedStorage. Install from https://github.com/Roblox/testez and place the ModuleScript at ReplicatedStorage.TestEZ.")
	return
end

-- Run all spec ModuleScripts in this folder.
local TestBootstrap = require(TestEZ).TestBootstrap
TestBootstrap:run({ script.Parent })
