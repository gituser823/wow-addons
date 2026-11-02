-- Farm Log: zählt Beute, Gold und Zeit pro Zone
-- Befehle: /fl (aktuelle Zone), /fl alle (alle Zonen nach Gold/h), /fl reset [alle]

local ADDON = ...
local db
local PREFIX = "|cff33ff99Farm Log:|r "

local currentZone
local blockMoney = 0          -- >0 solange Händler/Post/AH/Handel offen ist (kein Farm-Gold)
local lastMoney

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local function FormatMoney(copper)
	copper = math.floor(copper)
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s, c)
end

local function FormatTime(seconds)
	return string.format("%d:%02d h", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
end

-- Lokalisierten Format-String (z. B. "Ihr erhaltet Beute: %sx%d.") in ein Lua-Muster umwandeln
local function ToPattern(fmt)
	local p = fmt:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
	p = p:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	p = p:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
	return "^" .. p .. "$"
end

local LOOT_MULTI  = ToPattern(LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.")
local LOOT_SINGLE = ToPattern(LOOT_ITEM_SELF or "You receive loot: %s.")

local function Zone(name)
	db.zones[name] = db.zones[name] or { time = 0, money = 0, items = {} }
	return db.zones[name]
end

-- Geschätzter Händlerwert aller Items einer Zone
local function ItemValue(z)
	local total = 0
	for _, item in pairs(z.items) do
		local price = select(11, GetItemInfo(item.link)) or 0
		total = total + price * item.count
	end
	return total
end

---------------------------------------------------------------------------
-- Ausgabe
---------------------------------------------------------------------------
local function PrintZone(name)
	local z = db.zones[name]
	if not z then print(PREFIX .. "Noch keine Daten für " .. name .. ".") return end
	local hours = math.max(z.time, 60) / 3600
	local value = ItemValue(z)
	print(string.format("%s|cffffffff%s|r – %s gefarmt", PREFIX, name, FormatTime(z.time)))
	print(string.format("  Gold: %s  |  Items (Händlerwert): %s", FormatMoney(z.money), FormatMoney(value)))
	print(string.format("  Gesamt pro Stunde: %s", FormatMoney((z.money + value) / hours)))

	local list = {}
	for _, item in pairs(z.items) do table.insert(list, item) end
	table.sort(list, function(a, b) return a.count > b.count end)
	for i = 1, math.min(10, #list) do
		print(string.format("  %s x%d", list[i].link, list[i].count))
	end
end

local function PrintAll()
	local list = {}
	for name, z in pairs(db.zones) do
		if z.time >= 60 then
			local perHour = (z.money + ItemValue(z)) / (z.time / 3600)
			table.insert(list, { name = name, perHour = perHour, time = z.time })
		end
	end
	if #list == 0 then print(PREFIX .. "Noch keine Zone mit mindestens 1 Minute Farmzeit.") return end
	table.sort(list, function(a, b) return a.perHour > b.perHour end)
	print(PREFIX .. "Zonen nach Ertrag pro Stunde:")
	for i, e in ipairs(list) do
		print(string.format("  %d. %s – %s/h (%s)", i, e.name, FormatMoney(e.perHour), FormatTime(e.time)))
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local BLOCK_OPEN  = { MERCHANT_SHOW = true, MAIL_SHOW = true, AUCTION_HOUSE_SHOW = true, TRADE_SHOW = true }
local BLOCK_CLOSE = { MERCHANT_CLOSED = true, MAIL_CLOSED = true, AUCTION_HOUSE_CLOSED = true, TRADE_CLOSED = true }

for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
	"CHAT_MSG_LOOT", "PLAYER_MONEY" }) do frame:RegisterEvent(e) end
for e in pairs(BLOCK_OPEN) do pcall(frame.RegisterEvent, frame, e) end   -- nicht jedes Event gibt es überall
for e in pairs(BLOCK_CLOSE) do pcall(frame.RegisterEvent, frame, e) end

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		FarmLogDB = FarmLogDB or {}
		db = FarmLogDB
		db.zones = db.zones or {}
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		currentZone = GetRealZoneText()
		lastMoney = lastMoney or GetMoney()
	elseif event == "CHAT_MSG_LOOT" and currentZone then
		local link, count = arg1:match(LOOT_MULTI)
		if not link then link = arg1:match(LOOT_SINGLE); count = 1 end
		local id = link and link:match("item:(%d+)")
		if id then
			local z = Zone(currentZone)
			z.items[id] = z.items[id] or { link = link, count = 0 }
			z.items[id].count = z.items[id].count + tonumber(count)
		end
	elseif event == "PLAYER_MONEY" then
		local now = GetMoney()
		local diff = now - (lastMoney or now)
		lastMoney = now
		if diff > 0 and blockMoney == 0 and currentZone then
			Zone(currentZone).money = Zone(currentZone).money + diff
		end
	elseif BLOCK_OPEN[event] then
		blockMoney = blockMoney + 1
	elseif BLOCK_CLOSE[event] then
		blockMoney = math.max(0, blockMoney - 1)
		lastMoney = GetMoney()
	end
end)

-- Farmzeit zählen, nur außerhalb von Städten/Gasthäusern und nicht AFK
local tick = 0
frame:SetScript("OnUpdate", function(_, dt)
	tick = tick + dt
	if tick < 5 then return end
	if db and currentZone and not IsResting() and not UnitIsAFK("player") then
		Zone(currentZone).time = Zone(currentZone).time + tick
	end
	tick = 0
end)

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
SLASH_FARMLOG1 = "/fl"
SLASH_FARMLOG2 = "/farmlog"
SlashCmdList["FARMLOG"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "alle" then
		PrintAll()
	elseif msg == "reset alle" then
		db.zones = {}
		print(PREFIX .. "Alle Zonen gelöscht.")
	elseif msg == "reset" then
		currentZone = currentZone or GetRealZoneText()
		db.zones[currentZone] = nil
		print(PREFIX .. "Daten für " .. currentZone .. " gelöscht.")
	else
		PrintZone(currentZone or GetRealZoneText())
		print(PREFIX .. "Befehle: /fl alle, /fl reset, /fl reset alle")
	end
end
