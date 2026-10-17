local _, TG = ...

local Crypto = {}
TG.Crypto = Crypto

local floor, max = math.floor, math.max
local byte, char, rep, sub, format = string.byte, string.char, string.rep, string.sub, string.format
local concat, remove = table.concat, table.remove
local cocreate, coresume, costatus, coyield = coroutine.create, coroutine.resume, coroutine.status, coroutine.yield

local M32 = 4294967296
local M24 = 16777216
local INV24 = 1 / M24
local FOLD = 9728
local LIMBS = 11

local band, bor, bxor, bnot, rshift, lshift

if bit and bit.band then
    local b = bit
    band = function(x, y) return b.band(x, y) % M32 end
    bor = function(x, y) return b.bor(x, y) % M32 end
    bxor = function(x, y) return b.bxor(x, y) % M32 end
    bnot = function(x) return b.bnot(x) % M32 end
    rshift = function(x, n) return b.rshift(x, n) % M32 end
    lshift = function(x, n) return b.lshift(x, n) % M32 end
else
    local XOR, AND, OR = {}, {}, {}
    for i = 0, 15 do
        XOR[i], AND[i], OR[i] = {}, {}, {}
        for j = 0, 15 do
            local x, a, o, bitv, p, q = 0, 0, 0, 1, i, j
            for _ = 1, 4 do
                local pb, qb = p % 2, q % 2
                if pb ~= qb then x = x + bitv end
                if pb == 1 and qb == 1 then a = a + bitv end
                if pb == 1 or qb == 1 then o = o + bitv end
                p, q, bitv = (p - pb) / 2, (q - qb) / 2, bitv * 2
            end
            XOR[i][j], AND[i][j], OR[i][j] = x, a, o
        end
    end
    local function nibbles(fn)
        return function(x, y)
            x, y = x % M32, y % M32
            local out, mul = 0, 1
            for _ = 1, 8 do
                local xi, yi = x % 16, y % 16
                out = out + fn[xi][yi] * mul
                x, y, mul = (x - xi) / 16, (y - yi) / 16, mul * 16
            end
            return out
        end
    end
    band, bor, bxor = nibbles(AND), nibbles(OR), nibbles(XOR)
    bnot = function(x) return M32 - 1 - (x % M32) end
    rshift = function(x, n) return floor((x % M32) / 2 ^ n) end
    lshift = function(x, n) return ((x % M32) * 2 ^ n) % M32 end
end

local function rrot(x, n)
    return bor(rshift(x, n), lshift(x, 32 - n))
end

local K256 = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function be32(n)
    local a = n % 256
    n = (n - a) / 256
    local b = n % 256
    n = (n - b) / 256
    local c = n % 256
    return char((n - c) / 256, c, b, a)
end

function Crypto.sha256(msg)
    local len = #msg
    local bits = len * 8
    msg = msg .. "\128" .. rep("\0", (55 - len) % 64) .. be32(floor(bits / M32)) .. be32(bits % M32)
    local h0, h1, h2, h3, h4, h5, h6, h7 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local w = {}
    for chunk = 1, #msg, 64 do
        for i = 0, 15 do
            local p = chunk + i * 4
            local a, b, c, d = byte(msg, p, p + 3)
            w[i] = a * 16777216 + b * 65536 + c * 256 + d
        end
        for i = 16, 63 do
            local v = w[i - 15]
            local s0 = bxor(bxor(rrot(v, 7), rrot(v, 18)), rshift(v, 3))
            v = w[i - 2]
            local s1 = bxor(bxor(rrot(v, 17), rrot(v, 19)), rshift(v, 10))
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % M32
        end
        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 0, 63 do
            local S1 = bxor(bxor(rrot(e, 6), rrot(e, 11)), rrot(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local t1 = (h + S1 + ch + K256[i + 1] + w[i]) % M32
            local S0 = bxor(bxor(rrot(a, 2), rrot(a, 13)), rrot(a, 22))
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
            local t2 = (S0 + maj) % M32
            h, g, f, e, d, c, b, a = g, f, e, (d + t1) % M32, c, b, a, (t1 + t2) % M32
        end
        h0, h1, h2, h3 = (h0 + a) % M32, (h1 + b) % M32, (h2 + c) % M32, (h3 + d) % M32
        h4, h5, h6, h7 = (h4 + e) % M32, (h5 + f) % M32, (h6 + g) % M32, (h7 + h) % M32
    end
    return be32(h0) .. be32(h1) .. be32(h2) .. be32(h3) .. be32(h4) .. be32(h5) .. be32(h6) .. be32(h7)
end

local P2_1 = 2 * M24 - 2 * FOLD
local P2_2, P2_3, P2_4, P2_5, P2_6, P2_7, P2_8, P2_9, P2_10, P2_11 = 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2, 2 * M24 - 2

local function fadd(a, b)
    local t1 = a[1] + b[1]
    local t2 = a[2] + b[2]
    local t3 = a[3] + b[3]
    local t4 = a[4] + b[4]
    local t5 = a[5] + b[5]
    local t6 = a[6] + b[6]
    local t7 = a[7] + b[7]
    local t8 = a[8] + b[8]
    local t9 = a[9] + b[9]
    local t10 = a[10] + b[10]
    local t11 = a[11] + b[11]
    local c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    c = floor(t2 * INV24)
    t2 = t2 - c * M24
    t3 = t3 + c
    c = floor(t3 * INV24)
    t3 = t3 - c * M24
    t4 = t4 + c
    c = floor(t4 * INV24)
    t4 = t4 - c * M24
    t5 = t5 + c
    c = floor(t5 * INV24)
    t5 = t5 - c * M24
    t6 = t6 + c
    c = floor(t6 * INV24)
    t6 = t6 - c * M24
    t7 = t7 + c
    c = floor(t7 * INV24)
    t7 = t7 - c * M24
    t8 = t8 + c
    c = floor(t8 * INV24)
    t8 = t8 - c * M24
    t9 = t9 + c
    c = floor(t9 * INV24)
    t9 = t9 - c * M24
    t10 = t10 + c
    c = floor(t10 * INV24)
    t10 = t10 - c * M24
    t11 = t11 + c
    c = floor(t11 * INV24)
    t11 = t11 - c * M24
    t1 = t1 + c * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    return { t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 }
end

local function fsub(a, b)
    local t1 = a[1] + P2_1 - b[1]
    local t2 = a[2] + P2_2 - b[2]
    local t3 = a[3] + P2_3 - b[3]
    local t4 = a[4] + P2_4 - b[4]
    local t5 = a[5] + P2_5 - b[5]
    local t6 = a[6] + P2_6 - b[6]
    local t7 = a[7] + P2_7 - b[7]
    local t8 = a[8] + P2_8 - b[8]
    local t9 = a[9] + P2_9 - b[9]
    local t10 = a[10] + P2_10 - b[10]
    local t11 = a[11] + P2_11 - b[11]
    local c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    c = floor(t2 * INV24)
    t2 = t2 - c * M24
    t3 = t3 + c
    c = floor(t3 * INV24)
    t3 = t3 - c * M24
    t4 = t4 + c
    c = floor(t4 * INV24)
    t4 = t4 - c * M24
    t5 = t5 + c
    c = floor(t5 * INV24)
    t5 = t5 - c * M24
    t6 = t6 + c
    c = floor(t6 * INV24)
    t6 = t6 - c * M24
    t7 = t7 + c
    c = floor(t7 * INV24)
    t7 = t7 - c * M24
    t8 = t8 + c
    c = floor(t8 * INV24)
    t8 = t8 - c * M24
    t9 = t9 + c
    c = floor(t9 * INV24)
    t9 = t9 - c * M24
    t10 = t10 + c
    c = floor(t10 * INV24)
    t10 = t10 - c * M24
    t11 = t11 + c
    c = floor(t11 * INV24)
    t11 = t11 - c * M24
    t1 = t1 + c * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    return { t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 }
end

local function fneg(a)
    local t1 = P2_1 - a[1]
    local t2 = P2_2 - a[2]
    local t3 = P2_3 - a[3]
    local t4 = P2_4 - a[4]
    local t5 = P2_5 - a[5]
    local t6 = P2_6 - a[6]
    local t7 = P2_7 - a[7]
    local t8 = P2_8 - a[8]
    local t9 = P2_9 - a[9]
    local t10 = P2_10 - a[10]
    local t11 = P2_11 - a[11]
    local c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    c = floor(t2 * INV24)
    t2 = t2 - c * M24
    t3 = t3 + c
    c = floor(t3 * INV24)
    t3 = t3 - c * M24
    t4 = t4 + c
    c = floor(t4 * INV24)
    t4 = t4 - c * M24
    t5 = t5 + c
    c = floor(t5 * INV24)
    t5 = t5 - c * M24
    t6 = t6 + c
    c = floor(t6 * INV24)
    t6 = t6 - c * M24
    t7 = t7 + c
    c = floor(t7 * INV24)
    t7 = t7 - c * M24
    t8 = t8 + c
    c = floor(t8 * INV24)
    t8 = t8 - c * M24
    t9 = t9 + c
    c = floor(t9 * INV24)
    t9 = t9 - c * M24
    t10 = t10 + c
    c = floor(t10 * INV24)
    t10 = t10 - c * M24
    t11 = t11 + c
    c = floor(t11 * INV24)
    t11 = t11 - c * M24
    t1 = t1 + c * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    return { t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 }
end

local function fmul(a, b)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]
    local b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11 = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11]
    local t1 = a1 * b1
    local t2 = a1 * b2 + a2 * b1
    local t3 = a1 * b3 + a2 * b2 + a3 * b1
    local t4 = a1 * b4 + a2 * b3 + a3 * b2 + a4 * b1
    local t5 = a1 * b5 + a2 * b4 + a3 * b3 + a4 * b2 + a5 * b1
    local t6 = a1 * b6 + a2 * b5 + a3 * b4 + a4 * b3 + a5 * b2 + a6 * b1
    local t7 = a1 * b7 + a2 * b6 + a3 * b5 + a4 * b4 + a5 * b3 + a6 * b2 + a7 * b1
    local t8 = a1 * b8 + a2 * b7 + a3 * b6 + a4 * b5 + a5 * b4 + a6 * b3 + a7 * b2 + a8 * b1
    local t9 = a1 * b9 + a2 * b8 + a3 * b7 + a4 * b6 + a5 * b5 + a6 * b4 + a7 * b3 + a8 * b2 + a9 * b1
    local t10 = a1 * b10 + a2 * b9 + a3 * b8 + a4 * b7 + a5 * b6 + a6 * b5 + a7 * b4 + a8 * b3 + a9 * b2 + a10 * b1
    local t11 = a1 * b11 + a2 * b10 + a3 * b9 + a4 * b8 + a5 * b7 + a6 * b6 + a7 * b5 + a8 * b4 + a9 * b3 + a10 * b2 + a11 * b1
    local t12 = a2 * b11 + a3 * b10 + a4 * b9 + a5 * b8 + a6 * b7 + a7 * b6 + a8 * b5 + a9 * b4 + a10 * b3 + a11 * b2
    local t13 = a3 * b11 + a4 * b10 + a5 * b9 + a6 * b8 + a7 * b7 + a8 * b6 + a9 * b5 + a10 * b4 + a11 * b3
    local t14 = a4 * b11 + a5 * b10 + a6 * b9 + a7 * b8 + a8 * b7 + a9 * b6 + a10 * b5 + a11 * b4
    local t15 = a5 * b11 + a6 * b10 + a7 * b9 + a8 * b8 + a9 * b7 + a10 * b6 + a11 * b5
    local t16 = a6 * b11 + a7 * b10 + a8 * b9 + a9 * b8 + a10 * b7 + a11 * b6
    local t17 = a7 * b11 + a8 * b10 + a9 * b9 + a10 * b8 + a11 * b7
    local t18 = a8 * b11 + a9 * b10 + a10 * b9 + a11 * b8
    local t19 = a9 * b11 + a10 * b10 + a11 * b9
    local t20 = a10 * b11 + a11 * b10
    local t21 = a11 * b11
    local c = floor(t12 * INV24)
    t12 = t12 - c * M24
    t13 = t13 + c
    c = floor(t13 * INV24)
    t13 = t13 - c * M24
    t14 = t14 + c
    c = floor(t14 * INV24)
    t14 = t14 - c * M24
    t15 = t15 + c
    c = floor(t15 * INV24)
    t15 = t15 - c * M24
    t16 = t16 + c
    c = floor(t16 * INV24)
    t16 = t16 - c * M24
    t17 = t17 + c
    c = floor(t17 * INV24)
    t17 = t17 - c * M24
    t18 = t18 + c
    c = floor(t18 * INV24)
    t18 = t18 - c * M24
    t19 = t19 + c
    c = floor(t19 * INV24)
    t19 = t19 - c * M24
    t20 = t20 + c
    c = floor(t20 * INV24)
    t20 = t20 - c * M24
    t21 = t21 + c
    c = floor(t21 * INV24)
    t21 = t21 - c * M24
    local t22 = c
    t1 = t1 + t12 * FOLD
    t2 = t2 + t13 * FOLD
    t3 = t3 + t14 * FOLD
    t4 = t4 + t15 * FOLD
    t5 = t5 + t16 * FOLD
    t6 = t6 + t17 * FOLD
    t7 = t7 + t18 * FOLD
    t8 = t8 + t19 * FOLD
    t9 = t9 + t20 * FOLD
    t10 = t10 + t21 * FOLD
    t11 = t11 + t22 * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    c = floor(t2 * INV24)
    t2 = t2 - c * M24
    t3 = t3 + c
    c = floor(t3 * INV24)
    t3 = t3 - c * M24
    t4 = t4 + c
    c = floor(t4 * INV24)
    t4 = t4 - c * M24
    t5 = t5 + c
    c = floor(t5 * INV24)
    t5 = t5 - c * M24
    t6 = t6 + c
    c = floor(t6 * INV24)
    t6 = t6 - c * M24
    t7 = t7 + c
    c = floor(t7 * INV24)
    t7 = t7 - c * M24
    t8 = t8 + c
    c = floor(t8 * INV24)
    t8 = t8 - c * M24
    t9 = t9 + c
    c = floor(t9 * INV24)
    t9 = t9 - c * M24
    t10 = t10 + c
    c = floor(t10 * INV24)
    t10 = t10 - c * M24
    t11 = t11 + c
    c = floor(t11 * INV24)
    t11 = t11 - c * M24
    t1 = t1 + c * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    return { t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 }
end

local function fsq(a)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]
    local t1 = a1 * a1
    local t2 = 2 * a1 * a2
    local t3 = 2 * a1 * a3 + a2 * a2
    local t4 = 2 * a1 * a4 + 2 * a2 * a3
    local t5 = 2 * a1 * a5 + 2 * a2 * a4 + a3 * a3
    local t6 = 2 * a1 * a6 + 2 * a2 * a5 + 2 * a3 * a4
    local t7 = 2 * a1 * a7 + 2 * a2 * a6 + 2 * a3 * a5 + a4 * a4
    local t8 = 2 * a1 * a8 + 2 * a2 * a7 + 2 * a3 * a6 + 2 * a4 * a5
    local t9 = 2 * a1 * a9 + 2 * a2 * a8 + 2 * a3 * a7 + 2 * a4 * a6 + a5 * a5
    local t10 = 2 * a1 * a10 + 2 * a2 * a9 + 2 * a3 * a8 + 2 * a4 * a7 + 2 * a5 * a6
    local t11 = 2 * a1 * a11 + 2 * a2 * a10 + 2 * a3 * a9 + 2 * a4 * a8 + 2 * a5 * a7 + a6 * a6
    local t12 = 2 * a2 * a11 + 2 * a3 * a10 + 2 * a4 * a9 + 2 * a5 * a8 + 2 * a6 * a7
    local t13 = 2 * a3 * a11 + 2 * a4 * a10 + 2 * a5 * a9 + 2 * a6 * a8 + a7 * a7
    local t14 = 2 * a4 * a11 + 2 * a5 * a10 + 2 * a6 * a9 + 2 * a7 * a8
    local t15 = 2 * a5 * a11 + 2 * a6 * a10 + 2 * a7 * a9 + a8 * a8
    local t16 = 2 * a6 * a11 + 2 * a7 * a10 + 2 * a8 * a9
    local t17 = 2 * a7 * a11 + 2 * a8 * a10 + a9 * a9
    local t18 = 2 * a8 * a11 + 2 * a9 * a10
    local t19 = 2 * a9 * a11 + a10 * a10
    local t20 = 2 * a10 * a11
    local t21 = a11 * a11
    local c = floor(t12 * INV24)
    t12 = t12 - c * M24
    t13 = t13 + c
    c = floor(t13 * INV24)
    t13 = t13 - c * M24
    t14 = t14 + c
    c = floor(t14 * INV24)
    t14 = t14 - c * M24
    t15 = t15 + c
    c = floor(t15 * INV24)
    t15 = t15 - c * M24
    t16 = t16 + c
    c = floor(t16 * INV24)
    t16 = t16 - c * M24
    t17 = t17 + c
    c = floor(t17 * INV24)
    t17 = t17 - c * M24
    t18 = t18 + c
    c = floor(t18 * INV24)
    t18 = t18 - c * M24
    t19 = t19 + c
    c = floor(t19 * INV24)
    t19 = t19 - c * M24
    t20 = t20 + c
    c = floor(t20 * INV24)
    t20 = t20 - c * M24
    t21 = t21 + c
    c = floor(t21 * INV24)
    t21 = t21 - c * M24
    local t22 = c
    t1 = t1 + t12 * FOLD
    t2 = t2 + t13 * FOLD
    t3 = t3 + t14 * FOLD
    t4 = t4 + t15 * FOLD
    t5 = t5 + t16 * FOLD
    t6 = t6 + t17 * FOLD
    t7 = t7 + t18 * FOLD
    t8 = t8 + t19 * FOLD
    t9 = t9 + t20 * FOLD
    t10 = t10 + t21 * FOLD
    t11 = t11 + t22 * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    c = floor(t2 * INV24)
    t2 = t2 - c * M24
    t3 = t3 + c
    c = floor(t3 * INV24)
    t3 = t3 - c * M24
    t4 = t4 + c
    c = floor(t4 * INV24)
    t4 = t4 - c * M24
    t5 = t5 + c
    c = floor(t5 * INV24)
    t5 = t5 - c * M24
    t6 = t6 + c
    c = floor(t6 * INV24)
    t6 = t6 - c * M24
    t7 = t7 + c
    c = floor(t7 * INV24)
    t7 = t7 - c * M24
    t8 = t8 + c
    c = floor(t8 * INV24)
    t8 = t8 - c * M24
    t9 = t9 + c
    c = floor(t9 * INV24)
    t9 = t9 - c * M24
    t10 = t10 + c
    c = floor(t10 * INV24)
    t10 = t10 - c * M24
    t11 = t11 + c
    c = floor(t11 * INV24)
    t11 = t11 - c * M24
    t1 = t1 + c * FOLD
    c = floor(t1 * INV24)
    t1 = t1 - c * M24
    t2 = t2 + c
    return { t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 }
end

local function fcarry(t)
    for i = 1, LIMBS - 1 do
        local c = floor(t[i] * INV24)
        t[i] = t[i] - c * M24
        t[i + 1] = t[i + 1] + c
    end
    local c = floor(t[LIMBS] * INV24)
    t[LIMBS] = t[LIMBS] - c * M24
    t[1] = t[1] + c * FOLD
    c = floor(t[1] * INV24)
    t[1] = t[1] - c * M24
    t[2] = t[2] + c
    return t
end

local function fnew()
    return { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
end

local function fcopy(a)
    return { a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11] }
end

local function fsqn(a, n)
    for _ = 1, n do a = fsq(a) end
    return a
end

local function fpow250(z)
    local z2 = fsq(z)
    local z9 = fmul(fsqn(z2, 2), z)
    local z11 = fmul(z9, z2)
    local z5 = fmul(fsq(z11), z9)
    local z10 = fmul(fsqn(z5, 5), z5)
    local z20 = fmul(fsqn(z10, 10), z10)
    local z40 = fmul(fsqn(z20, 20), z20)
    local z50 = fmul(fsqn(z40, 10), z10)
    local z100 = fmul(fsqn(z50, 50), z50)
    local z200 = fmul(fsqn(z100, 100), z100)
    local z250 = fmul(fsqn(z200, 50), z50)
    return z250, z11
end

local function finv(z)
    local z250, z11 = fpow250(z)
    return fmul(fsqn(z250, 5), z11)
end

local function fpow22523(z)
    local z250 = fpow250(z)
    return fmul(fsqn(z250, 2), z)
end

local function ffreeze(a)
    local t = fcarry(fcopy(a))
    for _ = 1, 3 do
        local hi = floor(t[LIMBS] / 32768)
        if hi == 0 then break end
        t[LIMBS] = t[LIMBS] - hi * 32768
        t[1] = t[1] + hi * 19
        fcarry(t)
    end
    local top = t[LIMBS] == 32767 and t[1] >= M24 - 19
    for i = 2, LIMBS - 1 do
        if t[i] ~= M24 - 1 then top = false break end
    end
    if top then
        t[1] = t[1] - (M24 - 19)
        for i = 2, LIMBS do t[i] = 0 end
    end
    return t
end

local function fbytes(a)
    local t = ffreeze(a)
    local out = {}
    for i = 1, LIMBS do
        local l = t[i]
        local b1 = l % 256
        l = (l - b1) / 256
        local b2 = l % 256
        out[#out + 1] = char(b1, b2, (l - b2) / 256)
    end
    return sub(concat(out), 1, 32)
end

local function ffrombytes(s)
    local t = fnew()
    for i = 1, LIMBS - 1 do
        local p = (i - 1) * 3 + 1
        local a, b, c = byte(s, p, p + 2)
        t[i] = a + b * 256 + c * 65536
    end
    local a, b = byte(s, 31, 32)
    t[LIMBS] = a + (b % 128) * 256
    return t
end

local function fisodd(a)
    return ffreeze(a)[1] % 2 == 1
end

local function fequal(a, b)
    local x, y = ffreeze(a), ffreeze(b)
    for i = 1, LIMBS do
        if x[i] ~= y[i] then return false end
    end
    return true
end

local function fiszero(a)
    local x = ffreeze(a)
    for i = 1, LIMBS do
        if x[i] ~= 0 then return false end
    end
    return true
end

local function bigcarry(t)
    for i = 1, #t - 1 do
        local c = floor(t[i] * INV24)
        t[i] = t[i] - c * M24
        t[i + 1] = t[i + 1] + c
    end
    return t
end

local function bigfromdecimal(str, limbs)
    local t = {}
    for i = 1, limbs do t[i] = 0 end
    for i = 1, #str do
        local digit = byte(str, i) - 48
        for j = 1, limbs do t[j] = t[j] * 10 end
        t[1] = t[1] + digit
        bigcarry(t)
    end
    return t
end

local function ffromdecimal(str)
    return fcarry(bigfromdecimal(str, LIMBS))
end

local D = ffromdecimal("37095705934669439343138083508754565189542113879843219016388785533085940283555")
local D2 = fadd(D, D)
local SQRTM1 = ffromdecimal("19681161376707505956807079304988542015446066515923890162744021073123829784752")
local ONE = fnew()
ONE[1] = 1
local ZERO = fnew()
local L = bigfromdecimal("7237005577332262213973186563042994240857116359379907606001950938285454250989", LIMBS)

local running = false
local function pause()
    if running then coyield() end
end

local function pidentity()
    return { ZERO, fcopy(ONE), fcopy(ONE), ZERO }
end

local function pcached(p)
    return { fadd(p[2], p[1]), fsub(p[2], p[1]), fadd(p[3], p[3]), fmul(p[4], D2) }
end

local function paddc(p, q)
    local a = fmul(fsub(p[2], p[1]), q[2])
    local b = fmul(fadd(p[2], p[1]), q[1])
    local c = fmul(p[4], q[4])
    local d = fmul(p[3], q[3])
    local e, f, g, h = fsub(b, a), fsub(d, c), fadd(d, c), fadd(b, a)
    return { fmul(e, f), fmul(g, h), fmul(f, g), fmul(e, h) }
end

local function psubc(p, q)
    local a = fmul(fsub(p[2], p[1]), q[1])
    local b = fmul(fadd(p[2], p[1]), q[2])
    local c = fmul(p[4], q[4])
    local d = fmul(p[3], q[3])
    local e, f, g, h = fsub(b, a), fadd(d, c), fsub(d, c), fadd(b, a)
    return { fmul(e, f), fmul(g, h), fmul(f, g), fmul(e, h) }
end

local function padda(p, q)
    local a = fmul(fsub(p[2], p[1]), q[2])
    local b = fmul(fadd(p[2], p[1]), q[1])
    local c = fmul(p[4], q[3])
    local d = fadd(p[3], p[3])
    local e, f, g, h = fsub(b, a), fsub(d, c), fadd(d, c), fadd(b, a)
    return { fmul(e, f), fmul(g, h), fmul(f, g), fmul(e, h) }
end

local function psuba(p, q)
    local a = fmul(fsub(p[2], p[1]), q[1])
    local b = fmul(fadd(p[2], p[1]), q[2])
    local c = fmul(p[4], q[3])
    local d = fadd(p[3], p[3])
    local e, f, g, h = fsub(b, a), fadd(d, c), fsub(d, c), fadd(b, a)
    return { fmul(e, f), fmul(g, h), fmul(f, g), fmul(e, h) }
end

local function padd(p, q)
    return paddc(p, pcached(q))
end

local function pdouble(p)
    local a = fsq(p[1])
    local b = fsq(p[2])
    local c = fsq(p[3])
    c = fadd(c, c)
    local d = fneg(a)
    local e = fsub(fsub(fsq(fadd(p[1], p[2])), a), b)
    local g = fadd(d, b)
    local f = fsub(g, c)
    local h = fsub(d, b)
    return { fmul(e, f), fmul(g, h), fmul(f, g), fmul(e, h) }
end

local function pneg(p)
    return { fneg(p[1]), p[2], p[3], fneg(p[4]) }
end

local function pencode(p)
    local zi = finv(p[3])
    local x = fmul(p[1], zi)
    local y = fmul(p[2], zi)
    local s = fbytes(y)
    if fisodd(x) then
        local last = byte(s, 32)
        s = sub(s, 1, 31) .. char(last + 128)
    end
    return s
end

local function pdecode(s)
    if type(s) ~= "string" or #s ~= 32 then return nil end
    local y = ffrombytes(s)
    local sign = byte(s, 32) >= 128
    local y2 = fsq(y)
    local u = fsub(y2, ONE)
    local v = fadd(fmul(D, y2), ONE)
    local v3 = fmul(fsq(v), v)
    local v7 = fmul(fsq(v3), v)
    local x = fmul(fmul(u, v3), fpow22523(fmul(u, v7)))
    local check = fmul(v, fsq(x))
    if not fequal(check, u) then
        if fequal(check, fneg(u)) then
            x = fmul(x, SQRTM1)
        else
            return nil
        end
    end
    if fiszero(x) and sign then return nil end
    if fisodd(x) ~= sign then x = fneg(x) end
    return { x, y, fcopy(ONE), fmul(x, y) }
end

local BASE = {
    ffromdecimal("15112221349535400772501151409588531511454012693041857206046113283949847762202"),
    ffromdecimal("46316835694926478169428394003475163141307993866256225615783033603165251855960"),
}
BASE[3] = fcopy(ONE)
BASE[4] = fmul(BASE[1], BASE[2])

local WINDOWS = 65

local function affineTable(points)
    local n = #points
    local prefix = {}
    local acc = fcopy(ONE)
    for i = 1, n do
        acc = fmul(acc, points[i][3])
        prefix[i] = acc
        if i % 64 == 0 then pause() end
    end
    local inv = finv(acc)
    local out = {}
    for i = n, 1, -1 do
        local zi = i > 1 and fmul(inv, prefix[i - 1]) or inv
        inv = fmul(inv, points[i][3])
        local p = points[i]
        local x, y, t = fmul(p[1], zi), fmul(p[2], zi), fmul(p[4], zi)
        out[i] = { fadd(y, x), fsub(y, x), fmul(t, D2) }
        if i % 64 == 0 then pause() end
    end
    return out
end

local function buildComb(base)
    local points = {}
    local w = base
    for i = 1, WINDOWS do
        local wc = pcached(w)
        local m = w
        for k = 1, 8 do
            points[(i - 1) * 8 + k] = m
            if k < 8 then m = paddc(m, wc) end
        end
        w = pdouble(pdouble(pdouble(pdouble(w))))
        pause()
    end
    local affine = affineTable(points)
    local comb = {}
    for i = 1, WINDOWS do
        local row = {}
        for k = 1, 8 do row[k] = affine[(i - 1) * 8 + k] end
        comb[i] = row
    end
    return comb
end

local function combDigits(scalar)
    local e = {}
    for i = 1, 32 do
        local b = byte(scalar, i)
        local lo = b % 16
        e[2 * i - 1] = lo
        e[2 * i] = (b - lo) / 16
    end
    e[WINDOWS] = 0
    for i = 1, WINDOWS - 1 do
        if e[i] > 8 then
            e[i] = e[i] - 16
            e[i + 1] = e[i + 1] + 1
        end
    end
    return e
end

local function combMul(comb, scalar, negate, r)
    local e = combDigits(scalar)
    r = r or pidentity()
    for i = 1, WINDOWS do
        local d = e[i]
        if negate then d = -d end
        if d > 0 then
            r = padda(r, comb[i][d])
        elseif d < 0 then
            r = psuba(r, comb[i][-d])
        end
        if i % 16 == 0 then pause() end
    end
    return r
end

local baseComb

local function getBaseComb()
    if not baseComb then baseComb = buildComb(BASE) end
    return baseComb
end

local function naf(scalar)
    local r = {}
    for i = 1, 32 do
        local b = byte(scalar, i)
        for k = 0, 7 do
            local bitv = b % 2
            r[(i - 1) * 8 + k] = bitv
            b = (b - bitv) / 2
        end
    end
    r[256] = 0
    for i = 0, 255 do
        if r[i] ~= 0 then
            for b = 1, 4 do
                if i + b <= 255 and r[i + b] ~= 0 then
                    local v = r[i + b] * 2 ^ b
                    if r[i] + v <= 15 then
                        r[i] = r[i] + v
                        r[i + b] = 0
                    elseif r[i] - v >= -15 then
                        r[i] = r[i] - v
                        local k = i + b
                        while true do
                            if r[k] == 0 then
                                r[k] = 1
                                break
                            end
                            r[k] = 0
                            k = k + 1
                            if k > 256 then break end
                        end
                    else
                        break
                    end
                end
            end
        end
    end
    return r
end

local function nafTable(p)
    local t = { pcached(p) }
    local p2 = pcached(pdouble(p))
    local m = p
    for k = 2, 8 do
        m = paddc(m, p2)
        t[k] = pcached(m)
    end
    return t
end

local function nafMul(p, scalar)
    local t = nafTable(p)
    local digits = naf(scalar)
    local r = pidentity()
    for i = 256, 0, -1 do
        r = pdouble(r)
        local d = digits[i]
        if d > 0 then
            r = paddc(r, t[(d + 1) / 2])
        elseif d < 0 then
            r = psubc(r, t[(1 - d) / 2])
        end
        if i % 8 == 0 then pause() end
    end
    return r
end

local function bigfrombytes(s)
    local t = {}
    for i = 1, LIMBS do t[i] = 0 end
    for i = 1, 32 do
        local limb = floor((i - 1) / 3) + 1
        local shift = ((i - 1) % 3) * 8
        t[limb] = t[limb] + byte(s, i) * 2 ^ shift
    end
    return t
end

local function bigtobytes(t)
    local out = {}
    for i = 1, LIMBS do
        local l = t[i]
        local b1 = l % 256
        l = (l - b1) / 256
        local b2 = l % 256
        out[#out + 1] = char(b1, b2, (l - b2) / 256)
    end
    return sub(concat(out), 1, 32)
end

local function bigmul(a, b)
    local t = {}
    for i = 1, 2 * LIMBS do t[i] = 0 end
    for i = 1, LIMBS do
        local av = a[i]
        if av ~= 0 then
            for j = 1, LIMBS do
                local k = i + j - 1
                t[k] = t[k] + av * b[j]
            end
        end
    end
    return bigcarry(t)
end

local function bigadd(a, b)
    local t = {}
    for i = 1, max(#a, #b) do t[i] = (a[i] or 0) + (b[i] or 0) end
    t[#t + 1] = 0
    return bigcarry(t)
end

local function biggeq(a, b)
    for i = LIMBS, 1, -1 do
        if a[i] ~= b[i] then return a[i] > b[i] end
    end
    return true
end

local function bigsubL(a)
    local borrow = 0
    for i = 1, LIMBS do
        local v = a[i] - L[i] - borrow
        if v < 0 then
            v = v + M24
            borrow = 1
        else
            borrow = 0
        end
        a[i] = v
    end
end

local function bigmodL(x)
    local r = {}
    for i = 1, LIMBS do r[i] = 0 end
    for i = #x, 1, -1 do
        local limb = x[i]
        for bitpos = 23, 0, -1 do
            local pw = 2 ^ bitpos
            local bitv = floor(limb / pw)
            limb = limb - bitv * pw
            local carry = bitv
            for j = 1, LIMBS do
                local v = r[j] * 2 + carry
                if v >= M24 then
                    r[j] = v - M24
                    carry = 1
                else
                    r[j] = v
                    carry = 0
                end
            end
            if biggeq(r, L) then bigsubL(r) end
        end
        if i % 4 == 0 then pause() end
    end
    return r
end

local function clamp(s)
    local b1 = byte(s, 1)
    local b32 = byte(s, 32)
    return char(b1 - b1 % 8) .. sub(s, 2, 31) .. char(b32 % 64 + 64)
end

function Crypto.KeyPair(seed)
    local a = clamp(Crypto.sha256("TheGuild key" .. seed))
    local prefix = Crypto.sha256("TheGuild nonce" .. seed)
    local pub = pencode(combMul(getBaseComb(), a))
    return { a = a, prefix = prefix, pub = pub }
end

function Crypto.SignWith(key, msg)
    local r = Crypto.sha256(key.prefix .. msg)
    local R = pencode(combMul(getBaseComb(), r))
    local h = Crypto.sha256(R .. key.pub .. msg)
    local S = bigmodL(bigadd(bigmul(bigfrombytes(h), bigfrombytes(key.a)), bigfrombytes(r)))
    return R .. bigtobytes(S)
end

Crypto.cacheSize = 6
local combs = {}
local combOrder = {}
local decoded = {}

local function cachedComb(pub, point)
    local entry = combs[pub]
    if entry then
        entry.used = GetTime()
        return entry.comb
    end
    local comb = buildComb(point)
    combs[pub] = { comb = comb, used = GetTime() }
    combOrder[#combOrder + 1] = pub
    if #combOrder > Crypto.cacheSize then
        local oldest, at = nil, nil
        for i, key in ipairs(combOrder) do
            if not oldest or combs[key].used < combs[oldest].used then oldest, at = key, i end
        end
        combs[oldest] = nil
        remove(combOrder, at)
    end
    return comb
end

local function decodePub(pub)
    local point = decoded[pub]
    if point == nil then
        point = pdecode(pub) or false
        decoded[pub] = point
    end
    return point or nil
end

function Crypto.VerifyWith(pub, msg, sig, useComb)
    if type(sig) ~= "string" or #sig ~= 64 then return false end
    local A = decodePub(pub)
    if not A then return false end
    local R, S = sub(sig, 1, 32), sub(sig, 33, 64)
    if biggeq(bigfrombytes(S), L) then return false end
    local h = Crypto.sha256(R .. pub .. msg)
    local P
    if useComb or combs[pub] then
        P = combMul(cachedComb(pub, A), h, true, combMul(getBaseComb(), S))
    else
        P = padd(combMul(getBaseComb(), S), nafMul(pneg(A), h))
    end
    return pencode(P) == R
end

function Crypto.Hex(s)
    return (s:gsub(".", function(c) return format("%02x", byte(c)) end))
end

function Crypto.Unhex(h)
    if type(h) ~= "string" or #h % 2 == 1 or h:find("[^0-9a-fA-F]") then return nil end
    return (h:gsub("%x%x", function(x) return char(tonumber(x, 16)) end))
end

local jobs = {}
local queued = {}
local key
local waiting = {}
Crypto.budget = 4
Crypto.idleBudget = 10

local now = debugprofilestop or function() return GetTime() * 1000 end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, elapsed)
    local start = now()
    local budget = Crypto.budget
    if InCombatLockdown and InCombatLockdown() then
        budget = budget / 2
    elseif elapsed and elapsed < 0.012 then
        budget = Crypto.idleBudget
    end
    while jobs[1] and now() - start < budget do
        local job = jobs[1]
        running = true
        local ok, result = coresume(job.co)
        running = false
        if not ok then
            remove(jobs, 1)
            if job.pub then queued[job.pub] = queued[job.pub] - 1 end
            geterrorhandler()(result)
        elseif costatus(job.co) == "dead" then
            remove(jobs, 1)
            if job.pub then queued[job.pub] = queued[job.pub] - 1 end
            TG.SafeCall(job.cb, result)
        end
    end
    if not jobs[1] then driver:Hide() end
end)

local function enqueue(fn, cb, pub)
    if Crypto.sync then
        TG.SafeCall(cb, fn())
        return
    end
    jobs[#jobs + 1] = { co = cocreate(fn), cb = cb, pub = pub }
    if pub then queued[pub] = (queued[pub] or 0) + 1 end
    driver:Show()
end

function Crypto.Pending()
    return #jobs
end

function Crypto.HasKey()
    return key ~= nil
end

function Crypto.Public()
    return key and key.pub
end

function Crypto.SetSeed(seed, cb)
    enqueue(function() return Crypto.KeyPair(seed) end, function(pair)
        key = pair
        for _, w in ipairs(waiting) do Crypto.Sign(w[1], w[2]) end
        wipe(waiting)
        if cb then cb(pair.pub) end
    end)
end

function Crypto.Sign(msg, cb)
    if not key then
        waiting[#waiting + 1] = { msg, cb }
        return
    end
    local k = key
    enqueue(function() return Crypto.SignWith(k, msg) end, cb)
end

function Crypto.Verify(pub, msg, sig, cb)
    enqueue(function()
        return Crypto.VerifyWith(pub, msg, sig, (queued[pub] or 0) >= 3)
    end, cb, pub)
end

function Crypto.Warm(cb)
    enqueue(function() getBaseComb() return true end, cb or function() end)
end

function Crypto.Entropy(parts)
    local out = {}
    for i, v in ipairs(parts) do out[i] = tostring(v) end
    for _ = 1, 16 do out[#out + 1] = tostring(math.random()) end
    out[#out + 1] = tostring(now())
    out[#out + 1] = tostring(collectgarbage("count"))
    return Crypto.sha256(concat(out, "|") .. Crypto.sha256(concat(out, "#")))
end
