local TG = TheGuild
local Map = TG:GetModule("Map")

local Live = {}
Map.Live = Live

local units = {}
local LIVE_TICK = 0.2

local function rebuild()
    for key in pairs(units) do
        local peer = Map.peers[key]
        if peer then peer.live = nil end
    end
    wipe(units)
    local n = GetNumGroupMembers()
    if not TG.usable(n) or not n or n == 0 then return end
    local raid = IsInRaid()
    local prefix = raid and "raid" or "party"
    for i = 1, (raid and n or n - 1) do
        local unit = prefix .. i
        local key = TG.UnitKey(unit)
        if key and not TG.IsMe(key) and TG.Roster:Get(key) then units[key] = unit end
    end
end

function Live:Unit(key)
    return units[key]
end

function Live:Count()
    return TG.Count(units)
end

local function health(unit)
    if UnitHealthPercent then
        local pct = UnitHealthPercent(unit, true)
        if TG.usable(pct) and type(pct) == "number" then return math.max(0, math.min(100, math.floor(pct + 0.5))) end
    end
    return -1
end

local function tick()
    if not Map.enabled or not next(units) then return end
    local changed = false
    local now = GetTime()
    for key, unit in pairs(units) do
        local mapID = C_Map.GetBestMapForUnit(unit)
        if TG.usable(mapID) and mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, unit)
            local x, y
            if pos then x, y = pos:GetXY() end
            if TG.usable(x) and TG.usable(y) and x and y and x > 0 and y > 0 then
                local peer = Map.peers[key]
                if not peer then
                    peer = { flags = "", hp = -1 }
                    Map.peers[key] = peer
                    changed = true
                end
                if peer.mapID ~= mapID or not peer.live or not peer.hasPos then changed = true end
                peer.mapID, peer.x, peer.y = mapID, x, y
                peer.ts = now
                peer.live = true
                peer.hasPos = true
                peer.flags = TG.plain(UnitIsDeadOrGhost(unit), false) and "d" or ""
                local hp = health(unit)
                if hp >= 0 then peer.hp = hp end
                if not changed then
                    Map.MinimapPins:Move(key, peer)
                    Map.WorldMap:Move(key, peer)
                end
            end
        end
    end
    if changed then Map:Changed() end
end

function Live:Enable()
    rebuild()
    Map:RegisterEvent("GROUP_ROSTER_UPDATE", function() rebuild() Map:Changed() end)
    Map:On("ROSTER_UPDATED", rebuild)
    Map:Ticker(LIVE_TICK, tick)
end

function Live:Disable()
    for key in pairs(units) do
        local peer = Map.peers[key]
        if peer then peer.live = nil end
    end
    wipe(units)
end
