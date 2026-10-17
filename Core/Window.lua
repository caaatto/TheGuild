local _, TG = ...
local L = TG.L
local UI = TG.UI

local Window = {}
TG.Window = Window

local tabs = {}
local frame
local tabButtons = {}
local sideTabs = false

local WIDTH, HEIGHT = 920, 610

local function savePosition()
    local point, _, _, x, y = frame:GetPoint(1)
    local w = TG.db.global.window
    w.point, w.x, w.y = point, x, y
end

local function updateTabVisuals(index)
    if sideTabs then
        for i, button in ipairs(tabButtons) do
            if button.SetChecked then button:SetChecked(i == index) end
        end
    else
        PanelTemplates_SetTab(frame, index)
    end
end

local function buildSideTabs()
    for i, tab in ipairs(tabs) do
        local button = CreateFrame("Button", "TheGuildFrameTab" .. i, frame, "LargeSideTabButtonTemplate")
        button:SetID(i)
        button.tooltipText = tab.title
        if button.SetFillToInterior then button:SetFillToInterior(true, 50) end
        if button.Icon then
            button.Icon:SetTexture(tab.icon or TG.icon)
            button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if i == 1 then
            button:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -28)
        else
            button:SetPoint("TOPLEFT", tabButtons[i - 1], "BOTTOMLEFT", 0, -2)
        end
        button:SetScript("OnClick", function(self)
            Window:SelectTab(self:GetID())
        end)
        tabButtons[i] = button
    end
end

local function buildBottomTabs()
    for i, tab in ipairs(tabs) do
        local button = CreateFrame("Button", "TheGuildFrameTab" .. i, frame, "PanelTabButtonTemplate")
        button:SetID(i)
        button:SetText(tab.title)
        if i == 1 then
            button:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
        else
            button:SetPoint("LEFT", tabButtons[i - 1], "RIGHT", 3, 0)
        end
        tabButtons[i] = button
        PanelTemplates_TabResize(button, 0)
        button:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Window:SelectTab(self:GetID())
        end)
    end
    PanelTemplates_SetNumTabs(frame, #tabs)
end

local function build()
    frame = CreateFrame("Frame", "TheGuildFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetTitle(TG.title)
    frame:SetPortraitToAsset(TG.icon)
    ButtonFrameTemplate_HideButtonBar(frame)
    frame.Inset:SetPoint("TOPLEFT", 4, -60)
    frame.Inset:SetPoint("BOTTOMRIGHT", -6, 4)

    local w = TG.db.global.window
    frame:SetPoint(w.point or "CENTER", UIParent, w.point or "CENTER", w.x or 0, w.y or 0)

    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame.TitleContainer:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() end)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)

    frame.guildName = UI.Label(frame, "", "GameFontNormalLarge")
    frame.guildName:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -28)
    frame.subtitle = UI.Label(frame, "", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("LEFT", frame.guildName, "RIGHT", 14, -1)
    frame.subtitle:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    frame.tabTitle = UI.Label(frame, "", "GameFontDisableSmall", "RIGHT")
    frame.tabTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -32)

    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        Window:UpdateSubtitle()
        Window:SelectTab(TG.db.global.window.tab or 1)
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)

    tinsert(UISpecialFrames, "TheGuildFrame")

    frame:EnableKeyboard(not InCombatLockdown())
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(self, key)
        local handled = false
        if key == "TAB" and IsControlKeyDown() then
            Window:StepTab(IsShiftKeyDown() and -1 or 1)
            handled = true
        elseif key == "F" and IsControlKeyDown() then
            handled = Window:FocusSearch()
        end
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
    end)
    if type(C_GamePad) == "table" and C_GamePad.IsEnabled and C_GamePad.IsEnabled() then
        frame:EnableGamePadButton(true)
        frame:SetScript("OnGamePadButtonDown", function(self, button)
            local handled = false
            if button == "PADRSHOULDER" then Window:StepTab(1) handled = true
            elseif button == "PADLSHOULDER" then Window:StepTab(-1) handled = true end
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(not handled) end
        end)
    end
    TG:RegisterEvent("PLAYER_REGEN_DISABLED", function() frame:EnableKeyboard(false) end)
    TG:RegisterEvent("PLAYER_REGEN_ENABLED", function() frame:EnableKeyboard(true) end)

    sideTabs = UI.HasAtlas("common-sidetab")
    if sideTabs then buildSideTabs() else buildBottomTabs() end
    frame:Hide()
end

function Window:Tabs()
    return tabs
end

function Window:RegisterTab(id, title, builder, order, icon, module)
    tabs[#tabs + 1] = { id = id, title = title, builder = builder, order = order or 100, icon = icon, module = module }
    table.sort(tabs, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
end

function Window:Frame()
    if not frame then build() end
    return frame
end

function Window:UpdateSubtitle()
    if not frame then return end
    local guild = TG.Roster:GuildName()
    if not guild then
        frame.guildName:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(L["No guild"]))
        frame.subtitle:SetText("")
        return
    end
    local total, online = TG.Roster:Counts()
    frame.guildName:SetText(TG.gold .. guild .. "|r")
    frame.subtitle:SetText(("%s   %s"):format(L["%d of %d online"]:format(online, total), GRAY_FONT_COLOR:WrapTextInColorCode(L["%d with TheGuild"]:format(TG.Comm:PeerCount() + 1))))
end

function Window:SelectTab(index)
    if not frame then build() end
    local tab = tabs[index]
    if not tab then index, tab = 1, tabs[1] end
    if not tab then return end
    updateTabVisuals(index)
    TG.db.global.window.tab = index
    frame.tabTitle:SetText(tab.title)
    for _, t in ipairs(tabs) do
        if t.panel then t.panel:Hide() end
        if t.disabledPanel then t.disabledPanel:Hide() end
    end
    local mod = tab.module and TG:GetModule(tab.module)
    if mod and not mod.enabled then
        if not tab.disabledPanel then
            local panel = CreateFrame("Frame", nil, frame.Inset)
            panel:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 3, -3)
            panel:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -3, 3)
            UI.Empty(panel, L["This module is disabled. Turn it on in the settings."])
            tab.disabledPanel = panel
        end
        tab.disabledPanel:Show()
        TG:Fire("WINDOW_TAB", tab.id)
        return
    end
    if tab.disabledPanel then tab.disabledPanel:Hide() end
    if not tab.panel then
        local panel = CreateFrame("Frame", nil, frame.Inset)
        panel:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 3, -3)
        panel:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -3, 3)
        tab.panel = panel
        TG.SafeCall(tab.builder, panel)
    end
    tab.panel:Show()
    if tab.panel.OnShow then TG.SafeCall(tab.panel.OnShow, tab.panel) end
    TG:Fire("WINDOW_TAB", tab.id)
end

function Window:StepTab(delta)
    if not frame or #tabs == 0 then return end
    local current = TG.db.global.window.tab or 1
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    self:SelectTab(((current - 1 + delta) % #tabs) + 1)
end

function Window:FocusSearch()
    if not frame then return false end
    local tab = tabs[TG.db.global.window.tab or 1]
    local search = tab and tab.panel and tab.panel.search
    if not search then return false end
    search:SetFocus()
    search:HighlightText()
    return true
end

function Window:ShowTab(id)
    for i, t in ipairs(tabs) do
        if t.id == id then
            self:Frame():Show()
            self:SelectTab(i)
            return
        end
    end
    self:Frame():Show()
end

function Window:Toggle()
    local f = self:Frame()
    if f:IsShown() then f:Hide() else f:Show() end
end

function Window:IsShown()
    return frame ~= nil and frame:IsShown()
end

function Window:Refresh()
    if not frame or not frame:IsShown() then return end
    self:UpdateSubtitle()
    local tab = tabs[TG.db.global.window.tab or 1]
    if tab and tab.panel and tab.panel.OnShow then TG.SafeCall(tab.panel.OnShow, tab.panel) end
end

TG:On("ROSTER_UPDATED", function() Window:Refresh() end)
TG:On("MODULE_DISABLED", function(name)
    for _, tab in ipairs(tabs) do
        if tab.module == name and tab.panel then
            tab.panel:Hide()
            tab.panel = nil
        end
    end
    if frame and frame:IsShown() then Window:SelectTab(TG.db.global.window.tab or 1) end
end)
TG:On("MODULE_ENABLED", function()
    if frame and frame:IsShown() then Window:SelectTab(TG.db.global.window.tab or 1) end
end)
TG:On("PEER_HELLO", function() if Window:IsShown() then Window:UpdateSubtitle() end end)
