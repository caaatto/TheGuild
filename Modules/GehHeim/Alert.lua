local TG = TheGuild
local ns = TG.GH
if ns.off then return end
local L = ns.L
local UI = TG.UI

local Alert = {}
ns.Alert = Alert

local ICON_PATH = "Interface\\Icons\\"
local FALLBACK_ICON = ICON_PATH .. "INV_Misc_QuestionMark"
local HIDDEN_ICON = ICON_PATH .. "INV_Misc_Rune_01"
local ACHIEVEMENT_SOUND_FILE = 569593

local SKILL_ICONS = {
    [171] = "Trade_Alchemy", [164] = "Trade_BlackSmithing", [333] = "Trade_Engraving", [202] = "Trade_Engineering",
    [182] = "Spell_Nature_NatureTouchGrow", [165] = "INV_Misc_ArmorKit_17", [186] = "Trade_Mining", [393] = "INV_Misc_Pelt_Wolf_01",
    [197] = "Trade_Tailoring", [185] = "INV_Misc_Food_15", [129] = "Spell_Holy_SealOfSacrifice", [356] = "Trade_Fishing", [762] = "Ability_Mount_RidingHorse",
    [43] = "INV_Sword_27", [55] = "Ability_MeleeDamage", [44] = "INV_Axe_01", [172] = "INV_Axe_09", [54] = "INV_Mace_01", [160] = "INV_Mace_04",
    [229] = "INV_Spear_06", [136] = "INV_Staff_08", [173] = "Ability_SteelMelee", [473] = "INV_Gauntlets_04", [45] = "INV_Weapon_Bow_07",
    [46] = "INV_Weapon_Rifle_01", [226] = "INV_Weapon_Crossbow_02", [176] = "Ability_Throw", [228] = "Ability_ShootWand", [162] = "Ability_GolemThunderClap",
    [95] = "Ability_Defend",
}

local ICONS = {
    boss_guild_5 = "INV_Misc_GroupNeedMore", boss_guild_raid = "INV_Misc_GroupLooking", boss_screenshot = "INV_Misc_Spyglass_03",
    boss_tabard = "INV_Shirt_GuildTabard_01", capitals_all = "INV_Misc_Map_01",
    death_1 = "INV_Misc_Bone_HumanSkull_01", death_25 = "INV_Misc_Bone_HumanSkull_01", death_100 = "Spell_Shadow_DeathScream",
    death_drown = "Spell_Frost_SummonWaterElemental", death_enemy_capital = "INV_BannerPVP_01", death_fall = "Spell_Magic_FeatherFall",
    death_fatigue = "Spell_Nature_Sleep", death_hogger = "INV_Misc_MonsterClaw_03", death_lava = "Spell_Fire_LavaSpawn",
    death_lowlevel = "Ability_Rogue_FeignDeath", death_oneshot = "Ability_Warrior_Decisivestrike",
    fight_long = "Ability_Warrior_EndlessRage", fish_100 = "INV_Fishingpole_02", fish_500 = "Trade_Fishing", fish_2500 = "INV_Misc_Fish_24",
    fish_junk = "INV_Misc_Gear_01", fish_rare = "INV_Misc_Fish_24",
    gold_100 = "INV_Misc_Coin_01", gold_500 = "INV_Misc_Coin_02", gold_1000 = "INV_Misc_Coin_17",
    hearth_1 = "INV_Misc_Rune_01", hearth_100 = "INV_Misc_Rune_01", hearth_after_wipe = "INV_Misc_Rune_01",
    hogger = "INV_Misc_MonsterClaw_03", mount_first = "Ability_Mount_RidingHorse", naked_10 = "INV_Chest_Cloth_17", pets_10 = "INV_Box_PetCarrier_01",
    quests_100 = "Achievement_Quests_Completed_01", quests_250 = "Achievement_Quests_Completed_02", quests_500 = "Achievement_Quests_Completed_03", quests_1000 = "Achievement_Quests_Completed_04",
    rare_1 = "Ability_Hunter_MarkedForDeath", rare_10 = "Ability_Hunter_SniperShot",
    rep_capitals_horde = "INV_BannerPVP_01", rep_cartel = "INV_Misc_Coin_02", rep_exalted_10 = "Achievement_Reputation_06", rep_exalted_20 = "Achievement_Reputation_08",
    toys_10 = "INV_Misc_Toy_10", walk_45k = "Ability_Rogue_Sprint", walk_100k = "Ability_Rogue_Sprint", walk_500k = "Ability_Druid_Dash",
    wipe_1 = "Ability_Creature_Cursed_02", wipe_10 = "Spell_Shadow_Raisedead", wipe_25 = "Spell_Shadow_Raisedead",
    boss_guild_5_x5 = "INV_Misc_GroupNeedMore", boss_guild_5_x10 = "INV_Misc_GroupNeedMore", boss_guild_5_x25 = "INV_Misc_GroupNeedMore",
    boss_guild_5_x50 = "INV_Misc_GroupLooking", boss_guild_5_x100 = "INV_Misc_GroupLooking", boss_guild_5_x500 = "INV_Misc_GroupLooking",
    buff_world_1 = "INV_Misc_Head_Dragon_01", buff_world_all = "INV_Misc_Head_Dragon_01", camp_fire = "Spell_Fire_Fire",
    dng_all = "INV_Misc_Key_14", dng_clean_1 = "Spell_Holy_Renew", dng_clean_5 = "Spell_Holy_Renew", dng_clean_10 = "Spell_Holy_Renew",
    mount_riding_150 = "Ability_Mount_WhiteTiger", raid_onyxia = "INV_Misc_Head_Dragon_01", salute_horde = "INV_BannerPVP_01",
    recipe_any_25 = "INV_Scroll_03", recipe_any_100 = "INV_Scroll_03", recipe_any_250 = "INV_Scroll_03",
    tf_all = "INV_Misc_Orb_02", tf_ninja = "INV_Misc_MonsterHead_01", tf_pirate = "INV_Misc_MonsterHead_01", tf_ogre = "INV_Misc_Head_Orc_01",
    tf_orb = "INV_Misc_Orb_02", tf_shrink = "INV_Potion_83", tf_skeleton = "INV_Potion_83",
    sec_mounts_5 = "Ability_Mount_Dreadsteed",
}

local PREFIX_ICONS = {
    level = "Achievement_Level_%s", skill = nil, rep = "Achievement_Reputation_01", death = "INV_Misc_Bone_HumanSkull_01",
    fish = "Trade_Fishing", gold = "INV_Misc_Coin_01", hearth = "INV_Misc_Rune_01", quests = "INV_Misc_Note_01",
    rare = "Ability_Hunter_MarkedForDeath", walk = "Ability_Rogue_Sprint", wipe = "Spell_Shadow_Raisedead", boss = "INV_Misc_Head_Dragon_01",
    dng = "INV_Misc_Key_03", craft = "Trade_BlackSmithing", mount = "Ability_Mount_RidingHorse", tf = "INV_Misc_MonsterHead_01",
}

local iconCache = {}

local function exists(path)
    if type(GetFileIDFromPath) ~= "function" then return true end
    local ok, id = pcall(GetFileIDFromPath, path)
    return ok and id ~= nil
end
ns.FileExists = exists

function ns.Icon(entry)
    local code = entry and entry.code or "?"
    local cached = iconCache[code]
    if cached then return cached end
    local name = entry and entry.icon or ICONS[code]
    if not name then
        local prefix, rest = code:match("^([a-z]+)_(.*)$")
        if prefix == "skill" or prefix == "recipe" then
            local id = tonumber(rest and rest:match("^(%d+)"))
            name = SKILL_ICONS[id]
        elseif prefix == "level" then
            name = PREFIX_ICONS.level:format(rest)
        elseif prefix == "rep" then
            name = rest and rest:match("_8$") and "Achievement_Reputation_08" or "Achievement_Reputation_01"
        else
            name = PREFIX_ICONS[prefix]
        end
    end
    local path = name and (ICON_PATH .. name) or nil
    if not path or not exists(path) then
        if name and name:find("^Achievement_Reputation") then path = ICON_PATH .. "INV_Misc_Note_02"
        elseif name and name:find("^Achievement_Quests") then path = ICON_PATH .. "INV_Misc_Note_01"
        elseif name and name:find("^Achievement_Level") then path = ICON_PATH .. "Spell_Holy_Heroism"
        else path = FALLBACK_ICON end
        if not exists(path) then path = FALLBACK_ICON end
    end
    iconCache[code] = path
    return path
end

local function shieldPoints(fs, points)
    fs:SetFontObject(points < 100 and "GameFontNormal" or "GameFontNormalSmall")
    fs:SetText(points > 0 and tostring(points) or "")
end

local function tooltip(self)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip_SetTitle(GameTooltip, tostring(e.title or e.code))
    if e.description and e.description ~= "" then GameTooltip_AddNormalLine(GameTooltip, e.description, true) end
    GameTooltip_AddDisabledLine(GameTooltip, L["%d points, %d as pioneer"]:format(tonumber(e.points) or 0, tonumber(e.pioneer) or 0))
    GameTooltip:Show()
end

local function setup(frame, entry)
    frame.entry = entry
    local points = tonumber(entry.points) or 0
    local guild = ns.Mod.db.style == "guild" and UI.HasAtlas("ui-achievement-guild-background")
    frame.Name:SetText(tostring(entry.title or entry.code))
    local shield = frame.Shield
    shieldPoints(shield.Points, points)
    shield.Points:Show()
    shield.Icon:Show()
    if guild then
        frame:SetHeight(104)
        frame.Background:SetAtlas("ui-achievement-guild-background", TextureKitConstants.UseAtlasSize)
        frame.Icon.Overlay:SetAtlas("ui-achievement-guild-iconframe", TextureKitConstants.UseAtlasSize)
        frame.Icon.Overlay:SetPoint("CENTER", 0, 0)
        frame.Icon:SetPoint("TOPLEFT", 0, -25)
        frame.Icon.Texture:SetPoint("CENTER", -1, -2)
        frame.Shield:SetPoint("TOPRIGHT", -12, -25)
        shield.Points:SetPoint("CENTER", 2, -2)
        shield.Points:SetVertexColor(0, 1, 0)
        frame.Unlocked:SetPoint("TOP", 0, -38)
        frame.Unlocked:SetText(entry.hidden and L["Hidden guild achievement discovered"] or L["Guild achievement earned"])
        frame.GuildName:SetText(TG.plain(GetGuildInfo("player"), L["Geh Heim"]))
        frame.GuildName:Show()
        frame.GuildBanner:Show()
        frame.GuildBorder:Show()
        if UI.HasAtlas("ui-achievement-guild-glow") then frame.glow:SetAtlas("ui-achievement-guild-glow", TextureKitConstants.UseAtlasSize) end
        if UI.HasAtlas("ui-achievement-guild-shine") then frame.shine:SetAtlas("ui-achievement-guild-shine", TextureKitConstants.UseAtlasSize) end
        frame.shine:SetPoint("BOTTOMLEFT", 0, 16)
        pcall(SetSmallGuildTabardTextures, "player", nil, frame.GuildBanner, frame.GuildBorder)
    else
        frame:SetHeight(101)
        frame.Background:SetAtlas("ui-achievement-alert-background", TextureKitConstants.UseAtlasSize)
        frame.Icon.Overlay:SetAtlas("ui-achievement-iconframe", TextureKitConstants.UseAtlasSize)
        frame.Icon.Overlay:SetPoint("CENTER", -1, 1)
        frame.Icon:SetPoint("TOPLEFT", -4, -15)
        frame.Icon.Texture:SetPoint("CENTER", 0, 0)
        frame.Shield:SetPoint("TOPRIGHT", -8, -15)
        shield.Points:SetPoint("CENTER", 2, -2)
        shield.Points:SetVertexColor(1, 1, 1)
        frame.Unlocked:SetPoint("TOP", 7, -23)
        frame.Unlocked:SetText(entry.hidden and L["Hidden achievement discovered"] or L["Achievement earned"])
        frame.GuildName:Hide()
        frame.GuildBorder:Hide()
        frame.GuildBanner:Hide()
        if UI.HasAtlas("ui-achievement-alert-glow-glow") then frame.glow:SetAtlas("ui-achievement-alert-glow-glow", TextureKitConstants.UseAtlasSize) end
        if UI.HasAtlas("ui-achievement-alert-glow-shine") then frame.shine:SetAtlas("ui-achievement-alert-glow-shine", TextureKitConstants.UseAtlasSize) end
        frame.shine:SetPoint("BOTTOMLEFT", 0, 8)
    end
    shield.Icon:SetAtlas(points == 0 and "UI-Achievement-Shield-NoPoints" or "ui-achievement-shield-2", TextureKitConstants.UseAtlasSize)
    frame.Icon.Texture:SetTexture(ns.Icon(entry))
    if not frame.tgScripts then
        frame.tgScripts = true
        frame:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                self:Hide()
            else
                TG.Window:ShowTab("gehheim")
            end
        end)
        frame:SetScript("OnEnter", tooltip)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return true
end

local system
local systemTried = false

local function blizzardSystem()
    if system or systemTried then return system end
    systemTried = true
    if type(AlertFrame) ~= "table" or type(AlertFrame.AddQueuedAlertFrameSubSystem) ~= "function" or not UI.HasAtlas("ui-achievement-alert-background") then return nil end
    if not AchievementShield_OnLoad and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_AchievementUI") end
    if not AchievementShield_OnLoad then AchievementShield_OnLoad = function() end end
    local ok, sys = pcall(AlertFrame.AddQueuedAlertFrameSubSystem, AlertFrame, "AchievementAlertFrameTemplate", setup, 2, 6)
    if ok and sys then system = sys end
    return system
end

local simple
local queue = {}
local showing = false

local function nextSimple()
    if showing or #queue == 0 then return end
    local entry = table.remove(queue, 1)
    showing = true
    local f = simple
    f.entry = entry
    f.Title:SetText(tostring(entry.title or entry.code))
    f.Label:SetText(entry.hidden and L["Hidden achievement discovered"] or L["Achievement earned"])
    f.Points:SetText(("+%d"):format(tonumber(entry.points) or 0))
    f.Icon:SetTexture(ns.Icon(entry))
    f:SetAlpha(1)
    f:Show()
    if f.anim then
        f.anim:Play()
    else
        TG.After(5, function() f:Hide() showing = false nextSimple() end)
    end
end

local function buildSimple()
    local f = CreateFrame("Button", nil, UIParent, "TooltipBackdropTemplate")
    f:SetSize(300, 72)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetSize(46, 46)
    f.Icon:SetPoint("LEFT", 12, 0)
    f.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.Label = UI.Label(f, "", "GameFontNormalSmall")
    f.Label:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 10, -2)
    f.Label:SetPoint("RIGHT", f, "RIGHT", -48, 0)
    f.Title = UI.Label(f, "", "GameFontHighlightLarge")
    f.Title:SetPoint("TOPLEFT", f.Label, "BOTTOMLEFT", 0, -4)
    f.Title:SetPoint("RIGHT", f, "RIGHT", -48, 0)
    f.Title:SetWordWrap(false)
    f.Points = UI.Label(f, "", "GameFontNormal", "RIGHT")
    f.Points:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f:Hide()
    pcall(function()
        local ag = f:CreateAnimationGroup()
        local fadeIn = ag:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(1) fadeIn:SetDuration(0.3) fadeIn:SetOrder(1)
        local hold = ag:CreateAnimation("Alpha")
        hold:SetFromAlpha(1) hold:SetToAlpha(1) hold:SetDuration(5) hold:SetOrder(2)
        local fadeOut = ag:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1) fadeOut:SetToAlpha(0) fadeOut:SetDuration(0.8) fadeOut:SetOrder(3)
        ag:SetScript("OnFinished", function() f:Hide() showing = false nextSimple() end)
        f.anim = ag
    end)
    f:RegisterForClicks("AnyUp")
    f:SetScript("OnClick", function(self)
        if self.anim and self.anim:IsPlaying() then self.anim:Stop() end
        self:Hide()
        showing = false
        nextSimple()
    end)
    f:SetScript("OnEnter", tooltip)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

local notice
local notices = {}
local noticeShowing = false
local criteria, criteriaTried

local function setupCriteria(frame, data)
    frame.id = nil
    frame.Icon.Texture:SetTexture(data.icon)
    frame.Name:SetText(data.text)
    frame.Unlocked:SetText(ACHIEVEMENT_PROGRESSED)
end

local function criteriaSystem()
    if criteria or criteriaTried then return criteria end
    criteriaTried = true
    if type(AlertFrame) ~= "table" or type(AlertFrame.AddQueuedAlertFrameSubSystem) ~= "function" or type(ACHIEVEMENT_PROGRESSED) ~= "string" then return nil end
    local ok, probe = pcall(CreateFrame, "Button", nil, UIParent, "CriteriaAlertFrameTemplate")
    if not ok or type(probe) ~= "table" then return nil end
    probe:Hide()
    local fits = type(probe.Icon) == "table" and type(probe.Icon.Texture) == "table" and type(probe.Name) == "table" and type(probe.Unlocked) == "table"
    if not fits then return nil end
    local sys
    ok, sys = pcall(AlertFrame.AddQueuedAlertFrameSubSystem, AlertFrame, "CriteriaAlertFrameTemplate", setupCriteria, 3, math.huge)
    if ok and sys then criteria = sys end
    return criteria
end

local function nextNotice()
    if noticeShowing then return end
    local data = table.remove(notices, 1)
    if not data then return end
    local msg = L["Milestone recorded: %s"]:format(data.text)
    if not notice then
        notice = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
        notice:SetSize(360, 34)
        notice:SetPoint("TOP", UIParent, "TOP", 0, -120)
        notice:SetFrameStrata("HIGH")
        notice.Text = UI.Label(notice, "", "GameFontHighlight", "CENTER")
        notice.Text:SetPoint("CENTER")
        notice.Text:SetWidth(340)
        notice:Hide()
        pcall(function()
            local ag = notice:CreateAnimationGroup()
            local fadeIn = ag:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(1) fadeIn:SetDuration(0.2) fadeIn:SetOrder(1)
            local hold = ag:CreateAnimation("Alpha")
            hold:SetFromAlpha(1) hold:SetToAlpha(1) hold:SetDuration(3) hold:SetOrder(2)
            local fadeOut = ag:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(1) fadeOut:SetToAlpha(0) fadeOut:SetDuration(0.6) fadeOut:SetOrder(3)
            ag:SetScript("OnFinished", function() notice:Hide() noticeShowing = false nextNotice() end)
            notice.anim = ag
        end)
    end
    noticeShowing = true
    notice.Text:SetText(msg)
    notice:Show()
    if notice.anim then
        notice.anim:Play()
    else
        TG.After(3.5, function() notice:Hide() noticeShowing = false nextNotice() end)
    end
end

function ns.Notice(text, code)
    if not ns.Mod.db.notices or ns.Mod.passive then return end
    ns.lastNotice = text
    local data = { text = text, icon = ns.Icon({ code = code or "?" }) }
    local sys = criteriaSystem()
    if sys then
        sys:AddAlert(data)
        return
    end
    for _, q in ipairs(notices) do
        if q.text == text then return end
    end
    if #notices >= 5 then table.remove(notices, 1) end
    notices[#notices + 1] = data
    nextNotice()
end

function Alert.Show(entry)
    if type(entry) ~= "table" then return end
    local sys = blizzardSystem()
    if sys then
        sys:AddAlert(entry)
        return
    end
    simple = simple or buildSimple()
    if #queue >= 10 then table.remove(queue, 1) end
    queue[#queue + 1] = entry
    nextSimple()
end

function Alert.Sound()
    local mode = ns.Mod.db.sound
    if mode == "off" then return end
    if mode == "file" then
        pcall(PlaySoundFile, "Interface\\AddOns\\TheGuild\\Modules\\GehHeim\\Sounds\\achievement.ogg", "Master")
        return
    end
    if mode == "lfg" then
        pcall(PlaySound, SOUNDKIT.LFG_REWARDS, "Master")
        return
    end
    if mode == "quest" then
        pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_COMPLETE, "Master")
        return
    end
    local ok, played = pcall(PlaySoundFile, ACHIEVEMENT_SOUND_FILE, "Master")
    if not (ok and played) then pcall(PlaySound, SOUNDKIT.LFG_REWARDS, "Master") end
end
