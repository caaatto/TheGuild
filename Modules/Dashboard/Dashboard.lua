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
    { "guild", L["Guild changes"], { joined = true, left = true, rejoined = true, rank = true, note = true } },
    { "level", L["Level ups"], { level = true } },
    { "death", L["Deaths"], { death = true } },
    { "cta", L["Call to Arms"], { cta = true } },
}

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

local function build(panel)
    local left = CreateFrame("Frame", nil, panel)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 8)
    left:SetWidth(330)

    local emblem = CreateFrame("Frame", nil, left)
    emblem:SetSize(64, 64)
    emblem:SetPoint("TOPLEFT", left, "TOPLEFT", 4, -4)
    emblem.Background = emblem:CreateTexture(nil, "BACKGROUND")
    emblem.Background:SetAllPoints()
    emblem.Border = emblem:CreateTexture(nil, "BORDER")
    emblem.Border:SetAllPoints()
    emblem.Emblem = emblem:CreateTexture(nil, "ARTWORK")
    emblem.Emblem:SetPoint("CENTER")
    emblem.Emblem:SetSize(40, 40)

    local guildName = UI.Label(left, "", "GameFontNormalLarge")
    guildName:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 10, -4)
    guildName:SetPoint("RIGHT", left, "RIGHT", -4, 0)

    local stats = UI.Label(left, "", "GameFontHighlightSmall")
    stats:SetPoint("TOPLEFT", guildName, "BOTTOMLEFT", 0, -6)
    stats:SetPoint("RIGHT", left, "RIGHT", -4, 0)
    stats:SetSpacing(3)

    local motdTitle = UI.Label(left, L["Message of the day"], "GameFontNormal")
    motdTitle:SetPoint("TOPLEFT", emblem, "BOTTOMLEFT", 4, -16)

    local motd = UI.Label(left, "", "GameFontHighlightSmall")
    motd:SetPoint("TOPLEFT", motdTitle, "BOTTOMLEFT", 0, -4)
    motd:SetPoint("RIGHT", left, "RIGHT", -8, 0)
    motd:SetHeight(70)
    motd:SetJustifyV("TOP")
    motd:SetWordWrap(true)

    local buttons = {}
    local function addButton(text, fn)
        local b = UI.Button(left, text, 150, fn)
        local i = #buttons
        if i == 0 then
            b:SetPoint("TOPLEFT", motd, "BOTTOMLEFT", 0, -12)
        elseif i % 2 == 1 then
            b:SetPoint("LEFT", buttons[i], "RIGHT", 8, 0)
        else
            b:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, -6)
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

    local right = CreateFrame("Frame", nil, panel)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)

    local activityTitle = UI.Label(right, L["Recent activity"], "GameFontNormal")
    activityTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 6, -6)

    local export = UI.Button(right, L["Export"], 80, function()
        UI.TextDialog(L["Recent activity"], TG.Log:Export(currentFilter()))
    end)
    export:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -2)

    local filter = UI.Dropdown(right, 140, function(_, root)
        for _, f in ipairs(LOG_FILTERS) do
            root:CreateRadio(f[2], function() return Dashboard.db.logFilter == f[1] end, function()
                Dashboard.db.logFilter = f[1]
                panel:OnShow()
            end)
        end
    end)
    filter:SetPoint("RIGHT", export, "LEFT", -6, 0)
    filter:SetDefaultText(L["Everything"])

    local listFrame = CreateFrame("Frame", nil, right)
    listFrame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -28)
    listFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

    local empty = UI.Label(listFrame, L["Nothing happened yet."], "GameFontDisableSmall", "CENTER")
    empty:SetPoint("CENTER")

    local list = UI.List(listFrame, 20, function(button, item)
        button.time:SetText(date("%d.%m. %H:%M", item.t))
        button.text:SetText(TG.Log:Text(item))
    end, {
        buildRow = function(button)
            button.time = UI.Cell(button, 76, "LEFT", "GameFontDisableSmall")
            button.time:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.text = UI.Cell(button, 380)
            button.text:SetPoint("LEFT", button.time, "RIGHT", 4, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end,
    })

    local function updateEmblem()
        local ok = pcall(SetLargeGuildTabardTextures, "player", emblem.Emblem, emblem.Background, emblem.Border)
        emblem:SetShown(ok and IsInGuild())
    end

    function panel:OnShow()
        local guild = TG.Roster:GuildName()
        guildName:SetText(guild and (TG.gold .. guild .. "|r") or GRAY_FONT_COLOR:WrapTextInColorCode(L["No guild"]))
        updateEmblem()
        local total, online = TG.Roster:Counts()
        local me = TG.Roster:MyEntry()
        local map = TG:GetModule("Map")
        local lines = {
            ("%s: %d / %d"):format(L["Online members"], online, total),
            ("%s: %d"):format(L["Running TheGuild"], TG.Comm:PeerCount() + 1),
            ("%s: %s"):format(L["Your rank"], me and me.rank or "?"),
        }
        if map and map.enabled then
            lines[#lines + 1] = ("%s: %s"):format(L["Position sharing"], map:IsSharing() and GREEN_FONT_COLOR:WrapTextInColorCode(L["Online"]) or GRAY_FONT_COLOR:WrapTextInColorCode(L["Offline"]))
        end
        stats:SetText(table.concat(lines, "\n"))
        local text = C_GuildInfo and C_GuildInfo.GetMOTD and C_GuildInfo.GetMOTD()
        if not TG.usable(text) and GetGuildRosterMOTD then text = GetGuildRosterMOTD() end
        motd:SetText(TG.usable(text) and text ~= "" and text or GRAY_FONT_COLOR:WrapTextInColorCode("..."))
        shareButton:SetEnabled(map ~= nil and map.enabled)
        local items = TG.Log:Entries(currentFilter())
        empty:SetShown(#items == 0)
        list:SetData(items)
    end

    TG:On("LOG_ADDED", function() if panel:IsShown() then panel:OnShow() end end, Dashboard)
    TG:On("MAP_SHARING", function() if panel:IsShown() then panel:OnShow() end end, Dashboard)
    TG:RegisterEvent("GUILD_MOTD", function() if panel:IsShown() then panel:OnShow() end end, Dashboard)
end

TG.Window:RegisterTab("overview", L["Overview"], build, 1)
