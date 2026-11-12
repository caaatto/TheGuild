local TG = TheGuild
local ns = TG.GH
if ns.off then return end
local L = ns.L
local UI = TG.UI
local Codec, Link, Rules = ns.Codec, ns.Link, ns.Rules
local T = Codec.T
local GH = ns.Mod
local floor, min = math.floor, math.min

local STANDING = { L["Hated"], L["Hostile"], L["Unfriendly"], L["Neutral"], L["Friendly"], L["Honored"], L["Revered"], L["Exalted"] }
local ENV = { L["falling"], L["drowning"], L["fatigue"], L["fire"], L["lava"], L["slime"], L["the environment"] }
local STAT = { L["Distance on foot"], L["Fishing catches"], L["Hearthstone uses"], L["New toys"], L["New pets"], L["Crafted items"], L["Consumables used"], L["Guild resurrections"] }
local MOMENT_LABEL = {
    [3] = L["Saluted an NPC"], [4] = L["Rested at a campfire"], [5] = L["Rode the Deeprun Tram"], [6] = L["Lit a campfire"],
    [7] = L["First catch"], [8] = L["First craft"], [9] = L["First use"], [10] = L["Helpful buff received"],
    [11] = L["Resurrected by a guild member"], [12] = L["Guild dungeon run"], [13] = L["Hearthstone bound"], [14] = L["Guild photo"],
}
local MOMENT_MAP = { [4] = true, [6] = true, [11] = true, [13] = true, [14] = true }
local MOMENT_ITEM = { [7] = true, [9] = true }
local MOMENT_SPELL = { [8] = true, [10] = true }

local CATEGORY_OF = {
    [T.level] = "char", [T.money_peak] = "char", [T.pvp_rank] = "char", [T.mount_learned] = "char", [T.snapshot] = "char",
    [T.skill] = "skill", [T.fishing_loot] = "skill",
    [T.encounter_kill] = "combat", [T.encounter_wipe] = "combat", [T.fight] = "combat", [T.rare_kill] = "combat", [T.death] = "combat",
    [T.zone_visit] = "world", [T.area_discovered] = "world", [T.quest_turned_in] = "world",
    [T.reputation_standing] = "rep",
    [T.stat] = "misc", [T.moment] = "misc",
}

local CATEGORIES = {
    { "all", L["All"] }, { "char", L["Character"] }, { "skill", L["Professions"] }, { "combat", L["Combat"] },
    { "world", L["World"] }, { "rep", L["Reputation"] }, { "misc", L["Other"] },
}

local function safe(v)
    if type(v) == "string" and v ~= "" and TG.usable(v) then return v end
    return nil
end

local function mapName(id)
    if not id or id == 0 then return "?" end
    local city = ns.CITY_BY_MAP[id]
    return safe(TG.MapName(id)) or (city and city.name) or (L["Map"] .. " " .. id)
end

local function areaName(id)
    return safe(ns.Call(ns.Api("C_Map.GetAreaInfo"), id)) or (L["Area"] .. " " .. tostring(id))
end

local function encounterName(encounterId, npcId)
    if encounterId and encounterId > 0 then
        return safe((ns.Call(ns.Api("EJ_GetEncounterInfo"), encounterId))) or (L["Boss"] .. " " .. encounterId)
    end
    return "NPC " .. tostring(npcId or 0)
end

local function factionName(id)
    local data = ns.Call(ns.Api("C_Reputation.GetFactionDataByID"), id)
    return (type(data) == "table" and safe(data.name)) or (L["Faction"] .. " " .. tostring(id))
end

local function questName(id)
    return safe(ns.Call(ns.Api("C_QuestLog.GetTitleForQuestID"), id)) or (L["Quest"] .. " " .. tostring(id))
end

local function itemName(id)
    return safe(ns.Call(ns.Api("C_Item.GetItemNameByID"), id)) or (L["Item"] .. " " .. tostring(id))
end

local function spellName(id)
    return safe(ns.Call(ns.Api("C_Spell.GetSpellName"), id)) or (L["Spell"] .. " " .. tostring(id))
end

local function skillName(id, name)
    return ns.PROFESSIONS[id] or ns.WEAPON_SKILLS[id] or safe(name) or (L["Skill"] .. " " .. tostring(id))
end

local function duration(s)
    s = tonumber(s) or 0
    return ("%d:%02d"):format(floor(s / 60), s % 60)
end

local function money(copper)
    copper = tonumber(copper) or 0
    local gold = floor(copper / 10000)
    local silver = floor(copper / 100) % 100
    if gold > 0 then
        return silver > 0 and ("%d %s %d %s"):format(gold, L["gold"], silver, L["silver"]) or ("%d %s"):format(gold, L["gold"])
    end
    if silver > 0 then return ("%d %s %d %s"):format(silver, L["silver"], copper % 100, L["copper"]) end
    return ("%d %s"):format(copper % 100, L["copper"])
end

local function standing(n)
    return STANDING[n] or (L["Standing"] .. " " .. tostring(n))
end

function ns.Describe(e)
    local t = e[2]
    local f = Rules.Fields(e) or {}
    if t == T.snapshot then
        return L["Baseline recorded: level %d, %s, %d skills, %d reputations"]:format(e[4] or 0, money(e[5]), type(e[8]) == "table" and #e[8] or 0, type(e[9]) == "table" and #e[9] or 0)
    elseif t == T.level then
        return L["Reached level %d"]:format(f.level or 0)
    elseif t == T.skill then
        return ("%s %d"):format(skillName(f.skill_id, f.name), f.rank or 0) .. ((f.max_rank or 0) > 0 and (" (%s %d)"):format(L["of"], f.max_rank) or "")
    elseif t == T.money_peak then
        return L["Gold record: %s"]:format(money(f.copper))
    elseif t == T.zone_visit then
        return L["Visited: %s"]:format(mapName(f.ui_map_id))
    elseif t == T.area_discovered then
        return L["Discovered: %s"]:format(areaName(f.area_id))
    elseif t == T.encounter_kill then
        local extra = {}
        if (f.duration_s or 0) > 0 then extra[#extra + 1] = duration(f.duration_s) end
        if (f.guild_members or 0) > 0 then extra[#extra + 1] = L["%d from the guild"]:format(f.guild_members) end
        if (f.tabard_item or 0) > 0 then extra[#extra + 1] = L["with tabard"] end
        return L["Boss defeated: %s"]:format(encounterName(f.encounter_id, f.npc_id)) .. (#extra > 0 and (" (" .. table.concat(extra, ", ") .. ")") or "")
    elseif t == T.quest_turned_in then
        return L["Quest turned in: %s"]:format(questName(f.quest_id))
    elseif t == T.reputation_standing then
        return L["Reputation: %s %s"]:format(factionName(f.faction_id), standing(f.standing))
    elseif t == T.death then
        local cause = ""
        if f.killer_kind == 1 then
            cause = L[" by NPC %d"]:format(f.killer_id or 0)
        elseif f.killer_kind == 2 then
            cause = L[" by a player"]
        elseif f.killer_kind == 3 then
            cause = L[" by %s"]:format(ENV[f.killer_id] or ENV[f.env_type] or ENV[7])
        end
        return L["Died in %s (level %d)%s%s"]:format(mapName(f.ui_map_id), f.level or 0, cause, f.one_shot == 1 and L[", in one hit"] or "")
    elseif t == T.pvp_rank then
        return L["PvP rank %d"]:format(f.rank or 0)
    elseif t == T.mount_learned then
        return L["Mount learned: %s"]:format(spellName(f.spell_id))
    elseif t == T.encounter_wipe then
        return L["Wipe at %s after %s"]:format(encounterName(f.encounter_id, 0), duration(f.duration_s))
    elseif t == T.fight then
        return L["Fight %s, %d damage%s"]:format(duration(f.duration_s), floor(f.damage or 0), f.killed == 1 and L[", enemy defeated"] or "")
    elseif t == T.fishing_loot then
        return L["Fishing catch: %s"]:format(itemName(f.item_id))
    elseif t == T.stat then
        local label = STAT[f.stat_id] or (L["Counter"] .. " " .. tostring(f.stat_id))
        if f.stat_id == ns.STAT_DISTANCE then return ("%s: %d km"):format(label, floor((f.value or 0) / 1000)) end
        return ("%s: %d"):format(label, f.value or 0)
    elseif t == T.rare_kill then
        return L["Rare defeated: NPC %d"]:format(f.npc_id or 0)
    elseif t == T.moment then
        if f.moment_id == ns.MOMENT_BOSS_SCREENSHOT then return L["Moment: screenshot after the boss kill"] end
        if f.moment_id == ns.MOMENT_HEARTH_AFTER_DEATH then return L["Moment: hearthstone %d s after a death or wipe"]:format(f.value or 0) end
        local id, value = f.moment_id, f.value or 0
        local label = MOMENT_LABEL[id]
        if not label then return L["Moment"] .. " " .. tostring(id) end
        local detail
        if MOMENT_MAP[id] then
            detail = mapName(value)
        elseif MOMENT_ITEM[id] then
            detail = itemName(value)
        elseif MOMENT_SPELL[id] then
            detail = spellName(value)
        elseif id == ns.MOMENT.salute then
            detail = "NPC " .. tostring(value)
        elseif id == ns.MOMENT.tram then
            detail = value == 1 and L["Ironforge to Stormwind"] or L["Stormwind to Ironforge"]
        elseif id == ns.MOMENT.guild_dungeon then
            local flags = value % 10
            local parts = { L["Instance %d"]:format(floor(value / 10)) }
            if flags >= 4 then parts[#parts + 1] = L["guild group"] end
            if flags % 4 >= 2 then parts[#parts + 1] = L["no deaths"] end
            detail = table.concat(parts, ", ")
        else
            detail = tostring(value)
        end
        return label .. ": " .. detail
    end
    return L["Event type"] .. " " .. tostring(t)
end

local function formatTime(ts)
    if ts and ts > 0 then return date("%d.%m.%y %H:%M", ts) end
    return ""
end

local function progressText(st)
    if st.done then return GREEN_FONT_COLOR:WrapTextInColorCode(formatTime(st.done)) end
    if st.progress and st.required and st.required > 0 then
        if st.rule.kind == "threshold" and st.rule.p.field == "copper" then
            return ("%d / %d %s"):format(floor(st.progress / 10000), floor(st.required / 10000), L["gold"])
        end
        return ("%d / %d"):format(min(st.progress, st.required), st.required)
    end
    return GRAY_FONT_COLOR:WrapTextInColorCode(L["Open"])
end

local FILTERS = { { "all", L["All"] }, { "done", L["Earned"] }, { "open", L["Open"] } }
local GROUPS = { { "char", L["Character"] }, { "combat", L["Combat"] }, { "skill", L["Professions"] }, { "world", L["World"] }, { "rep", L["Reputation"] }, { "misc", L["Other"] } }
local GROUP_OF = {
    level = "char", money_peak = "char", mount_learned = "char", pvp_rank = "char",
    death = "combat", encounter_kill = "combat", encounter_wipe = "combat", fight = "combat", rare_kill = "combat",
    skill = "skill", fishing_loot = "skill",
    zone_visit = "world", area_discovered = "world", quest_turned_in = "world",
    reputation_standing = "rep",
}
local ART = "Interface\\AchievementFrame\\"
local PARCHMENT = ART .. "UI-Achievement-Parchment-Horizontal"
local PARCHMENT_GRAY = ART .. "UI-Achievement-Parchment-Horizontal-Desaturated"
local PARCHMENT_SIDE = ART .. "UI-Achievement-Parchment"
local BORDERS = ART .. "UI-Achievement-Borders"
local CORNERS = ART .. "UI-Achievement-Tsunami-Corners"
local ICON_FRAME = ART .. "UI-Achievement-IconFrame"
local SHIELDS = ART .. "UI-Achievement-Shields"
local TINY_SHIELD = ART .. "UI-Achievement-TinyShield"
local HEADER = ART .. "UI-Achievement-Header"
local RECENT_HEADER = ART .. "UI-Achievement-RecentHeader"
local LIST_BG = ART .. "UI-Achievement-AchievementBackground"
local WATERMARK = ART .. "UI-Achievement-AchievementWatermark"
local CATEGORY_BG = ART .. "UI-Achievement-Category-Background"
local CATEGORY_HL = ART .. "UI-Achievement-Category-Highlight"
local BAR_BORDER = ART .. "UI-Achievement-ProgressBar-Border"
local SKILL_BAR = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
local STATUS_BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local ROW_HEIGHT = 84
local SIDE_WIDTH = 175

local function font(name, fallback)
    return type(_G[name]) == "table" and name or fallback
end

local function borderColor(name, r, g, b)
    local c = _G[name]
    if type(c) == "table" and c.GetRGB then return c:GetRGB() end
    return r, g, b
end

local function rowTooltip(self)
    local st = self.st
    if not st then return end
    local e = st.entry
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, tostring(e.title or e.code))
    if e.description and e.description ~= "" then GameTooltip_AddNormalLine(GameTooltip, e.description, true) end
    GameTooltip_AddDisabledLine(GameTooltip, L["%d points, %d as pioneer"]:format(tonumber(e.points) or 0, tonumber(e.pioneer) or 0))
    if st.done then
        GameTooltip_AddColoredLine(GameTooltip, L["Earned on %s"]:format(formatTime(st.done)), GREEN_FONT_COLOR)
    elseif st.progress and st.required then
        GameTooltip_AddNormalLine(GameTooltip, L["Progress: %s"]:format(progressText(st)))
    end
    GameTooltip:Show()
end

local function goldBorder(parent)
    local f = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
    f:SetAllPoints(parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 5)
    if f.SetBackdropColor then f:SetBackdropColor(0, 0, 0, 0) end
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(borderColor("ACHIEVEMENT_GOLD_BORDER_COLOR", 0.8, 0.6, 0.2)) end
    return f
end

local function headerBar(parent, width)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, 21)
    bar:SetStatusBarTexture(SKILL_BAR)
    bar:SetStatusBarColor(0, 1, 0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetDrawLayer("BORDER") end
    bar.Fill = bar:CreateTexture(nil, "BACKGROUND")
    bar.Fill:SetPoint("LEFT")
    bar.Fill:SetPoint("RIGHT")
    bar.Fill:SetHeight(15)
    bar.Fill:SetColorTexture(0, 0, 0, 0.5)
    bar.Label = UI.Label(bar, "", "GameFontNormal")
    bar.Label:SetPoint("LEFT", bar, "LEFT", 6, 4)
    bar.Text = UI.Label(bar, "", "GameFontHighlight", "RIGHT")
    bar.Text:SetPoint("RIGHT", bar, "RIGHT", -5, 3)
    bar.Left = bar:CreateTexture(nil, "OVERLAY")
    bar.Left:SetSize(32, 48)
    bar.Left:SetPoint("TOPLEFT", bar, "TOPLEFT", -15, 16)
    bar.Left:SetTexture(HEADER)
    bar.Left:SetTexCoord(0.423828125, 0.486, 0.56640625, 0.75)
    bar.Right = bar:CreateTexture(nil, "OVERLAY")
    bar.Right:SetSize(32, 48)
    bar.Right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 15, 16)
    bar.Right:SetTexture(HEADER)
    bar.Right:SetTexCoord(0.486, 0.423828125, 0.56640625, 0.75)
    bar.Middle = bar:CreateTexture(nil, "OVERLAY")
    bar.Middle:SetPoint("TOPLEFT", bar.Left, "TOPRIGHT", 0, 0)
    bar.Middle:SetPoint("BOTTOMRIGHT", bar.Right, "BOTTOMLEFT", 0, 0)
    bar.Middle:SetTexture(HEADER)
    bar.Middle:SetTexCoord(0.889224609375, 0.486, 0.56640625, 0.75)
    function bar:Set(done, total)
        self:SetMinMaxValues(0, total > 0 and total or 1)
        self:SetValue(done)
        self.Text:SetText(("%d/%d"):format(done, total))
    end
    return bar
end

local function progressBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(212, 14)
    bar:SetStatusBarTexture(STATUS_BAR)
    bar:SetStatusBarColor(0, 0.6, 0, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetDrawLayer("BORDER") end
    bar.BG = bar:CreateTexture(nil, "BACKGROUND")
    bar.BG:SetAllPoints()
    bar.BG:SetColorTexture(0, 0, 0, 0.4)
    bar.Text = UI.Label(bar, "", "GameFontHighlightSmall", "CENTER")
    bar.Text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.BorderLeft = bar:CreateTexture(nil, "ARTWORK")
    bar.BorderLeft:SetWidth(16)
    bar.BorderLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", -6, 5)
    bar.BorderLeft:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -6, -5)
    bar.BorderLeft:SetTexture(BAR_BORDER)
    bar.BorderLeft:SetTexCoord(0, 0.0625, 0, 0.75)
    bar.BorderRight = bar:CreateTexture(nil, "ARTWORK")
    bar.BorderRight:SetWidth(16)
    bar.BorderRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 6, 5)
    bar.BorderRight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -5)
    bar.BorderRight:SetTexture(BAR_BORDER)
    bar.BorderRight:SetTexCoord(0.812, 0.8745, 0, 0.75)
    bar.BorderCenter = bar:CreateTexture(nil, "ARTWORK")
    bar.BorderCenter:SetPoint("TOPLEFT", bar.BorderLeft, "TOPRIGHT", 0, 0)
    bar.BorderCenter:SetPoint("BOTTOMRIGHT", bar.BorderRight, "BOTTOMLEFT", 0, 0)
    bar.BorderCenter:SetTexture(BAR_BORDER)
    bar.BorderCenter:SetTexCoord(0.0625, 0.812, 0, 0.75)
    return bar
end

local function recentHeader(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(20)
    f.Texture = f:CreateTexture(nil, "BACKGROUND")
    f.Texture:SetPoint("TOPLEFT", f, "TOPLEFT", -20, 0)
    f.Texture:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 20, 0)
    f.Texture:SetTexture(RECENT_HEADER)
    f.Texture:SetTexCoord(0, 1, 0, 0.71875)
    f.Title = UI.Label(f, text, "GameFontNormal", "CENTER")
    f.Title:SetPoint("CENTER", f, "CENTER", 0, 0)
    return f
end

local function buildRow(b)
    b.Background = b:CreateTexture(nil, "BACKGROUND")
    b.Background:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.Background:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.Background:SetTexCoord(0, 1, 1 - ROW_HEIGHT / 256, 1)
    local function corner(point, x, y, alpha, l, r, t, bt)
        local tex = b:CreateTexture(nil, "BORDER")
        tex:SetSize(32, 32)
        tex:SetPoint(point, b, point, x, y)
        tex:SetTexture(CORNERS)
        tex:SetTexCoord(l, r, t, bt)
        tex:SetVertexColor(1, 1, 1, alpha)
        return tex
    end
    b.BottomLeftTsunami = corner("BOTTOMLEFT", -2, -2, 0.2, 0, 0.5, 0, 1)
    b.BottomRightTsunami = corner("BOTTOMRIGHT", 2, -2, 0.2, 0.5, 1, 0, 1)
    b.TopLeftTsunami = corner("TOPLEFT", -2, -20, 0.1, 1, 0.5, 1, 0)
    b.TopRightTsunami = corner("TOPRIGHT", 2, -20, 0.1, 0.5, 0, 1, 0)
    b.BottomTsunami = b:CreateTexture(nil, "BORDER")
    b.BottomTsunami:SetHeight(16)
    b.BottomTsunami:SetPoint("BOTTOMLEFT", b.BottomLeftTsunami, "BOTTOMRIGHT", 0, 3)
    b.BottomTsunami:SetPoint("BOTTOMRIGHT", b.BottomRightTsunami, "BOTTOMLEFT", 0, 3)
    b.BottomTsunami:SetTexture(BORDERS)
    b.BottomTsunami:SetVertexColor(1, 1, 1, 0.35)
    b.TopTsunami = b:CreateTexture(nil, "BORDER")
    b.TopTsunami:SetHeight(16)
    b.TopTsunami:SetPoint("TOPLEFT", b.TopLeftTsunami, "TOPRIGHT", 0, -3)
    b.TopTsunami:SetPoint("TOPRIGHT", b.TopRightTsunami, "TOPLEFT", 0, -3)
    b.TopTsunami:SetTexture(BORDERS)
    b.TopTsunami:SetVertexColor(1, 1, 1, 0.3)
    b.TitleBar = b:CreateTexture(nil, "ARTWORK")
    b.TitleBar:SetHeight(24)
    b.TitleBar:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -4)
    b.TitleBar:SetPoint("TOPRIGHT", b, "TOPRIGHT", -5, -4)
    b.TitleBar:SetTexture(BORDERS)
    b.TitleBar:SetVertexColor(1, 1, 1, 0.8)
    b.Glow = b:CreateTexture(nil, "ARTWORK")
    b.Glow:SetHeight(64)
    b.Glow:SetPoint("TOPLEFT", b.TitleBar, "BOTTOMLEFT", 0, 4)
    b.Glow:SetPoint("RIGHT", b, "RIGHT", 0, 4)
    b.Glow:SetTexture(BORDERS)
    b.Glow:SetTexCoord(0, 1, 0.00390625, 0.25390625)
    b.Border = CreateFrame("Frame", nil, b, "TooltipBorderBackdropTemplate")
    b.Border:SetAllPoints(b)
    b.IconFrame = CreateFrame("Frame", nil, b)
    b.IconFrame:SetSize(60, 60)
    b.IconFrame:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -9)
    b.Icon = b.IconFrame:CreateTexture(nil, "ARTWORK")
    b.Icon:SetSize(50, 50)
    b.Icon:SetPoint("CENTER", b.IconFrame, "CENTER", 0, 3)
    b.IconBorder = b.IconFrame:CreateTexture(nil, "OVERLAY")
    b.IconBorder:SetSize(72, 72)
    b.IconBorder:SetPoint("CENTER", b.IconFrame, "CENTER", -1, 2)
    b.IconBorder:SetTexture(ICON_FRAME)
    b.IconBorder:SetTexCoord(0, 0.5625, 0, 0.5625)
    b.ShieldFrame = CreateFrame("Frame", nil, b)
    b.ShieldFrame:SetSize(64, 64)
    b.ShieldFrame:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, 0)
    b.Shield = b.ShieldFrame:CreateTexture(nil, "BACKGROUND")
    b.Shield:SetSize(66, 64)
    b.Shield:SetPoint("TOPRIGHT", b.ShieldFrame, "TOPRIGHT", 0, -6)
    b.Shield:SetTexture(SHIELDS)
    b.Points = UI.Label(b.ShieldFrame, "", font("AchievementPointsFont", "GameFontNormalLarge"), "CENTER")
    b.Points:SetSize(42, 16)
    b.Points:SetPoint("TOPRIGHT", b.ShieldFrame, "TOPRIGHT", -13, -26)
    b.Date = UI.Label(b.ShieldFrame, "", font("AchievementDateFont", "GameFontHighlightSmall"), "RIGHT")
    b.Date:SetSize(76, 14)
    b.Date:SetPoint("TOPRIGHT", b.ShieldFrame, "BOTTOMRIGHT", 2, 6)
    b.Label = UI.Label(b, "", font("GameFontHighlightMedium", "GameFontHighlight"), "CENTER")
    b.Label:SetHeight(20)
    b.Label:SetPoint("TOP", b.TitleBar, "TOP", 0, 0)
    b.Label:SetPoint("LEFT", b.IconFrame, "RIGHT", 8, 0)
    b.Label:SetPoint("RIGHT", b.ShieldFrame, "LEFT", -8, 0)
    b.Label:SetWordWrap(false)
    b.Description = UI.Label(b, "", font("AchievementDescriptionFont", "GameFontHighlightSmall"), "CENTER")
    b.Description:SetPoint("TOP", b, "TOP", 0, -30)
    b.Description:SetPoint("LEFT", b.IconFrame, "RIGHT", 8, 0)
    b.Description:SetPoint("RIGHT", b.ShieldFrame, "LEFT", -8, 0)
    b.Description:SetHeight(30)
    b.Description:SetJustifyV("TOP")
    b.Description:SetWordWrap(true)
    if b.Description.SetMaxLines then b.Description:SetMaxLines(2) end
    b.Progress = progressBar(b)
    b.Progress:SetPoint("BOTTOM", b, "BOTTOM", 0, 9)
    b.Progress:Hide()
    b:SetScript("OnEnter", rowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function saturate(b)
    b.Background:SetTexture(PARCHMENT)
    b.TitleBar:SetTexCoord(0, 1, 0.66015625, 0.73828125)
    b.BottomTsunami:SetTexCoord(0, 0.72265, 0.51953125, 0.58203125)
    b.TopTsunami:SetTexCoord(0.72265, 0, 0.58203125, 0.51953125)
    b.Glow:SetVertexColor(1, 1, 1)
    b.IconBorder:SetVertexColor(1, 1, 1, 1)
    b.Icon:SetVertexColor(1, 1, 1, 1)
    b.Shield:SetTexCoord(0, 0.5, 0, 0.5)
    b.Points:SetVertexColor(1, 1, 1)
    b.Label:SetVertexColor(1, 1, 1)
    b.Description:SetTextColor(0, 0, 0, 1)
    b.Description:SetShadowOffset(0, 0)
    if b.Border.SetBackdropBorderColor then b.Border:SetBackdropBorderColor(borderColor("ACHIEVEMENT_RED_BORDER_COLOR", 0.6, 0.1, 0.05)) end
end

local function desaturate(b)
    b.Background:SetTexture(PARCHMENT_GRAY)
    b.TitleBar:SetTexCoord(0, 1, 0.91796875, 0.99609375)
    b.BottomTsunami:SetTexCoord(0, 0.72265, 0.58984375, 0.65234375)
    b.TopTsunami:SetTexCoord(0.72265, 0, 0.65234375, 0.58984375)
    b.Glow:SetVertexColor(0.22, 0.17, 0.13)
    b.IconBorder:SetVertexColor(0.75, 0.75, 0.75, 1)
    b.Icon:SetVertexColor(0.55, 0.55, 0.55, 1)
    b.Shield:SetTexCoord(0.5, 1, 0, 0.5)
    b.Points:SetVertexColor(0.65, 0.65, 0.65)
    b.Label:SetVertexColor(0.65, 0.65, 0.65)
    b.Description:SetTextColor(1, 1, 1, 1)
    b.Description:SetShadowOffset(1, -1)
    if b.Border.SetBackdropBorderColor then b.Border:SetBackdropBorderColor(0.5, 0.5, 0.5) end
end

local function initRow(b, st)
    local e = st.entry
    local done = st.done ~= nil
    b.st = st
    b.Icon:SetTexture(ns.Icon(e))
    b.Label:SetText(tostring(e.title or e.code))
    local desc = e.description
    if not desc or desc == "" then desc = e.hidden and L["Hidden achievement"] or "" end
    b.Description:SetText(desc)
    b.Points:SetText(tostring(tonumber(e.points) or 0))
    if done then
        saturate(b)
        b.Date:SetText(formatTime(st.done))
        b.Date:Show()
        b.Progress:Hide()
    else
        desaturate(b)
        b.Date:Hide()
        if st.progress and st.required and st.required > 0 then
            b.Progress:SetMinMaxValues(0, st.required)
            b.Progress:SetValue(min(st.progress, st.required))
            b.Progress.Text:SetText(progressText(st))
            b.Progress:Show()
        else
            b.Progress:Hide()
        end
    end
end


local function groupOf(entry)
    local g = GROUP_OF[entry.event]
    if g then return g end
    local p = entry.params or {}
    if entry.event == "stat" then
        local id = p.where and p.where.stat_id
        if id == 2 then return "skill" end
        if id == 1 or id == 3 then return "world" end
    elseif entry.event == "moment" then
        local m = p.match and p.match[1] and p.match[1].moment_id
        if m == 1 then return "combat" end
        return "world"
    end
    return "misc"
end

local function groupStats()
    local stats = {}
    for _, g in ipairs(GROUPS) do stats[g[1]] = { done = 0, total = 0 } end
    for _, rule in ipairs(Rules.rules) do
        local s = stats[groupOf(rule.entry)]
        s.total = s.total + 1
        local state = Rules.state[rule.code]
        if state and state.done then s.done = s.done + 1 end
    end
    return stats
end

local function byTitle(a, b)
    local ta, tb = tostring(a.entry.title or a.rule.code), tostring(b.entry.title or b.rule.code)
    if ta ~= tb then return ta < tb end
    return a.rule.code < b.rule.code
end

local function matches(st, query)
    local e = st.entry
    if tostring(e.title or e.code):lower():find(query, 1, true) then return true end
    if e.hidden and st.done == nil then return false end
    local desc = e.description
    return desc ~= nil and desc:lower():find(query, 1, true) ~= nil
end

local function achievementList(group, filter, query)
    local list = {}
    for _, st in ipairs(Rules.Status()) do
        local done = st.done ~= nil
        local inGroup = query and matches(st, query) or (not query and groupOf(st.entry) == group)
        if inGroup and (filter == "all" or (filter == "done") == done) then list[#list + 1] = st end
    end
    table.sort(list, function(a, b)
        if (a.done ~= nil) ~= (b.done ~= nil) then return a.done ~= nil end
        if a.done and b.done and a.done ~= b.done then return a.done > b.done end
        return byTitle(a, b)
    end)
    return list
end

local function recentList(limit)
    local list = {}
    for _, st in ipairs(Rules.Status()) do
        if st.done then list[#list + 1] = st end
    end
    table.sort(list, function(a, b)
        if a.done ~= b.done then return a.done > b.done end
        return byTitle(a, b)
    end)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
end

local function eventList(category)
    local list = {}
    local rec = GH.rec
    if not rec then return list end
    for seq = rec.seq or 0, 1, -1 do
        local e = rec.events[seq]
        if e and (category == "all" or CATEGORY_OF[e[2]] == category) then list[#list + 1] = { seq = seq, e = e } end
    end
    return list
end

local linkDialog
local current = { links = {}, index = 1, url = "" }

local function showPart(i)
    local f = linkDialog
    local links = current.links
    if #links == 0 then return end
    i = math.max(1, min(i, #links))
    current.index = i
    current.url = links[i].url
    f.hint:SetText(L["The link is selected. Press Ctrl + C, paste it in the browser and click Übertragen on the website."])
    f.reveal:SetEnabled(true)
    f.edit:SetText(current.url)
    f.edit:SetCursorPosition(0)
    f.edit:SetFocus()
    f.edit:HighlightText()
    f:SetRevealed(false)
    if #links > 1 then
        f.part:SetText(L["Part %d of %d"]:format(i, #links))
        f.prev:SetEnabled(i > 1)
        f.next:SetEnabled(i < #links)
        f.prev:Show()
        f.next:Show()
        f.all:Show()
    else
        f.part:SetText("")
        f.prev:Hide()
        f.next:Hide()
        f.all:Hide()
    end
    f.feedback:SetText("")
end

local function showAllParts()
    local f = linkDialog
    local urls = {}
    for _, link in ipairs(current.links) do urls[#urls + 1] = link.url end
    if #urls == 0 then return end
    current.url = table.concat(urls, " ")
    f.part:SetText(L["All %d parts"]:format(#urls))
    f.edit:SetText(current.url)
    f.edit:SetCursorPosition(0)
    f.edit:SetFocus()
    f.edit:HighlightText()
    f.feedback:SetText(L["Paste them under Link manuell einfügen on the website."])
end

local function buildLinkDialog()
    local f = CreateFrame("Frame", "TheGuildGehHeimLinkDialog", UIParent, "ButtonFrameTemplate")
    f:SetSize(560, 250)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Rune_01")
    f:SetTitle(L["Report link"])
    ButtonFrameTemplate_HideButtonBar(f)
    f.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
    local hint = UI.Label(f.Inset, L["The link is selected. Press Ctrl + C, paste it in the browser and click Übertragen on the website."], "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 12, -10)
    hint:SetPoint("RIGHT", f.Inset, "RIGHT", -12, 0)
    hint:SetWordWrap(true)
    f.hint = hint
    local box = UI.Card(f.Inset)
    box:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 8, -44)
    box:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 40)
    local scroll = CreateFrame("ScrollFrame", nil, box, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 8)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetFontObject("ChatFontSmall")
    edit:SetWidth(490)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and current.url ~= "" then
            self:SetText(current.url)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    edit:SetScript("OnKeyDown", function(_, key)
        if key == "C" and ((IsControlKeyDown and IsControlKeyDown()) or (IsMetaKeyDown and IsMetaKeyDown())) then
            f.feedback:SetText(GREEN_FONT_COLOR:WrapTextInColorCode(L["Copied!"]))
        end
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit
    f.masked = UI.Label(box, L["The link is hidden. Ctrl + C still copies it."], "GameFontDisable", "CENTER")
    f.masked:SetPoint("CENTER", box, "CENTER", 0, 0)
    f.reveal = UI.Button(f.Inset, L["Show"], 90)
    f.reveal:SetPoint("BOTTOMLEFT", f.Inset, "BOTTOMLEFT", 8, 8)
    function f:SetRevealed(shown)
        self.revealed = shown
        edit:SetTextColor(1, 1, 1, shown and 1 or 0)
        self.masked:SetShown(not shown)
        self.reveal:SetText(shown and L["Hide"] or L["Show"])
    end
    f.reveal:SetScript("OnClick", function()
        f:SetRevealed(not f.revealed)
        edit:SetFocus()
        edit:HighlightText()
    end)
    f.part = UI.Label(f.Inset, "", "GameFontNormal")
    f.part:SetPoint("LEFT", f.reveal, "RIGHT", 12, 0)
    f.feedback = UI.Label(f.Inset, "", "GameFontNormal")
    f.feedback:SetPoint("LEFT", f.part, "RIGHT", 12, 0)
    f.next = UI.Button(f.Inset, L["Next"], 90, function() showPart(current.index + 1) end)
    f.next:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -8, 8)
    f.prev = UI.Button(f.Inset, L["Back"], 90, function() showPart(current.index - 1) end)
    f.prev:SetPoint("RIGHT", f.next, "LEFT", -6, 0)
    f.all = UI.Button(f.Inset, L["All parts"], 90, showAllParts)
    f.all:SetPoint("RIGHT", f.prev, "LEFT", -6, 0)
    tinsert(UISpecialFrames, "TheGuildGehHeimLinkDialog")
    return f
end

local function errorText(err)
    if err == "no_events" then return L["Nothing recorded yet."] end
    if err == "all_confirmed" then return L["Everything is transferred already. Nothing to report. New events show up here as soon as they are recorded. Resend from in the Report tab sends older events again."] end
    if err == "not_ready" then return L["Not ready yet."] end
    return L["The link could not be built (%s)."]:format(tostring(err))
end

local function showLinks(res)
    linkDialog = linkDialog or buildLinkDialog()
    current.links = res.links
    linkDialog:Show()
    showPart(1)
    TG:Fire("GEHHEIM_LINK")
end

local function showEmpty(text)
    linkDialog = linkDialog or buildLinkDialog()
    local f = linkDialog
    current.links, current.index, current.url = {}, 1, ""
    f.hint:SetText(text)
    f.edit:SetText("")
    f.edit:ClearFocus()
    f:SetRevealed(true)
    f.reveal:SetEnabled(false)
    f.part:SetText("")
    f.feedback:SetText("")
    f.prev:Hide()
    f.next:Hide()
    f.all:Hide()
    f:Show()
end

function ns.Report()
    if not ns.InHomeGuild() then
        TG:Print(L["The report link is only available in the guild Geh Heim."])
        return
    end
    local res, err = GH:BuildLinks({})
    if not res then
        if err == "all_confirmed" then
            showEmpty(errorText(err))
        else
            TG:Print(errorText(err))
        end
        return
    end
    showLinks(res)
end

function ns.ReportFrom(n)
    if not ns.InHomeGuild() then
        TG:Print(L["The report link is only available in the guild Geh Heim."])
        return
    end
    local res, err = GH:BuildLinks({ mode = "recovery", fromSeq = n, force = true })
    if not res then
        TG:Print(errorText(err))
        return
    end
    showLinks(res)
end

function ns.ApplyCode(code, quiet)
    local rec = GH.rec
    if not rec then return L["Not ready yet."] end
    if not ns.InHomeGuild() then
        if not quiet then TG:Print(L["The report link is only available in the guild Geh Heim."]) end
        return L["The report link is only available in the guild Geh Heim."]
    end
    code = TG.Trim(tostring(code or ""))
    if code == "" then return L["Enter the code shown by the website."] end
    local n, err = Link.ApplyAck(rec, code)
    if not n then
        local text = err == "mac" and L["The code does not belong to this character."] or (err == "range" and L["The code points beyond the recorded events."] or L["The code could not be read."])
        if not quiet then TG:Print(text) end
        return text
    end
    TG:Print(L["Transferred up to event %d. Future links start after it."], n)
    TG:Fire("GEHHEIM_LINK")
    return nil
end

function ns.ShowIdCheck()
    local hint = L["Ctrl + A, Ctrl + C, then send it to the guild organisers."]
    UI.TextDialog(L["ID check"], L["Checking, this takes a few seconds."], nil, hint)
    ns.IdCheck(function(text) UI.TextDialog(L["ID check"], text, nil, hint) end)
end

local function build(panel)
    local view = { tab = "achievements", category = "all", filter = "all", group = "summary", search = "" }
    local pages = {}

    local tabs = UI.Tabs(panel, { { "achievements", L["Overview"] }, { "log", L["Log"] }, { "report", L["Report"] } }, function(id)
        view.tab = id
        panel:OnShow()
    end)
    tabs:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -4)

    local function page(id)
        local p = CreateFrame("Frame", nil, panel)
        p:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -40)
        p:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
        p:Hide()
        pages[id] = p
        return p
    end

    local ach = page("achievements")

    local side = CreateFrame("Frame", nil, ach)
    side:SetPoint("TOPLEFT", ach, "TOPLEFT", 4, -4)
    side:SetPoint("BOTTOMLEFT", ach, "BOTTOMLEFT", 4, 4)
    side:SetWidth(SIDE_WIDTH)
    side.Background = side:CreateTexture(nil, "BACKGROUND")
    side.Background:SetPoint("TOPLEFT", side, "TOPLEFT", 3, -3)
    side.Background:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -3, 3)
    side.Background:SetTexture(PARCHMENT_SIDE)
    side.Background:SetTexCoord(0, 0.5, 0, 1)
    side.Watermark = side:CreateTexture(nil, "BORDER")
    side.Watermark:SetSize(SIDE_WIDTH - 6, SIDE_WIDTH - 6)
    side.Watermark:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 3, 3)
    side.Watermark:SetTexture(WATERMARK)
    goldBorder(side)
    ach.groups = UI.List(side, 24, function(b, row)
        b.row = row
        b.Label:SetText(row.title)
        if view.group == row.id then b:LockHighlight() else b:UnlockHighlight() end
    end, {
        alternate = false,
        spacing = 0,
        top = 6,
        bottom = 6,
        left = 6,
        buildRow = function(b)
            b.Background = b:CreateTexture(nil, "BACKGROUND")
            b.Background:SetSize(170, 32)
            b.Background:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            b.Background:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
            b.Background:SetTexture(CATEGORY_BG)
            b.Background:SetTexCoord(0, 0.6640625, 0, 1)
            if b.tgStripe then b.tgStripe:Hide() end
            b:SetHighlightTexture(CATEGORY_HL, "ADD")
            local hl = b:GetHighlightTexture()
            if hl then
                hl:ClearAllPoints()
                hl:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
                hl:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, -7)
                hl:SetTexCoord(0, 0.6640625, 0, 1)
            end
            b.Label = UI.Label(b, "", font("GameFontNormalLeftBottom", "GameFontNormal"))
            b.Label:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 16, 4)
            b.Label:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -4)
            b.Label:SetWordWrap(false)
            b:SetScript("OnClick", function(self)
                view.group = self.row.id
                panel:OnShow()
            end)
            b:SetScript("OnEnter", function(self)
                local row = self.row
                if not row or not row.total then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip_SetTitle(GameTooltip, row.title)
                GameTooltip_AddNormalLine(GameTooltip, ("%d/%d"):format(row.done, row.total))
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end,
    })

    local plate = CreateFrame("Frame", nil, ach)
    plate:SetSize(133, 39)
    plate:SetPoint("TOPRIGHT", ach, "TOPRIGHT", -8, -2)
    plate.Border = plate:CreateTexture(nil, "BORDER")
    plate.Border:SetAllPoints()
    plate.Border:SetTexture(HEADER)
    plate.Border:SetTexCoord(0.419921875, 0.6796875, 0.4140625, 0.56640625)
    plate.Title = UI.Label(plate, type(ACHIEVEMENT_TITLE) == "string" and ACHIEVEMENT_TITLE or L["Achievements"], "GameFontNormalSmall", "CENTER")
    plate.Title:SetSize(150, 20)
    plate.Title:SetPoint("TOP", plate, "TOP", 0, 12)
    plate.Points = UI.Label(plate, "", "GameFontHighlight", "CENTER")
    plate.Points:SetHeight(12)
    plate.Points:SetPoint("TOP", plate, "TOP", 0, -13)
    plate.Shield = plate:CreateTexture(nil, "ARTWORK")
    plate.Shield:SetSize(20, 20)
    plate.Shield:SetPoint("LEFT", plate.Points, "RIGHT", 3, -1)
    plate.Shield:SetTexture(TINY_SHIELD)
    plate.Shield:SetTexCoord(0, 0.625, 0, 0.625)

    ach.filter = UI.Dropdown(ach, 130, function(_, root)
        for _, opt in ipairs(FILTERS) do
            root:CreateRadio(opt[2], function() return view.filter == opt[1] end, function()
                view.filter = opt[1]
                panel:OnShow()
            end)
        end
    end)
    ach.filter:SetPoint("RIGHT", plate, "LEFT", -12, -4)
    ach.search = UI.SearchBox(ach, 160, function(text)
        view.search = text:lower()
        if ach:IsShown() then panel:OnShow() end
    end)
    ach.search:SetPoint("RIGHT", ach.filter, "LEFT", -8, 0)
    panel.search = ach.search
    ach.title = UI.Label(ach, "", "GameFontNormalLarge")
    ach.title:SetPoint("TOPLEFT", side, "TOPRIGHT", 12, -12)
    ach.title:SetPoint("RIGHT", ach.search, "LEFT", -8, 0)

    local box = CreateFrame("Frame", nil, ach)
    box:SetPoint("TOPLEFT", side, "TOPRIGHT", 6, -42)
    box:SetPoint("BOTTOMRIGHT", ach, "BOTTOMRIGHT", -4, 4)
    box.Background = box:CreateTexture(nil, "BACKGROUND")
    box.Background:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    box.Background:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    box.Background:SetTexture(LIST_BG)
    box.Background:SetTexCoord(0, 1, 0, 0.5)
    goldBorder(box)

    local listFrame = CreateFrame("Frame", nil, box)
    listFrame:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    listFrame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    ach.list = UI.List(listFrame, ROW_HEIGHT, initRow, { alternate = false, spacing = 0, top = 2, bottom = 2, left = 2, buildRow = buildRow })

    local summary = CreateFrame("Frame", nil, box)
    summary:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    summary:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    summary.RecentHeader = recentHeader(summary, L["Recently earned"])
    summary.RecentHeader:SetPoint("TOPLEFT", summary, "TOPLEFT", 25, -10)
    summary.RecentHeader:SetPoint("TOPRIGHT", summary, "TOPRIGHT", -25, -10)
    local recentFrame = CreateFrame("Frame", nil, summary)
    recentFrame:SetPoint("TOPLEFT", summary.RecentHeader, "BOTTOMLEFT", -22, -4)
    recentFrame:SetPoint("TOPRIGHT", summary.RecentHeader, "BOTTOMRIGHT", 22, -4)
    recentFrame:SetHeight(ROW_HEIGHT * 3 + 6)
    summary.recent = UI.List(recentFrame, ROW_HEIGHT, initRow, { alternate = false, spacing = 0, top = 2, bottom = 2, left = 2, buildRow = buildRow })
    summary.ProgressHeader = recentHeader(summary, L["Category progress"])
    summary.ProgressHeader:SetPoint("TOPLEFT", recentFrame, "BOTTOMLEFT", 22, -14)
    summary.ProgressHeader:SetPoint("TOPRIGHT", recentFrame, "BOTTOMRIGHT", -22, -14)
    summary.Total = headerBar(summary, 488)
    summary.Total:SetPoint("TOP", summary.ProgressHeader, "BOTTOM", 0, -6)
    summary.Total.Label:SetText(L["Achievements earned"])
    summary.bars = {}
    for i, g in ipairs(GROUPS) do
        local bar = headerBar(summary, 234)
        local col, rowi = (i - 1) % 2, floor((i - 1) / 2)
        if col == 0 then
            bar:SetPoint("TOPRIGHT", summary.Total, "BOTTOM", -10, -6 - rowi * 27)
        else
            bar:SetPoint("TOPLEFT", summary.Total, "BOTTOM", 10, -6 - rowi * 27)
        end
        bar.Label:SetText(g[2])
        summary.bars[g[1]] = bar
    end

    local log = page("log")
    log.count = UI.Label(log, "", "GameFontHighlight")
    log.count:SetPoint("TOPLEFT", log, "TOPLEFT", 12, -6)
    log.category = UI.Dropdown(log, 140, function(_, root)
        for _, opt in ipairs(CATEGORIES) do
            root:CreateRadio(opt[2], function() return view.category == opt[1] end, function()
                view.category = opt[1]
                panel:OnShow()
            end)
        end
    end)
    log.category:SetPoint("TOPRIGHT", log, "TOPRIGHT", -8, -2)
    local logFrame = CreateFrame("Frame", nil, log)
    logFrame:SetPoint("TOPLEFT", log, "TOPLEFT", 4, -30)
    logFrame:SetPoint("BOTTOMRIGHT", log, "BOTTOMRIGHT", -4, 4)
    log.list = UI.List(logFrame, 20, function(b, row)
        local rec = GH.rec
        local acked = rec and Link.EnsureState(rec).acked_upto or 0
        b.time:SetText(formatTime(row.e[1]))
        b.text:SetText(ns.Describe(row.e))
        b.seq:SetText((row.seq <= acked and GREEN_FONT_COLOR or GRAY_FONT_COLOR):WrapTextInColorCode("#" .. row.seq))
    end, {
        inset = true,
        buildRow = function(b)
            b.time = UI.Cell(b, 100, "LEFT", "GameFontDisableSmall")
            b.time:SetPoint("LEFT", b, "LEFT", 8, 0)
            b.seq = UI.Cell(b, 60, "RIGHT", "GameFontHighlightSmall")
            b.seq:SetPoint("RIGHT", b, "RIGHT", -8, 0)
            b.text = UI.Cell(b, 100, "LEFT", "GameFontHighlightSmall")
            b.text:SetPoint("LEFT", b.time, "RIGHT", 4, 0)
            b.text:SetPoint("RIGHT", b.seq, "LEFT", -4, 0)
        end,
    })

    local rep = page("report")
    local card = UI.Card(rep, L["Report"])
    card:SetPoint("TOPLEFT", rep, "TOPLEFT", 8, -8)
    card:SetPoint("RIGHT", rep, "RIGHT", -8, 0)
    card:SetHeight(230)
    rep.lines = UI.Label(card, "", "GameFontHighlight")
    rep.lines:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -30)
    rep.lines:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    rep.lines:SetWordWrap(true)
    rep.lines:SetSpacing(3)
    rep.report = UI.Button(card, L["Create link"], 150, function() ns.Report() end)
    rep.report:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 10, 10)
    rep.code = UI.Button(card, L["Website code"], 150, function()
        UI.FormDialog(L["Website code"], {
            { key = "code", label = L["Code"], required = true, max = 40, hint = L["Shown by the website after redeeming"] },
        }, function(values) return ns.ApplyCode(values.code, true) end)
    end)
    rep.code:SetPoint("LEFT", rep.report, "RIGHT", 6, 0)
    rep.resend = UI.Button(card, L["Resend from"], 110, function()
        UI.FormDialog(L["Resend events"], {
            { key = "from", label = L["From number"], required = true, max = 7, hint = L["First event number the website is missing"] },
        }, function(values)
            local n = tonumber(values.from)
            if not n or n < 1 then return L["Enter an event number."] end
            ns.ReportFrom(floor(n))
            return nil
        end)
    end)
    rep.resend:SetPoint("LEFT", rep.code, "RIGHT", 6, 0)
    local function refreshAchievements()
        local done, total, earned, points = Rules.Summary()
        local stats = groupStats()
        local rows = { { id = "summary", title = L["Summary"] } }
        for _, g in ipairs(GROUPS) do
            local st = stats[g[1]]
            rows[#rows + 1] = { id = g[1], title = g[2], done = st.done, total = st.total }
        end
        ach.groups:SetData(rows)
        local pointsText = BreakUpLargeNumbers and BreakUpLargeNumbers(earned)
        plate.Points:SetText(type(pointsText) == "string" and pointsText or tostring(earned))
        local query = view.search ~= "" and view.search or nil
        local isSummary = view.group == "summary" and not query
        summary:SetShown(isSummary)
        listFrame:SetShown(not isSummary)
        ach.filter:SetShown(not isSummary)
        if isSummary then
            ach.title:SetText(L["Summary"])
            summary.Total:Set(done, total)
            for _, g in ipairs(GROUPS) do
                local st = stats[g[1]]
                summary.bars[g[1]]:Set(st.done, st.total)
            end
            summary.recent:SetData(recentList(10))
        else
            local rows = achievementList(view.group, view.filter, query)
            ach.rows = rows
            if query then
                ach.title:SetText(("%s  |cffffffff%d|r"):format(L["Search"], #rows))
            else
                local st = stats[view.group]
                local title = view.group
                for _, g in ipairs(GROUPS) do
                    if g[1] == view.group then title = g[2] end
                end
                ach.title:SetText(("%s  |cffffffff%d/%d|r"):format(title, st.done, st.total))
            end
            ach.filter:GenerateMenu()
            ach.list:SetData(rows)
        end
    end

    local function refreshLog()
        local rows = eventList(view.category)
        local rec = GH.rec
        log.count:SetText(L["%d events, %d shown"]:format(rec and rec.seq or 0, #rows))
        log.category:GenerateMenu()
        log.list:SetData(rows)
    end

    local function refreshReport()
        local rec = GH.rec
        if not rec then
            rep.lines:SetText(L["Not ready yet."])
            return
        end
        if not ns.InHomeGuild() then
            rep.lines:SetText(L["The report link is only available in the guild Geh Heim."])
            rep.report:SetEnabled(false)
            rep.code:SetEnabled(false)
            rep.resend:SetEnabled(false)
            return
        end
        rep.code:SetEnabled(true)
        rep.resend:SetEnabled(true)
        local s = Link.EnsureState(rec)
        local open = Link.UnconfirmedCount(rec)
        local lines = {
            L["Character: %s"]:format(rec.name or "?"),
            L["Recorded events: %d"]:format(rec.seq or 0),
            L["Open: %d"]:format(open),
            L["New since the last link: %d"]:format(Link.NewEventCount(rec)),
            L["Links built: %d"]:format(s.link_no or 0),
            L["Website code applied: %s"]:format(s.confirmed and L["yes"] or L["no"]),
        }
        if s.last and s.last.created then lines[#lines + 1] = L["Last link: %s"]:format(formatTime(s.last.created)) end
        if open > 200 then lines[#lines + 1] = YELLOW_FONT_COLOR:WrapTextInColorCode(L["More than 200 open events. Apply the code from the website so links stay short."]) end
        if rec.imported_at then lines[#lines + 1] = GRAY_FONT_COLOR:WrapTextInColorCode(L["Taken over from GehHeim on %s with %d events"]:format(formatTime(rec.imported_at), rec.imported_seq or 0)) end
        if GH.passive then lines[#lines + 1] = RED_FONT_COLOR:WrapTextInColorCode(L["The old GehHeim addon is still loaded. Recording is off."]) end
        rep.lines:SetText(table.concat(lines, "\n"))
        rep.report:SetEnabled(not GH.passive and (rec.seq or 0) > 0)
    end

    panel.locked = UI.Label(panel, L["This module needs the Geh Heim addon in the AddOns folder. It can stay disabled in the AddOn list."], "GameFontHighlight", "CENTER")
    panel.locked:SetPoint("CENTER")
    panel.locked:SetWidth(420)
    panel.locked:SetWordWrap(true)
    panel.locked:Hide()

    function panel:OnShow()
        local home = ns.InHomeGuild()
        if not home then view.tab = "achievements" end
        local locked = GH.locked == true
        panel.locked:SetShown(locked)
        tabs:SetShown(home and not locked)
        for id, p in pairs(pages) do
            p:SetShown(id == view.tab and not locked)
            p:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, home and -40 or -4)
        end
        if locked then return end
        if home then tabs:Select(view.tab) end
        if view.tab == "achievements" then
            refreshAchievements()
        elseif view.tab == "log" then
            refreshLog()
        else
            refreshReport()
        end
    end

    local function visibleRefresh()
        if panel:IsVisible() then panel:OnShow() end
    end
    TG:On("GEHHEIM_ACHIEVEMENTS", function() if panel:IsVisible() and view.tab == "achievements" then refreshAchievements() end end, GH)
    TG:On("GEHHEIM_EVENT", function() if panel:IsVisible() and view.tab ~= "achievements" then visibleRefresh() end end, GH)
    TG:On("GEHHEIM_READY", visibleRefresh, GH)
    TG:On("GEHHEIM_LINK", function() if panel:IsVisible() and view.tab == "report" then refreshReport() end end, GH)
end

local TAB_ICON = { atlas = "UI-HUD-MicroMenu-Achievements-Up", file = ns.FileExists("Interface\\Icons\\Achievement_General") and "Interface\\Icons\\Achievement_General" or "Interface\\Icons\\INV_Misc_Rune_01" }
TG.Window:RegisterTab("gehheim", L["Achievements"], build, 29, TAB_ICON, "GehHeim")
