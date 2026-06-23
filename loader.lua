-- Sigma Scripts — auto-runs via MCP connector, or paste into executor Auto Execute
-- Disable: getgenv().DisableSigmaAutoExec = true  (connector)  OR  skip this file
-- Force hub UI: getgenv().SigmaShowHub = true
local url = "https://raw.githubusercontent.com/robloxgod910838-ctrl/sigmascript/refs/heads/main/sigma_hub.lua?t="
	.. tostring(os.time())
loadstring(game:HttpGet(url, true))()
