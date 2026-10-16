local _, TG = ...
local L = TG.L

-- Demo mode fills every module with made up data so the addon can be shown
-- without a guild. Everything lives in a separate guild record and is thrown
-- away when the demo ends. No network traffic leaves the client meanwhile.

local Demo = { active = false }
TG.Demo = Demo

local GUILD_KEY = "Demo@Demo"
local DAY = 86400

local FIRST = { "Anna", "Bodo", "Celine", "Dorin", "Elara", "Falk", "Greta", "Hagen", "Ilse", "Jorik", "Kaja", "Lennart", "Mira", "Nils", "Ottilie", "Piet", "Quirin", "Ragna", "Sven", "Thea", "Ulf", "Vera", "Wim", "Xenia", "Yorick", "Zora", "Aron", "Brida", "Corvin", "Dana", "Eyvind", "Freya", "Gorm", "Helka", "Ivo", "Juna", "Kolja", "Liv" }
local LAST = { "Berg", "Stein", "Nachtwind", "Eisenhand", "Morgenrot", "Sturmklinge", "Rabenfeld", "Silberhain", "Dornbusch", "Goldbach", "Wolkenstein", "Feuerbart", "Mondlicht", "Hartmann", "Winterkalt", "Aschenbrand", "Lindenholz", "Grauwald", "Tiefenbach", "Sonnentau", "Frostwacht", "Kupferberg", "Nebelgrund", "Eichenschild", "Sturmfels", "Lichtbringer", "Schattenfels", "Steinhauer", "Rosenquarz", "Himmelsturm" }
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ROLE_FOR_CLASS = { WARRIOR = "T", PALADIN = "H", HUNTER = "D", ROGUE = "D", PRIEST = "H", SHAMAN = "H", MAGE = "D", WARLOCK = "D", DRUID = "T" }

local seed = 7
local function rnd(n)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return (seed % n) + 1
end
local function pick(t) return t[rnd(#t)] end
local function chance(percent) return rnd(100) <= percent end

local members = {}
local names = {}
local ranks = {}
local ticker
local tickCount = 0

local function now() return TG.Now() end

local function myDemoName()
    local first, second = nil, nil
    if UnitFullName then
        local a, b = UnitFullName("player")
        if TG.usable(a) then first = a end
        if TG.usable(b) and b ~= "" and b ~= GetNormalizedRealmName() then second = b end
    end
    first = first or TG.plain(UnitName("player"), "Hero")
    local known = TG.MyName()
    if known and known:find(" ", 1, true) then return known end
    return first .. " " .. (second or "Sturmklinge")
end

local function zones()
    local out = {}
    local mapID = C_Map.GetBestMapForUnit("player")
    if TG.usable(mapID) and mapID then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name then out[#out + 1] = info.name end
        local parent = info and info.parentMapID
        if parent then
            for _, child in ipairs(C_Map.GetMapChildrenInfo(parent) or {}) do
                if child.name and child.mapType == Enum.UIMapType.Zone and #out < 8 then out[#out + 1] = child.name end
            end
        end
    end
    if #out == 0 then out = { L["Guild hall"], L["The harbor"], L["Old mines"], L["Frostpeak"] } end
    return out, mapID
end

local function buildRoster()
    members, names = {}, {}
    local zoneList, mapID = zones()
    local me = myDemoName()
    local myClass = TG.plain(select(2, UnitClass("player")), "WARRIOR")
    ranks = { L["Guild Master"], L["Officer"], L["Veteran"], L["Member"], L["Initiate"] }
    local function add(key, classFile, rankIndex, level, online, extra)
        local e = {
            key = key, fullName = key, guid = extra and extra.guid or ("Player-DEMO-" .. #members + 1),
            rank = ranks[rankIndex + 1], rankIndex = rankIndex, level = level, classFile = classFile,
            zone = online and pick(zoneList) or "", note = extra and extra.note or "", officerNote = "",
            online = online, status = 0, isMobile = false,
            lastSeen = online and now() or now() - rnd(40) * DAY,
        }
        members[#members + 1] = e
        names[key] = e
        return e
    end
    add(me, myClass, 0, TG.plain(UnitLevel("player"), 60), true, { guid = TG.MyGUID() or "Player-DEMO-ME" })
    local used = { [me] = true }
    local count = 0
    while count < 38 do
        local key = pick(FIRST) .. " " .. pick(LAST)
        if not used[key] then
            used[key] = true
            count = count + 1
            local rankIndex = count <= 3 and 1 or count <= 10 and 2 or count <= 32 and 3 or 4
            local level = count <= 24 and (50 + rnd(10)) or (10 + rnd(45))
            local online = count % 5 ~= 0 and count <= 24 or chance(20)
            add(key, pick(CLASSES), rankIndex, level, online)
        end
    end
    members[5].note = L["Alt of %s"]:format(TG.FirstName(members[3].key))
    members[9].note = L["Alt of %s"]:format(TG.FirstName(members[2].key))
    members[12].note = L["Tank, raids on Wednesday"]
    members[15].note = L["Bank character"]
    table.sort(members, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        return a.key < b.key
    end)
    return me, mapID
end

local function seedStore(me, mapID)
    local Store = TG.Store
    local t = now()
    local online = {}
    for _, e in ipairs(members) do if e.online then online[#online + 1] = e end end
    local function someone() return pick(members).key end
    local function someoneOnline() return pick(online).key end

    -- roles and alts
    for i, e in ipairs(members) do
        if i % 3 ~= 0 then Store:Seed("role", e.key, ROLE_FOR_CLASS[e.classFile] or "D", e.key, t - rnd(30) * DAY) end
    end
    Store:Seed("alt", members[5].key, members[3].key, members[3].key, t - 20 * DAY)
    Store:Seed("alt", members[9].key, members[2].key, members[2].key, t - 12 * DAY)
    Store:Seed("alt", members[15].key, me, me, t - 40 * DAY)

    -- history
    for _, e in ipairs(members) do
        local first = t - (30 + rnd(400)) * DAY
        local record = { f = first, r = { { t = first, i = 4 } } }
        if e.rankIndex < 4 then record.r[#record.r + 1] = { t = first + rnd(20) * DAY, i = e.rankIndex } end
        Store:Seed("hist", e.key, record, me, first)
    end
    for i = 1, 3 do
        local key = pick(FIRST) .. " " .. pick(LAST)
        Store:Seed("gone", key, { t = t - rnd(60) * DAY, l = 20 + rnd(40), r = ranks[4], c = pick(CLASSES) }, me, t - i * DAY)
    end

    -- deaths and pins on the current map
    if mapID then
        local zoneList = zones()
        for i = 1, 6 do
            local who = someone()
            local when = t - rnd(7 * DAY)
            Store:Seed("death", who .. "#" .. when, { m = mapID, x = 0.2 + rnd(60) / 100, y = 0.2 + rnd(60) / 100, t = when, z = pick(zoneList), l = 20 + rnd(40) }, who, when)
        end
        Store:Seed("pin", me .. "#" .. (t - DAY), { m = mapID, x = 0.42, y = 0.58, l = L["Herb spot"], e = 0 }, me, t - DAY)
        Store:Seed("pin", members[2].key .. "#" .. (t - 2 * DAY), { m = mapID, x = 0.61, y = 0.37, l = L["Meeting point"], e = 0 }, members[2].key, t - 2 * DAY)
    end

    -- raid teams
    local teamA = "tdemo1"
    local teamMembers = {}
    for i = 1, math.min(32, #members) do teamMembers[#teamMembers + 1] = members[i].key end
    local groups = {}
    for i, key in ipairs(teamMembers) do if i <= 25 then groups[key] = math.floor((i - 1) / 5) + 1 end end
    Store:Seed("team", teamA, { n = L["Raid team Alpha"], s = 40, m = teamMembers, g = groups, d = { { w = 4, h = 20, m = 0 }, { w = 1, h = 19, m = 30 } } }, me, t - 60 * DAY)
    local squad = {}
    for i = 2, 6 do squad[#squad + 1] = members[i].key end
    Store:Seed("team", "tdemo2", { n = L["Dungeon squad"], s = 10, m = squad, g = {}, d = { { w = 6, h = 21, m = 0 } } }, members[2].key, t - 20 * DAY)

    -- attendance for the last six raid nights
    for week = 1, 6 do
        local when = t - week * 7 * DAY
        local list = {}
        for i = 1, #teamMembers do
            if chance(75) then list[#list + 1] = teamMembers[i] end
        end
        Store:Seed("att", date("%Y-%m-%d", when) .. "#" .. me, { m = list, z = L["Molten Depths"] }, me, when)
    end

    -- loot history
    local items = {
        { "Blade of the Silver Dawn", 4 }, { "Mantle of Whispering Ash", 4 }, { "Signet of the Deep", 3 },
        { "Boots of Quiet Steps", 3 }, { "Staff of Burning Resolve", 4 }, { "Girdle of the Mountain", 3 },
        { "Cloak of Frozen Tears", 3 }, { "Helm of the Iron Vanguard", 4 }, { "Ring of Still Water", 3 },
        { "Band of Ember Light", 4 }, { "Gloves of the Night Watch", 3 }, { "Pendant of the Lost Tide", 3 },
    }
    local function link(i)
        local name, quality = items[i][1], items[i][2]
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex or "|cffa335ee"
        return ("%s|Hitem:%d::::::::60:::::|h[%s]|h|r"):format(color, 70000 + i, name), quality
    end
    for i = 1, #items do
        local when = t - rnd(42 * DAY)
        local winner = someone()
        local itemLink = link(i)
        Store:Seed("loot", when .. "#" .. (70000 + i) .. "#" .. winner, { t = when, i = itemLink, w = winner, r = rnd(2), b = me, z = L["Molten Depths"] }, me, when)
    end

    -- board
    local posts = {
        { L["Raid night rules"], L["Be online 15 minutes early, bring food and flasks. Loot is handled through TheGuild loot sessions. Soft reserves are posted on Tuesday."], me, 9 * DAY, true },
        { L["Guild meeting on Sunday"], L["We talk about the second raid team and the new recruits. Everyone is welcome."], members[2].key, 2 * DAY, false },
        { L["Looking for enchanting materials"], L["If you have spare dust or shards, send them to the bank character. Thanks!"], members[6].key, DAY, false },
        { L["Screenshots from last night"], L["The dragon went down on the third try. Pictures are in the Discord."], members[4].key, 5 * 3600, false },
    }
    for _, p in ipairs(posts) do
        local when = t - p[4]
        Store:Seed("post", p[3] .. "#" .. when, { t = p[1], b = p[2], ts = when, p = p[5] or nil }, p[3], when)
    end
    local poll1 = "pdemo1"
    Store:Seed("poll", poll1, { q = L["Which raid day suits you best?"], o = { L["Wednesday"], L["Thursday"], L["Sunday"] }, ts = t - 3 * DAY }, me, t - 3 * DAY)
    for i = 1, 14 do
        local who = members[i + 1].key
        Store:Seed("vote", who .. "#" .. poll1, (i % 3) + 1, who, t - rnd(2 * DAY))
    end
    local poll2 = "pdemo2"
    Store:Seed("poll", poll2, { q = L["Guild tabard color?"], o = { L["Silver and blue"], L["Gold and black"] }, ts = t - 10 * DAY, c = true }, members[2].key, t - 10 * DAY)
    for i = 1, 9 do
        local who = members[i + 3].key
        Store:Seed("vote", who .. "#" .. poll2, i <= 6 and 1 or 2, who, t - 9 * DAY)
    end
    local ev1 = date("*t", t + 2 * DAY)
    local evKey = me .. "#" .. (t - DAY)
    Store:Seed("event", evKey, { t = L["Dungeon evening"], b = L["Two groups, we meet at the guild hall."], y = ev1.year, m = ev1.month, d = ev1.day, h = 20, mi = 0, ts = t - DAY }, me, t - DAY)
    for i = 1, 8 do
        local who = members[i + 1].key
        Store:Seed("signup", who .. "#" .. evKey, i <= 5 and 1 or i <= 7 and 2 or 3, who, t - rnd(DAY))
    end
    local ev2 = date("*t", t + 6 * DAY)
    local evKey2 = members[3].key .. "#" .. (t - 2 * DAY)
    Store:Seed("event", evKey2, { t = L["Fishing contest"], b = L["Bring your rod, prizes for the biggest catch."], y = ev2.year, m = ev2.month, d = ev2.day, h = 18, mi = 30, ts = t - 2 * DAY }, members[3].key, t - 2 * DAY)
    local b1 = members[2].key .. "#" .. (t - 2 * DAY)
    Store:Seed("bounty", b1, { t = L["Twenty stacks of linen"], r = L["5 gold"], b = L["Deliver to the bank character."], ts = t - 2 * DAY }, members[2].key, t - 2 * DAY)
    Store:Seed("claim", members[7].key .. "#" .. b1, t - DAY, members[7].key, t - DAY)
    Store:Seed("claim", members[8].key .. "#" .. b1, t - 3600, members[8].key, t - 3600)
    local b2 = me .. "#" .. (t - 8 * DAY)
    Store:Seed("bounty", b2, { t = L["Escort to the harbor"], r = L["Rare recipe"], b = "", ts = t - 8 * DAY, d = true, w = members[4].key, dt = t - 6 * DAY }, me, t - 6 * DAY)

    -- candidates
    local statuses = { 1, 2, 3, 5 }
    for i = 1, 4 do
        local key = pick(FIRST) .. " " .. pick(LAST)
        Store:Seed("cand", key, { n = pick({ L["Met in a dungeon, solid healer"], L["Friend of %s"]:format(TG.FirstName(members[3].key)), L["Asked in the city"], L["Former raider, returning"] }), s = statuses[i], t = t - i * DAY, by = me }, me, t - i * DAY)
    end

    -- voice groups
    Store:Seed("vgroup", "gdemo1", { n = L["Raid team Alpha"], o = me, ts = t - 3600 }, me, t - 3600)
    Store:Seed("vgroup", "gdemo2", { n = L["Fishing"], o = members[3].key, ts = t - 1800 }, members[3].key, t - 1800)
    for i = 2, 4 do Store:Seed("vmem", members[i].key, "gdemo1", members[i].key, t - 3000) end
    for i = 5, 6 do Store:Seed("vmem", members[i].key, "gdemo2", members[i].key, t - 1500) end
    Store:Seed("stat", members[10].key, 0, members[10].key, t - 5 * DAY)
end

local function seedProfessions()
    local g = TG:GuildDB()
    if not g then return end
    g.profs = {}
    local profs = {
        { 171, L["Alchemy"], { L["Healing Potion"], L["Mana Potion"], L["Elixir of Agility"], L["Swiftness Potion"], L["Fire Protection Potion"] } },
        { 164, L["Blacksmithing"], { L["Iron Shield Spike"], L["Steel Breastplate"], L["Heavy Mithril Gauntlet"], L["Ornate Mithril Boots"] } },
        { 197, L["Tailoring"], { L["Linen Bag"], L["Silk Headband"], L["Mageweave Gloves"], L["Runecloth Robe"], L["Shadoweave Mask"] } },
        { 165, L["Leatherworking"], { L["Fine Leather Boots"], L["Hillman's Belt"], L["Nightscape Tunic"], L["Rugged Armor Kit"] } },
        { 333, L["Enchanting"], { L["Enchant Chest - Health"], L["Enchant Weapon - Fiery"], L["Enchant Cloak - Lesser Agility"], L["Enchant Boots - Minor Speed"] } },
        { 202, L["Engineering"], { L["Rough Dynamite"], L["Target Dummy"], L["Gnomish Net-o-Matic"], L["Thorium Grenade"] } },
        { 185, L["Cooking"], { L["Spiced Wolf Meat"], L["Dragonbreath Chili"], L["Goldthorn Tea"], L["Smoked Desert Dumplings"] } },
    }
    local t = now()
    for i = 1, 12 do
        local e = members[i]
        local char = { c = e.classFile, p = {} }
        local a = profs[(i % #profs) + 1]
        local b = profs[((i + 3) % #profs) + 1]
        for _, p in ipairs({ a, b }) do
            local recipes = {}
            for j, name in ipairs(p[3]) do
                if j <= 2 + rnd(#p[3] - 2) then recipes[p[1] * 100 + j] = name end
            end
            char.p[p[1]] = { n = p[2], s = 150 + rnd(150), m = 300, r = recipes, t = t - rnd(10 * DAY) }
        end
        g.profs[e.key] = char
    end
    local prof = TG:GetModule("Professions")
    if prof and prof.enabled then TG:Fire("GUILD_CHANGED") TG:Fire("PROFESSIONS_UPDATED") end
end

local function seedLog(me)
    local t = now()
    local kinds = { "online", "offline", "online", "level", "online", "offline", "death", "found", "post", "online", "joined", "cta", "rank", "offline", "online", "poll", "event", "bounty" }
    for i = 1, 60 do
        local kind = kinds[(i % #kinds) + 1]
        local who = pick(members).key
        local item = { kind = kind, name = who, t = t - i * (1800 + rnd(5400)) }
        if kind == "level" then item.level = 20 + rnd(40) end
        if kind == "rank" then item.rank = ranks[2 + rnd(3)] end
        if kind == "death" then item.zone = pick((zones())) end
        if kind == "cta" then item.zone = pick((zones())) end
        if kind == "found" then item.link = "|cff0070dd|Hitem:70020::::::::60:::::|h[" .. L["Ring of Still Water"] .. "]|h|r" item.bind = "P" item.zone = L["Molten Depths"] end
        if kind == "post" then item.title = L["Guild meeting on Sunday"] end
        if kind == "poll" then item.title = L["Which raid day suits you best?"] end
        if kind == "event" then item.title = L["Dungeon evening"] end
        if kind == "bounty" then item.title = L["Twenty stacks of linen"] end
        TG.Log:Seed(item)
    end
    TG.Log:Seed({ kind = "raid", name = me, t = t - 7 * DAY + 3 * 3600, count = 28 })
end

local function seedPeers(mapID)
    TG.Comm:ResetPeers()
    local map = TG:GetModule("Map")
    local mx, my = 0.5, 0.5
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            if TG.usable(x) and TG.usable(y) and x > 0 then mx, my = x, y end
        end
    end
    Demo.mapPeers = {}
    local n = 0
    for _, e in ipairs(members) do
        if e.online and not TG.IsMe(e.key) and n < 14 then
            n = n + 1
            TG.Comm:SeedPeer(e.key, n == 7 and "0.2.0" or TG.version, e.guid)
            if map and map.enabled and mapID then
                local peer = { mapID = mapID, x = TG.Clamp(mx + (rnd(200) - 100) / 1000, 0.02, 0.98), y = TG.Clamp(my + (rnd(200) - 100) / 1000, 0.02, 0.98), hp = 55 + rnd(45), flags = "", ts = GetTime(), hasPos = true }
                if n == 11 then peer.flags = "i" peer.hasPos = false end
                map:SeedPeer(e.key, peer)
                Demo.mapPeers[e.key] = peer
            end
        end
    end
end

local function seedVoice(me)
    local voice = TG:GetModule("Voice")
    if not voice or not voice.enabled then return end
    local channel = { channelID = 7, name = L["Guild"], isActive = true, members = {}, keys = {} }
    channel.members[1] = { memberID = 1, isActive = true, isSpeaking = false, energy = 0 }
    channel.keys[1] = me
    for i = 2, 7 do
        channel.members[i] = { memberID = i, isActive = true, isSpeaking = false, energy = 0 }
        channel.keys[i] = members[i].key
    end
    voice:SetDemoChannel(channel)
end

local function tick()
    tickCount = tickCount + 1
    local map = TG:GetModule("Map")
    if map and map.enabled and Demo.mapPeers then
        for key, peer in pairs(Demo.mapPeers) do
            if peer.hasPos and chance(60) then
                peer.x = TG.Clamp(peer.x + (rnd(21) - 11) / 1000, 0.02, 0.98)
                peer.y = TG.Clamp(peer.y + (rnd(21) - 11) / 1000, 0.02, 0.98)
            end
            peer.ts = GetTime()
            map:SeedPeer(key, peer)
        end
    end
    local voice = TG:GetModule("Voice")
    if voice and voice.enabled and voice.SetSpeaking then
        voice:SetSpeaking(2 + (tickCount % 6), tickCount % 2 == 0)
    end
    if tickCount % 12 == 0 then
        local e = members[1 + rnd(#members - 1)]
        if not TG.IsMe(e.key) then
            e.online = not e.online
            e.lastSeen = now()
            TG.Log:Add(e.online and "online" or "offline", e.key)
            TG.Roster:SetDemo(members, Demo.guildName)
        end
    end
end

Demo.motd = L["Welcome to the Silver Dawn. Raids on Wednesday and Sunday, sign up in the calendar."]

function Demo:Start()
    if self.active then return end
    self.active = true
    TG.db.global.demo = true
    TG.Comm.muted = true
    seed = 7
    self.guildName = L["Order of the Silver Dawn"]
    TG.db.guilds[GUILD_KEY] = nil
    local me, mapID = buildRoster()
    TG.Roster:SetDemo(members, self.guildName)
    TG.LearnMyName(me)
    TG:Fire("GUILD_CHANGED")
    seedStore(me, mapID)
    seedProfessions()
    seedLog(me)
    seedPeers(mapID)
    seedVoice(me)
    tickCount = 0
    ticker = TG.Ticker(5, tick)
    TG:Fire("ROSTER_UPDATED")
    TG:Fire("MAP_PEERS")
    TG.Window:Refresh()
    TG:Print(L["Demo mode on. Everything you see now is made up. /tg demo off ends it."])
end

function Demo:Stop()
    if not self.active then return end
    self.active = false
    TG.db.global.demo = nil
    if ticker then ticker:Cancel() ticker = nil end
    local voice = TG:GetModule("Voice")
    if voice and voice.SetDemoChannel then voice:SetDemoChannel(nil) end
    local map = TG:GetModule("Map")
    if map then
        for key in pairs(self.mapPeers or {}) do map.peers[key] = nil end
        map:Changed()
    end
    self.mapPeers = nil
    TG.Comm:ResetPeers()
    TG.Comm.muted = false
    TG.db.guilds[GUILD_KEY] = nil
    TG.ForgetMyName()
    TG.Roster:ClearDemo()
    TG:Fire("GUILD_CHANGED")
    TG:Fire("ROSTER_UPDATED")
    TG.Window:Refresh()
    TG:Print(L["Demo mode off."])
end

TG:RegisterSlash("demo", function(rest)
    rest = tostring(rest or ""):lower()
    if rest == "off" or (rest == "" and Demo.active) then Demo:Stop() else Demo:Start() end
end, L["fill the addon with made up data for a presentation"])

TG:On("READY", function()
    if TG.db.global.demo then TG.After(3, function() Demo:Start() end) end
end)
