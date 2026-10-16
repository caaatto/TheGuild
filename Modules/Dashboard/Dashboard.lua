local TG = TheGuild
local L = TG.L
local UI = TG.UI

local Dashboard = TG:NewModule("Dashboard", {
    title = L["Overview"],
    desc = L["Recent activity"],
    order = 5,
    defaults = { logFilter = "all" },
})

local LOG_FILTERS = {
    { "all", L["Everything"], nil },
    { "presence", L["Logins"], { online = true, offline = true } },
    { "guild", L["Guild changes"], { joined = true, left = true, rejoined = true, rank = true, note = true, post = true, poll = true, event = true, bounty = true, recruited = true } },
    { "level", L["Level ups"], { level = true } },
    { "death", L["Deaths"], { death = true } },
    { "found", L["Loot finds"], { found = true } },
    { "cta", L["Call to Arms"], { cta = true } },
}

local LEFT_WIDTH = 300

local function currentFilter()
    for _, f in ipairs(LOG_FILTERS) do
        if f[1] == Dashboard.db.logFilter then
            local kinds = f[3]
            if not kinds then return nil end
            return function(item) return kinds[item.kind] == true end
        end
    end
    return nil
end

local function filterName()
    for _, f in ipairs(LOG_FILTERS) do
        if f[1] == Dashboard.db.logFilter then return f[2] end
    end
    return L["Everything"]
end

local function build(panel)
    local left = CreateFrame("Frame", nil, panel)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -6)
    left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 6)
    left:SetWidth(LEFT_WIDTH)

    local banner = UI.Banner(left)
    banner:SetPoint("TOP", left, "TOP", 0, -4)

    local guildName = UI.Label(left, "", "GameFontNormalLarge", "CENTER")
    guildName:SetPoint("TOP", banner, "BOTTOM", 0, -6)
    guildName:SetPoint("LEFT", left, "LEFT", 4, 0)
    guildName:SetPoint("RIGHT", left, "RIGHT", -4, 0)
    guildName:SetWordWrap(false)

    local rankText = UI.Label(left, "", "GameFontHighlightSmall", "CENTER")
    rankText:SetPoint("TOP", guildName, "BOTTOM", 0, -3)
    rankText:SetPoint("LEFT", left, "LEFT", 4, 0)
    rankText:SetPoint("RIGHT", left, "RIGHT", -4, 0)

    local tiles = {}
    local tileWidth = (LEFT_WIDTH - 2 * 6) / 3
    for i, label in ipairs({ L["Online"], L["Members"], L["With addon"] }) do
        local tile = UI.Stat(left, label, tileWidth)
        tile:SetPoint("TOPLEFT", left, "TOPLEFT", (i - 1) * (tileWidth + 6), -206)
        tiles[i] = tile
    end

    local upcomingHeader = UI.SectionHeader(left, L["Upcoming"])
    upcomingHeader:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -270)
    upcomingHeader:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    local upcoming = UI.Label(left, "", "GameFontHighlightSmall")
    upcoming:SetPoint("TOPLEFT", upcomingHeader, "BOTTOMLEFT", 8, -6)
    upcoming:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    upcoming:SetHeight(48)
    upcoming:SetJustifyV("TOP")
    upcoming:SetWordWrap(true)
    upcoming:SetSpacing(3)

    local motdHeader = UI.SectionHeader(left, L["Message of the day"])
    motdHeader:SetPoint("TOPLEFT", upcoming, "BOTTOMLEFT", -8, -8)
    motdHeader:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    local motdCard = UI.Card(left)
    motdCard:SetPoint("TOPLEFT", motdHeader, "BOTTOMLEFT", 0, -4)
    motdCard:SetPoint("RIGHT", left, "RIGHT", 0, 0)
    motdCard:SetHeight(66)
    local motd = UI.Label(motdCard, "", "GameFontHighlightSmall")
    motd:SetPoint("TOPLEFT", motdCard, "TOPLEFT", 8, -7)
    motd:SetPoint("BOTTOMRIGHT", motdCard, "BOTTOMRIGHT", -8, 7)
    motd:SetJustifyV("TOP")
    motd:SetWordWrap(true)

    local actionsHeader = UI.SectionHeader(left, L["Quick actions"])
    actionsHeader:SetPoint("TOPLEFT", motdCard, "BOTTOMLEFT", 0, -8)
    actionsHeader:SetPoint("RIGHT", left, "RIGHT", 0, 0)

    local buttons = {}
    local function addButton(text, fn)
        local b = UI.Button(left, text, (LEFT_WIDTH - 6) / 2, fn)
        local i = #buttons
        if i == 0 then
            b:SetPoint("TOPLEFT", actionsHeader, "BOTTOMLEFT", 0, -6)
        elseif i % 2 == 1 then
            b:SetPoint("LEFT", buttons[i], "RIGHT", 6, 0)
        else
            b:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, -4)
        end
        buttons[#buttons + 1] = b
        return b
    end
    addButton(L["Call to Arms"], function()
        local alerts = TG:GetModule("Alerts")
        if alerts and alerts.enabled then alerts:Prompt() end
    end)
    addButton(L["Open map"], function() ToggleWorldMap() end)
    local shareButton = addButton(L["Position sharing"], function()
        local map = TG:GetModule("Map")
        if map and map.enabled then map:ToggleSharing() panel:OnShow() end
    end)
    addButton(L["Open settings"], function() TG:OpenSettings() end)
    addButton(L["Help"], function() UI.TextDialog(L["Help"], TG:HelpText()) end)

    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 6)

    local activityHeader = UI.SectionHeader(right, L["Recent activity"])
    activityHeader:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
    activityHeader:SetPoint("RIGHT", right, "RIGHT", 0, 0)

    local export = UI.Button(right, L["Export"], 80, function()
        UI.TextDialog(L["Recent activity"], TG.Log:Export(currentFilter()))
    end)
    export:SetPoint("TOPRIGHT", activityHeader, "BOTTOMRIGHT", 0, -6)

    local filter = UI.Dropdown(right, 150, function(_, root)
        for _, f in ipairs(LOG_FILTERS) do
            root:CreateRadio(f[2], function() return Dashboard.db.logFilter == f[1] end, function()
                Dashboard.db.logFilter = f[1]
                panel:OnShow()
            end)
        end
    end)
    filter:SetPoint("TOPLEFT", activityHeader, "BOTTOMLEFT", 0, -6)
    filter:SetDefaultText(L["Everything"])

    local listFrame = CreateFrame("Frame", nil, right)
    listFrame:SetPoint("TOPLEFT", filter, "BOTTOMLEFT", 0, -6)
    listFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

    local empty = UI.Empty(listFrame, L["Nothing happened yet."])

    local list = UI.List(listFrame, 22, function(button, item)
        button.icon:SetTexture(UI.KIND_ICONS[item.kind] or TG.icon)
        if item.kind == "online" or item.kind == "offline" or item.kind == "death" then
            button.icon:SetTexCoord(0, 1, 0, 1)
        else
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        button.time:SetText(date("%d.%m. %H:%M", item.t))
        button.text:SetText(TG.Log:Text(item))
    end, {
        inset = true,
        buildRow = function(button)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetSize(16, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.time = UI.Cell(button, 74, "LEFT", "GameFontDisableSmall")
            button.time:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
            button.text = UI.Cell(button, 380)
            button.text:SetPoint("LEFT", button.time, "RIGHT", 2, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        end,
    })

    function panel:OnShow()
        local guild = TG.Roster:GuildName()
        guildName:SetText(guild and (TG.gold .. guild .. "|r") or GRAY_FONT_COLOR:WrapTextInColorCode(L["No guild"]))
        banner:Update()
        local total, online = TG.Roster:Counts()
        local me = TG.Roster:MyEntry()
        local map = TG:GetModule("Map")
        rankText:SetText(me and me.rank and (L["Your rank"] .. ": " .. me.rank) or "")
        tiles[1]:SetValue(online)
        tiles[2]:SetValue(total)
        tiles[3]:SetValue(TG.Comm:PeerCount() + 1)

        local lines = {}
        local raids = TG:GetModule("Raids")
        local nextRaid = raids and raids.enabled and raids.NextRaid and raids:NextRaid()
        if nextRaid then
            lines[#lines + 1] = ("%s%s:|r %s"):format(TG.gold, L["Next raid"], raids:FormatRaid(nextRaid, true))
        end
        local board = TG:GetModule("Board")
        local nextEvent = board and board.enabled and board.NextEvent and board:NextEvent()
        if nextEvent then
            lines[#lines + 1] = ("%s%s:|r %s"):format(TG.gold, L["Next event"], board:FormatEvent(nextEvent, true))
        end
        local openBounties = board and board.enabled and board.OpenBountyCount and board:OpenBountyCount() or 0
        if openBounties > 0 then lines[#lines + 1] = L["%d open bounties"]:format(openBounties) end
        if map and map.enabled then
            lines[#lines + 1] = ("%s%s:|r %s"):format(TG.gold, L["Position sharing"], map:IsSharing() and GREEN_FONT_COLOR:WrapTextInColorCode(L["Online"]) or GRAY_FONT_COLOR:WrapTextInColorCode(L["Offline"]))
        end
        upcoming:SetText(#lines > 0 and table.concat(lines, "\n") or GRAY_FONT_COLOR:WrapTextInColorCode(L["Nothing planned."]))

        local text = C_GuildInfo and C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()
        if not TG.usable(text) and GetGuildRosterMOTD then text = GetGuildRosterMOTD() end
        motd:SetText(TG.usable(text) and text ~= "" and text or GRAY_FONT_COLOR:WrapTextInColorCode("..."))
        shareButton:SetEnabled(map ~= nil and map.enabled)
        filter:SetDefaultText(filterName())
        local items = TG.Log:Entries(currentFilter())
        empty:SetShown(#items == 0)
        list:SetData(items)
    end

    TG:On("LOG_ADDED", function() if panel:IsShown() then panel:OnShow() end end, Dashboard)
    TG:On("MAP_SHARING", function() if panel:IsShown() then panel:OnShow() end end, Dashboard)
    TG:RegisterEvent("GUILD_MOTD", function() if panel:IsShown() then panel:OnShow() end end, Dashboard)
end

TG.Window:RegisterTab("overview", L["Overview"], build, 1, TG.icon)
