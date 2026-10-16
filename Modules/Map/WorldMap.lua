local _, TG = ...
local L = TG.L
local UI = TG.UI
local Map = TG:GetModule("Map")
local HBD = LibStub("HereBeDragons-2.0")

local WM = {}
Map.WorldMap = WM

local MEMBER_TEMPLATE = "TheGuildMemberPinTemplate"
local MARKER_TEMPLATE = "TheGuildMarkerPinTemplate"

local GM_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local OFFICER_ICON = "Interface\\GroupFrame\\UI-Group-AssistantIcon"

function WM.Style(texture, classFile, peer, style)
    if style == "dot" then
        texture:SetTexture("Interface\\COMMON\\Indicator-Gray")
        texture:SetTexCoord(0, 1, 0, 1)
        local c = TG.ClassColor(classFile)
        texture:SetVertexColor(c.r, c.g, c.b)
    else
        TG.SetClassIcon(texture, classFile)
        texture:SetVertexColor(1, 1, 1)
    end
    texture:SetDesaturated(peer and peer.flags:find("d", 1, true) ~= nil)
end

function WM.Tooltip(tooltip, key, peer)
    local entry = TG.Roster:Get(key)
    if entry then
        UI.MemberTooltip(tooltip, entry)
    else
        GameTooltip_SetTitle(tooltip, key)
    end
    GameTooltip_AddBlankLineToTooltip(tooltip)
    GameTooltip_AddHighlightLine(tooltip, TG.MapName(peer.mapID))
    if peer.hp >= 0 then
        local color = peer.hp <= 30 and RED_FONT_COLOR or (peer.hp <= 60 and YELLOW_FONT_COLOR or GREEN_FONT_COLOR)
        GameTooltip_AddColoredLine(tooltip, ("%s: %d%%"):format(L["Health"], peer.hp), color)
    end
    if peer.flags:find("d", 1, true) then GameTooltip_AddColoredLine(tooltip, L["Dead"], RED_FONT_COLOR) end
    if peer.flags:find("i", 1, true) then GameTooltip_AddNormalLine(tooltip, L["In an instance"]) end
    if peer.flags:find("s", 1, true) then GameTooltip_AddNormalLine(tooltip, L["Stealthed"]) end
    GameTooltip_AddDisabledLine(tooltip, L["Updated %s ago"]:format(TG.FormatAge(GetTime() - peer.ts)))
end

function WM:Project(peer, mapID)
    if peer.mapID == mapID then return peer.x, peer.y end
    local x, y = HBD:TranslateZoneCoordinates(peer.x, peer.y, peer.mapID, mapID)
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
    return nil
end

function WM:Markers(mapID)
    local out = {}
    if Map.db.pins and Map.SharedPins then
        for _, m in ipairs(Map.SharedPins:ForMap(mapID)) do out[#out + 1] = m end
    end
    if Map.db.deaths and Map.Deaths then
        for _, m in ipairs(Map.Deaths:ForMap(mapID)) do out[#out + 1] = m end
    end
    return out
end

-- Data provider

TheGuildMapDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function TheGuildMapDataProviderMixin:OnAdded(mapCanvas)
    MapCanvasDataProviderMixin.OnAdded(self, mapCanvas)
    self.clickHandler = self.clickHandler or function(_, button, x, y) return WM:OnCanvasClick(button, x, y) end
    mapCanvas:AddCanvasClickHandler(self.clickHandler)
end

function TheGuildMapDataProviderMixin:OnRemoved(mapCanvas)
    mapCanvas:RemoveCanvasClickHandler(self.clickHandler)
    self:RemoveAllData()
    MapCanvasDataProviderMixin.OnRemoved(self, mapCanvas)
end

function TheGuildMapDataProviderMixin:RemoveAllData()
    local map = self:GetMap()
    map:RemoveAllPinsByTemplate(MEMBER_TEMPLATE)
    map:RemoveAllPinsByTemplate(MARKER_TEMPLATE)
end

function TheGuildMapDataProviderMixin:RefreshAllData()
    self:RemoveAllData()
    local map = self:GetMap()
    local mapID = map:GetMapID()
    if not mapID or not Map.enabled then return end
    if Map.db.worldMap then
        for key, peer in pairs(Map:Peers()) do
            if peer.hasPos then
                local x, y = WM:Project(peer, mapID)
                if x then
                    local pin = map:AcquirePin(MEMBER_TEMPLATE, key, peer)
                    pin:SetPosition(x, y)
                end
            end
        end
    end
    for _, marker in ipairs(WM:Markers(mapID)) do
        local pin = map:AcquirePin(MARKER_TEMPLATE, marker)
        pin:SetPosition(marker.x, marker.y)
    end
end

-- Member pin

TheGuildMemberPinMixin = CreateFromMixins(MapCanvasPinMixin)

function TheGuildMemberPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.4)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_GROUP_MEMBER")
end

function TheGuildMemberPinMixin:OnAcquired(key, peer)
    self.key, self.peer = key, peer
    local entry = TG.Roster:Get(key)
    local classFile = entry and entry.classFile
    local size = Map.db.worldSize
    self:SetSize(size, size)
    WM.Style(self.Icon, classFile, peer, Map.db.iconStyle)
    if Map.db.names then
        self.Label:SetText(TG.ClassText(classFile, TG.ShortName(key)))
        self.Label:Show()
    else
        self.Label:Hide()
    end
    if entry and entry.rankIndex == 0 then
        self.Badge:SetTexture(GM_ICON)
        self.Badge:Show()
    elseif entry and TG.Roster:IsOfficer(key) then
        self.Badge:SetTexture(OFFICER_ICON)
        self.Badge:Show()
    else
        self.Badge:Hide()
    end
end

function TheGuildMemberPinMixin:OnMouseEnter()
    self.Icon:SetAlpha(0.7)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    WM.Tooltip(GameTooltip, self.key, self.peer)
    GameTooltip:Show()
end

function TheGuildMemberPinMixin:OnMouseLeave()
    self.Icon:SetAlpha(1)
    GameTooltip:Hide()
end

function TheGuildMemberPinMixin:OnMouseClickAction(button)
    if button ~= "LeftButton" then return end
    local entry = TG.Roster:Get(self.key)
    if entry then UI.MemberMenu(self, entry) end
end

-- Marker pin (guild pins and deaths)

TheGuildMarkerPinMixin = CreateFromMixins(MapCanvasPinMixin)

function TheGuildMarkerPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.4)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_DEFAULT")
end

function TheGuildMarkerPinMixin:OnAcquired(marker)
    self.marker = marker
    self:SetSize(marker.size or 20, marker.size or 20)
    if marker.atlas and TG.HasAtlas(marker.atlas) then
        self.Icon:SetAtlas(marker.atlas)
    else
        self.Icon:SetTexture(marker.icon)
        self.Icon:SetTexCoord(0, 1, 0, 1)
    end
    self.Icon:SetDesaturated(false)
    self.Icon:SetVertexColor(1, 1, 1)
    self.Label:SetShown(false)
    self.Badge:Hide()
end

function TheGuildMarkerPinMixin:OnMouseEnter()
    self.Icon:SetAlpha(0.7)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.marker.tooltip then self.marker.tooltip(GameTooltip, self.marker) end
    GameTooltip:Show()
end

function TheGuildMarkerPinMixin:OnMouseLeave()
    self.Icon:SetAlpha(1)
    GameTooltip:Hide()
end

function TheGuildMarkerPinMixin:OnMouseClickAction(button)
    if self.marker.onClick then self.marker.onClick(self, button, self.marker) end
end

-- Provider management

local provider
local added = false
local refreshPending = false
local menusHooked = false

function WM:OnCanvasClick(button, x, y)
    if button == "RightButton" and IsControlKeyDown() and Map.db.pins and Map.SharedPins then
        Map.SharedPins:Prompt(WorldMapFrame:GetMapID(), x, y)
        return true
    end
    return false
end

function WM:Refresh()
    if not added or refreshPending then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    refreshPending = true
    TG.After(0.25, function()
        refreshPending = false
        if added and WorldMapFrame:IsShown() then provider:RefreshAllData() end
    end)
end

function WM:Ping(key)
    if not added or not WorldMapFrame:IsShown() then return end
    provider:RefreshAllData()
    for pin in WorldMapFrame:EnumeratePinsByTemplate(MEMBER_TEMPLATE) do
        if pin.key == key then
            provider:PingPin(pin)
            return
        end
    end
end

local function hookMenus()
    if menusHooked or not Menu or not Menu.ModifyMenu then return end
    menusHooked = true
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", function(_, root)
        if not Map.enabled then return end
        root:CreateDivider()
        root:CreateTitle(TG.title)
        local function toggle(label, key)
            root:CreateCheckbox(label,
                function() return Map.db[key] end,
                function() Map.db[key] = not Map.db[key] WM:Refresh() TG:Fire("MAP_PEERS") end)
        end
        toggle(L["Guild members"], "worldMap")
        toggle(L["Show names"], "names")
        toggle(L["Guild pins"], "pins")
        toggle(L["Death map"], "deaths")
    end)
end

function WM:Enable()
    if not WorldMapFrame then return end
    if not provider then provider = CreateFromMixins(TheGuildMapDataProviderMixin) end
    if not added then
        WorldMapFrame:AddDataProvider(provider)
        added = true
    end
    hookMenus()
    TG:On("MAP_PEERS", function() WM:Refresh() end, Map)
    TG:On("STORE_CHANGED", function(ns) if ns == "pin" or ns == "death" then WM:Refresh() end end, Map)
    TG:On("ROSTER_UPDATED", function() WM:Refresh() end, Map)
end

function WM:Disable()
    if added then
        WorldMapFrame:RemoveDataProvider(provider)
        added = false
    end
end
