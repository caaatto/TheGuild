local TG = TheGuild
local L = TG.L
local UI = TG.UI

local Roster = TG:NewModule("Roster", {
    title = L["Members"],
    desc = L["Members may set their own role and alt links. Officers may set them for anyone."],
    order = 20,
    defaults = { showOffline = true, sort = "rank", asc = true },
})

local columns = {
    { key = "name", text = L["Name"], width = 190 },
    { key = "level", text = L["Level"], width = 46, justify = "CENTER" },
    { key = "rank", text = L["Rank"], width = 110 },
    { key = "zone", text = L["Zone"], width = 170, stretch = true },
    { key = "role", text = L["Role"], width = 56, justify = "CENTER" },
    { key = "main", text = L["Main"], width = 120 },
    { key = "note", text = L["Note"], width = 110 },
}

local filterText = ""
local filterMode = "all"

local FILTERS = {
    { "all", L["All members"] },
    { "officers", L["Officers"] },
    { "norole", L["Without role"] },
    { "addon", L["With addon"] },
    { "inactive14", L["Inactive %d days"]:format(14) },
    { "inactive30", L["Inactive %d days"]:format(30) },
}

local function passesFilter(e)
    if filterMode == "officers" then return TG.Roster:IsOfficer(e.key) end
    if filterMode == "norole" then return TG.Store:Get("role", e.key) == nil end
    if filterMode == "addon" then return e.online and TG.Comm:HasAddon(e.key) end
    if filterMode == "inactive14" or filterMode == "inactive30" then
        local days = filterMode == "inactive14" and 14 or 30
        if e.online then return false end
        return e.lastSeen ~= nil and (TG.Now() - e.lastSeen) > days * 86400
    end
    return true
end

local function matches(e, text)
    if text == "" then return true end
    text = text:lower()
    return (e.key:lower():find(text, 1, true)
        or (e.zone and e.zone:lower():find(text, 1, true))
        or (e.rank and e.rank:lower():find(text, 1, true))
        or (e.note and e.note:lower():find(text, 1, true))
        or TG.ClassName(e.classFile):lower():find(text, 1, true)) ~= nil
end

local sorters = {
    name = function(a, b) return a.key < b.key end,
    level = function(a, b) if a.level ~= b.level then return a.level > b.level end return a.key < b.key end,
    rank = function(a, b) if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end return a.key < b.key end,
    zone = function(a, b) local za, zb = a.zone or "", b.zone or "" if za ~= zb then return za < zb end return a.key < b.key end,
    role = function(a, b)
        local ra, rb = TG.Store:Get("role", a.key) or "Z", TG.Store:Get("role", b.key) or "Z"
        if ra ~= rb then return ra < rb end
        return a.key < b.key
    end,
    main = function(a, b)
        local ma, mb = TG.Store:Get("alt", a.key) or a.key, TG.Store:Get("alt", b.key) or b.key
        if ma ~= mb then return ma < mb end
        return a.key < b.key
    end,
    note = function(a, b) local na, nb = a.note or "", b.note or "" if na ~= nb then return na < nb end return a.key < b.key end,
}

function Roster:Rows()
    local out = {}
    for _, e in ipairs(TG.Roster:Members()) do
        if (e.online or self.db.showOffline or filterMode:find("inactive")) and matches(e, filterText) and passesFilter(e) then out[#out + 1] = e end
    end
    local sorter = sorters[self.db.sort] or sorters.rank
    table.sort(out, function(a, b)
        if a.online ~= b.online then return a.online end
        if self.db.asc then return sorter(a, b) end
        return sorter(b, a)
    end)
    return out
end

local function roleMenu(root, entry)
    if not TG.Store:CanWrite("role", entry.key) then return end
    local current = TG.Store:Get("role", entry.key)
    local sub = root:CreateButton(L["Set role"])
    for _, role in ipairs(TG.ROLE_ORDER) do
        sub:CreateRadio(TG.RoleIconMarkup(role, 14) .. " " .. TG.ROLE_NAMES[role],
            function() return current == role end,
            function() TG.Store:Set("role", entry.key, role) end)
    end
    sub:CreateRadio(L["None"],
        function() return current == nil end,
        function() TG.Store:Delete("role", entry.key) end)
end

local function altMenu(root, entry)
    if not TG.Store:CanWrite("alt", entry.key) then return end
    root:CreateButton(L["Link as alt of"], function()
        StaticPopup_ShowCustomGenericInputBox({
            text = L["Choose a main for %s"]:format(entry.key),
            acceptText = ACCEPT,
            cancelText = CANCEL,
            maxLetters = 48,
            callback = function(text)
                local main = TG.Roster:Find(TG.Trim(text))
                if main and main.key ~= entry.key then
                    TG.Store:Set("alt", entry.key, main.key)
                end
            end,
        })
    end)
    if TG.Store:Get("alt", entry.key) then
        root:CreateButton(L["Remove alt link"], function() TG.Store:Delete("alt", entry.key) end)
    end
end

local function noteMenu(root, entry)
    if not entry.guid or not CanEditPublicNote or not CanEditPublicNote() then return end
    if not (C_GuildInfo and C_GuildInfo.SetNote) then return end
    root:CreateButton(L["Edit public note"], function()
        StaticPopup_Show("THEGUILD_NOTE", entry.key, nil, entry)
    end)
end

StaticPopupDialogs["THEGUILD_NOTE"] = {
    text = L["Public note for %s"],
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 31,
    OnShow = function(dialog, entry)
        dialog:GetEditBox():SetText(entry.note or "")
        dialog:GetEditBox():HighlightText()
        dialog:GetEditBox():SetFocus()
    end,
    OnAccept = function(dialog, entry)
        local text = dialog:GetEditBox():GetText()
        if pcall(C_GuildInfo.SetNote, entry.guid, text, true) then
            TG.Log:Add("note", entry.key)
            TG.Roster:Request()
        end
    end,
    EditBoxOnEnterPressed = function(editBox, entry)
        local text = editBox:GetText()
        if pcall(C_GuildInfo.SetNote, entry.guid, text, true) then
            TG.Log:Add("note", entry.key)
            TG.Roster:Request()
        end
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local function build(panel)
    local search = UI.SearchBox(panel, 180, function(text)
        filterText = text
        panel:OnShow()
    end)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    panel.search = search

    local filter = UI.Dropdown(panel, 150, function(_, root)
        for _, f in ipairs(FILTERS) do
            root:CreateRadio(f[2], function() return filterMode == f[1] end, function() filterMode = f[1] panel:OnShow() end)
        end
    end)
    filter:SetPoint("LEFT", search, "RIGHT", 10, 0)
    filter:SetDefaultText(L["All members"])

    local offline = UI.Checkbox(panel, L["Show offline members"], function(checked)
        Roster.db.showOffline = checked
        panel:OnShow()
    end)
    offline:SetPoint("LEFT", filter, "RIGHT", 10, 0)

    local suggest = UI.Button(panel, L["Alt suggestions"], 130, function() TG.AltSuggestions:Open() end)
    suggest:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local counts = UI.Label(panel, "", "GameFontHighlightSmall", "RIGHT")
    counts:SetPoint("RIGHT", suggest, "LEFT", -12, 0)

    local header = UI.Header(panel, columns, function(key)
        if Roster.db.sort == key then Roster.db.asc = not Roster.db.asc else Roster.db.sort, Roster.db.asc = key, true end
        panel:OnShow()
    end)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -36)
    header:SetPoint("RIGHT", panel, "RIGHT", -28, 0)

    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -1)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)

    local list = UI.List(listFrame, 20, function(button, e)
        button.entry = e
        TG.SetClassIcon(button.icon, e.classFile)
        button.icon:SetDesaturated(not e.online)
        local name = TG.ClassText(e.classFile, e.key)
        if not e.online then name = GRAY_FONT_COLOR:WrapTextInColorCode(e.key) end
        button.cells.name:SetText(name)
        button.cells.level:SetText(e.level or "")
        button.cells.rank:SetText(e.rank or "")
        button.cells.zone:SetText(e.online and (e.zone or "") or "")
        local role = TG.Store:Get("role", e.key)
        button.cells.role:SetText(role and TG.RoleIconMarkup(role, 14) or "")
        local main = TG.Store:Get("alt", e.key)
        button.cells.main:SetText(main or "")
        button.cells.note:SetText(e.note or "")
        if TG.Comm:HasAddon(e.key) and e.online then
            button.addon:Show()
        else
            button.addon:Hide()
        end
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
            button.addon = button:CreateTexture(nil, "OVERLAY")
            button.addon:SetSize(10, 10)
            button.addon:SetTexture(TG.icon)
            button.addon:SetPoint("RIGHT", button, "RIGHT", -6, 0)
            button:SetScript("OnClick", function(self, mouse)
                if not self.entry then return end
                if mouse == "RightButton" then
                    UI.MemberMenu(self, self.entry)
                else
                    TG.Whisper(self.entry.key)
                end
            end)
            button:SetScript("OnEnter", function(self)
                if not self.entry then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                UI.MemberTooltip(GameTooltip, self.entry)
                if self.entry.lastSeen and not self.entry.online then
                    GameTooltip_AddDisabledLine(GameTooltip, L["Last seen"] .. ": " .. TG.FormatAge(TG.Now() - self.entry.lastSeen))
                end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
    })

    TG.Tutorial:Define("members", {
        { target = search, text = L["Search by name, class, rank or note. Ctrl + F jumps here."], point = "bottom" },
        { target = filter, text = L["Filters for officers, inactive members and missing roles."], point = "bottom" },
        { target = offline, text = L["Shows or hides members who are offline."], point = "bottom" },
        { target = suggest, text = L["Officers get alt suggestions read from public notes and link them with one click."], point = "bottom" },
        { target = listFrame, text = L["Click a column header to sort. Right click any member for whisper, invite, show on map, role and main or alt links."], point = "top" },
    })

    function panel:OnShow()
        offline:SetChecked(Roster.db.showOffline)
        suggest:SetShown(TG.Roster:AmOfficer())
        local total, online = TG.Roster:Counts()
        counts:SetText(L["%d of %d online"]:format(online, total))
        header:SetSort(Roster.db.sort, Roster.db.asc)
        list:SetData(Roster:Rows())
    end

    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Roster)
    TG:On("STORE_CHANGED", function(ns) if panel:IsShown() and (ns == "role" or ns == "alt") then panel:OnShow() end end, Roster)
    TG:On("PEER_HELLO", function() if panel:IsShown() then list:Refresh() end end, Roster)
end

function Roster:OnEnable()
    self:On("MEMBER_MENU", function(root, entry)
        root:CreateDivider()
        roleMenu(root, entry)
        altMenu(root, entry)
        noteMenu(root, entry)
    end)
    TG.History:Enable(self)
    self:On("MEMBER_TOOLTIP", function(tooltip, entry)
        local role = TG.Store:Get("role", entry.key)
        local main = TG.Store:Get("alt", entry.key)
        if role or main then
            local parts = {}
            if role then parts[#parts + 1] = TG.RoleIconMarkup(role, 12) .. " " .. TG.ROLE_NAMES[role] end
            if main then parts[#parts + 1] = L["Main"] .. ": " .. main end
            GameTooltip_AddColoredLine(tooltip, table.concat(parts, "   "), LIGHTBLUE_FONT_COLOR)
        end
        local alts = {}
        for key, item in pairs(TG.Store:Items("alt")) do
            if item.v == entry.key then alts[#alts + 1] = key end
        end
        if #alts > 0 then
            table.sort(alts)
            GameTooltip_AddColoredLine(tooltip, L["Alts"] .. ": " .. table.concat(alts, ", "), LIGHTBLUE_FONT_COLOR, true)
        end
    end)
end

TG.Window:RegisterTab("members", L["Members"], build, 10, "Interface\\Icons\\INV_Misc_GroupLooking", "Roster")