-- Quest Notes: sagt Quest-Fortschritt an und speichert Notizen mit Ort
-- Befehle: /qn <Text>        Notiz an deiner aktuellen Position speichern
--          /qn liste         Notizen der aktuellen Zone mit Entfernung und Richtung
--          /qn weg <Nr>      Wegpunkt auf Notiz setzen (nur wo die Karte es unterstützt)
--          /qn del <Nr>      Notiz löschen
--          /qn gruppe        Fortschritt zusätzlich im Gruppenchat ansagen (an/aus)

local ADDON = ...
local db
local PREFIX = "|cff33ff99Quest Notes:|r "

local DIRECTIONS = { "N", "NO", "O", "SO", "S", "SW", "W", "NW" }

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
local function PlayerPosition()
	if not (C_Map and C_Map.GetBestMapForUnit) then return end
	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return end            -- z. B. in Instanzen gibt es keine Position
	local x, y = pos:GetXY()
	return mapID, x, y
end

local function MapName(mapID)
	local info = C_Map.GetMapInfo(mapID)
	return info and info.name or ("Karte " .. mapID)
end

-- Entfernung (in Kartenprozent) und Himmelsrichtung von der Spielerposition zur Notiz
local function DistanceAndDirection(px, py, nx, ny)
	local dx, dy = nx - px, py - ny        -- y wächst auf der Karte nach unten
	local dist = math.sqrt(dx * dx + dy * dy) * 100
	local angle = math.deg(math.atan2(dx, dy)) % 360
	local dir = DIRECTIONS[math.floor((angle + 22.5) / 45) % 8 + 1]
	return dist, dir
end

local function NotesOnMap(mapID)
	local list = {}
	for i, note in ipairs(db.notes) do
		if note.map == mapID then list[#list + 1] = { index = i, note = note } end
	end
	return list
end

---------------------------------------------------------------------------
-- Quest-Fortschritt
---------------------------------------------------------------------------
-- Fortschrittsmeldungen sehen aus wie "Kobold getötet: 3/8"
local function OnInfoMessage(...)
	local message
	for i = 1, select("#", ...) do                 -- Argumente unterscheiden sich je nach Version
		local v = select(i, ...)
		if type(v) == "string" then message = v end
	end
	if not message then return end
	local what, have, need = message:match("^(.+):%s*(%d+)%s*/%s*(%d+)$")
	if not what then return end
	have, need = tonumber(have), tonumber(need)

	if have >= need then
		if SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE then
			PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
		end
		print(PREFIX .. "|cff00ff00Erledigt:|r " .. what)
	end
	if db.announceGroup and IsInGroup() and not IsInRaid() then
		SendChatMessage(string.format("[Quest] %s: %d/%d", what, have, need), "PARTY")
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UI_INFO_MESSAGE")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		QuestNotesDB = QuestNotesDB or {}
		db = QuestNotesDB
		db.notes = db.notes or {}
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "UI_INFO_MESSAGE" and db then
		OnInfoMessage(...)
	end
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_QUESTNOTES1 = "/qn"
SlashCmdList["QUESTNOTES"] = function(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$")
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()

	if msg == "" then
		print(PREFIX .. "/qn <Text>, /qn liste, /qn weg <Nr>, /qn del <Nr>, /qn gruppe")
	elseif cmd == "gruppe" then
		db.announceGroup = not db.announceGroup
		print(PREFIX .. "Ansage im Gruppenchat " .. (db.announceGroup and "an." or "aus."))
	elseif cmd == "liste" then
		local mapID, px, py = PlayerPosition()
		if not mapID then print(PREFIX .. "Position hier nicht verfügbar.") return end
		local list = NotesOnMap(mapID)
		if #list == 0 then print(PREFIX .. "Keine Notizen in " .. MapName(mapID) .. ".") return end
		print(PREFIX .. "Notizen in " .. MapName(mapID) .. ":")
		for _, e in ipairs(list) do
			local dist, dir = DistanceAndDirection(px, py, e.note.x, e.note.y)
			print(string.format("  [%d] %s  |cff888888(%.1f, %.1f – %.0f %s)|r",
				e.index, e.note.text, e.note.x * 100, e.note.y * 100, dist, dir))
		end
	elseif cmd == "del" and tonumber(arg) then
		local note = table.remove(db.notes, tonumber(arg))
		print(PREFIX .. (note and ("Gelöscht: " .. note.text) or "Keine Notiz mit dieser Nummer."))
	elseif cmd == "weg" and tonumber(arg) then
		local note = db.notes[tonumber(arg)]
		if not note then print(PREFIX .. "Keine Notiz mit dieser Nummer.") return end
		if C_Map.SetUserWaypoint and UiMapPoint and C_Map.CanSetUserWaypointOnMap
			and C_Map.CanSetUserWaypointOnMap(note.map) then
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(note.map, note.x, note.y))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			end
			print(PREFIX .. "Wegpunkt gesetzt: " .. note.text)
		else
			print(string.format("%sWegpunkte werden hier nicht unterstützt. Ziel: %s (%.1f, %.1f)",
				PREFIX, MapName(note.map), note.x * 100, note.y * 100))
		end
	else
		local mapID, x, y = PlayerPosition()
		if not mapID then print(PREFIX .. "Position hier nicht verfügbar.") return end
		table.insert(db.notes, { map = mapID, x = x, y = y, text = msg })
		print(string.format("%sNotiz [%d] gespeichert: %s (%s %.1f, %.1f)",
			PREFIX, #db.notes, msg, MapName(mapID), x * 100, y * 100))
	end
end
