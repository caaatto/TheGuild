local TG = TheGuild
local L = TG.L
local UI = TG.UI

local LEVEL_SETS = {
    all = { 10, 20, 30, 40, 50, 60 },
    high = { 30, 40, 50, 60 },
    cap = { 60 },
}
local ACHIEVEMENT_SOUND_FILE = 569593
local REPEAT_WINDOW = 600
local JOIN_BURST = 3
local ICON_PATH = "Interface\\Icons\\"
local FALLBACK_ICON = ICON_PATH .. "INV_Misc_QuestionMark"
local SAMPLE_ITEM = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"

local Milestones = TG:NewModule("Milestones", {
    title = L["Milestones"],
    desc = L["Toasts in the client's own style when guild members reach milestone levels, find epic items or join the guild."],
    order = 31,
    defaults = { levels = "high", finds = 4, joins = true, sound = true },
    charDefaults = {},
    settings = {
        { key = "levels", type = "select", name = L["Level milestones"], default = "high",
          options = { { "off", L["Off"] }, { "cap", L["Only level 60"] }, { "high", L["30, 40, 50 and 60"] }, { "all", L["Every ten levels"] } } },
        { key = "finds", type = "select", name = L["Item finds"], tooltip = L["Finds come from every member with the addon. Sharing and the quality are core settings."], default = 4,
          options = { { 0, L["Off"] }, { 4, ITEM_QUALITY4_DESC or "Epic" }, { 3, ITEM_QUALITY3_DESC or "Rare" } } },
        { key = "joins", type = "boolean", name = L["New members"], default = true },
        { key = "sound", type = "boolean", name = L["Play a sound"], default = true },
    },
})

local useAtlasSize = TextureKitConstants and TextureKitConstants.UseAtlasSize or true
local iconCache = {}
local joinBurst = {}

local function exists(path)
    if type(GetFileIDFromPath) ~= "function" then return true end
    local ok, id = pcall(GetFileIDFromPath, path)
    return ok and id ~= nil
end

local function icon(name, fallback)
    local hit = iconCache[name]
    if hit then return hit end
    local path = ICON_PATH .. name
    if not exists(path) then
        path = ICON_PATH .. fallback
        if not exists(path) then path = FALLBACK_ICON end
    end
    iconCache[name] = path
    return path
end

local function itemIcon(link)
    local _, _, _, _, _, _, _, _, _, texture = C_Item.GetItemInfo(link)
    if TG.usable(texture) and texture then return texture end
    local id = tonumber(link:match("item:(%d+)"))
    local byId = id and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return TG.usable(byId) and byId or FALLBACK_ICON
end

local function itemName(link)
    local name = C_Item.GetItemInfo(link)
    if TG.usable(name) and name then return name end
    return link:match("%[(.-)%]") or ""
end

local function memberTooltip(self)
    local t = self.toast
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip_SetTitle(GameTooltip, TG.ClassText(t.classFile, t.key))
    if t.level then GameTooltip_AddNormalLine(GameTooltip, L["Level"] .. " " .. tostring(t.level)) end
    GameTooltip:Show()
end

local function setupAchievement(frame, t)
    frame.toast = t
    local guild = UI.HasAtlas("ui-achievement-guild-background")
    frame.Name:SetText(t.title)
    local shield = frame.Shield
    shield.Points:SetFontObject("GameFontNormal")
    shield.Points:SetText(t.points and tostring(t.points) or "")
    shield.Points:Show()
    shield.Icon:Show()
    shield.Icon:SetAtlas(t.points and "ui-achievement-shield-2" or "UI-Achievement-Shield-NoPoints", useAtlasSize)
    frame.Unlocked:SetText(L["Guild milestone"])
    if guild then
        frame:SetHeight(104)
        frame.Background:SetAtlas("ui-achievement-guild-background", useAtlasSize)
        frame.Icon.Overlay:SetAtlas("ui-achievement-guild-iconframe", useAtlasSize)
        frame.Icon.Overlay:SetPoint("CENTER", 0, 0)
        frame.Icon:SetPoint("TOPLEFT", 0, -25)
        frame.Icon.Texture:SetPoint("CENTER", -1, -2)
        frame.Shield:SetPoint("TOPRIGHT", -12, -25)
        shield.Points:SetPoint("CENTER", 2, -2)
        shield.Points:SetVertexColor(0, 1, 0)
        frame.Unlocked:SetPoint("TOP", 0, -38)
        frame.GuildName:SetText(TG.Roster:GuildName() or TG.plain(GetGuildInfo("player"), ""))
        frame.GuildName:Show()
        frame.GuildBanner:Show()
        frame.GuildBorder:Show()
        if UI.HasAtlas("ui-achievement-guild-glow") then frame.glow:SetAtlas("ui-achievement-guild-glow", useAtlasSize) end
        if UI.HasAtlas("ui-achievement-guild-shine") then frame.shine:SetAtlas("ui-achievement-guild-shine", useAtlasSize) end
        frame.shine:SetPoint("BOTTOMLEFT", 0, 16)
        pcall(SetSmallGuildTabardTextures, "player", nil, frame.GuildBanner, frame.GuildBorder)
    else
        frame:SetHeight(101)
        frame.Background:SetAtlas("ui-achievement-alert-background", useAtlasSize)
        frame.Icon.Overlay:SetAtlas("ui-achievement-iconframe", useAtlasSize)
        frame.Icon.Overlay:SetPoint("CENTER", -1, 1)
        frame.Icon:SetPoint("TOPLEFT", -4, -15)
        frame.Icon.Texture:SetPoint("CENTER", 0, 0)
        frame.Shield:SetPoint("TOPRIGHT", -8, -15)
        shield.Points:SetPoint("CENTER", 2, -2)
        shield.Points:SetVertexColor(1, 1, 1)
        frame.Unlocked:SetPoint("TOP", 7, -23)
        frame.GuildName:Hide()
        frame.GuildBorder:Hide()
        frame.GuildBanner:Hide()
        if UI.HasAtlas("ui-achievement-alert-glow-glow") then frame.glow:SetAtlas("ui-achievement-alert-glow-glow", useAtlasSize) end
        if UI.HasAtlas("ui-achievement-alert-glow-shine") then frame.shine:SetAtlas("ui-achievement-alert-glow-shine", useAtlasSize) end
        frame.shine:SetPoint("BOTTOMLEFT", 0, 8)
    end
    frame.Icon.Texture:SetTexture(t.icon)
    if not frame.tgScripts then
        frame.tgScripts = true
        frame:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                self:Hide()
            else
                TG.Window:ShowTab("members")
            end
        end)
        frame:SetScript("OnEnter", memberTooltip)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return true
end

local function setupLoot(frame, t)
    frame.toast = t
    frame.Background:SetPoint("CENTER", 0, 0)
    frame.Background:Show()
    frame.BGAtlas:Hide()
    frame.PvPBackground:Hide()
    frame.RatedPvPBackground:Hide()
    frame.glow.suppressGlow = nil
    frame.Label:SetText(t.label)
    frame.Label:SetPoint("TOPLEFT", frame.lootItem.Icon, "TOPRIGHT", 7, 5)
    frame.ItemName:SetText(itemName(t.link))
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[t.quality]
    if color then frame.ItemName:SetVertexColor(color.r, color.g, color.b) end
    frame.lootItem:Init(t.link, 1, nil, false, false, true, false, "BORDER")
    frame.RollTypeIcon:Hide()
    frame.RollValue:Hide()
    frame.hyperlink = t.link
    frame.isCurrency = false
    if not frame.tgScripts then
        frame.tgScripts = true
        frame:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                self:Hide()
            elseif self.hyperlink and IsModifiedClick() then
                HandleModifiedItemClick(self.hyperlink)
            end
        end)
    end
    return true
end

local systems = {}
local tried = {}

local function system(kind)
    if systems[kind] or tried[kind] then return systems[kind] end
    tried[kind] = true
    if type(AlertFrame) ~= "table" or type(AlertFrame.AddQueuedAlertFrameSubSystem) ~= "function" then return nil end
    local template, setup
    if kind == "find" then
        if not UI.HasAtlas("loottoast-glow") then return nil end
        template, setup = "LootWonAlertFrameTemplate", setupLoot
    else
        if not UI.HasAtlas("ui-achievement-alert-background") then return nil end
        if not AchievementShield_OnLoad and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_AchievementUI") end
        if not AchievementShield_OnLoad then AchievementShield_OnLoad = function() end end
        template, setup = "AchievementAlertFrameTemplate", setupAchievement
    end
    local ok, sys = pcall(AlertFrame.AddQueuedAlertFrameSubSystem, AlertFrame, template, setup, 2, 6)
    if ok and sys then systems[kind] = sys end
    return systems[kind]
end

local simple
local queue = {}
local showing = false

local function nextSimple()
    if showing or #queue == 0 then return end
    local t = table.remove(queue, 1)
    showing = true
    local f = simple
    f.toast = t
    if t.kind == "find" then
        f.Label:SetText(t.label)
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[t.quality]
        f.Title:SetText(color and color.hex and (color.hex .. itemName(t.link) .. "|r") or itemName(t.link))
        f.Icon:SetTexture(itemIcon(t.link))
    else
        f.Label:SetText(L["Guild milestone"])
        f.Title:SetText(t.title)
        f.Icon:SetTexture(t.icon)
    end
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
    f.Label:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.Title = UI.Label(f, "", "GameFontHighlightLarge")
    f.Title:SetPoint("TOPLEFT", f.Label, "BOTTOMLEFT", 0, -4)
    f.Title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.Title:SetWordWrap(false)
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
    f:SetScript("OnEnter", function(self)
        local t = self.toast
        if t and t.kind == "find" then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetHyperlink(t.link)
            GameTooltip:Show()
        else
            memberTooltip(self)
        end
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return f
end

function Milestones:Sound(t)
    if t.kind == "find" then
        local kit = SOUNDKIT and ((t.quality or 0) >= 5 and SOUNDKIT.UI_LEGENDARY_LOOT_TOAST or SOUNDKIT.UI_EPICLOOT_TOAST)
        if kit then pcall(PlaySound, kit, "Master") end
        return
    end
    local ok, played = pcall(PlaySoundFile, ACHIEVEMENT_SOUND_FILE, "Master")
    if not (ok and played) and SOUNDKIT and SOUNDKIT.LFG_REWARDS then pcall(PlaySound, SOUNDKIT.LFG_REWARDS, "Master") end
end

function Milestones:Show(t)
    local sys = system(t.kind == "find" and "find" or "achievement")
    if sys then
        sys:AddAlert(t)
    else
        simple = simple or buildSimple()
        if #queue >= 10 then table.remove(queue, 1) end
        queue[#queue + 1] = t
        nextSimple()
    end
    if self.db.sound then self:Sound(t) end
end

function Milestones:ShowWhenLoaded(t)
    if type(Item) == "table" and Item.CreateFromItemLink then
        local ok, item = pcall(Item.CreateFromItemLink, Item, t.link)
        if ok and item and not item:IsItemEmpty() and not item:IsItemDataCached() then
            item:ContinueOnItemLoad(function() if self.enabled then self:Show(t) end end)
            return
        end
    end
    self:Show(t)
end

function Milestones:Once(id)
    local now = GetTime()
    for k, at in pairs(self.recent) do
        if now - at > REPEAT_WINDOW then self.recent[k] = nil end
    end
    if self.recent[id] then return false end
    self.recent[id] = now
    return true
end

local function crossed(set, old, new)
    local hit
    for _, level in ipairs(set) do
        if old < level and new >= level then hit = level end
    end
    return hit
end

local function levelToast(key, classFile, level)
    return { kind = "level", key = key, classFile = classFile, level = level, points = level,
        title = L["%s reached level %d"]:format(TG.ShortName(key), level), icon = icon("Achievement_Level_" .. level, "Spell_Holy_Heroism") }
end

local function joinToast(entry)
    return { kind = "join", key = entry.key, classFile = entry.classFile, level = entry.level,
        title = L["%s joined the guild"]:format(TG.ShortName(entry.key)), icon = icon("Achievement_GuildPerk_EverybodysFriend", "INV_Misc_GroupNeedMore") }
end

local function findToast(key, classFile, link, quality)
    return { kind = "find", key = key, classFile = classFile, link = link, quality = quality, label = L["%s found"]:format(TG.ShortName(key)) }
end

function Milestones:OnLevel(entry, old)
    local set = LEVEL_SETS[self.db.levels]
    if not set or TG.IsMe(entry.key) then return end
    local level = crossed(set, tonumber(old) or 0, tonumber(entry.level) or 0)
    if not level or not self:Once("level:" .. entry.key .. ":" .. level) then return end
    self:Show(levelToast(entry.key, entry.classFile, level))
end

function Milestones:OnJoined(entry)
    if not self.db.joins or TG.IsMe(entry.key) then return end
    local now = GetTime()
    for i = #joinBurst, 1, -1 do
        if now - joinBurst[i] > 60 then table.remove(joinBurst, i) end
    end
    joinBurst[#joinBurst + 1] = now
    if #joinBurst > JOIN_BURST or not self:Once("join:" .. entry.key) then return end
    self:Show(joinToast(entry))
end

function Milestones:OnLog(item)
    if item.kind ~= "found" or (self.db.finds or 0) == 0 then return end
    if type(item.name) ~= "string" or type(item.link) ~= "string" or TG.IsMe(item.name) then return end
    local quality = tonumber(item.quality) or 0
    if quality < self.db.finds or not self:Once("find:" .. item.name .. ":" .. item.link) then return end
    local entry = TG.Roster:Get(item.name)
    self:ShowWhenLoaded(findToast(item.name, entry and entry.classFile, item.link, quality))
end

function Milestones:OnSimulate(kind, entry, value)
    if type(entry) ~= "table" or not entry.key then return end
    if kind == "level" then
        self:Show(levelToast(entry.key, entry.classFile, tonumber(value) or tonumber(entry.level) or 60))
    elseif kind == "join" then
        self:Show(joinToast(entry))
    elseif kind == "find" then
        local link = type(value) == "string" and value or SAMPLE_ITEM
        self:ShowWhenLoaded(findToast(entry.key, entry.classFile, link, TG.LinkQuality(link, 4)))
    end
end

function Milestones:OnEnable()
    self.recent = {}
    self:On("MEMBER_LEVEL", "OnLevel")
    self:On("MEMBER_JOINED", "OnJoined")
    self:On("LOG_ADDED", "OnLog")
    self:On("SIMULATE", "OnSimulate")
end
