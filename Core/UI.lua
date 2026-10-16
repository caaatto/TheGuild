local _, TG = ...
local L = TG.L

local UI = {}
TG.UI = UI

function UI.Label(parent, text, template, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

function UI.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(text)
    b:SetWidth(width or math.max(80, b:GetTextWidth() + 30))
    b:SetHeight(22)
    if onClick then b:SetScript("OnClick", onClick) end
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

function UI.Tooltip(frame, fn)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        fn(GameTooltip, self)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI.Inset(parent)
    local f = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    return f
end

-- Columns: { { key = "name", text = "Name", width = 150, justify = "LEFT" }, ... }
function UI.Header(parent, columns, onSort)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(22)
    header.columns = columns
    header.buttons = {}
    local x = 0
    for i, col in ipairs(columns) do
        local b = CreateFrame("Button", nil, header)
        b:SetPoint("TOPLEFT", header, "TOPLEFT", x, 0)
        b:SetSize(col.width, 22)
        b.Text = UI.Label(b, col.text, "GameFontNormalSmall", col.justify or "LEFT")
        b.Text:SetPoint("LEFT", b, "LEFT", 4, 0)
        b.Text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 1, 1, 0.05)
        b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
        b.key = col.key
        if onSort then
            b:SetScript("OnClick", function() onSort(col.key) end)
        end
        header.buttons[i] = b
        x = x + col.width + 2
    end
    header:SetWidth(x)
    return header
end

-- A scrolling list. rows get initRow(button, data) and are plain Buttons.
function UI.List(parent, rowHeight, initRow, opts)
    opts = opts or {}
    local list = {}
    local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -(opts.top or 4))
    scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, opts.bottom or 4)
    scrollBox:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.left or 4, -(opts.top or 4))
    scrollBox:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(rowHeight)
    view:SetPadding(2, 2, 2, 2, opts.spacing or 1)
    view:SetElementInitializer("Button", function(button, data)
        if not button.tgReady then
            button.tgReady = true
            button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            if opts.buildRow then opts.buildRow(button) end
        end
        initRow(button, data)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    if opts.alternate ~= false then
        ScrollUtil.RegisterAlternateRowBehavior(scrollBox, function(button, alternate)
            if not button.tgStripe then
                button.tgStripe = button:CreateTexture(nil, "BACKGROUND")
                button.tgStripe:SetAllPoints()
                button.tgStripe:SetColorTexture(1, 1, 1, 0.03)
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

function UI.Cell(button, width, justify, template)
    local fs = button:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Lays out a row of cells matching a header's columns.
function UI.Cells(button, columns, template)
    local cells = {}
    local x = 4
    for i, col in ipairs(columns) do
        local fs = UI.Cell(button, col.width - 8, col.justify, template)
        fs:SetPoint("LEFT", button, "LEFT", x, 0)
        cells[col.key] = fs
        x = x + col.width + 2
    end
    return cells
end

function UI.ClassIcon(parent, size)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetSize(size, size)
    return tex
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
