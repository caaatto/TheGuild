local _, TG = ...
local L = TG.L

TG.modules = {}
TG.moduleOrder = {}

local Module = {}
Module.__index = Module

function Module:Print(...) TG:Print(...) end
function Module:Debug(...) TG:Debug(...) end

function Module:RegisterEvent(event, handler)
    local fn = type(handler) == "string" and function(...) self[handler](self, ...) end or handler
    return TG:RegisterEvent(event, fn, self)
end

function Module:UnregisterEvent(event)
    TG:UnregisterEvent(event, self)
end

function Module:On(message, handler)
    local fn = type(handler) == "string" and function(...) self[handler](self, ...) end or handler
    TG:On(message, fn, self)
end

function Module:RegisterComm(tag, handler)
    local fn = type(handler) == "string" and function(...) self[handler](self, ...) end or handler
    TG.Comm:Register(tag, fn, self)
end

function Module:Ticker(interval, handler)
    local fn = type(handler) == "string" and function(...) self[handler](self, ...) end or handler
    local t = TG.Ticker(interval, fn)
    self.tickers[#self.tickers + 1] = t
    return t
end

function Module:IsEnabled()
    return self.enabled == true
end

function Module:Cleanup()
    TG:UnregisterAllEvents(self)
    TG:OffAll(self)
    TG.Comm:UnregisterAll(self)
    for _, t in ipairs(self.tickers) do t:Cancel() end
    self.tickers = {}
end

function TG:NewModule(name, def)
    assert(not TG.modules[name], "duplicate module " .. name)
    local mod = setmetatable({
        name = name,
        title = def.title or name,
        desc = def.desc,
        order = def.order or 100,
        defaultEnabled = def.defaultEnabled ~= false,
        defaults = def.defaults,
        charDefaults = def.charDefaults,
        settings = def.settings,
        requires = def.requires,
        tickers = {},
        enabled = false,
    }, Module)
    for k, v in pairs(def) do
        if type(v) == "function" then mod[k] = v end
    end
    TG.modules[name] = mod
    TG.moduleOrder[#TG.moduleOrder + 1] = mod
    table.sort(TG.moduleOrder, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    return mod
end

function TG:GetModule(name)
    return TG.modules[name]
end

function TG:IsModuleEnabled(name)
    local mod = TG.modules[name]
    return mod and mod.enabled or false
end

function TG.Requires(mod, name)
    local req = mod.requires
    if not req then return false end
    for _, n in ipairs(req) do
        if n == name then return true end
    end
    return false
end

function TG:ModuleNotes(mod)
    local notes = mod.desc or ""
    if not mod.requires then return notes end
    local names = {}
    for _, name in ipairs(mod.requires) do
        local other = TG.modules[name]
        names[#names + 1] = other and other.title or name
    end
    return notes .. " " .. L["Needs the %s module."]:format(table.concat(names, ", "))
end

local function wantsEnabled(mod)
    local state = TG.db.modules[mod.name]
    if state and state.enabledOverride ~= nil then return state.enabledOverride end
    return mod.defaultEnabled
end

function TG:EnableModule(mod, persist)
    if type(mod) == "string" then mod = TG.modules[mod] end
    if not mod or mod.enabled then return end
    if mod.requires then
        for _, name in ipairs(mod.requires) do
            TG:EnableModule(name, persist)
            if not TG:IsModuleEnabled(name) then return end
        end
    end
    mod.enabled = true
    if persist then mod.db.enabledOverride = true end
    if mod.OnEnable then TG.SafeCall(mod.OnEnable, mod) end
    TG:Fire("MODULE_ENABLED", mod.name)
end

function TG:DisableModule(mod, persist)
    if type(mod) == "string" then mod = TG.modules[mod] end
    if not mod or not mod.enabled then return end
    mod.enabled = false
    if persist then mod.db.enabledOverride = false end
    if mod.OnDisable then TG.SafeCall(mod.OnDisable, mod) end
    mod:Cleanup()
    TG:Fire("MODULE_DISABLED", mod.name)
    for _, other in ipairs(TG.moduleOrder) do
        if other.enabled and TG.Requires(other, mod.name) then TG:DisableModule(other, persist) end
    end
end

function TG:InitModules()
    for _, mod in ipairs(TG.moduleOrder) do
        mod.db = TG:ModuleDB(mod.name, mod.defaults)
        mod.cdb = TG:ModuleCharDB(mod.name, mod.charDefaults)
        if mod.OnInitialize then TG.SafeCall(mod.OnInitialize, mod) end
    end
    for _, mod in ipairs(TG.moduleOrder) do
        if wantsEnabled(mod) then TG:EnableModule(mod) end
    end
end

function TG:ModuleStateText(mod)
    return mod.enabled and GREEN_FONT_COLOR:WrapTextInColorCode(L["Enabled"] or "on") or GRAY_FONT_COLOR:WrapTextInColorCode(L["Disabled"] or "off")
end
