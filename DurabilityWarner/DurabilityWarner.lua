-- Durability Warner: Warnung bei niedriger Haltbarkeit, automatische Reparatur beim Händler
-- Befehle: /dw (Status), /dw schwelle <Prozent>, /dw repair (Auto-Reparatur an/aus),
--          /dw gilde (Gildenbank für Reparatur nutzen an/aus)

local ADDON = ...
local db
local warned = false        -- nur einmal warnen, bis wieder repariert wurde

local PREFIX = "|cff33ff99Durability Warner:|r "

-- Ausrüstungsplätze mit Haltbarkeit (Hemd = 4 und Wappenrock = 19 haben keine)
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function FormatMoney(copper)
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s, c)
end

-- Niedrigster Haltbarkeitswert aller angelegten Teile in Prozent (nil = nichts mit Haltbarkeit)
local function LowestDurability()
	local lowest
	for _, slot in ipairs(SLOTS) do
		local cur, max = GetInventoryItemDurability(slot)
		if cur and max and max > 0 then
			local pct = cur / max * 100
			if not lowest or pct < lowest then lowest = pct end
		end
	end
	return lowest
end

local function ShowWarning(pct)
	local msg = string.format("Ausrüstung bei %d%% Haltbarkeit – bald reparieren!", math.floor(pct))
	if RaidNotice_AddMessage and RaidWarningFrame then
		RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
	end
	print(PREFIX .. msg)
	-- Retail/Classic nutzen Sound-IDs, sehr alte Clients Sound-Namen
	if SOUNDKIT and SOUNDKIT.RAID_WARNING then
		PlaySound(SOUNDKIT.RAID_WARNING)
	else
		PlaySound("RaidWarning")
	end
end

local function CheckDurability()
	local pct = LowestDurability()
	if not pct then return end
	if pct <= db.threshold then
		if not warned then
			warned = true
			ShowWarning(pct)
		end
	elseif pct > db.threshold + 5 then
		warned = false          -- nach dem Reparieren wieder scharf schalten
	end
end

local function Repair()
	if not db.autoRepair or not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then return end

	-- Gildenbank zuerst, falls erlaubt und genug Geld vorhanden
	if db.useGuild and CanGuildBankRepair and CanGuildBankRepair() then
		local guildMoney = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
		if guildMoney == -1 or guildMoney >= cost then   -- -1 = unbegrenzt
			RepairAllItems(true)
			print(PREFIX .. "Repariert für " .. FormatMoney(cost) .. " (Gildenbank).")
			return
		end
	end

	if GetMoney() >= cost then
		RepairAllItems()
		print(PREFIX .. "Repariert für " .. FormatMoney(cost) .. ".")
	else
		print(PREFIX .. "Nicht genug Gold für die Reparatur (" .. FormatMoney(cost) .. ").")
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
frame:RegisterEvent("MERCHANT_SHOW")

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		DurabilityWarnerDB = DurabilityWarnerDB or {}
		db = DurabilityWarnerDB
		if db.threshold == nil then db.threshold = 20 end
		if db.autoRepair == nil then db.autoRepair = true end
		if db.useGuild == nil then db.useGuild = false end
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "MERCHANT_SHOW" then
		Repair()
	else
		CheckDurability()
	end
end)

SLASH_DURABILITYWARNER1 = "/dw"
SlashCmdList["DURABILITYWARNER"] = function(msg)
	local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	if cmd == "schwelle" and tonumber(arg) then
		db.threshold = math.max(1, math.min(99, tonumber(arg)))
		warned = false
		print(PREFIX .. "Warnschwelle: " .. db.threshold .. "%")
		CheckDurability()
	elseif cmd == "repair" then
		db.autoRepair = not db.autoRepair
		print(PREFIX .. "Auto-Reparatur " .. (db.autoRepair and "an." or "aus."))
	elseif cmd == "gilde" then
		db.useGuild = not db.useGuild
		print(PREFIX .. "Gildenbank-Reparatur " .. (db.useGuild and "an." or "aus."))
	else
		local pct = LowestDurability()
		print(PREFIX .. string.format("Niedrigstes Teil: %s | Schwelle: %d%% | Auto-Reparatur: %s | Gildenbank: %s",
			pct and (math.floor(pct) .. "%") or "–", db.threshold,
			db.autoRepair and "an" or "aus", db.useGuild and "an" or "aus"))
		print(PREFIX .. "Befehle: /dw schwelle <Prozent>, /dw repair, /dw gilde")
	end
end
