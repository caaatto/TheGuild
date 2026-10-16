local TG = TheGuild
local L = TG.L
local Map = TG:GetModule("Map")

local SP = {}
Map.SharedPins = SP

local NS = "pin"
local MAX_LABEL = 40

StaticPopupDialogs["THEGUILD_PIN"] = {
    text = L["New guild pin"],
    button1 = L["Temporary (1 hour)"],
    button2 = CANCEL,
    button3 = L["Permanent"],
    hasEditBox = 1,
    maxLetters = MAX_LABEL,
    OnAccept = function(dialog, data)
        SP:Create(data, dialog:GetEditBox():GetText(), 3600)
    end,
    OnAlt = function(dialog, data)
        SP:Create(data, dialog:GetEditBox():GetText(), 0)
    end,
    EditBoxOnEnterPressed = function(editBox, data)
        SP:Create(data, editBox:GetText(), 3600)
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox)
        editBox:GetParent():Hide()
    end,
    OnShow = function(dialog)
        dialog:GetEditBox():SetText("")
        dialog:GetEditBox():SetFocus()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

function SP:Prompt(mapID, x, y)
    if not mapID or not x or not y then return end
    StaticPopup_Show("THEGUILD_PIN", nil, nil, { mapID = mapID, x = x, y = y })
end

function SP:Create(data, label, duration)
    label = TG.Trim(label):sub(1, MAX_LABEL)
    if label == "" then label = TG.MapName(data.mapID) end
    local now = TG.Now()
    local key = TG.MyName() .. "#" .. now
    TG.Store:Set(NS, key, {
        m = data.mapID,
        x = TG.Round(data.x, 4),
        y = TG.Round(data.y, 4),
        l = label,
        e = duration > 0 and (now + duration) or 0,
    })
end

local function canRemove(item)
    return item.a == TG.MyName() or TG.Roster:AmOfficer()
end

local function tooltip(tt, marker)
    local item = marker.item
    GameTooltip_SetTitle(tt, item.v.l)
    GameTooltip_AddNormalLine(tt, L["Pin by %s"]:format(item.a or "?"))
    if item.v.e and item.v.e > 0 then
        GameTooltip_AddDisabledLine(tt, L["Expires in %s"]:format(TG.FormatAge(item.v.e - TG.Now())))
    end
end

local function onClick(pin, button, marker)
    if button ~= "LeftButton" then return end
    MenuUtil.CreateContextMenu(pin, function(_, root)
        root:SetTag("MENU_THEGUILD_PIN")
        root:CreateTitle(marker.item.v.l)
        root:CreateButton(L["Set waypoint"], function() TG.SetWaypoint(marker.item.v.m, marker.x, marker.y) end)
        if canRemove(marker.item) then
            root:CreateButton(L["Remove pin"], function() TG.Store:Delete(NS, marker.key) end)
        end
    end)
end

function SP:ForMap(mapID)
    local out = {}
    local now = TG.Now()
    for key, item in pairs(TG.Store:Items(NS)) do
        local v = item.v
        if type(v) == "table" and v.m == mapID and (not v.e or v.e == 0 or v.e > now) then
            out[#out + 1] = {
                key = key, item = item, x = v.x, y = v.y,
                atlas = "Waypoint-MapPin-Untracked", icon = "Interface\\Minimap\\POIIcons",
                size = 24, tooltip = tooltip, onClick = onClick,
            }
        end
    end
    return out
end

function SP:Cleanup()
    local now = TG.Now()
    local me = TG.MyName()
    for key, item in pairs(TG.Store:Items(NS)) do
        local v = item.v
        if type(v) == "table" and v.e and v.e > 0 and v.e < now and item.a == me then
            TG.Store:Delete(NS, key)
        end
    end
end

function SP:Enable()
    TG.After(30, function() if Map.enabled then SP:Cleanup() end end)
    TG:On("MAP_HOURLY", function() SP:Cleanup() end, Map)
end
