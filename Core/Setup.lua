local _, TG = ...
local L = TG.L
local UI = TG.UI

local Setup = {}
TG.Setup = Setup

local ROW = 38
local HEAD = 30
local GAP = 10
local dialog

local GROUPS = {
    { title = "Basics", desc = "For everyone, on by default.", modules = { "Roster", "Map", "Professions", "Stats" } },
    { title = "Community", desc = "Greetings, toasts, board, voice and the call to arms.", modules = { "Social", "Milestones", "Board", "Voice", "Alerts" } },
    { title = "Raid", desc = "Raid teams, schedule and loot.", modules = { "Raids", "Loot" } },
    { title = "Leadership", desc = "Tools for officers and guild leaders.", modules = { "Recruit" } },
    { title = "More", desc = "", modules = {} },
}

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

local function syncHead(h)
    local all = true
    for _, r in ipairs(h.rows) do
        if not r.check:GetChecked() then all = false break end
    end
    h.check:SetChecked(all)
end

local function cascade(f, r, checked)
    local mod = r.mod
    if not mod then return end
    for _, o in ipairs(f.rows) do
        local other = o.mod
        if other and o ~= r then
            local follow = checked and TG.Requires(mod, other.name) or (not checked and TG.Requires(other, mod.name))
            if follow and (o.check:GetChecked() and true or false) ~= checked then
                o.check:SetChecked(checked)
                if o.head then syncHead(o.head) end
            end
        end
    end
end

local function head(f, i)
    local h = f.heads[i]
    if h then return h end
    h = { rows = {} }
    h.check = UI.Checkbox(f.child, "", function(checked)
        for _, r in ipairs(h.rows) do r.check:SetChecked(checked) end
        for _, r in ipairs(h.rows) do cascade(f, r, checked) end
    end)
    h.check.Text:SetFontObject("GameFontNormalLarge")
    h.notes = UI.Label(f.child, "", "GameFontDisableSmall")
    h.notes:SetPoint("LEFT", h.check.Text, "RIGHT", 10, -1)
    h.notes:SetPoint("RIGHT", f.child, "RIGHT", -8, 0)
    h.notes:SetWordWrap(false)
    h.line = f.child:CreateTexture(nil, "ARTWORK")
    h.line:SetColorTexture(1, 1, 1, 0.12)
    h.line:SetHeight(1)
    h.line:SetPoint("TOPLEFT", h.check, "BOTTOMLEFT", 0, -1)
    h.line:SetPoint("RIGHT", f.child, "RIGHT", -8, 0)
    f.heads[i] = h
    return h
end

local function row(f, i)
    local r = f.rows[i]
    if r then return r end
    r = {}
    r.check = UI.Checkbox(f.child, "", function(checked)
        cascade(f, r, checked)
        if r.head then syncHead(r.head) end
    end)
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
    f:SetSize(520, 540)
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
    f.heads = {}
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

local function grouped()
    local placed = {}
    local out = {}
    for _, g in ipairs(GROUPS) do
        local mods = {}
        for _, name in ipairs(g.modules) do
            local mod = TG:GetModule(name)
            if mod then
                mods[#mods + 1] = mod
                placed[name] = true
            end
        end
        out[#out + 1] = { group = g, mods = mods }
    end
    local more = out[#out].mods
    for _, mod in ipairs(TG.moduleOrder) do
        if not placed[mod.name] and mod.name ~= "Dashboard" then more[#more + 1] = mod end
    end
    return out
end

function Setup:Open()
    dialog = dialog or build()
    local y = 2
    local nh, nr = 0, 0
    for _, entry in ipairs(grouped()) do
        if #entry.mods > 0 then
            if nh > 0 then y = y + GAP end
            nh = nh + 1
            local h = head(dialog, nh)
            wipe(h.rows)
            h.check:ClearAllPoints()
            h.check:SetPoint("TOPLEFT", dialog.child, "TOPLEFT", 4, -y)
            h.check.Text:SetText(L[entry.group.title])
            h.notes:SetText(entry.group.desc ~= "" and L[entry.group.desc] or "")
            h.check:Show()
            h.notes:Show()
            h.line:Show()
            y = y + HEAD
            for _, mod in ipairs(entry.mods) do
                nr = nr + 1
                local r = row(dialog, nr)
                r.mod = mod
                r.head = h
                h.rows[#h.rows + 1] = r
                r.check:ClearAllPoints()
                r.check:SetPoint("TOPLEFT", dialog.child, "TOPLEFT", 24, -y)
                r.check.Text:SetText(mod.title)
                r.check:SetChecked(mod.enabled)
                r.notes:SetText(TG:ModuleNotes(mod))
                r.check:Show()
                r.notes:Show()
                y = y + ROW
            end
            syncHead(h)
        end
    end
    for i = nh + 1, #dialog.heads do
        local h = dialog.heads[i]
        wipe(h.rows)
        h.check:Hide()
        h.notes:Hide()
        h.line:Hide()
    end
    for i = nr + 1, #dialog.rows do
        dialog.rows[i].mod = nil
        dialog.rows[i].head = nil
        dialog.rows[i].check:Hide()
        dialog.rows[i].notes:Hide()
    end
    dialog.child:SetHeight(math.max(ROW, y))
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
