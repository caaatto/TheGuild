local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Map = TG:GetModule("Map")

local columns = {
    { key = "name", text = L["Name"], width = 200 },
    { key = "level", text = L["Level"], width = 50, justify = "CENTER" },
    { key = "zone", text = L["Zone"], width = 220, stretch = true },
    { key = "health", text = L["Health"], width = 70, justify = "CENTER" },
    { key = "age", text = L["Last seen"], width = 90, justify = "RIGHT" },
}

local function rows()
    local out = {}
    for key, peer in pairs(Map:Peers()) do
        local entry = TG.Roster:Get(key)
        out[#out + 1] = { key = key, peer = peer, entry = entry }
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    local me = TG.MyName()
    if me and Map.cdb.share and TG.InGuild() then
        local snap = Map:Snapshot()
        if snap then
            snap.ts = GetTime()
            snap.hasPos = snap.x > 0 and snap.y > 0 and not snap.flags:find("[is]")
            table.insert(out, 1, { key = me, peer = snap, entry = TG.Roster:Get(me), me = true })
        end
    end
    return out
end

local function build(panel)
    local share = UI.Checkbox(panel, L["Share my position"], function(checked)
        if Map.cdb.share ~= checked then Map:ToggleSharing() end
    end)
    share:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)

    local status = UI.Label(panel, "", "GameFontHighlightSmall")
    status:SetPoint("LEFT", share.Text, "RIGHT", 24, 0)

    local hint = UI.Label(panel, L["Ctrl + right click on the map places a guild pin."], "GameFontDisableSmall", "RIGHT")
    hint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -12)

    local openMap = UI.Button(panel, L["Open map"], 110, function() ToggleWorldMap() end)
    openMap:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -32)

    local header = UI.Header(panel, columns)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -60)
    header:SetPoint("RIGHT", panel, "RIGHT", -28, 0)

    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -1)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)

    local list = UI.List(listFrame, 22, function(button, data)
        local peer, entry = data.peer, data.entry
        TG.SetClassIcon(button.icon, entry and entry.classFile)
        button.cells.name:SetText(TG.ClassText(entry and entry.classFile, data.key) .. (data.me and (" " .. GRAY_FONT_COLOR:WrapTextInColorCode(L["you"])) or ""))
        button.cells.level:SetText(entry and entry.level or "")
        local zone = TG.MapName(peer.mapID)
        if peer.flags:find("i", 1, true) then zone = zone .. " (" .. L["In an instance"] .. ")" end
        if peer.flags:find("s", 1, true) then zone = L["Stealthed"] end
        button.cells.zone:SetText(zone)
        button.cells.health:SetText(peer.hp >= 0 and (peer.hp .. "%") or (peer.gm and GRAY_FONT_COLOR:WrapTextInColorCode("GuildMap") or ""))
        button.cells.age:SetText(TG.FormatAge(GetTime() - peer.ts))
        button.data = data
    end, {
        inset = true,
        buildRow = function(button)
            button.icon = UI.ClassIcon(button, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.cells = UI.Cells(button, columns)
            button.cells.name:ClearAllPoints()
            button.cells.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
            button.cells.name.tgManual = true
            button.cells.name.tgInset = 30
            button:SetScript("OnClick", function(self, mouse)
                if not self.data then return end
                if mouse == "RightButton" then
                    if self.data.entry then UI.MemberMenu(self, self.data.entry) end
                elseif self.data.me then
                    ToggleWorldMap()
                elseif self.data.peer.hasPos then
                    Map:ShowOnMap(self.data.key)
                end
            end)
            button:SetScript("OnEnter", function(self)
                if not self.data then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                Map.WorldMap.Tooltip(GameTooltip, self.data.key, self.data.peer)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
    })

    TG.Tutorial:Define("map", {
        { target = share, text = L["Your position goes to guild members only while this is on and you move, never from inside an instance."], point = "bottom" },
        { target = openMap, text = L["Members appear on the world map and the minimap. Ctrl + right click on the world map places a guild pin for everyone."], point = "bottom" },
        { target = listFrame, text = L["Everybody who shares a position right now. Click a row to show that member on the map."], point = "top" },
    })

    function panel:OnShow()
        share:SetChecked(Map.cdb.share)
        local data = rows()
        if #data == 0 then
            status:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(L["Nobody shares a position right now."]))
        else
            status:SetText(L["Known positions"] .. ": " .. #data)
        end
        list:SetData(data)
    end

    TG:On("MAP_PEERS", function() if panel:IsShown() then panel:OnShow() end end, Map)
    TG:On("MAP_SHARING", function() if panel:IsShown() then share:SetChecked(Map.cdb.share) end end, Map)
end

TG.Window:RegisterTab("map", L["Map"], build, 20, "Interface\\Icons\\INV_Misc_Map_01", "Map")