local _, TG = ...

-- Replicated guild data. Every client keeps a copy, changes travel over
-- the guild addon channel and the highest revision wins. Nothing is
-- written into the guild itself.

local Store = {}
TG.Store = Store

local policies = {}
local SYNC_INTERVAL = 1200
local BATCH_SIZE = 40
local MAX_RESPONDERS = 3
local lastSyncRequest = 0

function Store:DefinePolicy(ns, policy)
    policies[ns] = policy
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

function Store:Set(ns, key, value)
    local d = data()
    if not d then return false end
    if not canWrite(ns, key, TG.MyName()) then return false end
    d[ns] = d[ns] or {}
    local existing = d[ns][key]
    local item = { v = value, r = (existing and existing.r or 0) + 1, t = TG.Now(), a = TG.MyName() }
    d[ns][key] = item
    TG.Comm:Send("ST", { ns = ns, k = key, v = value, r = item.r, t = item.t, a = item.a }, "ALERT")
    TG:Fire("STORE_CHANGED", ns, key, value)
    return true
end

-- Writes many keys of one namespace and sends them as a few batch messages
-- instead of one message per key.
function Store:SetBatch(ns, values)
    local d = data()
    if not d then return 0 end
    d[ns] = d[ns] or {}
    local me = TG.MyName()
    local batch = {}
    for key, value in pairs(values) do
        if canWrite(ns, key, me) then
            local existing = d[ns][key]
            local item = { v = value, r = (existing and existing.r or 0) + 1, t = TG.Now(), a = me }
            d[ns][key] = item
            batch[#batch + 1] = { ns = ns, k = key, v = value, r = item.r, t = item.t, a = me }
            TG:Fire("STORE_CHANGED", ns, key, value)
        end
    end
    for i = 1, #batch, BATCH_SIZE do
        local slice = {}
        for j = i, math.min(i + BATCH_SIZE - 1, #batch) do slice[#slice + 1] = batch[j] end
        TG.Comm:Send("SB", slice, "BULK")
    end
    return #batch
end

function Store:Delete(ns, key)
    return self:Set(ns, key, nil)
end

local function apply(msg, sender, relayed)
    if type(msg) ~= "table" or type(msg.ns) ~= "string" or msg.k == nil or type(msg.r) ~= "number" then return false end
    local author = TG.StripRealm(msg.a)
    if not author then return false end
    if not relayed and author ~= sender then return false end
    if not canWrite(msg.ns, msg.k, author) then return false end
    local d = data()
    if not d then return false end
    d[msg.ns] = d[msg.ns] or {}
    local item = { v = msg.v, r = msg.r, t = tonumber(msg.t) or 0, a = author }
    if not newer(item, d[msg.ns][msg.k]) then return false end
    d[msg.ns][msg.k] = item
    TG:Fire("STORE_CHANGED", msg.ns, msg.k, msg.v)
    return true
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

-- Only the first few clients by name answer a sync request, so a login in a
-- guild with a hundred users online does not trigger a hundred answers.
local function responderSlot(requester)
    local names = {}
    for name in pairs(TG.Comm:Peers()) do
        if name ~= requester then names[#names + 1] = name end
    end
    names[#names + 1] = TG.MyName()
    table.sort(names)
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
    local d = data()
    if not d then return end
    local batch = {}
    for ns, items in pairs(d) do
        for key, item in pairs(items) do
            local r = theirs[ns] and theirs[ns][key]
            if not r or r < item.r then
                batch[#batch + 1] = { ns = ns, k = key, v = item.v, r = item.r, t = item.t, a = item.a }
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
    TG.After(15, function() Store:RequestSync(true) end)
end)

TG.Ticker(SYNC_INTERVAL, function() Store:RequestSync() end)

Store:DefinePolicy("cfg", "gm")
Store:DefinePolicy("role", "self")
Store:DefinePolicy("alt", "self")
Store:DefinePolicy("pin", "any")
Store:DefinePolicy("death", "any")
