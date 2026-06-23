-- Sigma Scripts loader — paste into executor or use autoexec.lua
-- Force hub UI: getgenv().SigmaShowHub = true
-- Reload safely: just run this again (old UI is cleaned up automatically)
local URL = "https://raw.githubusercontent.com/robloxgod910838-ctrl/sigmascript/refs/heads/main/sigma_hub.lua"

local ok, err = pcall(function()
	local src = game:HttpGet(URL, true)
	if type(src) ~= "string" or #src < 5000 then
		error("fetch failed or script too small (" .. tostring(type(src)) .. ", len=" .. tostring(src and #src) .. ")")
	end
	local fn, compileErr = loadstring(src, "sigma_hub.lua")
	if not fn then
		error("compile: " .. tostring(compileErr))
	end
	fn()
end)

if not ok then
	warn("[Sigma Scripts] failed to start:", err)
end
