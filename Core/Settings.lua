local _, TG = ...
local L = TG.L
local UI = TG.UI

local Options = {}
TG.Options = Options

local controls = {}
Options.controls = controls

local category
local pages = {}
local listening

local ROW = 26
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true }

local function tooltip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_SetTitle(GameTooltip, title)
        GameTooltip_AddNormalLine(GameTooltip, text, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function newPage(title)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame.controls = {}
    frame.Title = UI.Label(frame, title, "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)
    function frame:OnRefresh()
        for _, control in ipairs(self.controls) do control.refresh() end
    end
    function frame:OnDefault()
        for _, control in ipairs(self.controls) do
            if control.default then control.default() end
        end
        self:OnRefresh()
    end
    pages[#pages + 1] = frame
    return frame
end

local function column(frame, x, width)
    return { frame = frame, x = x, y = -52, width = width }
end

local function place(col, widget, height, indent)
    widget:SetPoint("TOPLEFT", col.frame, "TOPLEFT", col.x + (indent or 0), col.y)
    col.y = col.y - height
end

local function register(col, variable, control)
    col.frame.controls[#col.frame.controls + 1] = control
    if variable then controls[variable] = control end
    return control
end

local function header(col, text)
    col.y = col.y - 8
    place(col, UI.SectionHeader(col.frame, text, col.width), ROW)
end

local function checkbox(col, variable, name, desc, get, set, default)
    local cb = UI.Checkbox(col.frame, name, function(value) set(value) end)
    cb.Text:SetWidth(col.width - 32)
    cb.Text:SetWordWrap(false)
    tooltip(cb, name, desc)
    place(col, cb, ROW, 2)
    return register(col, variable, {
        get = get,
        set = function(value) set(value) cb:SetChecked(value) end,
        refresh = function() cb:SetChecked(get() and true or false) end,
        default = default ~= nil and function() set(default) end or nil,
    })
end

local function button(col, label, text, desc, onClick)
    local fs = UI.Label(col.frame, label, "GameFontHighlight")
    fs:SetWidth(col.width - 130)
    fs:SetWordWrap(false)
    place(col, fs, 0, 8)
    local b = UI.Button(col.frame, text, 110, onClick)
    b:SetPoint("TOPRIGHT", col.frame, "TOPLEFT", col.x + col.width, col.y + 2)
    tooltip(b, label, desc)
    col.y = col.y - ROW
    return b
end

local function slider(col, variable, spec, get, set)
    local fs = UI.Label(col.frame, spec.name, "GameFontHighlight")
    place(col, fs, 18, 8)
    local s = CreateFrame("Frame", nil, col.frame, "MinimalSliderWithSteppersTemplate")
    s:SetWidth(col.width - 160)
    local step = spec.step or 1
    local min, max = spec.min or 0, spec.max or 100
    local format = spec.format or function(v) return v end
    s:Init(get() or spec.default or min, min, max, (max - min) / step, { [MinimalSliderWithSteppersMixin.Label.Right] = format })
    tooltip(s, spec.name, spec.tooltip)
    place(col, s, 44, 8)
    local control = register(col, variable, {
        get = get,
        set = function(value) set(value) s:SetValue(value) end,
        refresh = function() s:SetValue(get() or spec.default or min) end,
        default = spec.default ~= nil and function() set(spec.default) end or nil,
    })
    s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = min + math.floor((value - min) / step + 0.5) * step
        if value ~= get() then set(value) end
    end, s)
    return control
end

local function dropdown(col, variable, spec, get, set)
    local fs = UI.Label(col.frame, spec.name, "GameFontHighlight")
    fs:SetWidth(col.width - 230)
    fs:SetWordWrap(false)
    place(col, fs, 0, 8)
    local dd = UI.Dropdown(col.frame, 200, function(_, root)
        for _, opt in ipairs(spec.options) do
            root:CreateRadio(opt[2], function() return get() == opt[1] end, function() set(opt[1]) end)
        end
    end)
    dd:SetPoint("TOPRIGHT", col.frame, "TOPLEFT", col.x + col.width, col.y + 4)
    tooltip(dd, spec.name, spec.tooltip)
    col.y = col.y - 30
    return register(col, variable, {
        get = get,
        set = function(value) set(value) dd:GenerateMenu() end,
        refresh = function() dd:GenerateMenu() end,
        default = spec.default ~= nil and function() set(spec.default) end or nil,
    })
end

local function stopListening()
    local b = listening
    if not b then return end
    listening = nil
    b:EnableKeyboard(false)
    b:SetText(b.keyText())
end

local function bindingRow(col, action)
    local function keyText()
        local key = GetBindingKey(action)
        return key and GetBindingText(key) or GRAY_FONT_COLOR:WrapTextInColorCode(L["Not bound"])
    end
    local fs = UI.Label(col.frame, GetBindingName(action), "GameFontHighlight")
    fs:SetWidth(col.width - 150)
    fs:SetWordWrap(false)
    place(col, fs, 0, 8)
    local b = UI.Button(col.frame, keyText(), 130)
    b.keyText = keyText
    b:SetPoint("TOPRIGHT", col.frame, "TOPLEFT", col.x + col.width, col.y + 2)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:EnableKeyboard(false)
    b:SetScript("OnClick", function(self, mouse)
        if listening == self then
            stopListening()
            return
        end
        stopListening()
        if mouse == "RightButton" then
            local key1, key2 = GetBindingKey(action)
            if key1 then SetBinding(key1) end
            if key2 then SetBinding(key2) end
            SaveBindings(GetCurrentBindingSet())
            self:SetText(keyText())
            return
        end
        if InCombatLockdown() then return end
        listening = self
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(false)
        self:SetText(GREEN_FONT_COLOR:WrapTextInColorCode(L["Press a key"]))
    end)
    b:SetScript("OnKeyDown", function(self, key)
        if listening ~= self or MODIFIERS[key] then return end
        if key ~= "ESCAPE" then
            local chord = CreateKeyChordStringUsingMetaKeyState(key)
            local key1, key2 = GetBindingKey(action)
            if key1 then SetBinding(key1) end
            if key2 then SetBinding(key2) end
            SetBinding(chord, action)
            SaveBindings(GetCurrentBindingSet())
        end
        stopListening()
    end)
    b:SetScript("OnHide", stopListening)
    tooltip(b, GetBindingName(action), L["Click and press a key. Right click removes the binding."])
    col.y = col.y - ROW
    register(col, nil, { refresh = function() if listening ~= b then b:SetText(keyText()) end end })
end

local function addSpec(col, mod, spec)
    if spec.type == "header" then
        header(col, spec.name)
        return
    end
    if spec.type == "binding" then
        bindingRow(col, spec.action)
        return
    end
    local tbl = spec.scope == "char" and mod.cdb or mod.db
    local variable = ("TG_%s_%s"):format(mod.name, spec.key)
    local function get() return tbl[spec.key] end
    local function set(value)
        if tbl[spec.key] == value then return end
        tbl[spec.key] = value
        if spec.onChange then TG.SafeCall(spec.onChange, mod, value) end
    end
    if spec.type == "number" then
        slider(col, variable, spec, get, set)
    elseif spec.type == "select" then
        dropdown(col, variable, spec, get, set)
    else
        checkbox(col, variable, spec.name, spec.tooltip, get, set, spec.default)
    end
end

local function moduleToggle(col, mod)
    checkbox(col, "TG_MODULE_" .. mod.name, mod.title, TG:ModuleNotes(mod),
        function() return mod.enabled end,
        function(value)
            if value then TG:EnableModule(mod, true) else TG:DisableModule(mod, true) end
            Options:Refresh()
        end,
        mod.defaultEnabled)
end

function Options:Build()
    if category then return end
    local main = newPage(TG.title)
    local left = column(main, 20, 300)
    local right = column(main, 340, 300)

    header(left, L["General"])
    checkbox(left, "TG_MINIMAP", L["Minimap button"], L["Show a button on the minimap."],
        function() return not TG.db.global.minimap.hide end,
        function(value)
            TG.db.global.minimap.hide = not value
            if TG.MinimapButton then TG.MinimapButton:Refresh() end
        end, true)
    checkbox(left, "TG_DEBUG", L["Debug output"], nil,
        function() return TG.db.global.debug end,
        function(value) TG.db.global.debug = value end, false)

    header(left, L["Guild finds"])
    checkbox(left, "TG_FIND_SHARE", L["Share my finds with the guild"], L["Every member with the addon sees the find, the Milestones module shows a toast for it, the chat line adds the details."],
        function() return TG.db.global.finds.share end,
        function(value) TG.db.global.finds.share = value end, true)
    dropdown(left, "TG_FIND_CHAT", { name = L["Show finds of guild members in chat"], default = 4,
        options = { { 0, L["Off"] }, { 3, ITEM_QUALITY3_DESC or "Rare" }, { 4, ITEM_QUALITY4_DESC or "Epic" } } },
        function() return TG.db.global.finds.chat == true and 4 or tonumber(TG.db.global.finds.chat) or 0 end,
        function(value) TG.db.global.finds.chat = value end)
    dropdown(left, "TG_FIND_QUALITY", { name = L["Minimum quality for finds"], default = 4,
        options = { { 3, ITEM_QUALITY3_DESC or "Rare" }, { 4, ITEM_QUALITY4_DESC or "Epic" } } },
        function() return TG.db.global.finds.quality end,
        function(value) TG.db.global.finds.quality = value end)
    checkbox(left, "TG_FIND_BOP", L["Only report bind on pickup items"], nil,
        function() return TG.db.global.finds.bopOnly end,
        function(value) TG.db.global.finds.bopOnly = value end, false)

    if TG.Tutorial:Available() then
        header(left, L["Tutorials"])
        checkbox(left, "TG_TUTORIALS", L["Show tutorials for features you open for the first time"], nil,
            function() return TG.db.global.tutorialsOn == true end,
            function(value) TG.Tutorial:Choose(value) end, false)
        button(left, L["Show tutorials again"], L["Reset"], L["Resets every tutorial. They appear again the next time you open the window and its tabs."], function()
            TG.Tutorial:Reset()
            if TG.Window:IsShown() then TG.Tutorial:Tour() end
        end)
    end

    header(left, L["Profile"])
    button(left, L["Export profile"], L["Export"], L["Share your module settings with the guild as text."], function() TG.Profile:OpenExport() end)
    button(left, L["Import profile"], L["Import"], L["Paste a profile text. Your module settings are replaced."], function() TG.Profile:OpenImport() end)

    header(left, L["Key bindings"])
    for _, action in ipairs(TG.BINDINGS) do
        TG.SafeCall(bindingRow, left, action)
    end

    header(right, L["Modules"])
    button(right, L["Choose modules"], L["Select"], L["Pick the modules you use. Unticked modules stop and their tabs disappear."], function() TG.Setup:Open() end)
    for _, mod in ipairs(TG.moduleOrder) do
        moduleToggle(right, mod)
    end

    category = Settings.RegisterCanvasLayoutCategory(main, TG.title)
    Options.category = category

    for _, mod in ipairs(TG.moduleOrder) do
        if mod.settings and #mod.settings > 0 then
            local page = newPage(mod.title)
            local col = column(page, 20, 600)
            for _, spec in ipairs(mod.settings) do
                TG.SafeCall(addSpec, col, mod, spec)
            end
            Settings.RegisterCanvasLayoutSubcategory(category, page, mod.title)
        end
    end

    Settings.RegisterAddOnCategory(category)
end

function Options:Refresh()
    for _, page in ipairs(pages) do
        if page:IsVisible() then page:OnRefresh() end
    end
end

function Options:Open()
    if not category then self:Build() end
    Settings.OpenToCategory(category:GetID())
end

function TG:OpenSettings()
    Options:Open()
end
