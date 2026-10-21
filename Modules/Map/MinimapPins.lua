local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Map = TG:GetModule("Map")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local MP = {}
Map.MinimapPins = MP

local pool = {}
local active = {}
local menuHooked = false

local function create()
    local f = CreateFrame("Button", nil, Minimap)
    f:SetSize(14, 14)
    f:RegisterForClicks("LeftButtonUp")
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    f:SetScript("OnEnter", function(self)
        local peer = Map:Peer(self.key)
        if not peer then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        Map.WorldMap.Tooltip(GameTooltip, self.key, peer)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function(self)
        local entry = TG.Roster:Get(self.key)
        if entry then UI.MemberMenu(self, entry) end
    end)
    return f
end

local function acquire()
    local f = table.remove(pool) or create()
    active[#active + 1] = f
    return f
end

local function releaseAll()
    for _, f in ipairs(active) do
        f:Hide()
        f.key = nil
        pool[#pool + 1] = f
    end
    wipe(active)
end

function MP:Move(key, peer)
    for _, f in ipairs(active) do
        if f.key == key then
            HBDPins:AddMinimapIconMap(MP, f, peer.mapID, peer.x, peer.y, true, true)
            return
        end
    end
end

function MP:Refresh()
    HBDPins:RemoveAllMinimapIcons(MP)
    releaseAll()
    if not Map.enabled or not Map.db.minimap then return end
    local size = Map.db.minimapSize
    for key, peer in pairs(Map:Peers()) do
        if Map:Visible(key, peer) then
            local entry = TG.Roster:Get(key)
            local f = acquire()
            f.key = key
            f:SetSize(size, size)
            Map.WorldMap.Style(f.Icon, entry and entry.classFile, peer, Map.db.iconStyle)
            HBDPins:AddMinimapIconMap(MP, f, peer.mapID, peer.x, peer.y, true, true)
        end
    end
end

local function hookMenu()
    if menuHooked or not Menu or not Menu.ModifyMenu then return end
    menuHooked = true
    Menu.ModifyMenu("MENU_MINIMAP_TRACKING", function(_, root)
        if not Map.enabled then return end
        root:CreateDivider()
        root:CreateCheckbox(L["Guild members (TheGuild)"],
            function() return Map.db.minimap end,
            function() Map.db.minimap = not Map.db.minimap MP:Refresh() end)
    end)
end

function MP:Enable()
    hookMenu()
    TG:On("MAP_PEERS", function() MP:Refresh() end, Map)
    self:Refresh()
end

function MP:Disable()
    HBDPins:RemoveAllMinimapIcons(MP)
    releaseAll()
end
