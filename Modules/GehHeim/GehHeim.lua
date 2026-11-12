local TG = TheGuild
local ns = TG.GH
if ns.off then return end
local L = ns.L
local Codec, Link = ns.Codec, ns.Link
local max = math.max

ns.ADDON_VERSION = { 1, 3, 0 }
ns.LEGACY = "GehHeim"
ns.HOME_GUILD = "Geh Heim"

function ns.InHomeGuild()
    return TG.plain(GetGuildInfo("player"), nil) == ns.HOME_GUILD
end

ns.MONEY_RUNGS_GOLD = { 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000 }
ns.COPPER_PER_GOLD = 10000
ns.SKILL_RIDING = 762
ns.PROFESSIONS = {
    [171] = L["Alchemy"], [164] = L["Blacksmithing"], [333] = L["Enchanting"], [202] = L["Engineering"],
    [182] = L["Herbalism"], [165] = L["Leatherworking"], [186] = L["Mining"], [393] = L["Skinning"],
    [197] = L["Tailoring"], [185] = L["Cooking"], [129] = L["First Aid"], [356] = L["Fishing"], [762] = L["Riding"],
}
ns.WEAPON_SKILLS = {
    [43] = L["Swords"], [55] = L["Two-Handed Swords"], [44] = L["Axes"], [172] = L["Two-Handed Axes"],
    [54] = L["Maces"], [160] = L["Two-Handed Maces"], [229] = L["Polearms"], [136] = L["Staves"],
    [173] = L["Daggers"], [473] = L["Fist Weapons"], [45] = L["Bows"], [46] = L["Guns"], [226] = L["Crossbows"],
    [176] = L["Thrown"], [228] = L["Wands"], [162] = L["Unarmed"], [95] = L["Defense"],
}
ns.ENV_TYPES = { falling = 1, drowning = 2, fatigue = 3, fire = 4, lava = 5, slime = 6 }
ns.ENCOUNTER_DEDUPE = 30
ns.FIGHT_LONG_S = 120
ns.FIGHT_RECORD_MIN = 500
ns.STAT_DISTANCE, ns.STAT_FISH, ns.STAT_HEARTH, ns.STAT_TOYS, ns.STAT_PETS = 1, 2, 3, 4, 5
ns.STAT_CRAFTS, ns.STAT_CONSUMABLES, ns.STAT_GUILD_REZ = 6, 7, 8
ns.STAT_JUMPS, ns.STAT_KILLS, ns.STAT_HONOR_KILLS, ns.STAT_BG_WINS, ns.STAT_KILLS_TYPE_BASE = 20, 21, 22, 23, 30
ns.BIG_RUNGS = { 10, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000 }
ns.CREATURE_TYPES = {
    ["wildtier"] = 1, ["beast"] = 1, ["drachkin"] = 2, ["dragonkin"] = 2, ["dämon"] = 3, ["demon"] = 3,
    ["elementar"] = 4, ["elemental"] = 4, ["riese"] = 5, ["giant"] = 5, ["untoter"] = 6, ["undead"] = 6,
    ["humanoid"] = 7, ["kleintier"] = 8, ["critter"] = 8, ["mechanisch"] = 9, ["mechanical"] = 9,
}
ns.KILL_WATCH = { [620] = true, [265797] = true, [448] = true }
ns.KILL_COMBAT_WINDOW_S = 10
ns.EMOTES = { SALUTE = 1, SPIT = 2, WAVE = 3, HUG = 4, DANCE = 5, BOW = 6, CHICKEN = 7, KISS = 8,
    CHEER = 9, ROAR = 10, RUDE = 11, THANK = 12, FLEX = 13, LAUGH = 14, CRY = 15, POINT = 16 }
ns.BG_FACTION = { Horde = 0, Alliance = 1 }
ns.RUN_GRACE_SECONDS = 600
ns.RUN_MAX_SECONDS = 21600
ns.LONG_LINK_CHARS = 3000
ns.SKILL_BY_NAME = {
    ["alchemy"] = 171, ["alchemie"] = 171, ["blacksmithing"] = 164, ["schmiedekunst"] = 164,
    ["enchanting"] = 333, ["verzauberkunst"] = 333, ["engineering"] = 202, ["ingenieurskunst"] = 202,
    ["herbalism"] = 182, ["kräuterkunde"] = 182, ["leatherworking"] = 165, ["lederverarbeitung"] = 165,
    ["mining"] = 186, ["bergbau"] = 186, ["smelting"] = 186, ["verhüttung"] = 186,
    ["skinning"] = 393, ["kürschnerei"] = 393, ["tailoring"] = 197, ["schneiderei"] = 197,
    ["cooking"] = 185, ["kochkunst"] = 185, ["kochen"] = 185, ["first aid"] = 129, ["erste hilfe"] = 129,
    ["fishing"] = 356, ["angeln"] = 356, ["riding"] = 762, ["reiten"] = 762,
}
ns.DISTANCE_STEP_M = 5000
ns.FISH_RUNGS = { 10, 25, 50, 100, 250, 500, 1000, 2500 }
ns.STATISTIC_FISH = 1456
ns.ANNOUNCE_LEVELS = { [40] = true, [50] = true, [60] = true }
ns.PROFESSION_CAP = 300
ns.COUNTER_RUNGS = ns.FISH_RUNGS
ns.HEARTH_RUNGS = { 1, 10, 25, 50, 100, 250, 500 }
ns.COLLECTION_RUNGS = { 1, 5, 10, 25, 50, 100, 250 }
ns.MOMENT_BOSS_SCREENSHOT, ns.MOMENT_HEARTH_AFTER_DEATH = 1, 2
ns.MOMENT = { salute = 3, rest = 4, tram = 5, campfire = 6, catch = 7, craft = 8, use = 9, buff = 10, guild_rez = 11, guild_dungeon = 12, bind = 13, photo = 14,
    emote = 15, kill_watch = 16, loot_rare = 17, taxi = 18, gossip = 19 }
ns.MOMENT_WINDOW_S = 300
ns.ID_CANDIDATES = {
    leaders = { 4949, 3057, 10181, 10540 },
    rest = { 7353, 1232234, 1283391, 1229739, 1229741 }, campfire = { 818, 1290, 1229737, 1283400, 1291341, 1307237, 1307252 },
    campfireNames = { "lagerfeuer", "campfire" },
    tram = { 499 }, tramInstance = { 369 }, tramZone = { "tiefenbahn", "deeprun tram" },
    fish = { 6522 }, food = { 6657 }, recipe = { 8238 },
    transform = { 8219, 8220, 8221, 8222 },
    noggenfogger = { 16591, 16593, 16595 },
}
ns.TRAM_IRONFORGE = { [1455] = true, [87] = true }
ns.TRAM_STORMWIND = { [1453] = true, [84] = true }
ns.HEARTHSTONE_SPELLS = { [8690] = true }
ns.HEARTHSTONE_NAMES = { ["ruhestein"] = true, ["hearthstone"] = true }
ns.ARMOR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 15 }
ns.TABARD_SLOT = 19
ns.RIDING_SPELLS = { { 90265, 375 }, { 34091, 300 }, { 34090, 225 }, { 33391, 150 }, { 33388, 75 } }
ns.CITIES = {
    { key = "stormwind", name = "Sturmwind", map = 1453, parent = 1429, continent = 1415, areas = { 1519 } },
    { key = "ironforge", name = "Eisenschmiede", map = 1455, parent = 1426, continent = 1415, areas = { 1537, 809 } },
    { key = "darnassus", name = "Darnassus", map = 1457, parent = 1438, continent = 1414, areas = { 1657 } },
    { key = "orgrimmar", name = "Orgrimmar", map = 1454, parent = 1411, continent = 1414, areas = { 1637 } },
    { key = "thunder_bluff", name = "Donnerfels", map = 1456, parent = 1412, continent = 1414, areas = { 1638 } },
    { key = "undercity", name = "Unterstadt", map = 1458, parent = 1420, continent = 1415, areas = { 1497, 153 } },
}
ns.CITY_BY_MAP = {}
for _, city in ipairs(ns.CITIES) do ns.CITY_BY_MAP[city.map] = city end
ns.FACTION = { Alliance = 1, Horde = 2 }

local GH = TG:NewModule("GehHeim", {
    title = L["Achievements"],
    desc = L["Records milestones and guild achievements. Members of Geh Heim also get the report link for the guild website."],
    order = 60,
    defaults = { notify = "both", sound = "achievement", style = "guild", announce = false, notices = true, runChat = false },
    charDefaults = {},
    settings = {
        { key = "notify", type = "select", name = L["Achievement notification"], tooltip = L["How a newly earned guild achievement is announced to you."],
          options = { { "off", L["Off"] }, { "chat", L["Chat"] }, { "screen", L["Toast"] }, { "both", L["Chat and toast"] } }, default = "both" },
        { key = "sound", type = "select", name = L["Achievement sound"], tooltip = L["Sound for the achievement toast. Test it with /tg gh test."],
          options = { { "off", L["Off"] }, { "achievement", L["Achievement"] }, { "lfg", L["Dungeon reward"] }, { "quest", L["Quest complete"] }, { "file", L["Own file: Sounds\\achievement.ogg"] } }, default = "achievement" },
        { key = "style", type = "select", name = L["Toast style"], tooltip = L["The classic achievement toast or the guild achievement toast with the guild tabard."],
          options = { { "guild", L["Guild achievement"] }, { "achievement", L["Achievement"] } }, default = "guild" },
        { key = "notices", type = "boolean", name = L["Small notices for recorded milestones"], tooltip = L["A short line at the top of the screen when a level, gold, skill or reputation milestone or a boss kill is recorded."], default = true },
        { key = "announce", type = "boolean", name = L["Announce level 40, 50, 60 and mastered professions in guild chat"], tooltip = L["One guild chat line per milestone, never for what a character already had. No effect on the report link."], default = false },
        { key = "runChat", type = "boolean", name = L["Show recorded dungeon runs in my chat"], tooltip = L["One line in your own chat window when a dungeon or raid run with the guild is recorded. Nobody else sees it."], default = false },
    },
})
ns.Mod = GH

local listeners = {}

local function now()
    return TG.Now()
end

local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end
ns.Copy = copy

function ns.PlayerName()
    local name = TG.MyName()
    if name and name ~= "" then return name end
    return TG.plain(GetUnitName("player", false), "")
end

local function validRecord(c, guid)
    return type(c) == "table" and c.guid == guid and Link.RawKey(c.key) ~= nil
        and type(c.log_id) == "number" and c.log_id >= 1 and type(c.seq) == "number" and type(c.events) == "table"
end

local function repair(rec)
    local n = 0
    while rec.events[n + 1] ~= nil do n = n + 1 end
    rec.seq = n
    local lastTs = n > 0 and (rec.events[n][1] or 0) or 0
    rec.last_ts = max(rec.last_ts or 0, lastTs)
    rec.state = rec.state or {}
    rec.known = rec.known or {}
    local s = Link.EnsureState(rec)
    if s.sent_upto > rec.seq then s.sent_upto = rec.seq end
    if s.acked_upto > rec.seq then s.acked_upto = rec.seq end
    if s.prev_sent_upto > s.sent_upto then s.prev_sent_upto = s.sent_upto end
end

local function newRecord(guid, name, reason)
    local t = now()
    local key = TG.Crypto.Entropy({ "gehheim-key", guid, name, t, GetTime() })
    local idHash = TG.Crypto.Entropy({ "gehheim-logid", guid, key, t })
    local b1, b2, b3, b4 = idHash:byte(1, 4)
    local logId = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    if logId == 0 then logId = 1 end
    local rec = {
        schema = 1, guid = guid, name = name, created_at = t, updated_at = t,
        key = Codec.hex(key), key_id = Codec.hex(Codec.keyId(key)), log_id = logId,
        seq = 0, last_ts = 0, events = {}, state = {}, known = {}, needs_snapshot = reason,
    }
    Link.EnsureState(rec)
    return rec
end

local function pickLegacy(guid)
    local acc = _G.GehHeimAccountDB
    local c = _G.GehHeimCharDB
    local a = type(acc) == "table" and type(acc.characters) == "table" and acc.characters[guid] or nil
    c = validRecord(c, guid) and c or nil
    a = validRecord(a, guid) and a or nil
    if c and a then
        if c == a then return c end
        if c.log_id == a.log_id then return (a.seq or 0) > (c.seq or 0) and a or c end
        return (a.updated_at or 0) > (c.updated_at or 0) and a or c
    end
    return c or a
end

function GH:Import(guid)
    local src = pickLegacy(guid)
    if not src then return nil end
    local rec = copy(src)
    rec.known = {}
    local acc = _G.GehHeimAccountDB
    if type(acc) == "table" then
        local known = type(acc.ux) == "table" and type(acc.ux.known) == "table" and acc.ux.known[guid]
        if type(known) == "table" then
            for code, ts in pairs(known) do rec.known[code] = ts end
        end
        if acc.encounter_events_seen then rec.encounter_events_seen = true end
    end
    if rec.rotation then
        rec.rotation = nil
        Link.EnsureState(rec).confirmed = false
    end
    rec.old_keys = nil
    rec.imported_at = now()
    rec.imported_seq = rec.seq
    repair(rec)
    self.cdb.rec = rec
    return rec
end

function ns.OnAppend(fn)
    listeners[#listeners + 1] = fn
end

local function push(rec, ts, evt)
    ts = max(ts or 0, rec.last_ts or 0)
    local e = { ts }
    for i = 1, #evt do e[i + 1] = evt[i] end
    local ok, err = pcall(Codec.encodeFields, e)
    if not ok then
        TG:Debug("GehHeim: event dropped, %s", tostring(err))
        return nil
    end
    rec.seq = rec.seq + 1
    rec.events[rec.seq] = e
    rec.last_ts = ts
    rec.updated_at = ts
    for _, fn in ipairs(listeners) do TG.SafeCall(fn, rec.seq, e) end
    TG:Fire("GEHHEIM_EVENT", rec.seq, e)
    return rec.seq
end

function GH:SyncLegacy()
    local rec = self.rec
    if not rec or not self.passive then return 0 end
    local src = pickLegacy(rec.guid)
    if not src or src.log_id ~= rec.log_id or (src.seq or 0) <= rec.seq then return 0 end
    local added = 0
    for seq = rec.seq + 1, src.seq do
        local e = src.events[seq]
        if type(e) ~= "table" then break end
        local evt = {}
        for i = 2, #e do evt[i - 1] = copy(e[i]) end
        if push(rec, e[1], evt) then added = added + 1 end
    end
    local s, ls = Link.EnsureState(rec), src.link
    if type(ls) == "table" then
        s.acked_upto = max(s.acked_upto, math.min(ls.acked_upto or 0, rec.seq))
        s.sent_upto = max(s.sent_upto, math.min(ls.sent_upto or 0, rec.seq))
        if ls.confirmed then s.confirmed = true end
    end
    return added
end

local function legacyTick(token)
    if GH.legacyToken ~= token or not GH.passive or not GH.rec then return end
    GH:SyncLegacy()
    TG.After(10, function() legacyTick(token) end)
end

function ns.Append(evt, at)
    local rec = GH.rec
    if not rec or GH.passive then return nil end
    local ts = type(at) == "number" and at or now()
    if rec.pending_queue then
        rec.pending_queue[#rec.pending_queue + 1] = { ts, evt }
        return 0
    end
    return push(rec, ts, evt)
end

function ns.BeginQueue()
    local rec = GH.rec
    rec.pending_queue = rec.pending_queue or {}
    rec.pending_queue_start = rec.pending_queue_start or now()
end

function ns.FlushQueue(first)
    local rec = GH.rec
    local q = rec.pending_queue or {}
    local t0 = rec.pending_queue_start or now()
    rec.pending_queue = nil
    rec.pending_queue_start = nil
    for _, evt in ipairs(first or {}) do push(rec, t0, evt) end
    for _, item in ipairs(q) do push(rec, item[1], item[2]) end
end

function ns.State(name)
    local rec = GH.rec
    rec.state[name] = rec.state[name] or {}
    return rec.state[name]
end

function ns.Rec()
    return GH.rec
end

local bootTries = 0

function ns.LegacyInstalled()
    if not ns.sealed then return false end
    local exists = C_AddOns and C_AddOns.DoesAddOnExist
    if exists then return TG.plain(exists(ns.LEGACY), false) and true or false end
    local count = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
    local info = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if not count or not info then return false end
    for i = 1, TG.plain(count(), 0) do
        if TG.plain(info(i), "") == ns.LEGACY then return true end
    end
    return false
end

function GH:Boot()
    if self.rec or not self.enabled then return end
    if not ns.LegacyInstalled() then
        self.locked = true
        TG:Fire("GEHHEIM_READY")
        return
    end
    local guid = TG.plain(UnitGUID("player"))
    if not guid or guid == "" then
        bootTries = bootTries + 1
        if bootTries < 20 then TG.After(1, function() self:Boot() end) end
        return
    end
    local name = ns.PlayerName()
    local rec = self.cdb.rec
    local source = "own"
    if not validRecord(rec, guid) then
        rec = self:Import(guid)
        source = rec and "import" or nil
    end
    if not rec then
        local hadSomething = type(self.cdb.rec) == "table" and next(self.cdb.rec) ~= nil
        rec = newRecord(guid, name, hadSomething and 2 or 1)
        self.cdb.rec = rec
        source = "new"
    end
    repair(rec)
    if name ~= "" then rec.name = name end
    self.rec = rec
    self.source = source
    self.passive = C_AddOns.IsAddOnLoaded(ns.LEGACY) and true or false
    if source == "import" then
        TG:Print(L["Geh Heim: %d recorded events taken over from the old addon."], rec.seq)
    end
    if self.passive then
        TG:Print(L["Geh Heim: the old GehHeim addon is still loaded. Recording stays off until it is disabled in the AddOn list."])
        ns.Rules.Init(rec)
        self.ready = true
        self.legacyToken = (self.legacyToken or 0) + 1
        legacyTick(self.legacyToken)
        TG:Fire("GEHHEIM_READY")
        return
    end
    ns.Facts.Start(rec)
    if rec.needs_snapshot then
        ns.Snapshot.Begin(rec.needs_snapshot)
    else
        self.ready = true
        ns.Facts.CheckAll()
    end
    ns.Rules.Init(rec)
    TG:Fire("GEHHEIM_READY")
end

function ns.OnBaselineReady()
    GH.ready = true
    ns.Facts.CheckAll()
    TG:Fire("GEHHEIM_READY")
end

function GH:OnEnable()
    self.rec = nil
    self.ready = false
    self.passive = false
    self.locked = false
    bootTries = 0
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if self.passive then self:SyncLegacy() return end
        if self.rec and self.ready then ns.Facts.CheckAll() end
    end)
    if IsLoggedIn() then
        self:Boot()
    else
        self:RegisterEvent("PLAYER_LOGIN", function() self:Boot() end)
    end
end

function GH:OnDisable()
    self.rec = nil
    self.ready = false
    self.legacyToken = (self.legacyToken or 0) + 1
end

function ns.Header()
    local rec = GH.rec
    local _, _, _, toc = GetBuildInfo()
    local _, _, classId = UnitClass("player")
    local _, _, raceId = UnitRace("player")
    local region = tonumber(TG.plain(GetCurrentRegion(), 0)) or 0
    if region < 0 or region > 5 then region = 0 end
    local realm = TG.plain(GetNormalizedRealmName(), nil)
    if not realm or realm == "" then realm = TG.plain(GetRealmName(), "") end
    return {
        addon = ns.ADDON_VERSION,
        build = tonumber(TG.plain(toc, 0)) or 0,
        project = tonumber(TG.plain(WOW_PROJECT_ID, 0)) or 0,
        region = region,
        realm = realm,
        ruleset = ns.Ruleset(),
        name = ns.PlayerName(),
        guid = rec.guid,
        classId = math.min(255, tonumber(TG.plain(classId, 0)) or 0),
        raceId = math.min(255, tonumber(TG.plain(raceId, 0)) or 0),
        faction = ns.FACTION[TG.plain(UnitFactionGroup("player"), "")] or 0,
        guild = Codec.cleanGuild(TG.plain(GetGuildInfo("player"), "")),
        logId = rec.log_id,
    }
end

function ns.Ruleset()
    local rules = C_GameRules
    local enum = Enum and Enum.GameRule
    if type(rules) ~= "table" or type(enum) ~= "table" or type(rules.IsGameRuleActive) ~= "function" then return "" end
    local function active(name)
        if enum[name] == nil then return nil end
        local ok, v = pcall(rules.IsGameRuleActive, enum[name])
        if not ok or not TG.usable(v) then return nil end
        return v and true or false
    end
    local hc, pvp, rp = active("HardcoreRuleset"), active("PvPRuleset"), active("RPRuleset")
    local base = ""
    if hc then
        base = "Hardcore"
    elseif rp and pvp then
        base = "RP-PvP"
    elseif rp then
        base = "RP"
    elseif pvp then
        base = "PvP"
    elseif pvp ~= nil or rp ~= nil then
        base = "PvE"
    end
    if base ~= "" and C_PlayerInfo and type(C_PlayerInfo.IsSelfFoundActive) == "function" then
        local ok, sf = pcall(C_PlayerInfo.IsSelfFoundActive)
        if ok and TG.usable(sf) and sf then base = base .. "-SF" end
    end
    return base
end

function GH:BuildLinks(opts)
    local rec = self.rec
    if not rec then return nil, "not_ready" end
    opts = opts or {}
    opts.now = now()
    return Link.Build(rec, ns.Header(), opts)
end

function GH:StatusText()
    local rec = self.rec
    if not rec then return L["Not ready yet."] end
    return L["%d events, %d open, %d new since the last link."]:format(rec.seq or 0, Link.UnconfirmedCount(rec), Link.NewEventCount(rec))
end

local function hookMinimap()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    local obj = ldb and ldb:GetDataObjectByName("TheGuild")
    if not obj or obj.gehheim then return end
    obj.gehheim = true
    local click, tooltip = obj.OnClick, obj.OnTooltipShow
    obj.OnClick = function(owner, button)
        if GH.enabled and button == "LeftButton" and IsShiftKeyDown() and ns.InHomeGuild() then
            ns.Report()
            return
        end
        if click then click(owner, button) end
    end
    obj.OnTooltipShow = function(tt)
        if tooltip then tooltip(tt) end
        if GH.enabled and ns.InHomeGuild() then tt:AddLine(L["Shift + left click: report link"], 0.6, 0.6, 0.6) end
    end
end

function GH:OnInitialize()
    hookMinimap()
    TG:RegisterSlash("gh", function(rest)
        local cmd, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
        cmd = cmd:lower()
        if cmd == "" then
            TG.Window:ShowTab("gehheim")
        elseif cmd == "link" or cmd == "melden" then
            ns.Report()
        elseif cmd == "status" then
            TG:Print(self:StatusText())
        elseif cmd == "test" then
            ns.Rules.Test()
        elseif cmd == "code" then
            ns.ApplyCode(arg)
        elseif cmd == "ids" then
            ns.PrintIds()
        elseif cmd == "pruefen" or cmd == "prüfen" or cmd == "check" then
            ns.ShowIdCheck()
        else
            TG:Print(L["/tg gh opens the tab, link builds the report link, status, test shows a sample toast, code <code> applies the website code, ids prints the IDs around you, pruefen checks the candidate IDs."])
        end
    end, L["Geh Heim achievements, log and report link"])
end
