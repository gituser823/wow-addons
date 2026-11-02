-- Session Tracker: Gold und XP pro Stunde seit dem Login
-- Befehle: /st (Fenster an/aus), /st reset (Sitzung neu starten), /st lock (Fenster fixieren)

local ADDON = ...
local session = {}          -- Daten der laufenden Sitzung (nicht gespeichert)
local db                    -- SessionTrackerDB (gespeichert: Fensterposition, Optionen)

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local function FormatMoney(copper)
	local sign = copper < 0 and "-" or ""
	copper = math.abs(math.floor(copper))
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	return string.format("%s|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", sign, g, s, c)
end

local function FormatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%d:%02d:%02d", h, m, s)
end

local function FormatNumber(n)
	n = math.floor(n)
	if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
	if n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(n)
end

---------------------------------------------------------------------------
-- Sitzung
---------------------------------------------------------------------------
local function ResetSession()
	session.startTime  = GetTime()
	session.startMoney = GetMoney()
	session.xpGained   = 0
	session.lastXP     = UnitXP("player")
	session.lastMaxXP  = UnitXPMax("player")
	session.lastLevel  = UnitLevel("player")
end

-- XP-Zuwachs berechnen, auch über einen Levelaufstieg hinweg
local function UpdateXP()
	local xp, maxXP, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
	if level > session.lastLevel then
		session.xpGained = session.xpGained + (session.lastMaxXP - session.lastXP) + xp
	elseif xp > session.lastXP then
		session.xpGained = session.xpGained + (xp - session.lastXP)
	end
	session.lastXP, session.lastMaxXP, session.lastLevel = xp, maxXP, level
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "SessionTrackerFrame", UIParent,
	BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(210, 92)
frame:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0, 0, 0, 0.75)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("Session Tracker")

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("TOPLEFT", 10, -26)
text:SetJustifyH("LEFT")

frame:SetScript("OnDragStart", function(self)
	if not db.locked then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	db.pos = { point, relPoint, x, y }
end)

local function Refresh()
	local elapsed = math.max(GetTime() - session.startTime, 1)
	local hours   = elapsed / 3600
	local money   = GetMoney() - session.startMoney

	local lines = {
		"Zeit:  " .. FormatTime(elapsed),
		"Gold:  " .. FormatMoney(money),
		"Gold/h: " .. FormatMoney(money / hours),
	}
	-- XP nur anzeigen, solange der Charakter noch nicht auf Maximallevel ist
	if session.lastMaxXP and session.lastMaxXP > 0 and session.xpGained > 0 then
		table.insert(lines, string.format("XP: %s  (%s/h)",
			FormatNumber(session.xpGained), FormatNumber(session.xpGained / hours)))
	end
	text:SetText(table.concat(lines, "\n"))
	frame:SetHeight(34 + #lines * 13)
end

-- Einmal pro Sekunde aktualisieren (OnUpdate läuft in jeder WoW-Version)
local throttle = 0
frame:SetScript("OnUpdate", function(_, dt)
	throttle = throttle + dt
	if throttle >= 1 then
		throttle = 0
		Refresh()
	end
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		SessionTrackerDB = SessionTrackerDB or {}
		db = SessionTrackerDB
		if db.hidden == nil then db.hidden = false end
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		ResetSession()
		self:ClearAllPoints()
		if db.pos then
			self:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
		else
			self:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
		end
		self:SetShown(not db.hidden)
		Refresh()
	elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
		UpdateXP()
	end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_SESSIONTRACKER1 = "/st"
SLASH_SESSIONTRACKER2 = "/sessiontracker"
SlashCmdList["SESSIONTRACKER"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "reset" then
		ResetSession()
		Refresh()
		print("|cff33ff99Session Tracker:|r Sitzung zurückgesetzt.")
	elseif msg == "lock" then
		db.locked = not db.locked
		print("|cff33ff99Session Tracker:|r Fenster " .. (db.locked and "fixiert." or "beweglich."))
	else
		db.hidden = frame:IsShown()
		frame:SetShown(not db.hidden)
	end
end
