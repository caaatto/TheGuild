local TG = TheGuild
local L = TG.L

local NS_POST, NS_POLL, NS_VOTE = "post", "poll", "vote"
local MAX_TITLE, MAX_BODY = 60, 1500
local MAX_QUESTION, MAX_OPTIONS, MAX_OPTION = 120, 8, 60
local FRESH = 600

local Board = TG:NewModule("Board", {
    title = L["Board"],
    desc = L["Guild bulletin board, polls, events and bounties, shared through the guild store."],
    order = 28,
    defaults = { chat = true, days = 30 },
    settings = {
        { key = "chat", type = "boolean", name = L["Announce new posts and polls in chat"], default = true },
        { key = "days", type = "number", name = L["Show posts of the last days"], default = 30, min = 7, max = 90, step = 1 },
    },
})

TG.Store:DefinePolicy(NS_POST, "own", 180 * 86400)
TG.Store:DefinePolicy(NS_POLL, "officer", 180 * 86400)
TG.Store:DefinePolicy(NS_VOTE, "own", 180 * 86400)

local function authorOf(key)
    return key:match("^(.-)#") or key
end

function Board:Posts()
    local cutoff = TG.Now() - self.db.days * 86400
    local out = {}
    for key, item in pairs(TG.Store:Items(NS_POST)) do
        local v = item.v
        if type(v) == "table" and (v.p == true or (v.ts or 0) >= cutoff) then
            out[#out + 1] = { key = key, author = authorOf(key), title = v.t or "", body = v.b or "", pinned = v.p == true, time = v.ts or item.t or 0 }
        end
    end
    table.sort(out, function(a, b)
        if a.pinned ~= b.pinned then return a.pinned end
        if a.time ~= b.time then return a.time > b.time end
        return a.key < b.key
    end)
    return out
end

function Board:CanPost()
    return TG.InGuild() and TG.Store:CanWrite(NS_POST, TG.MyName() .. "#x")
end

function Board:CanManage()
    return TG.Roster:AmOfficer()
end

function Board:CanEditPost(post)
    return post.author == TG.MyName() or self:CanManage()
end

function Board:Post(title, body)
    title = TG.Trim(title or ""):sub(1, MAX_TITLE)
    body = TG.Trim(body or ""):sub(1, MAX_BODY)
    if title == "" then return nil end
    local now = TG.Now()
    local key = TG.MyName() .. "#" .. now
    if not TG.Store:Set(NS_POST, key, { t = title, b = body, ts = now }) then return nil end
    TG.Log:Add("post", TG.MyName(), { title = title })
    return key
end

function Board:DeletePost(key)
    return TG.Store:Delete(NS_POST, key)
end

function Board:SetPinned(key, pinned)
    local v = TG.Store:Get(NS_POST, key)
    if type(v) ~= "table" or not self:CanManage() then return false end
    return TG.Store:Set(NS_POST, key, { t = v.t, b = v.b, ts = v.ts, p = pinned and true or nil })
end

function Board:Prune()
    if not self:CanManage() then return end
    local cutoff = TG.Now() - self.db.days * 2 * 86400
    local removed = 0
    for key, item in pairs(TG.Store:Items(NS_POST)) do
        local v = item.v
        if type(v) == "table" and v.p ~= true and (v.ts or 0) < cutoff and removed < 10 then
            TG.Store:Delete(NS_POST, key)
            removed = removed + 1
        end
    end
end

function Board:Polls()
    local out = {}
    for key, item in pairs(TG.Store:Items(NS_POLL)) do
        local v = item.v
        if type(v) == "table" and type(v.o) == "table" then
            out[#out + 1] = { key = key, author = item.a, question = v.q or "", options = v.o, closed = v.c == true, time = v.ts or item.t or 0 }
        end
    end
    table.sort(out, function(a, b)
        if a.closed ~= b.closed then return b.closed end
        if a.time ~= b.time then return a.time > b.time end
        return a.key < b.key
    end)
    return out
end

function Board:CreatePoll(question, options)
    question = TG.Trim(question or ""):sub(1, MAX_QUESTION)
    local clean = {}
    for _, o in ipairs(options or {}) do
        o = TG.Trim(o):sub(1, MAX_OPTION)
        if o ~= "" and #clean < MAX_OPTIONS then clean[#clean + 1] = o end
    end
    if question == "" or #clean < 2 then return nil end
    local now = TG.Now()
    local key = "p" .. now .. math.random(10, 99)
    if not TG.Store:Set(NS_POLL, key, { q = question, o = clean, ts = now }) then return nil end
    TG.Log:Add("poll", TG.MyName(), { title = question })
    return key
end

function Board:ClosePoll(key, closed)
    local v = TG.Store:Get(NS_POLL, key)
    if type(v) ~= "table" then return false end
    return TG.Store:Set(NS_POLL, key, { q = v.q, o = v.o, ts = v.ts, c = closed and true or nil })
end

function Board:DeletePoll(key)
    if not TG.Store:Delete(NS_POLL, key) then return false end
    local suffix = "#" .. key
    for vkey in pairs(TG.Store:Items(NS_VOTE)) do
        if vkey:sub(-#suffix) == suffix then TG.Store:Delete(NS_VOTE, vkey) end
    end
    return true
end

function Board:Vote(pollKey, option)
    local poll = TG.Store:Get(NS_POLL, pollKey)
    if type(poll) ~= "table" or poll.c or type(poll.o) ~= "table" or not poll.o[option] then return false end
    return TG.Store:Set(NS_VOTE, TG.MyName() .. "#" .. pollKey, option)
end

function Board:MyVote(pollKey)
    return TG.Store:Get(NS_VOTE, TG.MyName() .. "#" .. pollKey)
end

function Board:Results(poll)
    local counts, total, voters = {}, 0, {}
    for i = 1, #poll.options do counts[i] = 0 voters[i] = {} end
    local suffix = "#" .. poll.key
    for vkey, item in pairs(TG.Store:Items(NS_VOTE)) do
        local opt = item.v
        if type(opt) == "number" and counts[opt] and vkey:sub(-#suffix) == suffix then
            counts[opt] = counts[opt] + 1
            total = total + 1
            voters[opt][#voters[opt] + 1] = vkey:sub(1, #vkey - #suffix)
        end
    end
    for _, list in ipairs(voters) do table.sort(list) end
    return counts, total, voters
end

function Board:OnStoreChanged(ns, key, value)
    if type(value) ~= "table" or TG.Now() - (value.ts or 0) > FRESH then return end
    if ns == NS_POST then
        local author = authorOf(key)
        if TG.IsMe(author) then return end
        TG.Log:Add("post", author, { title = value.t })
        if self.db.chat then TG:Print(L["New post on the guild board: %s (%s)"], value.t or "", TG.ShortName(author)) end
    elseif ns == "event" then
        local author = authorOf(key)
        if TG.IsMe(author) then return end
        TG.Log:Add("event", author, { title = value.t })
        if self.db.chat then TG:Print(L["New event: %s (%s)"], value.t or "", TG.ShortName(author)) end
    elseif ns == "bounty" then
        self:OnBountyChanged(key, value)
    elseif ns == NS_POLL then
        local item = TG.Store:Items(NS_POLL)[key]
        local author = item and item.a or "?"
        if TG.IsMe(author) or value.c then return end
        TG.Log:Add("poll", author, { title = value.q })
        if self.db.chat then TG:Print(L["New poll: %s (%s)"], value.q or "", TG.ShortName(author)) end
    end
end

function Board:OnEnable()
    self:On("STORE_CHANGED", function(ns, key, value) self:OnStoreChanged(ns, key, value) end)
    TG.After(90, function()
        if not self.enabled then return end
        self:Prune()
        if self.PruneEvents then self:PruneEvents() end
        if self.PruneBounties then self:PruneBounties() end
    end)
end
