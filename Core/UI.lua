local _, TG = ...
local L = TG.L

local UI = {}
TG.UI = UI

local HIGHLIGHT = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar"
local SELECTED = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar-Blue"
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local GUILD_PARTS = "Interface\\GuildFrame\\GuildFrame"

UI.STATUS_ICONS = {
    online = "Interface\\FriendsFrame\\StatusIcon-Online",
    offline = "Interface\\FriendsFrame\\StatusIcon-Offline",
    away = "Interface\\FriendsFrame\\StatusIcon-Away",
    dnd = "Interface\\FriendsFrame\\StatusIcon-DnD",
}

UI.KIND_ICONS = {
    online = UI.STATUS_ICONS.online,
    offline = UI.STATUS_ICONS.offline,
    joined = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    rejoined = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend_Rank2",
    left = "Interface\\Icons\\Spell_Shadow_Teleport",
    renamed = "Interface\\Icons\\INV_Scroll_11",
    level = "Interface\\Icons\\Achievement_Level_10",
    rank = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention",
    death = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
    cta = "Interface\\Icons\\Ability_Warrior_BattleShout",
    note = "Interface\\Icons\\INV_Misc_Note_05",
    raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    found = "Interface\\Icons\\INV_Misc_Bag_10",
    post = "Interface\\Icons\\INV_Misc_Note_01",
    poll = "Interface\\Icons\\INV_Scroll_03",
    event = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    bounty = "Interface\\Icons\\INV_Misc_Coin_02",
    recruited = "Interface\\Icons\\Achievement_GuildPerk_FastTrack",
}

function UI.HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- Text

function UI.Label(parent, text, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

function UI.Cell(button, width, justify, template)
    local fs = button:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- The guild frame header strip with a small caption, used above every section.
function UI.SectionHeader(parent, text, width)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(18)
    if width then header:SetWidth(width) end
    header.Background = header:CreateTexture(nil, "BACKGROUND")
    header.Background:SetAllPoints()
    header.Background:SetTexture(GUILD_PARTS)
    header.Background:SetTexCoord(0.63183594, 0.94531250, 0.57617188, 0.61523438)
    header.Text = UI.Label(header, text, "GameFontNormalSmall")
    header.Text:SetPoint("LEFT", header, "LEFT", 8, 0)
    header.Text:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    header.Right = UI.Label(header, "", "GameFontHighlightSmall", "RIGHT")
    header.Right:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    function header:SetText(t) self.Text:SetText(t) end
    function header:SetRightText(t) self.Right:SetText(t or "") end
    return header
end

function UI.Divider(parent, width)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    if UI.HasAtlas("perks-divider") then
        tex:SetAtlas("perks-divider", true)
        if width then tex:SetWidth(width) end
    else
        tex:SetColorTexture(1, 0.82, 0, 0.25)
        tex:SetSize(width or 200, 1)
    end
    return tex
end

function UI.Empty(parent, text)
    local fs = UI.Label(parent, text, "GameFontDisable", "CENTER")
    fs:SetPoint("CENTER")
    fs:SetWidth(360)
    fs:SetWordWrap(true)
    return fs
end

-- Containers

-- Bordered dark panel in the style of the Blizzard tooltip backdrop.
function UI.Card(parent, title)
    local card = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
    if title then
        card.Title = UI.Label(card, title, "GameFontNormal")
        card.Title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        card.Title:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    end
    return card
end

function UI.Inset(parent)
    return CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
end

-- Inset border around a list, as the Blizzard member lists have it.
function UI.ListBox(parent)
    local box = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    if box.Bg then box.Bg:Hide() end
    box.Content = CreateFrame("Frame", nil, box)
    box.Content:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -2)
    box.Content:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, 2)
    return box
end

-- Controls

function UI.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(text)
    b:SetWidth(width or math.max(80, b:GetTextWidth() + 30))
    b:SetHeight(22)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- Square button with an icon, the Blizzard square button art.
function UI.IconButton(parent, icon, tooltip, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelSquareButton")
    b:SetSize(24, 24)
    if b.icon then
        b.icon:SetTexture(icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon:SetSize(16, 16)
    end
    if onClick then b:SetScript("OnClick", onClick) end
    if tooltip then
        UI.Tooltip(b, function(tt)
            if type(tooltip) == "function" then tooltip(tt) else GameTooltip_SetTitle(tt, tooltip) end
        end)
    end
    return b
end

function UI.Checkbox(parent, label, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    if cb.Text then
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlight")
    else
        cb.Text = UI.Label(cb, label, "GameFontHighlight")
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    if onClick then
        cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false, self) end)
    end
    return cb
end

function UI.SearchBox(parent, width, onChanged)
    local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    box:SetSize(width or 160, 20)
    box:SetAutoFocus(false)
    box:HookScript("OnTextChanged", function(self, userInput)
        if onChanged then onChanged(TG.Trim(self:GetText()), userInput) end
    end)
    return box
end

function UI.Dropdown(parent, width, setup)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(width or 140)
    if setup then dd:SetupMenu(setup) end
    return dd
end

-- Tab strip for views inside a panel. items: { { id, text }, ... }
function UI.Tabs(parent, items, onSelect)
    local tabs = CreateFrame("Frame", nil, parent, "TabSystemTemplate")
    tabs:SetHeight(32)
    tabs.items = items
    tabs.ids = {}
    tabs.minTabWidth = 70
    tabs.maxTabWidth = 160
    if tabs.SetTabSelectedCallback then
        tabs:SetTabSelectedCallback(function(tabID, isUserAction)
            local item = items[tabID]
            if item and isUserAction then onSelect(item[1]) end
        end)
    end
    for i, item in ipairs(items) do
        tabs.ids[item[1]] = i
        if tabs.AddTab then tabs:AddTab(item[2]) end
    end
    function tabs:Select(id)
        local index = self.ids[id]
        if index and self.SetTabVisuallySelected then self:SetTabVisuallySelected(index) end
    end
    return tabs
end

function UI.Tooltip(frame, fn)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        fn(GameTooltip, self)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Numbers

-- Big number with a caption, for the overview tiles.
function UI.Stat(parent, label, width)
    local tile = UI.Card(parent)
    tile:SetSize(width or 100, 52)
    tile.Value = UI.Label(tile, "0", "GameFontNormalHuge", "CENTER")
    tile.Value:SetPoint("TOP", tile, "TOP", 0, -6)
    tile.Value:SetPoint("LEFT", tile, "LEFT", 4, 0)
    tile.Value:SetPoint("RIGHT", tile, "RIGHT", -4, 0)
    tile.Label = UI.Label(tile, label, "GameFontDisableSmall", "CENTER")
    tile.Label:SetPoint("BOTTOM", tile, "BOTTOM", 0, 7)
    tile.Label:SetPoint("LEFT", tile, "LEFT", 4, 0)
    tile.Label:SetPoint("RIGHT", tile, "RIGHT", -4, 0)
    function tile:SetValue(v) self.Value:SetText(tostring(v)) end
    return tile
end

-- Status bar with a label on the left and a value on the right.
function UI.Bar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width or 200, height or 14)
    bar:SetStatusBarTexture(BAR)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    bar.Background:SetTexture(BAR)
    bar.Background:SetVertexColor(0.15, 0.15, 0.15, 0.8)
    bar.Border = CreateFrame("Frame", nil, bar, "TooltipBorderBackdropTemplate")
    bar.Border:SetPoint("TOPLEFT", -3, 3)
    bar.Border:SetPoint("BOTTOMRIGHT", 3, -3)
    bar.Text = UI.Label(bar, "", "GameFontHighlightSmall")
    bar.Text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.Right = UI.Label(bar, "", "GameFontHighlightSmall", "RIGHT")
    bar.Right:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    function bar:Set(value, max, color)
        max = max or 1
        self:SetMinMaxValues(0, max > 0 and max or 1)
        self:SetValue(value or 0)
        if color then self:SetStatusBarColor(color.r, color.g, color.b, 0.9) else self:SetStatusBarColor(0.3, 0.55, 0.9, 0.9) end
    end
    return bar
end

-- Lists

-- Column headers in the Blizzard who list style.
-- columns: { { key = "name", text = "Name", width = 150, justify = "LEFT" }, ... }
function UI.Header(parent, columns, onSort)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(19)
    header.columns = columns
    header.buttons = {}
    local x = 0
    for i, col in ipairs(columns) do
        local b = CreateFrame("Button", nil, header, "ColumnDisplayButtonTemplate")
        b:SetID(i)
        b:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", x, 0)
        b:SetWidth(col.width)
        b:SetHeight(19)
        if not b.Text then
            b.Text = UI.Label(b, "", "GameFontHighlightSmall")
            b.Text:SetPoint("LEFT", b, "LEFT", 8, 0)
        end
        b.Text:SetText(col.text)
        b.key = col.key
        b.title = col.text
        if not onSort then b:SetScript("OnClick", nil) b:EnableMouse(false) end
        header.buttons[i] = b
        x = x + col.width - 2
    end
    header:SetWidth(x + 2)
    function header:OnClick(index)
        local col = columns[index]
        if onSort and col then onSort(col.key) end
    end
    function header:SetSort(key, ascending)
        for _, b in ipairs(self.buttons) do
            local arrow = ""
            if b.key == key then arrow = ascending and " |A:uitools-arrow-up:8:8|a" or " |A:uitools-arrow-down:8:8|a" end
            b.Text:SetText(b.title .. arrow)
        end
    end
    return header
end

-- Cells aligned with UI.Header columns.
function UI.Cells(button, columns, template)
    local cells = {}
    local x = 0
    for _, col in ipairs(columns) do
        local fs = UI.Cell(button, col.width - 14, col.justify, template)
        fs:SetPoint("LEFT", button, "LEFT", x + 8, 0)
        cells[col.key] = fs
        x = x + col.width - 2
    end
    return cells
end

local function prepareRow(button, opts)
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.tgSelected = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.tgSelected:SetAllPoints()
    button.tgSelected:SetTexture(SELECTED)
    button.tgSelected:SetBlendMode("ADD")
    button.tgSelected:Hide()
    if opts.buildRow then opts.buildRow(button) end
end

function UI.SetRowSelected(button, selected)
    if button.tgSelected then button.tgSelected:SetShown(selected and true or false) end
end

-- A scrolling list. rows are plain Buttons filled by initRow(button, data).
-- opts: buildRow(button), alternate (stripes), spacing, top/bottom/left padding, inset (border around the list)
function UI.List(parent, rowHeight, initRow, opts)
    opts = opts or {}
    local list = {}
    local host = parent
    if opts.inset then
        host = UI.ListBox(parent)
        host:SetAllPoints(parent)
        list.box = host
        host = host.Content
    end
    local scrollBox = CreateFrame("Frame", nil, host, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, host, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", host, "TOPRIGHT", -6, -(opts.top or 4))
    scrollBar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -6, opts.bottom or 4)
    scrollBox:SetPoint("TOPLEFT", host, "TOPLEFT", opts.left or (opts.inset and 2 or 4), -(opts.top or 4))
    scrollBox:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(rowHeight)
    view:SetPadding(2, 2, 2, 2, opts.spacing or 1)
    view:SetElementInitializer("Button", function(button, data)
        if not button.tgReady then
            button.tgReady = true
            prepareRow(button, opts)
        end
        initRow(button, data)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    if opts.alternate ~= false then
        ScrollUtil.RegisterAlternateRowBehavior(scrollBox, function(button, alternate)
            if not button.tgStripe then
                button.tgStripe = button:CreateTexture(nil, "BACKGROUND")
                button.tgStripe:SetAllPoints()
                button.tgStripe:SetColorTexture(1, 1, 1, 0.035)
            end
            button.tgStripe:SetShown(alternate)
        end)
    end

    list.scrollBox = scrollBox
    list.scrollBar = scrollBar
    list.view = view

    function list:SetData(array)
        local provider = CreateDataProvider(array)
        scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
    end

    function list:Refresh()
        scrollBox:ForEachFrame(function(button, data) initRow(button, data) end)
    end

    function list:ScrollToTop() scrollBox:ScrollToBegin() end

    return list
end

-- Members

function UI.ClassIcon(parent, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    return tex
end

function UI.StatusIcon(parent, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size or 14, size or 14)
    tex:SetTexture(UI.STATUS_ICONS.offline)
    return tex
end

function UI.SetStatusIcon(tex, entry)
    if not entry or not entry.online then
        tex:SetTexture(UI.STATUS_ICONS.offline)
    elseif entry.status == 1 then
        tex:SetTexture(UI.STATUS_ICONS.away)
    elseif entry.status == 2 then
        tex:SetTexture(UI.STATUS_ICONS.dnd)
    else
        tex:SetTexture(UI.STATUS_ICONS.online)
    end
end

function UI.StatusText(entry)
    if not entry.online then return GRAY_FONT_COLOR:WrapTextInColorCode(L["Offline"]) end
    if entry.status == 1 then return "<AFK>" end
    if entry.status == 2 then return "<DND>" end
    if entry.isMobile then return "(Mobile)" end
    return GREEN_FONT_COLOR:WrapTextInColorCode(L["Online"])
end

function UI.MemberLine(entry, size)
    return TG.ClassIconMarkup(entry.classFile, size or 14) .. " " .. TG.ClassText(entry.classFile, entry.key)
end

function UI.MemberTooltip(tooltip, entry)
    GameTooltip_SetTitle(tooltip, TG.ClassText(entry.classFile, entry.key))
    GameTooltip_AddNormalLine(tooltip, ("%s %d %s"):format(L["Level"], entry.level or 0, TG.ClassName(entry.classFile)))
    GameTooltip_AddNormalLine(tooltip, entry.rank or "")
    if entry.zone and entry.zone ~= "" then GameTooltip_AddHighlightLine(tooltip, entry.zone) end
    if entry.note and entry.note ~= "" then GameTooltip_AddNormalLine(tooltip, entry.note, true) end
    if entry.officerNote and entry.officerNote ~= "" then
        GameTooltip_AddColoredLine(tooltip, entry.officerNote, LIGHTBLUE_FONT_COLOR, true)
    end
    TG:Fire("MEMBER_TOOLTIP", tooltip, entry)
end

function UI.MemberMenu(owner, entry)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetTag("MENU_THEGUILD_MEMBER")
        root:CreateTitle(TG.ClassText(entry.classFile, entry.key))
        root:CreateButton(L["Whisper"], function() TG.Whisper(entry.key) end)
        if entry.online and not TG.IsMe(entry.key) then
            root:CreateButton(L["Invite"], function() TG.Invite(entry.key) end)
        end
        TG:Fire("MEMBER_MENU", root, entry)
    end)
end

-- Guild banner with the tabard, as the inspect frame shows it.
function UI.Banner(parent)
    local banner = CreateFrame("Frame", nil, parent)
    banner:SetSize(118, 144)
    local parts = "Interface\\GuildFrame\\GuildInspect-Parts"
    banner.Background = banner:CreateTexture(nil, "BACKGROUND")
    banner.Background:SetAllPoints()
    banner.Background:SetTexture(parts)
    banner.Background:SetTexCoord(0.23632813, 0.46679688, 0.70117188, 0.98242188)
    banner.Border = banner:CreateTexture(nil, "BORDER")
    banner.Border:SetAllPoints()
    banner.Border:SetTexture(parts)
    banner.Border:SetTexCoord(0.00195313, 0.23242188, 0.70117188, 0.98242188)
    banner.Left = banner:CreateTexture(nil, "ARTWORK")
    banner.Left:SetSize(50, 125)
    banner.Left:SetPoint("TOPLEFT", banner, "TOPLEFT", 10, -1)
    banner.Left:SetTexCoord(1, 0, 0, 1)
    banner.Right = banner:CreateTexture(nil, "ARTWORK")
    banner.Right:SetSize(50, 125)
    banner.Right:SetPoint("LEFT", banner.Left, "RIGHT", -1, 0)
    banner.Emblem = banner:CreateTexture(nil, "OVERLAY")
    banner.Emblem:SetSize(56, 56)
    banner.Emblem:SetPoint("CENTER", banner, "CENTER", 0, 10)
    banner.EmblemBg = banner:CreateTexture(nil, "OVERLAY")
    banner.EmblemBg:Hide()
    banner.EmblemBorder = banner:CreateTexture(nil, "OVERLAY")
    banner.EmblemBorder:Hide()
    function banner:Update()
        if TG.Demo and TG.Demo.active then
            self:Show()
            self.Left:Hide()
            self.Right:Hide()
            self.Emblem:Hide()
            return
        end
        if not IsInGuild() then self:Hide() return end
        self:Show()
        if SetDoubleGuildTabardTextures then
            local ok = pcall(SetDoubleGuildTabardTextures, "player", self.Left, self.Right, self.Background, self.Border)
            self.Left:SetShown(ok)
            self.Right:SetShown(ok)
            self.Emblem:SetShown(not ok)
            if ok then return end
        end
        local ok = pcall(SetLargeGuildTabardTextures, "player", self.Emblem, self.EmblemBg, self.EmblemBorder)
        self.Emblem:SetShown(ok)
        self.Left:Hide()
        self.Right:Hide()
    end
    return banner
end

-- Text dialog, doubles as compose and import box.

local textDialog

function UI.TextDialog(title, text, onAccept, hint)
    if not textDialog then
        local f = CreateFrame("Frame", "TheGuildTextDialog", UIParent, "ButtonFrameTemplate")
        f:SetSize(540, 440)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetPortraitToAsset(TG.icon)
        ButtonFrameTemplate_HideButtonBar(f)
        f.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
        local box = UI.Card(f.Inset)
        box:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 8, -8)
        box:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 8)
        f.box = box
        local scroll = CreateFrame("ScrollFrame", nil, box, "ScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 8)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(470)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        f.scroll = scroll
        f.accept = UI.Button(f.Inset, ACCEPT, 100, function()
            if f.onAccept then f.onAccept(f.edit:GetText()) end
            f:Hide()
        end)
        f.accept:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 6)
        f.hint = UI.Label(f.Inset, "", "GameFontDisableSmall")
        f.hint:SetPoint("BOTTOMLEFT", f.Inset, "BOTTOMLEFT", 10, 10)
        f.hint:SetPoint("RIGHT", f.accept, "LEFT", -8, 0)
        f.hint:SetWordWrap(true)
        tinsert(UISpecialFrames, "TheGuildTextDialog")
        textDialog = f
    end
    textDialog:SetTitle(title or TG.title)
    textDialog.onAccept = onAccept
    textDialog.accept:SetShown(onAccept ~= nil)
    textDialog.hint:SetText(hint or "")
    textDialog.hint:SetShown(hint ~= nil)
    textDialog.box:SetPoint("BOTTOMRIGHT", textDialog.Inset, "BOTTOMRIGHT", -8, (onAccept or hint) and 34 or 8)
    textDialog.edit:SetText(text or "")
    textDialog:Show()
    textDialog.edit:HighlightText()
    textDialog.edit:SetFocus()
end
