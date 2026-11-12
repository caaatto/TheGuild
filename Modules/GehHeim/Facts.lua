local TG = TheGuild
local ns = TG.GH
if ns.off then return end
local L = ns.L
local Codec = ns.Codec
local T = Codec.T
local usable, plain = TG.usable, TG.plain
local floor, max, min = math.floor, math.max, math.min

local Facts = {}
ns.Facts = Facts

local function pass(ok, ...)
    if ok then return ... end
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return pass(pcall(fn, ...))
end
ns.Call = call

local function num(v, default)
    if not usable(v) then return default end
    v = tonumber(v)
    if not v or v ~= v or v < 0 or v == math.huge then return default end
    return floor(v)
end
ns.Num = num

local function str(v, default)
    if usable(v) and type(v) == "string" then return v end
    return default
end
ns.Str = str

local function u8(v)
    return max(0, min(255, v or 0))
end
ns.U8 = u8

local function yes(v)
    return usable(v) and v and true or false
end

local function api(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end
ns.Api = api

local function now()
    return TG.Now()
end

function ns.Level()
    return num(call(UnitLevel, "player"), 0)
end

function ns.Money()
    return num(call(GetMoney), 0)
end

function ns.IsDeadOrGhost()
    local v = call(UnitIsDeadOrGhost, "player")
    if not usable(v) then return true end
    return v and true or false
end

function ns.BestMap()
    local id = num(call(api("C_Map.GetBestMapForUnit"), "player"), nil)
    if id and id > 0 then return id end
    return nil
end

function ns.PlayerPosition()
    local map = ns.BestMap()
    local fn = api("C_Map.GetPlayerMapPosition")
    if not map or not fn then return nil end
    local pos = call(fn, map, "player")
    if type(pos) ~= "table" or not usable(pos) then return nil end
    local x, y
    if type(pos.GetXY) == "function" then x, y = call(pos.GetXY, pos) else x, y = pos.x, pos.y end
    if not usable(x) or not usable(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return map, x, y
end

local function rectOn(child, parent)
    local minX, maxX, minY, maxY = call(api("C_Map.GetMapRectOnMap"), child, parent)
    if not (usable(minX) and usable(maxX) and usable(minY) and usable(maxY)) then return nil end
    if type(minX) ~= "number" or type(maxX) ~= "number" or type(minY) ~= "number" or type(maxY) ~= "number" or maxX <= minX or maxY <= minY then return nil end
    return minX, maxX, minY, maxY
end

function ns.MapRect(childMap, parentMap, continentMap)
    local minX, maxX, minY, maxY = rectOn(childMap, parentMap)
    if minX then return minX, maxX, minY, maxY end
    if not continentMap then return nil end
    local cx1, cx2, cy1, cy2 = rectOn(childMap, continentMap)
    local zx1, zx2, zy1, zy2 = rectOn(parentMap, continentMap)
    if not (cx1 and zx1) then return nil end
    local w, h = zx2 - zx1, zy2 - zy1
    minX, maxX = (cx1 - zx1) / w, (cx2 - zx1) / w
    minY, maxY = (cy1 - zy1) / h, (cy2 - zy1) / h
    if maxX <= 0 or minX >= 1 or maxY <= 0 or minY >= 1 then return nil end
    return max(minX, 0), min(maxX, 1), max(minY, 0), min(maxY, 1)
end

function ns.ExploredAreasAt(mapId, x, y)
    local fn = api("C_MapExplorationInfo.GetExploredAreaIDsAtPosition")
    if not fn then return nil end
    local vec = type(CreateVector2D) == "function" and call(CreateVector2D, x, y) or { x = x, y = y }
    local ids = call(fn, mapId, vec)
    if type(ids) ~= "table" then return nil end
    local out = {}
    for _, id in ipairs(ids) do
        local v = num(id, nil)
        if v then out[#out + 1] = v end
    end
    return out
end

function ns.InstanceInfo()
    local _, instanceType, difficultyID, _, _, _, _, instanceID = call(GetInstanceInfo)
    return str(instanceType, ""), num(difficultyID, 0), num(instanceID, 0)
end

function ns.GroupSize()
    return u8(max(1, num(call(GetNumGroupMembers), 0)))
end

function ns.Weather()
    local fn = api("C_Weather.GetCurrentWeather")
    if not fn then return 0 end
    local info = call(fn)
    if type(info) ~= "table" or not usable(info) then return 0 end
    return u8(num(info.type, 0))
end

function ns.ArmorPieces()
    local n = 0
    for _, slot in ipairs(ns.ARMOR_SLOTS) do
        local id = num(call(GetInventoryItemID, "player", slot), nil)
        if id and id > 0 then n = n + 1 end
    end
    return n
end

function ns.TabardItem()
    return num(call(GetInventoryItemID, "player", ns.TABARD_SLOT), 0)
end

function ns.GuildMembersInGroup()
    if type(UnitIsInMyGuild) ~= "function" then return 0 end
    local prefix, count = "party", 4
    if yes(call(IsInRaid)) then prefix, count = "raid", 40 end
    local n = 0
    for i = 1, count do
        local unit = prefix .. i
        if yes(call(UnitExists, unit)) and yes(call(UnitIsInMyGuild, unit)) and not yes(call(UnitIsUnit, unit, "player")) then
            n = n + 1
        end
    end
    return u8(n)
end

local CLASSIFICATION = { elite = 1, rare = 2, rareelite = 3, worldboss = 4 }

function ns.Classification(unit)
    if yes(call(UnitIsBossMob, unit)) then return 4 end
    local lvl = call(UnitLevel, unit)
    if usable(lvl) and lvl == -1 then return 4 end
    return CLASSIFICATION[str(call(UnitClassification, unit), "")] or 0
end

function ns.NpcIdFromGUID(guid)
    if not usable(guid) or type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, npcId = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(npcId)
end

function ns.IsSpellKnown(spellId)
    local sb = api("C_SpellBook.IsSpellKnown")
    if sb and yes(call(sb, spellId)) then return true end
    if yes(call(IsPlayerSpell, spellId)) then return true end
    if yes(call(IsSpellKnown, spellId)) then return true end
    return false
end

function ns.RidingFromSpells()
    for _, entry in ipairs(ns.RIDING_SPELLS) do
        if ns.IsSpellKnown(entry[1]) then return entry[2] end
    end
    return nil
end

function ns.AppendWeaponSkills(list)
    local count, info = api("C_SkillInfo.GetNumSkillLines"), api("C_SkillInfo.GetSkillLineInfo")
    if not count or not info then return end
    local have = {}
    for _, s in ipairs(list) do have[s.id] = true end
    local n = num(call(count), 0)
    for i = 1, min(n, 200) do
        local line = call(info, i)
        if type(line) == "table" and usable(line) and not line.isHeader then
            local id = num(line.skillID, nil)
            if id and ns.WEAPON_SKILLS[id] and not have[id] then
                local rank = num(line.rank, 0)
                if rank > 0 then
                    have[id] = true
                    list[#list + 1] = { id = id, rank = rank, max = num(line.maxRank, 0), name = str(line.name, ns.WEAPON_SKILLS[id]) }
                end
            end
        end
    end
end

function ns.GetSkills()
    local list = {}
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local slots = { call(GetProfessions) }
        for i = 1, table.maxn(slots) do
            local idx = slots[i]
            if usable(idx) then
                local name, _, rank, maxRank, _, _, skillLine = call(GetProfessionInfo, idx)
                local id = num(skillLine, nil)
                if id then
                    list[#list + 1] = { id = id, rank = num(rank, 0), max = num(maxRank, 0), name = str(name, "") }
                end
            end
        end
    end
    local riding = ns.RidingFromSpells()
    if riding then list[#list + 1] = { id = ns.SKILL_RIDING, rank = riding, max = riding, name = ns.PROFESSIONS[ns.SKILL_RIDING] } end
    ns.AppendWeaponSkills(list)
    return list
end

function ns.SkillKey(s)
    if s.id and s.id > 0 then return tostring(s.id) end
    return "n:" .. (s.name or "")
end

local function clampStanding(v)
    v = num(v, 0)
    if v < 1 or v > 8 then return nil end
    return v
end

local function readFactions(list, seen)
    local count, byIndex = api("C_Reputation.GetNumFactions"), api("C_Reputation.GetFactionDataByIndex")
    if not count or not byIndex then return end
    local n = num(call(count), 0)
    for i = 1, n do
        local d = call(byIndex, i)
        if type(d) == "table" then
            local id = num(d.factionID, 0)
            local isHeader = yes(d.isHeader)
            local withRep = yes(d.isHeaderWithRep)
            local standing = clampStanding(d.reaction)
            if id > 0 and standing and (not isHeader or withRep) and not seen[id] then
                seen[id] = true
                list[#list + 1] = { id = id, standing = standing }
            end
        end
    end
end

function ns.FactionStanding(id)
    local fn = api("C_Reputation.GetFactionDataByID")
    local d = fn and call(fn, id)
    if type(d) == "table" then return clampStanding(d.reaction) end
    return nil
end

function ns.GetFactions(expand)
    local list, seen = {}, {}
    local count, byIndex = api("C_Reputation.GetNumFactions"), api("C_Reputation.GetFactionDataByIndex")
    local expandFn, collapseFn = api("C_Reputation.ExpandFactionHeader"), api("C_Reputation.CollapseFactionHeader")
    local collapsed = {}
    if expand and count and byIndex and expandFn and collapseFn and not InCombatLockdown() then
        for _ = 1, 30 do
            local changed = false
            local n = num(call(count), 0)
            for i = 1, n do
                local d = call(byIndex, i)
                if type(d) == "table" and yes(d.isHeader) and yes(d.isCollapsed) and str(d.name, nil) then
                    collapsed[#collapsed + 1] = d.name
                    call(expandFn, i)
                    changed = true
                    break
                end
            end
            if not changed then break end
        end
    end
    readFactions(list, seen)
    for k = #collapsed, 1, -1 do
        local n = num(call(count), 0)
        for i = 1, n do
            local d = call(byIndex, i)
            if type(d) == "table" and d.name == collapsed[k] then
                call(collapseFn, i)
                break
            end
        end
    end
    return list
end

function ns.PvpRank()
    if type(UnitPVPRank) == "function" then
        local r = num(call(UnitPVPRank, "player"), nil)
        if r then return u8(max(0, r - 4)) end
    end
    if type(UnitHonorLevel) == "function" then
        local h = num(call(UnitHonorLevel, "player"), nil)
        if h then return u8(h) end
    end
    return nil
end

function ns.CollectedMountSpells()
    local ids, info = api("C_MountJournal.GetMountIDs"), api("C_MountJournal.GetMountInfoByID")
    if not ids or not info then return nil end
    local list = call(ids)
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, mountId in ipairs(list) do
        local _, spellId, _, _, _, _, _, _, _, _, isCollected = call(info, mountId)
        local sid = num(spellId, nil)
        if sid and yes(isCollected) then out[#out + 1] = sid end
    end
    return out
end

function ns.MountSpell(mountId)
    local info = api("C_MountJournal.GetMountInfoByID")
    if not info then return nil end
    local _, spellId = call(info, mountId)
    return num(spellId, nil)
end

local collectors = {}
local byEvent = {}
local debounced = {}

function ns.Collector(name, def)
    def.name = name
    collectors[#collectors + 1] = def
    for event, handler in pairs(def.events or {}) do
        byEvent[event] = byEvent[event] or {}
        table.insert(byEvent[event], { def = def, handler = handler })
    end
end

function ns.Debounce(key, delay, fn)
    if debounced[key] then return end
    debounced[key] = true
    TG.After(delay, function()
        debounced[key] = nil
        if ns.Mod.rec and not ns.Mod.passive then fn() end
    end)
end

local function each(method, ...)
    local rec = ns.Mod.rec
    for _, def in ipairs(collectors) do
        if type(def[method]) == "function" then TG.SafeCall(def[method], rec, ...) end
    end
end
Facts.Each = each

function Facts.CheckAll()
    local mod = ns.Mod
    if mod.ready and mod.rec and not mod.passive then each("check") end
end

local function dispatch(event, ...)
    local mod = ns.Mod
    local list = byEvent[event]
    if not list or not mod.rec or mod.passive then return end
    for _, entry in ipairs(list) do
        if mod.ready or not entry.def.waitForBaseline then TG.SafeCall(entry.handler, mod.rec, ...) end
    end
end

local function eventValid(event)
    local fn = api("C_EventUtils.IsEventValid")
    if not fn then return true end
    local ok, valid = pcall(fn, event)
    return not (ok and valid == false)
end

function Facts.Start(rec)
    for event in pairs(byEvent) do
        if eventValid(event) then ns.Mod:RegisterEvent(event, dispatch) end
    end
    each("init")
end

local MILESTONES = { [75] = true, [150] = true, [225] = true, [300] = true, [375] = true }

local announceQueue = {}

local function flushAnnounce()
    if InCombatLockdown() then return end
    local pending = announceQueue
    announceQueue = {}
    if not yes(call(IsInGuild)) then return end
    for _, text in ipairs(pending) do
        SendChatMessage("[Geh Heim] " .. text, "GUILD")
    end
end

function ns.Announce(key, text)
    if not ns.Mod.db.announce or not ns.Mod.rec then return end
    local st = ns.State("announced")
    if st[key] then return end
    st[key] = now()
    announceQueue[#announceQueue + 1] = text
    flushAnnounce()
end

ns.Collector("Announce", {
    waitForBaseline = false,
    events = { PLAYER_REGEN_ENABLED = flushAnnounce },
})

local function levelExtras()
    return ns.Weather(), ns.BestMap() or 0, u8(ns.ArmorPieces()), ns.GroupSize()
end

local function logLevelsUpTo(level, live)
    local st = ns.State("level")
    if not level or level < 1 or level > 255 then return end
    if st.logged == nil then
        ns.Append({ T.level, level })
        st.logged = level
        return
    end
    if level <= st.logged then return end
    for l = st.logged + 1, level do
        if live then
            local weather, map, armor, group = levelExtras()
            ns.Append({ T.level, l, weather, map, armor, group })
            ns.Notice(L["Level %d"]:format(l), "level_" .. l)
            if ns.ANNOUNCE_LEVELS[l] then ns.Announce("level:" .. l, L["Level %d reached!"]:format(l)) end
        else
            ns.Append({ T.level, l })
        end
    end
    st.logged = level
end

ns.Collector("Level", {
    waitForBaseline = false,
    events = {
        PLAYER_LEVEL_UP = function(_, level)
            level = num(level, nil)
            if level then logLevelsUpTo(level, true) end
        end,
    },
    baseline = function(_, snap)
        local st = ns.State("level")
        st.logged = max(st.logged or 0, snap.level or 0)
    end,
    check = function()
        local st = ns.State("level")
        local cur = ns.Level()
        if st.logged and cur > st.logged then
            logLevelsUpTo(cur)
        elseif not st.logged then
            st.logged = cur
        end
    end,
})

local function rungFor(copper)
    local idx = 0
    for i, g in ipairs(ns.MONEY_RUNGS_GOLD) do
        if copper >= g * ns.COPPER_PER_GOLD then idx = i end
    end
    return idx
end

local function checkMoney()
    local st = ns.State("money")
    local copper = ns.Money()
    st.peak = max(st.peak or 0, copper)
    local rung = rungFor(copper)
    if rung > (st.rung or 0) then
        if st.rung then
            local gold = ns.MONEY_RUNGS_GOLD[rung]
            ns.Notice(L["%d gold"]:format(gold), "gold_" .. gold)
        end
        st.rung = rung
        ns.Append({ T.money_peak, copper })
    end
end

ns.Collector("Money", {
    waitForBaseline = true,
    events = { PLAYER_MONEY = checkMoney },
    baseline = function(_, snap)
        local st = ns.State("money")
        st.peak = max(st.peak or 0, snap.money or 0)
        st.rung = max(st.rung or 0, rungFor(snap.money or 0))
    end,
    check = checkMoney,
})

local function readDeathRecap(diedAt)
    local has, get, maxHp = api("C_DeathRecap.HasRecapEvents"), api("C_DeathRecap.GetRecapEvents"), api("C_DeathRecap.GetRecapMaxHealth")
    if not has or not get then return nil end
    if not yes(call(has)) then return nil end
    local events = call(get)
    if type(events) ~= "table" or not usable(events) then return nil end
    local fatal, newest
    for _, e in ipairs(events) do
        if type(e) == "table" and usable(e) then
            local ts = tonumber(usable(e.timestamp) and e.timestamp or nil)
            if ts and math.abs(ts - diedAt) <= 60 then
                if not newest or ts > newest.ts then newest = { e = e, ts = ts } end
                local overkill = usable(e.overkill) and tonumber(e.overkill) or -1
                if overkill and overkill >= 0 and (not fatal or ts > fatal.ts) then fatal = { e = e, ts = ts } end
            end
        end
    end
    local hit = fatal or newest
    if not hit then return nil end
    local e = hit.e
    local kind, id, env = 0, 0, 0
    if str(e.event, "") == "ENVIRONMENTAL_DAMAGE" then
        env = ns.ENV_TYPES[str(e.environmentalType, ""):lower()] or 7
        kind, id = 3, env
    else
        local guid = str(e.sourceGUID, nil)
        local npc = ns.NpcIdFromGUID(guid)
        if npc then
            kind, id = 1, npc
        elseif guid and guid:find("^Player%-") then
            kind = 2
        end
    end
    local maxHealth = num(call(maxHp), 0)
    local before = num(e.currentHP, 0)
    local oneShot = (maxHealth > 0 and before >= maxHealth) and 1 or 0
    return kind, id, env, oneShot
end

local function guessEnvironment()
    if yes(call(IsFalling)) then return ns.ENV_TYPES.falling end
    if yes(call(IsSwimming)) and type(GetMirrorTimerInfo) == "function" then
        for i = 1, 3 do
            local name = call(GetMirrorTimerInfo, i)
            if usable(name) and name == "BREATH" then return ns.ENV_TYPES.drowning end
        end
    end
    return 0
end

local deathPending = false

ns.Collector("Death", {
    waitForBaseline = false,
    events = {
        PLAYER_DEAD = function()
            if deathPending then return end
            deathPending = true
            local map, level, guess, weather, diedAt = ns.BestMap() or 0, u8(ns.Level()), guessEnvironment(), ns.Weather(), now()
            local instanceType, _, instanceId = ns.InstanceInfo()
            if instanceType ~= "party" and instanceType ~= "raid" then instanceId = 0 end
            local tries = 0
            local function finish()
                tries = tries + 1
                local kind, id, env, oneShot = readDeathRecap(diedAt)
                if not kind and tries < 3 then
                    TG.After(1.5, finish)
                    return
                end
                if not kind or (kind == 0 and guess > 0) then
                    kind, id, env, oneShot = guess > 0 and 3 or 0, guess, guess, 0
                end
                deathPending = false
                ns.Append({ T.death, map, level, kind, id, env, oneShot, weather, instanceId })
            end
            TG.After(0.5, finish)
        end,
    },
})

local function checkPvp()
    local rank = ns.PvpRank()
    if not rank then return end
    local st = ns.State("pvp")
    if st.rank == nil then
        st.rank = rank
        return
    end
    if rank > st.rank then
        st.rank = rank
        ns.Append({ T.pvp_rank, rank })
    end
end

ns.Collector("PvP", {
    waitForBaseline = true,
    events = { PLAYER_PVP_RANK_CHANGED = checkPvp, HONOR_LEVEL_UPDATE = checkPvp },
    baseline = function(_, snap) ns.State("pvp").rank = snap.pvp or 0 end,
    check = checkPvp,
})

local function checkSkills()
    local st = ns.State("skills")
    for _, s in ipairs(ns.GetSkills()) do
        local key = ns.SkillKey(s)
        local known = st[key]
        local prev = known and known.rank
        local rank = s.rank or 0
        local logIt = false
        if not known then
            known = { rank = rank, logged = rank }
            st[key] = known
            logIt = true
        elseif floor(rank / 25) > floor((known.logged or 0) / 25) then
            known.logged = rank
            logIt = true
        end
        known.rank = rank
        if logIt then
            ns.Append({ T.skill, s.id, rank, s.max or 0, ns.Snapshot.SkillName(s) })
            for m in pairs(MILESTONES) do
                if prev and prev < m and rank >= m then
                    ns.Notice(("%s %d"):format(ns.PROFESSIONS[s.id] or ns.WEAPON_SKILLS[s.id] or s.name or "", m), "skill_" .. s.id .. "_" .. m)
                end
            end
        end
        if prev and prev < ns.PROFESSION_CAP and rank >= ns.PROFESSION_CAP and ns.PROFESSIONS[s.id] and s.id ~= ns.SKILL_RIDING then
            ns.Announce("skill:" .. s.id, L["%s mastered (%d)!"]:format(ns.PROFESSIONS[s.id], ns.PROFESSION_CAP))
        end
    end
end

local function scheduleSkills()
    ns.Debounce("skills", 0.5, checkSkills)
end

ns.Collector("Skills", {
    waitForBaseline = true,
    events = {
        SKILL_LINES_CHANGED = scheduleSkills,
        CHAT_MSG_SKILL = scheduleSkills,
        TRADE_SKILL_LIST_UPDATE = scheduleSkills,
        LEARNED_SPELL_IN_TAB = scheduleSkills,
        SPELLS_CHANGED = scheduleSkills,
    },
    baseline = function(_, snap)
        local st = ns.State("skills")
        for _, s in ipairs(snap.skills or {}) do
            st[ns.SkillKey(s)] = { rank = s.rank or 0, logged = s.rank or 0 }
        end
    end,
    check = checkSkills,
})

local function mountBaseline()
    local st = ns.State("mounts")
    local list = ns.CollectedMountSpells()
    if not list then return end
    st.known = st.known or {}
    for _, sid in ipairs(list) do st.known[sid] = true end
    st.init = true
end

local function logMount(spellId)
    local st = ns.State("mounts")
    st.known = st.known or {}
    if spellId and not st.known[spellId] then
        st.known[spellId] = true
        ns.Append({ T.mount_learned, spellId })
    end
end

local function checkMounts()
    local st = ns.State("mounts")
    if not st.init then
        mountBaseline()
        return
    end
    for _, sid in ipairs(ns.CollectedMountSpells() or {}) do logMount(sid) end
end

ns.Collector("Mounts", {
    waitForBaseline = true,
    events = {
        NEW_MOUNT_ADDED = function(_, mountId)
            local mid = num(mountId, nil)
            if mid then logMount(ns.MountSpell(mid)) end
        end,
        COMPANION_LEARNED = function() ns.Debounce("mounts", 1, checkMounts) end,
    },
    baseline = mountBaseline,
    check = checkMounts,
})

local function checkZone()
    if ns.IsDeadOrGhost() then return end
    local map = ns.BestMap()
    if not map then return end
    local st = ns.State("zones")
    if st[map] then return end
    st[map] = true
    ns.Append({ T.zone_visit, map })
end

local function scheduleZone()
    ns.Debounce("zones", 0.3, checkZone)
end

ns.Collector("Zones", {
    waitForBaseline = false,
    events = {
        ZONE_CHANGED_NEW_AREA = scheduleZone,
        ZONE_CHANGED = scheduleZone,
        ZONE_CHANGED_INDOORS = scheduleZone,
        PLAYER_UNGHOST = scheduleZone,
        PLAYER_ALIVE = scheduleZone,
    },
    check = checkZone,
})

local function checkExploration()
    local map, x, y = ns.PlayerPosition()
    if not map then return end
    local st = ns.State("explored")
    for _, id in ipairs(ns.ExploredAreasAt(map, x, y) or {}) do
        if not st[id] then
            st[id] = now()
            ns.Append({ T.area_discovered, id })
        end
    end
end

ns.Collector("Exploration", {
    waitForBaseline = true,
    events = { MAP_EXPLORATION_UPDATED = function() ns.Debounce("exploration", 0.5, checkExploration) end },
})

local SAMPLE_POINTS = { { 0.5, 0.5 }, { 0.3, 0.5 }, { 0.7, 0.5 }, { 0.5, 0.3 }, { 0.5, 0.7 } }

local function findCityArea(city)
    local minX, maxX, minY, maxY = ns.MapRect(city.map, city.parent, city.continent)
    if not minX then return nil end
    local wanted = {}
    for i, id in ipairs(city.areas) do wanted[id] = i end
    local best, bestRank
    for _, pt in ipairs(SAMPLE_POINTS) do
        local x = minX + (maxX - minX) * pt[1]
        local y = minY + (maxY - minY) * pt[2]
        for _, id in ipairs(ns.ExploredAreasAt(city.parent, x, y) or {}) do
            local rank = wanted[id]
            if rank and (not bestRank or rank < bestRank) then best, bestRank = id, rank end
        end
        if bestRank == 1 then break end
    end
    return best
end

local function scanCities()
    local st = ns.State("areas")
    local found = {}
    for _, city in ipairs(ns.CITIES) do
        if not st[city.key] then
            local ok, id = pcall(findCityArea, city)
            if ok and id then
                st[city.key] = id
                found[#found + 1] = { T.area_discovered, id }
            end
        end
    end
    return found
end

local function checkCities()
    for _, e in ipairs(scanCities()) do ns.Append(e) end
end

local function scheduleCities()
    ns.Debounce("cities", 1, checkCities)
end

ns.Collector("Cities", {
    waitForBaseline = true,
    events = { MAP_EXPLORATION_UPDATED = scheduleCities, ZONE_CHANGED_NEW_AREA = scheduleCities },
    snapshotEvents = function() return scanCities() end,
    check = checkCities,
})

ns.Collector("Quests", {
    waitForBaseline = false,
    events = {
        QUEST_TURNED_IN = function(_, questId)
            local id = num(questId, nil)
            if not id or id == 0 then return end
            local st = ns.State("quests")
            if st[id] then return end
            st[id] = true
            ns.Append({ T.quest_turned_in, id })
        end,
    },
})

local function noteStanding(st, id, standing)
    local known = st[id]
    if known == nil then
        st[id] = standing
        if standing >= 5 then ns.Append({ T.reputation_standing, id, standing }) end
    elseif standing > known then
        st[id] = standing
        ns.Append({ T.reputation_standing, id, standing })
        if standing == 8 then
            local label = type(FACTION_STANDING_LABEL8) == "string" and FACTION_STANDING_LABEL8 or L["Exalted"]
            local ok, d = pcall(C_Reputation and C_Reputation.GetFactionDataByID or error, id)
            local name = ok and type(d) == "table" and TG.plain(d.name, nil)
            ns.Notice(type(name) == "string" and name ~= "" and (name .. ": " .. label) or label, "rep_" .. id .. "_8")
        end
    end
end

local function checkReps()
    local st = ns.State("reps")
    local seen = {}
    for _, f in ipairs(ns.GetFactions()) do
        seen[f.id] = true
        noteStanding(st, f.id, f.standing)
    end
    for id in pairs(st) do
        if not seen[id] and type(id) == "number" then
            local standing = ns.FactionStanding(id)
            if standing then noteStanding(st, id, standing) end
        end
    end
end

ns.Collector("Reputation", {
    waitForBaseline = true,
    events = { UPDATE_FACTION = function() ns.Debounce("reps", 1, checkReps) end },
    baseline = function(_, snap)
        local st = ns.State("reps")
        for _, f in ipairs(snap.factions or {}) do
            if st[f.id] == nil or f.standing > st[f.id] then st[f.id] = f.standing end
        end
    end,
    check = checkReps,
})

local recent, started, recentWipe = {}, {}, {}

local function durationOf(encounterId, t)
    local s = started[encounterId]
    if s and t >= s and t - s <= 7200 then return t - s end
    return 0
end

local function logEncounter(encounterId, src, difficulty, size, name)
    local t = now()
    local last = recent[encounterId]
    if last and t - last < ns.ENCOUNTER_DEDUPE then return end
    recent[encounterId] = t
    local instanceType, instDifficulty, instanceId = ns.InstanceInfo()
    if instanceType == "party" or instanceType == "raid" then ns.Mod.rec.encounter_events_seen = true end
    local diff = num(difficulty, nil) or instDifficulty
    local st = ns.State("kills")
    local key = encounterId .. ":" .. diff
    st[key] = st[key] or t
    local groupSize = num(size, nil)
    groupSize = u8(groupSize and max(1, groupSize) or ns.GroupSize())
    ns.Append({ T.encounter_kill, encounterId, 0, diff, instanceId, groupSize, src,
        durationOf(encounterId, t), ns.GuildMembersInGroup(), ns.Weather(), ns.TabardItem() })
    started[encounterId] = nil
    ns.lastBossKill = { id = encounterId, at = t }
    local label = str(name, nil)
    ns.Notice(label and label ~= "" and L["Boss defeated: %s"]:format(label) or L["Boss defeated"], "boss_kill")
end

local BOSSLIKE = { worldboss = true, rareelite = true, elite = true }

local function unitIsBossLike(unit)
    if yes(call(UnitIsBossMob, unit)) then return true end
    local lvl = call(UnitLevel, unit)
    if usable(lvl) and lvl == -1 then return true end
    return BOSSLIKE[str(call(UnitClassification, unit), "")] == true
end

local function lootFallback()
    if ns.Mod.rec.encounter_events_seen then return end
    local instanceType, difficulty, instanceId = ns.InstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then return end
    if type(GetLootSourceInfo) ~= "function" then return end
    local units = {}
    for _, unit in ipairs({ "target", "mouseover" }) do
        local g = str(call(UnitGUID, unit), nil)
        if g then units[g] = unit end
    end
    local n = num(call(GetNumLootItems), 0)
    local st = ns.State("loot_npcs")
    for slot = 1, n do
        local sources = { call(GetLootSourceInfo, slot) }
        for i = 1, #sources, 2 do
            local guid = sources[i]
            if usable(guid) and type(guid) == "string" then
                local unit = units[guid]
                local npcId = ns.NpcIdFromGUID(guid)
                if npcId and unit and not st[npcId] and unitIsBossLike(unit) then
                    st[npcId] = now()
                    ns.Append({ T.encounter_kill, 0, npcId, difficulty, instanceId, ns.GroupSize(), 3 })
                end
            end
        end
    end
end

ns.Collector("Encounters", {
    waitForBaseline = false,
    events = {
        BOSS_KILL = function(_, encounterId, name)
            local id = num(encounterId, nil)
            if id and id > 0 then logEncounter(id, 4, nil, nil, name) end
        end,
        ENCOUNTER_START = function(_, encounterId)
            local id = num(encounterId, nil)
            if id and id > 0 then started[id] = now() end
        end,
        ENCOUNTER_END = function(_, encounterId, name, difficulty, size, success)
            if not usable(encounterId) or not usable(success) then return end
            local id = num(encounterId, nil)
            if not id or id == 0 then return end
            if success ~= 1 and success ~= true then
                local t = now()
                if not (recentWipe[id] and t - recentWipe[id] < ns.ENCOUNTER_DEDUPE) then
                    recentWipe[id] = t
                    local _, instDifficulty, instanceId = ns.InstanceInfo()
                    local groupSize = num(size, nil)
                    ns.Append({ T.encounter_wipe, id, num(difficulty, nil) or instDifficulty, instanceId,
                        u8(groupSize and max(1, groupSize) or ns.GroupSize()), durationOf(id, t) })
                    started[id] = nil
                end
                return
            end
            logEncounter(id, 1, difficulty, size, name)
        end,
        LOOT_OPENED = lootFallback,
    },
})

local fight
local rares, raresCount, rareDone = {}, 0, {}

local function noteRare(unit)
    local guid = str(call(UnitGUID, unit), nil)
    if not guid or rares[guid] or rareDone[guid] then return end
    local cls = ns.Classification(unit)
    if cls ~= 2 and cls ~= 3 then return end
    local npc = ns.NpcIdFromGUID(guid)
    if not npc then return end
    if raresCount > 200 then rares, raresCount = {}, 0 end
    rares[guid] = { npc = npc, cls = cls }
    raresCount = raresCount + 1
end

local function logRareKill(guid, how)
    local r = guid and rares[guid]
    if not r or rareDone[guid] then return end
    rareDone[guid] = true
    ns.Append({ T.rare_kill, r.npc, r.cls, how })
end

local function noteTarget(unit)
    noteRare(unit)
    if not fight then return end
    if not yes(call(UnitCanAttack, "player", unit)) then return end
    local guid = str(call(UnitGUID, unit), nil)
    local npc = ns.NpcIdFromGUID(guid)
    if not npc then return end
    local cls = ns.Classification(unit)
    if not fight.npc or cls > fight.cls then fight.npc, fight.cls, fight.guid = npc, cls, guid end
end

local function lastFightDamage()
    local fn = api("C_DamageMeter.GetCombatSessionFromType")
    if not fn then return 0, 0 end
    local session = call(fn, 1, 0)
    if type(session) ~= "table" or not usable(session) then return 0, 0 end
    local duration = num(session.durationSeconds, 0)
    local damage = 0
    if type(session.combatSources) == "table" and usable(session.combatSources) then
        for _, src in ipairs(session.combatSources) do
            if type(src) == "table" and usable(src) and yes(src.isLocalPlayer) then damage = num(src.totalAmount, 0) end
        end
    end
    return damage, duration
end

local function targetDead(f)
    if not f.guid then return false end
    local guid = str(call(UnitGUID, "target"), nil)
    return guid == f.guid and yes(call(UnitIsDead, "target"))
end

local function finishFight(f)
    local damage, meterDuration = lastFightDamage()
    local duration = max(f.ended - f.started, 0)
    if meterDuration > 0 and meterDuration <= duration + 5 then duration = meterDuration end
    local kill = ns.lastBossKill
    local bossKilled = kill and kill.at and kill.at >= f.started and kill.at <= f.ended + 2
    local killed = (f.deadAtEnd or bossKilled or targetDead(f)) and 1 or 0
    local instanceType = ns.InstanceInfo()
    local inInstance = instanceType == "party" or instanceType == "raid"
    local st = ns.State("fights")
    local reasons = 0
    if duration >= ns.FIGHT_LONG_S then reasons = reasons + 1 end
    if f.cls >= (inInstance and 2 or 1) then reasons = reasons + 2 end
    if damage >= ns.FIGHT_RECORD_MIN and damage > (st.max_damage or 0) then
        st.max_damage = damage
        reasons = reasons + 4
    end
    if killed == 1 then logRareKill(f.guid, 1) end
    if reasons == 0 then return end
    ns.Append({ T.fight, duration, damage, f.npc or 0, f.cls or 0, killed, reasons, ns.GuildMembersInGroup(), ns.Weather() })
end

ns.Collector("Fights", {
    waitForBaseline = true,
    events = {
        PLAYER_REGEN_DISABLED = function()
            fight = { started = now(), cls = 0 }
            noteTarget("target")
        end,
        PLAYER_TARGET_CHANGED = function() noteTarget("target") end,
        UPDATE_MOUSEOVER_UNIT = function() noteTarget("mouseover") end,
        NAME_PLATE_UNIT_ADDED = function(_, unit)
            if usable(unit) and type(unit) == "string" then noteRare(unit) end
        end,
        PLAYER_REGEN_ENABLED = function()
            local f = fight
            fight = nil
            if not f then return end
            f.ended = now()
            f.deadAtEnd = targetDead(f)
            TG.After(1, function() if ns.Mod.rec then finishFight(f) end end)
        end,
    },
})

local function contains(list, id)
    for _, v in ipairs(list) do
        if v == id then return true end
    end
    return false
end
ns.IsCandidate = contains

local function once(id, value)
    value = num(value, 0)
    if value == 0 then return end
    local st = ns.State("moments12")
    local key = id .. ":" .. value
    if st[key] then return end
    ns.Append({ T.moment, id, value })
    st[key] = true
end
ns.RecordMoment = once

local function bump(id)
    local st = ns.State("stats12")
    st[id] = (st[id] or 0) + 1
    for _, rung in ipairs(ns.COUNTER_RUNGS) do
        if st[id] == rung then ns.Append({ T.stat, id, rung }) end
    end
end

function ns.PlayerBuffs()
    local out = {}
    local byIndex = api("C_UnitAuras.GetAuraDataByIndex")
    for i = 1, 255 do
        local name, id
        if byIndex then
            local aura = call(byIndex, "player", i, "HELPFUL")
            if type(aura) ~= "table" or not usable(aura) then break end
            name, id = str(aura.name, ""), num(aura.spellId, nil)
        else
            local values = { call(UnitBuff, "player", i) }
            name, id = str(values[1], nil), num(values[10], nil)
            if not name then break end
        end
        if id and id > 0 then out[#out + 1] = { id = id, name = name } end
    end
    return out
end

local activeBuffs = {}

local function noteBuff(id, fresh)
    once(ns.MOMENT.buff, id)
    if fresh and contains(ns.ID_CANDIDATES.rest, id) then once(ns.MOMENT.rest, ns.BestMap()) end
end

local function scanBuffs()
    local seen = {}
    for _, buff in ipairs(ns.PlayerBuffs()) do
        noteBuff(buff.id, not activeBuffs[buff.id])
        seen[buff.id] = true
    end
    activeBuffs = seen
end

local function onAura(_, unit, info)
    if str(unit, "") ~= "player" then return end
    if type(info) == "table" and usable(info) then
        local full = info.isFullUpdate
        if full == nil or (usable(full) and not full) then
            local added = info.addedAuras
            if type(added) == "table" and usable(added) then
                for _, aura in ipairs(added) do
                    local id = type(aura) == "table" and usable(aura) and num(aura.spellId, nil)
                    if id and id > 0 and not yes(aura.isHarmful) then
                        noteBuff(id, true)
                        activeBuffs[id] = true
                    end
                end
            end
            return
        end
    end
    ns.Debounce("buffs12", 0.5, scanBuffs)
end

local recipes = {}

local function scanRecipes()
    local all = api("C_TradeSkillUI.GetAllRecipeIDs")
    local ids = all and call(all)
    if type(ids) == "table" and usable(ids) then
        for _, raw in ipairs(ids) do
            local id = num(raw, nil)
            if id then recipes[id] = true end
        end
    end
    for _, kind in ipairs({ "TradeSkill", "Craft" }) do
        local n = num(call(_G["GetNum" .. kind .. "s"]), 0)
        local getLink = _G["Get" .. kind .. "RecipeLink"]
        for i = 1, min(n, 5000) do
            local link = str(call(getLink, i), "")
            local id = tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
            if id then recipes[id] = true end
        end
    end
end

local pendingItem, lastCast
ns.RecentSpells = {}

local function usedBag(bag, slot)
    bag, slot = num(bag, nil), num(slot, nil)
    if not bag or not slot or bag > 5 or slot < 1 then return end
    local item = num(call(api("C_Container.GetContainerItemID") or GetContainerItemID, bag, slot), nil)
    if not item then return end
    local _, spell = call(api("C_Item.GetItemSpell") or GetItemSpell, item)
    spell = num(spell, nil)
    if spell then pendingItem = { item = item, spell = spell, at = now() } end
end

local function onCast(_, unit, castGuid, spellId)
    if str(unit, "") ~= "player" then return end
    local id = num(spellId, nil)
    if not id then return end
    local key = str(castGuid, nil)
    if key and key == lastCast then return end
    lastCast = key
    table.insert(ns.RecentSpells, 1, id)
    if #ns.RecentSpells > 5 then table.remove(ns.RecentSpells) end
    if contains(ns.ID_CANDIDATES.campfire, id) then once(ns.MOMENT.campfire, ns.BestMap()) end
    if recipes[id] then
        once(ns.MOMENT.craft, id)
        bump(ns.STAT_CRAFTS)
    end
    if pendingItem and pendingItem.spell == id and now() - pendingItem.at <= 30 then
        ns.LastUsedItem = pendingItem.item
        once(ns.MOMENT.use, pendingItem.item)
        local instant = api("C_Item.GetItemInfoInstant") or GetItemInfoInstant
        if num(select(6, call(instant, pendingItem.item)), -1) == 0 then bump(ns.STAT_CONSUMABLES) end
        pendingItem = nil
    end
end

local function salute(emote)
    if str(emote, ""):upper() ~= "SALUTE" or not ns.Mod.rec or ns.Mod.passive then return end
    local player = call(UnitIsPlayer, "target")
    if usable(player) and not player then once(ns.MOMENT.salute, ns.NpcIdFromGUID(str(call(UnitGUID, "target"), nil))) end
end

local lastMap, tramOrigin

local function inTram(map)
    if map and contains(ns.ID_CANDIDATES.tram, map) then return true end
    local _, _, instanceId = ns.InstanceInfo()
    if instanceId ~= 0 and contains(ns.ID_CANDIDATES.tramInstance, instanceId) then return true end
    local zone = str(call(GetRealZoneText), ""):lower()
    if zone ~= "" then
        for _, word in ipairs(ns.ID_CANDIDATES.tramZone) do
            if zone:find(word, 1, true) then return true end
        end
    end
    return false
end

local function checkTram()
    local map = ns.BestMap()
    if inTram(map) then
        if not tramOrigin then
            if ns.TRAM_IRONFORGE[lastMap] then tramOrigin = 1 elseif ns.TRAM_STORMWIND[lastMap] then tramOrigin = 2 end
        end
        return
    end
    if not map then return end
    if tramOrigin then
        if (tramOrigin == 1 and ns.TRAM_STORMWIND[map]) or (tramOrigin == 2 and ns.TRAM_IRONFORGE[map]) then once(ns.MOMENT.tram, tramOrigin) end
        tramOrigin = nil
    end
    lastMap = map
end

local bindLocation

local function checkBind()
    local current = str(call(GetBindLocation), nil)
    if current and bindLocation and current ~= bindLocation then once(ns.MOMENT.bind, ns.BestMap()) end
    bindLocation = current or bindLocation
end

local rez

local function onRezRequest(_, unit)
    rez = nil
    local u = str(unit, "")
    if u ~= "" and yes(call(UnitIsInMyGuild, u)) then rez = { map = ns.BestMap(), at = now() } end
end

local function onAlive()
    local alive = not ns.IsDeadOrGhost()
    if rez and alive and now() - rez.at < 120 then
        once(ns.MOMENT.guild_rez, rez.map)
        bump(ns.STAT_GUILD_REZ)
    end
    if alive then rez = nil end
end

local run

local function checkRun()
    local kind, _, id = ns.InstanceInfo()
    if run and (kind ~= "party" or id ~= run.id) then
        if run.n >= 3 then once(ns.MOMENT.guild_dungeon, run.id * 10 + 1 + (run.clean and 2 or 0) + (run.guild and 4 or 0)) end
        run = nil
    end
    if kind ~= "party" or id == 0 then return end
    if not run then run = { id = id, bosses = {}, n = 0, clean = true, guild = true } end
end

local function onRunEvent(_, e)
    if not run then return end
    if e[2] == T.encounter_kill and e[6] == run.id then
        local key = e[3] .. ":" .. e[4]
        if not run.bosses[key] then
            run.bosses[key] = true
            run.n = run.n + 1
        end
        run.guild = run.guild and (e[10] or 0) >= 3
    elseif e[2] == T.encounter_wipe or e[2] == T.death then
        run.clean = false
    end
end

local hooked = false

ns.Collector("Discoveries", {
    waitForBaseline = true,
    init = function()
        if hooked then return end
        hooked = true
        ns.OnAppend(onRunEvent)
        if type(hooksecurefunc) == "function" then
            if type(DoEmote) == "function" then call(hooksecurefunc, "DoEmote", salute) end
            if type(Emote) == "function" then call(hooksecurefunc, "Emote", salute) end
            if api("C_Container.UseContainerItem") then
                call(hooksecurefunc, C_Container, "UseContainerItem", usedBag)
            elseif type(UseContainerItem) == "function" then
                call(hooksecurefunc, "UseContainerItem", usedBag)
            end
        end
        bindLocation = str(call(GetBindLocation), nil)
    end,
    check = function()
        checkTram()
        checkRun()
        checkBind()
    end,
    events = {
        UNIT_AURA = onAura,
        UNIT_SPELLCAST_SUCCEEDED = onCast,
        TRADE_SKILL_SHOW = scanRecipes,
        CRAFT_SHOW = scanRecipes,
        TRADE_SKILL_LIST_UPDATE = function() ns.Debounce("recipes12", 1, scanRecipes) end,
        ZONE_CHANGED_NEW_AREA = function()
            checkTram()
            checkRun()
        end,
        HEARTHSTONE_BOUND = function()
            once(ns.MOMENT.bind, ns.BestMap())
            checkBind()
        end,
        GOSSIP_CLOSED = function() ns.Debounce("bind12", 1, checkBind) end,
        RESURRECT_REQUEST = onRezRequest,
        PLAYER_ALIVE = onAlive,
        PLAYER_UNGHOST = onAlive,
        PLAYER_DEAD = function()
            if run then run.clean = false end
            rez = nil
        end,
        SCREENSHOT_SUCCEEDED = function()
            if ns.GuildMembersInGroup() >= 3 then once(ns.MOMENT.photo, ns.BestMap()) end
        end,
    },
})

function ns.PrintIds()
    local function yn(group, value)
        return contains(ns.ID_CANDIDATES[group], value) and L["yes"] or L["no"]
    end
    local map = ns.BestMap() or 0
    local kind, difficulty, id = ns.InstanceInfo()
    local npc = ns.NpcIdFromGUID(str(call(UnitGUID, "target"), nil)) or 0
    TG:Print(L["UiMapID %d, tram candidate: %s"], map, yn("tram", map))
    TG:Print(L["Instance %s, ID %d, difficulty %d"], kind, id, difficulty)
    TG:Print(L["Target NPC %d, Horde leader candidate: %s"], npc, yn("leaders", npc))
    for _, buff in ipairs(ns.PlayerBuffs()) do
        TG:Print(L["Buff %s: %d, rest %s, pirate or ninja %s, Noggenfogger %s"], buff.name, buff.id, yn("rest", buff.id), yn("transform", buff.id), yn("noggenfogger", buff.id))
    end
    for i, spell in ipairs(ns.RecentSpells) do
        TG:Print(L["Own spell %d: %d, campfire %s, recipe %s"], i, spell, yn("campfire", spell), yn("recipe", spell))
    end
    TG:Print(L["Last catch: %d, Deviate Fish %s"], ns.LastFishingItem or 0, yn("fish", ns.LastFishingItem or 0))
    TG:Print(L["Last used item: %d, Savory Deviate Delight %s"], ns.LastUsedItem or 0, yn("food", ns.LastUsedItem or 0))
    TG:Print(L["Bind location: %s"], str(call(GetBindLocation), L["unknown"]))
end

local ID_WORDS = {
    maps = { "tiefenbahn", "deeprun", "tram" },
    spells = { "lagerfeuer", "campfire", "rast", "gemütlich", "cozy", "pirat", "pirate", "ninja", "noggenfogger", "deviat", "zelt", "tent" },
}
local SPELL_SCAN_MAX, SPELL_SCAN_STEP, MAP_SCAN_MAX, SPELL_HITS_MAX = 60000, 3000, 3000, 120

local function matchesWord(name, words)
    if not name then return false end
    name = name:lower()
    for _, w in ipairs(words) do
        if name:find(w, 1, true) then return true end
    end
    return false
end

function ns.IdCheck(onDone)
    local spellInfo, spellLegacy = api("C_Spell.GetSpellInfo"), GetSpellInfo
    local itemById, itemLegacy, itemLoad = api("C_Item.GetItemNameByID"), GetItemInfo, api("C_Item.RequestLoadItemDataByID")
    local mapInfo = api("C_Map.GetMapInfo")
    local function spellNameOf(id)
        local data = spellInfo and call(spellInfo, id)
        if type(data) == "table" then return str(data.name, nil) end
        return str(call(spellLegacy, id), nil)
    end
    local function itemNameOf(id)
        local name = str(call(itemById, id), nil) or str(call(itemLegacy, id), nil)
        if not name then call(itemLoad, id) end
        return name
    end
    local function mapNameOf(id)
        local data = call(mapInfo, id)
        return type(data) == "table" and str(data.name, nil) or nil
    end
    local lines = { ("Geh Heim %d.%d.%d"):format(ns.ADDON_VERSION[1], ns.ADDON_VERSION[2], ns.ADDON_VERSION[3]), "" }
    local function addList(label, ids, lookup)
        lines[#lines + 1] = label .. ":"
        for _, id in ipairs(ids) do
            local name = lookup(id)
            lines[#lines + 1] = ("  %d  %s"):format(id, name and ("= " .. name) or L["unknown or not loaded yet"])
        end
    end
    addList(L["Campfire spells"], ns.ID_CANDIDATES.campfire, spellNameOf)
    addList(L["Rest buff at the campfire"], ns.ID_CANDIDATES.rest, spellNameOf)
    addList(L["Recipe Savory Deviate Delight"], ns.ID_CANDIDATES.recipe, spellNameOf)
    addList(L["Pirate and ninja transformations"], ns.ID_CANDIDATES.transform, spellNameOf)
    addList(L["Noggenfogger buffs"], ns.ID_CANDIDATES.noggenfogger, spellNameOf)
    addList(L["Deviate Fish item"], ns.ID_CANDIDATES.fish, itemNameOf)
    addList(L["Savory Deviate Delight item"], ns.ID_CANDIDATES.food, itemNameOf)
    addList(L["Deeprun Tram map"], ns.ID_CANDIDATES.tram, mapNameOf)
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Maps named like the tram"] .. ":"
    local found = 0
    for id = 1, MAP_SCAN_MAX do
        local name = mapNameOf(id)
        if matchesWord(name, ID_WORDS.maps) then
            lines[#lines + 1] = ("  %d  = %s"):format(id, name)
            found = found + 1
        end
    end
    if found == 0 then lines[#lines + 1] = "  " .. L["none found"] end
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Horde leader NPC IDs need a target: select the NPC and use /tg gh ids."]
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Spells matching campfire, rest, pirate, ninja, Noggenfogger, deviate, tent"] .. ":"
    local hits, nextId = 0, 1
    local function step()
        local last = min(nextId + SPELL_SCAN_STEP - 1, SPELL_SCAN_MAX)
        for id = nextId, last do
            local name = spellNameOf(id)
            if hits < SPELL_HITS_MAX and matchesWord(name, ID_WORDS.spells) then
                lines[#lines + 1] = ("  %d  = %s"):format(id, name)
                hits = hits + 1
            end
        end
        nextId = last + 1
        if nextId <= SPELL_SCAN_MAX then
            TG.After(0, step)
            return
        end
        if hits == 0 then lines[#lines + 1] = "  " .. L["none found"] end
        lines[#lines + 1] = ""
        lines[#lines + 1] = L["Items shown as unknown: run the check again after a few seconds."]
        onDone(table.concat(lines, "\n"))
    end
    step()
end

local lootHandled = false

local function itemIdFromLink(link)
    if not usable(link) or type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function gameFishCount()
    if type(GetStatistic) ~= "function" then return nil end
    local v = call(GetStatistic, ns.STATISTIC_FISH)
    if not usable(v) or (type(v) ~= "string" and type(v) ~= "number") then return nil end
    local n = tonumber((tostring(v):gsub("%D", "")))
    if not n or n > 10000000 then return nil end
    return floor(n)
end

local function setCatches(st, n)
    local before = st.catches or 0
    if not n or n <= before then return end
    st.catches = n
    for _, rung in ipairs(ns.FISH_RUNGS) do
        if rung > before and rung <= n then ns.Append({ T.stat, ns.STAT_FISH, rung }) end
    end
end

local function syncFishFromGame()
    local n = gameFishCount()
    if n then setCatches(ns.State("fishing"), n) end
end

local function logFishingLoot()
    if not yes(call(IsFishingLoot)) then return end
    local st = ns.State("fishing")
    setCatches(st, (st.catches or 0) + 1)
    syncFishFromGame()
    local n = num(call(GetNumLootItems), 0)
    local instant = api("C_Item.GetItemInfoInstant") or GetItemInfoInstant
    for slot = 1, min(n, 10) do
        local id = itemIdFromLink(call(GetLootSlotLink, slot))
        if id then
            ns.LastFishingItem = id
            once(ns.MOMENT.catch, id)
            local quality = num(select(5, call(GetLootSlotInfo, slot)), 0)
            local classId = instant and num(select(6, call(instant, id)), 0) or 0
            if quality >= 2 or classId == 2 or classId == 4 then
                ns.Append({ T.fishing_loot, id, u8(quality), u8(classId) })
            end
        end
    end
end

ns.Collector("Fishing", {
    waitForBaseline = true,
    check = syncFishFromGame,
    events = {
        LOOT_READY = function()
            if lootHandled then return end
            lootHandled = true
            logFishingLoot()
            if next(rares) and type(GetLootSourceInfo) == "function" then
                local n = num(call(GetNumLootItems), 0)
                for slot = 1, min(n, 10) do
                    local sources = { call(GetLootSourceInfo, slot) }
                    for i = 1, #sources, 2 do
                        local guid = sources[i]
                        if usable(guid) and type(guid) == "string" and rares[guid] then logRareKill(guid, 2) end
                    end
                end
            end
        end,
        LOOT_CLOSED = function() lootHandled = false end,
    },
})

local YARD_TO_M = 0.9144
local TICK_S = 2
local ticker

local function onFoot()
    for _, fn in ipairs({ IsMounted, UnitOnTaxi, IsFlying, IsSwimming, UnitInVehicle, UnitIsDeadOrGhost }) do
        if type(fn) == "function" then
            local v = call(fn, "player")
            if not usable(v) or v then return false end
        end
    end
    return true
end

local function tick()
    if not ns.Mod.rec or ns.Mod.passive or not onFoot() then return end
    local raw = call(GetUnitSpeed, "player")
    local speed = usable(raw) and tonumber(raw) or 0
    if speed > 0 and speed <= 20 then
        local st = ns.State("distance")
        st.m = (st.m or 0) + speed * TICK_S * YARD_TO_M
        local step = floor(st.m / ns.DISTANCE_STEP_M)
        if step > (st.step or 0) then
            st.step = step
            ns.Append({ T.stat, ns.STAT_DISTANCE, step * ns.DISTANCE_STEP_M })
        end
    end
end

ns.Collector("Distance", {
    waitForBaseline = true,
    check = function()
        if ticker then return end
        ticker = ns.Mod:Ticker(TICK_S, tick)
    end,
})

local lastDownAt

local function bumpStat(stateKey, statId, rungs)
    local st = ns.State(stateKey)
    st.n = (st.n or 0) + 1
    for _, rung in ipairs(rungs) do
        if st.n == rung then ns.Append({ T.stat, statId, rung }) end
    end
end

local function isHearthstone(spellId)
    local id = num(spellId, nil)
    if not id then return false end
    if ns.HEARTHSTONE_SPELLS[id] then return true end
    local getName = api("C_Spell.GetSpellName")
    local name = getName and str(call(getName, id), nil) or str(call(GetSpellInfo, id), nil)
    return name ~= nil and ns.HEARTHSTONE_NAMES[name:lower()] == true
end

ns.Collector("Moments", {
    waitForBaseline = true,
    events = {
        PLAYER_DEAD = function() lastDownAt = now() end,
        ENCOUNTER_END = function(_, _, _, _, _, success)
            if usable(success) and success ~= 1 and success ~= true then lastDownAt = now() end
        end,
        UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellId)
            if unit ~= "player" or not isHearthstone(spellId) then return end
            bumpStat("hearth", ns.STAT_HEARTH, ns.HEARTH_RUNGS)
            local t = now()
            if lastDownAt and t - lastDownAt <= ns.MOMENT_WINDOW_S then
                ns.Append({ T.moment, ns.MOMENT_HEARTH_AFTER_DEATH, t - lastDownAt })
                lastDownAt = nil
            end
        end,
        SCREENSHOT_SUCCEEDED = function()
            local kill = ns.lastBossKill
            local t = now()
            if kill and not kill.shot and t - kill.at <= ns.MOMENT_WINDOW_S then
                kill.shot = true
                ns.Append({ T.moment, ns.MOMENT_BOSS_SCREENSHOT, kill.id })
            end
        end,
        NEW_TOY_ADDED = function() bumpStat("toys", ns.STAT_TOYS, ns.COLLECTION_RUNGS) end,
        NEW_PET_ADDED = function() bumpStat("pets", ns.STAT_PETS, ns.COLLECTION_RUNGS) end,
    },
})

local Snapshot = {}
ns.Snapshot = Snapshot
Snapshot.TIMEOUT = 15

function Snapshot.Collect()
    local snap = {
        level = ns.Level(),
        money = ns.Money(),
        pvp = ns.PvpRank() or 0,
        skills = ns.GetSkills(),
        factions = ns.GetFactions(true),
    }
    table.sort(snap.skills, function(a, b)
        if a.id ~= b.id then return a.id < b.id end
        return (a.name or "") < (b.name or "")
    end)
    table.sort(snap.factions, function(a, b) return a.id < b.id end)
    return snap
end

function Snapshot.SkillName(s)
    if s.id == 0 or (s.id == ns.SKILL_RIDING and s.name and s.name ~= ns.PROFESSIONS[ns.SKILL_RIDING]) then
        return Codec.clampUtf8(s.name or "", Codec.MAX_STRING)
    end
    return ""
end

function Snapshot.BuildEvent(reason, snap, played)
    local skills, reps = {}, {}
    for _, s in ipairs(snap.skills) do skills[#skills + 1] = { s.id, s.rank, s.max, Snapshot.SkillName(s) } end
    for _, f in ipairs(snap.factions) do
        if f.standing >= 5 then reps[#reps + 1] = { f.id, f.standing } end
    end
    return { T.snapshot, reason, u8(snap.level), snap.money, played or 0, u8(snap.pvp), skills, reps }
end

function Snapshot.Begin(reason)
    if Snapshot.pending then return end
    ns.BeginQueue()
    Snapshot.pending = { reason = reason, started = now() }
    if type(RequestTimePlayed) == "function" then
        ns.Mod:RegisterEvent("TIME_PLAYED_MSG", function(_, total)
            if Snapshot.pending then Snapshot.Finish(num(total, 0)) end
        end)
        call(RequestTimePlayed)
        TG.After(Snapshot.TIMEOUT, function() if Snapshot.pending then Snapshot.Finish(nil) end end)
    else
        TG.After(1, function() Snapshot.Finish(nil) end)
    end
end

function Snapshot.Finish(played)
    local p = Snapshot.pending
    if not p or not ns.Mod.rec then return end
    Snapshot.pending = nil
    local rec = ns.Mod.rec
    local ok, err = pcall(function()
        local snap = Snapshot.Collect()
        local first = { Snapshot.BuildEvent(p.reason, snap, played) }
        each("baseline", snap)
        for _, def in ipairs(collectors) do
            if type(def.snapshotEvents) == "function" then
                local okS, list = pcall(def.snapshotEvents, rec, snap)
                if okS then
                    for _, e in ipairs(list or {}) do first[#first + 1] = e end
                end
            end
        end
        ns.FlushQueue(first)
    end)
    if not ok then
        TG:Debug("GehHeim snapshot failed: %s", tostring(err))
        if rec.pending_queue then ns.FlushQueue({}) end
    end
    rec.needs_snapshot = nil
    rec.snapshot_at = now()
    ns.OnBaselineReady()
    TG:Print(L["Geh Heim: baseline recorded. Use the report link in the Geh Heim tab to redeem it."])
end
