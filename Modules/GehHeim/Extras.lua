local TG = TheGuild
local ns = TG.GH
if ns.off then return end
local L = ns.L
local Codec = ns.Codec
local T = Codec.T
local usable = TG.usable
local call, num, str, u8 = ns.Call, ns.Num, ns.Str, ns.U8
local max, min, floor = math.max, math.min, math.floor
local once = ns.RecordMoment

local function yes(v)
    return usable(v) and v and true or false
end

local function now()
    return TG.Now()
end

local function active()
    local mod = ns.Mod
    return mod.rec ~= nil and not mod.passive
end

local function bumpBy(statId, n)
    local st = ns.State("stats13")
    local before = st[statId] or 0
    local after = before + (n or 1)
    st[statId] = after
    for _, rung in ipairs(ns.BIG_RUNGS) do
        if rung > after then break end
        if rung > before then ns.Append({ T.stat, statId, rung }) end
    end
end
ns.BumpStat13 = bumpBy

local function setAbsolute(statId, value)
    local before = ns.State("stats13")[statId] or 0
    if value and value > before then bumpBy(statId, value - before) end
end

local WATCHED = setmetatable({ target = true, mouseover = true }, { __index = function(t, unit)
    local v = unit:find("^nameplate%d+$") ~= nil
    t[unit] = v
    return v
end })

local lastCombat = 0
local counted, countedN = {}, 0

local function checkDead(unit)
    if not yes(call(UnitIsDead, unit)) then return end
    local guid = str(call(UnitGUID, unit), nil)
    if not guid or counted[guid] then return end
    local npc = ns.NpcIdFromGUID(guid)
    if not npc then return end
    if yes(call(UnitIsTapDenied, unit)) then return end
    if not yes(call(UnitAffectingCombat, "player")) and now() - lastCombat > ns.KILL_COMBAT_WINDOW_S then return end
    if countedN > 500 then counted, countedN = {}, 0 end
    counted[guid] = true
    countedN = countedN + 1
    bumpBy(ns.STAT_KILLS, 1)
    local kind = ns.CREATURE_TYPES[str(call(UnitCreatureType, unit), ""):lower()]
    if kind then bumpBy(ns.STAT_KILLS_TYPE_BASE + kind, 1) end
    if ns.KILL_WATCH[npc] then once(ns.MOMENT.kill_watch, npc) end
end
ns.CheckDeadUnit = checkDead

local function lootRare()
    local n = min(num(call(GetNumLootItems), 0), 20)
    for slot = 1, n do
        local _, _, _, _, quality = call(GetLootSlotInfo, slot)
        quality = num(quality, 0)
        if quality >= 3 then
            local id = tonumber(str(call(GetLootSlotLink, slot), ""):match("item:(%d+)"))
            if id then once(ns.MOMENT.loot_rare, id, quality) end
        end
    end
end

local function taxi()
    local all = ns.Api("C_TaxiMap.GetAllTaxiNodes")
    if not all then return end
    local mapOf = ns.Api("C_TaxiMap.GetTaxiMapID")
    local map = (mapOf and num(call(mapOf), nil)) or ns.BestMap()
    if not map then return end
    local nodes = call(all, map)
    if type(nodes) ~= "table" or not usable(nodes) then return end
    for _, node in ipairs(nodes) do
        if type(node) == "table" and usable(node.state) and (node.state == 0 or node.state == 1) then
            local id = num(node.nodeID, nil)
            if id then once(ns.MOMENT.taxi, id) end
        end
    end
end

local function gossip()
    local npc = ns.NpcIdFromGUID(str(call(UnitGUID, "npc"), nil))
    if npc then once(ns.MOMENT.gossip, npc) end
end

local function honorKills()
    local hk = num(call(GetPVPLifetimeStats), nil)
    if hk and hk < 10000000 then setAbsolute(ns.STAT_HONOR_KILLS, hk) end
end

local bgDone

local function battlefield()
    local winner = call(GetBattlefieldWinner)
    if not usable(winner) or winner == nil then
        bgDone = nil
        return
    end
    if bgDone then return end
    bgDone = true
    local mine = ns.BG_FACTION[str(call(UnitFactionGroup, "player"), "")]
    if mine and num(winner, -1) == mine then bumpBy(ns.STAT_BG_WINS, 1) end
end

local jumpHooked = false

ns.Collector("Extras", {
    waitForBaseline = true,
    init = function()
        if jumpHooked or type(hooksecurefunc) ~= "function" or type(JumpOrAscendStart) ~= "function" then return end
        jumpHooked = true
        call(hooksecurefunc, "JumpOrAscendStart", function()
            if ns.Mod.ready and active() then bumpBy(ns.STAT_JUMPS, 1) end
        end)
    end,
    events = {
        PLAYER_REGEN_DISABLED = function() lastCombat = now() end,
        PLAYER_REGEN_ENABLED = function() lastCombat = now() end,
        UNIT_HEALTH = function(_, unit)
            local u = str(unit, nil)
            if u and WATCHED[u] then checkDead(u) end
        end,
        PLAYER_TARGET_CHANGED = function() checkDead("target") end,
        LOOT_READY = lootRare,
        TAXIMAP_OPENED = taxi,
        GOSSIP_SHOW = gossip,
        QUEST_GREETING = gossip,
        PLAYER_PVP_KILLS_CHANGED = honorKills,
        UPDATE_BATTLEFIELD_STATUS = battlefield,
    },
})

local MAX = Codec.MAX_VARINT
local run, roster, dead = nil, nil, {}
local ticking = false
local update

local GROUP_UNIT = setmetatable({ player = true }, { __index = function(t, unit)
    local v = unit:find("^party%d+$") ~= nil or unit:find("^raid%d+$") ~= nil
    t[unit] = v
    return v
end })

local function uint(v)
    return min(MAX, num(v, 0))
end

local function elapsed(at)
    return uint(at - run.enter)
end

local function instance()
    local name, kind, difficulty, _, _, _, _, id = call(GetInstanceInfo)
    return str(kind, ""), num(difficulty, 0), num(id, 0), str(name, "")
end

local function readUID(unit)
    local guid = str(call(UnitGUID, unit), "")
    return uint(tonumber(guid:match("^Creature%-0%-%d+%-%d+%-(%d+)%-%d+%-%x+$")))
end

local function nearUID()
    local uid = readUID("target")
    if uid > 0 then return uid end
    return readUID("mouseover")
end

local function visibleUID()
    local uid = nearUID()
    if uid > 0 then return uid end
    for i = 1, 40 do
        uid = readUID("nameplate" .. i)
        if uid > 0 then return uid end
    end
    return 0
end

local function sameSet(a, b)
    if not a then return true end
    for key in pairs(a) do
        if not b[key] then return false end
    end
    for key in pairs(b) do
        if not a[key] then return false end
    end
    return true
end

local function memberName(unit)
    local first, second = call(UnitName, unit)
    local name = str(first, ""):match("^[^%-]*") or ""
    second = str(second, "")
    if second ~= "" and not name:find(" ", 1, true) then name = name .. " " .. second end
    return Codec.clampUtf8(name, 64)
end

local function scan(changed)
    local size = ns.GroupSize()
    local raid = yes(call(IsInRaid))
    local current, present, guild = {}, {}, 0
    local t = now()
    local first, last, prefix = 0, min(size - 1, 4), "party"
    if raid then first, last, prefix = 1, min(size, 40), "raid" end
    for i = first, last do
        local unit = i == 0 and "player" or prefix .. i
        local guid = str(call(UnitGUID, unit), nil)
        local key = guid or unit
        if not current[key] then
            current[key] = true
            local level = u8(num(call(UnitLevel, unit), 0))
            if level > 0 then
                run.levelMax = max(run.levelMax, level)
                run.levelMin = run.levelMin == 0 and level or min(run.levelMin, level)
            end
            local member
            if yes(call(UnitIsInMyGuild, unit)) then
                guild = guild + 1
                local server, low
                if guid then server, low = guid:match("^Player%-(%d+)%-(%x+)$") end
                if server and low then
                    present[guid] = true
                    member = run.members[guid]
                    if not member then
                        local _, _, class = call(UnitClass, unit)
                        member = { server = uint(tonumber(server)), low = uint(tonumber(low, 16)), class = u8(num(class, 0)),
                            level = level, joined = elapsed(t), left = 0, deaths = 0, name = memberName(unit) }
                        run.members[guid] = member
                    end
                    if member.left > 0 then
                        member.dead = nil
                        dead[key] = nil
                    end
                    member.level = max(member.level, level)
                    member.left = 0
                end
            end
            local value = call(UnitIsDeadOrGhost, unit)
            if usable(value) and type(value) == "boolean" then
                local previous = dead[key]
                if previous == nil and member then previous = member.dead end
                if value and previous == false then
                    run.deaths = u8(run.deaths + 1)
                    if member then member.deaths = u8(member.deaths + 1) end
                end
                dead[key] = value
                if member then member.dead = value end
            end
        end
    end
    for guid, member in pairs(run.members) do
        if not present[guid] and member.left == 0 then member.left = elapsed(t) end
    end
    for key in pairs(dead) do
        if not current[key] then dead[key] = nil end
    end
    if changed and not sameSet(roster, current) then run.changes = u8(run.changes + 1) end
    if changed or not roster then roster = current end
    run.size = max(run.size, u8(size))
    return guild, size
end

local function clock(seconds)
    if seconds >= 3600 then return ("%d:%02d:%02d"):format(floor(seconds / 3600), floor(seconds / 60) % 60, seconds % 60) end
    return ("%02d:%02d"):format(floor(seconds / 60), seconds % 60)
end

local function finish(reason, at)
    if not run then return end
    local r = run
    local exit = elapsed(r.left or at)
    run, roster, dead = nil, nil, {}
    ns.Mod.rec.dungeon_run = nil
    if not r.valid or r.bossCount == 0 then return end
    local flags = (r.resumed and 1 or 0) + (r.uid > 0 and 2 or 0) + (r.allGuild and 4 or 0)
    ns.Append({ T.dungeon_run, r.enter, r.id, r.difficulty, r.kind, r.firstCombat or 0, r.lastBoss, exit, reason,
        u8(r.bossCount), r.wipes, r.deaths, r.size, u8(r.guildMin), r.levelMax, r.levelMin, r.changes, r.uid, flags }, at)
    local keys = {}
    for guid in pairs(r.members) do keys[#keys + 1] = guid end
    table.sort(keys)
    for _, guid in ipairs(keys) do
        local m = r.members[guid]
        ns.Append({ T.run_member, r.enter, m.server, m.low, m.class, m.level, m.joined, m.left, m.deaths, m.name }, at)
    end
    if ns.Mod.db.runChat then
        TG:Print(L["Dungeon run recorded: %s, %s to the last boss, %d bosses"], r.name, clock(r.lastBoss), r.bossCount)
    end
end

local function step(changed, seen)
    local t = now()
    local kind, difficulty, id, name = instance()
    local inside = (kind == "party" or kind == "raid") and id > 0
    local uid = inside and (seen or nearUID()) or 0
    if run then
        local deadline = run.enter + ns.RUN_MAX_SECONDS
        if run.left and run.left + ns.RUN_GRACE_SECONDS <= t and run.left + ns.RUN_GRACE_SECONDS <= deadline then
            finish(1, t)
        elseif t >= deadline then
            finish(3, t)
        end
    end
    if run and inside and (id ~= run.id or (uid > 0 and run.uid > 0 and uid ~= run.uid)) then finish(2, t) end
    if not inside then
        if run and not run.left then
            run.left = t
            run.lastSeen = t
        end
        return
    end
    if not run then
        run = { enter = t, lastSeen = t, id = id, difficulty = difficulty, kind = kind == "raid" and 2 or 1, name = name, uid = uid,
            members = {}, bosses = {}, bossCount = 0, lastBoss = 0, wipes = 0, deaths = 0, changes = 0, size = 0,
            levelMax = 0, levelMin = 0, valid = true, allGuild = true, guildMin = 255 }
        ns.Mod.rec.dungeon_run = run
    end
    run.left = nil
    scan(changed)
    run.lastSeen = t
    if run.uid == 0 then run.uid = uid end
end

local function tick()
    ticking = false
    if active() then update(false) end
end

function update(changed, seen)
    if not active() then return end
    step(changed, seen)
    if run and not ticking then
        ticking = true
        TG.After(1, tick)
    end
end

local function see(unit)
    if not run or run.left then return end
    local uid = readUID(unit)
    if uid == 0 then return end
    if run.uid == 0 then
        run.uid = uid
    elseif uid ~= run.uid then
        update(false, uid)
    end
end

local function rescan()
    if not run or run.left then return end
    scan(false)
    run.lastSeen = now()
end

local function appended(_, e)
    local t = e[2]
    if t ~= T.encounter_kill and t ~= T.encounter_wipe then return end
    update(false)
    if not run or run.left or e[1] < run.enter then return end
    if t == T.encounter_kill and e[6] == run.id then
        local guild, size = scan(false)
        run.valid = run.valid and (guild >= 3 or (size <= 5 and guild == size))
        run.allGuild = run.allGuild and guild == size
        run.guildMin = min(run.guildMin, guild)
        local key = e[3] ~= 0 and ("e:" .. e[3]) or ("n:" .. (e[4] or 0))
        if not run.bosses[key] then
            run.bosses[key] = true
            run.bossCount = run.bossCount + 1
        end
        run.lastBoss = elapsed(e[1])
    elseif t == T.encounter_wipe and e[5] == run.id then
        run.wipes = u8(run.wipes + 1)
    end
end

local function valid(r)
    return type(r) == "table" and type(r.members) == "table" and type(r.bosses) == "table"
        and type(r.enter) == "number" and type(r.lastSeen) == "number" and type(r.id) == "number" and type(r.uid) == "number"
end

local listening = false

ns.Collector("Runs", {
    waitForBaseline = false,
    init = function(rec)
        run, roster, dead = nil, nil, {}
        local saved = rec.dungeon_run
        if valid(saved) then
            run = saved
            local kind, _, id = instance()
            local uid = visibleUID()
            local t = now()
            if (kind == "party" or kind == "raid") and id == run.id and t >= run.lastSeen and t - run.lastSeen < ns.RUN_GRACE_SECONDS
                and (uid == 0 or run.uid == 0 or uid == run.uid) then
                run.resumed = true
            else
                finish(4, run.lastSeen)
            end
        else
            rec.dungeon_run = nil
        end
        if not listening then
            listening = true
            ns.OnAppend(appended)
        end
        update(false)
    end,
    check = function() update(false) end,
    events = {
        PLAYER_ENTERING_WORLD = function() update(false) end,
        ZONE_CHANGED_NEW_AREA = function() update(false) end,
        GROUP_ROSTER_UPDATE = function() update(true) end,
        PLAYER_REGEN_DISABLED = function()
            update(false)
            if run and not run.left and run.firstCombat == nil then run.firstCombat = elapsed(now()) end
        end,
        UNIT_FLAGS = function(_, unit)
            if not run or run.left then return end
            local u = str(unit, nil)
            if u and GROUP_UNIT[u] then ns.Debounce("run13", 0.3, rescan) end
        end,
        PLAYER_DEAD = function() update(false) end,
        PLAYER_ALIVE = function() update(false) end,
        PLAYER_UNGHOST = function() update(false) end,
        PLAYER_TARGET_CHANGED = function() see("target") end,
        UPDATE_MOUSEOVER_UNIT = function() see("mouseover") end,
        NAME_PLATE_UNIT_ADDED = function(_, unit)
            local u = str(unit, nil)
            if u and u:find("^nameplate%d+$") then see(u) end
        end,
    },
})

function ns.CurrentRun()
    return run
end
