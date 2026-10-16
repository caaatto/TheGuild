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
local MAX_CHUNKS = 300
local CHUNK_TTL = 120
local HELLO_INTERVAL = 300
local PEER_TTL = 900
local ROSTER_GRACE = 90

local handlers = {}
local peers = {}
local partials = {}
local held = {}
local seq = math.random(1, 9999)
local lastHello = 0
local warnedVersion
local sendDeflateOpts = { level = 5 }

Comm.stats = { sent = 0, held = 0, received = 0, ignored = 0, chunks = 0, reassembled = 0, lastTag = nil, lastFrom = nil }

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

local function decode(body)
    if type(body) ~= "string" or body == "" then return nil end
    local marker = body:sub(1, 1)
    if marker == "=" then return body:sub(2) end
    if marker ~= "~" then return nil end
    local compressed = LibDeflate:DecodeForWoWAddonChannel(body:sub(2))
    if not compressed then return nil end
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil end
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

local function dispatchRaw(text, chatType, target, prio)
    if Comm.muted then return end
    if lockedDown() then
        held[#held + 1] = { text = text, chatType = chatType, target = target, prio = prio }
        Comm.stats.held = Comm.stats.held + 1
        return
    end
    CTL:SendAddonMessage(prio or "NORMAL", TG.prefix, text, chatType, target)
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

function Comm:Send(tag, payload, prio, target)
    if not IsInGuild() and not target then return false end
    if tag:find(SEP, 1, true) then return false end
    local chatType = target and "WHISPER" or "GUILD"
    local body = encode(payload)
    local head = TG.protocol .. SEP .. tag .. SEP
    if #head + #body <= MAX_MESSAGE then
        dispatchRaw(head .. body, chatType, target, prio)
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
    for idx, piece in ipairs(pieces) do
        local text = TG.protocol .. SEP .. "K" .. SEP .. ("%d:%d:%d:%s"):format(seq, idx, #pieces, tag) .. SEP .. piece
        dispatchRaw(text, chatType, target, prio or "BULK")
    end
    Comm.stats.chunks = Comm.stats.chunks + #pieces
    return true
end

function Comm:Whisper(target, tag, payload, prio)
    return self:Send(tag, payload, prio, TG.Address(target))
end

-- Group messages go to the raid or party and are accepted from anyone in
-- the group, guild member or not.
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

local function senderAllowed(key)
    if TG.Roster:Get(key) then return true end
    if not TG.Roster:IsReady() then return true end
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
    local data = decode(table.concat(part.pieces))
    if data ~= nil then deliver(part.tag, sender, data, channel) end
end

local function onAddonMessage(_, prefix, text, channel, sender)
    if prefix ~= TG.prefix then return end
    if not TG.usable(text) or not TG.usable(sender) then return end
    local group = channel == "RAID" or channel == "PARTY"
    if channel ~= "GUILD" and channel ~= "WHISPER" and not group then return end
    local key = TG.StripRealm(sender)
    if not key then return end
    Comm.stats.received = Comm.stats.received + 1

    local proto, tag, body = strsplit(SEP, text, 3)
    proto = tonumber(proto)
    if not proto or not tag then return end

    if tag == "HI" then
        local version, guid = strsplit(":", body and body:sub(2) or "")
        if guid and guid ~= "" and guid == TG.MyGUID() then
            TG.LearnMyName(key)
            return
        end
        if TG.IsMe(key) then return end
        if not senderAllowed(key) then Comm.stats.ignored = Comm.stats.ignored + 1 return end
        peers[key] = { version = version, guid = guid, seen = GetTime(), proto = proto }
        if version and TG.VersionNewer(version, TG.version) and warnedVersion ~= version then
            warnedVersion = version
            TG:Print(L["A newer version (%s) is available."], version)
        end
        TG:Fire("PEER_HELLO", key, peers[key])
        return
    end

    if TG.IsMe(key) then return end
    if proto ~= TG.protocol then Comm.stats.ignored = Comm.stats.ignored + 1 return end
    if group then
        if not TG.InGroup(key) then Comm.stats.ignored = Comm.stats.ignored + 1 return end
    elseif not senderAllowed(key) then
        Comm.stats.ignored = Comm.stats.ignored + 1
        return
    end
    if peers[key] then peers[key].seen = GetTime() end

    if tag == "K" then
        handleChunk(key, body or "", channel)
        return
    end
    local data = decode(body)
    if data == nil then return end
    deliver(tag, key, data, channel)
end

function Comm:SendHello(prio)
    if not IsInGuild() then return end
    lastHello = GetTime()
    self:Send("HI", ("%s:%s"):format(TG.version, TG.MyGUID() or "-"), prio or "ALERT")
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
    TG:Print("sent %d, held %d, received %d, ignored %d, chunks %d, reassembled %d, peers %d",
        s.sent, s.held, s.received, s.ignored, s.chunks, s.reassembled, self:PeerCount())
    if s.lastTag then TG:Print("last: %s from %s", s.lastTag, tostring(s.lastFrom)) end
    if lockedDown() then TG:Print("chat messaging lockdown active, %d messages waiting", #held) end
end

TG:RegisterEvent("CHAT_MSG_ADDON", onAddonMessage)

C_ChatInfo.RegisterAddonMessagePrefix(TG.prefix)

TG:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, initial)
    if initial then TG.After(8, function() Comm:SendHello() end) end
end)

TG:On("GUILD_CHANGED", function()
    peers = {}
    TG.After(5, function() Comm:SendHello() end)
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
            CTL:SendAddonMessage(item.prio or "NORMAL", TG.prefix, item.text, item.chatType, item.target)
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
