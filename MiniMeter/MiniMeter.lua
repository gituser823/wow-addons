-- Mini Meter: schlanke DPS-/HPS-Anzeige für dich und deine Gruppe (aktueller bzw. letzter Kampf)
-- Befehle: /mm (Fenster an/aus), /mm reset, /mm melden (Top 5 in den Gruppenchat)
-- Klick auf den Titel wechselt zwischen Schaden und Heilung.
-- Hinweis: braucht CombatLogGetCurrentEventInfo (Classic-Varianten, ältere Retail-Versionen).

local ADDON = ...
local db
local PREFIX = "|cff33ff99Mini Meter:|r "
local MAX_BARS = 8

local fight = { damage = {}, healing = {}, start = 0, duration = 0, active = false }
local petOwner = {}       -- [Pet-GUID] = Name des Besitzers

local band = bit.band
local GROUP_MASK = COMBATLOG_OBJECT_AFFILIATION_MINE + COMBATLOG_OBJECT_AFFILIATION_PARTY
	+ COMBATLOG_OBJECT_AFFILIATION_RAID

---------------------------------------------------------------------------
-- Kampfdaten
---------------------------------------------------------------------------
local function ResetFight()
	fight.damage, fight.healing = {}, {}
	fight.start, fight.duration = GetTime(), 0
end

local function Add(kind, name, amount)
	if not name or amount <= 0 then return end
	name = name:match("^([^%-]+)") or name        -- Realm-Anhang entfernen
	fight[kind][name] = (fight[kind][name] or 0) + amount
end

local DAMAGE_EVENTS = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
	DAMAGE_SHIELD = true, DAMAGE_SPLIT = true }
local HEAL_EVENTS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

local function OnCombatLog()
	local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID = CombatLogGetCurrentEventInfo()

	if sub == "SPELL_SUMMON" and band(srcFlags or 0, GROUP_MASK) > 0 then
		petOwner[dstGUID] = srcName
		return
	end
	if not srcFlags or band(srcFlags, GROUP_MASK) == 0 then return end

	-- Schaden von Begleitern dem Besitzer zuschreiben
	local name = petOwner[srcGUID]
	if not name and srcGUID == UnitGUID("pet") then name = UnitName("player") end
	name = name or srcName

	if sub == "SWING_DAMAGE" then
		local amount = select(12, CombatLogGetCurrentEventInfo())
		Add("damage", name, amount or 0)
	elseif DAMAGE_EVENTS[sub] then
		local amount = select(15, CombatLogGetCurrentEventInfo())
		Add("damage", name, amount or 0)
	elseif HEAL_EVENTS[sub] then
		local amount, overheal = select(15, CombatLogGetCurrentEventInfo())
		Add("healing", name, (amount or 0) - (overheal or 0))
	end
end

local function Sorted(kind)
	local list = {}
	for name, amount in pairs(fight[kind]) do list[#list + 1] = { name = name, amount = amount } end
	table.sort(list, function(a, b) return a.amount > b.amount end)
	return list
end

local function Duration()
	if fight.active then return math.max(GetTime() - fight.start, 1) end
	return math.max(fight.duration, 1)
end

local function Short(n)
	if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
	if n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(math.floor(n))
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "MiniMeterFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(200, 24 + MAX_BARS * 15)
frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
frame:SetBackdropColor(0, 0, 0, 0.6)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	db.pos = { point, relPoint, x, y }
end)

local titleButton = CreateFrame("Button", nil, frame)
titleButton:SetPoint("TOPLEFT", 4, -3)
titleButton:SetPoint("TOPRIGHT", -4, -3)
titleButton:SetHeight(16)
local titleText = titleButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
titleText:SetAllPoints()
titleText:SetJustifyH("LEFT")

local bars = {}
for i = 1, MAX_BARS do
	local bar = CreateFrame("StatusBar", nil, frame)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetSize(192, 14)
	bar:SetPoint("TOPLEFT", 4, -20 - (i - 1) * 15)
	bar:SetMinMaxValues(0, 1)
	bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.left:SetPoint("LEFT", 3, 0)
	bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.right:SetPoint("RIGHT", -3, 0)
	bar:Hide()
	bars[i] = bar
end

local function ClassColorOf(name)
	local _, classFile = UnitClass(name)
	local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if c then return c.r, c.g, c.b end
	return 0.4, 0.4, 0.8
end

local function Refresh()
	local kind = db.mode
	local list, secs = Sorted(kind), Duration()
	titleText:SetText(string.format("%s – %ds%s", kind == "damage" and "Schaden (DPS)" or "Heilung (HPS)",
		secs, fight.active and " |cffff4040•|r" or ""))
	local top = list[1] and list[1].amount or 1
	for i, bar in ipairs(bars) do
		local e = list[i]
		if e then
			bar:SetValue(e.amount / top)
			bar:SetStatusBarColor(ClassColorOf(e.name))
			bar.left:SetText(i .. ". " .. e.name)
			bar.right:SetText(string.format("%s (%s)", Short(e.amount), Short(e.amount / secs)))
			bar:Show()
		else
			bar:Hide()
		end
	end
end

titleButton:SetScript("OnClick", function()
	db.mode = db.mode == "damage" and "healing" or "damage"
	Refresh()
end)

local elapsed = 0
frame:SetScript("OnUpdate", function(_, dt)
	elapsed = elapsed + dt
	if elapsed >= 0.5 then elapsed = 0; Refresh() end
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		MiniMeterDB = MiniMeterDB or {}
		db = MiniMeterDB
		db.mode = db.mode or "damage"
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		frame:ClearAllPoints()
		if db.pos then
			frame:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
		else
			frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, -100)
		end
		frame:SetShown(not db.hidden)
		if not CombatLogGetCurrentEventInfo then
			print(PREFIX .. "Dieser Client stellt Addons kein Kampflog zur Verfügung – Mini Meter bleibt leer.")
			return
		end
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	elseif event == "PLAYER_REGEN_DISABLED" then
		ResetFight()
		fight.active = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		fight.active = false
		fight.duration = GetTime() - fight.start
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and fight.active then
		OnCombatLog()
	end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_MINIMETER1 = "/mm"
SlashCmdList["MINIMETER"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "reset" then
		ResetFight()
		fight.active = InCombatLockdown()
		Refresh()
	elseif msg == "melden" then
		local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
		local list, secs = Sorted(db.mode), Duration()
		local out = function(text) if channel then SendChatMessage(text, channel) else print(PREFIX .. text) end end
		out(string.format("Mini Meter – %s, %ds:", db.mode == "damage" and "Schaden" or "Heilung", secs))
		for i = 1, math.min(5, #list) do
			out(string.format("%d. %s %s (%s/s)", i, list[i].name, Short(list[i].amount), Short(list[i].amount / secs)))
		end
	else
		db.hidden = frame:IsShown()
		frame:SetShown(not db.hidden)
	end
end
