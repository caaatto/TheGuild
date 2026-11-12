local TG = TheGuild
local ns = TG.GH
if ns.off then return end

local Codec = ns.Codec
local max, min, floor = math.max, math.min, math.floor

local Link = {}
ns.Link = Link

Link.BASE_URL = ns.Unseal("6GC5pXZ2Vqjeq7Gi+zxz/ynBB/yyLnMDMHs5yCJyvow3WbxzwOvyvcA0ZZeaN99iew==", "url") or ""
Link.MAX_PAYLOAD = 14000
Link.MAX_EVENTS = 2000
Link.MAX_PARTS = 255
Link.COMPRESS_LEVEL = 9

local function deflate()
    return LibStub and LibStub("LibDeflate", true)
end

function Link.EnsureState(rec)
    rec.link = rec.link or {}
    local s = rec.link
    s.link_no = s.link_no or 0
    s.sent_upto = s.sent_upto or 0
    s.prev_sent_upto = s.prev_sent_upto or 0
    s.acked_upto = s.acked_upto or 0
    if s.confirmed == nil then s.confirmed = false end
    return s
end

local function makePayload(body)
    local LD = deflate()
    if LD then
        local ok, comp = pcall(LD.CompressDeflate, LD, body, { level = Link.COMPRESS_LEVEL })
        if ok and comp and #comp < #body then return comp, true end
    end
    return body, false
end

local function buildPart(ctx, from, to, part, parts)
    local key = from .. ":" .. to .. ":" .. part .. ":" .. parts
    local cached = ctx.cache[key]
    if cached then return cached end
    local h = ctx.header
    local header = {
        addon = h.addon, build = h.build, project = h.project, region = h.region,
        realm = h.realm, ruleset = h.ruleset, name = h.name, guid = h.guid,
        classId = h.classId, raceId = h.raceId, faction = h.faction, logId = h.logId,
        linkNo = ctx.linkNo, part = part, parts = parts, fromSeq = from, tCreated = ctx.tCreated,
        guild = h.guild or "",
    }
    local body = Codec.encodeBody(header, ctx.events, from, to, ctx.encoded)
    local payload, compressed = makePayload(body)
    local result = {
        payload = payload,
        compressed = compressed,
        from = from,
        to = to,
        payloadChars = Codec.base64Length(Codec.frameLength(#payload, ctx.keyPresent)),
    }
    ctx.cache[key] = result
    return result
end

local function split(ctx, from, to, limit)
    local ranges = {}
    local start = from
    while start <= to do
        if #ranges >= Link.MAX_PARTS then return nil, "too_many_parts" end
        local n = min(to - start + 1, Link.MAX_EVENTS)
        local p = buildPart(ctx, start, start + n - 1, 1, 1)
        while p.payloadChars > limit do
            if n == 1 then return nil, "event_too_large" end
            n = max(1, min(n - 1, floor(n * limit / p.payloadChars * 0.98)))
            p = buildPart(ctx, start, start + n - 1, 1, 1)
        end
        ranges[#ranges + 1] = { start, start + n - 1 }
        start = start + n
    end
    return ranges
end

local function preEncode(events, from, last)
    local encoded, prev = {}, events[from][1]
    for i = from, last do
        local e = events[i]
        local ts = max(prev, e[1])
        encoded[i] = Codec.encodeEvent(e, ts - prev)
        prev = ts
    end
    return encoded
end

local function buildAll(ctx, from, to)
    local limit = Link.MAX_PAYLOAD
    for _ = 1, 8 do
        local ranges, err = split(ctx, from, to, limit)
        if not ranges then return nil, err end
        local parts, ok = {}, true
        for i, r in ipairs(ranges) do
            local p = buildPart(ctx, r[1], r[2], i, #ranges)
            if p.payloadChars > Link.MAX_PAYLOAD then
                ok = false
                break
            end
            parts[i] = p
        end
        if ok then return parts end
        limit = limit - 16
    end
    return nil, "split_failed"
end

local function finalize(ctx, parts)
    local links = {}
    for i, p in ipairs(parts) do
        local frame = Codec.buildFrame({
            key = ctx.key,
            keyId = ctx.keyId,
            keyPresent = ctx.keyPresent,
            payload = p.payload,
            compressed = p.compressed,
        })
        local b64 = Codec.base64url(frame)
        links[i] = { url = Link.BASE_URL .. "#v1." .. b64, from = p.from, to = p.to, count = p.to - p.from + 1 }
    end
    return links
end

local function rawKey(hex)
    local k = Codec.unhex(hex or "")
    if not k or #k ~= Codec.KEY_LEN then return nil end
    return k
end
Link.RawKey = rawKey

function Link.NewEventCount(rec)
    local s = Link.EnsureState(rec)
    return max(0, (rec.seq or 0) - s.sent_upto)
end

function Link.UnconfirmedCount(rec)
    local s = Link.EnsureState(rec)
    return max(0, (rec.seq or 0) - s.acked_upto)
end

function Link.Build(rec, header, opts)
    opts = opts or {}
    local s = Link.EnsureState(rec)
    local last = rec.seq or 0
    local mode = opts.mode or "normal"
    if last == 0 then return nil, "no_events" end
    local key = rawKey(rec.key)
    if not key then return nil, "no_key" end
    local keyPresent = not s.confirmed or mode == "recovery"
    local from
    if mode == "recovery" then
        from = max(1, min(floor(tonumber(opts.fromSeq) or 1), last))
    else
        from = max(1, s.acked_upto + 1)
    end
    if mode == "normal" and not opts.force then
        local l = s.last
        if l and l.links and #l.links > 0 and l.mode ~= "recovery" and l.fromSeq == from and l.toSeq == last
            and l.keyPresent == keyPresent and l.guild == (header.guild or "") then
            return { links = l.links, fromSeq = l.fromSeq, toSeq = l.toSeq, linkNo = l.linkNo, cached = true, keyPresent = keyPresent, mode = "normal" }
        end
    end
    if from > last then
        if not opts.force then return nil, "all_confirmed" end
        from = last
    end
    if last - from + 1 > Link.MAX_PARTS * Link.MAX_EVENTS then return nil, "too_many_parts" end
    local ctx = {
        cache = {},
        encoded = preEncode(rec.events, from, last),
        header = header,
        events = rec.events,
        key = key,
        keyId = Codec.keyId(key),
        keyPresent = keyPresent,
        linkNo = s.link_no + 1,
        tCreated = max(opts.now or 0, rec.last_ts or 0),
    }
    local parts, err = buildAll(ctx, from, last)
    if not parts then return nil, err end
    local links = finalize(ctx, parts)
    s.link_no = ctx.linkNo
    if last > s.sent_upto then
        s.prev_sent_upto = s.sent_upto
        s.sent_upto = last
    end
    s.last = { links = links, fromSeq = from, toSeq = last, linkNo = ctx.linkNo, keyPresent = keyPresent, created = ctx.tCreated, mode = mode, guild = header.guild or "" }
    return { links = links, fromSeq = from, toSeq = last, keyPresent = keyPresent, linkNo = ctx.linkNo, mode = mode }
end

function Link.ApplyAck(rec, code)
    local s = Link.EnsureState(rec)
    local key = rawKey(rec.key)
    if not key then return nil, "no_key" end
    local n, err = Codec.verifyAck(code, key, rec.log_id)
    if not n then return nil, err end
    if n < 1 or n > (rec.seq or 0) then return nil, "range" end
    s.confirmed = true
    s.acked_upto = max(s.acked_upto, n)
    s.sent_upto = max(s.sent_upto, n)
    return n
end
