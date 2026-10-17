local TG = TheGuild
local L = TG.L
local Loot = TG:GetModule("Loot")

local Trade = {}
Loot.Trade = Trade

local MAX_TRADE_ITEMS = 6
local placed = {}

local function itemID(link)
    return tonumber((link or ""):match("item:(%d+)"))
end

local function findInBags(id)
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return nil end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, (TG.usable(slots) and slots or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and TG.usable(info.itemID) and info.itemID == id then return bag, slot end
        end
    end
    return nil
end

function Trade:Pending()
    return Loot.cdb.trades
end

function Trade:Add(link, winner, guid)
    local id = itemID(link)
    if not id or TG.IsMe(winner) or not findInBags(id) then return false end
    for _, t in ipairs(Loot.cdb.trades) do
        if t.link == link and t.to == winner then return false end
    end
    Loot.cdb.trades[#Loot.cdb.trades + 1] = { link = link, id = id, to = winner, guid = guid, t = TG.Now() }
    TG:Print(L["%s is in your bags and belongs to %s. Open a trade to hand it over."], link, TG.ShortName(winner))
    TG:Fire("LOOT_TRADES")
    return true
end

function Trade:Remove(index)
    if table.remove(Loot.cdb.trades, index) then TG:Fire("LOOT_TRADES") end
end

function Trade:Clear()
    wipe(Loot.cdb.trades)
    TG:Fire("LOOT_TRADES")
end

function Trade:Prune()
    local list = Loot.cdb.trades
    local changed = false
    for i = #list, 1, -1 do
        if not findInBags(list[i].id) then
            table.remove(list, i)
            changed = true
        end
    end
    if changed then TG:Fire("LOOT_TRADES") end
end

local function sameFirstName(a, b)
    local fa, fb = TG.FirstName(a), TG.FirstName(b)
    return fa ~= nil and fb ~= nil and fa:lower() == fb:lower()
end

function Trade:ForPartner(partner, guid)
    local out = {}
    for _, t in ipairs(Loot.cdb.trades) do
        if t.guid and guid then
            if t.guid == guid then out[#out + 1] = t end
        elseif sameFirstName(t.to, partner) then
            out[#out + 1] = t
        end
    end
    return out
end

local function partnerList()
    local partner = UnitName("NPC")
    if not TG.usable(partner) or not partner then return {} end
    local guid = UnitGUID and UnitGUID("NPC")
    return Trade:ForPartner(partner, TG.usable(guid) and guid or nil)
end

local tradeButton

local function tradeButtonFrame()
    if tradeButton or not TradeFrame then return tradeButton end
    tradeButton = CreateFrame("Button", "TheGuildTradeButton", TradeFrame, "UIPanelButtonTemplate")
    tradeButton:SetSize(200, 22)
    tradeButton:SetPoint("BOTTOM", TradeFrame, "TOP", 0, 2)
    tradeButton:SetScript("OnClick", function() Trade:Place() end)
    return tradeButton
end

function Trade:OnTradeShow()
    wipe(placed)
    local list = partnerList()
    local button = tradeButtonFrame()
    if button then
        button:SetText(L["Place %d awarded items"]:format(#list))
        button:SetShown(#list > 0)
    end
    if #list > 0 then TG:Print(L["%d awarded items for this player are in your bags. Use the button above the trade window or /tg loot trade."], #list) end
end

function Trade:Place()
    wipe(placed)
    local list = partnerList()
    if #list == 0 or not (C_Container and C_Container.PickupContainerItem and ClickTradeButton) then return end
    local slot = 1
    for _, trade in ipairs(list) do
        if slot > MAX_TRADE_ITEMS then break end
        local bag, bagSlot = findInBags(trade.id)
        if bag then
            ClearCursor()
            C_Container.PickupContainerItem(bag, bagSlot)
            if CursorHasItem() then
                ClickTradeButton(slot)
                placed[#placed + 1] = trade
                slot = slot + 1
            end
            ClearCursor()
        end
    end
    if #placed > 0 then TG:Print(L["%d items placed in the trade window."], #placed) end
    if tradeButton then tradeButton:Hide() end
end

function Trade:OnTradeComplete()
    if #placed == 0 then return end
    for _, trade in ipairs(placed) do
        for i, t in ipairs(Loot.cdb.trades) do
            if t == trade then table.remove(Loot.cdb.trades, i) break end
        end
        TG:Print(L["%s traded to %s."], trade.link, TG.ShortName(trade.to))
    end
    wipe(placed)
    TG:Fire("LOOT_TRADES")
end

function Trade:Open(index)
    local t = Loot.cdb.trades[index]
    if not t or not InitiateTrade then return false end
    local unit = TG.UnitForName(t.to)
    if not unit then
        TG:Print(L["%s is not in your group."], TG.ShortName(t.to))
        return false
    end
    InitiateTrade(unit)
    return true
end

function Trade:Enable(mod)
    mod:RegisterEvent("TRADE_SHOW", function() self:OnTradeShow() end)
    mod:RegisterEvent("TRADE_CLOSED", function()
        if tradeButton then tradeButton:Hide() end
        TG.After(1, function()
            wipe(placed)
            if #Loot.cdb.trades > 0 then self:Prune() end
        end)
    end)
    mod:RegisterEvent("UI_INFO_MESSAGE", function(_, _, msg)
        if TG.usable(msg) and msg == ERR_TRADE_COMPLETE then self:OnTradeComplete() end
    end)
end
