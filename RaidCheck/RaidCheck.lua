-- Raid Check: prüft vor dem Pull, wem in der Gruppe Food, Flask oder weitere Buffs fehlen
-- Befehle: /rcheck (prüfen, Ergebnis nur für dich), /rcheck melden (Ergebnis in Gruppen-/Raidchat),
--          /rcheck buff <Name> (zusätzlichen Pflicht-Buff hinzufügen/entfernen), /rcheck liste

local ADDON = ...
local db
local PREFIX = "|cff33ff99Raid Check:|r "

-- Lokalisierter Name des "Satt"-Buffs (Spell 19705 existiert in allen Versionen)
local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return GetSpellInfo and (GetSpellInfo(id))
end
local WELL_FED = SpellName(19705) or "Well Fed"

-- Flask-/Elixier-Buffs erkennt man am Namensanfang; mehrere Sprachen abgedeckt
local FLASK_WORDS = { "flask", "phial", "fläschchen", "phiole", "flacon", "frasco", "elixir", "elixier" }

---------------------------------------------------------------------------
-- Buffs einer Einheit auslesen (neue und alte API)
---------------------------------------------------------------------------
local function GetBuffNames(unit)
	local names = {}
	for i = 1, 40 do
		local name
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
			name = aura and aura.name
		else
			name = UnitBuff(unit, i)
		end
		if not name then break end
		names[#names + 1] = name:lower()
	end
	return names
end

local function HasBuff(names, wanted)
	wanted = wanted:lower()
	for _, n in ipairs(names) do
		if n == wanted then return true end
	end
	return false
end

local function HasFlask(names)
	for _, n in ipairs(names) do
		for _, word in ipairs(FLASK_WORDS) do
			if n:find(word, 1, true) then return true end
		end
	end
	return false
end

local function GroupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
	end
	return units
end

---------------------------------------------------------------------------
-- Prüfung
---------------------------------------------------------------------------
local function RunCheck(announce)
	if InCombatLockdown() then
		print(PREFIX .. "Im Kampf nicht möglich.")
		return
	end

	local problems = {}    -- [Spieler] = { "Food", "Flask", ... }
	local checked = 0
	for _, unit in ipairs(GroupUnits()) do
		if UnitExists(unit) then
			local name = UnitName(unit)
			local missing = {}
			if not UnitIsConnected(unit) then
				missing[#missing + 1] = "offline"
			elseif UnitIsDeadOrGhost(unit) then
				missing[#missing + 1] = "tot"
			else
				local buffs = GetBuffNames(unit)
				if not HasBuff(buffs, WELL_FED) then missing[#missing + 1] = "Food" end
				if not HasFlask(buffs) then missing[#missing + 1] = "Flask" end
				for _, extra in ipairs(db.extraBuffs) do
					if not HasBuff(buffs, extra) then missing[#missing + 1] = extra end
				end
			end
			checked = checked + 1
			if #missing > 0 then problems[#problems + 1] = name .. ": " .. table.concat(missing, ", ") end
		end
	end

	local lines = {}
	if #problems == 0 then
		lines[1] = string.format("Alle %d Spieler sind bereit.", checked)
	else
		lines[1] = string.format("%d von %d Spielern fehlt etwas:", #problems, checked)
		for _, p in ipairs(problems) do lines[#lines + 1] = "  " .. p end
	end

	local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
	for _, line in ipairs(lines) do
		if announce and channel then
			SendChatMessage("[Raid Check] " .. line, channel)
		else
			print(PREFIX .. line)
		end
	end
	if announce and not channel then print(PREFIX .. "Du bist in keiner Gruppe – Ergebnis nur lokal.") end
end

---------------------------------------------------------------------------
-- Events & Slash-Befehle
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("READY_CHECK")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		RaidCheckDB = RaidCheckDB or {}
		db = RaidCheckDB
		db.extraBuffs = db.extraBuffs or {}
		if db.onReadyCheck == nil then db.onReadyCheck = true end
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "READY_CHECK" and db.onReadyCheck then
		RunCheck(false)    -- bei jedem Bereitschaftscheck automatisch lokal prüfen
	end
end)

SLASH_RAIDCHECK1 = "/rcheck"
SlashCmdList["RAIDCHECK"] = function(msg)
	local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "melden" then
		RunCheck(true)
	elseif cmd == "buff" and arg ~= "" then
		for i, b in ipairs(db.extraBuffs) do
			if b:lower() == arg:lower() then
				table.remove(db.extraBuffs, i)
				print(PREFIX .. "Pflicht-Buff entfernt: " .. arg)
				return
			end
		end
		table.insert(db.extraBuffs, arg)
		print(PREFIX .. "Pflicht-Buff hinzugefügt: " .. arg)
	elseif cmd == "liste" then
		local extras = #db.extraBuffs > 0 and table.concat(db.extraBuffs, ", ") or "keine"
		print(PREFIX .. "Geprüft: " .. WELL_FED .. ", Flask/Elixier, zusätzlich: " .. extras)
	elseif cmd == "auto" then
		db.onReadyCheck = not db.onReadyCheck
		print(PREFIX .. "Prüfung bei Bereitschaftscheck " .. (db.onReadyCheck and "an." or "aus."))
	else
		RunCheck(false)
	end
end
