-- Auto Sell Grey: verkauft graue (Qualität 0) Items beim Händler und meldet den Erlös
-- Befehle: /asg (an/aus), /asg liste (zeigt, was verkauft würde)

local ADDON = ...
local db
local PREFIX = "|cff33ff99Auto Sell Grey:|r "

-- Neue Clients haben C_Container, alte die globalen Funktionen
local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local UseItem     = (C_Container and C_Container.UseContainerItem) or UseContainerItem
local NUM_BAGS    = NUM_BAG_SLOTS or 4

-- Liefert quality, stackCount, link, noValue für einen Taschenplatz
local function GetSlotInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then return info.quality, info.stackCount, info.hyperlink, info.hasNoValue end
	else
		local _, count, _, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
		return quality, count, link, noValue
	end
end

local function FormatMoney(copper)
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s, c)
end

-- Alle grauen Items mit Verkaufswert sammeln
local function CollectGrey()
	local items = {}
	for bag = 0, NUM_BAGS do
		for slot = 1, (GetNumSlots(bag) or 0) do
			local quality, count, link, noValue = GetSlotInfo(bag, slot)
			if quality == 0 and link and not noValue then
				local price = select(11, GetItemInfo(link)) or 0
				if price > 0 then
					table.insert(items, { bag = bag, slot = slot, link = link,
						count = count or 1, value = price * (count or 1) })
				end
			end
		end
	end
	return items
end

local function SellGrey()
	local items = CollectGrey()
	if #items == 0 then return end
	local total = 0
	for _, item in ipairs(items) do
		UseItem(item.bag, item.slot)    -- bei offenem Händlerfenster = verkaufen
		total = total + item.value
	end
	print(string.format("%s%d Item(s) verkauft für %s.", PREFIX, #items, FormatMoney(total)))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		AutoSellGreyDB = AutoSellGreyDB or {}
		db = AutoSellGreyDB
		if db.enabled == nil then db.enabled = true end
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "MERCHANT_SHOW" and db.enabled then
		SellGrey()
	end
end)

SLASH_AUTOSELLGREY1 = "/asg"
SlashCmdList["AUTOSELLGREY"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "liste" then
		local items, total = CollectGrey(), 0
		for _, item in ipairs(items) do
			print(string.format("  %s x%d – %s", item.link, item.count, FormatMoney(item.value)))
			total = total + item.value
		end
		print(string.format("%s%d graue(s) Item(s), zusammen %s.", PREFIX, #items, FormatMoney(total)))
	else
		db.enabled = not db.enabled
		print(PREFIX .. (db.enabled and "aktiviert." or "deaktiviert."))
	end
end
