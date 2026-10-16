local _, TG = ...
local L = TG.L
local Map = TG:GetModule("Map")

local D = {}
Map.Deaths = D

local NS = "death"
local KEEP_OWN = 5
local MAX_AGE = 7 * 86400
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local function tooltip(tt, marker)
    local item = marker.item
    local entry = TG.Roster:Get(item.a)
    GameTooltip_SetTitle(tt, entry and TG.ClassText(entry.classFile, item.a) or item.a)
    if item.v.z and item.v.z ~= "" then GameTooltip_AddHighlightLine(tt, item.v.z) end
    if item.v.l then GameTooltip_AddNormalLine(tt, ("%s %d"):format(L["Level"], item.v.l)) end
    GameTooltip_AddDisabledLine(tt, L["Died %s ago"]:format(TG.FormatAge(TG.Now() - (item.v.t or item.t or 0))))
end

function D:ForMap(mapID)
    local out = {}
    for key, item in pairs(TG.Store:Items(NS)) do
        local v = item.v
        if type(v) == "table" and v.m == mapID then
            out[#out + 1] = { key = key, item = item, x = v.x, y = v.y, icon = SKULL, size = 18, tooltip = tooltip }
        end
    end
    return out
end

function D:Record()
    local snap = Map:Snapshot()
    if not snap or snap.x <= 0 or snap.flags:find("i", 1, true) then return end
    local now = TG.Now()
    local zone = TG.plain(GetSubZoneText(), "")
    if zone == "" then zone = TG.plain(GetZoneText(), "") end
    TG.Store:Set(NS, TG.MyName() .. "#" .. now, {
        m = snap.mapID, x = TG.Round(snap.x, 4), y = TG.Round(snap.y, 4),
        t = now, z = zone, l = TG.plain(UnitLevel("player"), 0),
    })
    self:Cleanup()
end

function D:Cleanup()
    local me = TG.MyName()
    local now = TG.Now()
    local own = {}
    for key, item in pairs(TG.Store:Items(NS)) do
        if item.a == me then
            if (now - (item.v.t or 0)) > MAX_AGE then
                TG.Store:Delete(NS, key)
            else
                own[#own + 1] = { key = key, t = item.v.t or 0 }
            end
        end
    end
    table.sort(own, function(a, b) return a.t > b.t end)
    for i = KEEP_OWN + 1, #own do TG.Store:Delete(NS, own[i].key) end
end

function D:Enable()
    TG:RegisterEvent("PLAYER_DEAD", function() if Map.enabled then D:Record() end end, Map)
    TG:On("STORE_CHANGED", function(ns, key, value)
        if ns ~= NS or type(value) ~= "table" then return end
        local author = key:match("^(.-)#%d+$")
        if author and not TG.IsMe(author) and (TG.Now() - (value.t or 0)) < 120 then
            TG:Fire("ACTIVITY", "death", author, value)
        end
    end, Map)
end

function D:Disable()
end
