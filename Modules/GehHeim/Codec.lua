local TG = TheGuild
local ns = TG.GH
if ns.off then return end

local byte, char, sub, rep = string.byte, string.char, string.sub, string.rep
local floor = math.floor
local concat = table.concat
local sha256 = TG.Crypto.sha256

local Codec = {}
ns.Codec = Codec

Codec.FMT = 1
Codec.FLAG_COMPRESSED = 1
Codec.FLAG_KEY_PRESENT = 2
Codec.FLAG_EXTENDED = 8
Codec.MAC_LEN = 16
Codec.KEY_LEN = 32
Codec.KEY_ID_LEN = 8
Codec.MAX_STRING = 64
Codec.MAX_VARINT = 9007199254740991
Codec.MAC_CONTEXT = "FGA1\0"
Codec.ACK_CONTEXT = "FGA1ACK\0"
Codec.KEY_ID_LABEL = "fg-ach-keyid"

Codec.T = {
    level = 1,
    skill = 2,
    money_peak = 3,
    zone_visit = 4,
    area_discovered = 5,
    encounter_kill = 6,
    quest_turned_in = 7,
    reputation_standing = 8,
    death = 9,
    pvp_rank = 10,
    mount_learned = 11,
    snapshot = 12,
    encounter_wipe = 13,
    fight = 14,
    fishing_loot = 15,
    stat = 16,
    rare_kill = 17,
    moment = 18,
    dungeon_run = 19,
    run_member = 20,
}

Codec.NAME = {}
for name, t in pairs(Codec.T) do Codec.NAME[t] = name end

Codec.SCHEMA = {
    [1] = { "u8" },
    [2] = { "v", "v", "v", "s" },
    [3] = { "v" },
    [4] = { "v" },
    [5] = { "v" },
    [6] = { "v", "v", "v", "v", "u8", "u8" },
    [7] = { "v" },
    [8] = { "v", "u8" },
    [9] = { "v", "u8", "u8", "v" },
    [10] = { "u8" },
    [11] = { "v" },
    [13] = { "v", "v", "v", "u8", "v" },
    [14] = { "v", "v", "v", "u8", "u8", "u8", "u8", "u8" },
    [15] = { "v", "u8", "u8" },
    [16] = { "u8", "v" },
    [17] = { "v", "u8", "u8" },
    [18] = { "u8", "v" },
    [19] = { "v", "v", "v", "u8", "v", "v", "v", "u8", "u8", "u8", "u8", "u8", "u8", "u8", "u8", "u8", "v", "u8" },
    [20] = { "v", "v", "v", "u8", "u8", "v", "v", "u8", "s" },
}

Codec.EXTRA = {
    [1] = { "u8", "v", "u8", "u8", "u8" },
    [6] = { "v", "u8", "u8", "v", "v" },
    [9] = { "u8", "u8", "u8", "v" },
    [18] = { "v" },
}

local bxor8
if bit and bit.bxor then
    local bx = bit.bxor
    bxor8 = function(a, b) return bx(a, b) % 256 end
else
    bxor8 = function(a, b)
        local r, m = 0, 1
        for _ = 1, 8 do
            local x, y = a % 2, b % 2
            if x ~= y then r = r + m end
            a, b, m = (a - x) / 2, (b - y) / 2, m * 2
        end
        return r
    end
end

local padCache = {}

local function pads(key)
    local c = padCache[key]
    if c then return c[1], c[2] end
    if #key > 64 then key = sha256(key) end
    local i, o = {}, {}
    for n = 1, 64 do
        local b = byte(key, n) or 0
        i[n] = char(bxor8(b, 0x36))
        o[n] = char(bxor8(b, 0x5c))
    end
    c = { concat(i), concat(o) }
    padCache[key] = c
    return c[1], c[2]
end

function Codec.hmac(key, msg)
    local ipad, opad = pads(key)
    return sha256(opad .. sha256(ipad .. msg))
end

function Codec.hex(s)
    return TG.Crypto.Hex(s)
end

function Codec.unhex(h)
    return TG.Crypto.Unhex(h)
end

local function isUInt(n, max)
    return type(n) == "number" and n >= 0 and n <= max and floor(n) == n
end

function Codec.varint(n)
    if not isUInt(n, Codec.MAX_VARINT) then error("varint: invalid value " .. tostring(n), 2) end
    local out = {}
    while n >= 128 do
        local low = n % 128
        out[#out + 1] = char(low + 128)
        n = (n - low) / 128
    end
    out[#out + 1] = char(n)
    return concat(out)
end

function Codec.u8(n)
    if not isUInt(n, 255) then error("u8: invalid value " .. tostring(n), 2) end
    return char(n)
end

function Codec.clampUtf8(s, maxBytes)
    s = tostring(s or "")
    maxBytes = maxBytes or Codec.MAX_STRING
    if #s <= maxBytes then return s end
    local cut = maxBytes
    while cut > 0 do
        local b = byte(s, cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return sub(s, 1, cut)
end

function Codec.str(s)
    s = Codec.clampUtf8(s, Codec.MAX_STRING)
    return Codec.varint(#s) .. s
end

function Codec.cleanGuild(s)
    if type(s) ~= "string" then return "" end
    return Codec.clampUtf8((s:gsub("%z", "")), Codec.MAX_STRING)
end

function Codec.readVarint(s, pos)
    local value, mult = 0, 1
    for i = 0, 7 do
        local b = byte(s, pos + i)
        if not b then return nil, "truncated varint" end
        local low = b % 128
        value = value + low * mult
        if b < 128 then
            if i > 0 and b == 0 then return nil, "overlong varint" end
            if value > Codec.MAX_VARINT then return nil, "varint too large" end
            return value, pos + i + 1
        end
        mult = mult * 128
    end
    return nil, "varint too long"
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

function Codec.base64url(s)
    local out = {}
    local n = #s
    local i = 1
    while i <= n - 2 do
        local a, b, c = byte(s, i, i + 2)
        local v = a * 65536 + b * 256 + c
        local c1 = floor(v / 262144)
        local c2 = floor(v / 4096) % 64
        local c3 = floor(v / 64) % 64
        local c4 = v % 64
        out[#out + 1] = sub(B64, c1 + 1, c1 + 1) .. sub(B64, c2 + 1, c2 + 1) .. sub(B64, c3 + 1, c3 + 1) .. sub(B64, c4 + 1, c4 + 1)
        i = i + 3
    end
    local rest = n - i + 1
    if rest == 1 then
        local v = byte(s, i) * 16
        out[#out + 1] = sub(B64, floor(v / 64) + 1, floor(v / 64) + 1) .. sub(B64, v % 64 + 1, v % 64 + 1)
    elseif rest == 2 then
        local a, b = byte(s, i, i + 1)
        local v = (a * 256 + b) * 4
        local c1 = floor(v / 4096)
        local c2 = floor(v / 64) % 64
        local c3 = v % 64
        out[#out + 1] = sub(B64, c1 + 1, c1 + 1) .. sub(B64, c2 + 1, c2 + 1) .. sub(B64, c3 + 1, c3 + 1)
    end
    return concat(out)
end

function Codec.base64Length(n)
    return floor(n / 3) * 4 + ({ [0] = 0, 2, 3 })[n % 3]
end

local B32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
local B32DEC = {}
for i = 1, 32 do B32DEC[byte(B32, i)] = i - 1 end

function Codec.base32(s)
    local out = {}
    local buffer, bits = 0, 0
    for i = 1, #s do
        buffer = buffer * 256 + byte(s, i)
        bits = bits + 8
        while bits >= 5 do
            bits = bits - 5
            local div = 2 ^ bits
            local idx = floor(buffer / div)
            buffer = buffer - idx * div
            out[#out + 1] = sub(B32, idx + 1, idx + 1)
        end
    end
    if bits > 0 then
        local idx = buffer * 2 ^ (5 - bits)
        out[#out + 1] = sub(B32, idx + 1, idx + 1)
    end
    return concat(out)
end

function Codec.unbase32(s)
    if type(s) ~= "string" then return nil, "not a string" end
    s = s:upper():gsub("[%s%-]", "")
    if s == "" then return nil, "empty" end
    local out = {}
    local buffer, bits = 0, 0
    for i = 1, #s do
        local v = B32DEC[byte(s, i)]
        if not v then return nil, "bad character" end
        buffer = buffer * 32 + v
        bits = bits + 5
        if bits >= 8 then
            bits = bits - 8
            local div = 2 ^ bits
            local b = floor(buffer / div)
            buffer = buffer - b * div
            out[#out + 1] = char(b)
        end
    end
    if bits >= 5 or buffer ~= 0 then return nil, "bad padding" end
    return concat(out)
end

local function encodeByKinds(kinds, values, startIndex)
    local out = {}
    for i, kind in ipairs(kinds) do
        local v = values[startIndex + i - 1]
        if kind == "v" then
            out[i] = Codec.varint(v or 0)
        elseif kind == "u8" then
            out[i] = Codec.u8(v or 0)
        else
            out[i] = Codec.str(v or "")
        end
    end
    return concat(out)
end

local function encodeSnapshot(e)
    local out = {
        Codec.u8(e[3] or 1),
        Codec.u8(e[4] or 0),
        Codec.varint(e[5] or 0),
        Codec.varint(e[6] or 0),
        Codec.u8(e[7] or 0),
    }
    local skills = e[8] or {}
    out[#out + 1] = Codec.varint(#skills)
    for _, sk in ipairs(skills) do
        out[#out + 1] = Codec.varint(sk[1] or 0) .. Codec.varint(sk[2] or 0) .. Codec.varint(sk[3] or 0) .. Codec.str(sk[4] or "")
    end
    local reps = e[9] or {}
    out[#out + 1] = Codec.varint(#reps)
    for _, r in ipairs(reps) do
        out[#out + 1] = Codec.varint(r[1] or 0) .. Codec.u8(r[2] or 0)
    end
    return concat(out)
end

function Codec.encodeFields(e)
    local t = e[2]
    if t == Codec.T.snapshot then return encodeSnapshot(e) end
    local kinds = Codec.SCHEMA[t]
    if not kinds then error("unknown event type " .. tostring(t), 2) end
    local base = encodeByKinds(kinds, e, 3)
    local extra = Codec.EXTRA[t]
    if not extra then return base end
    local present = {}
    for i = 1, #extra do
        if e[2 + #kinds + i] == nil then break end
        present[i] = extra[i]
    end
    if #present == 0 then return base end
    return base .. encodeByKinds(present, e, 3 + #kinds)
end

function Codec.encodeEvent(e, dt)
    local fields = Codec.encodeFields(e)
    return Codec.u8(e[2]) .. Codec.varint(dt) .. Codec.varint(#fields) .. fields
end

function Codec.encodeBody(h, events, first, last, encoded)
    first, last = first or 1, last or #events
    local out = {
        Codec.varint(h.addon[1]), Codec.varint(h.addon[2]), Codec.varint(h.addon[3]),
        Codec.varint(h.build or 0), Codec.varint(h.project or 0), Codec.u8(h.region or 0),
        Codec.str(h.realm or ""), Codec.str(h.ruleset or ""), Codec.str(h.name or ""), Codec.str(h.guid or ""),
        Codec.u8(h.classId or 0), Codec.u8(h.raceId or 0), Codec.u8(h.faction or 0),
        Codec.varint(h.logId), Codec.varint(h.linkNo), Codec.u8(h.part or 1), Codec.u8(h.parts or 1),
        Codec.varint(h.fromSeq), Codec.varint(last - first + 1), Codec.varint(h.tCreated),
        Codec.varint(events[first] and events[first][1] or h.tCreated),
        Codec.str(Codec.cleanGuild(h.guild)),
    }
    local prev = events[first] and events[first][1] or 0
    for i = first, last do
        local e = events[i]
        local ts = e[1]
        local dt = ts - prev
        if dt < 0 then
            dt = 0
            ts = prev
        end
        out[#out + 1] = (encoded and dt ~= 0 and encoded[i]) or Codec.encodeEvent(e, dt)
        prev = ts
    end
    return concat(out)
end

function Codec.keyId(key)
    return sub(Codec.hmac(key, Codec.KEY_ID_LABEL), 1, Codec.KEY_ID_LEN)
end

function Codec.mac(key, macInput)
    return sub(Codec.hmac(key, macInput), 1, Codec.MAC_LEN)
end

function Codec.frameLength(payloadLen, keyPresent)
    local n = 2 + Codec.KEY_ID_LEN + payloadLen + Codec.MAC_LEN
    if keyPresent then n = n + Codec.KEY_LEN end
    return n
end

function Codec.buildFrame(opts)
    local flags = Codec.FLAG_EXTENDED
    if opts.compressed then flags = flags + Codec.FLAG_COMPRESSED end
    if opts.keyPresent then flags = flags + Codec.FLAG_KEY_PRESENT end
    local parts = { char(Codec.FMT, flags), opts.keyId or Codec.keyId(opts.key) }
    if opts.keyPresent then parts[#parts + 1] = opts.key end
    parts[#parts + 1] = opts.payload
    local prefix = concat(parts)
    return prefix .. Codec.mac(opts.key, Codec.MAC_CONTEXT .. prefix)
end

function Codec.ackCode(key, logId, n)
    local tag = sub(Codec.hmac(key, Codec.ACK_CONTEXT .. Codec.varint(logId) .. Codec.varint(n)), 1, 4)
    return Codec.base32(Codec.varint(n) .. tag)
end

function Codec.verifyAck(code, key, logId)
    local raw = Codec.unbase32(code)
    if not raw or #raw < 5 then return nil, "format" end
    local n, p = Codec.readVarint(raw, 1)
    if not n or #raw - p + 1 ~= 4 then return nil, "format" end
    local expect = sub(Codec.hmac(key, Codec.ACK_CONTEXT .. Codec.varint(logId) .. Codec.varint(n)), 1, 4)
    if sub(raw, p) ~= expect then return nil, "mac" end
    return n
end
