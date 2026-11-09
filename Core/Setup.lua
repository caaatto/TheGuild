local _, TG = ...
local L = TG.L
local UI = TG.UI

local Setup = {}
TG.Setup = Setup

local PREFIX = TG.name .. "_"
local ROW = 38
local dialog

local function api()
    local A = C_AddOns
    return A and A.GetNumAddOns and A.GetAddOnInfo and A.GetAddOnEnableState and A.EnableAddOn and A.DisableAddOn and A or nil
end

local function character()
    local me = TG.plain(UnitName("player"), nil)
    if me and TG.plain(C_AddOns.GetAddOnEnableState(TG.name, me), 0) == 0 then return nil end
    return me
end

local function cleanTitle(title, name)
    title = TG.plain(title, nil)
    if not title then return name:sub(#PREFIX + 1) end
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if title:sub(1, #TG.title) == TG.title then title = title:sub(#TG.title + 1) end
    title = TG.Trim((title:gsub("^[_%s]+", "")))
    return title ~= "" and title or name:sub(#PREFIX + 1)
end

function Setup:Installed()
    local out = {}
    local A = api()
    if not A then return out end
    local me = character()
    for i = 1, A.GetNumAddOns() do
        local name, title, notes = A.GetAddOnInfo(i)
        name = TG.plain(name, nil)
        if name and name:sub(1, #PREFIX) == PREFIX then
            local state = TG.plain(A.GetAddOnEnableState(name, me), 0)
            out[#out + 1] = {
                name = name,
                title = cleanTitle(title, name),
                notes = TG.plain(notes, ""),
                enabled = state ~= 0,
            }
        end
    end
    table.sort(out, function(a, b) return a.title < b.title end)
    return out
end

function Setup:Pending()
    local known = TG.cdb.setup.known
    for _, mod in ipairs(self:Installed()) do
        if not known[mod.name] then return true end
    end
    return false
end

function Setup:Remember()
    local known = TG.cdb.setup.known
    for _, mod in ipairs(self:Installed()) do known[mod.name] = true end
end

local function row(f, i)
    local r = f.rows[i]
    if r then return r end
    r = {}
    r.check = UI.Checkbox(f.child, "")
    r.check:SetPoint("TOPLEFT", f.child, "TOPLEFT", 4, -(i - 1) * ROW - 2)
    r.check.Text:SetFontObject("GameFontNormal")
    r.notes = UI.Label(f.child, "", "GameFontDisableSmall")
    r.notes:SetPoint("TOPLEFT", r.check, "BOTTOMLEFT", 28, 4)
    r.notes:SetPoint("RIGHT", f.child, "RIGHT", -8, 0)
    r.notes:SetWordWrap(false)
    f.rows[i] = r
    return r
end

local function build()
    local f = CreateFrame("Frame", "TheGuildSetupDialog", UIParent, "ButtonFrameTemplate")
    f:SetSize(520, 460)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPortraitToAsset(TG.icon)
    f:SetTitle(L["Choose modules"])
    ButtonFrameTemplate_HideButtonBar(f)
    f.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
    f.intro = UI.Label(f.Inset, L["Every module is its own addon. Untick what you do not need, those are disabled in the AddOn list and the interface reloads."], "GameFontHighlight")
    f.intro:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 10, -10)
    f.intro:SetPoint("RIGHT", f.Inset, "RIGHT", -10, 0)
    f.intro:SetWordWrap(true)
    f.intro:SetHeight(32)
    local box = UI.Card(f.Inset)
    box:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 8, -50)
    box:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 36)
    local scroll = CreateFrame("ScrollFrame", nil, box, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 8)
    f.child = CreateFrame("Frame", nil, scroll)
    f.child:SetSize(440, ROW)
    scroll:SetScrollChild(f.child)
    f.rows = {}
    f.apply = CreateFrame("Button", "TheGuildSetupApply", f.Inset, "UIPanelButtonTemplate, SecureActionButtonTemplate")
    f.apply:SetText(L["Apply and reload"])
    f.apply:SetSize(math.max(150, (tonumber(f.apply:GetTextWidth()) or 0) + 24), 22)
    f.apply:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 6)
    f.apply:RegisterForClicks("AnyUp")
    f.apply:SetAttribute("useOnKeyDown", false)
    f.apply:SetAttribute("type", "macro")
    f.apply:SetAttribute("macrotext", "")
    f.apply:SetScript("PreClick", function(self)
        if InCombatLockdown() then
            TG:Print(L["Not during combat."])
            return
        end
        local changed = Setup:Apply()
        self:SetAttribute("macrotext", changed and "/reload" or "")
        if not changed then TG:Print(L["No module changed."]) end
    end)
    f.apply:SetScript("PostClick", function(self)
        if not InCombatLockdown() then self:SetAttribute("macrotext", "") end
    end)
    f.keep = UI.Button(f.Inset, L["Keep everything"], 120, function() f:Hide() end)
    f.keep:SetPoint("RIGHT", f.apply, "LEFT", -6, 0)
    f.hint = UI.Label(f.Inset, L["Later: /tg modules or the AddOn list of the game."], "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f.Inset, "BOTTOMLEFT", 10, 10)
    f.hint:SetPoint("RIGHT", f.keep, "LEFT", -8, 0)
    f.hint:SetWordWrap(true)
    f:SetScript("OnHide", function() Setup:Remember() end)
    tinsert(UISpecialFrames, "TheGuildSetupDialog")
    return f
end

function Setup:Open()
    if not api() then
        TG:Print(L["The AddOn list is not available on this client. Use the AddOn menu of the game."])
        return
    end
    dialog = dialog or build()
    local mods = self:Installed()
    for i, mod in ipairs(mods) do
        local r = row(dialog, i)
        r.mod = mod
        r.check.Text:SetText(mod.title)
        r.check:SetChecked(mod.enabled)
        r.notes:SetText(mod.notes)
        r.check:Show()
        r.notes:Show()
    end
    for i = #mods + 1, #dialog.rows do
        dialog.rows[i].mod = nil
        dialog.rows[i].check:Hide()
        dialog.rows[i].notes:Hide()
    end
    dialog.child:SetHeight(math.max(ROW, #mods * ROW))
    dialog.apply:SetEnabled(#mods > 0)
    dialog:Show()
end

function Setup:Apply()
    local A = api()
    if not dialog or not A then return false end
    local me = character()
    local changed = false
    for _, r in ipairs(dialog.rows) do
        local mod = r.mod
        if mod then
            local want = r.check:GetChecked() and true or false
            if want ~= mod.enabled then
                if want then A.EnableAddOn(mod.name, me) else A.DisableAddOn(mod.name, me) end
                changed = true
            end
        end
    end
    dialog:Hide()
    return changed
end

TG:On("READY", function()
    TG.After(3, function()
        if Setup:Pending() then Setup:Open() end
    end)
end)
