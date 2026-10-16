local _, TG = ...
local L = TG.L

local Options = {}
TG.Options = Options

local category

local function header(layout, text)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

local function varType(spec)
    if spec.type == "number" then return Settings.VarType.Number end
    if spec.type == "select" then
        return type(spec.default) == "number" and Settings.VarType.Number or Settings.VarType.String
    end
    return Settings.VarType.Boolean
end

local function addSpec(cat, layout, mod, spec)
    if spec.type == "header" then
        header(layout, spec.name)
        return
    end
    local tbl = spec.scope == "char" and mod.cdb or mod.db
    local variable = ("TG_%s_%s"):format(mod.name, spec.key)
    local setting = Settings.RegisterAddOnSetting(cat, variable, spec.key, tbl, varType(spec), spec.name, spec.default)
    if spec.onChange then
        setting:SetValueChangedCallback(function(_, value)
            TG.SafeCall(spec.onChange, mod, value)
        end)
    end
    if spec.type == "number" then
        local options = Settings.CreateSliderOptions(spec.min or 0, spec.max or 100, spec.step or 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, spec.format)
        Settings.CreateSlider(cat, setting, options, spec.tooltip)
    elseif spec.type == "select" then
        Settings.CreateDropdown(cat, setting, function()
            local container = Settings.CreateControlTextContainer()
            for _, opt in ipairs(spec.options) do container:Add(opt[1], opt[2]) end
            return container:GetData()
        end, spec.tooltip)
    else
        Settings.CreateCheckbox(cat, setting, spec.tooltip)
    end
end

local function moduleToggle(mod)
    local function get() return mod.enabled end
    local function set(value)
        if value then TG:EnableModule(mod, true) else TG:DisableModule(mod, true) end
    end
    local setting = Settings.RegisterProxySetting(category, "TG_MODULE_" .. mod.name, Settings.VarType.Boolean, mod.title, mod.defaultEnabled, get, set)
    Settings.CreateCheckbox(category, setting, mod.desc)
end

function Options:Build()
    if category then return end
    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(TG.title)
    Options.category = category

    header(layout, L["General"])
    local minimap = Settings.RegisterProxySetting(category, "TG_MINIMAP", Settings.VarType.Boolean, L["Minimap button"], true,
        function() return not TG.db.global.minimap.hide end,
        function(value)
            TG.db.global.minimap.hide = not value
            if TG.MinimapButton then TG.MinimapButton:Refresh() end
        end)
    Settings.CreateCheckbox(category, minimap, L["Show a button on the minimap."])

    local debug = Settings.RegisterAddOnSetting(category, "TG_DEBUG", "debug", TG.db.global, Settings.VarType.Boolean, L["Debug output"], false)
    Settings.CreateCheckbox(category, debug)

    header(layout, L["Modules"])
    for _, mod in ipairs(TG.moduleOrder) do
        moduleToggle(mod)
    end

    for _, mod in ipairs(TG.moduleOrder) do
        if mod.settings and #mod.settings > 0 then
            local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(category, mod.title)
            for _, spec in ipairs(mod.settings) do
                TG.SafeCall(addSpec, sub, subLayout, mod, spec)
            end
        end
    end

    Settings.RegisterAddOnCategory(category)
end

function Options:Open()
    if not category then self:Build() end
    Settings.OpenToCategory(category:GetID())
end

function TG:OpenSettings()
    Options:Open()
end
