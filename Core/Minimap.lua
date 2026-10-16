local _, TG = ...
local L = TG.L

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local Button = {}
TG.MinimapButton = Button

local function menu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetTag("MENU_THEGUILD_MINIMAP")
        root:CreateTitle(TG.title)
        root:CreateButton(L["Toggle window"], function() TG.Window:Toggle() end)
        local map = TG:GetModule("Map")
        if map and map.enabled then
            root:CreateCheckbox(L["Share my position"],
                function() return map:IsSharing() end,
                function() map:ToggleSharing() end)
        end
        local alerts = TG:GetModule("Alerts")
        if alerts and alerts.enabled then
            root:CreateButton(L["Call to Arms"], function() alerts:Prompt() end)
        end
        root:CreateDivider()
        root:CreateButton(L["Open settings"], function() TG:OpenSettings() end)
    end)
end

local function tooltip(tt)
    tt:AddLine(TG.title .. " |cff888888" .. TG.version .. "|r")
    local guild = TG.Roster:GuildName()
    if guild then
        local total, online = TG.Roster:Counts()
        tt:AddLine(TG.gold .. guild .. "|r")
        tt:AddLine(L["%d members online"]:format(online), 1, 1, 1)
        tt:AddLine(L["%d with TheGuild"]:format(TG.Comm:PeerCount() + 1), 1, 1, 1)
    else
        tt:AddLine(L["No guild"], 0.6, 0.6, 0.6)
    end
    tt:AddLine(" ")
    tt:AddLine(L["Left click: window. Right click: menu."], 0.6, 0.6, 0.6)
end

local function click(owner, button)
    if button == "RightButton" then
        menu(owner)
    else
        TG.Window:Toggle()
    end
end

local object = LDB:NewDataObject("TheGuild", {
    type = "launcher",
    text = TG.title,
    icon = TG.icon,
    OnClick = click,
    OnTooltipShow = tooltip,
})

function Button:Init()
    LDBIcon:Register("TheGuild", object, TG.db.global.minimap)
    self:Refresh()
end

function Button:Refresh()
    if TG.db.global.minimap.hide then LDBIcon:Hide("TheGuild") else LDBIcon:Show("TheGuild") end
end

function TheGuild_OnCompartmentClick(_, buttonName)
    click(AddonCompartmentFrame, buttonName)
end

function TheGuild_OnCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    tooltip(GameTooltip)
    GameTooltip:Show()
end

function TheGuild_OnCompartmentLeave()
    GameTooltip:Hide()
end
