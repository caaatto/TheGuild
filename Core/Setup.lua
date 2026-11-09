local _, TG = ...
local L = TG.L
local UI = TG.UI

local Setup = {}
TG.Setup = Setup

local ROW = 38
local dialog

function Setup:Pending()
    local known = TG.cdb.setup.known
    for _, mod in ipairs(TG.moduleOrder) do
        if not known[mod.name] then return true end
    end
    return false
end

function Setup:Remember()
    local known = TG.cdb.setup.known
    for _, mod in ipairs(TG.moduleOrder) do known[mod.name] = true end
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
    f.intro = UI.Label(f.Inset, L["Untick what you do not need. Those modules stop and their tabs disappear, the settings bring them back any time."], "GameFontHighlight")
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
    f.apply = UI.Button(f.Inset, ACCEPT, 110, function() Setup:Apply() end)
    f.apply:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 6)
    f.keep = UI.Button(f.Inset, L["Keep everything"], 120, function() f:Hide() end)
    f.keep:SetPoint("RIGHT", f.apply, "LEFT", -6, 0)
    f.hint = UI.Label(f.Inset, L["Later: /tg modules or the settings."], "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", f.Inset, "BOTTOMLEFT", 10, 10)
    f.hint:SetPoint("RIGHT", f.keep, "LEFT", -8, 0)
    f.hint:SetWordWrap(true)
    f:SetScript("OnHide", function() Setup:Remember() end)
    tinsert(UISpecialFrames, "TheGuildSetupDialog")
    return f
end

function Setup:Open()
    dialog = dialog or build()
    local n = 0
    for _, mod in ipairs(TG.moduleOrder) do
        if mod.name ~= "Dashboard" then
            n = n + 1
            local r = row(dialog, n)
            r.mod = mod
            r.check.Text:SetText(mod.title)
            r.check:SetChecked(mod.enabled)
            r.notes:SetText(mod.desc or "")
            r.check:Show()
            r.notes:Show()
        end
    end
    for i = n + 1, #dialog.rows do
        dialog.rows[i].mod = nil
        dialog.rows[i].check:Hide()
        dialog.rows[i].notes:Hide()
    end
    dialog.child:SetHeight(math.max(ROW, n * ROW))
    dialog:Show()
end

function Setup:Apply()
    if not dialog then return end
    local changed = 0
    for _, r in ipairs(dialog.rows) do
        local mod = r.mod
        if mod then
            local want = r.check:GetChecked() and true or false
            if want ~= mod.enabled then
                if want then TG:EnableModule(mod, true) else TG:DisableModule(mod, true) end
                changed = changed + 1
            end
        end
    end
    dialog:Hide()
    if changed == 0 then
        TG:Print(L["No module changed."])
    else
        TG:Print(L["%d modules changed. The settings list every module."], changed)
    end
end

TG:On("READY", function()
    TG.After(3, function()
        if Setup:Pending() then Setup:Open() end
    end)
end)
