local TG = TheGuild
local L = TG.L
local UI = TG.UI

local Alts = {}
TG.AltSuggestions = Alts

local MIN_FIRST_NAME = 4

local function ignored()
    local g = TG:GuildDB()
    if not g then return {} end
    g.altIgnored = g.altIgnored or {}
    return g.altIgnored
end

local function resolveMain(key)
    local main = TG.Store:Get("alt", key)
    return main or key
end

local function mentions(note, member)
    local full = member.key:lower()
    if note:find(full, 1, true) then return true end
    local first = TG.FirstName(member.key):lower()
    if #first < MIN_FIRST_NAME then return false end
    local s, e = note:find(first, 1, true)
    while s do
        local before = s == 1 or not note:sub(s - 1, s - 1):match("[%a]")
        local after = e == #note or not note:sub(e + 1, e + 1):match("[%a]")
        if before and after then return true end
        s, e = note:find(first, e + 1, true)
    end
    return false
end

function Alts:Compute()
    local out = {}
    local skip = ignored()
    local members = TG.Roster:Members()
    for _, e in ipairs(members) do
        local note = (e.note or ""):lower()
        if note ~= "" and not TG.Store:Get("alt", e.key) then
            for _, m in ipairs(members) do
                if m.key ~= e.key and mentions(note, m) then
                    local main = resolveMain(m.key)
                    if main ~= e.key and not skip[e.key .. "|" .. main] then
                        out[#out + 1] = { alt = e.key, main = main, note = e.note, classFile = e.classFile }
                        break
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.main < b.main or (a.main == b.main and a.alt < b.alt) end)
    return out
end

function Alts:Accept(s)
    TG.Store:Set("alt", s.alt, s.main)
end

function Alts:Ignore(s)
    ignored()[s.alt .. "|" .. s.main] = true
end

local dialog

function Alts:Open()
    if not dialog then
        local f = CreateFrame("Frame", "TheGuildAltSuggestions", UIParent, "ButtonFrameTemplate")
        f:SetSize(560, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetPortraitToAsset(TG.icon)
        f:SetTitle(L["Alt suggestions"])
        ButtonFrameTemplate_HideButtonBar(f)
        f.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
        tinsert(UISpecialFrames, "TheGuildAltSuggestions")

        local hint = UI.Label(f.Inset, L["Suggestions come from public notes that name another member."], "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 10, -8)

        local listFrame = CreateFrame("Frame", nil, f.Inset)
        listFrame:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 4, -26)
        listFrame:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -4, 4)

        f.list = UI.List(listFrame, 26, function(button, s)
            button.s = s
            button.text:SetText(("%s  %s  %s"):format(TG.ClassText(s.classFile, s.alt), L["is an alt of"], TG.gold .. s.main .. "|r"))
            button.note:SetText(s.note or "")
        end, {
            alternate = false,
            buildRow = function(button)
                button.text = UI.Cell(button, 300)
                button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
                button.note = UI.Cell(button, 150, "LEFT", "GameFontDisableSmall")
                button.note:SetPoint("LEFT", button.text, "RIGHT", 4, 0)
                button.accept = UI.Button(button, ACCEPT, 70, function() Alts:Accept(button.s) Alts:Refresh() end)
                button.accept:SetPoint("RIGHT", button, "RIGHT", -80, 0)
                button.ignore = UI.Button(button, IGNORE, 70, function() Alts:Ignore(button.s) Alts:Refresh() end)
                button.ignore:SetPoint("RIGHT", button, "RIGHT", -6, 0)
            end,
        })
        f.empty = UI.Label(listFrame, L["No suggestions."], "GameFontDisableSmall", "CENTER")
        f.empty:SetPoint("CENTER")
        dialog = f
    end
    dialog:Show()
    self:Refresh()
end

function Alts:Refresh()
    if not dialog or not dialog:IsShown() then return end
    local rows = self:Compute()
    dialog.empty:SetShown(#rows == 0)
    dialog.list:SetData(rows)
end
