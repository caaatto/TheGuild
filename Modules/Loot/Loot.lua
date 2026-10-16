local TG = TheGuild
local L = TG.L

local NS_HISTORY = "loot"
local MAX_ITEMS = 20
local LOOT_SLOT_ITEM = 1
local RESPONSE_PASS = 4

local Loot = TG:NewModule("Loot", {
    title = L["Loot"],
    desc = L["Loot sessions with responses, council votes and a shared history."],
    order = 27,
    defaults = { autoAdd = true, minQuality = 3, announce = true, autoPass = true, findShare = true, findChat = true, findQuality = 3, findBopOnly = false },
    charDefaults = { reserves = {}, reservesTime = 0, trades = {} },
    settings = {
        { type = "header", name = L["Loot session"] },
        { key = "autoAdd", type = "boolean", name = L["Add loot from the loot window to the session"], tooltip = L["Only while you lead the group."], default = true },
        { key = "minQuality", type = "select", name = L["Minimum quality"], default = 3,
          options = { { 2, ITEM_QUALITY2_DESC or "Uncommon" }, { 3, ITEM_QUALITY3_DESC or "Rare" }, { 4, ITEM_QUALITY4_DESC or "Epic" } } },
        { key = "announce", type = "boolean", name = L["Announce awards in group chat"], default = true },
        { key = "autoPass", type = "boolean", name = L["Pass automatically on items your class cannot use"], default = true },
        { type = "header", name = L["Guild finds"] },
        { key = "findShare", type = "boolean", name = L["Tell the guild when I find a rare or better item"], default = true },
        { key = "findChat", type = "boolean", name = L["Show finds of guild members in chat"], default = true },
        { key = "findQuality", type = "select", name = L["Minimum quality for finds"], default = 3,
          options = { { 3, ITEM_QUALITY3_DESC or "Rare" }, { 4, ITEM_QUALITY4_DESC or "Epic" } } },
        { key = "findBopOnly", type = "boolean", name = L["Only report bind on pickup items"], default = false },
    },
})

TG.Store:DefinePolicy(NS_HISTORY, "officer")

Loot.RESPONSES = {
    { id = 1, text = L["Need"], color = "|cffff4040" },
    { id = 2, text = L["Greed"], color = "|cff40c040" },
    { id = 3, text = L["Offspec"], color = "|cffffd100" },
    { id = 4, text = L["Pass"], color = "|cff808080" },
}

function Loot:ResponseText(id)
    for _, r in ipairs(self.RESPONSES) do
        if r.id == id then return r.color .. r.text .. "|r", r.text end
    end
    return "", ""
end

Loot.session = nil

local function newItem(link)
    local id = tonumber(link:match("item:(%d+)"))
    if id and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(link)
    return { link = link, name = name or link:match("%[(.-)%]") or link, quality = quality, icon = icon, responses = {}, votes = {}, reserves = Loot.Reserves:Names(link) }
end

function Loot:IsOwner()
    return self.session ~= nil and self.session.owner == TG.MyName()
end

function Loot:IsCouncil()
    return TG.Roster:AmOfficer() or self:IsOwner()
end

function Loot:HasSession()
    return self.session ~= nil
end

local function itemLinks(items)
    local out = {}
    for _, item in ipairs(items) do out[#out + 1] = item.link end
    return out
end

function Loot:Start(links)
    if not IsInGroup() then
        TG:Print(L["You need to be in a group."])
        return false
    end
    if not TG.IsGroupLead() then
        TG:Print(L["Only the group leader or an assistant can start a loot session."])
        return false
    end
    if self.session and not self:IsOwner() then return false end
    if not self.session then
        self.session = { id = TG.MyName() .. "#" .. TG.Now(), owner = TG.MyName(), items = {}, started = TG.Now() }
    end
    local added = {}
    for _, link in ipairs(links or {}) do
        if #self.session.items < MAX_ITEMS and type(link) == "string" and link:find("|Hitem:") then
            local item = newItem(link)
            self.session.items[#self.session.items + 1] = item
            added[#added + 1] = item
        end
    end
    if #added > 0 then
        local sr = {}
        for i, item in ipairs(added) do sr[i] = item.reserves end
        TG.Comm:SendGroup("LS", { id = self.session.id, items = itemLinks(added), sr = sr }, "ALERT")
    end
    self:AutoPass()
    TG:Fire("LOOT_SESSION")
    self.Frames:ShowOwner()
    self.Frames:ShowResponse()
    return true
end

function Loot:IsReserved(item, name)
    return self.Reserves:Matches(item.reserves, name)
end

function Loot:AutoPass(isRetry)
    local s = self.session
    if not s or not self.db.autoPass then return end
    local me = TG.MyName()
    for i, item in ipairs(s.items) do
        if not item.awarded and not item.responses[me] and self.Usable:CanUse(item.link) == false then
            self:Respond(i, RESPONSE_PASS, true)
        end
    end
    if not isRetry and not self.autoPassTimer then
        self.autoPassTimer = true
        TG.After(2, function()
            self.autoPassTimer = nil
            if self.session then self:AutoPass(true) end
        end)
    end
end

function Loot:End()
    if not self.session then return end
    if self:IsOwner() then TG.Comm:SendGroup("LE", { id = self.session.id }, "ALERT") end
    self.session = nil
    TG:Fire("LOOT_SESSION")
    self.Frames:Hide()
end

function Loot:Respond(index, responseID, auto)
    local s = self.session
    if not s or not s.items[index] or s.items[index].awarded then return end
    local roll = math.random(1, 100)
    self:RecordResponse(TG.MyName(), index, responseID, roll, auto)
    TG.Comm:SendGroup("LR", { id = s.id, n = index, r = responseID, roll = roll }, "ALERT")
end

function Loot:RecordResponse(name, index, responseID, roll, auto)
    local s = self.session
    local item = s and s.items[index]
    if not item then return end
    item.responses[name] = { r = responseID, roll = roll, t = GetTime(), auto = auto or nil }
    TG:Fire("LOOT_SESSION")
end

function Loot:Vote(index, candidate)
    local s = self.session
    if not s or not s.items[index] or not self:IsCouncil() then return end
    local me = TG.MyName()
    local item = s.items[index]
    item.votes[candidate] = item.votes[candidate] or {}
    local on = not item.votes[candidate][me]
    item.votes[candidate][me] = on or nil
    TG.Comm:SendGroup("LV", { id = s.id, n = index, c = candidate, v = on }, "NORMAL")
    TG:Fire("LOOT_SESSION")
end

function Loot:VoteCount(item, candidate)
    return TG.Count(item.votes[candidate])
end

function Loot:Award(index, winner, responseID)
    local s = self.session
    local item = s and s.items[index]
    if not item or not self:IsOwner() then return end
    item.awarded = { winner = winner, r = responseID, t = TG.Now() }
    TG.Comm:SendGroup("LA", { id = s.id, n = index, w = winner, r = responseID }, "ALERT")
    local _, plain = self:ResponseText(responseID)
    if self.db.announce then
        local chatType = IsInRaid() and "RAID" or "PARTY"
        SendChatMessage((L["%s awarded to %s (%s)"]:format(item.link, TG.ShortName(winner), plain)):sub(1, 255), chatType)
    end
    self:RecordHistory(item, winner, responseID, TG.MyName())
    self.Trade:Add(item.link, winner)
    TG:Fire("LOOT_SESSION")
end

function Loot:RecordHistory(item, winner, responseID, by)
    if not TG.Store:CanWrite(NS_HISTORY, "x") then return end
    local now = TG.Now()
    TG.Store:Set(NS_HISTORY, now .. "#" .. (item.link:match("item:(%d+)") or "0") .. "#" .. winner, {
        t = now, i = item.link, w = winner, r = responseID, b = by, z = TG.plain(GetZoneText(), ""),
    })
end

function Loot:History()
    local out = {}
    for key, entry in pairs(TG.Store:Items(NS_HISTORY)) do
        if type(entry.v) == "table" then
            local v = entry.v
            out[#out + 1] = { key = key, t = v.t or 0, link = v.i, winner = v.w, r = v.r, by = v.b, zone = v.z }
        end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
end

function Loot:OnStart(sender, data)
    if type(data) ~= "table" or type(data.id) ~= "string" or type(data.items) ~= "table" then return end
    if self.session and self.session.id ~= data.id then
        if self:IsOwner() then return end
        self.session = nil
    end
    if not self.session then
        self.session = { id = data.id, owner = sender, items = {}, started = TG.Now() }
    end
    for i, link in ipairs(data.items) do
        if #self.session.items < MAX_ITEMS and type(link) == "string" and link:find("|Hitem:") then
            local item = newItem(link)
            local sr = type(data.sr) == "table" and data.sr[i]
            if type(sr) == "table" and #sr > 0 then item.reserves = sr end
            self.session.items[#self.session.items + 1] = item
        end
    end
    self:AutoPass()
    TG:Fire("LOOT_SESSION")
    self.Frames:ShowResponse()
    if self:IsCouncil() then self.Frames:ShowOwner() end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
end

function Loot:OnResponse(sender, data)
    local s = self.session
    if not s or type(data) ~= "table" or data.id ~= s.id then return end
    local index, r = tonumber(data.n), tonumber(data.r)
    if not index or not r then return end
    self:RecordResponse(sender, index, r, tonumber(data.roll) or 0)
end

function Loot:OnVote(sender, data)
    local s = self.session
    if not s or type(data) ~= "table" or data.id ~= s.id then return end
    local item = s.items[tonumber(data.n) or 0]
    if not item or type(data.c) ~= "string" then return end
    if not TG.Roster:IsOfficer(sender) and sender ~= s.owner then return end
    item.votes[data.c] = item.votes[data.c] or {}
    item.votes[data.c][sender] = data.v and true or nil
    TG:Fire("LOOT_SESSION")
end

function Loot:OnAward(sender, data)
    local s = self.session
    if not s or type(data) ~= "table" or data.id ~= s.id or sender ~= s.owner then return end
    local item = s.items[tonumber(data.n) or 0]
    if not item or type(data.w) ~= "string" then return end
    item.awarded = { winner = data.w, r = tonumber(data.r), t = TG.Now() }
    if TG.IsMe(data.w) then
        TG:Print(L["You received %s"], item.link)
        PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND)
    else
        self.Trade:Add(item.link, data.w)
    end
    TG:Fire("LOOT_SESSION")
end

function Loot:OnEnd(sender, data)
    local s = self.session
    if not s or type(data) ~= "table" or data.id ~= s.id or sender ~= s.owner then return end
    self.session = nil
    TG:Fire("LOOT_SESSION")
    self.Frames:Hide()
end

function Loot:OnLootOpened()
    if not self.db.autoAdd or not IsInGroup() or not TG.IsGroupLead() then return end
    if not GetNumLootItems then return end
    local links = {}
    for i = 1, GetNumLootItems() do
        local slotType = GetLootSlotType and GetLootSlotType(i) or LOOT_SLOT_ITEM
        if slotType == LOOT_SLOT_ITEM then
            local _, _, _, _, quality = GetLootSlotInfo(i)
            if TG.usable(quality) and quality >= self.db.minQuality then
                local link = GetLootSlotLink(i)
                if TG.usable(link) and link then
                    local known = false
                    for _, item in ipairs(self.session and self.session.items or {}) do
                        if item.link == link then known = true end
                    end
                    if not known then links[#links + 1] = link end
                end
            end
        end
    end
    if #links > 0 then self:Start(links) end
end

function Loot:OnInitialize()
    TG:RegisterSlash("loot", function(rest)
        if not self.enabled then return end
        rest = TG.Trim(rest)
        if rest == "end" then self:End() return end
        if rest == "sr" then self.Reserves:OpenImport() return end
        if rest == "" then
            if self.session then self.Frames:ShowOwner() self.Frames:ShowResponse() else TG:Print(L["Usage: /tg loot <item link>, /tg loot end, /tg loot sr"]) end
            return
        end
        local links = {}
        for link in rest:gmatch("|c%x+|Hitem:.-|h%[.-%]|h|r") do links[#links + 1] = link end
        if #links > 0 then self:Start(links) end
    end, L["start a loot session with item links"])
end

function Loot:OnEnable()
    self:RegisterComm("LS", "OnStart")
    self:RegisterComm("LR", "OnResponse")
    self:RegisterComm("LV", "OnVote")
    self:RegisterComm("LA", "OnAward")
    self:RegisterComm("LE", "OnEnd")
    self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
    self.Finds:Enable(self)
    self.Trade:Enable(self)
    self:RegisterEvent("GROUP_LEFT", function() if self.session then self.session = nil TG:Fire("LOOT_SESSION") self.Frames:Hide() end end)
end

function Loot:OnDisable()
    self.session = nil
    self.Frames:Hide()
end
