local _, TG = ...
local L = TG.L

-- Guild event log, kept per guild on this client. Not synced.

local Log = {}
TG.Log = Log

local MAX_ENTRIES = 500

Log.KINDS = { "online", "offline", "joined", "left", "rejoined", "renamed", "level", "rank", "death", "cta", "note", "raid", "found", "post", "poll" }

local function entries()
    local g = TG:GuildDB()
    if not g then return nil end
    g.log = g.log or {}
    return g.log
end

function Log:Add(kind, name, extra)
    local list = entries()
    if not list then return end
    local item = { kind = kind, name = name, t = TG.Now() }
    if extra then
        for k, v in pairs(extra) do item[k] = v end
    end
    table.insert(list, 1, item)
    for i = #list, MAX_ENTRIES + 1, -1 do list[i] = nil end
    TG:Fire("LOG_ADDED", item)
end

function Log:Entries(filter)
    local list = entries() or {}
    if not filter then return list end
    local out = {}
    for _, item in ipairs(list) do
        if filter(item) then out[#out + 1] = item end
    end
    return out
end

function Log:Text(item)
    local name = item.name or "?"
    local entry = TG.Roster:Get(name)
    local colored = entry and TG.ClassText(entry.classFile, name) or name
    local kind = item.kind
    if kind == "online" then return L["%s came online"]:format(colored) end
    if kind == "offline" then return L["%s went offline"]:format(colored) end
    if kind == "joined" then return L["%s joined the guild"]:format(colored) end
    if kind == "rejoined" then return L["%s rejoined the guild"]:format(colored) end
    if kind == "left" then return L["%s left the guild"]:format(colored) end
    if kind == "level" then return L["%s reached level %d"]:format(colored, item.level or 0) end
    if kind == "rank" then return L["%s is now %s"]:format(colored, item.rank or "?") end
    if kind == "death" then return L["%s died in %s"]:format(colored, item.zone or L["Unknown"]) end
    if kind == "cta" then return L["%s calls to arms in %s"]:format(colored, item.zone or "") end
    if kind == "note" then return L["Note of %s changed"]:format(colored) end
    if kind == "renamed" then return L["%s was renamed to %s"]:format(item.from or "?", colored) end
    if kind == "found" then
        local text = L["%s found %s"]:format(colored, item.link or "?")
        local bind = TG:GetModule("Loot") and TG:GetModule("Loot").Finds and TG:GetModule("Loot").Finds.BindText(item.bind)
        if bind then text = text .. " (" .. bind .. ")" end
        return text
    end
    if kind == "raid" then return L["Raid night recorded with %d members"]:format(item.count or 0) end
    if kind == "post" then return L["%s posted on the board: %s"]:format(colored, item.title or "") end
    if kind == "poll" then return L["%s started a poll: %s"]:format(colored, item.title or "") end
    return colored
end

function Log:PlainText(item)
    return (self:Text(item):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A:[^|]*|a", ""):gsub("|T[^|]*|t", ""))
end

function Log:Export(filter)
    local lines = {}
    for _, item in ipairs(self:Entries(filter)) do
        lines[#lines + 1] = date("%Y-%m-%d %H:%M", item.t) .. "  " .. self:PlainText(item)
    end
    return table.concat(lines, "\n")
end

function Log:Clear()
    local g = TG:GuildDB()
    if g then g.log = {} end
    TG:Fire("LOG_ADDED")
end

TG:On("MEMBER_ONLINE", function(e) Log:Add("online", e.key) end)
TG:On("MEMBER_OFFLINE", function(e) Log:Add("offline", e.key) end)
TG:On("MEMBER_JOINED", function(e) Log:Add("joined", e.key, { level = e.level }) end)
TG:On("MEMBER_LEFT", function(e) Log:Add("left", e.key, { level = e.level, rank = e.rank }) end)
TG:On("MEMBER_LEVEL", function(e) Log:Add("level", e.key, { level = e.level }) end)
TG:On("MEMBER_RENAMED", function(e, oldKey) Log:Add("renamed", e.key, { from = oldKey }) end)
TG:On("MEMBER_RANK", function(e, oldRank) Log:Add("rank", e.key, { rank = e.rank, from = oldRank, to = e.rankIndex }) end)
TG:On("ACTIVITY", function(kind, name, data)
    if kind == "death" then
        Log:Add("death", name, { zone = data and data.z })
    elseif kind == "cta" then
        Log:Add("cta", name, { zone = data and data.z })
    end
end)
