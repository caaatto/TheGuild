local TG = TheGuild
local L = TG.L
local Board = TG:GetModule("Board")

local NS_BOUNTY, NS_CLAIM = "bounty", "claim"
local MAX_TITLE, MAX_REWARD, MAX_DESC = 60, 60, 1000
local KEEP_DONE = 14 * 86400

TG.Store:DefinePolicy(NS_BOUNTY, "own", 90 * 86400, TG.Store.Shape({ t = "string", r = "string", b = "string?", ts = "number", d = "boolean?", w = "string?", dt = "number?" }))
TG.Store:DefinePolicy(NS_CLAIM, "own", 90 * 86400, TG.Store.Number(0))

local function authorOf(key)
    return key:match("^(.-)#") or key
end

function Board:Bounties()
    local cutoff = TG.Now() - KEEP_DONE
    local out = {}
    for key, item in pairs(TG.Store:Items(NS_BOUNTY)) do
        local v = item.v
        if type(v) == "table" and (not v.d or (v.dt or 0) >= cutoff) then
            out[#out + 1] = {
                key = key, author = authorOf(key), title = v.t or "", reward = v.r or "", desc = v.b or "",
                done = v.d == true, winner = v.w, time = v.ts or item.t or 0, doneTime = v.dt,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.done ~= b.done then return b.done end
        if a.time ~= b.time then return a.time > b.time end
        return a.key < b.key
    end)
    return out
end

function Board:CreateBounty(title, reward, desc)
    title = TG.Trim(title or ""):sub(1, MAX_TITLE)
    reward = TG.Trim(reward or ""):sub(1, MAX_REWARD)
    desc = TG.Trim(desc or ""):sub(1, MAX_DESC)
    if title == "" or reward == "" then return nil end
    local now = TG.Now()
    local key = TG.MyName() .. "#" .. now
    if not TG.Store:Set(NS_BOUNTY, key, { t = title, r = reward, b = desc, ts = now }) then return nil end
    TG.Log:Add("bounty", TG.MyName(), { title = title })
    return key
end

function Board:CanEditBounty(bounty)
    return bounty.author == TG.MyName() or self:CanManage()
end

function Board:DeleteBounty(key)
    if not TG.Store:Delete(NS_BOUNTY, key) then return false end
    local suffix = "#" .. key
    for ckey in pairs(TG.Store:Items(NS_CLAIM)) do
        if ckey:sub(-#suffix) == suffix then TG.Store:Delete(NS_CLAIM, ckey) end
    end
    return true
end

function Board:Claim(key)
    local v = TG.Store:Get(NS_BOUNTY, key)
    if type(v) ~= "table" or v.d or authorOf(key) == TG.MyName() then return false end
    return TG.Store:Set(NS_CLAIM, TG.MyName() .. "#" .. key, TG.Now())
end

function Board:Unclaim(key)
    return TG.Store:Delete(NS_CLAIM, TG.MyName() .. "#" .. key)
end

function Board:MyClaim(key)
    return TG.Store:Get(NS_CLAIM, TG.MyName() .. "#" .. key) ~= nil
end

function Board:Claimers(bounty)
    local out = {}
    local suffix = "#" .. bounty.key
    for ckey, item in pairs(TG.Store:Items(NS_CLAIM)) do
        if ckey:sub(-#suffix) == suffix then
            out[#out + 1] = { name = ckey:sub(1, #ckey - #suffix), time = tonumber(item.v) or item.t or 0 }
        end
    end
    table.sort(out, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        return a.name < b.name
    end)
    return out
end

function Board:CompleteBounty(key, winner)
    local v = TG.Store:Get(NS_BOUNTY, key)
    if type(v) ~= "table" or v.d then return false end
    if authorOf(key) ~= TG.MyName() and not self:CanManage() then return false end
    if not TG.Store:Set(NS_BOUNTY, key, { t = v.t, r = v.r, b = v.b, ts = v.ts, d = true, w = winner, dt = TG.Now() }) then return false end
    TG.Log:Add("bounty", winner or TG.MyName(), { title = v.t, done = true })
    return true
end

function Board:ReopenBounty(key)
    local v = TG.Store:Get(NS_BOUNTY, key)
    if type(v) ~= "table" or not v.d then return false end
    if authorOf(key) ~= TG.MyName() and not self:CanManage() then return false end
    return TG.Store:Set(NS_BOUNTY, key, { t = v.t, r = v.r, b = v.b, ts = v.ts })
end

function Board:OpenBountyCount()
    local n = 0
    for _, b in ipairs(self:Bounties()) do
        if not b.done then n = n + 1 end
    end
    return n
end

function Board:OnBountyChanged(key, value)
    local item = TG.Store:Item(NS_BOUNTY, key)
    if item and TG.IsMe(item.a) then return end
    local author = authorOf(key)
    local now = TG.Now()
    if value.d then
        if now - (value.dt or 0) > 600 then return end
        TG.Log:Add("bounty", value.w or author, { title = value.t, done = true })
        if self.db.chat and value.w then TG:Print(L["Bounty completed by %s: %s"], TG.ShortName(value.w), value.t or "") end
    else
        if now - (value.ts or 0) > 600 then return end
        TG.Log:Add("bounty", author, { title = value.t })
        if self.db.chat then TG:Print(L["New bounty: %s, reward %s (%s)"], value.t or "", value.r or "", TG.ShortName(author)) end
    end
end

function Board:PruneBounties()
    if not self:CanManage() then return end
    local cutoff = TG.Now() - KEEP_DONE * 2
    local removed = 0
    for key, item in pairs(TG.Store:Items(NS_BOUNTY)) do
        local v = item.v
        if type(v) == "table" and v.d and (v.dt or 0) < cutoff and removed < 10 then
            self:DeleteBounty(key)
            removed = removed + 1
        end
    end
end
