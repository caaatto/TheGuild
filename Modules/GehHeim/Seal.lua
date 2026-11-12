local TG = TheGuild
local ns = {}
TG.GH = ns

ns.LEGACY = ns.LEGACY or "GehHeim"

local sha256 = TG.Crypto.sha256
local byte, char, sub, floor, concat = string.byte, string.char, string.sub, math.floor, table.concat

local FIELDS = { "Title", "Notes", "Author", "X-License" }

local function rawKey()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if not get then return nil end
    local parts = {}
    for i, field in ipairs(FIELDS) do
        local ok, v = pcall(get, ns.LEGACY, field)
        v = ok and TG.plain(v, nil) or nil
        if type(v) ~= "string" or v == "" then return nil end
        parts[i] = v
    end
    return concat(parts, "\n")
end

local raw = rawKey()
local KEY = raw and sha256("TheGuild_GehHeim catalog seal " .. raw) or nil
ns.sealed = KEY ~= nil

local function separate()
    local exists = C_AddOns and C_AddOns.DoesAddOnExist
    local state = C_AddOns and C_AddOns.GetAddOnEnableState
    if not exists or not state then return false end
    local ok, on = pcall(function() return exists("TheGuild_GehHeim") and (state("TheGuild_GehHeim") or 0) > 0 end)
    if not ok or not on then return false end
    if ns.sealed then
        pcall(C_AddOns.DisableAddOn, "TheGuild_GehHeim")
        if C_AddOns.SaveAddOns then pcall(C_AddOns.SaveAddOns) end
    end
    return true
end

ns.off = not ns.sealed or separate()

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for i = 1, 64 do DECODE[byte(ALPHABET, i)] = i - 1 end

local XOR = {}
for a = 0, 15 do
    XOR[a] = {}
    for b = 0, 15 do
        local r, bitA, bitB, m = 0, a, b, 1
        while bitA > 0 or bitB > 0 do
            if (bitA % 2) ~= (bitB % 2) then r = r + m end
            bitA, bitB, m = floor(bitA / 2), floor(bitB / 2), m * 2
        end
        XOR[a][b] = r
    end
end

local function mix(s, salt)
    local out, block, ks = {}, 0, ""
    for i = 1, #s do
        local j = (i - 1) % 32
        if j == 0 then
            ks = sha256(KEY .. salt .. char(floor(block / 256), block % 256))
            block = block + 1
        end
        local a, b = byte(s, i), byte(ks, j + 1)
        out[i] = char(XOR[floor(a / 16)][floor(b / 16)] * 16 + XOR[a % 16][b % 16])
    end
    return concat(out)
end

local function encode(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = byte(s, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local q = { floor(n / 262144) % 64, floor(n / 4096) % 64, floor(n / 64) % 64, n % 64 }
        out[#out + 1] = sub(ALPHABET, q[1] + 1, q[1] + 1) .. sub(ALPHABET, q[2] + 1, q[2] + 1)
            .. (b and sub(ALPHABET, q[3] + 1, q[3] + 1) or "=") .. (c and sub(ALPHABET, q[4] + 1, q[4] + 1) or "=")
    end
    return concat(out)
end

local function decode(s)
    local out, bits, value = {}, 0, 0
    for i = 1, #s do
        local v = DECODE[byte(s, i)]
        if v then
            value = value * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local div = 2 ^ bits
                out[#out + 1] = char(floor(value / div))
                value = value % div
            end
        end
    end
    return concat(out)
end

local function pack(v, out)
    local t = type(v)
    if t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "number" then
        out[#out + 1] = "n" .. v .. ";"
    elseif t == "boolean" then
        out[#out + 1] = v and "t" or "f"
    elseif t == "table" then
        out[#out + 1] = "{"
        local n = #v
        for i = 1, n do pack(v[i], out) end
        out[#out + 1] = "|"
        local keys = {}
        for k in pairs(v) do
            if type(k) ~= "number" or k < 1 or k > n or k ~= floor(k) then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            pack(k, out)
            pack(v[k], out)
        end
        out[#out + 1] = "}"
    end
end

local function unpack(s, pos)
    local c = sub(s, pos, pos)
    if c == "s" then
        local len, p = s:match("^(%d+):()", pos + 1)
        len = tonumber(len)
        return sub(s, p, p + len - 1), p + len
    elseif c == "n" then
        local num, p = s:match("^([^;]+);()", pos + 1)
        return tonumber(num), p
    elseif c == "t" then
        return true, pos + 1
    elseif c == "f" then
        return false, pos + 1
    elseif c == "{" then
        local t, i = {}, 1
        pos = pos + 1
        while sub(s, pos, pos) ~= "|" do
            t[i], pos = unpack(s, pos)
            i = i + 1
        end
        pos = pos + 1
        while sub(s, pos, pos) ~= "}" do
            local k
            k, pos = unpack(s, pos)
            t[k], pos = unpack(s, pos)
        end
        return t, pos + 1
    end
    error("sealed data damaged at " .. pos)
end

function ns.Seal(value, salt)
    if not KEY then return nil end
    local out = {}
    pack(value, out)
    local body = concat(out)
    return encode(mix(sub(sha256(KEY .. salt .. body), 1, 8) .. body, salt))
end

function ns.Unseal(text, salt)
    if not KEY or type(text) ~= "string" then return nil end
    local plain = mix(decode(text), salt)
    if #plain < 9 then return nil end
    local body = sub(plain, 9)
    if sub(sha256(KEY .. salt .. body), 1, 8) ~= sub(plain, 1, 8) then return nil end
    local ok, value = pcall(function() return (unpack(body, 1)) end)
    return ok and value or nil
end

function ns.SealName(code)
    if not KEY then return nil end
    return "x" .. sub(TG.Crypto.Hex(sha256(KEY .. "name" .. code)), 1, 12)
end

function ns.OpenCatalog()
    local entries = ns.Catalog.entries
    local found, opened = 0, 0
    for i = #entries, 1, -1 do
        local e = entries[i]
        if e.sealed then
            found = found + 1
            local fields = ns.Unseal(e.sealed, e.code)
            if type(fields) == "table" and type(fields.code) == "string" then
                for k, v in pairs(fields) do e[k] = v end
                e.sealed = nil
                opened = opened + 1
            else
                table.remove(entries, i)
            end
        end
    end
    if found > 0 and opened < found then
        ns.sealed = false
        ns.off = true
    end
end
