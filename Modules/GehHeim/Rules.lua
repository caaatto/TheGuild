local TG = TheGuild
local ns = TG.GH
if ns.off then return end
local L = ns.L
local Codec = ns.Codec
local T = Codec.T

local Rules = {}
ns.Rules = Rules

Rules.rules = {}
Rules.byCode = {}
Rules.byEvent = {}
Rules.state = {}
Rules.snapshotTs = {}
Rules.ready = false

Rules.FIELDS = {
    [1] = { "level", "weather", "ui_map_id", "armor_pieces", "group_size" },
    [2] = { "skill_id", "rank", "max_rank", "name" },
    [3] = { "copper" },
    [4] = { "ui_map_id" },
    [5] = { "area_id" },
    [6] = { "encounter_id", "npc_id", "difficulty_id", "instance_id", "group_size", "src", "duration_s", "guild_members", "weather", "tabard_item" },
    [7] = { "quest_id" },
    [8] = { "faction_id", "standing" },
    [9] = { "ui_map_id", "level", "killer_kind", "killer_id", "env_type", "one_shot", "weather", "instance_id" },
    [10] = { "rank" },
    [11] = { "spell_id" },
    [13] = { "encounter_id", "difficulty_id", "instance_id", "group_size", "duration_s" },
    [14] = { "duration_s", "damage", "npc_id", "classification", "killed", "reasons", "guild_members", "weather" },
    [15] = { "item_id", "quality", "item_class" },
    [16] = { "stat_id", "value" },
    [17] = { "npc_id", "classification", "how" },
    [18] = { "moment_id", "value" },
}

local ALIAS_EVENTS = { "zone_visit", "area_discovered", "encounter_kill" }

local head = { faction = 0, classId = 0 }

local function withHead(data)
    data["@faction"] = head.faction
    data["@class_id"] = head.classId
    return data
end

function Rules.Fields(e)
    local t = e[2]
    local names = Rules.FIELDS[t]
    if not names then return nil end
    local base = Codec.SCHEMA[t] and #Codec.SCHEMA[t] or #names
    local data = {}
    for i, name in ipairs(names) do
        local v = e[i + 2]
        if v == nil then
            if t == 1 and i > base then break end
            v = (name == "name") and "" or 0
        end
        data[name] = v
    end
    return data
end

function Rules.Facts(e)
    local t = e[2]
    if t == T.snapshot then
        local out = {
            { "level", withHead({ level = e[4] or 0 }) },
            { "money_peak", withHead({ copper = e[5] or 0 }) },
            { "pvp_rank", withHead({ rank = e[7] or 0 }) },
        }
        for _, s in ipairs(type(e[8]) == "table" and e[8] or {}) do
            out[#out + 1] = { "skill", withHead({ skill_id = s[1] or 0, rank = s[2] or 0, max_rank = s[3] or 0, name = s[4] or "" }) }
        end
        for _, r in ipairs(type(e[9]) == "table" and e[9] or {}) do
            out[#out + 1] = { "reputation_standing", withHead({ faction_id = r[1] or 0, standing = r[2] or 0 }) }
        end
        return out
    end
    local data = Rules.Fields(e)
    local name = Codec.NAME[t]
    if not data or not name then return {} end
    return { { name, withHead(data) } }
end

function Rules.Match(data, m, skipEvent)
    for k, want in pairs(m) do
        if not (skipEvent and k == "event") then
            local have = data[k]
            if have == nil then return false end
            if type(want) == "table" then
                local found = false
                for _, item in ipairs(want["in"] or {}) do
                    if item == have then
                        found = true
                        break
                    end
                end
                if not found then return false end
            elseif have ~= want then
                return false
            end
        end
    end
    return true
end

local function factKey(event, ts, data)
    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = { event, tostring(ts) }
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(data[k]) end
    return table.concat(parts, "|")
end

local function addIndex(event, rule)
    local list = Rules.byEvent[event]
    if not list then
        list = {}
        Rules.byEvent[event] = list
    end
    for _, r in ipairs(list) do
        if r == rule then return end
    end
    list[#list + 1] = rule
end

function Rules.Compile(catalog)
    Rules.rules, Rules.byCode, Rules.byEvent = {}, {}, {}
    for _, entry in ipairs(catalog and catalog.entries or {}) do
        local p = entry.params or {}
        local rule = { entry = entry, code = entry.code, kind = entry.rule, p = p, event = p.event or entry.event }
        if rule.kind == "count" then
            rule.required = tonumber(p.n) or 1
        elseif rule.kind == "set_complete" then
            local members = p.members or {}
            rule.required = p.need == "all" and #members or (tonumber(p.need) or #members)
        elseif rule.kind == "threshold" then
            rule.required = tonumber(p.gte) or 0
        else
            rule.required = 1
        end
        if rule.code and rule.event and (rule.kind == "threshold" or rule.kind == "single_event" or rule.kind == "count" or rule.kind == "set_complete") then
            Rules.rules[#Rules.rules + 1] = rule
            Rules.byCode[rule.code] = rule
            addIndex(rule.event, rule)
            if rule.kind == "set_complete" then
                for _, ev in ipairs(ALIAS_EVENTS) do addIndex(ev, rule) end
            end
        end
    end
end

local function stateOf(code)
    local s = Rules.state[code]
    if not s then
        s = { count = 0 }
        Rules.state[code] = s
    end
    return s
end

local function apply(rule, event, data, ts)
    local p = rule.p
    if p.where and not Rules.Match(data, p.where) then return false end
    local s = stateOf(rule.code)
    local kind = rule.kind
    if kind == "set_complete" then
        s.set = s.set or {}
        for _, member in ipairs(p.members or {}) do
            if member.key and not s.set[member.key] then
                for _, alias in ipairs(member.match or {}) do
                    if (alias.event or rule.event) == event and Rules.Match(data, alias, true) then
                        s.set[member.key] = true
                        s.count = s.count + 1
                        break
                    end
                end
            end
        end
        return s.count >= rule.required
    end
    if event ~= rule.event then return false end
    if kind == "threshold" then
        local v = tonumber(data[p.field]) or -1
        if v > (s.best or -1) then s.best = v end
        return v >= rule.required
    elseif kind == "single_event" then
        for _, m in ipairs(p.match or {}) do
            if Rules.Match(data, m) then return true end
        end
        return false
    end
    local key
    if p.distinct then
        key = tostring(data[p.distinct] == nil and "" or data[p.distinct])
    else
        key = factKey(event, ts, data)
    end
    s.set = s.set or {}
    if not s.set[key] then
        s.set[key] = true
        s.count = s.count + 1
    end
    return s.count >= rule.required
end

function Rules.Notify(rule)
    local mode = ns.Mod.db.notify
    if mode == "off" then return end
    local e = rule.entry
    if mode == "chat" or mode == "both" then
        TG:Print("%s %s (+%d %s)", TG.gold .. (e.hidden and L["Hidden achievement discovered:"] or L["Achievement earned:"]) .. "|r",
            tostring(e.title or e.code), tonumber(e.points) or 0, L["points"])
    end
    if mode == "screen" or mode == "both" then ns.Alert.Show(e) end
    ns.Alert.Sound()
end

function Rules.Process(e, silent)
    if type(e) ~= "table" then return end
    local t, ts = e[2], e[1] or 0
    if t == T.snapshot then
        Rules.snapshotTs[ts] = true
        silent = true
    elseif t == T.area_discovered and Rules.snapshotTs[ts] then
        silent = true
    end
    local rec = ns.Mod.rec
    local known = rec and rec.known or {}
    local any = false
    for _, fact in ipairs(Rules.Facts(e)) do
        local event, data = fact[1], fact[2]
        for _, rule in ipairs(Rules.byEvent[event] or {}) do
            local s = stateOf(rule.code)
            if not s.done and apply(rule, event, data, ts) then
                s.done = ts
                s.set = nil
                any = true
                if not known[rule.code] then
                    known[rule.code] = ts
                    if not silent then TG.SafeCall(Rules.Notify, rule) end
                end
            end
        end
    end
    if any then TG:Fire("GEHHEIM_ACHIEVEMENTS") end
end

local hooked = false

function Rules.Init(rec)
    local _, _, classId = UnitClass("player")
    head.faction = ns.FACTION[TG.plain(UnitFactionGroup("player"), "")] or 0
    head.classId = math.min(255, tonumber(TG.plain(classId, 0)) or 0)
    Rules.Compile(ns.Catalog)
    Rules.state, Rules.snapshotTs = {}, {}
    for seq = 1, rec.seq or 0 do
        local e = rec.events[seq]
        if e then Rules.Process(e, true) end
    end
    Rules.ready = true
    if not hooked then
        hooked = true
        ns.OnAppend(function(_, e) Rules.Process(e, false) end)
    end
    TG:Fire("GEHHEIM_ACHIEVEMENTS")
end

function Rules.Status()
    local out = {}
    for _, rule in ipairs(Rules.rules) do
        local s = Rules.state[rule.code] or { count = 0 }
        local progress
        if rule.kind == "threshold" then
            progress = s.best and s.best >= 0 and s.best or nil
        elseif rule.kind == "count" or rule.kind == "set_complete" then
            progress = s.count
        end
        if not (rule.entry and rule.entry.hidden) or s.done then
            out[#out + 1] = { rule = rule, entry = rule.entry, done = s.done, progress = progress, required = rule.required }
        end
    end
    return out
end

function Rules.HiddenOpen()
    local n = 0
    for _, rule in ipairs(Rules.rules) do
        local s = Rules.state[rule.code]
        if rule.entry and rule.entry.hidden and not (s and s.done) then n = n + 1 end
    end
    return n
end

function Rules.Summary()
    local done, total, points, earned = 0, 0, 0, 0
    for _, rule in ipairs(Rules.rules) do
        local s = Rules.state[rule.code]
        local p = tonumber(rule.entry.points) or 0
        total = total + 1
        points = points + p
        if s and s.done then
            done = done + 1
            earned = earned + p
        end
    end
    return done, total, earned, points
end

function Rules.Test()
    local entry = { code = "test", title = L["Sample achievement"], description = L["Only a test of the toast and the sound."], points = 10, pioneer = 15 }
    TG:Print("%s %s (+%d %s)", TG.gold .. L["Achievement earned:"] .. "|r", entry.title, entry.points, L["points"])
    ns.Alert.Show(entry)
    ns.Alert.Sound()
end
