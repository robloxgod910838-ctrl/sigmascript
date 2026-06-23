-- Put this in your executor's Auto Execute folder (runs every inject/join)
-- Force hub UI: getgenv().SigmaShowHub = true
local URL = "https://raw.githubusercontent.com/robloxgod910838-ctrl/sigmascript/refs/heads/main/sigma_hub.lua"

local ok, err = pcall(function()
	local src = game:HttpGet(URL, true)
	if type(src) ~= "string" or #src < 5000 then
		error("fetch failed or script too small")
	end
	local fn, compileErr = loadstring(src, "sigma_hub.lua")
	if not fn then
		error("compile: " .. tostring(compileErr))
	end
	fn()
end)

if not ok then
	warn("[Sigma Scripts] autoexec failed:", err)
end
