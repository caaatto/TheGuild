local TG = TheGuild
local L = TG.L

local History = {}
TG.History = History

local NS_HIST = "hist"
local NS_GONE = "gone"
local MAX_RANK_CHANGES = 8

TG.Store:DefinePolicy(NS_HIST, "any")
TG.Store:DefinePolicy(NS_GONE, "any")

local function later(fn)
    TG.After(math.random(2, 10), fn)
end

function History:Get(key)
    return TG.Store:Get(NS_HIST, key)
end

function History:Former(key)
    return TG.Store:Get(NS_GONE, key)
end

function History:FirstSeen(key)
    local h = self:Get(key)
    return h and h.f
end

local pendingFirst = {}
local flushScheduled = false

local function flushFirstSeen()
    flushScheduled = false
    local values = {}
    local now = TG.Now()
    for key, rankIndex in pairs(pendingFirst) do
        if not History:Get(key) and TG.Roster:Get(key) then
            values[key] = { f = now, r = { { t = now, i = rankIndex } } }
        end
    end
    wipe(pendingFirst)
    if next(values) then TG.Store:SetBatch(NS_HIST, values) end
end

function History:RecordFirstSeen(entry)
    if self:Get(entry.key) then return end
    pendingFirst[entry.key] = entry.rankIndex
    if not flushScheduled then
        flushScheduled = true
        later(flushFirstSeen)
    end
end

function History:RecordRank(entry, oldRank)
    local key = entry.key
    later(function()
        local h = TG.Store:Get(NS_HIST, key)
        local record = h and TG.CopyTable(h) or { f = TG.Now(), r = {} }
        record.r = record.r or {}
        local last = record.r[#record.r]
        if last and last.i == entry.rankIndex then return end
        record.r[#record.r + 1] = { t = TG.Now(), i = entry.rankIndex, o = oldRank }
        while #record.r > MAX_RANK_CHANGES do table.remove(record.r, 1) end
        TG.Store:Set(NS_HIST, key, record)
    end)
end

function History:RecordLeft(entry)
    local key = entry.key
    later(function()
        if TG.Roster:Get(key) then return end
        if self:Former(key) then return end
        TG.Store:Set(NS_GONE, key, { t = TG.Now(), l = entry.level, r = entry.rank, c = entry.classFile })
    end)
end

function History:OnJoined(entry)
    local former = self:Former(entry.key)
    if former then
        TG.Log:Add("rejoined", entry.key, { level = entry.level })
        later(function() TG.Store:Delete(NS_GONE, entry.key) end)
    end
    self:RecordFirstSeen(entry)
end

local MIGRATE = { "role", "alt", NS_HIST }

function History:OnRenamed(entry, oldKey)
    later(function()
        for _, ns in ipairs(MIGRATE) do
            local item = TG.Store:Item(ns, oldKey)
            if item and item.v ~= nil and TG.Store:Get(ns, entry.key) == nil
                and TG.Store:CanWrite(ns, entry.key) and TG.Store:CanWrite(ns, oldKey) then
                TG.Store:Set(ns, entry.key, item.v)
                TG.Store:Delete(ns, oldKey)
            end
        end
        for key, item in pairs(TG.Store:Items("alt")) do
            if item.v == oldKey and TG.Store:CanWrite("alt", key) then
                TG.Store:Set("alt", key, entry.key)
            end
        end
    end)
end

function History:Tooltip(tooltip, entry)
    local h = self:Get(entry.key)
    if not h then return end
    local now = TG.Now()
    if h.f then
        GameTooltip_AddColoredLine(tooltip, L["First seen %s ago"]:format(TG.FormatAge(now - h.f)), LIGHTBLUE_FONT_COLOR)
    end
    local changes = h.r or {}
    local last = changes[#changes]
    if last and last.o then
        GameTooltip_AddColoredLine(tooltip, L["%s since %s ago"]:format(TG.Roster:RankName(last.i), TG.FormatAge(now - last.t)), LIGHTBLUE_FONT_COLOR)
    end
end

function History:Enable(owner)
    TG:On("MEMBER_JOINED", function(e) History:OnJoined(e) end, owner)
    TG:On("MEMBER_RANK", function(e, old) History:RecordRank(e, old) end, owner)
    TG:On("MEMBER_LEFT", function(e) History:RecordLeft(e) end, owner)
    TG:On("MEMBER_RENAMED", function(e, old) History:OnRenamed(e, old) end, owner)
    TG:On("MEMBER_TOOLTIP", function(tooltip, e) History:Tooltip(tooltip, e) end, owner)
    TG:On("ROSTER_READY", function()
        for _, e in ipairs(TG.Roster:Members()) do
            if not History:Get(e.key) then History:RecordFirstSeen(e) end
        end
    end, owner)
    if TG.Roster:IsReady() then
        for _, e in ipairs(TG.Roster:Members()) do
            if not History:Get(e.key) then History:RecordFirstSeen(e) end
        end
    end
end
