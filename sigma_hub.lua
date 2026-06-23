-- Sigma Scripts — multi-game hub launcher (bundled, keyless)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local plr = Players.LocalPlayer

local C = {
	bg = Color3.fromRGB(8, 6, 16),
	panel = Color3.fromRGB(14, 10, 26),
	card = Color3.fromRGB(22, 16, 38),
	accent = Color3.fromRGB(168, 85, 247),
	accent2 = Color3.fromRGB(192, 132, 252),
	text = Color3.fromRGB(245, 240, 255),
	muted = Color3.fromRGB(130, 115, 165),
	green = Color3.fromRGB(52, 211, 153),
	yellow = Color3.fromRGB(250, 204, 21),
	red = Color3.fromRGB(248, 113, 113),
}

local EMBEDDED = {
	sell_lemons    = [=[-- Sell Lemons — Sigma Scripts game module (refactored Lemon Hub)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer

local SIGMA_VERSION = "2026.06.23-trade6"

local LOOP_DELAY = 0.1
local BUYS_PER_TICK = 8
local PHONE_RAISE_COUNT = 1
local FRUIT_TRAVEL_DWELL = 0.2
local FRUIT_MAX_COLLECT_ATTEMPTS = 40
local FRUIT_EMPTY_CYCLE_DELAY = 0.5
local FRUIT_FULL_SCAN_INTERVAL = 14
local FRUIT_REGISTRY_RIPE_INTERVAL = 1.25
local CASH_TRAVEL_DWELL = 0.6
local REBIRTH_KICKSTART_TIMEOUT = 45
local REBIRTH_KICKSTART_WAKE_INTERVAL = 0.12

local MODULE_PATHS = {
	{ "Huge", RS.Modules.Huge },
	{ "Tycoon", RS.Modules.Tycoon.Tycoon },
	{ "Analyzer", RS.Modules.Tycoon.Component.TycoonAnalyzer },
	{ "Balances", RS.Modules.Tycoon.Component.TycoonBalances },
	{ "Purchases", RS.Modules.Tycoon.Component.TycoonPurchases },
	{ "Rebirth", RS.Modules.Tycoon.Component.TycoonRebirth },
	{ "Evolution", RS.Modules.Tycoon.Component.TycoonEvolution },
	{ "Ascension", RS.Modules.Tycoon.Component.TycoonAscension },
	{ "ClientBalances", RS.Modules.Tycoon.Component.Client.ClientTycoonBalances },
	{ "ClientRebirth", RS.Modules.Tycoon.Component.Client.ClientTycoonRebirth },
	{ "ClientAscension", RS.Modules.Tycoon.Component.Client.ClientTycoonAscension },
	{ "ClientIncome", RS.Modules.Tycoon.Component.Client.ClientTycoonIncome },
	{ "ClientPhoneOffers", RS.Modules.Tycoon.Component.Client.ClientTycoonPhoneOffers },
	{ "Balance", RS.Balance },
	{ "Task", RS.Core.Task },
	{ "TradeService", RS.Modules.Service.MinigameTradeService },
	{ "RaceService", RS.Modules.Service.MinigameRaceService },
	{ "UIMinigameTrade", RS.Modules.UI.Layers.Minigame.UIMinigameTrade },
	{ "UIMinigameRace", RS.Modules.UI.Layers.Minigame.UIMinigameRace },
	{ "UICashCheck", RS.Modules.UI.Layers.Popup.UICashCheck },
	{ "UIButton", RS.Core.UIButton },
}

local M = {}

local function loadModules()
	for _, entry in MODULE_PATHS do
		if not M[entry[1]] then
			local ok, mod = pcall(require, entry[2])
			if ok then
				M[entry[1]] = mod
			end
		end
	end
end

loadModules()

local Farm = {
	autoFruit = false,
	autoUpgrade = false,
	autoRebirth = false,
	autoAscend = false,
	autoCashDrop = false,
	autoComplete = false,
	autoPhone = false,
	autoTrade = false,
	autoRace = false,
	rebirthMultiplier = 1.5,
	upgradeMultiplier = 1,
	running = true,
	logLines = {},
	treeIndex = 1,
	treeGroups = {},
	treeRegistry = {},
	lastFullTreeScanAt = 0,
	lastRegistryRipeScanAt = 0,
	fruitState = "travel",
	lastTpTime = 0,
	collectAttempts = 0,
	fruitCycleAt = 0,
	lastFruitLogAt = 0,
	cashState = "travel",
	lastCashTpTime = 0,
	currentCashBag = nil,
	lastAction = "Idle",
	tick = 0,
	minigameBusy = false,
	phoneState = "idle",
	phoneRaises = 0,
	phoneUsesEvents = false,
	tycoonRetries = 0,
	lastTreeScanCount = nil,
	lastRegisteredTreeCount = nil,
	scannedTreeCount = 0,
	lastRebirthAttemptAt = 0,
	lastRebirthNoTycoonLogAt = 0,
	lastKnownRebirths = nil,
	rebirthKickstart = false,
	rebirthKickstartStartedAt = 0,
	lastRebirthKickstartWakeAt = 0,
	lastRebirthKickstartLogAt = 0,
	lastAscendAttemptAt = 0,
	lastAscendNoTycoonLogAt = 0,
	lastAscendProgressLogAt = 0,
	knownTotalAscensions = nil,
	lastUpgradeLogAt = 0,
	phoneConns = {},
}

local UI = {
	featureAccum = {},
	toggleCards = {},
	toggleRefreshers = {},
	teleportCards = {},
	teleportSections = {},
	searchQuery = "",
	activeNav = "Home",
	frames = 0,
}

local heartbeatConn

local function refreshUI()
	if UI.logLabel then
		UI.logLabel.Text = #Farm.logLines > 0 and table.concat(Farm.logLines, "\n") or "No activity yet."
	end
	if UI.statusLabel then
		UI.statusLabel.Text = "Status: " .. Farm.lastAction
	end
end

local function log(msg)
	table.insert(Farm.logLines, 1, os.date("%H:%M:%S") .. "  " .. msg)
	if #Farm.logLines > 12 then
		table.remove(Farm.logLines)
	end
	refreshUI()
end

local function setStatus(msg)
	Farm.lastAction = msg
	refreshUI()
end

local function getTycoon()
	if not M.Tycoon then
		return nil
	end
	local ok, t = pcall(M.Tycoon.getLocal)
	return ok and t or nil
end

local function findTycoonInstanceByOwner()
	for _, inst in workspace:GetChildren() do
		if inst.Name:match("^Tycoon%d+$") then
			local owner = inst:FindFirstChild("Owner")
			if owner and owner:IsA("ObjectValue") and owner.Value == plr then
				return inst
			end
		end
	end
	return nil
end

local function getTycoonInstance()
	local t = getTycoon()
	if t and t.Instance then
		return t.Instance
	end
	return findTycoonInstanceByOwner()
end

local function comp(t, name)
	if not (t and M[name]) then
		return nil
	end
	local ok, c = pcall(function()
		return t:GetComponent(M[name])
	end)
	return ok and c or nil
end

local function fmt(v)
	if v == nil then
		return "N/A"
	end
	if M.Huge and M.Huge.formatShort then
		local ok, a, b = pcall(M.Huge.formatShort, v)
		if ok and a then
			return b and (tostring(a) .. " " .. tostring(b)) or tostring(a)
		end
	end
	return tostring(v)
end

local function fmtCash(v)
	if v == nil then
		return "N/A"
	end
	if M.Huge and M.Huge.formatShort then
		local ok, a, b = pcall(M.Huge.formatShort, v, "$", 2)
		if ok and a then
			return b and (tostring(a) .. " " .. tostring(b)) or tostring(a)
		end
	end
	return tostring(v)
end

local function readStats()
	local stats = {
		tycoon = "Loading...",
		cash = "N/A",
		investors = "N/A",
		invSpent = "N/A",
		potential = "N/A",
		rebirths = "N/A",
		totalRebirths = "N/A",
		evolution = "N/A",
		totalEvolves = "N/A",
		ascensions = "N/A",
		totalAscensions = "N/A",
	}

	local ok = pcall(function()
		local t = getTycoon()
		if not t then
			stats.tycoon = "No tycoon yet"
			return
		end

		stats.tycoon = t.Instance and t.Instance.Name or "N/A"

		local tb = comp(t, "Balances")
		local tr = comp(t, "Rebirth")
		local te = comp(t, "Evolution")
		local ta = comp(t, "Ascension")
		local ca = comp(t, "ClientAscension")
		local cb = comp(t, "ClientBalances") or tb

		if cb then
			local cOk, cash = pcall(function()
				return cb:GetCash()
			end)
			stats.cash = cOk and fmtCash(cash) or "N/A"
		end

		if tb then
			local iOk, inv = pcall(function()
				return tb:GetInvestors()
			end)
			stats.investors = iOk and fmt(inv) or "N/A"

			local sOk, spent = pcall(function()
				return tb:GetInvestorsSpent()
			end)
			stats.invSpent = sOk and fmt(spent) or "N/A"
		end

		if tr then
			local pOk, pot = pcall(function()
				return tr:GetPotentialInvestors()
			end)
			stats.potential = pOk and fmt(pot) or "N/A"

			local rOk, reb = pcall(function()
				return tr:GetRebirths()
			end)
			stats.rebirths = rOk and tostring(reb) or "N/A"

			local trOk, total = pcall(function()
				return tr:GetTotalRebirths()
			end)
			stats.totalRebirths = trOk and tostring(total) or "N/A"
		end

		if te then
			local eOk, evo = pcall(function()
				return te:GetEvolution()
			end)
			stats.evolution = eOk and tostring(evo) or "N/A"

			local teOk, total = pcall(function()
				return te:GetTotalEvolves()
			end)
			stats.totalEvolves = teOk and tostring(total) or "N/A"
		end

		if ta or ca then
			local total, current = readAscensionCounts(ta, ca)
			if current ~= nil then
				stats.ascensions = tostring(current)
			end
			if total ~= nil then
				stats.totalAscensions = tostring(total)
			end
		end
	end)

	if not ok then
		stats.tycoon = "Error reading stats"
	end

	return stats
end

local function callComponentNumber(compObj, methodName)
	if not (compObj and compObj[methodName]) then
		return nil
	end
	local ok, result = pcall(function()
		return compObj[methodName](compObj)
	end)
	if ok and type(result) == "number" then
		return result
	end
	return nil
end

local function readAscensionCounts(ta, ca)
	for _, name in ipairs({ "GetTotalAscensions", "GetTotalAscends", "GetTotalAscension" }) do
		local total = callComponentNumber(ta, name) or callComponentNumber(ca, name)
		if total ~= nil then
			Farm.knownTotalAscensions = math.max(Farm.knownTotalAscensions or 0, total)
			local current = callComponentNumber(ta, "GetAscension") or callComponentNumber(ca, "GetAscension")
			return total, current
		end
	end

	for _, attr in ipairs({ "TotalAscensions", "Ascensions", "Ascension" }) do
		local attrVal = plr:GetAttribute(attr)
		if type(attrVal) == "number" then
			Farm.knownTotalAscensions = math.max(Farm.knownTotalAscensions or 0, attrVal)
			local current = callComponentNumber(ta, "GetAscension") or callComponentNumber(ca, "GetAscension")
			return attrVal, current
		end
	end

	local inst = getTycoonInstance()
	if inst then
		for _, valueName in ipairs({ "TotalAscensions", "Ascensions", "Ascension" }) do
			local valueObj = inst:FindFirstChild(valueName, true)
			if valueObj and valueObj:IsA("NumberValue") then
				local total = valueObj.Value
				Farm.knownTotalAscensions = math.max(Farm.knownTotalAscensions or 0, total)
				local current = callComponentNumber(ta, "GetAscension") or callComponentNumber(ca, "GetAscension")
				return total, current
			end
		end
	end

	local current = callComponentNumber(ta, "GetAscension") or callComponentNumber(ca, "GetAscension")
	if Farm.knownTotalAscensions ~= nil then
		return Farm.knownTotalAscensions, current
	end
	if current ~= nil then
		return current, current
	end
	return nil, nil
end

local function readAscensionStats()
	local out = {
		progress = nil,
		progressText = "N/A",
		level = "N/A",
		ready = false,
	}
	pcall(function()
		local t = getTycoon()
		if not t then
			out.progressText = "No tycoon"
			return
		end
		local ca = comp(t, "ClientAscension")
		local ta = comp(t, "Ascension")
		if ca then
			local ok, progress = pcall(function()
				return ca:GetAscensionProgress()
			end)
			if ok and progress ~= nil then
				out.progress = progress
				out.progressText = string.format("%.0f%%", progress * 100)
				out.ready = progress >= 1
			end
		end
		local total, current = readAscensionCounts(ta, ca)
		if total ~= nil then
			out.level = tostring(total)
		elseif current ~= nil then
			out.level = tostring(current)
		end
	end)
	return out
end

local function getHRP()
	local char = plr.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
	local hrp = getHRP()
	if hrp then
		hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	end
end

local function resolveInstFromPath(path)
	if not path or path == "" then
		return nil
	end
	local cur = game
	for part in string.gmatch(path, "[^%.]+") do
		if part == "Workspace" then
			cur = workspace
		elseif part ~= "game" then
			cur = cur and cur:FindFirstChild(part)
		end
	end
	return cur
end

local function getInstPosition(inst, fallback)
	if not inst then
		return fallback
	end
	local ok, pos = pcall(function()
		if inst:IsA("BasePart") then
			return inst.Position
		end
		return inst:GetPivot().Position
	end)
	if ok and pos then
		return pos
	end
	local part = inst:FindFirstChildWhichIsA("BasePart", true)
	if part then
		return part.Position
	end
	return fallback
end

local TELEPORT_CATEGORIES = {
	{
		name = "Entrances",
		icon = "🚪",
		locations = {
			{ name = "Entrance (1)", path = "Workspace.Map.Sewer.Build.Entrances.SewerEntrance", pos = Vector3.new(-1.1, -9.5, 96), index = 1 },
			{ name = "Entrance (2)", path = "Workspace.Map.Sewer.Build.Entrances.SewerEntrance", pos = Vector3.new(-1.1, -9.5, -96), index = 2 },
			{ name = "Entrance (3)", path = "Workspace.Map.Sewer.Build.Entrances.SewerEntrance", pos = Vector3.new(-1.1, -9.5, -256), index = 3 },
			{ name = "Entrance (4)", path = "Workspace.Map.Sewer.Build.Entrances.SewerEntrance", pos = Vector3.new(-1.1, -9.5, 256), index = 4 },
		},
	},
	{
		name = "Sewer Exits",
		icon = "🕳",
		locations = {
			{ name = "Sewer Exit (1)", path = "Workspace.Map.Sewer.Exits.Exit", pos = Vector3.new(-293, -39, 0), index = 1 },
			{ name = "Sewer Exit (2)", path = "Workspace.Map.Sewer.Exits.Exit", pos = Vector3.new(0, -39, -283), index = 2 },
			{ name = "Sewer Exit (3)", path = "Workspace.Map.Sewer.Exits.Exit", pos = Vector3.new(0, -39, 283), index = 3 },
			{ name = "Sewer Exit (4)", path = "Workspace.Map.Sewer.Exits.Exit", pos = Vector3.new(294, -39, 0), index = 4 },
			{ name = "Sewer Exit Left", path = "Workspace.Locations.SewerExitLeft", pos = Vector3.new(0, 1, -448) },
			{ name = "Sewer Exit Right", path = "Workspace.Locations.SewerExitRight", pos = Vector3.new(0, 1, 448) },
		},
	},
	{
		name = "Vine Area",
		icon = "🌿",
		locations = {
			{ name = "Vine Door", path = "Workspace.Map.Sewer.CashVine.VineDoor", pos = Vector3.new(32, -32, -77.1) },
			{ name = "Vine Key", path = "Workspace.Map.Sewer.CashVine.VineKey", pos = Vector3.new(-167.1, -42.1, -106) },
			{ name = "Cash Vine", path = "Workspace.Map.Sewer.CashVine.CashVine", pos = Vector3.new(41.2, -31, -77.1) },
		},
	},
	{
		name = "Blue Doors",
		icon = "🔵",
		locations = {
			{ name = "Blue Door (1)", path = "Workspace.Map.Sewer.DoorsBlue.Door (Blue)", pos = Vector3.new(296.9, -33.5, -110), index = 1 },
			{ name = "Blue Door (2)", path = "Workspace.Map.Sewer.DoorsBlue.Door (Blue)", pos = Vector3.new(214, -33.6, 195), index = 2 },
			{ name = "Blue Door (3)", path = "Workspace.Map.Sewer.DoorsBlue.Door (Blue)", pos = Vector3.new(-148.6, -33.5, 136), index = 3 },
			{ name = "Inverse Door", path = "Workspace.Map.Sewer.DoorsBlue.InverseDoor (Blue)", pos = Vector3.new(-195.1, -33.5, -142) },
			{ name = "Blue Lever", path = "Workspace.Map.Sewer.DoorsBlue.Lever (Blue)", pos = Vector3.new(31.4, -42.9, 284.8) },
		},
	},
	{
		name = "Green Doors",
		icon = "🟢",
		locations = {
			{ name = "Green Door (1)", path = "Workspace.Map.Sewer.DoorsGreen.Door (Green)", pos = Vector3.new(-47.1, -33.5, 184), index = 1 },
			{ name = "Green Door (2)", path = "Workspace.Map.Sewer.DoorsGreen.Door (Green)", pos = Vector3.new(-259.6, -33.5, -43), index = 2 },
			{ name = "Green Door (3)", path = "Workspace.Map.Sewer.DoorsGreen.Door (Green)", pos = Vector3.new(-93.1, -33.5, -204.5), index = 3 },
			{ name = "Green Door (4)", path = "Workspace.Map.Sewer.DoorsGreen.Door (Green)", pos = Vector3.new(204.9, -33.5, -277), index = 4 },
			{ name = "Green Door (5)", path = "Workspace.Map.Sewer.DoorsGreen.Door (Green)", pos = Vector3.new(296.9, -33.5, -130), index = 5 },
			{ name = "Inverse Door (1)", path = "Workspace.Map.Sewer.DoorsGreen.InverseDoor (Green)", pos = Vector3.new(296.5, -33.6, 96.5), index = 1 },
			{ name = "Inverse Door (2)", path = "Workspace.Map.Sewer.DoorsGreen.InverseDoor (Green)", pos = Vector3.new(159, -33.6, 123), index = 2 },
			{ name = "Inverse Door (3)", path = "Workspace.Map.Sewer.DoorsGreen.InverseDoor (Green)", pos = Vector3.new(121.5, -33.6, 88.5), index = 3 },
			{ name = "Green Lever", path = "Workspace.Map.Sewer.DoorsGreen.Lever (Green)", pos = Vector3.new(-159.6, -42.8, 231.6) },
		},
	},
	{
		name = "Red Doors",
		icon = "🔴",
		locations = {
			{ name = "Red Door (1)", path = "Workspace.Map.Sewer.DoorsRed.Door (Red)", pos = Vector3.new(196, -33.6, 87), index = 1 },
			{ name = "Red Door (2)", path = "Workspace.Map.Sewer.DoorsRed.Door (Red)", pos = Vector3.new(-47.1, -33.5, -123.5), index = 2 },
			{ name = "Red Door (3)", path = "Workspace.Map.Sewer.DoorsRed.Door (Red)", pos = Vector3.new(296.9, -33.5, -150), index = 3 },
			{ name = "Red Door (4)", path = "Workspace.Map.Sewer.DoorsRed.Door (Red)", pos = Vector3.new(-148.6, -33.5, 149.5), index = 4 },
			{ name = "Inverse Door (1)", path = "Workspace.Map.Sewer.DoorsRed.InverseDoor (Red)", pos = Vector3.new(149.4, -33, -132), index = 1 },
			{ name = "Inverse Door (2)", path = "Workspace.Map.Sewer.DoorsRed.InverseDoor (Red)", pos = Vector3.new(39, -33.6, 150), index = 2 },
			{ name = "Inverse Door (3)", path = "Workspace.Map.Sewer.DoorsRed.InverseDoor (Red)", pos = Vector3.new(241.9, -33.5, -187), index = 3 },
			{ name = "Inverse Door (4)", path = "Workspace.Map.Sewer.DoorsRed.InverseDoor (Red)", pos = Vector3.new(140, -33.6, 105), index = 4 },
			{ name = "Red Lever", path = "Workspace.Map.Sewer.DoorsRed.Lever (Red)", pos = Vector3.new(-37.8, -42.8, -98.6) },
		},
	},
	{
		name = "Purple Doors",
		icon = "🟣",
		locations = {
			{ name = "Purple Door (1)", path = "Workspace.Map.Sewer.DoorsPurple.Door (Purple)", pos = Vector3.new(204.5, -33.6, 238.5), index = 1 },
			{ name = "Purple Door (2)", path = "Workspace.Map.Sewer.DoorsPurple.Door (Purple)", pos = Vector3.new(-130.6, -33.5, -97.5), index = 2 },
			{ name = "Purple Door (3)", path = "Workspace.Map.Sewer.DoorsPurple.Door (Purple)", pos = Vector3.new(232, -33.6, 214), index = 3 },
			{ name = "Purple Door (4)", path = "Workspace.Map.Sewer.DoorsPurple.Door (Purple)", pos = Vector3.new(-277.6, -33.5, 277.5), index = 4 },
			{ name = "Purple Door (5)", path = "Workspace.Map.Sewer.DoorsPurple.Door (Purple)", pos = Vector3.new(296.9, -33.5, -90), index = 5 },
			{ name = "Inverse Door (1)", path = "Workspace.Map.Sewer.DoorsPurple.InverseDoor (Purple)", pos = Vector3.new(39.5, -33.6, 169), index = 1 },
			{ name = "Inverse Door (2)", path = "Workspace.Map.Sewer.DoorsPurple.InverseDoor (Purple)", pos = Vector3.new(-111.6, -33.5, -97.5), index = 2 },
			{ name = "Purple Lever", path = "Workspace.Map.Sewer.DoorsPurple.Lever (Purple)", pos = Vector3.new(160.5, -42.5, -267.8) },
		},
	},
	{
		name = "Sewer Landmarks",
		icon = "📍",
		locations = {
			{ name = "Maze End", path = "Workspace.Map.Sewer.Build.MazeEnd", pos = Vector3.new(39.8, -32.6, -77.3) },
			{ name = "Sewer Leaderboard", path = "Workspace.Map.Sewer.Build.Leaderboard", pos = Vector3.new(-11, -35.8, 12.3) },
			{ name = "Ghost Hunter Bo", path = "Workspace.Map.Sewer.Bo", pos = Vector3.new(299.8, -42.7, -74.9) },
		},
	},
	{
		name = "Alien Area",
		icon = "👽",
		locations = {
			{ name = "Sewer Alien", path = "Workspace.Map.Sewer.SewerAlien", pos = Vector3.new(-42.3, -41.5, 180.6) },
			{ name = "Alien NPC", path = "Workspace.Map.Sewer.SewerAlien.Alien", pos = Vector3.new(-39.5, -45.2, 176.9) },
			{ name = "UFO Key", path = "Workspace.Map.Sewer.SewerAlien.UFOKey", pos = Vector3.new(204.0, -42.0, 285.0) },
			{ name = "Alien Cam", path = "Workspace.Map.Sewer.SewerAlien.CamListen", pos = Vector3.new(-29.1, -41.1, 178.4) },
		},
	},
}

local function resolveIndexedInst(path, index)
	local parentPath = path:match("^(.*)%.[^%.]+$") or path
	local childName = path:match("%.([^%.]+)$")
	local parent = resolveInstFromPath(parentPath)
	if not (parent and childName and index) then
		return resolveInstFromPath(path)
	end
	local i = 0
	for _, child in parent:GetChildren() do
		if child.Name == childName then
			i += 1
			if i == index then
				return child
			end
		end
	end
	return resolveInstFromPath(path)
end

local function fireProximityPrompt(prompt)
	if not prompt then
		return false
	end
	if fireproximityprompt then
		local ok = pcall(fireproximityprompt, prompt)
		if ok then
			return true
		end
	end
	if getconnections then
		local ok = pcall(function()
			for _, conn in getconnections(prompt.Triggered) do
				if conn.Function then
					conn:Fire()
				else
					conn:Fire(plr)
				end
			end
		end)
		if ok then
			return true
		end
	end
	return false
end

local function clickDetector(cd)
	if not cd then
		return false
	end
	if fireclickdetector then
		local ok = pcall(fireclickdetector, cd, 0)
		if ok then
			return true
		end
		ok = pcall(fireclickdetector, cd)
		if ok then
			return true
		end
	end
	if getconnections then
		local ok = pcall(function()
			for _, conn in getconnections(cd.MouseClick) do
				if conn.Function then
					conn:Fire()
				else
					conn:Fire(plr)
				end
			end
		end)
		if ok then
			return true
		end
	end
	local clickPart = cd.Parent
	if clickPart and clickPart:IsA("BasePart") and getconnections then
		local ok = pcall(function()
			for _, conn in getconnections(clickPart.MouseButton1Click) do
				if conn.Function then
					conn:Fire()
				else
					conn:Fire(plr)
				end
			end
		end)
		if ok then
			return true
		end
	end
	return false
end

local function fireGuiButton(btn)
	if not btn then
		return false
	end
	if getconnections then
		local ok = pcall(function()
			for _, conn in getconnections(btn.MouseButton1Click) do
				conn:Fire()
			end
		end)
		if ok then
			return true
		end
	end
	return false
end

local TREE_ANCHOR_NAMES = { "HumanoidRootPart", "Trunk", "Base", "Root", "Handle", "Main", "Primary" }

local function getInteractionPosition(node, part)
	if part and part:IsA("BasePart") then
		return part.Position
	end
	if node:IsA("BasePart") then
		return node.Position
	end
	local ok, pivot = pcall(function()
		return node:GetPivot().Position
	end)
	return ok and pivot or nil
end

local function findClickPartForNode(node)
	local clickPart = node:FindFirstChild("ClickPart", false)
	if not clickPart then
		clickPart = node:FindFirstChild("ClickPart", true)
	end
	if not clickPart and node.Parent then
		local sibling = node.Parent:FindFirstChild("ClickPart")
		if sibling and sibling ~= node then
			clickPart = sibling
		end
	end
	if not clickPart and node:IsA("BasePart") then
		clickPart = node
	end
	return clickPart
end

local function getCollectInteraction(node)
	local clickPart = findClickPartForNode(node)
	if clickPart then
		local cd = clickPart:FindFirstChildWhichIsA("ClickDetector", true)
		if cd then
			return cd, nil, getInteractionPosition(node, clickPart)
		end
		local prompt = clickPart:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			return nil, prompt, getInteractionPosition(node, clickPart)
		end
	end

	local cd = node:FindFirstChildWhichIsA("ClickDetector", true)
	if cd then
		local part = cd.Parent
		return cd, nil, getInteractionPosition(node, part and part:IsA("BasePart") and part)
	end

	local prompt = node:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		local part = prompt.Parent
		return nil, prompt, getInteractionPosition(node, part and part:IsA("BasePart") and part)
	end

	return nil, nil, nil
end

local function resolveCollectInteraction(entry)
	local cd, prompt = entry.cd, entry.prompt
	if cd and not cd.Parent then
		cd = nil
	end
	if prompt and not prompt.Parent then
		prompt = nil
	end
	if not (cd or prompt) and entry.fruit and entry.fruit.Parent then
		cd, prompt, entry.pos = getCollectInteraction(entry.fruit)
		entry.cd = cd
		entry.prompt = prompt
	end
	return cd, prompt
end

local function fireCollectInteraction(entry)
	local cd, prompt = resolveCollectInteraction(entry)
	if cd and clickDetector(cd) then
		return true
	end
	if prompt and fireProximityPrompt(prompt) then
		return true
	end
	return false
end

local function isFruitNode(node)
	if node.Name == "Fruit" then
		return true
	end
	if CollectionService:HasTag(node, "ClickFruit") then
		return node:IsA("BasePart") or node:IsA("Model")
	end
	return false
end

local function treeHasFruitContent(tree)
	for _, desc in tree:GetDescendants() do
		if isFruitNode(desc) then
			return true
		end
	end
	return false
end

local function isProduceTreeName(name)
	if type(name) ~= "string" or name == "Tree" then
		return false
	end
	return name:match("^[%w]+Tree%d*$") ~= nil or name:match("Tree%d*$") ~= nil
end

local function isExcludedTreePath(inst)
	return inst:GetFullName():find("%.Decor%.", 1, true) ~= nil
end

local function isDecorTreeInstance(inst)
	return inst.Name == "Tree" and isExcludedTreePath(inst)
end

local function isFruitTreeInstance(inst)
	if inst:IsA("Model") or inst:IsA("Folder") then
		if isExcludedTreePath(inst) then
			return false
		end
		if isProduceTreeName(inst.Name) then
			return true
		end
		if inst.Name == "Tree" and treeHasFruitContent(inst) then
			return true
		end
		if inst:IsA("Model") and treeHasFruitContent(inst) then
			return true
		end
	end
	return false
end

local function isOwnedByOtherPlayer(node)
	local cur = node
	while cur and cur ~= workspace do
		if cur.Name:match("^Tycoon%d$") then
			local owner = cur:FindFirstChild("Owner")
			if owner and owner:IsA("ObjectValue") and owner.Value and owner.Value ~= plr then
				return true
			end
			return false
		end
		cur = cur.Parent
	end
	return false
end

local function isCollectibleFruitScope(node)
	if not node or not node.Parent then
		return false
	end
	return not isOwnedByOtherPlayer(node)
end

local function isNestedInProduceTree(inst)
	local parent = inst.Parent
	while parent and parent ~= workspace do
		if isFruitTreeInstance(parent) and isProduceTreeName(parent.Name) then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function resolveFruitTreeRoot(node)
	local typedTree
	local genericTree
	local fruitModel
	local cur = node
	while cur and cur ~= workspace do
		if cur:IsA("Model") or cur:IsA("Folder") then
			if isExcludedTreePath(cur) then
				cur = cur.Parent
				continue
			end
			if isProduceTreeName(cur.Name) then
				typedTree = cur
				break
			end
			if cur.Name == "Tree" and not genericTree then
				genericTree = cur
			end
			if cur:IsA("Model") and treeHasFruitContent(cur) and not fruitModel then
				fruitModel = cur
			end
		end
		cur = cur.Parent
	end
	return typedTree or genericTree or fruitModel
end

local function getTreeShortId(tree)
	local ok, id = pcall(function()
		return tree:GetDebugId()
	end)
	if ok and type(id) == "string" and #id > 0 then
		return id:gsub("^1_", "")
	end
	return tostring(tree):match("0x[%x]+") or "?"
end

local function getShortPath(fullPath)
	local parts = {}
	for segment in fullPath:gmatch("[^%.]+") do
		table.insert(parts, segment)
	end
	local n = #parts
	if n <= 3 then
		return table.concat(parts, ".")
	end
	return parts[n - 2] .. "." .. parts[n - 1] .. "." .. parts[n]
end

local function ensureTreeGroup(byId, tree, nameCounts)
	if byId[tree] then
		return byId[tree]
	end
	local baseName = tree.Name
	nameCounts[baseName] = (nameCounts[baseName] or 0) + 1
	local path = tree:GetFullName():gsub("^Workspace%.", "")
	local shortPath = getShortPath(path)
	local label = baseName .. " @ " .. shortPath
	byId[tree] = {
		root = tree,
		treeId = getTreeShortId(tree),
		path = path,
		name = label,
		fruits = {},
	}
	return byId[tree]
end

local function collectFruitFromNode(node, byId, nameCounts)
	local cd, prompt, pos = getCollectInteraction(node)
	if not (cd or prompt) or not pos then
		return
	end
	local tree = resolveFruitTreeRoot(node)
	if not tree or tree == workspace then
		return
	end
	local group = ensureTreeGroup(byId, tree, nameCounts)
	table.insert(group.fruits, { fruit = node, cd = cd, prompt = prompt, pos = pos })
end

local function scanTreeInstance(tree, byId, nameCounts)
	ensureTreeGroup(byId, tree, nameCounts)
	for _, desc in tree:GetDescendants() do
		if isFruitNode(desc) then
			collectFruitFromNode(desc, byId, nameCounts)
		end
	end
end

local function getFruitScanRoots()
	local roots = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(roots, map)
	end
	for _, ch in workspace:GetChildren() do
		if ch.Name:match("^Tycoon%d+$") and isCollectibleFruitScope(ch) then
			table.insert(roots, ch)
		end
	end
	if #roots == 0 then
		table.insert(roots, workspace)
	end
	return roots
end

local function findAllProduceTrees()
	local trees = {}
	local seen = {}
	for _, root in getFruitScanRoots() do
		for _, desc in root:GetDescendants() do
			if isCollectibleFruitScope(desc) and isFruitTreeInstance(desc) and not isNestedInProduceTree(desc) and not seen[desc] then
				seen[desc] = true
				table.insert(trees, desc)
			end
		end
	end
	return trees
end

local function countRipeFruitsOnTree(group)
	if group.fruits and #group.fruits > 0 then
		local n = 0
		for _, entry in group.fruits do
			if entry.fruit.Parent then
				local cd, prompt = resolveCollectInteraction(entry)
				if cd or prompt then
					n += 1
				end
			end
		end
		return n
	end
	local n = 0
	local tree = group.root
	if not tree or not tree.Parent then
		return 0
	end
	for _, desc in tree:GetDescendants() do
		if isFruitNode(desc) then
			local cd, prompt = getCollectInteraction(desc)
			if cd or prompt then
				n += 1
			end
		end
	end
	return n
end

local function rebuildTreeRegistry()
	local byId = {}
	local nameCounts = {}

	for _, tree in findAllProduceTrees() do
		ensureTreeGroup(byId, tree, nameCounts)
	end

	for _, fruit in CollectionService:GetTagged("ClickFruit") do
		if isCollectibleFruitScope(fruit) and fruit.Parent then
			local tree = resolveFruitTreeRoot(fruit)
			if tree and tree ~= workspace then
				ensureTreeGroup(byId, tree, nameCounts)
			end
		end
	end

	local registry = {}
	for _, group in byId do
		group.fruits = {}
		table.insert(registry, group)
	end
	table.sort(registry, function(a, b)
		return a.path < b.path
	end)

	Farm.treeRegistry = registry
	Farm.scannedTreeCount = #registry
	Farm.lastFullTreeScanAt = os.clock()

	local prevRegistered = Farm.lastRegisteredTreeCount
	if prevRegistered ~= #registry then
		Farm.lastRegisteredTreeCount = #registry
		log("Tree registry: " .. #registry .. " produce trees on map")
	end
end

local function updateRipeTreeQueue(scanRegistryTrees)
	local byId = {}
	local nameCounts = {}

	for _, fruit in CollectionService:GetTagged("ClickFruit") do
		if isCollectibleFruitScope(fruit) and fruit.Parent then
			collectFruitFromNode(fruit, byId, nameCounts)
		end
	end

	if scanRegistryTrees then
		for _, reg in Farm.treeRegistry do
			local tree = reg.root
			if tree and tree.Parent then
				local group = ensureTreeGroup(byId, tree, nameCounts)
				group.path = reg.path
				group.name = reg.name
				group.treeId = reg.treeId
				for _, desc in tree:GetDescendants() do
					if isFruitNode(desc) then
						collectFruitFromNode(desc, byId, nameCounts)
					end
				end
			end
		end
		Farm.lastRegistryRipeScanAt = os.clock()
	end

	local order = {}
	local ripeTreeCount = 0
	local fruitCount = 0
	for _, group in byId do
		local ripe = countRipeFruitsOnTree(group)
		if ripe > 0 then
			ripeTreeCount += 1
			fruitCount += ripe
			table.insert(order, group)
		end
	end
	table.sort(order, function(a, b)
		return a.path < b.path
	end)

	local prevRipe = #Farm.treeGroups
	Farm.treeGroups = order

	if prevRipe ~= #order then
		log(
			"Ripe trees: "
				.. ripeTreeCount
				.. "/"
				.. Farm.scannedTreeCount
				.. " ("
				.. fruitCount
				.. " fruits)"
		)
	end

	if Farm.treeIndex > #Farm.treeGroups then
		if Farm.fruitState == "travel" or #Farm.treeGroups == 0 then
			Farm.treeIndex = 1
		else
			Farm.treeIndex = math.min(Farm.treeIndex, math.max(1, #Farm.treeGroups))
		end
	end
end

local function refreshTreeGroups(forceFull)
	local now = os.clock()
	if forceFull or #Farm.treeRegistry == 0 or now - Farm.lastFullTreeScanAt >= FRUIT_FULL_SCAN_INTERVAL then
		rebuildTreeRegistry()
	end

	local scanRegistry = forceFull
		or now - Farm.lastRegistryRipeScanAt >= FRUIT_REGISTRY_RIPE_INTERVAL
		or #Farm.treeGroups == 0

	updateRipeTreeQueue(scanRegistry)
end

local function getTreePosition(group)
	local tree = group.root
	if tree and tree.Parent then
		local ok, pivot = pcall(function()
			return tree:GetPivot().Position
		end)
		if ok and pivot then
			return pivot
		end
		if tree:IsA("Model") and tree.PrimaryPart then
			return tree.PrimaryPart.Position
		end
		for _, anchorName in TREE_ANCHOR_NAMES do
			local part = tree:FindFirstChild(anchorName, true)
			if part and part:IsA("BasePart") then
				return part.Position
			end
		end
		local anyPart = tree:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			return anyPart.Position
		end
	end
	local center = Vector3.zero
	local count = 0
	for _, entry in group.fruits do
		if entry.fruit.Parent and (not entry.cd or entry.cd.Parent) and (not entry.prompt or entry.prompt.Parent) then
			center += entry.pos
			count += 1
		end
	end
	if count > 0 then
		return center / count
	end
	return nil
end

local function getActiveFruitsOnTree(group)
	local active = {}
	if group.fruits and #group.fruits > 0 then
		for _, entry in group.fruits do
			if entry.fruit.Parent then
				local cd, prompt = resolveCollectInteraction(entry)
				if (cd or prompt) and entry.pos then
					table.insert(active, { fruit = entry.fruit, cd = cd, prompt = prompt, pos = entry.pos })
				end
			end
		end
		if #active > 0 then
			return active
		end
	end
	local tree = group.root
	if not tree or not tree.Parent then
		return active
	end
	for _, desc in tree:GetDescendants() do
		if isFruitNode(desc) then
			local cd, prompt, pos = getCollectInteraction(desc)
			if (cd or prompt) and pos then
				table.insert(active, { fruit = desc, cd = cd, prompt = prompt, pos = pos })
			end
		end
	end
	return active
end

local function countActiveFruits()
	local n = 0
	for _, group in Farm.treeGroups do
		n += countRipeFruitsOnTree(group)
	end
	return n
end

local function advanceToNextTree()
	Farm.treeIndex += 1
	if Farm.treeIndex > #Farm.treeGroups then
		refreshTreeGroups(true)
		Farm.treeIndex = 1
		if #Farm.treeGroups == 0 then
			Farm.fruitCycleAt = os.clock()
		else
			Farm.fruitCycleAt = 0
		end
	end
	Farm.fruitState = "travel"
	Farm.collectAttempts = 0
end

local function fruitWaitingStatus()
	local n = Farm.scannedTreeCount or 0
	if n > 0 then
		return "Waiting for fruits… (" .. n .. " map trees)"
	end
	return "Waiting for fruits…"
end

local function tryAutoFruit()
	local now = os.clock()

	if #Farm.treeRegistry == 0 then
		refreshTreeGroups(true)
	elseif #Farm.treeGroups == 0 then
		refreshTreeGroups(false)
	end

	if #Farm.treeGroups == 0 and getTycoonInstance() then
		loadModules()
		refreshTreeGroups(true)
	end
	if #Farm.treeGroups == 0 then
		if Farm.fruitCycleAt == 0 then
			Farm.fruitCycleAt = now
		end
		if now - Farm.fruitCycleAt < FRUIT_EMPTY_CYCLE_DELAY then
			setStatus(fruitWaitingStatus())
			return
		end
		Farm.fruitCycleAt = 0
		refreshTreeGroups(true)
		if #Farm.treeGroups == 0 then
			Farm.fruitCycleAt = now
			setStatus(fruitWaitingStatus())
			return
		end
	end

	if Farm.treeIndex > #Farm.treeGroups then
		Farm.treeIndex = 1
	end

	if Farm.fruitCycleAt > 0 and now - Farm.fruitCycleAt < FRUIT_EMPTY_CYCLE_DELAY then
		setStatus(fruitWaitingStatus())
		return
	end

	local group = Farm.treeGroups[Farm.treeIndex]
	if not group or not group.root or not group.root.Parent then
		refreshTreeGroups(false)
		advanceToNextTree()
		return
	end

	if Farm.fruitState == "travel" then
		local active = getActiveFruitsOnTree(group)
		if #active == 0 then
			refreshTreeGroups(false)
			advanceToNextTree()
			return
		end
		Farm.fruitCycleAt = 0
		local center = Vector3.zero
		for _, entry in active do
			center += entry.pos
		end
		local pos = center / #active
		tpTo(pos)
		Farm.lastTpTime = now
		Farm.fruitState = "wait"
		setStatus("→ " .. group.name .. " (" .. #active .. " ripe)")
		if now - Farm.lastFruitLogAt > 2 then
			Farm.lastFruitLogAt = now
			log("Fruit: visit " .. group.name .. " id=" .. (group.treeId or "?") .. " ripe=" .. #active)
		end
		return
	end

	if Farm.fruitState == "wait" then
		if now - Farm.lastTpTime < FRUIT_TRAVEL_DWELL then
			return
		end
		Farm.fruitState = "collecting"
		Farm.collectAttempts = 0
	end

	if Farm.fruitState == "collecting" then
		local active = getActiveFruitsOnTree(group)
		if #active == 0 then
			refreshTreeGroups(false)
			setStatus(group.name .. ": cleared")
			if now - Farm.lastFruitLogAt > 1 then
				Farm.lastFruitLogAt = now
				log("Fruit: " .. group.name .. " cleared")
			end
			advanceToNextTree()
			return
		end

		local clicked = 0
		for _, entry in active do
			if not entry.fruit.Parent then
				continue
			end
			if fireCollectInteraction(entry) then
				clicked += 1
			end
		end
		Farm.collectAttempts += 1

		local remaining = 0
		for _, entry in active do
			if entry.fruit.Parent then
				local cd, prompt = resolveCollectInteraction(entry)
				if cd or prompt then
					remaining += 1
				end
			end
		end

		if remaining == 0 then
			refreshTreeGroups(false)
			setStatus(group.name .. ": cleared")
			log("Fruit: " .. group.name .. " collected " .. clicked)
			advanceToNextTree()
		elseif Farm.collectAttempts >= FRUIT_MAX_COLLECT_ATTEMPTS then
			refreshTreeGroups(true)
			setStatus(group.name .. ": next tree")
			log("Fruit: " .. group.name .. " max attempts, ripe=" .. remaining)
			advanceToNextTree()
		elseif clicked > 0 then
			setStatus(group.name .. ": " .. clicked .. " fruits")
			if now - Farm.lastFruitLogAt > 1 then
				Farm.lastFruitLogAt = now
				log("Fruit: " .. group.name .. " +" .. clicked .. " (left " .. remaining .. ")")
			end
		elseif Farm.collectAttempts % 8 == 1 and now - Farm.lastFruitLogAt > 2 then
			Farm.lastFruitLogAt = now
			log("Fruit: " .. group.name .. " try #" .. Farm.collectAttempts .. " ripe=" .. #active)
		end
	end
end

local function listCashBags(drops)
	local bags = {}
	for _, drop in drops:GetChildren() do
		local bag = drop:FindFirstChild("Bag", true)
		local pos = bag and bag.Position or (drop:IsA("BasePart") and drop.Position)
		if pos then
			table.insert(bags, { drop = drop, pos = pos })
		end
	end
	return bags
end

local function tryAutoCashDrop()
	local now = os.clock()
	local drops = workspace:FindFirstChild("CashDrops")
	if not drops then
		Farm.cashState = "travel"
		Farm.currentCashBag = nil
		return
	end

	local hrp = getHRP()
	if not hrp then
		return
	end

	local bags = listCashBags(drops)
	if #bags == 0 then
		Farm.cashState = "travel"
		Farm.currentCashBag = nil
		return
	end

	if Farm.cashState == "travel" then
		local target
		if Farm.currentCashBag and Farm.currentCashBag.Parent then
			for _, bag in bags do
				if bag.drop == Farm.currentCashBag then
					target = bag
					break
				end
			end
		end
		if not target then
			local closest, closestDist
			for _, bag in bags do
				local dist = (hrp.Position - bag.pos).Magnitude
				if not closestDist or dist < closestDist then
					closest = bag
					closestDist = dist
				end
			end
			target = closest
		end
		if target then
			tpTo(target.pos)
			Farm.currentCashBag = target.drop
			Farm.lastCashTpTime = now
			Farm.cashState = "wait"
			setStatus("Travel → cash bag")
		end
		return
	end

	if Farm.cashState == "wait" then
		if now - Farm.lastCashTpTime < CASH_TRAVEL_DWELL then
			return
		end
		if not Farm.currentCashBag or not Farm.currentCashBag.Parent then
			Farm.cashState = "travel"
			Farm.currentCashBag = nil
			return
		end
		Farm.cashState = "collecting"
		setStatus("Collecting cash bag")
		return
	end

	if Farm.cashState == "collecting" then
		if not Farm.currentCashBag or not Farm.currentCashBag.Parent then
			log("Cash bag collected")
			Farm.cashState = "travel"
			Farm.currentCashBag = nil
			setStatus("Cash bag done")
		else
			setStatus("Waiting at cash bag...")
		end
	end
end

local function tryAutoBuy(maxCount)
	maxCount = maxCount or 1
	local t = getTycoon()
	if not t then
		return 0
	end
	local a = comp(t, "Analyzer")
	local cb = comp(t, "ClientBalances")
	if not (a and cb and M.Balance) then
		return 0
	end

	local purchases = a:GetPurchases()
	local bought = 0
	for _ = 1, maxCount do
		local didBuy = false
		for _, key in M.Balance.PurchaseOrder do
			local purchase = purchases[key]
			if purchase and purchase:IsEnabled() and not purchase:IsPurchased() then
				local price = purchase:GetPrice()
				if price and cb:GetCash() >= price then
					local ok, err = pcall(function()
						if purchase.PurchaseRemote then
							purchase.PurchaseRemote:InvokeServer(false)
						else
							purchase:TryPurchaseAsync(false)
						end
					end)
					if ok then
						bought += 1
						didBuy = true
						setStatus("Bought " .. (purchase.DisplayName or key))
						log("Bought: " .. (purchase.DisplayName or key))
					else
						log("Buy fail: " .. tostring(err))
					end
					break
				end
			end
		end
		if not didBuy then
			break
		end
	end
	return bought
end

local function tryAutoUpgrade(maxCount)
	maxCount = maxCount or 1
	local t = getTycoon()
	if not t then
		return 0
	end
	local a = comp(t, "Analyzer")
	local cb = comp(t, "ClientBalances")
	if not (a and cb) then
		return 0
	end

	local upgraded = 0
	for _ = 1, maxCount do
		local didUpgrade = false
		for _, earner in a:GetEarners() do
			if earner.IsEnabled and earner:IsEnabled() then
				local info = earner.GetNextUpgradeInfo and earner:GetNextUpgradeInfo()
				if info and not info.Max and info.Price and cb:GetCash() >= info.Price then
					local ok, err = pcall(function()
						if earner.UpgradeRemote then
							earner.UpgradeRemote:InvokeServer(info.Count)
						else
							earner:UpgradeAsync(info.Count)
						end
					end)
					if ok then
						upgraded += 1
						didUpgrade = true
					else
						log("Upgrade fail: " .. tostring(err))
					end
					break
				end
			end
		end
		if not didUpgrade then
			break
		end
	end
	if upgraded > 0 then
		setStatus("Upgraded " .. upgraded .. " earner" .. (upgraded == 1 and "" or "s"))
		local now = os.clock()
		if upgraded > 1 or now - Farm.lastUpgradeLogAt > 2 then
			Farm.lastUpgradeLogAt = now
			log("Upgrade: bought " .. upgraded .. " earners")
		end
	end
	return upgraded
end

local function formatMultiplier(n)
	if math.floor(n) == n then
		return tostring(math.floor(n))
	end
	return tostring(n)
end

local function getFirstEnabledEarner(t)
	local a = comp(t, "Analyzer")
	if not a then
		return nil
	end
	if M.Balance and M.Balance.PurchaseOrder then
		for _, key in M.Balance.PurchaseOrder do
			local earner = a.GetEarner and a:GetEarner(key)
			if earner and earner.IsEnabled and earner:IsEnabled() then
				return earner
			end
		end
	end
	for _, earner in a:GetEarners() do
		if earner.IsEnabled and earner:IsEnabled() then
			return earner
		end
	end
	return nil
end

local function wakeEarner(earner)
	if not earner then
		return false
	end
	local ok = pcall(function()
		if earner.WakeAsync then
			earner:WakeAsync()
			return
		end
		local income = earner.Tycoon and comp(earner.Tycoon, "ClientIncome")
		if income and income.WakeManualStreamAsync and earner.Name then
			income:WakeManualStreamAsync(earner.Name)
		end
	end)
	return ok
end

local function getNextPurchaseNeed(t)
	local a = comp(t, "Analyzer")
	if not (a and M.Balance) then
		return nil
	end
	local purchases = a:GetPurchases()
	for _, key in M.Balance.PurchaseOrder do
		local purchase = purchases[key]
		if purchase and purchase.IsEnabled and purchase:IsEnabled() and not purchase:IsPurchased() then
			local price
			pcall(function()
				price = purchase:GetPrice()
			end)
			return price, purchase
		end
	end
	return nil
end

local function markRebirthKickstart(rebirthCount)
	Farm.rebirthKickstart = true
	Farm.rebirthKickstartStartedAt = os.clock()
	Farm.lastRebirthKickstartWakeAt = 0
	if rebirthCount ~= nil then
		Farm.lastKnownRebirths = rebirthCount
	end
	log("Rebirth: waking first earner for auto-buy")
	setStatus("Post-rebirth: waking earner")
end

local function detectRebirthIncrease()
	if not Farm.autoComplete then
		return
	end
	local t = getTycoon()
	if not t then
		return
	end
	local tr = comp(t, "Rebirth")
	if not tr then
		return
	end
	local ok, count = pcall(function()
		return tr:GetRebirths()
	end)
	if not ok or count == nil then
		return
	end
	if Farm.lastKnownRebirths == nil then
		Farm.lastKnownRebirths = count
		return
	end
	if count > Farm.lastKnownRebirths then
		Farm.lastKnownRebirths = count
		markRebirthKickstart(count)
	end
end

local function tryRebirthKickstart()
	detectRebirthIncrease()
	if not Farm.rebirthKickstart then
		return false
	end

	local now = os.clock()
	if now - Farm.rebirthKickstartStartedAt > REBIRTH_KICKSTART_TIMEOUT then
		Farm.rebirthKickstart = false
		log("Rebirth kickstart timed out")
		return false
	end

	local t = getTycoon()
	if not t then
		return true
	end

	tryAutoBuy(1)

	local cb = comp(t, "ClientBalances")
	local nextPrice = getNextPurchaseNeed(t)
	if cb and nextPrice and M.Huge and M.Huge.one then
		local needsCash = M.Huge.one <= nextPrice
		if needsCash then
			local cashOk, cash = pcall(function()
				return cb:GetCash()
			end)
			if cashOk and cash and cash >= nextPrice then
				Farm.rebirthKickstart = false
				log("Rebirth kickstart done — ready for auto-buy")
				return false
			end
		end
	elseif cb and not nextPrice then
		Farm.rebirthKickstart = false
		return false
	end

	if now - Farm.lastRebirthKickstartWakeAt >= REBIRTH_KICKSTART_WAKE_INTERVAL then
		Farm.lastRebirthKickstartWakeAt = now
		local earner = getFirstEnabledEarner(t)
		if earner then
			wakeEarner(earner)
			if now - Farm.lastRebirthKickstartLogAt >= 2 then
				Farm.lastRebirthKickstartLogAt = now
				local label = earner.DisplayName or earner.Name or "earner"
				setStatus("Post-rebirth: waking " .. label)
				log("Rebirth kickstart: waking " .. label)
			end
		end
	end

	return true
end

local function getRebirthMultiplier()
	local fromBox = UI.rebirthMultBox and tonumber(UI.rebirthMultBox.Text)
	if fromBox and fromBox >= 1 and fromBox <= 100 then
		return fromBox
	end
	return Farm.rebirthMultiplier
end

local function getUpgradeMultiplier()
	local fromBox = UI.upgradeMultBox and tonumber(UI.upgradeMultBox.Text)
	if fromBox and fromBox >= 1 and fromBox <= 100 then
		return math.floor(fromBox)
	end
	return Farm.upgradeMultiplier
end

local function getRebirthRatio(potential, current)
	if not (M.Huge and M.Huge.divide and M.Huge.max and M.Huge.toHuge) then
		return nil
	end
	-- Match UIInvestorsMenu: potential / max(current, 100)
	return M.Huge.divide(potential, M.Huge.max(current, M.Huge.toHuge(100)))
end

local function formatRebirthRatio(ratio)
	if not (ratio and M.Huge and M.Huge.toNumber) then
		return "?"
	end
	local ok, n = pcall(M.Huge.toNumber, ratio)
	if ok and n then
		return string.format("%.2f", n)
	end
	return "?"
end

local function invokeRebirth(cr)
	-- Normal rebirth: UIInvestorsMenu calls RebirthAsync(nil) -> InvokeServer(nil)
	if cr.RebirthAsync then
		return cr:RebirthAsync(nil)
	end
	if cr.RebirthRemote then
		return cr.RebirthRemote:InvokeServer(nil)
	end
	error("ClientRebirth missing RebirthAsync/RebirthRemote")
end

local function tryAutoRebirth()
	loadModules()

	local t = getTycoon()
	if not t then
		local now = os.clock()
		if now - Farm.lastRebirthNoTycoonLogAt >= 10 then
			Farm.lastRebirthNoTycoonLogAt = now
			log("Rebirth check: waiting for tycoon")
		end
		return
	end

	local tb = comp(t, "Balances")
	local cr = comp(t, "ClientRebirth")
	local tr = comp(t, "Rebirth")
	if not (M.Huge and M.Huge.toHuge and M.Huge.one and M.Huge.multiply) then
		log("Rebirth check: Huge module unavailable")
		return
	end
	if not tb then
		log("Rebirth check: missing Balances")
		return
	end
	if not cr then
		log("Rebirth check: missing ClientRebirth (required for RebirthRemote)")
		return
	end

	local okPot, potential = pcall(function()
		return cr:GetPotentialInvestors()
	end)
	local okCur, current = pcall(function()
		return tb:GetInvestors()
	end)
	if not (okPot and okCur and potential and current) then
		log("Rebirth check: could not read investors")
		return
	end

	local mult = getRebirthMultiplier()
	local need = M.Huge.toHuge(mult)
	local safeCurrent = current
	if safeCurrent == M.Huge.zero or safeCurrent == (-1 / 0) then
		safeCurrent = M.Huge.toHuge(1)
	end
	local ratioForLog = M.Huge.divide(potential, safeCurrent)
	local ratioText = formatRebirthRatio(ratioForLog)
	local needText = formatMultiplier(mult)
	log(
		"Rebirth check: "
			.. fmt(potential)
			.. "/"
			.. fmt(current)
			.. " = "
			.. ratioText
			.. "x (need "
			.. needText
			.. "x)"
	)

	-- Match in-game rebirth button: potential must exceed 1 investor
	if not (M.Huge.one < potential) then
		return
	end

	-- Rebirth when REBIRTH TO GET >= multiplier × YOU HAVE (log-space: potential >= current * mult)
	local threshold = M.Huge.multiply(current, need)
	local shouldRebirth = not (potential < threshold)
	if not shouldRebirth then
		return
	end

	local now = os.clock()
	if now - Farm.lastRebirthAttemptAt < 3 then
		return
	end
	Farm.lastRebirthAttemptAt = now

	local beforeRebirths
	if tr then
		pcall(function()
			beforeRebirths = tr:GetRebirths()
		end)
	end

	log("Rebirth: invoking (ratio " .. ratioText .. "x >= " .. needText .. "x)")
	local ok, result = pcall(function()
		return invokeRebirth(cr)
	end)
	if not ok then
		log("Rebirth fail: " .. tostring(result))
		return
	end

	if result then
		log("Rebirth success (+" .. fmt(result) .. " investors)")
		setStatus("Rebirth!")
		if Farm.autoComplete then
			local afterCount
			if tr then
				pcall(function()
					afterCount = tr:GetRebirths()
				end)
			end
			markRebirthKickstart(afterCount)
		end
		return
	end

	local afterRebirths
	if tr then
		pcall(function()
			afterRebirths = tr:GetRebirths()
		end)
	end
	if beforeRebirths and afterRebirths and afterRebirths > beforeRebirths then
		log("Rebirth success (count " .. tostring(afterRebirths) .. ")")
		setStatus("Rebirth!")
		if Farm.autoComplete then
			markRebirthKickstart(afterRebirths)
		end
	else
		log("Rebirth declined by server (returned " .. tostring(result) .. ")")
	end
end

local function invokeAscend(ca)
	-- Normal ascension: UIAscensionMenu calls AscendAsync() -> InvokeServer()
	if ca.AscendAsync then
		return ca:AscendAsync()
	end
	if ca.AscendRemote then
		return ca.AscendRemote:InvokeServer()
	end
	error("ClientAscension missing AscendAsync/AscendRemote")
end

local function tryAutoAscend()
	loadModules()

	local t = getTycoon()
	if not t then
		local now = os.clock()
		if now - Farm.lastAscendNoTycoonLogAt >= 10 then
			Farm.lastAscendNoTycoonLogAt = now
			log("Ascend check: waiting for tycoon")
		end
		return
	end

	local ca = comp(t, "ClientAscension")
	local ta = comp(t, "Ascension")
	if not ca then
		log("Ascend check: missing ClientAscension (required for AscendRemote)")
		return
	end

	local okProg, progress = pcall(function()
		return ca:GetAscensionProgress()
	end)
	if not (okProg and progress ~= nil) then
		log("Ascend check: could not read ascension progress")
		return
	end

	local progressText = string.format("%.0f%%", progress * 100)
	local now = os.clock()
	if now - Farm.lastAscendProgressLogAt >= 8 then
		Farm.lastAscendProgressLogAt = now
		log("Ascend check: progress " .. progressText .. " (need 100%)")
	end

	-- Match in-game ascend button: progress must reach 100% (all purchases bought)
	if progress < 1 then
		return
	end

	local now = os.clock()
	if now - Farm.lastAscendAttemptAt < 3 then
		return
	end
	Farm.lastAscendAttemptAt = now

	local beforeTotal
	pcall(function()
		beforeTotal = readAscensionCounts(ta, ca)
	end)

	log("Ascend: invoking (all upgrades purchased)")
	local ok, result = pcall(function()
		return invokeAscend(ca)
	end)
	if not ok then
		log("Ascend fail: " .. tostring(result))
		return
	end

	task.wait(0.35)

	local afterTotal
	pcall(function()
		afterTotal = readAscensionCounts(ta, ca)
	end)

	local ascended = result == true
		or (beforeTotal and afterTotal and afterTotal > beforeTotal)
	if ascended then
		if afterTotal then
			Farm.knownTotalAscensions = afterTotal
		elseif Farm.knownTotalAscensions then
			Farm.knownTotalAscensions += 1
		else
			Farm.knownTotalAscensions = 1
		end
		log("Ascend success (total " .. tostring(Farm.knownTotalAscensions) .. ")")
		setStatus("Ascended!")
		if Farm.autoComplete then
			markRebirthKickstart(nil)
		end
		return
	end

	log("Ascend declined by server (returned " .. tostring(result) .. ")")
end

local function tryAutoComplete()
	local kickstarting = tryRebirthKickstart()
	local bought = tryAutoBuy(BUYS_PER_TICK)
	if bought > 0 then
		if Farm.rebirthKickstart then
			Farm.rebirthKickstart = false
		end
		setStatus("Auto-buy: " .. bought .. " items")
	elseif kickstarting then
		setStatus("Post-rebirth: waking first earner...")
	else
		setStatus("Auto-buy: waiting for cash...")
	end
end

local function tryAutoPhone()
	if Farm.phoneUsesEvents then
		return
	end

	local t = getTycoon()
	local offers = comp(t, "ClientPhoneOffers")
	if not offers then
		return
	end

	local current
	local ok, val = pcall(function()
		return offers:GetCurrentOffer()
	end)
	current = ok and val or nil

	if not current then
		Farm.phoneState = "idle"
		Farm.phoneRaises = 0
		return
	end

	if Farm.phoneState == "idle" then
		Farm.phoneState = "raising"
		Farm.phoneRaises = 0
		log("Phone offer detected — raising")
	end

	if Farm.phoneState == "raising" then
		if Farm.phoneRaises < PHONE_RAISE_COUNT then
			pcall(function()
				offers:RaiseOffer()
			end)
			Farm.phoneRaises += 1
			setStatus("Phone: raised once")
		else
			Farm.phoneState = "accepting"
		end
		return
	end

	if Farm.phoneState == "accepting" then
		pcall(function()
			offers:AcceptOffer()
		end)
		log("Phone offer accepted")
		setStatus("Phone offer accepted")
		Farm.phoneState = "idle"
		Farm.phoneRaises = 0
	end
end

local function teardownPhoneAuto()
	for _, conn in Farm.phoneConns do
		conn:Disconnect()
	end
	table.clear(Farm.phoneConns)
	Farm.phoneUsesEvents = false
end

local function setupPhoneAuto()
	teardownPhoneAuto()
	if not Farm.autoPhone then
		return
	end

	local t = getTycoon()
	local offers = comp(t, "ClientPhoneOffers")
	if not offers then
		return
	end

	local function onStarted()
		if not Farm.autoPhone then
			return
		end
		pcall(function()
			offers:RaiseOffer()
		end)
		log("Phone: raised once")
		setStatus("Phone: raised once")
	end

	local function onUpdated()
		if not Farm.autoPhone then
			return
		end
		pcall(function()
			offers:AcceptOffer()
		end)
		log("Phone offer accepted")
		setStatus("Phone offer accepted")
	end

	local hooked = false
	if typeof(offers.OfferStarted) == "RBXScriptSignal" then
		table.insert(Farm.phoneConns, offers.OfferStarted:Connect(onStarted))
		hooked = true
	end
	if typeof(offers.OfferUpdated) == "RBXScriptSignal" then
		table.insert(Farm.phoneConns, offers.OfferUpdated:Connect(onUpdated))
		hooked = true
	end

	Farm.phoneUsesEvents = hooked
	if hooked then
		log("Phone auto: event hooks active")
	end
end

local function minigameReady(getTimeFn)
	if not getTimeFn then
		return false
	end
	local ok, avail = pcall(function()
		return getTimeFn()
	end)
	if not ok or not avail then
		return false
	end
	return workspace:GetServerTimeNow() >= avail
end

local Trade = {
	prices = {},
	helperConn = nil,
	lastAt = 0,
	lastBuyAt = 0,
	lastSellAt = 0,
	lastPrice = nil,
	lastWaitLogAt = 0,
	lastSessionEndLogAt = 0,
	lastNewsScanAt = 0,
	cachedNews = nil,
	positionLockUntil = 0,
	tickAccum = 0,
	trend = 0,
	rises = 0,
	falls = 0,
	peak = nil,
	trough = nil,
	sessionActive = false,
	sessionStartAt = 0,
	COOLDOWN = 1.5,
	ENDGAME_COOLDOWN = 0.5,
	POST_SELL_BUY_WAIT = 2.5,
	POST_BUY_SELL_WAIT = 1.5,
	WAIT_LOG = 3.5,
	TICK_INTERVAL = 0.1,
	NEWS_REFRESH = 0.25,
	POSITION_LOCK = 0.75,
	BUF = 24,
	RISE_MIN = 3,
	CRASH = 0.07,
	MA = 5,
	NET_THRESHOLD = 0.75,
	NEUTRAL_BAND = 1.0,
	LATEST_BOOST = 3.0,
	ENDGAME_ELAPSED = 42,
	ENDGAME_LINE_T = 48,
	CRITICAL_ELAPSED = 52,
	CRITICAL_LINE_T = 55,
	FORCE_SELL_DROP = 0.06,
	FORCE_SELL_PEAK_DROP = 0.08,
}

local function resetTradeSessionState()
	table.clear(Trade.prices)
	Trade.lastAt = 0
	Trade.lastBuyAt = 0
	Trade.lastSellAt = 0
	Trade.lastPrice = nil
	Trade.lastWaitLogAt = 0
	Trade.lastSessionEndLogAt = 0
	Trade.trend = 0
	Trade.rises = 0
	Trade.falls = 0
	Trade.peak = nil
	Trade.trough = nil
	Trade.sessionActive = false
	Trade.sessionStartAt = 0
	Trade.lastNewsScanAt = 0
	Trade.cachedNews = nil
	Trade.positionLockUntil = 0
	Trade.tickAccum = 0
end

local function stopTradeHelper()
	if Trade.helperConn then
		Trade.helperConn:Disconnect()
		Trade.helperConn = nil
	end
	resetTradeSessionState()
end

local function isHoldingCrypto(ui)
	local status = ui.Gui.Main.Balances.Status
	if status and status.Text == "IN" then
		return true
	end
	if status and status.Text == "OUT" then
		return false
	end
	local cash = ui._CashVal and ui._CashVal.Value or 0
	local crypto = ui._CryptoVal and ui._CryptoVal.Value or 0
	return crypto > cash
end

local function getTradeButtonText(ui)
	local btn = ui._TradeButton and ui._TradeButton.Gui
	if not btn then
		return ""
	end
	if btn:IsA("TextButton") and btn.Text ~= "" then
		return btn.Text
	end
	local title = btn:FindFirstChild("Title", true)
	if title and title:IsA("TextLabel") then
		return title.Text or ""
	end
	return btn.Text or ""
end

local function getTradeButtonIntent(ui)
	local title = string.upper(getTradeButtonText(ui))
	if string.find(title, "SELL", 1, true) then
		return "sell"
	end
	if string.find(title, "BUY", 1, true) then
		return "buy"
	end
	return nil
end

local function getTradeSessionPhase(ui)
	local elapsed, lineT = getTradeTiming(ui)
	local ending = (elapsed and elapsed >= Trade.ENDGAME_ELAPSED)
		or (lineT and lineT >= Trade.ENDGAME_LINE_T)
	local critical = (elapsed and elapsed >= Trade.CRITICAL_ELAPSED)
		or (lineT and lineT >= Trade.CRITICAL_LINE_T)
	return elapsed, lineT, ending, critical
end

local function getCachedNews(ui, now)
	if Trade.cachedNews and now - Trade.lastNewsScanAt < Trade.NEWS_REFRESH then
		return Trade.cachedNews
	end
	local ok, news = pcall(analyzeNewsSentiment, ui)
	if ok and news then
		Trade.cachedNews = news
	else
		Trade.cachedNews = {
			bullScore = 0,
			bearScore = 0,
			netScore = 0,
			redBreaking = false,
			greenBreaking = false,
			latestHeader = nil,
			latestSentiment = nil,
			latestBearish = false,
			latestBullish = false,
			latestUrgentBear = false,
			majorityBearish = false,
			majorityBullish = false,
			newsNeutral = true,
			newsCount = 0,
			headlines = {},
		}
	end
	Trade.lastNewsScanAt = now
	return Trade.cachedNews
end

local function getTradePosition(ui)
	local intent = getTradeButtonIntent(ui)
	if intent == "sell" then
		return true
	end
	if intent == "buy" then
		return false
	end
	return isHoldingCrypto(ui)
end

local function classifyNewsColor(color)
	if color.G > 0.5 and color.R < 0.5 then
		return "bull"
	end
	if color.R > 0.5 and color.G < 0.5 then
		return "bear"
	end
	return "neutral"
end

local function newsTagWeight(headerText)
	local tag = string.upper(headerText or "")
	if string.find(tag, "BREAKING") then
		return 3.0
	end
	if string.find(tag, "MEGA")
		or string.find(tag, "LIVE")
		or string.find(tag, "WHALE")
		or string.find(tag, "WARNING")
		or string.find(tag, "PANIC")
		or string.find(tag, "LIQUIDATION") then
		return 2.5
	end
	if string.find(tag, "BUG WATCH")
		or string.find(tag, "DELAYED")
		or string.find(tag, "INVESTIGATION")
		or string.find(tag, "REGULAT") then
		return 2.2
	end
	if string.find(tag, "ON THE LIST") or string.find(tag, "TRENDING") or string.find(tag, "VIRAL") then
		return 2.0
	end
	if string.find(tag, "UPDATE") or string.find(tag, "RUMOR") or string.find(tag, "DOWNGRADE") or string.find(tag, "FAQ") then
		return 1.8
	end
	return 1.0
end

local function isUrgentBearTag(headerText)
	local tag = string.upper(headerText or "")
	if string.find(tag, "BUG WATCH") then
		return true
	end
	if string.find(tag, "PANIC") then
		return true
	end
	if string.find(tag, "WARNING") then
		return true
	end
	if string.find(tag, "DELAYED") then
		return true
	end
	if string.find(tag, "INVESTIGATION") then
		return true
	end
	if string.find(tag, "BREAKING") then
		return true
	end
	return false
end

local function analyzeNewsSentiment(ui)
	local container = ui.Gui.Main.News.Container
	local headlines = {}

	for _, child in container:GetChildren() do
		if child.Name == "News" and child:FindFirstChild("Frame") then
			local header = child.Frame:FindFirstChild("Header")
			if not header then
				continue
			end

			local visualY = 0
			if child:IsA("GuiObject") then
				visualY = child.AbsolutePosition.Y
			end

			table.insert(headlines, {
				layoutOrder = child.LayoutOrder,
				visualY = visualY,
				headerText = header.Text,
				sentiment = classifyNewsColor(header.TextColor3),
				tagWeight = newsTagWeight(header.Text),
			})
		end
	end

	-- Prefer top-of-panel headline (smallest Y); fall back to lowest LayoutOrder
	table.sort(headlines, function(a, b)
		if a.visualY > 0 and b.visualY > 0 and math.abs(a.visualY - b.visualY) > 2 then
			return a.visualY < b.visualY
		end
		return a.layoutOrder < b.layoutOrder
	end)

	local bullScore = 0
	local bearScore = 0
	local redBreaking = false
	local greenBreaking = false
	local latestHeader = nil
	local latestSentiment = nil
	local latestUrgentBear = false

	for rank, item in headlines do
		local positionWeight = Trade.LATEST_BOOST / (1 + (rank - 1) * 0.45)
		local weight = item.tagWeight * positionWeight
		local upper = string.upper(item.headerText)

		if rank == 1 then
			latestHeader = item.headerText
			latestSentiment = item.sentiment
			latestUrgentBear = item.sentiment == "bear" and isUrgentBearTag(item.headerText)
		end

		if item.sentiment == "bull" then
			bullScore += weight
			if string.find(upper, "BREAKING") then
				greenBreaking = true
			end
		elseif item.sentiment == "bear" then
			bearScore += weight
			if string.find(upper, "BREAKING") then
				redBreaking = true
			end
		else
			bullScore += weight * 0.15
			bearScore += weight * 0.15
		end
	end

	local netScore = bullScore - bearScore
	local latestBearish = latestSentiment == "bear"
	local latestBullish = latestSentiment == "bull"
	local majorityBearish = bearScore > bullScore
	local majorityBullish = bullScore > bearScore
	local newsNeutral = math.abs(netScore) < Trade.NEUTRAL_BAND

	return {
		bullScore = bullScore,
		bearScore = bearScore,
		netScore = netScore,
		redBreaking = redBreaking,
		greenBreaking = greenBreaking,
		latestHeader = latestHeader,
		latestSentiment = latestSentiment,
		latestBearish = latestBearish,
		latestBullish = latestBullish,
		latestUrgentBear = latestUrgentBear,
		majorityBearish = majorityBearish,
		majorityBullish = majorityBullish,
		newsNeutral = newsNeutral,
		newsCount = #headlines,
		headlines = headlines,
	}
end

local function calcMovingAverage(prices, count)
	local n = math.min(count, #prices)
	if n == 0 then
		return nil
	end
	local sum = 0
	for i = #prices - n + 1, #prices do
		sum += prices[i]
	end
	return sum / n
end

local function countConsecutiveMoves(prices)
	if #prices < 2 then
		return 0, 0
	end
	local rises, falls = 0, 0
	for i = #prices, 2, -1 do
		if prices[i] > prices[i - 1] * 1.0005 then
			if falls > 0 then
				break
			end
			rises += 1
		elseif prices[i] < prices[i - 1] * 0.9995 then
			if rises > 0 then
				break
			end
			falls += 1
		else
			break
		end
	end
	return rises, falls
end

local function isTradeLineActive(ui)
	if ui._LineConn ~= nil then
		return true
	end
	local price = ui._LastLineValue
	return type(price) == "number" and price > 0
end

local function getTradeTiming(ui)
	if not ui._LineStartTime then
		return nil, nil
	end
	local elapsed = time() - ui._LineStartTime
	local lineT = elapsed
	if ui._Line then
		local ok, last = pcall(function()
			return ui._Line:GetLast().T
		end)
		if ok and last then
			lineT = last
		end
	end
	return elapsed, lineT
end

local function isAtMaxEarnings(ui)
	if not (ui._MaxValue and M.Huge and M.Huge.toHuge) then
		return false
	end
	local ok, net = pcall(function()
		return ui:GetCurrentNetValue()
	end)
	if not ok or not net then
		return false
	end
	local ok2, capped = pcall(function()
		return M.Huge.toHuge(ui._MaxValue) <= net
	end)
	return ok2 and capped
end

local function shouldForceEndgameSell(ui, price, px, sessionEnding, sessionCritical)
	if not getTradePosition(ui) then
		return false, nil
	end
	if sessionCritical then
		return true, "critical — must exit position"
	end
	if sessionEnding then
		return true, "session ending — take profits"
	end
	if isAtMaxEarnings(ui) then
		return true, "max earnings reached"
	end
	if price <= 0.05 then
		return true, "price near zero"
	end
	if px.dropFromPositionPeak >= Trade.FORCE_SELL_PEAK_DROP then
		return true, string.format("position peak drop %.0f%%", px.dropFromPositionPeak * 100)
	end
	return false, nil
end

local function decideSellAction(news, px, forceSell, forceReason, sessionCritical, sessionEnding, now)
	if forceSell then
		return true, forceReason or "protect position"
	end
	if news.latestUrgentBear or (news.latestBearish and news.redBreaking) then
		return true, "urgent bear headline"
	end
	if news.latestBearish then
		return true, "latest bearish headline"
	end
	if news.bearScore > news.bullScore then
		return true, "net bearish news"
	end
	if px.sharpCrash and news.bearScore > 0 then
		return true, "crash + bearish news"
	end
	if news.newsNeutral and px.sharpCrash and px.fallingHard then
		return true, "neutral news — price crash"
	end
	if sessionEnding and px.dropFromPositionPeak >= 0.04 then
		return true, "endgame peak giveback"
	end
	return false, nil
end

local function decideBuyAction(news, px, now, sessionEnding, sessionCritical)
	if sessionEnding or sessionCritical then
		return false, nil
	end
	local postSellBlock = Trade.lastSellAt > 0
		and now - Trade.lastSellAt < Trade.POST_SELL_BUY_WAIT
		and not (news.latestBullish and news.bullScore > news.bearScore + Trade.NET_THRESHOLD)
	if postSellBlock then
		return false, nil
	end
	if news.latestBearish or news.latestUrgentBear then
		return false, nil
	end
	if news.majorityBearish and not news.latestBullish then
		return false, nil
	end
	if news.bullScore > news.bearScore + Trade.NET_THRESHOLD and news.latestBullish then
		return true, "net bullish + green latest"
	end
	if news.latestBullish and news.greenBreaking and news.bullScore >= news.bearScore then
		return true, "green breaking headline"
	end
	if news.newsNeutral and px.risingHard and news.bullScore > 0 then
		return true, "neutral news — rising price"
	end
	if news.newsNeutral and px.momentum > 0.005 and news.latestBullish then
		return true, "neutral news — momentum"
	end
	return false, nil
end

local function executeTradeAction(ui, now, action, reason, news, holding, price)
	if now < Trade.positionLockUntil then
		return false
	end
	if action == "sell" and not holding then
		return false
	end
	if action == "buy" and holding then
		return false
	end

	local traded = false
	pcall(function()
		ui:Trade()
		traded = true
	end)
	if not traded and ui._TradeButton and ui._TradeButton.Gui then
		traded = fireGuiButton(ui._TradeButton.Gui)
	end
	if not traded then
		log("Trade: failed to click " .. string.upper(action))
		return false
	end

	Trade.lastAt = now
	Trade.positionLockUntil = now + Trade.POSITION_LOCK
	if action == "buy" then
		Trade.lastBuyAt = now
		Trade.peak = price
		Trade.trough = nil
	else
		Trade.lastBuyAt = 0
		Trade.lastSellAt = now
		Trade.trough = price
		Trade.peak = nil
	end
	Trade.trend = 0
	Trade.rises = 0
	Trade.falls = 0
	log(string.format(
		"Trade: %s because [%s] bull %.1f bear %.1f",
		string.upper(action),
		reason,
		news.bullScore,
		news.bearScore
	))
	return true
end

local function getPriceContext(price)
	local minP, maxP = math.huge, -math.huge
	for _, v in Trade.prices do
		minP = math.min(minP, v)
		maxP = math.max(maxP, v)
	end

	local range = maxP - minP
	local risingHard = Trade.trend >= Trade.RISE_MIN or Trade.rises >= Trade.RISE_MIN
	local fallingHard = Trade.trend <= -Trade.RISE_MIN or Trade.falls >= Trade.RISE_MIN
	local recentDropPct = 0
	local recentRisePct = 0
	local sharpCrash = false
	local atLocalBottom = false
	local atLocalPeak = false
	local ma5 = calcMovingAverage(Trade.prices, Trade.MA)
	local aboveMA = ma5 and price > ma5 * 1.002
	local belowMA = ma5 and price < ma5 * 0.998
	local momentum = 0
	if ma5 and ma5 > 0.001 then
		momentum = (price - ma5) / ma5
	end

	local peakRef = Trade.peak or price
	if #Trade.prices >= 5 then
		local recentPeak = price
		local startIdx = math.max(1, #Trade.prices - 11)
		for i = startIdx, #Trade.prices do
			recentPeak = math.max(recentPeak, Trade.prices[i])
		end
		peakRef = math.max(peakRef, recentPeak)
		if peakRef > 0.001 then
			recentDropPct = (peakRef - price) / peakRef
		end
		sharpCrash = recentDropPct >= Trade.CRASH or Trade.trend <= -5
	end

	local troughRef = Trade.trough or price
	if troughRef > 0.001 then
		recentRisePct = (price - troughRef) / troughRef
	end

	if #Trade.prices >= 6 and range > 0 and range / math.max(minP, 0.001) >= 0.015 then
		atLocalBottom = price <= minP + range * 0.15 and (Trade.trend >= 0 or Trade.rises >= 1)
		atLocalPeak = price >= maxP - range * 0.15 and (Trade.trend <= 0 or Trade.falls >= 1)
	end

	local dropFromPositionPeak = 0
	if Trade.peak and Trade.peak > 0.001 then
		dropFromPositionPeak = (Trade.peak - price) / Trade.peak
	end

	local riseFromPositionTrough = 0
	if Trade.trough and Trade.trough > 0.001 then
		riseFromPositionTrough = (price - Trade.trough) / Trade.trough
	end

	return {
		fallingHard = fallingHard,
		risingHard = risingHard,
		atLocalBottom = atLocalBottom,
		atLocalPeak = atLocalPeak,
		recentDropPct = recentDropPct,
		recentRisePct = recentRisePct,
		sharpCrash = sharpCrash,
		ma5 = ma5,
		aboveMA = aboveMA,
		belowMA = belowMA,
		momentum = momentum,
		dropFromPositionPeak = dropFromPositionPeak,
		riseFromPositionTrough = riseFromPositionTrough,
	}
end

local function startTradeHelper()
	stopTradeHelper()
	if not M.UIMinigameTrade then
		return
	end

	Trade.helperConn = RunService.Heartbeat:Connect(function(dt)
		Trade.tickAccum += dt
		if Trade.tickAccum < Trade.TICK_INTERVAL then
			return
		end
		Trade.tickAccum = 0

		local ok, ui = pcall(function()
			return M.UIMinigameTrade:get()
		end)
		if not ok or not ui then
			return
		end

		local price = ui._LastLineValue
		local lineRunning = isTradeLineActive(ui)
		local canTrade = ui._TradeButton and ui._TradeButton.Gui.Active

		if not lineRunning then
			if Trade.sessionActive then
				if isHoldingCrypto(ui) and os.clock() >= Trade.positionLockUntil then
					pcall(function()
						ui:Trade()
					end)
					if ui._TradeButton and ui._TradeButton.Gui then
						fireGuiButton(ui._TradeButton.Gui)
					end
					log("Trade: emergency sell at line stop")
				end
				local now = os.clock()
				if now - Trade.lastSessionEndLogAt >= 2 then
					Trade.lastSessionEndLogAt = now
					if isHoldingCrypto(ui) then
						log("Trade: line stopped while still IN")
					else
						log("Trade: session ended (line stopped)")
					end
				end
				Trade.sessionActive = false
			end
			return
		end

		if not Trade.sessionActive then
			Trade.sessionActive = true
			Trade.sessionStartAt = os.clock()
			log("Trade: session active — tracking price")
		end

		local now = os.clock()
		local holdingCrypto = isHoldingCrypto(ui)

		if holdingCrypto then
			Trade.peak = Trade.peak and math.max(Trade.peak, price) or price
			Trade.trough = nil
		else
			Trade.trough = Trade.trough and math.min(Trade.trough, price) or price
			Trade.peak = nil
		end

		table.insert(Trade.prices, price)
		if #Trade.prices > Trade.BUF then
			table.remove(Trade.prices, 1)
		end

		if Trade.lastPrice then
			if price > Trade.lastPrice * 1.0005 then
				Trade.trend = math.min(Trade.trend + 1, 10)
			elseif price < Trade.lastPrice * 0.9995 then
				Trade.trend = math.max(Trade.trend - 1, -10)
			end
		end
		Trade.lastPrice = price
		Trade.rises, Trade.falls = countConsecutiveMoves(Trade.prices)

		local _, _, sessionEnding, sessionCritical = getTradeSessionPhase(ui)
		local news = getCachedNews(ui, now)
		local px = getPriceContext(price)
		local forceSell, forceReason = shouldForceEndgameSell(ui, price, px, sessionEnding, sessionCritical)
		local cooldown = Trade.COOLDOWN
		if holdingCrypto and (sessionCritical or sessionEnding or forceSell) then
			cooldown = Trade.ENDGAME_COOLDOWN
		end

		if not canTrade then
			if now - Trade.lastWaitLogAt >= Trade.WAIT_LOG then
				Trade.lastWaitLogAt = now
				log(string.format(
					"Trade: waiting (button inactive) — trend %d rises %d falls %d",
					Trade.trend,
					Trade.rises,
					Trade.falls
				))
			end
			if not (forceSell and holdingCrypto) then
				return
			end
		end
		if now - Trade.lastAt < cooldown then
			return
		end

		local action, reason
		if holdingCrypto then
			local shouldSell
			shouldSell, reason = decideSellAction(news, px, forceSell, forceReason, sessionCritical, sessionEnding, now)
			if shouldSell then
				action = "sell"
			end
		else
			local shouldBuy
			shouldBuy, reason = decideBuyAction(news, px, now, sessionEnding, sessionCritical)
			if shouldBuy then
				action = "buy"
			end
		end

		if action then
			executeTradeAction(ui, now, action, reason, news, holdingCrypto, price)
		elseif now - Trade.lastWaitLogAt >= Trade.WAIT_LOG then
			Trade.lastWaitLogAt = now
			local posTag = holdingCrypto and "IN" or "OUT"
			local headline = news.latestHeader or "no headline"
			log(string.format(
				"Trade: waiting (%s) [%s] bull %.1f bear %.1f trend %d%s",
				posTag,
				headline,
				news.bullScore,
				news.bearScore,
				Trade.trend,
				sessionCritical and " [CRITICAL]" or (sessionEnding and " [ENDGAME]" or "")
			))
		end
	end)
end

local function autoPickRaceLemon()
	for _, g in plr.PlayerGui:GetChildren() do
		if g:IsA("BillboardGui") and g.Enabled then
			local btn = g:FindFirstChild("Button", true)
			if btn and btn:IsA("GuiButton") then
				fireGuiButton(btn)
				return true
			end
		end
	end
	return false
end

local function autoCheerRace()
	if not M.UIMinigameRace then
		return
	end
	local ok, ui = pcall(function()
		return M.UIMinigameRace:get()
	end)
	if ok and ui and ui._Cheer then
		pcall(function()
			ui.Cheered:Fire()
		end)
		local cheerBtn = ui.Gui and ui.Gui:FindFirstChild("Button")
		if cheerBtn then
			fireGuiButton(cheerBtn)
		end
	end
end

local MinigameClaim = {
	lastClaimAt = 0,
	CLAIM_COOLDOWN = 0.35,
}

local function isCashCheckVisible()
	if not M.UICashCheck then
		return false
	end
	local ok, ui = pcall(function()
		return M.UICashCheck:get()
	end)
	if not ok or not ui or not ui.Gui then
		return false
	end
	local visible = ui.Gui.Visible
	pcall(function()
		if ui.IsVisible then
			visible = ui:IsVisible()
		end
	end)
	return visible
end

local function tryClaimMinigameCheck()
	if not M.UICashCheck then
		loadModules()
	end
	if not M.UICashCheck then
		return false
	end

	local ok, ui = pcall(function()
		return M.UICashCheck:get()
	end)
	if not ok or not ui or not ui.Gui then
		return false
	end

	local visible = ui.Gui.Visible
	pcall(function()
		if ui.IsVisible then
			visible = ui:IsVisible()
		end
	end)
	if not visible then
		return false
	end

	local main = ui.Gui:FindFirstChild("Main")
	if not main or not main:IsA("GuiObject") or not main.Visible or not main.Active then
		return false
	end

	local now = os.clock()
	if now - MinigameClaim.lastClaimAt < MinigameClaim.CLAIM_COOLDOWN then
		return false
	end
	MinigameClaim.lastClaimAt = now

	if not M.UIButton then
		loadModules()
	end

	local claimed = false
	pcall(function()
		local btn = M.UIButton:get(main)
		if btn and btn.Clicked then
			btn.Clicked:Fire(true)
			claimed = true
		end
	end)
	if not claimed then
		claimed = fireGuiButton(main)
	end

	if claimed then
		log("Minigame: claimed check/reward")
	end
	return claimed
end

local function watchMinigameCheckAfterRun(seconds)
	task.spawn(function()
		local deadline = os.clock() + (seconds or 10)
		while os.clock() < deadline and Farm.running do
			if tryClaimMinigameCheck() then
				return
			end
			task.wait(0.12)
		end
	end)
end

local raceHelperToken = nil

local function startRaceHelper()
	raceHelperToken = {}
	local token = raceHelperToken
	task.spawn(function()
		while Farm.autoRace and Farm.running and raceHelperToken == token do
			autoPickRaceLemon()
			autoCheerRace()
			task.wait(0.04)
		end
	end)
end

local function stopRaceHelper()
	raceHelperToken = nil
end

local function tryAutoTrade()
	if not Farm.autoTrade then
		return
	end
	if Farm.minigameBusy then
		return
	end
	if not M.TradeService then
		loadModules()
	end
	if not M.TradeService then
		return
	end

	local availTime
	local availOk, availResult = pcall(function()
		return M.TradeService:GetTradingAvailableTime()
	end)
	if not availOk or not availResult then
		return
	end
	availTime = availResult

	local serverNow = workspace:GetServerTimeNow()
	if serverNow < availTime then
		return
	end

	Farm.minigameBusy = true
	setStatus("Lemon Trading...")
	log("Starting Lemon Trading minigame")

	task.spawn(function()
		local ok, err = pcall(function()
			if not M.UIMinigameTrade then
				loadModules()
			end
			local prepOk, prepErr = M.TradeService:PrepTradingAsync()
			if not prepOk then
				log("Trade prep failed" .. (prepErr and (": " .. tostring(prepErr)) or ""))
				return
			end
			startTradeHelper()
			local earnings = M.TradeService:RunTradingAsync()
			stopTradeHelper()
			watchMinigameCheckAfterRun(10)
			if earnings then
				log("Trade finished — earned " .. fmtCash(earnings))
			else
				log("Trade finished")
			end
		end)
		if not ok then
			log("Trade error: " .. tostring(err))
		end
		stopTradeHelper()
		Farm.minigameBusy = false
	end)
end

local function tryAutoRace()
	if Farm.minigameBusy or not M.RaceService then
		return
	end
	if not minigameReady(function()
		return M.RaceService:GetRaceAvailableTime()
	end) then
		return
	end

	Farm.minigameBusy = true
	setStatus("Lemon Dash...")
	log("Starting Lemon Dash minigame")

	task.spawn(function()
		local ok, err = pcall(function()
			local prepOk = M.RaceService:PrepRaceAsync()
			if not prepOk then
				log("Race prep failed")
				return
			end
			startRaceHelper()
			local placement = M.RaceService:RunRaceAsync()
			stopRaceHelper()
			watchMinigameCheckAfterRun(10)
			if placement then
				log("Race finished — placement " .. tostring(placement))
			else
				log("Race finished")
			end
		end)
		if not ok then
			log("Race error: " .. tostring(err))
		end
		stopRaceHelper()
		Farm.minigameBusy = false
	end)
end

local function retryTycoonLoad()
	if getTycoon() or getTycoonInstance() then
		Farm.tycoonRetries = 0
		if Farm.autoPhone then
			setupPhoneAuto()
		end
		if Farm.autoFruit and #Farm.treeRegistry == 0 then
			refreshTreeGroups(true)
		end
		return
	end
	Farm.tycoonRetries += 1
	loadModules()
	if Farm.tycoonRetries % 5 == 0 then
		setStatus("Waiting for tycoon... (" .. Farm.tycoonRetries .. ")")
	end
end

local FEATURE_HANDLERS = {
	autoFruit = tryAutoFruit,
	autoUpgrade = function()
		tryAutoUpgrade(getUpgradeMultiplier())
	end,
	autoCashDrop = tryAutoCashDrop,
	autoRebirth = tryAutoRebirth,
	autoAscend = tryAutoAscend,
	autoComplete = tryAutoComplete,
	autoPhone = tryAutoPhone,
	autoTrade = tryAutoTrade,
	autoRace = tryAutoRace,
}

local FEATURE_DELAYS = {
	autoFruit = LOOP_DELAY,
	autoUpgrade = LOOP_DELAY,
	autoCashDrop = 1.25,
	autoRebirth = 2,
	autoAscend = 2,
	autoComplete = LOOP_DELAY,
	autoPhone = 1.5,
	autoTrade = 8,
	autoRace = 8,
}

local function refreshAllToggles()
	for _, fn in UI.toggleRefreshers do
		fn()
	end
end

local function setFeature(key, enabled)
	Farm[key] = enabled
	if enabled then
		if key == "autoFruit" then
			refreshTreeGroups(true)
			Farm.fruitState = "travel"
			Farm.lastTpTime = 0
			Farm.collectAttempts = 0
			Farm.fruitCycleAt = 0
		end
		if key == "autoPhone" then
			setupPhoneAuto()
		end
		if key == "autoRebirth" and UI.rebirthMultBox then
			local n = tonumber(UI.rebirthMultBox.Text)
			if n and n >= 1 and n <= 100 then
				Farm.rebirthMultiplier = n
			end
		end
		if key == "autoUpgrade" and UI.upgradeMultBox then
			local n = tonumber(UI.upgradeMultBox.Text)
			if n and n >= 1 and n <= 100 then
				Farm.upgradeMultiplier = math.floor(n)
			end
		end
		UI.featureAccum[key] = FEATURE_DELAYS[key] or LOOP_DELAY
		task.defer(function()
			if Farm[key] and FEATURE_HANDLERS[key] then
				pcall(FEATURE_HANDLERS[key])
			end
		end)
	else
		UI.featureAccum[key] = 0
		if key == "autoPhone" then
			Farm.phoneState = "idle"
			Farm.phoneRaises = 0
			teardownPhoneAuto()
		end
		if key == "autoCashDrop" then
			Farm.cashState = "travel"
			Farm.lastCashTpTime = 0
			Farm.currentCashBag = nil
		end
	end
	refreshAllToggles()
end

local CONFIG = {
	folder = "SigmaScripts/SellLemons",
	activeFile = "SigmaScripts/SellLemons/_active.txt",
	version = 1,
	activeName = nil,
}

local FEATURE_CONFIG_KEYS = {
	"autoComplete",
	"autoFruit",
	"autoUpgrade",
	"autoCashDrop",
	"autoRebirth",
	"autoAscend",
	"autoPhone",
	"autoTrade",
	"autoRace",
}

local function configStorageReady()
	return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

local function ensureConfigFolder()
	if not configStorageReady() then
		return false
	end
	if makefolder and isfolder then
		if not isfolder(CONFIG.folder) then
			local ok = pcall(makefolder, CONFIG.folder)
			if not ok then
				return false
			end
		end
	end
	return true
end

local function sanitizeConfigName(raw)
	if type(raw) ~= "string" then
		return ""
	end
	local name = string.gsub(raw, "^%s*(.-)%s*$", "%1")
	name = string.gsub(name, "[^%w%-_]", "")
	if #name > 32 then
		name = string.sub(name, 1, 32)
	end
	return name
end

local function configFilePath(name)
	return CONFIG.folder .. "/" .. name .. ".json"
end

local function captureConfigData()
	local features = {}
	for _, key in ipairs(FEATURE_CONFIG_KEYS) do
		features[key] = Farm[key] == true
	end
	return {
		version = CONFIG.version,
		rebirthMultiplier = Farm.rebirthMultiplier,
		upgradeMultiplier = Farm.upgradeMultiplier,
		features = features,
	}
end

local function listConfigNames()
	local names = {}
	if not configStorageReady() then
		return names
	end
	ensureConfigFolder()
	if listfiles then
		local ok, files = pcall(listfiles, CONFIG.folder)
		if ok and type(files) == "table" then
			for _, path in ipairs(files) do
				local base = path:match("([^/\\]+)$") or path
				local name = base:match("^(.+)%.json$")
				if name and name ~= "_active" then
					table.insert(names, name)
				end
			end
		end
	end
	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)
	return names
end

local function getActiveConfigName()
	if CONFIG.activeName and CONFIG.activeName ~= "" then
		return CONFIG.activeName
	end
	if readfile and isfile and isfile(CONFIG.activeFile) then
		local ok, txt = pcall(readfile, CONFIG.activeFile)
		if ok and type(txt) == "string" and #txt > 0 then
			CONFIG.activeName = sanitizeConfigName(txt)
			return CONFIG.activeName ~= "" and CONFIG.activeName or nil
		end
	end
	return nil
end

local function saveConfigNamed(name)
	name = sanitizeConfigName(name)
	if name == "" then
		return false, "Enter a config name"
	end
	if not ensureConfigFolder() then
		return false, "Executor needs writefile/readfile"
	end
	local data = captureConfigData()
	local okJson, json = pcall(HttpService.JSONEncode, HttpService, data)
	if not okJson or type(json) ~= "string" then
		return false, "Could not encode config"
	end
	local okW = pcall(writefile, configFilePath(name), json)
	if not okW then
		return false, "Save failed"
	end
	pcall(writefile, CONFIG.activeFile, name)
	CONFIG.activeName = name
	return true, name
end

local function loadConfigNamed(name, applyFn)
	name = sanitizeConfigName(name)
	if name == "" then
		return false, "Enter a config name"
	end
	if not configStorageReady() then
		return false, "Executor needs writefile/readfile"
	end
	local path = configFilePath(name)
	if not isfile(path) then
		return false, "Config not found"
	end
	local okR, raw = pcall(readfile, path)
	if not okR or type(raw) ~= "string" or #raw == 0 then
		return false, "Could not read config"
	end
	local okD, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not okD or type(data) ~= "table" then
		return false, "Invalid config file"
	end
	if applyFn then
		applyFn(data)
	end
	pcall(writefile, CONFIG.activeFile, name)
	CONFIG.activeName = name
	return true, name
end

local function deleteConfigNamed(name)
	name = sanitizeConfigName(name)
	if name == "" then
		return false, "Enter a config name"
	end
	if not isfile(configFilePath(name)) then
		return false, "Config not found"
	end
	if not delfile then
		return false, "Executor needs delfile"
	end
	local ok = pcall(delfile, configFilePath(name))
	if not ok then
		return false, "Delete failed"
	end
	if getActiveConfigName() == name then
		CONFIG.activeName = nil
		if isfile(CONFIG.activeFile) then
			pcall(delfile, CONFIG.activeFile)
		end
	end
	return true, name
end

local function buildUI()
local C = {
	bg = Color3.fromRGB(13, 15, 20),
	panel = Color3.fromRGB(18, 21, 28),
	sidebar = Color3.fromRGB(16, 18, 25),
	card = Color3.fromRGB(24, 27, 36),
	cardInner = Color3.fromRGB(30, 34, 45),
	border = Color3.fromRGB(42, 48, 62),
	accent = Color3.fromRGB(34, 211, 238),
	accentBright = Color3.fromRGB(103, 232, 249),
	accentDim = Color3.fromRGB(8, 145, 178),
	gold = Color3.fromRGB(251, 191, 36),
	text = Color3.fromRGB(241, 245, 249),
	muted = Color3.fromRGB(148, 163, 184),
	green = Color3.fromRGB(52, 211, 153),
	yellow = Color3.fromRGB(250, 204, 21),
	red = Color3.fromRGB(251, 113, 133),
}

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or C.accent
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.65
	s.Parent = parent
	return s
end

for _, name in ipairs({ "LemonDash", "StatsDashboard", "LemonHub", "SellLemons", "DestineHub", "SigmaHub" }) do
	local old = plr.PlayerGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

if getgenv().SigmaStopRequested then
	Farm.running = false
end
getgenv().SigmaStopRequested = false
Farm.running = true

local GUI_DISPLAY_FLOOR = 1000000

local gui = Instance.new("ScreenGui")
gui.Name = "SellLemons"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = GUI_DISPLAY_FLOOR
gui.Parent = plr:WaitForChild("PlayerGui")

local function ensureHubOnTop()
	if not gui or not gui.Parent then
		return
	end
	local order = GUI_DISPLAY_FLOOR
	for _, child in plr.PlayerGui:GetChildren() do
		if child:IsA("ScreenGui") and child ~= gui and child.Enabled then
			order = math.max(order, (child.DisplayOrder or 0) + 1)
		end
	end
	gui.DisplayOrder = math.min(order, 2147483647)
end

ensureHubOnTop()
plr.PlayerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") and child ~= gui then
		child:GetPropertyChangedSignal("DisplayOrder"):Connect(ensureHubOnTop)
		child:GetPropertyChangedSignal("Enabled"):Connect(ensureHubOnTop)
		task.defer(ensureHubOnTop)
	end
end)
for _, child in plr.PlayerGui:GetChildren() do
	if child:IsA("ScreenGui") and child ~= gui then
		child:GetPropertyChangedSignal("DisplayOrder"):Connect(ensureHubOnTop)
		child:GetPropertyChangedSignal("Enabled"):Connect(ensureHubOnTop)
	end
end

local glow = Instance.new("Frame")
glow.Size = UDim2.fromOffset(720, 560)
glow.Position = UDim2.fromScale(0.02, 0.06)
glow.BackgroundColor3 = C.accent
glow.BackgroundTransparency = 0.92
glow.BorderSizePixel = 0
glow.Parent = gui
corner(glow, 20)

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(700, 540)
root.Position = UDim2.fromScale(0.02, 0.06)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.ClipsDescendants = false
root.Parent = gui
corner(root, 16)
stroke(root, C.border, 1, 0.35)

local bgGrad = Instance.new("UIGradient")
bgGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 26, 34)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 13, 18)),
})
bgGrad.Rotation = 160
bgGrad.Parent = root

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 46)
header.BackgroundColor3 = C.panel
header.BackgroundTransparency = 0.08
header.BorderSizePixel = 0
header.Parent = root
stroke(header, C.border, 1, 0.5)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(0, 160, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = C.text
title.Text = "Sell Lemons"
title.Parent = header

local titleAccent = Instance.new("Frame")
titleAccent.Size = UDim2.fromOffset(3, 18)
titleAccent.Position = UDim2.fromOffset(8, 14)
titleAccent.BackgroundColor3 = C.accent
titleAccent.BorderSizePixel = 0
titleAccent.Parent = header
corner(titleAccent, 2)
title.Position = UDim2.fromOffset(18, 0)

local version = Instance.new("TextLabel")
version.BackgroundTransparency = 1
version.Size = UDim2.new(0, 220, 1, 0)
version.Position = UDim2.fromOffset(174, 0)
version.Font = Enum.Font.Gotham
version.TextSize = 11
version.TextXAlignment = Enum.TextXAlignment.Left
version.TextColor3 = C.muted
version.Text = "Sigma Scripts · by ghoul 🍋"
version.Parent = header

local function hdrBtn(text, color, xOff, callback)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(22, 22)
	button.Position = UDim2.new(1, xOff, 0.5, -11)
	button.BackgroundColor3 = color
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(20, 20, 30)
	button.AutoButtonColor = true
	button.Parent = header
	corner(button, 11)
	button.MouseButton1Click:Connect(callback)
end

local bodyWrap = Instance.new("Frame")
bodyWrap.Name = "BodyWrap"
bodyWrap.Size = UDim2.new(1, 0, 1, -46)
bodyWrap.Position = UDim2.fromOffset(0, 46)
bodyWrap.BackgroundTransparency = 1
bodyWrap.Parent = root

local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, 0, 0, 26)
footer.Position = UDim2.new(0, 0, 1, -26)
footer.BackgroundColor3 = C.panel
footer.BackgroundTransparency = 0.12
footer.BorderSizePixel = 0
footer.Parent = bodyWrap
stroke(footer, C.border, 1, 0.55)

local footerFps = Instance.new("TextLabel")
footerFps.BackgroundTransparency = 1
footerFps.Size = UDim2.new(0.25, 0, 1, 0)
footerFps.Position = UDim2.fromOffset(10, 0)
footerFps.Font = Enum.Font.Gotham
footerFps.TextSize = 10
footerFps.TextXAlignment = Enum.TextXAlignment.Left
footerFps.TextColor3 = C.muted
footerFps.Text = "FPS: --"
footerFps.Parent = footer

local footerIds = Instance.new("TextLabel")
footerIds.BackgroundTransparency = 1
footerIds.Size = UDim2.new(0.55, 0, 1, 0)
footerIds.Position = UDim2.fromScale(0.22, 0)
footerIds.Font = Enum.Font.Gotham
footerIds.TextSize = 10
footerIds.TextXAlignment = Enum.TextXAlignment.Center
footerIds.TextColor3 = C.muted
footerIds.Text = "Game: " .. tostring(game.PlaceId)
footerIds.Parent = footer

local footerStatus = Instance.new("TextLabel")
footerStatus.BackgroundTransparency = 1
footerStatus.Size = UDim2.new(0.2, -10, 1, 0)
footerStatus.Position = UDim2.new(0.8, 0, 0, 0)
footerStatus.Font = Enum.Font.GothamBold
footerStatus.TextSize = 10
footerStatus.TextXAlignment = Enum.TextXAlignment.Right
footerStatus.TextColor3 = C.accent
footerStatus.Text = "Active"
footerStatus.TextTruncate = Enum.TextTruncate.AtEnd
footerStatus.Parent = footer

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, 0, 1, -26)
contentArea.BackgroundTransparency = 1
contentArea.Parent = bodyWrap

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 118, 1, 0)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BackgroundTransparency = 0.05
sidebar.BorderSizePixel = 0
sidebar.Parent = contentArea
stroke(sidebar, C.border, 1, 0.6)

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 6)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Parent = sidebar
local sidebarPad = Instance.new("UIPadding", sidebar)
sidebarPad.PaddingTop = UDim.new(0, 12)
sidebarPad.PaddingLeft = UDim.new(0, 8)
sidebarPad.PaddingRight = UDim.new(0, 8)

local mainArea = Instance.new("Frame")
mainArea.Size = UDim2.new(1, -118, 1, 0)
mainArea.Position = UDim2.fromOffset(118, 0)
mainArea.BackgroundTransparency = 1
mainArea.Parent = contentArea

local searchBar = Instance.new("Frame")
searchBar.Size = UDim2.new(1, -20, 0, 34)
searchBar.Position = UDim2.fromOffset(10, 8)
searchBar.BackgroundColor3 = C.card
searchBar.BorderSizePixel = 0
searchBar.Parent = mainArea
corner(searchBar, 10)
stroke(searchBar, C.border, 1, 0.45)

local searchIcon = Instance.new("TextLabel")
searchIcon.BackgroundTransparency = 1
searchIcon.Size = UDim2.fromOffset(30, 34)
searchIcon.Font = Enum.Font.Gotham
searchIcon.TextSize = 14
searchIcon.TextColor3 = C.muted
searchIcon.Text = "🔍"
searchIcon.Parent = searchBar

local searchBox = Instance.new("TextBox")
searchBox.BackgroundTransparency = 1
searchBox.Size = UDim2.new(1, -36, 1, 0)
searchBox.Position = UDim2.fromOffset(32, 0)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.PlaceholderText = "Search features..."
searchBox.PlaceholderColor3 = C.muted
searchBox.TextColor3 = C.text
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchBar

local pagesHost = Instance.new("Frame")
pagesHost.ClipsDescendants = false
pagesHost.Size = UDim2.new(1, -20, 1, -52)
pagesHost.Position = UDim2.fromOffset(10, 48)
pagesHost.BackgroundTransparency = 1
pagesHost.Parent = mainArea

local navItems = {}
local pages = {}

local function makePage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarImageColor3 = C.accent
	page.Visible = false
	page.Parent = pagesHost

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 14)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = page
	local pagePad = Instance.new("UIPadding", page)
	pagePad.PaddingTop = UDim.new(0, 6)
	pagePad.PaddingBottom = UDim.new(0, 12)
	pagePad.PaddingLeft = UDim.new(0, 2)
	pagePad.PaddingRight = UDim.new(0, 2)

	pages[name] = page
	return page
end

local homePage = makePage("Home")
local farmPage = makePage("Farm")
local miniPage = makePage("Minigames")
local teleportPage = makePage("Teleport")
local infoPage = makePage("Info")

local function selectNav(name)
	UI.activeNav = name
	for n, item in pairs(navItems) do
		local active = n == name
		item.btn.BackgroundColor3 = active and C.cardInner or C.card
		item.btn.BackgroundTransparency = active and 0.05 or 0.35
		item.btn.TextColor3 = active and C.accentBright or C.muted
		if item.indicator then
			item.indicator.BackgroundTransparency = active and 0.2 or 1
		end
	end
	for n, page in pairs(pages) do
		page.Visible = n == name
	end
	searchBox.PlaceholderText = name == "Teleport" and "Search locations..." or "Search features..."
	UI.applySearchFilter()
end

local function makeNav(icon, label, pageName)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(100, 38)
	btn.BackgroundColor3 = C.card
	btn.BackgroundTransparency = 0.35
	btn.Text = icon .. "  " .. label
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 11
	btn.TextColor3 = C.muted
	btn.AutoButtonColor = false
	btn.TextTruncate = Enum.TextTruncate.AtEnd
	btn.Parent = sidebar
	corner(btn, 8)
	stroke(btn, C.border, 1, 0.65)

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.new(0, 3, 0.55, 0)
	indicator.Position = UDim2.new(0, 3, 0.225, 0)
	indicator.BackgroundColor3 = C.accent
	indicator.BackgroundTransparency = 1
	indicator.BorderSizePixel = 0
	indicator.Parent = btn
	corner(indicator, 2)

	navItems[pageName] = { btn = btn, indicator = indicator }
	btn.MouseButton1Click:Connect(function()
		selectNav(pageName)
	end)
end

makeNav("🏠", "Home", "Home")
makeNav("⚡", "Farm", "Farm")
makeNav("🎮", "Games", "Minigames")
makeNav("📍", "Teleport", "Teleport")
makeNav("ℹ️", "Info", "Info")

local collapsed = false
hdrBtn("-", C.yellow, -58, function()
	collapsed = not collapsed
	bodyWrap.Visible = not collapsed
	root.Size = collapsed and UDim2.fromOffset(700, 46) or UDim2.fromOffset(700, 540)
	glow.Size = collapsed and UDim2.fromOffset(720, 66) or UDim2.fromOffset(720, 560)
end)
hdrBtn("×", C.red, -32, function()
	Farm.running = false
	stopTradeHelper()
	stopRaceHelper()
	if heartbeatConn then
		heartbeatConn:Disconnect()
	end
	gui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightControl then
		gui.Enabled = not gui.Enabled
	end
end)

local function sectionCard(parent, titleText, icon)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = C.card
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 12)
	stroke(card, C.border, 1, 0.45)

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 10)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card

	local heading = Instance.new("TextLabel")
	heading.LayoutOrder = 1
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, 0, 0, 22)
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 11
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = C.accent
	heading.Text = (icon or "") .. "  " .. string.upper(titleText)
	heading.ZIndex = 1
	heading.Parent = card

	local inner = Instance.new("Frame")
	inner.LayoutOrder = 2
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.BackgroundTransparency = 1
	inner.ClipsDescendants = false
	inner.Parent = card

	local innerList = Instance.new("UIListLayout")
	innerList.Padding = UDim.new(0, 8)
	innerList.SortOrder = Enum.SortOrder.LayoutOrder
	innerList.Parent = inner

	return inner
end

local function statRow(inner, label, color)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = C.cardInner
	row.BackgroundTransparency = 0.4
	row.BorderSizePixel = 0
	row.Parent = inner
	corner(row, 8)
	stroke(row, C.border, 1, 0.7)

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft = UDim.new(0, 10)
	rowPad.PaddingRight = UDim.new(0, 10)
	rowPad.Parent = row

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(0.52, -10, 1, 0)
	name.Font = Enum.Font.Gotham
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = C.muted
	name.Text = label
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Size = UDim2.new(0.48, -10, 1, 0)
	value.Position = UDim2.fromScale(0.52, 0)
	value.Font = Enum.Font.GothamBold
	value.TextSize = 13
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = color or C.text
	value.Text = "..."
	value.TextTruncate = Enum.TextTruncate.AtEnd
	value.Parent = row
	return value
end

local ecoInner = sectionCard(homePage, "Economy", "💰")
local vTycoon = statRow(ecoInner, "Tycoon", C.text)
local vCash = statRow(ecoInner, "Cash", C.green)
local vInv = statRow(ecoInner, "Investors", C.accent)
local vInvSpent = statRow(ecoInner, "Investors Spent", C.gold)
local vPot = statRow(ecoInner, "Potential Rebirth", C.yellow)

local progInner = sectionCard(homePage, "Progress", "📈")
local vReb = statRow(progInner, "Rebirths", C.accent)
local vTReb = statRow(progInner, "Total Rebirths", C.gold)
local vEvo = statRow(progInner, "Evolution", C.green)
local vTEvo = statRow(progInner, "Total Evolves", C.green)
local vAsc = statRow(progInner, "Ascension Run", C.gold)
local vTAsc = statRow(progInner, "Total Ascensions", C.gold)

local sesInner = sectionCard(homePage, "Session", "⏱")
local vPlay = statRow(sesInner, "Play Time")
local vSess = statRow(sesInner, "Sessions")
local vFps = statRow(sesInner, "FPS")
local vPing = statRow(sesInner, "Ping")
local vTrees = statRow(sesInner, "Fruit Trees", C.green)
local vFruits = statRow(sesInner, "Fruits Left", C.green)

UI.applySearchFilter = function()
	local q = string.lower(UI.searchQuery)
	if UI.activeNav == "Teleport" then
		for _, entry in UI.teleportCards do
			local match = q == ""
				or string.find(string.lower(entry.label), q, 1, true)
				or string.find(string.lower(entry.category), q, 1, true)
			entry.btn.Visible = match
		end
		for _, section in UI.teleportSections do
			local anyVisible = false
			for _, entry in UI.teleportCards do
				if entry.section == section.frame and entry.btn.Visible then
					anyVisible = true
					break
				end
			end
			section.frame.Visible = q == "" or anyVisible
			if q ~= "" and anyVisible and not section.expanded then
				section.setExpanded(true)
			end
		end
		return
	end
	for _, entry in UI.toggleCards do
		local match = q == ""
			or string.find(string.lower(entry.label), q, 1, true)
			or string.find(string.lower(entry.desc), q, 1, true)
		entry.card.Visible = match
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	UI.searchQuery = searchBox.Text
	UI.applySearchFilter()
end)

local function makeToggle(inner, label, desc, key, icon)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = C.cardInner
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.Parent = inner
	corner(card, 10)
	local cardStroke = stroke(card, C.border, 1, 0.5)

	table.insert(UI.toggleCards, { card = card, label = label, desc = desc })

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 6)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = card

	local topRow = Instance.new("Frame")
	topRow.LayoutOrder = 1
	topRow.Size = UDim2.new(1, 0, 0, 26)
	topRow.BackgroundTransparency = 1
	topRow.Parent = card

	local iconLbl = Instance.new("TextLabel")
	iconLbl.BackgroundTransparency = 1
	iconLbl.Size = UDim2.fromOffset(24, 26)
	iconLbl.Font = Enum.Font.Gotham
	iconLbl.TextSize = 14
	iconLbl.Text = icon or "⚙"
	iconLbl.Parent = topRow

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -130, 1, 0)
	name.Position = UDim2.fromOffset(28, 0)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = C.text
	name.Text = label
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = topRow

	local stateLabel = Instance.new("TextLabel")
	stateLabel.BackgroundTransparency = 1
	stateLabel.Size = UDim2.fromOffset(34, 18)
	stateLabel.Position = UDim2.new(1, -96, 0.5, -9)
	stateLabel.Font = Enum.Font.GothamBlack
	stateLabel.TextSize = 11
	stateLabel.Text = "OFF"
	stateLabel.TextColor3 = C.red
	stateLabel.Parent = topRow

	local switch = Instance.new("TextButton")
	switch.Size = UDim2.fromOffset(48, 26)
	switch.Position = UDim2.new(1, -52, 0.5, -13)
	switch.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.ZIndex = 2
	switch.Parent = topRow
	corner(switch, 13)
	local switchStroke = stroke(switch, C.border, 1, 0.35)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = C.muted
	knob.ZIndex = 3
	knob.Parent = switch
	corner(knob, 10)

	local detail = Instance.new("TextLabel")
	detail.LayoutOrder = 2
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.new(1, 0, 0, 0)
	detail.AutomaticSize = Enum.AutomaticSize.Y
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 11
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = C.muted
	detail.TextWrapped = true
	detail.Text = desc
	detail.Parent = card

	local function refresh()
		local on = Farm[key] == true
		switch.BackgroundColor3 = on and C.accentDim or Color3.fromRGB(38, 42, 54)
		switchStroke.Color = on and C.accent or C.border
		switchStroke.Transparency = on and 0.1 or 0.45
		knob.Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
		knob.BackgroundColor3 = on and Color3.new(1, 1, 1) or C.muted
		cardStroke.Color = on and C.green or C.border
		cardStroke.Transparency = on and 0.25 or 0.5
		card.BackgroundColor3 = on and Color3.fromRGB(24, 38, 46) or C.cardInner
		stateLabel.Text = on and "ON" or "OFF"
		stateLabel.TextColor3 = on and C.green or C.red
	end

	switch.MouseButton1Click:Connect(function()
		setFeature(key, not Farm[key])
		log((Farm[key] and "ON: " or "OFF: ") .. label)
	end)
	refresh()
	table.insert(UI.toggleRefreshers, refresh)
	return detail
end

local function rebirthDescText()
	return "Rebirths at " .. formatMultiplier(Farm.rebirthMultiplier) .. "x"
end

local function upgradeDescText()
	return "Upgrades earners (" .. formatMultiplier(Farm.upgradeMultiplier) .. "x)"
end

local farmInner = sectionCard(farmPage, "Automation", "👤")
makeToggle(farmInner, "Auto Complete Tycoon", "Buys everything", "autoComplete", "🏗")
makeToggle(farmInner, "Auto Collect Fruits", "Collects fruits on your trees", "autoFruit", "🍋")
UI.upgradeToggleDetail = makeToggle(farmInner, "Auto Upgrade", upgradeDescText(), "autoUpgrade", "⬆")

local upgradeMultCard = Instance.new("Frame")
upgradeMultCard.Size = UDim2.new(1, 0, 0, 44)
upgradeMultCard.BackgroundColor3 = C.cardInner
upgradeMultCard.BorderSizePixel = 0
upgradeMultCard.Parent = farmInner
corner(upgradeMultCard, 10)
stroke(upgradeMultCard, C.border, 1, 0.5)

local upgradeMultPad = Instance.new("UIPadding")
upgradeMultPad.PaddingTop = UDim.new(0, 8)
upgradeMultPad.PaddingBottom = UDim.new(0, 8)
upgradeMultPad.PaddingLeft = UDim.new(0, 12)
upgradeMultPad.PaddingRight = UDim.new(0, 12)
upgradeMultPad.Parent = upgradeMultCard

local upgradeMultLabel = Instance.new("TextLabel")
upgradeMultLabel.BackgroundTransparency = 1
upgradeMultLabel.Size = UDim2.new(1, -156, 1, 0)
upgradeMultLabel.Font = Enum.Font.Gotham
upgradeMultLabel.TextSize = 11
upgradeMultLabel.TextXAlignment = Enum.TextXAlignment.Left
upgradeMultLabel.TextColor3 = C.muted
upgradeMultLabel.Text = "Upgrades per tick (" .. formatMultiplier(Farm.upgradeMultiplier) .. "x)"
upgradeMultLabel.Parent = upgradeMultCard

local function styleUpgradePresetBtn(btn, active)
	btn.BackgroundColor3 = active and C.accentDim or C.card
	btn.TextColor3 = active and C.text or C.muted
	local s = btn:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = active and C.accent or C.border
		s.Transparency = active and 0.2 or 0.45
	end
end

local function refreshUpgradePresetButtons()
	if UI.upgradeBtn1x then
		styleUpgradePresetBtn(UI.upgradeBtn1x, Farm.upgradeMultiplier == 1)
	end
	if UI.upgradeBtn25x then
		styleUpgradePresetBtn(UI.upgradeBtn25x, Farm.upgradeMultiplier == 25)
	end
end

local function updateUpgradeMultiplierUI()
	local display = formatMultiplier(Farm.upgradeMultiplier)
	upgradeMultLabel.Text = "Upgrades per tick (" .. display .. "x)"
	if UI.upgradeToggleDetail then
		UI.upgradeToggleDetail.Text = upgradeDescText()
	end
	refreshUpgradePresetButtons()
end

local function applyUpgradeMultiplier(text)
	local n = tonumber(text)
	if not n or n < 1 or n > 100 then
		UI.upgradeMultBox.Text = formatMultiplier(Farm.upgradeMultiplier)
		UI.upgradeMultBox.TextColor3 = C.text
		return false
	end
	Farm.upgradeMultiplier = math.floor(n)
	UI.upgradeMultBox.Text = formatMultiplier(Farm.upgradeMultiplier)
	UI.upgradeMultBox.TextColor3 = C.text
	updateUpgradeMultiplierUI()
	log("Upgrade multiplier: " .. formatMultiplier(Farm.upgradeMultiplier) .. "×")
	return true
end

UI.upgradeBtn1x = Instance.new("TextButton")
UI.upgradeBtn1x.Size = UDim2.fromOffset(32, 28)
UI.upgradeBtn1x.Position = UDim2.new(1, -150, 0.5, -14)
UI.upgradeBtn1x.BackgroundColor3 = C.card
UI.upgradeBtn1x.Font = Enum.Font.GothamBold
UI.upgradeBtn1x.TextSize = 11
UI.upgradeBtn1x.Text = "1x"
UI.upgradeBtn1x.AutoButtonColor = false
UI.upgradeBtn1x.Parent = upgradeMultCard
corner(UI.upgradeBtn1x, 8)
stroke(UI.upgradeBtn1x, C.border, 1, 0.45)

UI.upgradeBtn25x = Instance.new("TextButton")
UI.upgradeBtn25x.Size = UDim2.fromOffset(36, 28)
UI.upgradeBtn25x.Position = UDim2.new(1, -114, 0.5, -14)
UI.upgradeBtn25x.BackgroundColor3 = C.card
UI.upgradeBtn25x.Font = Enum.Font.GothamBold
UI.upgradeBtn25x.TextSize = 11
UI.upgradeBtn25x.Text = "25x"
UI.upgradeBtn25x.AutoButtonColor = false
UI.upgradeBtn25x.Parent = upgradeMultCard
corner(UI.upgradeBtn25x, 8)
stroke(UI.upgradeBtn25x, C.border, 1, 0.45)

UI.upgradeMultBox = Instance.new("TextBox")
UI.upgradeMultBox.Size = UDim2.fromOffset(42, 28)
UI.upgradeMultBox.Position = UDim2.new(1, -42, 0.5, -14)
UI.upgradeMultBox.BackgroundColor3 = C.card
UI.upgradeMultBox.Font = Enum.Font.GothamBold
UI.upgradeMultBox.TextSize = 12
UI.upgradeMultBox.TextColor3 = C.text
UI.upgradeMultBox.Text = formatMultiplier(Farm.upgradeMultiplier)
UI.upgradeMultBox.ClearTextOnFocus = false
UI.upgradeMultBox.Parent = upgradeMultCard
corner(UI.upgradeMultBox, 8)
stroke(UI.upgradeMultBox, C.border, 1, 0.45)

UI.upgradeBtn1x.MouseButton1Click:Connect(function()
	applyUpgradeMultiplier("1")
end)

UI.upgradeBtn25x.MouseButton1Click:Connect(function()
	applyUpgradeMultiplier("25")
end)

UI.upgradeMultBox.FocusLost:Connect(function()
	applyUpgradeMultiplier(UI.upgradeMultBox.Text)
end)

UI.upgradeMultBox:GetPropertyChangedSignal("Text"):Connect(function()
	local n = tonumber(UI.upgradeMultBox.Text)
	if n and n >= 1 and n <= 100 then
		Farm.upgradeMultiplier = math.floor(n)
		local display = formatMultiplier(Farm.upgradeMultiplier)
		upgradeMultLabel.Text = "Upgrades per tick (" .. display .. "x)"
		if UI.upgradeToggleDetail then
			UI.upgradeToggleDetail.Text = "Upgrades earners (" .. display .. "x)"
		end
		UI.upgradeMultBox.TextColor3 = C.accent
		refreshUpgradePresetButtons()
	else
		UI.upgradeMultBox.TextColor3 = C.red
	end
end)

refreshUpgradePresetButtons()

makeToggle(farmInner, "Auto Cash Drops", "Collects cash bags", "autoCashDrop", "💵")
local rebirthToggleDetail = makeToggle(farmInner, "Auto Rebirth", rebirthDescText(), "autoRebirth", "🔄")

local rebirthMultCard = Instance.new("Frame")
rebirthMultCard.Size = UDim2.new(1, 0, 0, 44)
rebirthMultCard.BackgroundColor3 = C.cardInner
rebirthMultCard.BorderSizePixel = 0
rebirthMultCard.Parent = farmInner
corner(rebirthMultCard, 10)
stroke(rebirthMultCard, C.border, 1, 0.5)

local rebirthMultPad = Instance.new("UIPadding")
rebirthMultPad.PaddingTop = UDim.new(0, 8)
rebirthMultPad.PaddingBottom = UDim.new(0, 8)
rebirthMultPad.PaddingLeft = UDim.new(0, 12)
rebirthMultPad.PaddingRight = UDim.new(0, 12)
rebirthMultPad.Parent = rebirthMultCard

local rebirthMultLabel = Instance.new("TextLabel")
rebirthMultLabel.BackgroundTransparency = 1
rebirthMultLabel.Size = UDim2.new(1, -70, 1, 0)
rebirthMultLabel.Font = Enum.Font.Gotham
rebirthMultLabel.TextSize = 11
rebirthMultLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthMultLabel.TextColor3 = C.muted
rebirthMultLabel.Text = "Rebirth at " .. formatMultiplier(Farm.rebirthMultiplier) .. "x or more"
rebirthMultLabel.Parent = rebirthMultCard

UI.rebirthMultBox = Instance.new("TextBox")
UI.rebirthMultBox.Size = UDim2.fromOffset(58, 28)
UI.rebirthMultBox.Position = UDim2.new(1, -58, 0.5, -14)
UI.rebirthMultBox.BackgroundColor3 = C.card
UI.rebirthMultBox.Font = Enum.Font.GothamBold
UI.rebirthMultBox.TextSize = 12
UI.rebirthMultBox.TextColor3 = C.text
UI.rebirthMultBox.Text = formatMultiplier(Farm.rebirthMultiplier)
UI.rebirthMultBox.ClearTextOnFocus = false
UI.rebirthMultBox.Parent = rebirthMultCard
corner(UI.rebirthMultBox, 8)
stroke(UI.rebirthMultBox, C.border, 1, 0.45)

local function updateRebirthMultiplierUI()
	local display = formatMultiplier(Farm.rebirthMultiplier)
	rebirthMultLabel.Text = "Rebirth at " .. display .. "x or more"
	rebirthToggleDetail.Text = rebirthDescText()
end

local function applyRebirthMultiplier(text)
	local n = tonumber(text)
	if not n or n < 1 or n > 100 then
		UI.rebirthMultBox.Text = formatMultiplier(Farm.rebirthMultiplier)
		UI.rebirthMultBox.TextColor3 = C.text
		return false
	end
	Farm.rebirthMultiplier = n
	UI.rebirthMultBox.Text = formatMultiplier(n)
	UI.rebirthMultBox.TextColor3 = C.text
	updateRebirthMultiplierUI()
	log("Rebirth multiplier: " .. formatMultiplier(n) .. "×")
	return true
end

UI.rebirthMultBox.FocusLost:Connect(function()
	applyRebirthMultiplier(UI.rebirthMultBox.Text)
end)

UI.rebirthMultBox:GetPropertyChangedSignal("Text"):Connect(function()
	local n = tonumber(UI.rebirthMultBox.Text)
	if n and n >= 1 and n <= 100 then
		Farm.rebirthMultiplier = n
		local display = formatMultiplier(n)
		rebirthMultLabel.Text = "Rebirth at " .. display .. "x or more"
		rebirthToggleDetail.Text = "Rebirths at " .. display .. "x or more"
		UI.rebirthMultBox.TextColor3 = C.accent
	else
		UI.rebirthMultBox.TextColor3 = C.red
	end
end)

makeToggle(farmInner, "Auto Phone Offers", "Raises once then accepts", "autoPhone", "📱")

local ascendInner = sectionCard(farmPage, "Ascension", "🚀")

local function ascendDescText()
	if Farm.autoAscend then
		return "Watching progress — ascends at 100%"
	end
	return "Turn on to ascend when all upgrades are bought"
end

UI.ascendToggleDetail = makeToggle(ascendInner, "Auto Ascend", ascendDescText(), "autoAscend", "⬆")

local ascendInfoCard = Instance.new("Frame")
ascendInfoCard.Size = UDim2.new(1, 0, 0, 72)
ascendInfoCard.BackgroundColor3 = C.cardInner
ascendInfoCard.BorderSizePixel = 0
ascendInfoCard.Parent = ascendInner
corner(ascendInfoCard, 10)
stroke(ascendInfoCard, C.border, 1, 0.5)

local ascendInfoPad = Instance.new("UIPadding")
ascendInfoPad.PaddingTop = UDim.new(0, 10)
ascendInfoPad.PaddingBottom = UDim.new(0, 10)
ascendInfoPad.PaddingLeft = UDim.new(0, 12)
ascendInfoPad.PaddingRight = UDim.new(0, 12)
ascendInfoPad.Parent = ascendInfoCard

local ascendInfoLayout = Instance.new("UIListLayout")
ascendInfoLayout.Padding = UDim.new(0, 6)
ascendInfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
ascendInfoLayout.Parent = ascendInfoCard

local function ascendInfoLine(text, color, order)
	local lbl = Instance.new("TextLabel")
	lbl.LayoutOrder = order
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = color or C.muted
	lbl.Text = text
	lbl.Parent = ascendInfoCard
	return lbl
end

UI.ascendProgressLabel = ascendInfoLine("Tycoon progress: ...", C.text, 1)
UI.ascendLevelLabel = ascendInfoLine("Total ascensions: ...", C.gold, 2)
UI.ascendStatusLabel = ascendInfoLine("Status: waiting for tycoon", C.muted, 3)

local ascendBarWrap = Instance.new("Frame")
ascendBarWrap.LayoutOrder = 4
ascendBarWrap.Size = UDim2.new(1, 0, 0, 8)
ascendBarWrap.BackgroundColor3 = C.card
ascendBarWrap.BorderSizePixel = 0
ascendBarWrap.Parent = ascendInfoCard
corner(ascendBarWrap, 4)

UI.ascendBarFill = Instance.new("Frame")
UI.ascendBarFill.Size = UDim2.fromScale(0, 1)
UI.ascendBarFill.BackgroundColor3 = C.accent
UI.ascendBarFill.BorderSizePixel = 0
UI.ascendBarFill.Parent = ascendBarWrap
corner(UI.ascendBarFill, 4)

local function refreshAscensionUI()
	local asc = readAscensionStats()
	UI.ascendProgressLabel.Text = "Tycoon progress: " .. asc.progressText
	UI.ascendLevelLabel.Text = "Total ascensions: " .. asc.level
	if asc.ready then
		UI.ascendStatusLabel.Text = Farm.autoAscend and "Status: ready — ascending soon" or "Status: ready to ascend (toggle off)"
		UI.ascendStatusLabel.TextColor3 = C.green
		UI.ascendProgressLabel.TextColor3 = C.green
	elseif asc.progress then
		UI.ascendStatusLabel.Text = Farm.autoAscend and "Status: buying upgrades..." or "Status: in progress"
		UI.ascendStatusLabel.TextColor3 = C.muted
		UI.ascendProgressLabel.TextColor3 = C.text
	else
		UI.ascendStatusLabel.Text = "Status: " .. asc.progressText
		UI.ascendStatusLabel.TextColor3 = C.muted
		UI.ascendProgressLabel.TextColor3 = C.muted
	end
	UI.ascendBarFill.Size = UDim2.fromScale(math.clamp(asc.progress or 0, 0, 1), 1)
	if UI.ascendToggleDetail then
		UI.ascendToggleDetail.Text = ascendDescText()
	end
end

table.insert(UI.toggleRefreshers, refreshAscensionUI)

local function applyConfigData(data)
	if type(data) ~= "table" then
		return false
	end
	local rm = tonumber(data.rebirthMultiplier)
	if rm and rm >= 1 and rm <= 100 then
		applyRebirthMultiplier(tostring(rm))
	end
	local um = tonumber(data.upgradeMultiplier)
	if um and um >= 1 and um <= 100 then
		applyUpgradeMultiplier(tostring(um))
	end
	local features = type(data.features) == "table" and data.features or {}
	for _, key in ipairs(FEATURE_CONFIG_KEYS) do
		local enabled = features[key] == true
		if Farm[key] ~= enabled then
			setFeature(key, enabled)
		end
	end
	refreshAllToggles()
	return true
end

local farmActions = Instance.new("Frame")
farmActions.Size = UDim2.new(1, 0, 0, 36)
farmActions.BackgroundTransparency = 1
farmActions.Parent = farmPage

local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.Padding = UDim.new(0, 8)
actionLayout.Parent = farmActions

local function makeActionBtn(text, color, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(200, 32)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = C.text
	b.AutoButtonColor = true
	b.Parent = farmActions
	corner(b, 10)
	stroke(b, C.border, 1, 0.4)
	b.MouseButton1Click:Connect(callback)
	return b
end

makeActionBtn("▶  Enable All Farm", C.accentDim, function()
	for _, key in ipairs({ "autoComplete", "autoFruit", "autoUpgrade", "autoCashDrop", "autoRebirth", "autoAscend", "autoPhone" }) do
		setFeature(key, true)
	end
	setStatus("All farm features running")
	log("Enabled all farm automations")
end)

makeActionBtn("⏹  Disable All", C.card, function()
	for _, key in ipairs({ "autoComplete", "autoFruit", "autoUpgrade", "autoCashDrop", "autoRebirth", "autoAscend", "autoPhone" }) do
		setFeature(key, false)
	end
	log("Disabled all farm automations")
end)

UI.statusLabel = Instance.new("TextLabel")
UI.statusLabel.BackgroundTransparency = 1
UI.statusLabel.Size = UDim2.new(1, 0, 0, 18)
UI.statusLabel.Font = Enum.Font.GothamBold
UI.statusLabel.TextSize = 11
UI.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.statusLabel.TextColor3 = C.accent
UI.statusLabel.Text = "Status: Idle"
UI.statusLabel.Parent = farmPage

local miniInner = sectionCard(miniPage, "Quick Actions", "🎯")
makeToggle(miniInner, "Auto Lemon Trading", "Plays trade minigame", "autoTrade", "📈")
makeToggle(miniInner, "Auto Lemon Dash", "Plays race minigame", "autoRace", "🏁")

local configInner = sectionCard(infoPage, "Configs", "💾")

local configCurrent = Instance.new("TextLabel")
configCurrent.BackgroundTransparency = 1
configCurrent.Size = UDim2.new(1, 0, 0, 18)
configCurrent.Font = Enum.Font.GothamBold
configCurrent.TextSize = 12
configCurrent.TextXAlignment = Enum.TextXAlignment.Left
configCurrent.TextColor3 = C.muted
configCurrent.Text = "Active config: (none)"
configCurrent.Parent = configInner
UI.configCurrentLabel = configCurrent

local function refreshConfigCurrentLabel()
	local active = getActiveConfigName()
	if active then
		configCurrent.Text = "Active config: " .. active
		configCurrent.TextColor3 = C.accent
	else
		configCurrent.Text = "Active config: (none)"
		configCurrent.TextColor3 = C.muted
	end
end

if not configStorageReady() then
	local storageWarn = Instance.new("TextLabel")
	storageWarn.BackgroundTransparency = 1
	storageWarn.Size = UDim2.new(1, 0, 0, 32)
	storageWarn.Font = Enum.Font.Gotham
	storageWarn.TextSize = 11
	storageWarn.TextXAlignment = Enum.TextXAlignment.Left
	storageWarn.TextYAlignment = Enum.TextYAlignment.Top
	storageWarn.TextWrapped = true
	storageWarn.TextColor3 = C.yellow
	storageWarn.Text = "Config files need writefile, readfile, and isfile on your executor."
	storageWarn.Parent = configInner
end

local configNameRow = Instance.new("Frame")
configNameRow.Size = UDim2.new(1, 0, 0, 34)
configNameRow.BackgroundTransparency = 1
configNameRow.Parent = configInner

local configNameWrap = Instance.new("Frame")
configNameWrap.Size = UDim2.new(1, -200, 1, 0)
configNameWrap.BackgroundColor3 = C.cardInner
configNameWrap.BorderSizePixel = 0
configNameWrap.Parent = configNameRow
corner(configNameWrap, 8)
stroke(configNameWrap, C.border, 1, 0.55)

UI.configNameBox = Instance.new("TextBox")
UI.configNameBox.BackgroundTransparency = 1
UI.configNameBox.Size = UDim2.new(1, -16, 1, 0)
UI.configNameBox.Position = UDim2.fromOffset(10, 0)
UI.configNameBox.Font = Enum.Font.Gotham
UI.configNameBox.TextSize = 13
UI.configNameBox.PlaceholderText = "Config name..."
UI.configNameBox.PlaceholderColor3 = C.muted
UI.configNameBox.TextColor3 = C.text
UI.configNameBox.ClearTextOnFocus = false
UI.configNameBox.Text = ""
UI.configNameBox.Parent = configNameWrap

local function configActionBtn(text, color, xOff, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(56, 34)
	b.Position = UDim2.new(1, xOff, 0, 0)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.TextColor3 = C.text
	b.AutoButtonColor = true
	b.Parent = configNameRow
	corner(b, 8)
	stroke(b, C.border, 1, 0.4)
	b.MouseButton1Click:Connect(callback)
	return b
end

local configStatus = Instance.new("TextLabel")
configStatus.BackgroundTransparency = 1
configStatus.Size = UDim2.new(1, 0, 0, 16)
configStatus.Font = Enum.Font.Gotham
configStatus.TextSize = 10
configStatus.TextXAlignment = Enum.TextXAlignment.Left
configStatus.TextColor3 = C.muted
configStatus.Text = ""
configStatus.Parent = configInner

local configList = Instance.new("ScrollingFrame")
configList.Size = UDim2.new(1, 0, 0, 108)
configList.BackgroundColor3 = C.cardInner
configList.BackgroundTransparency = 0.15
configList.BorderSizePixel = 0
configList.ScrollBarThickness = 3
configList.ScrollBarImageColor3 = C.accent
configList.CanvasSize = UDim2.fromOffset(0, 0)
configList.AutomaticCanvasSize = Enum.AutomaticSize.Y
configList.Parent = configInner
corner(configList, 8)
stroke(configList, C.border, 1, 0.6)

local configListLayout = Instance.new("UIListLayout")
configListLayout.Padding = UDim.new(0, 4)
configListLayout.SortOrder = Enum.SortOrder.LayoutOrder
configListLayout.Parent = configList

local configListPad = Instance.new("UIPadding")
configListPad.PaddingTop = UDim.new(0, 6)
configListPad.PaddingBottom = UDim.new(0, 6)
configListPad.PaddingLeft = UDim.new(0, 6)
configListPad.PaddingRight = UDim.new(0, 6)
configListPad.Parent = configList

local configEmpty = Instance.new("TextLabel")
configEmpty.BackgroundTransparency = 1
configEmpty.Size = UDim2.new(1, 0, 0, 28)
configEmpty.Font = Enum.Font.Gotham
configEmpty.TextSize = 11
configEmpty.TextColor3 = C.muted
configEmpty.Text = "No saved configs yet"
configEmpty.Parent = configList

local function refreshConfigList()
	for _, child in configList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local names = listConfigNames()
	configEmpty.Visible = #names == 0
	local active = getActiveConfigName()
	for i, name in ipairs(names) do
		local btn = Instance.new("TextButton")
		btn.LayoutOrder = i
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.BackgroundColor3 = name == active and Color3.fromRGB(24, 38, 46) or C.card
		btn.BackgroundTransparency = name == active and 0.05 or 0.2
		btn.Text = "  " .. name .. (name == active and "  · active" or "")
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 12
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.TextColor3 = name == active and C.accentBright or C.text
		btn.AutoButtonColor = false
		btn.Parent = configList
		corner(btn, 6)
		stroke(btn, name == active and C.accent or C.border, 1, name == active and 0.25 or 0.55)
		btn.MouseButton1Click:Connect(function()
			UI.configNameBox.Text = name
		end)
		btn.MouseButton2Click:Connect(function()
			UI.configNameBox.Text = name
			local ok, msg = loadConfigNamed(name, applyConfigData)
			if ok then
				configStatus.Text = "Loaded " .. name
				configStatus.TextColor3 = C.green
				refreshConfigCurrentLabel()
				refreshConfigList()
				log("Loaded config: " .. name)
			else
				configStatus.Text = tostring(msg)
				configStatus.TextColor3 = C.red
			end
		end)
	end
end

configActionBtn("Save", C.accentDim, -192, function()
	local ok, msg = saveConfigNamed(UI.configNameBox.Text)
	if ok then
		configStatus.Text = "Saved " .. msg
		configStatus.TextColor3 = C.green
		refreshConfigCurrentLabel()
		refreshConfigList()
		log("Saved config: " .. msg)
	else
		configStatus.Text = tostring(msg)
		configStatus.TextColor3 = C.red
	end
end)

configActionBtn("Load", C.cardInner, -128, function()
	local ok, msg = loadConfigNamed(UI.configNameBox.Text, applyConfigData)
	if ok then
		configStatus.Text = "Loaded " .. msg
		configStatus.TextColor3 = C.green
		refreshConfigCurrentLabel()
		refreshConfigList()
		log("Loaded config: " .. msg)
	else
		configStatus.Text = tostring(msg)
		configStatus.TextColor3 = C.red
	end
end)

configActionBtn("Delete", C.red, -60, function()
	local ok, msg = deleteConfigNamed(UI.configNameBox.Text)
	if ok then
		configStatus.Text = "Deleted " .. msg
		configStatus.TextColor3 = C.yellow
		refreshConfigCurrentLabel()
		refreshConfigList()
		log("Deleted config: " .. msg)
	else
		configStatus.Text = tostring(msg)
		configStatus.TextColor3 = C.red
	end
end)

refreshConfigCurrentLabel()
refreshConfigList()

local infoInner = sectionCard(infoPage, "Activity Log", "📋")
UI.logLabel = Instance.new("TextLabel")
UI.logLabel.BackgroundTransparency = 1
UI.logLabel.Size = UDim2.new(1, 0, 0, 200)
UI.logLabel.Font = Enum.Font.Code
UI.logLabel.TextSize = 11
UI.logLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.logLabel.TextYAlignment = Enum.TextYAlignment.Top
UI.logLabel.TextColor3 = C.muted
UI.logLabel.TextWrapped = true
UI.logLabel.Text = "Ready."
UI.logLabel.Parent = infoInner

local aboutInner = sectionCard(infoPage, "About", "ℹ️")
local aboutText = Instance.new("TextLabel")
aboutText.BackgroundTransparency = 1
aboutText.Size = UDim2.new(1, 0, 0, 90)
aboutText.Font = Enum.Font.Gotham
aboutText.TextSize = 12
aboutText.TextXAlignment = Enum.TextXAlignment.Left
aboutText.TextYAlignment = Enum.TextYAlignment.Top
aboutText.TextColor3 = C.muted
aboutText.TextWrapped = true
aboutText.Text = ("Sigma Scripts · Sell Lemons v%s\nRightControl toggles UI visibility.\nFarm → Ascension section for auto ascend.\nInfo → Configs saves toggles & multipliers."):format(SIGMA_VERSION)
aboutText.Parent = aboutInner

local teleportCount = 0
for _, cat in TELEPORT_CATEGORIES do
	teleportCount += #cat.locations
end

local tpHeader = Instance.new("TextLabel")
tpHeader.LayoutOrder = 0
tpHeader.BackgroundTransparency = 1
tpHeader.Size = UDim2.new(1, 0, 0, 18)
tpHeader.Font = Enum.Font.GothamBold
tpHeader.TextSize = 11
tpHeader.TextXAlignment = Enum.TextXAlignment.Left
tpHeader.TextColor3 = C.muted
tpHeader.Text = teleportCount .. " sewer locations · click to teleport"
tpHeader.Parent = teleportPage

local function makeTeleportBtn(parent, label, category, loc, sectionFrame)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = C.cardInner
	btn.BackgroundTransparency = 0.15
	btn.Text = "  " .. label
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.TextColor3 = C.text
	btn.AutoButtonColor = false
	btn.Parent = parent
	corner(btn, 8)
	stroke(btn, C.border, 1, 0.65)

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(28, 42, 52)
		btn.TextColor3 = C.accentBright
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = C.cardInner
		btn.TextColor3 = C.text
	end)
	btn.MouseButton1Click:Connect(function()
		pcall(function()
			local inst = loc.index and resolveIndexedInst(loc.path, loc.index) or resolveInstFromPath(loc.path)
			local target = getInstPosition(inst, loc.pos)
			if target then
				tpTo(target)
				local posStr = string.format("%.1f, %.1f, %.1f", target.X, target.Y, target.Z)
				setStatus("Teleported → " .. label)
				log("Teleport: " .. label .. " @ " .. posStr)
			else
				log("Teleport failed: " .. label)
			end
		end)
	end)

	table.insert(UI.teleportCards, { btn = btn, label = label, category = category, section = sectionFrame })
	return btn
end

local function makeCollapsibleSection(parent, category)
	local expanded = true
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = C.card
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 12)
	stroke(card, C.border, 1, 0.45)

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	local headerBtn = Instance.new("TextButton")
	headerBtn.LayoutOrder = 1
	headerBtn.Size = UDim2.new(1, 0, 0, 28)
	headerBtn.BackgroundTransparency = 1
	headerBtn.Text = ""
	headerBtn.AutoButtonColor = false
	headerBtn.Parent = card

	local toggleLbl = Instance.new("TextLabel")
	toggleLbl.BackgroundTransparency = 1
	toggleLbl.Size = UDim2.fromOffset(22, 28)
	toggleLbl.Font = Enum.Font.GothamBold
	toggleLbl.TextSize = 14
	toggleLbl.TextColor3 = C.accent
	toggleLbl.Text = "−"
	toggleLbl.Parent = headerBtn

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Size = UDim2.new(1, -60, 1, 0)
	titleLbl.Position = UDim2.fromOffset(26, 0)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 11
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextColor3 = C.accent
	titleLbl.Text = (category.icon or "📍") .. "  " .. string.upper(category.name)
	titleLbl.Parent = headerBtn

	local countLbl = Instance.new("TextLabel")
	countLbl.BackgroundTransparency = 1
	countLbl.Size = UDim2.fromOffset(40, 28)
	countLbl.Position = UDim2.new(1, -40, 0, 0)
	countLbl.Font = Enum.Font.Gotham
	countLbl.TextSize = 10
	countLbl.TextXAlignment = Enum.TextXAlignment.Right
	countLbl.TextColor3 = C.muted
	countLbl.Text = tostring(#category.locations)
	countLbl.Parent = headerBtn

	local inner = Instance.new("Frame")
	inner.LayoutOrder = 2
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.BackgroundTransparency = 1
	inner.Parent = card

	local innerList = Instance.new("UIListLayout")
	innerList.Padding = UDim.new(0, 6)
	innerList.SortOrder = Enum.SortOrder.LayoutOrder
	innerList.Parent = inner

	local function setExpanded(on)
		expanded = on
		inner.Visible = on
		toggleLbl.Text = on and "−" or "+"
	end

	headerBtn.MouseButton1Click:Connect(function()
		setExpanded(not expanded)
	end)

	for _, loc in category.locations do
		makeTeleportBtn(inner, loc.name, category.name, loc, card)
	end

	table.insert(UI.teleportSections, {
		frame = card,
		expanded = expanded,
		setExpanded = setExpanded,
	})

	return card
end

for _, category in TELEPORT_CATEGORIES do
	makeCollapsibleSection(teleportPage, category)
end

selectNav("Home")

local dragging = false
local dragStart
local startPos
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = root.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		local newPos = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
		root.Position = newPos
		glow.Position = newPos
	end
end)

	UI.gui = gui
	UI.glow = glow
	UI.root = root
	UI.footerFps = footerFps
	UI.footerStatus = footerStatus
	UI.vTycoon = vTycoon
	UI.vCash = vCash
	UI.vInv = vInv
	UI.vInvSpent = vInvSpent
	UI.vPot = vPot
	UI.vReb = vReb
	UI.vTReb = vTReb
	UI.vEvo = vEvo
	UI.vTEvo = vTEvo
	UI.vAsc = vAsc
	UI.vTAsc = vTAsc
	UI.vPlay = vPlay
	UI.vSess = vSess
	UI.vFps = vFps
	UI.vPing = vPing
	UI.vTrees = vTrees
	UI.vFruits = vFruits

	task.defer(function()
		if not configStorageReady() then
			return
		end
		local active = getActiveConfigName()
		if active then
			local ok = loadConfigNamed(active, applyConfigData)
			if ok then
				log("Restored config: " .. active)
				refreshConfigCurrentLabel()
				refreshConfigList()
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		UI.frames += 1
	end)
end

buildUI()

local function fmtTime(sec)
	sec = tonumber(sec) or 0
	return string.format("%dh %dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60))
end

refreshTreeGroups(true)
setStatus("Hub active")
log("Loaded " .. Farm.scannedTreeCount .. " trees (" .. #Farm.treeGroups .. " ripe) | Heartbeat loops active")

local hb = { stats = 0, tycoon = 0, toggle = 0, minigame = 0 }
heartbeatConn = RunService.Heartbeat:Connect(function(dt)
	if not UI.gui.Parent or not Farm.running then
		if heartbeatConn then
			heartbeatConn:Disconnect()
		end
		return
	end

	for key, handler in pairs(FEATURE_HANDLERS) do
		if Farm[key] then
			UI.featureAccum[key] = (UI.featureAccum[key] or 0) + dt
			local interval = FEATURE_DELAYS[key] or LOOP_DELAY
			if UI.featureAccum[key] >= interval then
				UI.featureAccum[key] = 0
				task.defer(function()
					if Farm[key] and Farm.running then
						pcall(handler)
					end
				end)
			end
		else
			UI.featureAccum[key] = 0
		end
	end

	hb.minigame += dt
	if hb.minigame >= 0.15 then
		hb.minigame = 0
		if Farm.autoTrade or Farm.autoRace or Farm.minigameBusy or isCashCheckVisible() then
			pcall(tryClaimMinigameCheck)
		end
	end

	hb.tycoon += dt
	if hb.tycoon >= 2 then
		hb.tycoon = 0
		if not getTycoonInstance() then
			retryTycoonLoad()
		end
	end

	hb.stats += dt
	hb.toggle += dt
	if hb.toggle >= 0.25 then
		hb.toggle = 0
		refreshAllToggles()
	end

	if hb.stats >= 0.5 then
		hb.stats = 0

		local stats = readStats()
		UI.vTycoon.Text = stats.tycoon
		UI.vCash.Text = stats.cash
		UI.vInv.Text = stats.investors
		UI.vInvSpent.Text = stats.invSpent
		UI.vPot.Text = stats.potential
		UI.vReb.Text = stats.rebirths
		UI.vTReb.Text = stats.totalRebirths
		UI.vEvo.Text = stats.evolution
		UI.vTEvo.Text = stats.totalEvolves
		UI.vAsc.Text = stats.ascensions
		UI.vTAsc.Text = stats.totalAscensions

		UI.vPlay.Text = fmtTime(plr:GetAttribute("_Clock_TotalPlayTime"))
		UI.vSess.Text = tostring(plr:GetAttribute("_Clock_SessionCount") or "?")
		UI.vFps.Text = tostring(UI.frames * 2)
		UI.footerFps.Text = "FPS: " .. tostring(UI.frames * 2)
		UI.frames = 0
		local pingOk, ping = pcall(function()
			return math.floor(plr:GetNetworkPing() * 1000)
		end)
		UI.vPing.Text = pingOk and (ping .. " ms") or "N/A"
		UI.vTrees.Text = tostring(#Farm.treeGroups)
		UI.vFruits.Text = tostring(countActiveFruits())
		UI.footerStatus.Text = Farm.lastAction
		refreshUI()
		refreshAscensionUI()
		ensureHubOnTop()

		Farm.tick += 1
		if Farm.autoFruit and Farm.tick % 120 == 0 then
			refreshTreeGroups(true)
		end
	end
end)

while Farm.running and UI.gui.Parent do
	if getgenv().SigmaStopRequested then
		Farm.running = false
		break
	end
	task.wait(0.25)
end

getgenv().SigmaScriptsRunning = nil
]=],
	candy_escape   = [=[-- Candy & Chocolate Keyboard Escape — Sigma Scripts game module
-- Game: [UPD] +1 Speed Keyboard Escape | Candy & Chocolate (PlaceId 95082159892680)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local plr = Players.LocalPlayer

local CANDY_VERSION = "2026.06.23-v2"
local PLACE_ID = 95082159892680

if game.PlaceId ~= PLACE_ID then
	warn("[CandyEscape] Wrong game — expected PlaceId " .. PLACE_ID)
end

local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5)
local function remote(name)
	return Remotes and Remotes:FindFirstChild(name)
end

local S = {
	speedHack = false,
	speedVal = 300,
	jumpBoost = false,
	jumpPower = 120,
	fly = false,
	flySpeed = 80,
	noclip = false,
	infiniteJump = false,
	antiVoid = false,
	godMode = false,
	autoRun = false,
	autoWin = false,
	autoWinDelay = 1.5,
	autoRebirth = false,
	autoCollect = false,
	fullClear = false,
	running = true,
	logLines = {},
}

local UI = {}

local function getChar()
	return plr.Character or plr.CharacterAdded:Wait()
end
local function getHRP()
	local c = plr.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
	local c = plr.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function log(msg)
	if #S.logLines >= 60 then
		table.remove(S.logLines, 1)
	end
	table.insert(S.logLines, os.date("%H:%M:%S") .. "  " .. msg)
	if UI.logFrame then
		for _, c in ipairs(UI.logFrame:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		for i = #S.logLines, math.max(1, #S.logLines - 8), -1 do
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(1, 0, 0, 14)
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 10
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = Color3.fromRGB(190, 230, 255)
			lbl.Text = S.logLines[i]
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.LayoutOrder = #S.logLines - i
			lbl.Parent = UI.logFrame
		end
	end
end

local function setStatus(text, color)
	if UI.statusLabel then
		UI.statusLabel.Text = text
		UI.statusLabel.TextColor3 = color or C.accent
	end
end

-- ── Stage / win data ───────────────────────────────────────────────────────
local STAGE_SPAWNS = {
	{ name = "HUB", pos = Vector3.new(0, 7, 0) },
	{ name = "Stage 1", pos = Vector3.new(-23, 25, 110) },
	{ name = "Stage 2", pos = Vector3.new(2, 8, 282) },
	{ name = "Stage 3", pos = Vector3.new(2, 8, 507) },
}

local STAGE_ORDER = {
	"Stage0_HUB", "Stage1", "Stage2", "Stage3", "Stage4", "Stage5",
	"Stage6", "Stage7", "Stage8", "Stage9", "Stage10", "Stage11",
	"Stage12", "Stage13", "Stage14", "Stage15", "Level15",
}

local function findStagePos(stageName)
	local structure = workspace:FindFirstChild("Structure")
	if not structure then
		return nil
	end
	local stage = structure:FindFirstChild(stageName)
	if not stage then
		return nil
	end
	for _, p in ipairs(stage:GetDescendants()) do
		if p:IsA("SpawnLocation") then
			return p.Position + Vector3.new(0, 4, 0)
		end
	end
	for _, p in ipairs(stage:GetDescendants()) do
		if p:IsA("BasePart") then
			return p.Position + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

local function findWinBlocks()
	local found = {}
	local structure = workspace:FindFirstChild("Structure")
	if structure then
		for _, v in ipairs(structure:GetDescendants()) do
			if v:IsA("BasePart") and v.Name:find("Win") then
				table.insert(found, v.Position + Vector3.new(0, 3, 0))
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Z < b.Z
	end)
	return found
end

local function tpTo(pos)
	local hrp = getHRP()
	if hrp and pos then
		hrp.CFrame = CFrame.new(pos)
	end
end

local function tpToStage(index)
	local entry = STAGE_SPAWNS[index]
	if entry then
		tpTo(entry.pos + Vector3.new(0, 3, 0))
		log("TP → " .. entry.name)
		setStatus("Teleported to " .. entry.name)
	end
end

local function tpToLastStage()
	for i = #STAGE_ORDER, 1, -1 do
		local pos = findStagePos(STAGE_ORDER[i])
		if pos then
			tpTo(pos)
			log("TP → " .. STAGE_ORDER[i])
			setStatus("Teleported to " .. STAGE_ORDER[i])
			return
		end
	end
	tpTo(Vector3.new(0, 50, 1000))
end

local function tpCheckpoint(name)
	local cp = workspace:FindFirstChild("Checkpoints")
	local spawns = cp and cp:FindFirstChild("Spawns")
	local part = spawns and spawns:FindFirstChild(name)
	if part then
		tpTo(part.Position + Vector3.new(0, 3, 0))
		log("Checkpoint → " .. name)
		return
	end
	local rem = remote("RequestCheckpointTp")
	if rem then
		pcall(function()
			rem:FireServer(name)
		end)
		log("Requested checkpoint " .. name)
	end
end

local function doInstantWin()
	local hrp = getHRP()
	if not hrp then
		return
	end
	local blocks = findWinBlocks()
	if #blocks == 0 then
		setStatus("No win blocks found", C.red)
		return
	end
	tpTo(blocks[#blocks])
	task.wait(0.2)
	local rem = remote("AddWin")
	if rem then
		pcall(function()
			rem:FireServer()
		end)
	end
	log("Instant win triggered")
	setStatus("Win triggered")
end

local function doSingleWin()
	local hrp = getHRP()
	if not hrp then
		return
	end
	local blocks = findWinBlocks()
	if #blocks == 0 then
		return
	end
	tpTo(blocks[1])
	task.wait(0.25)
	tpTo(STAGE_SPAWNS[1].pos)
end

local function tryRebirth()
	local rem = remote("Rebirth")
	if rem then
		pcall(function()
			rem:FireServer()
		end)
	end
end

local function collectNearbyCurrency()
	local hrp = getHRP()
	if not hrp then
		return
	end
	local rem = remote("CurrencyCollect")
	if not rem then
		return
	end
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("BasePart") and (v.Name:lower():find("coin") or v.Name:lower():find("candy") or v.Name:lower():find("sugar")) then
			if (v.Position - hrp.Position).Magnitude < 80 then
				pcall(function()
					rem:FireServer(v)
				end)
			end
		end
	end
end

-- ── Feature loops ──────────────────────────────────────────────────────────
local flyConn, noclipConn, speedConn, jumpConn, antiVoidConn, godConn, autoRunConn
local lastSafePos

local function stopFly()
	if flyConn then
		flyConn:Disconnect()
		flyConn = nil
	end
	local hrp = getHRP()
	if hrp then
		for _, n in ipairs({ "SigmaFlyBV", "SigmaFlyBG" }) do
			local o = hrp:FindFirstChild(n)
			if o then
				o:Destroy()
			end
		end
	end
	local hum = getHum()
	if hum then
		hum.PlatformStand = false
	end
end

local function startFly()
	stopFly()
	local hrp = getHRP()
	if not hrp then
		return
	end
	local bv = Instance.new("BodyVelocity")
	bv.Name = "SigmaFlyBV"
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp
	local bg = Instance.new("BodyGyro")
	bg.Name = "SigmaFlyBG"
	bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bg.P = 1e4
	bg.D = 100
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp
	local hum = getHum()
	if hum then
		hum.PlatformStand = true
	end
	flyConn = RunService.Heartbeat:Connect(function()
		if not S.fly or not hrp.Parent then
			return
		end
		local cam = workspace.CurrentCamera
		local cf = cam.CFrame
		local vel = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then vel += cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then vel -= cf.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then vel -= cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then vel += cf.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel -= Vector3.yAxis end
		bv.Velocity = vel.Magnitude > 0 and vel.Unit * S.flySpeed or Vector3.zero
		bg.CFrame = CFrame.new(hrp.Position, hrp.Position + cf.LookVector)
	end)
end

local function stopNoclip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
end

local function startNoclip()
	stopNoclip()
	noclipConn = RunService.Stepped:Connect(function()
		if not S.noclip then
			return
		end
		local c = plr.Character
		if not c then
			return
		end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
	end)
end

local function ensureSpeedConn()
	if speedConn then
		return
	end
	speedConn = RunService.Heartbeat:Connect(function()
		local hum = getHum()
		if not hum then
			return
		end
		if S.speedHack and hum.WalkSpeed ~= S.speedVal then
			hum.WalkSpeed = S.speedVal
		end
		if S.jumpBoost and hum.JumpPower ~= S.jumpPower then
			hum.JumpPower = S.jumpPower
		end
	end)
end

local function ensureJumpConn()
	if jumpConn then
		return
	end
	jumpConn = UserInputService.JumpRequest:Connect(function()
		if S.infiniteJump then
			local hum = getHum()
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end)
end

local function ensureAntiVoidConn()
	if antiVoidConn then
		return
	end
	antiVoidConn = RunService.Heartbeat:Connect(function()
		if not S.antiVoid then
			return
		end
		local hrp = getHRP()
		if not hrp then
			return
		end
		if hrp.Position.Y > -50 and hrp.Position.Y < 2500 then
			lastSafePos = hrp.CFrame
		elseif lastSafePos then
			hrp.CFrame = lastSafePos
		else
			hrp.CFrame = CFrame.new(0, 10, 0)
		end
	end)
end

local function ensureGodConn()
	if godConn then
		return
	end
	godConn = RunService.Heartbeat:Connect(function()
		if not S.godMode then
			return
		end
		local hum = getHum()
		if hum and hum.Health < hum.MaxHealth then
			hum.Health = hum.MaxHealth
		end
	end)
end

local function ensureAutoRunConn()
	if autoRunConn then
		return
	end
	autoRunConn = RunService.Heartbeat:Connect(function()
		if not S.autoRun then
			return
		end
		local hum = getHum()
		local hrp = getHRP()
		if hum and hrp then
			hum:Move(Vector3.new(0, 0, -1), false)
		end
	end)
end

task.spawn(function()
	while S.running do
		if S.autoWin then
			pcall(doSingleWin)
			task.wait(math.max(0.5, S.autoWinDelay))
		elseif S.fullClear then
			for _, stageName in ipairs(STAGE_ORDER) do
				if not S.fullClear then
					break
				end
				local pos = findStagePos(stageName)
				if pos then
					tpTo(pos)
					log("Clearing → " .. stageName)
					task.wait(0.4)
				end
			end
			local wins = findWinBlocks()
			if wins[#wins] then
				tpTo(wins[#wins])
			end
			S.fullClear = false
			if UI.toggleRefresh then
				UI.toggleRefresh("fullClear")
			end
			log("Full obby clear done")
			setStatus("Obby cleared")
		elseif S.autoRebirth then
			pcall(tryRebirth)
			task.wait(3)
		elseif S.autoCollect then
			pcall(collectNearbyCurrency)
			task.wait(0.5)
		else
			task.wait(0.25)
		end
	end
end)

local function readStats()
	local ls = plr:FindFirstChild("leaderstats")
	local speed = ls and ls:FindFirstChild("Speed")
	local wins = ls and ls:FindFirstChild("Wins")
	local rebirths = ls and ls:FindFirstChild("Rebirths")
	return {
		speed = speed and tostring(speed.Value) or "?",
		wins = wins and tostring(wins.Value) or "?",
		rebirths = rebirths and tostring(rebirths.Value) or "?",
	}
end

-- ── GUI ────────────────────────────────────────────────────────────────────
local C = {
	bg = Color3.fromRGB(18, 10, 28),
	panel = Color3.fromRGB(28, 16, 42),
	sidebar = Color3.fromRGB(22, 12, 34),
	card = Color3.fromRGB(34, 20, 50),
	cardInner = Color3.fromRGB(42, 26, 58),
	accent = Color3.fromRGB(255, 120, 180),
	accent2 = Color3.fromRGB(255, 170, 90),
	border = Color3.fromRGB(255, 140, 200),
	text = Color3.fromRGB(255, 245, 250),
	muted = Color3.fromRGB(180, 150, 190),
	green = Color3.fromRGB(74, 222, 128),
	yellow = Color3.fromRGB(250, 204, 21),
	red = Color3.fromRGB(248, 113, 113),
	gold = Color3.fromRGB(255, 210, 90),
}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
end

local function stroke(inst, col, t, tr)
	local s = Instance.new("UIStroke")
	s.Color = col or C.border
	s.Thickness = t or 1
	s.Transparency = tr or 0.45
	s.Parent = inst
	return s
end

for _, n in ipairs({ "CandyEscape", "SigmaCandy" }) do
	local old = plr.PlayerGui:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

local GUI_ORDER = 999
local gui = Instance.new("ScreenGui")
gui.Name = "CandyEscape"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = GUI_ORDER
gui.Parent = plr:WaitForChild("PlayerGui")

local function ensureOnTop()
	local maxOrder = GUI_ORDER
	for _, sg in ipairs(plr.PlayerGui:GetChildren()) do
		if sg:IsA("ScreenGui") and sg ~= gui and sg.Enabled then
			maxOrder = math.max(maxOrder, sg.DisplayOrder + 1)
		end
	end
	gui.DisplayOrder = maxOrder
end
ensureOnTop()
plr.PlayerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		task.defer(ensureOnTop)
	end
end)

local glow = Instance.new("Frame")
glow.Size = UDim2.fromOffset(660, 520)
glow.Position = UDim2.fromScale(0.02, 0.08)
glow.BackgroundColor3 = C.accent
glow.BackgroundTransparency = 0.9
glow.BorderSizePixel = 0
glow.Parent = gui
corner(glow, 18)

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(640, 500)
root.Position = UDim2.fromScale(0.02, 0.08)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.Parent = gui
corner(root, 14)
stroke(root, C.border, 1.2, 0.35)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 18, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 8, 22)),
})
grad.Rotation = 145
grad.Parent = root

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = C.panel
header.BackgroundTransparency = 0.05
header.BorderSizePixel = 0
header.Parent = root
stroke(header, C.border, 1, 0.55)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.fromOffset(3, 20)
accentBar.Position = UDim2.fromOffset(10, 14)
accentBar.BackgroundColor3 = C.accent2
accentBar.BorderSizePixel = 0
accentBar.Parent = header
corner(accentBar, 2)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(0.72, 0, 0, 22)
title.Position = UDim2.fromOffset(20, 6)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = C.text
title.Text = "+1 Speed Keyboard Escape"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Size = UDim2.new(0.72, 0, 0, 16)
subtitle.Position = UDim2.fromOffset(20, 26)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = C.muted
subtitle.Text = "Candy & Chocolate · Sigma " .. CANDY_VERSION
subtitle.Parent = header

local function hdrBtn(text, color, xOff, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(24, 24)
	b.Position = UDim2.new(1, xOff, 0.5, -12)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(20, 20, 30)
	b.AutoButtonColor = true
	b.Parent = header
	corner(b, 12)
	b.MouseButton1Click:Connect(cb)
end

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -48)
body.Position = UDim2.fromOffset(0, 48)
body.BackgroundTransparency = 1
body.Parent = root

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.fromOffset(108, 1)
sidebar.Size = UDim2.new(0, 108, 1, -28)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BackgroundTransparency = 0.04
sidebar.BorderSizePixel = 0
sidebar.Parent = body
stroke(sidebar, C.border, 1, 0.65)

local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 10)
sidebarPad.PaddingLeft = UDim.new(0, 8)
sidebarPad.PaddingRight = UDim.new(0, 8)
sidebarPad.Parent = sidebar

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 6)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.Parent = sidebar

local mainArea = Instance.new("Frame")
mainArea.Size = UDim2.new(1, -108, 1, -28)
mainArea.Position = UDim2.fromOffset(108, 0)
mainArea.BackgroundTransparency = 1
mainArea.Parent = body

local pagesHost = Instance.new("Frame")
pagesHost.Size = UDim2.new(1, -16, 1, -8)
pagesHost.Position = UDim2.fromOffset(8, 8)
pagesHost.BackgroundTransparency = 1
pagesHost.ClipsDescendants = true
pagesHost.Parent = mainArea

local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, 0, 0, 28)
footer.Position = UDim2.new(0, 0, 1, -28)
footer.BackgroundColor3 = C.panel
footer.BackgroundTransparency = 0.1
footer.BorderSizePixel = 0
footer.Parent = body
stroke(footer, C.border, 1, 0.6)

UI.statusLabel = Instance.new("TextLabel")
UI.statusLabel.BackgroundTransparency = 1
UI.statusLabel.Size = UDim2.new(0.55, 0, 1, 0)
UI.statusLabel.Position = UDim2.fromOffset(10, 0)
UI.statusLabel.Font = Enum.Font.Gotham
UI.statusLabel.TextSize = 10
UI.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.statusLabel.TextColor3 = C.accent
UI.statusLabel.Text = "Ready"
UI.statusLabel.Parent = footer

local footerHint = Instance.new("TextLabel")
footerHint.BackgroundTransparency = 1
footerHint.Size = UDim2.new(0.4, -10, 1, 0)
footerHint.Position = UDim2.new(0.6, 0, 0, 0)
footerHint.Font = Enum.Font.Gotham
footerHint.TextSize = 10
footerHint.TextXAlignment = Enum.TextXAlignment.Right
footerHint.TextColor3 = C.muted
footerHint.Text = "] toggle GUI"
footerHint.Parent = footer

local pages = {}
local navItems = {}
local toggleStates = {}

local function makePage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = C.accent
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.fromOffset(0, 0)
	page.Visible = false
	page.Parent = pagesHost

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	return page
end

local function sectionCard(parent, titleText, emoji)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.BackgroundTransparency = 1
	wrap.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = wrap

	local head = Instance.new("TextLabel")
	head.LayoutOrder = 0
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 18)
	head.Font = Enum.Font.GothamBold
	head.TextSize = 11
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextColor3 = C.accent2
	head.Text = (emoji or "") .. "  " .. string.upper(titleText)
	head.Parent = wrap

	local inner = Instance.new("Frame")
	inner.LayoutOrder = 1
	inner.Size = UDim2.new(1, 0, 0, 0)
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.BackgroundColor3 = C.card
	inner.BorderSizePixel = 0
	inner.Parent = wrap
	corner(inner, 10)
	stroke(inner, C.border, 1, 0.55)

	local innerPad = Instance.new("UIPadding")
	innerPad.PaddingTop = UDim.new(0, 8)
	innerPad.PaddingBottom = UDim.new(0, 8)
	innerPad.PaddingLeft = UDim.new(0, 10)
	innerPad.PaddingRight = UDim.new(0, 10)
	innerPad.Parent = inner

	local innerList = Instance.new("UIListLayout")
	innerList.Padding = UDim.new(0, 8)
	innerList.SortOrder = Enum.SortOrder.LayoutOrder
	innerList.Parent = inner

	return inner
end

local function refreshToggle(key)
	local t = toggleStates[key]
	if not t then
		return
	end
	local on = S[key] == true
	TweenService:Create(t.pill, TweenInfo.new(0.15), {
		BackgroundColor3 = on and C.green or Color3.fromRGB(55, 38, 72),
	}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.15), {
		Position = on and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
	}):Play()
end

UI.toggleRefresh = refreshToggle

local function makeToggle(parent, labelText, descText, key, emoji)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundColor3 = C.cardInner
	row.Text = ""
	row.AutoButtonColor = false
	row.Parent = parent
	corner(row, 8)

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(24, 46)
	icon.Font = Enum.Font.Gotham
	icon.TextSize = 16
	icon.Text = emoji or "⚡"
	icon.Parent = row

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -90, 0, 18)
	lbl.Position = UDim2.fromOffset(28, 6)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextColor3 = C.text
	lbl.Text = labelText
	lbl.Parent = row

	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Size = UDim2.new(1, -90, 0, 14)
	desc.Position = UDim2.fromOffset(28, 24)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 10
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextColor3 = C.muted
	desc.Text = descText or ""
	desc.Parent = row

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(46, 24)
	pill.Position = UDim2.new(1, -54, 0.5, -12)
	pill.BackgroundColor3 = S[key] and C.green or Color3.fromRGB(55, 38, 72)
	pill.BorderSizePixel = 0
	pill.Parent = row
	corner(pill, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = S[key] and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = pill
	corner(knob, 9)

	toggleStates[key] = { pill = pill, knob = knob }

	local function flip()
		local v = not S[key]
		S[key] = v
		refreshToggle(key)
		if key == "speedHack" or key == "jumpBoost" then
			ensureSpeedConn()
			log(labelText .. " " .. (v and "ON" or "OFF"))
		elseif key == "fly" then
			if v then startFly() else stopFly() end
			log(labelText .. " " .. (v and "ON" or "OFF"))
		elseif key == "noclip" then
			if v then startNoclip() else stopNoclip() end
			log(labelText .. " " .. (v and "ON" or "OFF"))
		elseif key == "infiniteJump" then
			if v then ensureJumpConn() end
			log(labelText .. " " .. (v and "ON" or "OFF"))
		elseif key == "antiVoid" then
			if v then ensureAntiVoidConn() end
			log(labelText .. " " .. (v and "ON" or "OFF"))
		elseif key == "godMode" then
			if v then ensureGodConn() end
			log(labelText .. " " .. (v and "ON" or "OFF"))
		elseif key == "autoRun" then
			if v then ensureAutoRunConn() end
			log(labelText .. " " .. (v and "ON" or "OFF"))
		else
			log(labelText .. " " .. (v and "ON" or "OFF"))
		end
		setStatus(labelText .. (v and " enabled" or " disabled"))
	end

	row.MouseButton1Click:Connect(flip)
	return row
end

local function makeSlider(parent, labelText, minV, maxV, getter, setter, fmt)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 52)
	card.BackgroundColor3 = C.cardInner
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card, 8)

	local valLbl = Instance.new("TextLabel")
	valLbl.BackgroundTransparency = 1
	valLbl.Size = UDim2.new(1, -16, 0, 18)
	valLbl.Position = UDim2.fromOffset(10, 6)
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextSize = 11
	valLbl.TextXAlignment = Enum.TextXAlignment.Left
	valLbl.TextColor3 = C.text
	valLbl.Text = labelText .. ": " .. (fmt and fmt(getter()) or getter())
	valLbl.Parent = card

	local track = Instance.new("TextButton")
	track.Size = UDim2.new(1, -20, 0, 10)
	track.Position = UDim2.fromOffset(10, 30)
	track.BackgroundColor3 = Color3.fromRGB(55, 38, 72)
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = card
	corner(track, 5)

	local fill = Instance.new("Frame")
	local pct = (getter() - minV) / (maxV - minV)
	fill.Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1)
	fill.BackgroundColor3 = C.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 5)

	local dragging = false
	local function applyAt(x)
		local abs = track.AbsolutePosition
		local sz = track.AbsoluteSize
		local rel = math.clamp((x - abs.X) / sz.X, 0, 1)
		local val = minV + rel * (maxV - minV)
		setter(val)
		fill.Size = UDim2.fromScale(rel, 1)
		valLbl.Text = labelText .. ": " .. (fmt and fmt(val) or math.floor(val))
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			applyAt(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			applyAt(input.Position.X)
		end
	end)
end

local function makeActionBtn(parent, text, color, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = C.text
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	stroke(b, C.border, 1, 0.45)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function makeNavBtn(text, pageName)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = C.card
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.TextColor3 = C.muted
	b.AutoButtonColor = false
	b.Parent = sidebar
	corner(b, 8)
	navItems[pageName] = b
	b.MouseButton1Click:Connect(function()
		for name, page in pages do
			page.Visible = name == pageName
		end
		for name, btn in navItems do
			btn.BackgroundColor3 = name == pageName and C.accent or C.card
			btn.TextColor3 = name == pageName and Color3.fromRGB(20, 10, 30) or C.muted
		end
	end)
end

-- Pages
pages.main = makePage("Main")
pages.move = makePage("Move")
pages.auto = makePage("Auto")
pages.tp = makePage("TP")

makeNavBtn("Main", "main")
makeNavBtn("Move", "move")
makeNavBtn("Auto", "auto")
makeNavBtn("TP", "tp")

-- MAIN tab
local statsCard = sectionCard(pages.main, "Live Stats", "📊")
local stats = readStats()
UI.speedStat = Instance.new("TextLabel")
UI.speedStat.BackgroundTransparency = 1
UI.speedStat.Size = UDim2.new(1, 0, 0, 18)
UI.speedStat.Font = Enum.Font.GothamBold
UI.speedStat.TextSize = 12
UI.speedStat.TextXAlignment = Enum.TextXAlignment.Left
UI.speedStat.TextColor3 = C.gold
UI.speedStat.Text = "Speed: " .. stats.speed
UI.speedStat.Parent = statsCard

UI.winsStat = Instance.new("TextLabel")
UI.winsStat.BackgroundTransparency = 1
UI.winsStat.Size = UDim2.new(1, 0, 0, 18)
UI.winsStat.Font = Enum.Font.Gotham
UI.winsStat.TextSize = 11
UI.winsStat.TextXAlignment = Enum.TextXAlignment.Left
UI.winsStat.TextColor3 = C.text
UI.winsStat.Text = "Wins: " .. stats.wins
UI.winsStat.Parent = statsCard

UI.rebirthStat = Instance.new("TextLabel")
UI.rebirthStat.BackgroundTransparency = 1
UI.rebirthStat.Size = UDim2.new(1, 0, 0, 18)
UI.rebirthStat.Font = Enum.Font.Gotham
UI.rebirthStat.TextSize = 11
UI.rebirthStat.TextXAlignment = Enum.TextXAlignment.Left
UI.rebirthStat.TextColor3 = C.text
UI.rebirthStat.Text = "Rebirths: " .. stats.rebirths
UI.rebirthStat.Parent = statsCard

local quickCard = sectionCard(pages.main, "Quick Actions", "⚡")
makeActionBtn(quickCard, "🏆  Instant Win", C.accent, function()
	doInstantWin()
end)
makeActionBtn(quickCard, "🚀  TP to End", Color3.fromRGB(90, 50, 130), function()
	tpToLastStage()
end)
makeActionBtn(quickCard, "✅  Enable All Movement", Color3.fromRGB(50, 120, 90), function()
	for _, k in ipairs({ "speedHack", "infiniteJump", "antiVoid", "noclip" }) do
		S[k] = true
		refreshToggle(k)
	end
	ensureSpeedConn()
	ensureJumpConn()
	ensureAntiVoidConn()
	startNoclip()
	log("Enabled all movement")
	setStatus("All movement ON")
end)

local logCard = sectionCard(pages.main, "Log", "📝")
UI.logFrame = Instance.new("Frame")
UI.logFrame.Size = UDim2.new(1, 0, 0, 120)
UI.logFrame.BackgroundColor3 = Color3.fromRGB(10, 6, 16)
UI.logFrame.BorderSizePixel = 0
UI.logFrame.Parent = logCard
corner(UI.logFrame, 6)
local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 1)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = UI.logFrame

-- MOVE tab
local moveCard = sectionCard(pages.move, "Movement", "🏃")
makeToggle(moveCard, "Speed Hack", "Bypass speed cap — no gamepass needed", "speedHack", "⚡")
makeSlider(moveCard, "Walk Speed", 16, 3000,
	function() return S.speedVal end,
	function(v) S.speedVal = math.floor(v) end,
	function(v) return tostring(math.floor(v)) end)
makeToggle(moveCard, "Jump Boost", "Higher jump power", "jumpBoost", "🦘")
makeSlider(moveCard, "Jump Power", 50, 500,
	function() return S.jumpPower end,
	function(v) S.jumpPower = math.floor(v) end,
	function(v) return tostring(math.floor(v)) end)
makeToggle(moveCard, "Fly", "WASD + Space/Shift", "fly", "🕊")
makeSlider(moveCard, "Fly Speed", 20, 300,
	function() return S.flySpeed end,
	function(v) S.flySpeed = math.floor(v) end,
	function(v) return tostring(math.floor(v)) end)
makeToggle(moveCard, "Noclip", "Walk through walls", "noclip", "👻")
makeToggle(moveCard, "Infinite Jump", "Jump in mid-air", "infiniteJump", "⬆")
makeToggle(moveCard, "Anti-Void", "Rescue if you fall", "antiVoid", "🛡")
makeToggle(moveCard, "God Mode", "Keep health full", "godMode", "❤")
makeToggle(moveCard, "Auto Run", "Always run forward (+1 speed)", "autoRun", "🏃")

-- AUTO tab
local autoCard = sectionCard(pages.auto, "Automation", "🤖")
makeToggle(autoCard, "Auto-Win Farm", "Farm wins via WinBlock TP loop", "autoWin", "🏆")
makeSlider(autoCard, "Win Delay (sec)", 0.5, 5,
	function() return S.autoWinDelay end,
	function(v) S.autoWinDelay = v end,
	function(v) return string.format("%.1f", v) end)
makeToggle(autoCard, "Auto-Rebirth", "Rebirth when possible", "autoRebirth", "♻")
makeToggle(autoCard, "Auto Collect", "Collect nearby candy/coins", "autoCollect", "🍬")
makeToggle(autoCard, "Full Obby Clear", "TP through every stage to end", "fullClear", "🗺")

-- TP tab
local tpCard = sectionCard(pages.tp, "Teleport", "📍")
makeActionBtn(tpCard, "⚡  TP to Last Stage", C.accent2, tpToLastStage)
makeActionBtn(tpCard, "🏠  TP to HUB", C.cardInner, function()
	tpToStage(1)
end)
makeActionBtn(tpCard, "📌  Checkpoint Stage 2", C.cardInner, function()
	tpCheckpoint("Stage2")
end)
makeActionBtn(tpCard, "📌  Checkpoint Stage 3", C.cardInner, function()
	tpCheckpoint("Stage3")
end)

local stageGrid = Instance.new("Frame")
stageGrid.Size = UDim2.new(1, 0, 0, 0)
stageGrid.AutomaticSize = Enum.AutomaticSize.Y
stageGrid.BackgroundTransparency = 1
stageGrid.Parent = tpCard

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(96, 32)
grid.CellPadding = UDim2.fromOffset(6, 6)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = stageGrid

for i, entry in ipairs(STAGE_SPAWNS) do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = C.cardInner
	b.Text = entry.name
	b.Font = Enum.Font.GothamBold
	b.TextSize = 10
	b.TextColor3 = C.text
	b.AutoButtonColor = true
	b.Parent = stageGrid
	corner(b, 6)
	b.MouseButton1Click:Connect(function()
		tpToStage(i)
	end)
end

for _, stageName in ipairs({ "Stage4", "Stage5", "Stage6", "Stage7", "Stage8", "Stage9", "Stage10" }) do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = C.cardInner
	b.Text = stageName
	b.Font = Enum.Font.GothamBold
	b.TextSize = 10
	b.TextColor3 = C.text
	b.AutoButtonColor = true
	b.Parent = stageGrid
	corner(b, 6)
	b.MouseButton1Click:Connect(function()
		local pos = findStagePos(stageName)
		if pos then
			tpTo(pos)
			log("TP → " .. stageName)
		else
			setStatus("Stage not found: " .. stageName, C.red)
		end
	end)
end

-- Show default page
for name, page in pages do
	page.Visible = name == "main"
end
navItems.main.BackgroundColor3 = C.accent
navItems.main.TextColor3 = Color3.fromRGB(20, 10, 30)

-- Header buttons
local minimized = false
hdrBtn("−", C.yellow, -58, function()
	minimized = not minimized
	body.Visible = not minimized
	root.Size = minimized and UDim2.fromOffset(640, 48) or UDim2.fromOffset(640, 500)
	glow.Size = minimized and UDim2.fromOffset(660, 68) or UDim2.fromOffset(660, 520)
end)
hdrBtn("×", C.red, -30, function()
	S.running = false
	stopFly()
	stopNoclip()
	if speedConn then speedConn:Disconnect() end
	if jumpConn then jumpConn:Disconnect() end
	if antiVoidConn then antiVoidConn:Disconnect() end
	if godConn then godConn:Disconnect() end
	if autoRunConn then autoRunConn:Disconnect() end
	gui:Destroy()
end)

-- Drag
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = root.Position
	end
end)
header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local d = input.Position - dragStart
		local p = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		root.Position = p
		glow.Position = p
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightBracket then
		gui.Enabled = not gui.Enabled
	end
end)

task.spawn(function()
	while S.running and gui.Parent do
		local s = readStats()
		if UI.speedStat then UI.speedStat.Text = "Speed: " .. s.speed end
		if UI.winsStat then UI.winsStat.Text = "Wins: " .. s.wins end
		if UI.rebirthStat then UI.rebirthStat.Text = "Rebirths: " .. s.rebirths end
		if getgenv().SigmaStopRequested then
			S.running = false
			pcall(function() gui:Destroy() end)
			break
		end
		task.wait(1)
	end
end)

log("Loaded " .. CANDY_VERSION)
log("Use tabs: Main · Move · Auto · TP")
setStatus("Ready — pick a tab")
]=],
}

local EMBEDDED_ICON_BASE64 = ""

-- Official Sell Lemons thumbnail (rbxcdn — works on ImageLabel without HttpGet)
local SELL_LEMONS_PLACE_ID = 79268393072444
local SELL_LEMONS_UNIVERSE_ID = 7395930870
local SELL_LEMONS_ICON_URL =
	"https://tr.rbxcdn.com/180DAY-3d8fd895f358e86fb886c17fe06201d8/256/256/Image/Png/noFilter"

local CANDY_ESCAPE_PLACE_ID = 95082159892680
local CANDY_ESCAPE_UNIVERSE_ID = 9584852943
local CANDY_ESCAPE_ICON_URL =
	"https://tr.rbxcdn.com/180DAY-207e9d6ae7e65d6db5ce5963e2c68d61/256/256/Image/Png/noFilter"

local GAMES = {
	{
		id = "sell_lemons",
		name = "Sell Lemons",
		subtitle = "Tycoon · Farm · Minigames",
		keywords = { "sell", "lemon", "lemons", "tycoon", "farm", "fruit" },
		placeIds = { SELL_LEMONS_PLACE_ID },
		status = "working",
		placeId = SELL_LEMONS_PLACE_ID,
		universeId = SELL_LEMONS_UNIVERSE_ID,
		iconUrl = SELL_LEMONS_ICON_URL,
		iconPath = "assets/sell_lemons_icon.png",
		file = "sell_lemons.lua",
		embeddedIcon = true,
	},
	{
		id = "candy_escape",
		name = "[UPD] +1 Speed Keyboard Escape | Candy & Chocolate",
		subtitle = "Speed · Wins · Rebirth · Auto-farm",
		keywords = { "candy", "chocolate", "escape", "keyboard", "speed", "obby", "treadmill", "upd" },
		placeIds = { CANDY_ESCAPE_PLACE_ID },
		status = "working",
		placeId = CANDY_ESCAPE_PLACE_ID,
		universeId = CANDY_ESCAPE_UNIVERSE_ID,
		iconUrl = CANDY_ESCAPE_ICON_URL,
		iconPath = "assets/candy_escape_icon.png",
		file = "candy_escape.lua",
		iconFallback = "🍬",
	},
}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
end

local function stroke(inst, color, t, tr)
	local s = Instance.new("UIStroke")
	s.Color = color or C.accent
	s.Thickness = t or 1
	s.Transparency = tr or 0.55
	s.Parent = inst
	return s
end

local function statusColor(status)
	if status == "working" then
		return C.green
	elseif status == "partial" then
		return C.yellow
	end
	return C.red
end

local function gameWorksHere(entry)
	for _, id in entry.placeIds do
		if game.PlaceId == id then
			return true
		end
	end
	return false
end

local function tryReadfile(filename)
	if not readfile then
		return nil
	end
	local paths = {
		filename,
		"./" .. filename,
		"../" .. filename,
		"roblox-executor-mcp-main/" .. filename,
		"C:\\Users\\Krish\\Desktop\\roblox-executor-mcp-main\\" .. filename,
	}
	for _, p in paths do
		local ok, src = pcall(readfile, p)
		if ok and type(src) == "string" and #src > 0 then
			return src
		end
	end
	return nil
end

local function loadGameModule(entry)
	local src = EMBEDDED[entry.id]
	if type(src) == "string" and #src > 0 then
		local fn, err = loadstring(src, entry.file)
		if fn then
			return fn
		end
		error("compile bundled: " .. tostring(err))
	end

	src = tryReadfile(entry.file)
	if src then
		local fn, err = loadstring(src, entry.file)
		if fn then
			return fn
		end
		error("compile file: " .. tostring(err))
	end

	error("Game script missing — re-run bundle or keep " .. entry.file .. " with sigma_hub.lua")
end

local function cleanupSigmaScripts()
	getgenv().SigmaStopRequested = true
	pcall(function()
		local pg = plr:FindFirstChild("PlayerGui")
		if not pg then
			return
		end
		for _, name in ipairs({ "SellLemons", "SigmaHub", "LemonHub", "DestineHub" }) do
			local old = pg:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end)
	getgenv().SigmaScriptsRunning = nil
end

if getgenv().SigmaScriptsRunning then
	cleanupSigmaScripts()
	task.wait(0.05)
end

getgenv().SigmaStopRequested = false

getgenv().SigmaScriptsRunning = true

local function decodeBase64(data)
	if type(data) ~= "string" or #data == 0 then
		return nil
	end

	local ok, bytes = pcall(function()
		return HttpService:Base64Decode(data)
	end)
	if ok and type(bytes) == "string" and #bytes > 0 then
		return bytes
	end

	ok, bytes = pcall(function()
		if base64 and base64.decode then
			return base64.decode(data)
		end
	end)
	if ok and type(bytes) == "string" and #bytes > 0 then
		return bytes
	end

	ok, bytes = pcall(function()
		if crypt and crypt.base64 and crypt.base64.decode then
			return crypt.base64.decode(data)
		end
	end)
	if ok and type(bytes) == "string" and #bytes > 0 then
		return bytes
	end

	return nil
end

local function tryCustomAssetIcon(entry)
	if not getcustomasset then
		return nil
	end
	local candidates = {}
	local function add(path)
		if type(path) == "string" and #path > 0 then
			table.insert(candidates, path)
		end
	end

	add(entry.iconPath)
	if entry.iconPath then
		add("./" .. entry.iconPath)
		add("../" .. entry.iconPath)
		add("roblox-executor-mcp-main/" .. entry.iconPath)
		add("roblox-executor-mcp-main\\" .. entry.iconPath:gsub("/", "\\"))
		add("C:\\Users\\Krish\\Desktop\\roblox-executor-mcp-main\\" .. entry.iconPath:gsub("/", "\\"))
		add("C:/Users/Krish/Desktop/roblox-executor-mcp-main/" .. entry.iconPath)
	end

	if entry.id == "sell_lemons" then
		add("sigma_hub_sell_lemons_icon.png")
		add("./sigma_hub_sell_lemons_icon.png")
	elseif entry.id == "candy_escape" then
		add("sigma_hub_candy_escape_icon.png")
		add("./sigma_hub_candy_escape_icon.png")
	end

	for _, p in candidates do
		local ok, asset = pcall(getcustomasset, p)
		if ok and type(asset) == "string" and #asset > 0 then
			return asset, "getcustomasset:" .. p
		end
	end
	return nil
end

local embeddedIconAssets = {}

local function tryEmbeddedIcon(entry)
	if entry and entry.embeddedIcon ~= true then
		return nil
	end
	if entry and entry.id and embeddedIconAssets[entry.id] then
		return embeddedIconAssets[entry.id], "embedded-cache"
	end
	if type(EMBEDDED_ICON_BASE64) ~= "string" or #EMBEDDED_ICON_BASE64 < 32 then
		return nil
	end
	if not writefile or not getcustomasset then
		return nil
	end

	local bytes = decodeBase64(EMBEDDED_ICON_BASE64)
	if type(bytes) ~= "string" or #bytes == 0 then
		return nil
	end

	local writeNames = {
		"sigma_hub_sell_lemons_icon.png",
		"assets/sell_lemons_icon.png",
		"./sigma_hub_sell_lemons_icon.png",
	}
	for _, iconFile in writeNames do
		local okW = pcall(writefile, iconFile, bytes)
		if okW then
			local okA, asset = pcall(getcustomasset, iconFile)
			if okA and type(asset) == "string" and #asset > 0 then
				if entry and entry.id then
					embeddedIconAssets[entry.id] = asset
				end
				return asset, "embedded-base64"
			end
		end
	end
	return nil
end

local function tryHttpDownloadIcon(imageUrl, cacheKey)
	if not writefile or not getcustomasset then
		return nil
	end

	local body
	local okGet = pcall(function()
		if http and http.request then
			local res = http.request({ Url = imageUrl, Method = "GET" })
			if res and res.Body and #res.Body > 0 then
				body = res.Body
			end
		elseif HttpService.HttpEnabled then
			body = HttpService:GetAsync(imageUrl)
		end
	end)
	if not okGet or type(body) ~= "string" or #body == 0 then
		return nil
	end

	local iconFile = "sigma_hub_downloaded_icon_" .. tostring(cacheKey or "default") .. ".png"
	local okW = pcall(writefile, iconFile, body)
	if not okW then
		return nil
	end

	local okA, asset = pcall(getcustomasset, iconFile)
	if okA and type(asset) == "string" and #asset > 0 then
		return asset, "http-download"
	end
	return nil
end

local function tryRobloxIconUrl(entry)
	if type(entry.iconUrl) == "string" and #entry.iconUrl > 0 then
		return entry.iconUrl
	end

	local function fetchThumbnailJson(url)
		local body
		if http and http.request then
			local res = http.request({ Url = url, Method = "GET" })
			body = res and res.Body
		elseif HttpService.HttpEnabled then
			body = HttpService:GetAsync(url)
		end
		if not body then
			return nil
		end
		return HttpService:JSONDecode(body)
	end

	local function pickThumbnailUrl(data)
		if data and data.data and data.data[1] and data.data[1].imageUrl then
			return data.data[1].imageUrl
		end
		return nil
	end

	if not HttpService.HttpEnabled and not (http and http.request) then
		return nil
	end

	local placeId = entry.placeId
	if not placeId then
		return nil
	end
	local imageUrl = nil

	local ok1 = pcall(function()
		local url = ("https://thumbnails.roblox.com/v1/places/gameicons?placeIds=%d&size=256x256&format=Png&isCircular=false"):format(
			placeId
		)
		imageUrl = pickThumbnailUrl(fetchThumbnailJson(url))
	end)
	if ok1 and imageUrl then
		return imageUrl
	end

	local universeIds = {}
	if entry.universeId and entry.universeId > 0 then
		table.insert(universeIds, entry.universeId)
	end
	if game.GameId and game.GameId > 0 and gameWorksHere(entry) then
		table.insert(universeIds, game.GameId)
	end

	for _, universeId in universeIds do
		local ok2 = pcall(function()
			local url = ("https://thumbnails.roblox.com/v1/games/icons?universeIds=%d&size=256x256&format=Png&isCircular=false"):format(
				universeId
			)
			imageUrl = pickThumbnailUrl(fetchThumbnailJson(url))
		end)
		if ok2 and imageUrl then
			return imageUrl
		end

		local ok3 = pcall(function()
			local url = ("https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=%d&countPerUniverse=1&defaults=true&size=256x256&format=Png"):format(
				universeId
			)
			imageUrl = pickThumbnailUrl(fetchThumbnailJson(url))
		end)
		if ok3 and imageUrl then
			return imageUrl
		end
	end

	return nil
end

local function applyIcon(iconLabel, fallbackLabel, image, statusLabel, method)
	iconLabel.Image = image
	local isCustomAsset = type(image) == "string" and string.find(image, "rbxasset://", 1, true) == 1
	fallbackLabel.Visible = not isCustomAsset
	if statusLabel then
		statusLabel.Text = "Icon: " .. method
		statusLabel.TextColor3 = C.muted
		task.delay(3, function()
			if statusLabel.Text == "Icon: " .. method then
				statusLabel.Text = ""
			end
		end)
	end
	if not isCustomAsset then
		task.delay(2, function()
			if iconLabel.Image == image and iconLabel.Image == "" then
				fallbackLabel.Visible = true
			end
		end)
	end
end

local function fetchGameIcon(iconLabel, fallbackLabel, entry, statusLabel)
	fallbackLabel.Visible = true
	iconLabel.Image = ""

	task.spawn(function()
		local asset, method = tryEmbeddedIcon(entry)
		if asset then
			applyIcon(iconLabel, fallbackLabel, asset, statusLabel, method)
			return
		end

		asset, method = tryCustomAssetIcon(entry)
		if asset then
			applyIcon(iconLabel, fallbackLabel, asset, statusLabel, method)
			return
		end

		local thumbUrl = tryRobloxIconUrl(entry)
		if thumbUrl then
			asset, method = tryHttpDownloadIcon(thumbUrl, entry.id)
			if asset then
				applyIcon(iconLabel, fallbackLabel, asset, statusLabel, method)
				return
			end
		end

		if thumbUrl then
			applyIcon(iconLabel, fallbackLabel, thumbUrl, statusLabel, "rbxcdn-url")
			return
		end

		iconLabel.Image = ""
		fallbackLabel.Visible = true
		if statusLabel then
			statusLabel.Text = "Icon: emoji fallback (all methods failed)"
			statusLabel.TextColor3 = C.yellow
		end
	end)
end

for _, n in ipairs({ "SigmaHub", "LemonHub", "DestineHub" }) do
	local old = plr.PlayerGui:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "SigmaHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = plr:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(520, 420)
root.Position = UDim2.fromScale(0.5, 0.5)
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.BackgroundColor3 = C.bg
root.BorderSizePixel = 0
root.Parent = gui
corner(root, 14)
stroke(root, C.accent2, 1.2, 0.45)

local splash = Instance.new("Frame")
splash.Size = UDim2.fromScale(1, 1)
splash.BackgroundColor3 = C.bg
splash.BorderSizePixel = 0
splash.ZIndex = 10
splash.Parent = root
corner(splash, 14)

local splashTitle = Instance.new("TextLabel")
splashTitle.BackgroundTransparency = 1
splashTitle.Size = UDim2.new(1, 0, 0, 80)
splashTitle.Position = UDim2.fromScale(0, 0.38)
splashTitle.Font = Enum.Font.GothamBlack
splashTitle.TextSize = 42
splashTitle.TextColor3 = C.text
splashTitle.Text = "Sigma Scripts"
splashTitle.Parent = splash

local splashSub = Instance.new("TextLabel")
splashSub.BackgroundTransparency = 1
splashSub.Size = UDim2.new(1, 0, 0, 24)
splashSub.Position = UDim2.new(0, 0, 1, -36)
splashSub.Font = Enum.Font.GothamMedium
splashSub.TextSize = 14
splashSub.TextColor3 = C.muted
splashSub.Text = "by ghoul"
splashSub.Parent = splash

local picker = Instance.new("Frame")
picker.Size = UDim2.fromScale(1, 1)
picker.BackgroundTransparency = 1
picker.Visible = false
picker.Parent = root

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = C.panel
header.BackgroundTransparency = 0.1
header.BorderSizePixel = 0
header.Parent = picker

local hubTitle = Instance.new("TextLabel")
hubTitle.BackgroundTransparency = 1
hubTitle.Size = UDim2.new(0.55, 0, 1, 0)
hubTitle.Position = UDim2.fromOffset(14, 0)
hubTitle.Font = Enum.Font.GothamBold
hubTitle.TextSize = 18
hubTitle.TextXAlignment = Enum.TextXAlignment.Left
hubTitle.TextColor3 = C.text
hubTitle.Text = "Sigma Scripts"
hubTitle.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -36, 0.5, -13)
closeBtn.BackgroundColor3 = C.red
closeBtn.Text = "×"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header
corner(closeBtn, 13)

local statusMsg = Instance.new("TextLabel")
statusMsg.BackgroundTransparency = 1
statusMsg.Size = UDim2.new(1, -50, 0, 16)
statusMsg.Position = UDim2.new(0, 12, 0, 52)
statusMsg.Font = Enum.Font.Gotham
statusMsg.TextSize = 11
statusMsg.TextXAlignment = Enum.TextXAlignment.Left
statusMsg.TextColor3 = C.red
statusMsg.Text = ""
statusMsg.Parent = picker

local searchWrap = Instance.new("Frame")
searchWrap.Size = UDim2.new(1, -24, 0, 34)
searchWrap.Position = UDim2.fromOffset(12, 72)
searchWrap.BackgroundColor3 = C.card
searchWrap.BorderSizePixel = 0
searchWrap.Parent = picker
corner(searchWrap, 10)
stroke(searchWrap, C.accent, 0.8, 0.65)

local searchBox = Instance.new("TextBox")
searchBox.BackgroundTransparency = 1
searchBox.Size = UDim2.new(1, -16, 1, 0)
searchBox.Position = UDim2.fromOffset(12, 0)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.PlaceholderText = "Search games..."
searchBox.PlaceholderColor3 = C.muted
searchBox.TextColor3 = C.text
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchWrap

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -24, 1, -118)
list.Position = UDim2.fromOffset(12, 114)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = C.accent
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.fromOffset(0, 0)
list.Parent = picker

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local noResults = Instance.new("TextLabel")
noResults.Name = "NoResults"
noResults.BackgroundTransparency = 1
noResults.Size = UDim2.new(1, -24, 0, 56)
noResults.Position = UDim2.fromOffset(12, 114)
noResults.Font = Enum.Font.GothamMedium
noResults.TextSize = 14
noResults.TextColor3 = C.muted
noResults.TextWrapped = true
noResults.Text = "Unavailable — no games match your search"
noResults.Visible = false
noResults.ZIndex = 2
noResults.Parent = picker

local gameCards = {}

local function trimQuery(raw)
	if type(raw) ~= "string" then
		return ""
	end
	return string.lower(string.gsub(raw, "^%s*(.-)%s*$", "%1"))
end

local function matchesQuery(entry, query)
	if query == "" then
		return true
	end
	if string.find(string.lower(entry.name or ""), query, 1, true) then
		return true
	end
	if entry.subtitle and string.find(string.lower(entry.subtitle), query, 1, true) then
		return true
	end
	if entry.id and string.find(string.lower(entry.id), query, 1, true) then
		return true
	end
	if entry.placeId and string.find(tostring(entry.placeId), query, 1, true) then
		return true
	end
	if entry.placeIds then
		for _, pid in entry.placeIds do
			if string.find(tostring(pid), query, 1, true) then
				return true
			end
		end
	end
	if entry.keywords then
		for _, kw in entry.keywords do
			if string.find(string.lower(kw), query, 1, true) then
				return true
			end
		end
	end
	return false
end

local function renderGames(query)
	query = trimQuery(query)
	local visibleCount = 0
	for _, card in ipairs(gameCards) do
		local match = matchesQuery(card.entry, query)
		card.frame.Visible = match
		if match then
			visibleCount += 1
		end
	end

	local hasQuery = query ~= ""
	local showEmpty = hasQuery and visibleCount == 0
	noResults.Visible = showEmpty
	list.Visible = not showEmpty
end

local hubActive = true

local function launchGame(entry, cardSub)
	if not gameWorksHere(entry) then
		cardSub.Text = "Join " .. entry.name .. " first, then click again"
		cardSub.TextColor3 = C.red
		statusMsg.Text = "Wrong game — PlaceId " .. tostring(game.PlaceId)
		return
	end

	statusMsg.Text = "Loading " .. entry.name .. "..."
	statusMsg.TextColor3 = C.muted

	local ok, fnOrErr = pcall(loadGameModule, entry)
	if not ok then
		statusMsg.Text = tostring(fnOrErr)
		statusMsg.TextColor3 = C.red
		cardSub.Text = "Load failed — see error above"
		cardSub.TextColor3 = C.red
		return
	end

	hubActive = false
	gui:Destroy()
	local runOk, runErr = pcall(fnOrErr)
	if not runOk then
		warn("[Sigma Scripts] " .. entry.name .. " error: " .. tostring(runErr))
	end
end

for _, entry in GAMES do
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(1, 0, 0, 88)
	card.BackgroundColor3 = C.card
	card.Text = ""
	card.AutoButtonColor = false
	card.Parent = list
	corner(card, 12)
	stroke(card, C.accent, 0.9, 0.7)

	local iconWrap = Instance.new("Frame")
	iconWrap.Size = UDim2.fromOffset(56, 56)
	iconWrap.Position = UDim2.fromOffset(10, 8)
	iconWrap.BackgroundColor3 = C.panel
	iconWrap.ClipsDescendants = true
	iconWrap.Parent = card
	corner(iconWrap, 10)

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Crop
	icon.Parent = iconWrap

	local iconFallback = Instance.new("TextLabel")
	iconFallback.Size = UDim2.fromScale(1, 1)
	iconFallback.BackgroundTransparency = 1
	iconFallback.Font = Enum.Font.GothamBold
	iconFallback.TextSize = 28
	iconFallback.Text = entry.iconFallback or "🍋"
	iconFallback.Visible = false
	iconFallback.Parent = iconWrap

	fetchGameIcon(icon, iconFallback, entry, statusMsg)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -130, 0, 40)
	name.Position = UDim2.fromOffset(76, 10)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 12
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.TextWrapped = true
	name.TextColor3 = C.text
	name.Text = entry.name
	name.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -130, 0, 28)
	sub.Position = UDim2.fromOffset(76, 50)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextYAlignment = Enum.TextYAlignment.Top
	sub.TextWrapped = true
	sub.TextColor3 = C.muted
	sub.Text = entry.subtitle or ""
	sub.Parent = card

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(14, 14)
	dot.Position = UDim2.new(1, -24, 0.5, -7)
	dot.BackgroundColor3 = gameWorksHere(entry) and statusColor(entry.status) or C.yellow
	dot.BorderSizePixel = 0
	dot.Parent = card
	corner(dot, 7)
	stroke(dot, Color3.new(1, 1, 1), 1, 0.6)

	card.MouseEnter:Connect(function()
		card.BackgroundColor3 = Color3.fromRGB(32, 22, 54)
	end)
	card.MouseLeave:Connect(function()
		card.BackgroundColor3 = C.card
	end)
	card.MouseButton1Click:Connect(function()
		launchGame(entry, sub)
	end)

	table.insert(gameCards, { frame = card, entry = entry })
end

renderGames("")

local function onSearchChanged()
	renderGames(searchBox.Text)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(onSearchChanged)
searchBox.FocusLost:Connect(onSearchChanged)

closeBtn.MouseButton1Click:Connect(function()
	hubActive = false
	gui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.RightControl then
		gui.Enabled = not gui.Enabled
	end
end)

local dragging, dragStart, startPos = false
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = root.Position
	end
end)
header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local d = input.Position - dragStart
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

task.delay(2, function()
	if not splash.Parent then
		return
	end
	TweenService:Create(splashTitle, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(splashSub, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	TweenService:Create(splash, TweenInfo.new(0.55), { BackgroundTransparency = 1 }):Play()
	task.wait(0.55)
	splash:Destroy()
	picker.Visible = true
end)

while hubActive and gui.Parent do
	task.wait(0.5)
end
