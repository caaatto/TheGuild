local _, TG = ...
local L = TG.L

local Blizzard = {}
TG.Blizzard = Blizzard

-- Guild window tab

local communitiesTab

local function layoutCommunitiesTab()
    if not communitiesTab or not CommunitiesFrame then return end
    local club = CommunitiesFrame.GetSelectedClubInfo and CommunitiesFrame:GetSelectedClubInfo()
    local isGuild = club and club.clubType == Enum.ClubType.Guild
    local anchor = CommunitiesFrame.GuildInfoTab
    if CommunitiesFrame.GuildPreferredPlaySettingsTab and CommunitiesFrame.GuildPreferredPlaySettingsTab:IsShown() then
        anchor = CommunitiesFrame.GuildPreferredPlaySettingsTab
    end
    communitiesTab:ClearAllPoints()
    communitiesTab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
    communitiesTab:SetShown(isGuild and anchor:IsShown())
    communitiesTab:SetChecked(false)
end

local function hookCommunities()
    if communitiesTab or not CommunitiesFrame then return end
    communitiesTab = CreateFrame("CheckButton", "TheGuildCommunitiesTab", CommunitiesFrame, "RightSideTabTemplate")
    communitiesTab.iconTexture = TG.icon
    communitiesTab.tooltip = L["Open TheGuild"]
    communitiesTab.Icon:SetTexture(TG.icon)
    communitiesTab:SetFrameLevel(510)
    communitiesTab:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        self:SetChecked(false)
        TG.Window:Toggle()
    end)
    communitiesTab:SetScript("OnEnter", RightSideTabMixin.OnEnter)
    communitiesTab:SetScript("OnLeave", RightSideTabMixin.OnLeave or function() GameTooltip:Hide() end)
    hooksecurefunc(CommunitiesFrame, "SetDisplayMode", layoutCommunitiesTab)
    CommunitiesFrame:HookScript("OnShow", function() TG.After(0, layoutCommunitiesTab) end)
    if CommunitiesFrame.GuildPreferredPlaySettingsTab then
        CommunitiesFrame.GuildPreferredPlaySettingsTab:HookScript("OnShow", layoutCommunitiesTab)
        CommunitiesFrame.GuildPreferredPlaySettingsTab:HookScript("OnHide", layoutCommunitiesTab)
    end
    layoutCommunitiesTab()
end

-- Unit popup menus

local MENUS = { "COMMUNITIES_GUILD_MEMBER", "GUILD", "GUILD_OFFLINE", "FRIEND", "CHAT_ROSTER", "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "TARGET", "FOCUS" }

local function memberFromContext(contextData)
    if not contextData then return nil end
    local name = contextData.name
    if contextData.clubMemberInfo and contextData.clubMemberInfo.name then name = contextData.clubMemberInfo.name end
    if contextData.guid and TG.usable(contextData.guid) then
        local e = TG.Roster:GetByGUID(contextData.guid)
        if e then return e end
    end
    if contextData.unit and TG.usable(contextData.unit) then
        local guid = UnitGUID(contextData.unit)
        if TG.usable(guid) then
            local e = TG.Roster:GetByGUID(guid)
            if e then return e end
        end
    end
    if not TG.usable(name) then return nil end
    return TG.Roster:Find(name)
end

local function outsiderName(contextData)
    local unit = contextData and contextData.unit
    if not (unit and TG.usable(unit) and UnitIsPlayer(unit)) or UnitIsUnit(unit, "player") then return nil end
    local first, second = UnitFullName(unit)
    if not TG.usable(first) or not first then return nil end
    if TG.usable(second) and type(second) == "string" and second ~= "" then return first .. " " .. second end
    return first
end

local function modifyUnitMenu(owner, root, contextData)
    local entry = memberFromContext(contextData)
    if not entry then
        local name = outsiderName(contextData)
        if name then
            root:CreateDivider()
            root:CreateTitle(TG.title)
            TG:Fire("UNIT_MENU", root, name)
        end
        return
    end
    if TG.IsMe(entry.key) then return end
    local map = TG:GetModule("Map")
    local hasPos = map and map.enabled and map:HasPosition(entry.key)
    root:CreateDivider()
    root:CreateTitle(TG.title)
    if hasPos then
        root:CreateButton(L["Show on map"], function() map:ShowOnMap(entry.key) end)
    end
    TG:Fire("MEMBER_MENU", root, entry)
end

local function hookUnitMenus()
    if not Menu or not Menu.ModifyMenu then return end
    for _, which in ipairs(MENUS) do
        Menu.ModifyMenu("MENU_UNIT_" .. which, modifyUnitMenu)
    end
end

-- Unit tooltip

local function onUnitTooltip(tooltip, data)
    if tooltip ~= GameTooltip or not data or not TG.usable(data.guid) then return end
    local entry = TG.Roster:GetByGUID(data.guid)
    if not entry then return end
    local parts = {}
    local role = TG.Store:Get("role", entry.key)
    if role then parts[#parts + 1] = TG.RoleIconMarkup(role, 12) .. " " .. (TG.ROLE_NAMES[role] or role) end
    local main = TG.Store:Get("alt", entry.key)
    if main then parts[#parts + 1] = L["Main"] .. ": " .. main end
    local version = TG.Comm:PeerVersion(entry.key)
    if version then parts[#parts + 1] = TG.title .. " " .. version end
    if #parts > 0 then
        GameTooltip_AddColoredLine(tooltip, table.concat(parts, "  "), LIGHTBLUE_FONT_COLOR)
    end
end

function Blizzard:Init()
    hookUnitMenus()
    if TooltipDataProcessor and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            TG.SafeCall(onUnitTooltip, tooltip, data)
        end)
    end
    if C_AddOns.IsAddOnLoaded("Blizzard_Communities") then
        hookCommunities()
    else
        TG:RegisterEvent("ADDON_LOADED", function(_, name)
            if name == "Blizzard_Communities" then hookCommunities() end
        end)
    end
end
