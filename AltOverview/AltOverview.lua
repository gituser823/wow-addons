-- Alt Overview: Gold, Level, Gegenstandsstufe, Berufe und freie Taschenplätze aller Charaktere
-- Daten werden beim Spielen jedes Charakters gesammelt (account-weit gespeichert).
-- Befehle: /alts (Fenster an/aus), /alts del <Name> (Charakter entfernen)

local ADDON = ...
local db
local PREFIX = "|cff33ff99Alt Overview:|r "
local key        -- "Name-Realm" des aktuellen Charakters

local GetFreeSlots = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
local GetNumSlots  = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

---------------------------------------------------------------------------
-- Daten sammeln
---------------------------------------------------------------------------
local function GetProfessionList()
	local list = {}
	if GetProfessions then                         -- Retail, Cata Classic und neuer
		for _, index in ipairs({ GetProfessions() }) do
			if index then
				local name, _, rank, maxRank = GetProfessionInfo(index)
				table.insert(list, string.format("%s %d/%d", name, rank, maxRank))
			end
		end
	elseif GetNumSkillLines then                   -- Classic Era: Fertigkeiten-Liste durchsuchen
		local inSection = false
		for i = 1, GetNumSkillLines() do
			local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
			if isHeader then
				inSection = (name == TRADE_SKILLS or name == SECONDARY_SKILLS)
			elseif inSection then
				table.insert(list, string.format("%s %d/%d", name, rank, maxRank))
			end
		end
	end
	return table.concat(list, ", ")
end

local function UpdateCharacter()
	if not key then return end
	local c = db.chars[key] or {}
	local _, classFile = UnitClass("player")
	c.name, c.realm = UnitName("player"), GetRealmName()
	c.class   = classFile
	c.level   = UnitLevel("player")
	c.money   = GetMoney()
	c.ilvl    = GetAverageItemLevel and math.floor((GetAverageItemLevel())) or nil
	c.profs   = GetProfessionList()
	c.updated = time()

	local free, total = 0, 0
	for bag = 0, (NUM_BAG_SLOTS or 4) do
		free  = free + (GetFreeSlots(bag) or 0)
		total = total + (GetNumSlots(bag) or 0)
	end
	c.bagFree, c.bagTotal = free, total
	db.chars[key] = c
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "AltOverviewFrame", UIParent,
	BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(560, 100)
frame:SetPoint("CENTER")
frame:SetBackdrop({
	bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0, 0, 0, 0.85)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetClampedToScreen(true)
frame:Hide()
table.insert(UISpecialFrames, "AltOverviewFrame")   -- mit Escape schließen

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("Alt Overview")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local COLUMNS = { { "Charakter", 150 }, { "Lvl", 35 }, { "iLvl", 40 }, { "Gold", 110 }, { "Taschen", 60 }, { "Berufe", 150 } }
local rows = {}

local function GetRow(i)
	if rows[i] then return rows[i] end
	local row, x = {}, 12
	for col, def in ipairs(COLUMNS) do
		local fs = frame:CreateFontString(nil, "OVERLAY", i == 0 and "GameFontNormalSmall" or "GameFontHighlightSmall")
		fs:SetPoint("TOPLEFT", x, -30 - i * 16)
		fs:SetWidth(def[2])
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		row[col] = fs
		x = x + def[2] + 4
	end
	rows[i] = row
	return row
end

local function ClassColor(classFile)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if not c then return "ffffffff" end
	return string.format("ff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

local function Gold(copper)
	return string.format("|cffffd700%s|r g", BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(copper / 10000))
		or tostring(math.floor(copper / 10000)))
end

local function Refresh()
	UpdateCharacter()
	local header = GetRow(0)
	for col, def in ipairs(COLUMNS) do header[col]:SetText(def[1]) end

	local list, totalMoney = {}, 0
	for _, c in pairs(db.chars) do
		table.insert(list, c)
		totalMoney = totalMoney + (c.money or 0)
	end
	table.sort(list, function(a, b) return (a.money or 0) > (b.money or 0) end)

	for i, c in ipairs(list) do
		local row = GetRow(i)
		row[1]:SetText(string.format("|c%s%s|r |cff888888%s|r", ClassColor(c.class), c.name, c.realm))
		row[2]:SetText(c.level or "?")
		row[3]:SetText(c.ilvl or "–")
		row[4]:SetText(Gold(c.money or 0))
		row[5]:SetText(string.format("%d/%d", c.bagFree or 0, c.bagTotal or 0))
		row[6]:SetText(c.profs ~= "" and c.profs or "–")
		for _, fs in ipairs(row) do fs:Show() end
	end
	for i = #list + 1, #rows do
		for _, fs in ipairs(rows[i]) do fs:Hide() end
	end

	local totalRow = GetRow(#list + 1)
	for _, fs in ipairs(totalRow) do fs:SetText(""); fs:Show() end
	totalRow[1]:SetText("|cffffffffGesamt|r")
	totalRow[4]:SetText(Gold(totalMoney))

	frame:SetHeight(44 + (#list + 2) * 16)
end
frame:SetScript("OnShow", Refresh)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local pending = false
local function UpdateSoon()           -- BAG_UPDATE kommt oft in Serie: gebündelt nach 2 s speichern
	if pending then return end
	pending = true
	local waited = 0
	frame:SetScript("OnUpdate", function(self, dt)
		waited = waited + dt
		if waited >= 2 then
			self:SetScript("OnUpdate", nil)
			pending = false
			UpdateCharacter()
			if self:IsShown() then Refresh() end
		end
	end)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_MONEY", "PLAYER_LEVEL_UP",
	"BAG_UPDATE", "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LOGOUT" }) do
	events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		AltOverviewDB = AltOverviewDB or {}
		db = AltOverviewDB
		db.chars = db.chars or {}
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		key = UnitName("player") .. "-" .. GetRealmName()
		UpdateCharacter()
	elseif event == "PLAYER_LOGOUT" then
		UpdateCharacter()
	elseif key then
		UpdateSoon()
	end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_ALTOVERVIEW1 = "/alts"
SlashCmdList["ALTOVERVIEW"] = function(msg)
	local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	if cmd:lower() == "del" and arg ~= "" then
		local removed = 0
		for k, c in pairs(db.chars) do
			if k ~= key and (k:lower() == arg:lower() or c.name:lower() == arg:lower()) then
				db.chars[k] = nil
				removed = removed + 1
			end
		end
		print(PREFIX .. removed .. " Charakter(e) entfernt.")
		if frame:IsShown() then Refresh() end
	else
		frame:SetShown(not frame:IsShown())
	end
end
