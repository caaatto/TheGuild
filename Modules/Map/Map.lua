local TG = TheGuild
local L = TG.L

local TICK = 3
local MOVE_EPS = 0.002
local HEARTBEAT = 25
local PEER_TTL = 120
local HEALTH_WARN_GAP = 60

local function refreshAll(mod)
    TG:Fire("MAP_PEERS")
end

local Map = TG:NewModule("Map", {
    title = L["Map"],
    desc = L["Show guild members on the world map"],
    order = 10,
    defaults = {
        worldMap = true, minimap = true, names = true, iconStyle = "icon",
        worldSize = 22, minimapSize = 14,
        lowHealth = false, lowHealthThreshold = 30,
        deaths = true, pins = true, minLevel = 1,
    },
    charDefaults = { share = true, hideStealth = true },
    settings = {
        { key = "share", scope = "char", type = "boolean", name = L["Share my position"], tooltip = L["Send your position to guild members running TheGuild."], default = true,
          onChange = function(mod) mod:Publish(true) end },
        { key = "hideStealth", scope = "char", type = "boolean", name = L["Hide while stealthed"], tooltip = L["Do not send a position while you are stealthed."], default = true },
        { key = "worldMap", type = "boolean", name = L["Show guild members on the world map"], default = true, onChange = refreshAll },
        { key = "minimap", type = "boolean", name = L["Show guild members on the minimap"], default = true, onChange = refreshAll },
        { key = "names", type = "boolean", name = L["Show names"], default = true, onChange = refreshAll },
        { key = "iconStyle", type = "select", name = L["Icon style"], default = "icon", onChange = refreshAll,
          options = { { "icon", L["Class icon"] }, { "dot", L["Class colored dot"] } } },
        { key = "worldSize", type = "number", name = L["World map icon size"], default = 22, min = 12, max = 40, step = 2, onChange = refreshAll },
        { key = "minimapSize", type = "number", name = L["Minimap icon size"], default = 14, min = 8, max = 24, step = 1, onChange = refreshAll },
        { key = "minLevel", type = "number", name = L["Hide members below level"], default = 1, min = 1, max = 60, step = 1, onChange = refreshAll },
        { key = "lowHealth", type = "boolean", name = L["Low health warning"], tooltip = L["Warn when a guild member drops below the health threshold."], default = false },
        { key = "lowHealthThreshold", type = "number", name = L["Health threshold"], default = 30, min = 10, max = 90, step = 5, format = function(v) return v .. "%" end },
        { key = "deaths", type = "boolean", name = L["Show deaths"], default = true, onChange = refreshAll },
        { key = "pins", type = "boolean", name = L["Show guild pins"], default = true, onChange = refreshAll },
    },
})

Map.peers = {}
local last = { at = 0 }
local pendingFire = false

local function health()
    local cur, max = UnitHealth("player"), UnitHealthMax("player")
    if TG.IsSecret(cur, max) or not cur or not max or max == 0 then return -1 end
    return math.floor(cur / max * 100 + 0.5)
end

function Map:Snapshot()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not TG.usable(mapID) then return nil end
    local flags = ""
    local inInstance = IsInInstance()
    if TG.usable(inInstance) and inInstance then flags = flags .. "i" end
    if self.cdb.hideStealth and IsStealthed and TG.plain(IsStealthed(), false) then flags = flags .. "s" end
    if TG.plain(UnitIsDeadOrGhost("player"), false) then flags = flags .. "d" end
    local x, y = 0, 0
    if not flags:find("[is]") then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local px, py = pos:GetXY()
            if TG.usable(px) and TG.usable(py) then x, y = px, py end
        end
    end
    return { mapID = mapID, x = x, y = y, hp = health(), flags = flags }
end

function Map:Publish(force)
    if not TG.InGuild() then return end
    if not self.cdb.share then
        if self.announced then
            self.announced = false
            TG.Comm:Send("P", "0:0:0:-1:x", "NORMAL")
        end
        return
    end
    local snap = self:Snapshot()
    if not snap then return end
    local now = GetTime()
    local dx, dy = snap.x - (last.x or 0), snap.y - (last.y or 0)
    local moved = math.sqrt(dx * dx + dy * dy) >= MOVE_EPS
    local changed = snap.mapID ~= last.mapID or moved or snap.flags ~= last.flags
        or math.abs(snap.hp - (last.hp or -1)) >= 10
    if not force and not changed and now - last.at < HEARTBEAT then return end
    last = snap
    last.at = now
    self.announced = true
    TG.Comm:Send("P", ("%d:%.4f:%.4f:%d:%s"):format(snap.mapID, snap.x, snap.y, snap.hp, snap.flags), force and "ALERT" or "NORMAL")
end

function Map:Changed()
    if pendingFire then return end
    pendingFire = true
    TG.After(0.3, function()
        pendingFire = false
        TG:Fire("MAP_PEERS")
    end)
end

function Map:OnPosition(sender, data)
    if type(data) ~= "string" then return end
    local mapID, x, y, hp, flags = strsplit(":", data)
    mapID = tonumber(mapID)
    flags = flags or ""
    if not mapID or flags:find("x", 1, true) then
        if self.peers[sender] then
            self.peers[sender] = nil
            self:Changed()
        end
        return
    end
    local entry = TG.Roster:Get(sender)
    if entry and entry.guid and entry.guid == TG.MyGUID() then return end
    x, y = TG.Clamp(x, 0, 1) or 0, TG.Clamp(y, 0, 1) or 0
    local peer = self.peers[sender] or {}
    peer.mapID, peer.x, peer.y = mapID, x, y
    peer.hp = tonumber(hp) or -1
    peer.flags = flags
    peer.ts = GetTime()
    peer.hasPos = x > 0 and y > 0 and not flags:find("[is]")
    self.peers[sender] = peer
    self:CheckHealth(sender, peer)
    self:Changed()
end

function Map:CheckHealth(key, peer)
    if not self.db.lowHealth or peer.hp < 0 or peer.hp > self.db.lowHealthThreshold then return end
    if peer.flags:find("d", 1, true) then return end
    if peer.warnedAt and GetTime() - peer.warnedAt < HEALTH_WARN_GAP then return end
    peer.warnedAt = GetTime()
    local entry = TG.Roster:Get(key)
    local name = entry and TG.ClassText(entry.classFile, key) or key
    TG.RaidWarning(L["%s is low on health (%d%%) in %s"]:format(name, peer.hp, TG.MapName(peer.mapID)))
end

function Map:SeedPeer(key, peer)
    self.peers[key] = peer
    self:Changed()
end

function Map:Peers()
    local now = GetTime()
    for key, p in pairs(self.peers) do
        local entry = TG.Roster:Get(key)
        if now - p.ts > PEER_TTL or (TG.Roster:IsReady() and (not entry or not entry.online)) then
            self.peers[key] = nil
        end
    end
    return self.peers
end

function Map:Peer(key)
    return self.peers[TG.StripRealm(key) or key]
end

function Map:Visible(key, peer)
    if not peer or not peer.hasPos then return false end
    if (self.db.minLevel or 1) > 1 then
        local entry = TG.Roster:Get(key)
        if entry and entry.level and entry.level < self.db.minLevel then return false end
    end
    return true
end

function Map:HasPosition(key)
    local p = self:Peer(key)
    return p ~= nil and p.hasPos
end

function Map:PeerCount()
    local n = 0
    for _, p in pairs(self:Peers()) do if p.hasPos then n = n + 1 end end
    return n
end

function Map:ShowOnMap(key)
    local p = self:Peer(key)
    if not p or not p.hasPos then return end
    if OpenWorldMap then OpenWorldMap(p.mapID) elseif WorldMapFrame then WorldMapFrame:SetMapID(p.mapID) WorldMapFrame:Show() end
    TG.After(0.3, function() self.WorldMap:Ping(TG.StripRealm(key)) end)
end

function Map:IsSharing()
    return self.cdb.share == true
end

function Map:ToggleSharing()
    self.cdb.share = not self.cdb.share
    TG:Print(self.cdb.share and L["Position sharing is on."] or L["Position sharing is off."])
    last.at = 0
    self:Publish(true)
    TG:Fire("MAP_SHARING", self.cdb.share)
end

function Map:OnInitialize()
    TG:RegisterSlash("share", function() if self.enabled then self:ToggleSharing() end end, L["toggle position sharing"])
end

function Map:OnEnable()
    self:RegisterComm("P", "OnPosition")
    self:Ticker(TICK, function() self:Publish() end)
    self:Ticker(3600, function() TG:Fire("MAP_HOURLY") end)
    self:On("PEER_HELLO", function()
        TG.After(math.random(1, 4), function() if self.enabled then last.at = 0 self:Publish(true) end end)
    end)
    self:On("MEMBER_OFFLINE", function(e)
        if self.peers[e.key] then self.peers[e.key] = nil self:Changed() end
    end)
    self:On("GUILD_CHANGED", function() wipe(self.peers) self:Changed() end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() last = { at = 0 } end)
    self.WorldMap:Enable()
    self.MinimapPins:Enable()
    self.SharedPins:Enable()
    self.Deaths:Enable()
    self.announced = false
end

function Map:OnDisable()
    if self.announced then TG.Comm:Send("P", "0:0:0:-1:x", "NORMAL") end
    self.announced = false
    self.WorldMap:Disable()
    self.MinimapPins:Disable()
    self.Deaths:Disable()
    wipe(self.peers)
    TG:Fire("MAP_PEERS")
end
