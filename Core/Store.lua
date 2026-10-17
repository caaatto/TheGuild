local _, TG = ...
local L = TG.L

local Store = {}
TG.Store = Store

local LibDeflate = LibStub("LibDeflate")

local policies = {}
local SYNC_INTERVAL = 1200
local BATCH_SIZE = 15
local MAX_RESPONDERS = 3
local MAX_REV_JUMP = 10000
local MAX_PENDING = 400
local MAX_PENDING_AUTHOR = 60
local PENDING_TTL = 900
local MAX_VALUE = 8192
local MAX_AUTHOR_ITEMS = 300
local MAX_OFFICER_ITEMS = 20000
local TOMBSTONE_TTL = 45 * 86400
local FUTURE_SLACK = 600
local ANSWER_COOLDOWN = 300
local retention = {}
local answered = {}
local lastSyncRequest = 0
local pending = {}
local pendingCount = 0

Store.stats = { verified = 0, rejected = 0, held = 0, unsigned = 0 }

function Store:DefinePolicy(ns, policy, keep)
    policies[ns] = policy
    retention[ns] = keep
end

function Store:Retention(ns)
    return retention[ns]
end

local function data()
    local g = TG:GuildDB()
    if not g then return nil end
    g.store = g.store or {}
    return g.store
end

local function canWrite(ns, key, author)
    local policy = policies[ns] or "officer"
    local roster = TG.Roster
    if policy == "any" then return roster:Get(author) ~= nil or TG.IsMe(author) end
    if policy == "gm" then
        if TG.IsMe(author) then return roster:AmGuildMaster() end
        return roster:IsGuildMaster(author)
    end
    if policy == "officer" then
        if TG.IsMe(author) then return roster:AmOfficer() end
        return roster:IsOfficer(author)
    end
    if policy == "own" then
        if type(key) == "string" and key:sub(1, #author + 1) == author .. "#" then return true end
        if TG.IsMe(author) then return roster:AmOfficer() end
        return roster:IsOfficer(author)
    end
    if policy == "self" then
        if TG.StripRealm(key) == author then return true end
        if TG.IsMe(author) then return roster:AmOfficer() end
        return roster:IsOfficer(author)
    end
    return false
end

Store.CanWrite = function(_, ns, key)
    return canWrite(ns, key, TG.MyName())
end

local function newer(item, existing)
    if not existing then return true end
    if item.r ~= existing.r then return item.r > existing.r end
    if (item.t or 0) ~= (existing.t or 0) then return (item.t or 0) > (existing.t or 0) end
    return tostring(item.a) < tostring(existing.a)
end

local function message(ns, key, r, t, v)
    return ns .. "\0" .. TG.Canon(key) .. "\0" .. TG.Canon(r) .. "\0" .. TG.Canon(t) .. "\0" .. TG.Canon(v)
end
Store.Message = message

local function decodeSignature(s)
    if type(s) ~= "string" or s == "" then return nil end
    local raw = LibDeflate:DecodeForPrint(s)
    if raw and #raw == 64 then return raw end
    return nil
end

local function payload(ns, key, item)
    return { ns = ns, k = key, v = item.o or item.v, r = item.r, t = item.t, a = item.a, s = item.s }
end

function Store:Get(ns, key)
    local d = data()
    local item = d and d[ns] and d[ns][key]
    return item and item.v
end

function Store:Item(ns, key)
    local d = data()
    return d and d[ns] and d[ns][key]
end

function Store:Items(ns)
    local d = data()
    local out = {}
    for key, item in pairs(d and d[ns] or {}) do
        if item.v ~= nil then out[key] = item end
    end
    return out
end

local function sign(ns, key, item, cb)
    TG.Crypto.Sign(message(ns, key, item.r, item.t, item.v), function(sig)
        item.s = LibDeflate:EncodeForPrint(sig)
        cb()
    end)
end

function Store:Set(ns, key, value)
    local d = data()
    if not d then return false end
    if not canWrite(ns, key, TG.MyName()) then return false end
    d[ns] = d[ns] or {}
    local existing = d[ns][key]
    local item = { v = value, r = (existing and existing.r or 0) + 1, t = TG.Now(), a = TG.MyName() }
    d[ns][key] = item
    TG:Fire("STORE_CHANGED", ns, key, value)
    sign(ns, key, item, function()
        if d[ns][key] == item then TG.Comm:Send("ST", payload(ns, key, item), "ALERT") end
    end)
    return true
end

local function sendBatch(batch, prio)
    for i = 1, #batch, BATCH_SIZE do
        local slice = {}
        for j = i, math.min(i + BATCH_SIZE - 1, #batch) do slice[#slice + 1] = batch[j] end
        TG.Comm:Send("SB", slice, prio or "BULK")
    end
end

local function signAll(entries, d)
    local batch, outstanding = {}, #entries
    if outstanding == 0 then return end
    for _, e in ipairs(entries) do
        sign(e.ns, e.key, e.item, function()
            if d[e.ns][e.key] == e.item then batch[#batch + 1] = payload(e.ns, e.key, e.item) end
            outstanding = outstanding - 1
            if outstanding == 0 then sendBatch(batch) end
        end)
    end
end

function Store:SetBatch(ns, values)
    local d = data()
    if not d then return 0 end
    d[ns] = d[ns] or {}
    local me = TG.MyName()
    local entries = {}
    for key, value in pairs(values) do
        if canWrite(ns, key, me) then
            local existing = d[ns][key]
            local item = { v = value, r = (existing and existing.r or 0) + 1, t = TG.Now(), a = me }
            d[ns][key] = item
            entries[#entries + 1] = { ns = ns, key = key, item = item }
            TG:Fire("STORE_CHANGED", ns, key, value)
        end
    end
    signAll(entries, d)
    return #entries
end

function Store:Seed(ns, key, value, author, t)
    local d = data()
    if not d then return end
    d[ns] = d[ns] or {}
    d[ns][key] = { v = value, r = 1, t = t or TG.Now(), a = author or TG.MyName() }
end

function Store:Delete(ns, key)
    return self:Set(ns, key, nil)
end

function Store:ResignOwn()
    local d = data()
    local me = TG.MyName()
    if not d or not me or not TG.Crypto.HasKey() then return 0 end
    local entries = {}
    for ns, items in pairs(d) do
        for key, item in pairs(items) do
            if item.a == me and item.s == nil then
                item.t = TG.Now()
                entries[#entries + 1] = { ns = ns, key = key, item = item }
            end
        end
    end
    signAll(entries, d)
    return #entries
end

local function expired(ns, t, now)
    local keep = retention[ns]
    return keep ~= nil and (tonumber(t) or 0) < now - keep
end

local function authorCount(d, ns, author)
    local n = 0
    for _, item in pairs(d[ns] or {}) do
        if item.a == author and item.v ~= nil then n = n + 1 end
    end
    return n
end

function Store:Compact()
    local d = data()
    if not d then return 0 end
    local now = TG.Now()
    local removed = 0
    for ns, items in pairs(d) do
        for key, item in pairs(items) do
            if (item.v == nil and (item.t or 0) < now - TOMBSTONE_TTL) or (item.v ~= nil and expired(ns, item.t, now)) then
                items[key] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end

local function validRevision(r, existing)
    if type(r) ~= "number" or r ~= r or r < 1 or r ~= math.floor(r) then return false end
    return r <= (existing and existing.r or 0) + MAX_REV_JUMP
end

local function settle(entry, ok)
    local d = data()
    if not d then return end
    local ns, key, item = entry.ns, entry.key, entry.item
    d[ns] = d[ns] or {}
    local current = d[ns][key]
    if ok then
        Store.stats.verified = Store.stats.verified + 1
        if entry.provisional then
            if current == item then
                item.u = nil
                TG:Fire("STORE_VERIFIED", ns, key, item.v)
            end
        elseif newer(item, current) then
            d[ns][key] = item
            TG:Fire("STORE_CHANGED", ns, key, item.v)
            TG:Fire("STORE_VERIFIED", ns, key, item.v)
        end
        return
    end
    Store.stats.rejected = Store.stats.rejected + 1
    if entry.provisional and current == item then
        d[ns][key] = nil
        TG:Fire("STORE_CHANGED", ns, key, nil)
        TG:Print(L["Removed an entry by %s with a bad signature, relayed by %s."], TG.ShortName(item.a), TG.ShortName(entry.sender))
    else
        TG:Debug("rejected signature on %s/%s by %s via %s", ns, tostring(key), item.a, entry.sender)
    end
end

local function hold(entry)
    local author = entry.item.a
    local list = pending[author]
    if not list then
        list = {}
        pending[author] = list
    end
    if pendingCount >= MAX_PENDING or #list >= MAX_PENDING_AUTHOR then return end
    list[#list + 1] = entry
    pendingCount = pendingCount + 1
    Store.stats.held = Store.stats.held + 1
end

local function check(entry)
    local item = entry.item
    local keys = TG.Keys and TG.Keys:Trusted(item.a) or {}
    if #keys == 0 then
        if not entry.provisional then hold(entry) end
        return
    end
    local raw = decodeSignature(item.s)
    if not raw then
        settle(entry, false)
        return
    end
    local msg = message(entry.ns, entry.key, item.r, item.t, item.o or item.v)
    local i = 0
    local function try()
        i = i + 1
        if not keys[i] then
            settle(entry, false)
            return
        end
        TG.Crypto.Verify(keys[i], msg, raw, function(ok)
            if ok then settle(entry, true) else try() end
        end)
    end
    try()
end

local function apply(msg, sender, relayed)
    if type(msg) ~= "table" or type(msg.ns) ~= "string" or msg.k == nil then return false end
    local policy = policies[msg.ns]
    if policy == nil then return false end
    local author = TG.StripRealm(msg.a)
    if not author then return false end
    if not canWrite(msg.ns, msg.k, author) then return false end
    local d = data()
    if not d then return false end
    d[msg.ns] = d[msg.ns] or {}
    local existing = d[msg.ns][msg.k]
    if not validRevision(msg.r, existing) then return false end
    local now = TG.Now()
    local t = tonumber(msg.t) or 0
    if t > now + FUTURE_SLACK then return false end
    if msg.v ~= nil and expired(msg.ns, t, now) then return false end
    if msg.v ~= nil and #TG.Canon(msg.v) > MAX_VALUE then return false end
    if msg.v ~= nil and not existing then
        local limit = (policy == "officer" or policy == "gm") and MAX_OFFICER_ITEMS or MAX_AUTHOR_ITEMS
        if authorCount(d, msg.ns, author) >= limit then return false end
    end
    local item = { v = TG.CleanValue(msg.v), r = msg.r, t = t, a = author }
    if type(msg.s) == "string" then item.s = msg.s end
    if TG.Canon(item.v) ~= TG.Canon(msg.v) then item.o = msg.v end
    if not newer(item, existing) then return false end
    if author == sender then
        d[msg.ns][msg.k] = item
        TG:Fire("STORE_CHANGED", msg.ns, msg.k, item.v)
        return true
    end
    if not relayed then return false end
    if not decodeSignature(item.s) then
        Store.stats.unsigned = Store.stats.unsigned + 1
        return false
    end
    local entry = { ns = msg.ns, key = msg.k, item = item, sender = sender, at = GetTime() }
    if policy ~= "gm" and TG.Roster:IsOfficer(sender) then
        entry.provisional = true
        item.u = true
        d[msg.ns][msg.k] = item
        TG:Fire("STORE_CHANGED", msg.ns, msg.k, item.v)
    end
    check(entry)
    return entry.provisional == true
end

function Store:Retry(author)
    local list = pending[author]
    if list then
        pending[author] = nil
        pendingCount = pendingCount - #list
        for _, entry in ipairs(list) do check(entry) end
    end
    local d = data()
    if not d then return end
    for ns, items in pairs(d) do
        for key, item in pairs(items) do
            if item.u and item.a == author then
                check({ ns = ns, key = key, item = item, sender = "?", provisional = true, at = GetTime() })
            end
        end
    end
end

function Store:PendingCount()
    return pendingCount
end

local function digest()
    local out = {}
    for ns, items in pairs(data() or {}) do
        out[ns] = {}
        for key, item in pairs(items) do out[ns][key] = item.r end
    end
    return out
end

function Store:RequestSync(force)
    if not IsInGuild() then return end
    if not force and GetTime() - lastSyncRequest < 60 then return end
    lastSyncRequest = GetTime()
    TG.Comm:Send("SQ", digest(), "BULK")
end

local function responderSlot(requester)
    local names = {}
    for name in pairs(TG.Comm:Peers()) do
        if name ~= requester then names[#names + 1] = name end
    end
    names[#names + 1] = TG.MyName()
    table.sort(names, function(a, b)
        local oa, ob = TG.Roster:IsOfficer(a) == true, TG.Roster:IsOfficer(b) == true
        if oa ~= ob then return oa end
        return a < b
    end)
    for i, n in ipairs(names) do
        if n == TG.MyName() then return i end
    end
    return 1
end

TG.Comm:Register("ST", function(sender, msg) apply(msg, sender) end)

TG.Comm:Register("SB", function(sender, msg)
    if type(msg) ~= "table" then return end
    for _, item in ipairs(msg) do apply(item, sender, true) end
end)

TG.Comm:Register("SQ", function(sender, theirs)
    if type(theirs) ~= "table" then return end
    if answered[sender] and GetTime() - answered[sender] < ANSWER_COOLDOWN then return end
    answered[sender] = GetTime()
    local d = data()
    if not d then return end
    local batch = {}
    for ns, items in pairs(d) do
        for key, item in pairs(items) do
            local r = theirs[ns] and theirs[ns][key]
            if item.s and not item.u and (not r or r < item.r) then
                batch[#batch + 1] = payload(ns, key, item)
            end
        end
    end
    if #batch == 0 then return end
    local slot = responderSlot(sender)
    if slot > MAX_RESPONDERS then return end
    TG.After((slot - 1) * 1.5, function()
        if not (TG.Roster:Get(sender) and TG.Roster:Get(sender).online or TG.Comm:Peers()[sender]) then return end
        for i = 1, #batch, BATCH_SIZE do
            local slice = {}
            for j = i, math.min(i + BATCH_SIZE - 1, #batch) do slice[#slice + 1] = batch[j] end
            TG.Comm:Whisper(sender, "SB", slice, "BULK")
        end
    end)
end)

TG:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, initial)
    if initial then TG.After(20, function() Store:RequestSync(true) end) end
end)

TG:On("GUILD_CHANGED", function()
    wipe(pending)
    pendingCount = 0
    TG.After(15, function() Store:RequestSync(true) end)
end)

TG.Ticker(SYNC_INTERVAL, function() Store:RequestSync() end)

TG:On("READY", function() TG.After(60, function() Store:Compact() end) end)
TG.Ticker(6 * 3600, function() Store:Compact() end)

TG.Ticker(60, function()
    local now = GetTime()
    for author, list in pairs(pending) do
        for i = #list, 1, -1 do
            if now - list[i].at > PENDING_TTL then
                table.remove(list, i)
                pendingCount = pendingCount - 1
            end
        end
        if #list == 0 then pending[author] = nil end
    end
end)

Store:DefinePolicy("cfg", "gm")
Store:DefinePolicy("role", "self")
Store:DefinePolicy("alt", "self")
Store:DefinePolicy("pin", "any")
Store:DefinePolicy("death", "any", 14 * 86400)
