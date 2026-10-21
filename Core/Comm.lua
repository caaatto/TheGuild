local _, TG = ...
local L = TG.L

local Comm = {}
TG.Comm = Comm

local CTL = ChatThrottleLib
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local SEP = "\001"
local MAX_MESSAGE = 255
local CHUNK_SIZE = 200
local MAX_CHUNKS = 40
local MAX_PARTIALS = 2
local CHUNK_TTL = 120
local HELLO_INTERVAL = 300
local PEER_TTL = 900
local ROSTER_GRACE = 90

local handlers = {}
local peers = {}
local partials = {}
local held = {}
local lastHi = {}
local quota = {}
local blocked = {}
local HI_COOLDOWN = 20
local QUOTA_BYTES = 262144
local QUOTA_WINDOW = 60
local BLOCK_TIME = 300
local seq = math.random(1, 9999)
local lastHello = 0
local warnedVersion
local sendDeflateOpts = { level = 5 }

Comm.stats = { sent = 0, held = 0, received = 0, ignored = 0, chunks = 0, reassembled = 0, lastTag = nil, lastFrom = nil, failed = 0, raw = 0, unusable = 0 }
local warnedResult = {}

local function enumName(list, result)
    if type(Enum) == "table" and type(Enum[list]) == "table" then
        for name, value in pairs(Enum[list]) do
            if value == result then return name end
        end
    end
    return tostring(result)
end

local function resultName(result)
    return enumName("SendAddonMessageResult", result)
end

Comm.echo = {}
local MAX_FANOUT = 200
local PROBE_DELAY = 12
local REPROBE = 600

local function onSent(_, didSend, result)
    if didSend then return end
    Comm.stats.failed = Comm.stats.failed + 1
    Comm.stats.lastResult = result
    if not warnedResult[result] then
        warnedResult[result] = true
        TG:Print(L["Addon message not sent: %s"], resultName(result))
    end
end

local function trace(fmt, ...)
    if Comm.debug then TG:Print("comm " .. fmt, ...) end
end

local function lockedDown()
    return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() == true
end

local function encode(payload)
    if type(payload) == "table" then
        local serialized = LibSerialize:Serialize(payload)
        local compressed = LibDeflate:CompressDeflate(serialized, sendDeflateOpts)
        return "~" .. LibDeflate:EncodeForWoWAddonChannel(compressed)
    end
    return "=" .. tostring(payload)
end

function Comm:Quota(sender, bytes)
    local now = GetTime()
    local q = quota[sender]
    if not q or now - q.at > QUOTA_WINDOW then
        q = { at = now, bytes = 0 }
        quota[sender] = q
    end
    q.bytes = q.bytes + bytes
    if q.bytes > QUOTA_BYTES then
        blocked[sender] = now
        Comm.stats.ignored = Comm.stats.ignored + 1
        return false
    end
    return true
end

function Comm:Blocked(sender)
    return blocked[sender] ~= nil and GetTime() - blocked[sender] < BLOCK_TIME
end

local function decode(body, sender)
    if type(body) ~= "string" or body == "" then return nil end
    local marker = body:sub(1, 1)
    if marker == "=" then return body:sub(2) end
    if marker ~= "~" then return nil end
    local compressed = LibDeflate:DecodeForWoWAddonChannel(body:sub(2))
    if not compressed then return nil end
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil end
    if sender and not Comm:Quota(sender, #serialized) then return nil end
    local ok, data = LibSerialize:Deserialize(serialized)
    if not ok then return nil end
    return data
end

local function utf8Cut(s, i, j)
    while j > i and j < #s do
        local b = s:byte(j + 1)
        if b < 128 or b >= 192 then break end
        j = j - 1
    end
    return j
end

local function dispatchRaw(text, chatType, target, prio, prefix)
    if Comm.muted then return end
    if lockedDown() then
        held[#held + 1] = { text = text, chatType = chatType, target = target, prio = prio, prefix = prefix }
        Comm.stats.held = Comm.stats.held + 1
        return
    end
    CTL:SendAddonMessage(prio or "NORMAL", prefix or TG.prefix, text, chatType, target, nil, onSent)
    Comm.stats.sent = Comm.stats.sent + 1
end

function Comm:Register(tag, fn, owner)
    handlers[tag] = handlers[tag] or {}
    table.insert(handlers[tag], { fn = fn, owner = owner })
end

function Comm:UnregisterAll(owner)
    for tag, list in pairs(handlers) do
        for i = #list, 1, -1 do
            if list[i].owner == owner then table.remove(list, i) end
        end
        if #list == 0 then handlers[tag] = nil end
    end
end

function Comm:Targets(tag)
    local out = {}
    if tag == "HI" or tag == "PING" then
        for _, e in ipairs(TG.Roster:Online()) do
            if not TG.IsMe(e.key) then out[#out + 1] = e.key end
            if #out >= MAX_FANOUT then break end
        end
    else
        for key in pairs(self:Peers()) do out[#out + 1] = key end
    end
    return out
end

function Comm:Send(tag, payload, prio, target)
    if not IsInGuild() and not target then return false end
    if tag:find(SEP, 1, true) then return false end
    local body = encode(payload)
    local head = TG.protocol .. SEP .. tag .. SEP
    local targets
    if target then
        targets = { target }
    elseif self.guildBlocked then
        targets = self:Targets(tag)
        if #targets == 0 then return true end
    else
        targets = { false }
    end
    if #head + #body <= MAX_MESSAGE then
        for _, t in ipairs(targets) do
            dispatchRaw(head .. body, t and "WHISPER" or "GUILD", t or nil, prio)
        end
        return true
    end
    seq = (seq % 99999) + 1
    local pieces = {}
    local i = 1
    while i <= #body do
        local j = utf8Cut(body, i, math.min(i + CHUNK_SIZE - 1, #body))
        pieces[#pieces + 1] = body:sub(i, j)
        i = j + 1
    end
    if #pieces > MAX_CHUNKS then return false end
    for _, t in ipairs(targets) do
        for idx, piece in ipairs(pieces) do
            local text = TG.protocol .. SEP .. "K" .. SEP .. ("%d:%d:%d:%s"):format(seq, idx, #pieces, tag) .. SEP .. piece
            dispatchRaw(text, t and "WHISPER" or "GUILD", t or nil, prio or "BULK")
        end
    end
    Comm.stats.chunks = Comm.stats.chunks + #pieces * #targets
    return true
end

function Comm:Probe()
    if not IsInGuild() or self.muted then return end
    local me = TG.MyName()
    if not me then return end
    wipe(self.echo)
    local start = GetTime()
    local text = TG.protocol .. SEP .. "PING" .. SEP .. "="
    dispatchRaw(text, "GUILD", nil, "ALERT")
    dispatchRaw(text, "WHISPER", TG.Address(me), "ALERT")
    TG.After(PROBE_DELAY, function()
        local whisper = self.echo.WHISPER ~= nil and self.echo.WHISPER >= start
        local guild = self.echo.GUILD ~= nil and self.echo.GUILD >= start
        if whisper and not guild then
            if not self.guildBlocked then
                self.guildBlocked = true
                TG:Print(L["The guild addon channel is not available here, messages go out as whispers to members who run TheGuild."])
                self:SendHello("ALERT")
                TG.After(5, function() TG.Store:RequestSync(true) end)
            end
        elseif guild and self.guildBlocked then
            self.guildBlocked = false
        end
    end)
end

function Comm:SendForeign(prefix, text, prio)
    if not IsInGuild() or type(text) ~= "string" or #text > MAX_MESSAGE then return false end
    dispatchRaw(text, "GUILD", nil, prio or "BULK", prefix)
    return true
end

function Comm:Whisper(target, tag, payload, prio)
    return self:Send(tag, payload, prio, TG.Address(target))
end

function Comm:SendGroup(tag, payload, prio)
    if not IsInGroup() then return false end
    local chatType = IsInRaid() and "RAID" or "PARTY"
    local body = encode(payload)
    local head = TG.protocol .. SEP .. tag .. SEP
    if #head + #body <= MAX_MESSAGE then
        dispatchRaw(head .. body, chatType, nil, prio)
        return true
    end
    seq = (seq % 99999) + 1
    local i = 1
    local pieces = {}
    while i <= #body do
        local j = utf8Cut(body, i, math.min(i + CHUNK_SIZE - 1, #body))
        pieces[#pieces + 1] = body:sub(i, j)
        i = j + 1
    end
    if #pieces > MAX_CHUNKS then return false end
    for idx, piece in ipairs(pieces) do
        dispatchRaw(TG.protocol .. SEP .. "K" .. SEP .. ("%d:%d:%d:%s"):format(seq, idx, #pieces, tag) .. SEP .. piece, chatType, nil, prio or "BULK")
    end
    return true
end

local function deliver(tag, sender, data, channel)
    local list = handlers[tag]
    if not list then return end
    Comm.stats.lastTag, Comm.stats.lastFrom = tag, sender
    for i = #list, 1, -1 do
        TG.SafeCall(list[i].fn, sender, data, channel)
    end
end

local function senderAllowed(key, channel)
    if TG.Roster:Get(key) then return true end
    if not TG.Roster:IsReady() then return channel == "GUILD" end
    if peers[key] and GetTime() - peers[key].seen < ROSTER_GRACE then return true end
    return false
end

local function handleChunk(sender, body, channel)
    local header, piece = strsplit(SEP, body, 2)
    if not header or not piece then return end
    local id, idx, n, tag = header:match("^(%d+):(%d+):(%d+):(.+)$")
    idx, n = tonumber(idx), tonumber(n)
    if not id or not idx or not n or n > MAX_CHUNKS or idx > n then return end
    local key = sender .. "#" .. id
    local part = partials[key]
    if not part then
        local open = 0
        for k in pairs(partials) do
            if k:sub(1, #sender + 1) == sender .. "#" then open = open + 1 end
        end
        if open >= MAX_PARTIALS then return end
        part = { n = n, tag = tag, pieces = {}, count = 0, at = GetTime() }
        partials[key] = part
    end
    part.at = GetTime()
    if not part.pieces[idx] then
        part.pieces[idx] = piece
        part.count = part.count + 1
    end
    if part.count < n then return end
    partials[key] = nil
    Comm.stats.reassembled = Comm.stats.reassembled + 1
    local data = decode(table.concat(part.pieces), sender)
    if data ~= nil then deliver(part.tag, sender, data, channel) end
end

local function onAddonMessage(_, prefix, text, channel, sender)
    if prefix ~= TG.prefix then return end
    Comm.stats.raw = Comm.stats.raw + 1
    if not TG.usable(text) or not TG.usable(sender) then
        Comm.stats.unusable = Comm.stats.unusable + 1
        trace("dropped a message with a secret sender or text")
        return
    end
    local group = channel == "RAID" or channel == "PARTY"
    if channel ~= "GUILD" and channel ~= "WHISPER" and not group then
        trace("ignored channel %s from %s", tostring(channel), tostring(sender))
        return
    end
    local key = TG.StripRealm(sender)
    if not key then return end
    if Comm:Blocked(key) then trace("blocked sender %s", key) return end
    Comm.stats.received = Comm.stats.received + 1

    if TG.IsMe(key) then
        Comm.echo[channel] = GetTime()
        if channel == "GUILD" and Comm.guildBlocked then
            Comm.guildBlocked = false
            TG:Print(L["The guild addon channel works again."])
        end
    end
    local proto, tag, body = strsplit(SEP, text, 3)
    proto = tonumber(proto)
    if not proto or not tag then trace("malformed message from %s", key) return end
    trace("%s from %s (%s) protocol %d, %d bytes", tag, key, tostring(sender), proto, #text)

    if tag == "HI" then
        local version, guid, pub = strsplit(":", body and body:sub(2) or "")
        if version and not version:match("^%d+%.%d+%.%d+$") then version = nil end
        if guid and guid ~= "" and guid == TG.MyGUID() then
            local first = UnitName("player")
            if TG.usable(first) and first and TG.FirstName(key) == first then TG.LearnMyName(key) end
            return
        end
        if TG.IsMe(key) then trace("own hello echoed as %s", key) return end
        if not senderAllowed(key, channel) then Comm.stats.ignored = Comm.stats.ignored + 1 trace("hello from %s rejected, not in the roster", key) return end
        local repeated = lastHi[key] ~= nil and GetTime() - lastHi[key] < HI_COOLDOWN
        lastHi[key] = GetTime()
        if repeated then
            if peers[key] then peers[key].seen = GetTime() end
            return
        end
        peers[key] = { version = version, guid = guid, seen = GetTime(), proto = proto }
        if pub and #pub == 64 and TG.Keys then TG.Keys:Learn(key, pub, "direct") end
        if version and TG.VersionNewer(version, TG.version) and warnedVersion ~= version then
            warnedVersion = version
            TG:Print(L["A newer version (%s) is available."], version)
        end
        TG:Fire("PEER_HELLO", key, peers[key])
        return
    end

    if TG.IsMe(key) then trace("own message echoed as %s", key) return end
    if proto ~= TG.protocol then Comm.stats.ignored = Comm.stats.ignored + 1 trace("%s runs protocol %d, we need %d", key, proto, TG.protocol) return end
    if group then
        if not TG.InGroup(key) then Comm.stats.ignored = Comm.stats.ignored + 1 trace("%s is not in our group", key) return end
    elseif not senderAllowed(key, channel) then
        Comm.stats.ignored = Comm.stats.ignored + 1
        trace("%s rejected, not in the roster", key)
        return
    end
    if peers[key] then peers[key].seen = GetTime() end

    if tag == "K" then
        handleChunk(key, body or "", channel)
        return
    end
    local data = decode(body, key)
    if data == nil then return end
    deliver(tag, key, data, channel)
end

function Comm:SendHello(prio)
    if not IsInGuild() then return end
    lastHello = GetTime()
    self:Send("HI", ("%s:%s:%s"):format(TG.version, TG.MyGUID() or "-", TG.Keys and TG.Keys.pubHex or ""), prio or "ALERT")
end

function Comm:SeedPeer(key, version, guid)
    peers[key] = { version = version, guid = guid, seen = GetTime(), proto = TG.protocol }
end

function Comm:ResetPeers()
    wipe(peers)
end

function Comm:Peers()
    local out = {}
    local now = GetTime()
    for key, p in pairs(peers) do
        local m = TG.Roster:Get(key)
        local online = (m and m.online) or now - p.seen < ROSTER_GRACE
        if online and now - p.seen < PEER_TTL then out[key] = p end
    end
    return out
end

function Comm:PeerCount()
    return TG.Count(self:Peers())
end

function Comm:HasAddon(key)
    key = TG.StripRealm(key)
    if TG.IsMe(key) then return true end
    return self:Peers()[key] ~= nil
end

function Comm:PeerVersion(key)
    local p = peers[TG.StripRealm(key) or key]
    return p and p.version
end

function Comm:PrintStats()
    local s = self.stats
    TG:Print("sent %d, failed %d, held %d, received %d (raw %d, unusable %d), ignored %d, chunks %d, reassembled %d, peers %d",
        s.sent, s.failed, s.held, s.received, s.raw, s.unusable, s.ignored, s.chunks, s.reassembled, self:PeerCount())
    if s.lastResult then TG:Print("last send failure: %s", resultName(s.lastResult)) end
    if s.lastTag then TG:Print("last: %s from %s", s.lastTag, tostring(s.lastFrom)) end
    TG:Print("in guild: %s, my name: %s, roster ready: %s, protocol %d, debug %s", tostring(IsInGuild()), tostring(TG.MyName()), tostring(TG.Roster:IsReady()), TG.protocol, self.debug and "on" or "off")
    local registered = C_ChatInfo.IsAddonMessagePrefixRegistered and C_ChatInfo.IsAddonMessagePrefixRegistered(TG.prefix)
    TG:Print("prefix %s registered: %s (%s)", TG.prefix, tostring(registered), enumName("RegisterAddonMessagePrefixResult", self.prefixResult))
    TG:Print("guild channel: %s", self.guildBlocked and "not delivered, whispering to peers" or "ok")
    for key, p in pairs(self:Peers()) do TG:Print("peer %s: version %s, seen %s ago", key, tostring(p.version), TG.FormatAge(GetTime() - p.seen)) end
    if lockedDown() then TG:Print("chat messaging lockdown active, %d messages waiting", #held) end
end

TG:RegisterEvent("CHAT_MSG_ADDON", onAddonMessage)

Comm.prefixResult = C_ChatInfo.RegisterAddonMessagePrefix(TG.prefix)

function Comm:SelfTest()
    local me = TG.MyName()
    if not me then return end
    wipe(self.echo)
    local start = GetTime()
    if IsInGuild() then dispatchRaw(TG.protocol .. SEP .. "PING" .. SEP .. "=", "GUILD", nil, "ALERT") end
    dispatchRaw(TG.protocol .. SEP .. "PING" .. SEP .. "=", "WHISPER", TG.Address(me), "ALERT")
    TG:Print("comm test: sent a ping to the guild and to myself, waiting 3 seconds")
    TG.After(3, function()
        local function age(channel)
            local at = self.echo[channel]
            return at and at >= start and "arrived" or "nothing"
        end
        TG:Print("comm test: guild echo %s, whisper echo %s, raw events %d, send failures %d", age("GUILD"), age("WHISPER"), self.stats.raw, self.stats.failed)
    end)
end

TG:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, initial)
    if initial then TG.After(8, function() Comm:SendHello() Comm:Probe() end) end
end)

TG:On("GUILD_CHANGED", function()
    peers = {}
    TG.After(5, function() Comm:SendHello() Comm:Probe() end)
end)

TG.Ticker(REPROBE, function()
    if Comm.guildBlocked then Comm:Probe() end
end)

TG:On("PEER_HELLO", function(key, info)
    if GetTime() - lastHello > 30 and not (info.seen and info.greeted) then
        info.greeted = true
        TG.After(math.random(2, 6), function()
            if GetTime() - lastHello > 30 then Comm:SendHello("NORMAL") end
        end)
    end
end)

TG.Ticker(1, function()
    if #held > 0 and not lockedDown() then
        local queue = held
        held = {}
        for _, item in ipairs(queue) do
            CTL:SendAddonMessage(item.prio or "NORMAL", item.prefix or TG.prefix, item.text, item.chatType, item.target)
            Comm.stats.sent = Comm.stats.sent + 1
        end
    end
    local now = GetTime()
    for key, part in pairs(partials) do
        if now - part.at > CHUNK_TTL then partials[key] = nil end
    end
end)

TG.Ticker(HELLO_INTERVAL, function()
    if GetTime() - lastHello >= HELLO_INTERVAL - 5 then Comm:SendHello("BULK") end
end)
