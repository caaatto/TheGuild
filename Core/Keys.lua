local _, TG = ...
local L = TG.L
local Crypto = TG.Crypto

local Keys = {}
TG.Keys = Keys

local NS_CERT = "cert"
TG.Store:DefinePolicy(NS_CERT, "officer", nil, function(v)
    return type(v) == "table" and type(v.n) == "string" and type(v.p) == "string" and #v.p == 64 and v.p:find("[^0-9a-f]") == nil
end)

local function trustTable()
    local g = TG:GuildDB()
    if not g then return nil end
    g.trust = g.trust or {}
    return g.trust
end

function Keys:Trusted(name)
    local t = trustTable()
    local entry = t and t[name]
    local out = {}
    if entry then
        for hex in pairs(entry) do
            local raw = Crypto.Unhex(hex)
            if raw and #raw == 32 then out[#out + 1] = raw end
        end
    end
    return out
end

function Keys:IsTrusted(name, hex)
    local t = trustTable()
    return t ~= nil and t[name] ~= nil and t[name][hex] ~= nil
end

function Keys:Certify(name, hex)
    if TG.IsMe(name) or not TG.InGuild() or not TG.Roster:AmOfficer() then return false end
    local key = name .. "#" .. hex:sub(1, 16)
    local existing = TG.Store:Get(NS_CERT, key)
    if type(existing) == "table" and existing.p == hex then return false end
    local issued = 0
    for _, item in pairs(TG.Store:Items(NS_CERT)) do
        if type(item.v) == "table" and item.v.n == name then issued = issued + 1 end
    end
    if issued >= 3 then return false end
    return TG.Store:Set(NS_CERT, key, { n = name, p = hex })
end

function Keys:Learn(name, hex, source)
    if type(name) ~= "string" or type(hex) ~= "string" or #hex ~= 64 or not Crypto.Unhex(hex) then return false end
    local t = trustTable()
    if not t then return false end
    t[name] = t[name] or {}
    local fresh = t[name][hex] == nil
    if fresh then
        local count, oldest, oldestAt = 0, nil, nil
        for k, entry in pairs(t[name]) do
            count = count + 1
            local weight = (entry.t or 0) + (entry.by == "direct" and 1e12 or 0)
            if not oldestAt or weight < oldestAt then oldest, oldestAt = k, weight end
        end
        if count >= 3 and oldest then t[name][oldest] = nil end
        t[name][hex] = { by = source, t = TG.Now() }
        TG:Fire("KEY_TRUSTED", name, hex, source)
        TG.Store:Retry(name)
    end
    if source == "direct" then self:Certify(name, hex) end
    return fresh
end

local function onCert(ns, key)
    if ns ~= NS_CERT then return end
    local item = TG.Store:Item(NS_CERT, key)
    if not item or item.u or type(item.v) ~= "table" then return end
    local v = item.v
    if type(v.n) ~= "string" or type(v.p) ~= "string" then return end
    if not TG.Roster:IsOfficer(item.a) and not TG.IsMe(item.a) then return end
    if TG.Roster:IsGuildMaster(v.n) then return end
    if TG.Roster:IsOfficer(v.n) and not TG.Roster:IsGuildMaster(item.a) then return end
    Keys:Learn(v.n, v.p, item.a)
end

TG:On("STORE_CHANGED", onCert)
TG:On("STORE_VERIFIED", onCert)

function Keys:TrustOwn()
    local me = TG.MyName()
    if me and self.pubHex and not self:IsTrusted(me, self.pubHex) then
        self:Learn(me, self.pubHex, "direct")
    end
end

local SAMPLES = 40
local clock = debugprofilestop or function() return GetTime() * 1000 end

local function sample(parts)
    parts[#parts + 1] = clock()
    parts[#parts + 1] = GetTime()
    parts[#parts + 1] = collectgarbage("count")
    parts[#parts + 1] = math.random()
    if GetCursorPosition then
        local x, y = GetCursorPosition()
        parts[#parts + 1] = x
        parts[#parts + 1] = y
    end
    if GetFramerate then parts[#parts + 1] = GetFramerate() end
    if GetNetStats then
        local a, b, c, d = GetNetStats()
        parts[#parts + 1] = tostring(a) .. tostring(b) .. tostring(c) .. tostring(d)
    end
end

local function collectEntropy(cb)
    local parts = { time(), TG.MyGUID(), UnitName("player"), GetRealmName and GetRealmName(), GetServerTime and GetServerTime() }
    if Crypto.sync then
        for _ = 1, SAMPLES do sample(parts) end
        cb(Crypto.Entropy(parts))
        return
    end
    local frame = CreateFrame("Frame")
    local n = 0
    frame:SetScript("OnUpdate", function(self)
        sample(parts)
        n = n + 1
        if n >= SAMPLES then
            self:SetScript("OnUpdate", nil)
            cb(Crypto.Entropy(parts))
        end
    end)
end

local function start(cdb)
    Crypto.SetSeed(Crypto.Unhex(cdb.keySeed), function(pub)
        Keys.pubHex = Crypto.Hex(pub)
        Keys:TrustOwn()
        TG:Fire("KEY_READY", Keys.pubHex)
        if IsInGuild() then TG.Comm:SendHello("BULK") end
        TG.After(30, function() TG.Store:ResignOwn() end)
    end)
end

function Keys:Init()
    local cdb = TG.cdb
    if type(cdb.keySeed) == "string" and #cdb.keySeed == 64 and Crypto.Unhex(cdb.keySeed) then
        start(cdb)
        return
    end
    collectEntropy(function(seed)
        cdb.keySeed = Crypto.Hex(seed)
        start(cdb)
    end)
end

function Keys:Reset()
    TG.cdb.keySeed = nil
    self.pubHex = nil
    self:Init()
end

TG:On("READY", function() Keys:Init() end)
TG:On("ROSTER_UPDATED", function() Keys:TrustOwn() end)
TG:On("GUILD_CHANGED", function() TG.After(5, function() Keys:TrustOwn() end) end)

TG:RegisterSlash("keys", function(rest)
    rest = tostring(rest or ""):lower()
    if rest == "bench" then
        local clock = debugprofilestop or function() return GetTime() * 1000 end
        local pair = Crypto.KeyPair("bench")
        local t0 = clock()
        local sig = Crypto.SignWith(pair, "bench")
        local t1 = clock()
        local ok = Crypto.VerifyWith(pair.pub, "bench", sig)
        local t2 = clock()
        TG:Print(L["Signature %.0f ms, verification %.0f ms, result %s"], t1 - t0, t2 - t1, tostring(ok))
        return
    end
    if rest == "reset" then
        Keys:Reset()
        TG:Print(L["A new signing key is being generated."])
        return
    end
    local t = trustTable() or {}
    local names, keys = 0, 0
    for _, entry in pairs(t) do
        names = names + 1
        for _ in pairs(entry) do keys = keys + 1 end
    end
    TG:Print(L["Signing key %s, %d trusted keys from %d members, %d entries waiting for a key, %d verified, %d rejected, %d jobs queued"],
        Keys.pubHex and Keys.pubHex:sub(1, 16) or "-", keys, names, TG.Store:PendingCount(), TG.Store.stats.verified, TG.Store.stats.rejected, Crypto.Pending())
end, L["keys: signing key status, keys reset, keys bench"])
