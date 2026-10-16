local _, TG = ...

local Roster = {}
TG.Roster = Roster

local members = {}
local list = {}
local byGUID = {}
local ready = false
local reading = false
local pending = false
local lastRead = 0
local demo = false
local demoGuild
local READ_GAP = 1.5
local REQUEST_INTERVAL = 60

local function newEntry(key)
    return { key = key }
end

local function lastOnline(i)
    if not GetGuildRosterLastOnline then return nil end
    local ok, years, months, days, hours = pcall(GetGuildRosterLastOnline, i)
    if not ok or TG.IsSecret(years, months, days, hours) or not years then return nil end
    local seconds = ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 86400 + (hours or 0) * 3600
    return TG.Now() - seconds
end

local function readRow(i)
    local name, rank, rankIndex, level, _, zone, note, officerNote, online, status, classFile, _, _, isMobile, _, _, guid = GetGuildRosterInfo(i)
    if not TG.usable(name) or TG.IsSecret(rank, rankIndex, level, zone, note, officerNote, online, status, classFile, guid) then
        return nil, true
    end
    local key = TG.StripRealm(name)
    if not key or key == "" then return nil end
    return {
        lastOnline = (not online) and lastOnline(i) or nil,
        key = key,
        fullName = name,
        guid = guid,
        rank = rank,
        rankIndex = rankIndex or 99,
        level = level or 0,
        classFile = classFile,
        zone = zone,
        note = note,
        officerNote = officerNote,
        online = online and true or false,
        status = status or 0,
        isMobile = isMobile and true or false,
    }
end

local function withOffline(fn)
    local flipped = false
    if GetGuildRosterShowOffline and SetGuildRosterShowOffline then
        local ok, shown = pcall(GetGuildRosterShowOffline)
        if ok and TG.usable(shown) and not shown then
            pcall(SetGuildRosterShowOffline, true)
            flipped = true
        end
    end
    local ok, err = pcall(fn)
    if flipped then pcall(SetGuildRosterShowOffline, false) end
    if not ok then error(err, 0) end
end

function Roster:SetDemo(entries, guildName)
    demo = true
    demoGuild = guildName
    members, list, byGUID = {}, {}, {}
    for _, e in ipairs(entries) do
        members[e.key] = e
        list[#list + 1] = e
        if e.guid then byGUID[e.guid] = e end
    end
    ready = true
    TG:Fire("ROSTER_UPDATED")
end

function Roster:ClearDemo()
    demo = false
    demoGuild = nil
    members, list, byGUID = {}, {}, {}
    ready = false
    self:Read()
end

function Roster:Read()
    if demo then return end
    if not IsInGuild() then
        if next(members) then
            members, list, byGUID = {}, {}, {}
            TG:Fire("ROSTER_UPDATED")
        end
        return
    end
    reading = true
    local total = GetNumGuildMembers()
    local fresh, freshList, freshGUID = {}, {}, {}
    local aborted = false
    withOffline(function()
        total = GetNumGuildMembers()
        if not TG.usable(total) then aborted = true return end
        for i = 1, total do
            local e, secret = readRow(i)
            if secret then aborted = true break end
            if e then
                fresh[e.key] = e
                freshList[#freshList + 1] = e
                if e.guid then freshGUID[e.guid] = e end
            end
        end
    end)
    reading = false
    lastRead = GetTime()
    if aborted or #freshList == 0 then return end

    local now = TG.Now()
    local me = TG.MyGUID()

    local renamed = {}
    local guildDB = TG:GuildDB()
    if guildDB then
        guildDB.guids = guildDB.guids or {}
        for key, e in pairs(fresh) do
            if e.guid then
                local previous = guildDB.guids[e.guid]
                if ready and previous and previous ~= key and not fresh[previous] and members[previous] then
                    renamed[key] = previous
                    renamed[previous] = key
                    local old = members[previous]
                    e.lastSeen = old.lastSeen
                    TG:Fire("MEMBER_RENAMED", e, previous)
                end
                guildDB.guids[e.guid] = key
            end
        end
    end

    for key, e in pairs(fresh) do
        local old = members[key]
        if e.online then
            e.lastSeen = now
        else
            e.lastSeen = (old and old.lastSeen) or e.lastOnline
            if e.lastOnline and (not e.lastSeen or e.lastOnline > e.lastSeen) then e.lastSeen = e.lastOnline end
        end
        if me and e.guid == me then TG.LearnMyName(e.key) end
        if ready then
            if not old then
                if not renamed[key] then TG:Fire("MEMBER_JOINED", e) end
            else
                if e.online and not old.online then TG:Fire("MEMBER_ONLINE", e) end
                if not e.online and old.online then TG:Fire("MEMBER_OFFLINE", e) end
                if e.level > (old.level or 0) and old.level > 0 then TG:Fire("MEMBER_LEVEL", e, old.level) end
                if e.rankIndex ~= old.rankIndex then TG:Fire("MEMBER_RANK", e, old.rankIndex) end
            end
        end
    end
    if ready then
        for key, old in pairs(members) do
            if not fresh[key] and not renamed[key] then TG:Fire("MEMBER_LEFT", old) end
        end
    end

    table.sort(freshList, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        return a.key < b.key
    end)
    members, list, byGUID = fresh, freshList, freshGUID
    local first = not ready
    ready = true
    if first then TG:Fire("ROSTER_READY") end
    TG:Fire("ROSTER_UPDATED")
end

local function scheduleRead()
    if pending then return end
    pending = true
    local wait = math.max(0.2, READ_GAP - (GetTime() - lastRead))
    TG.After(wait, function()
        pending = false
        Roster:Read()
    end)
end

function Roster:Request()
    if demo then return end
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end

function Roster:IsReady() return ready end
function Roster:Get(key) return key and members[TG.StripRealm(key) or key] end
function Roster:GetByGUID(guid) return guid and byGUID[guid] end
function Roster:Members() return list end
function Roster:All() return members end

function Roster:Find(name)
    if not name then return nil end
    local key = TG.StripRealm(name)
    if members[key] then return members[key] end
    local first = TG.FirstName(key)
    local found
    for k, e in pairs(members) do
        if TG.FirstName(k) == first then
            if found then return nil end
            found = e
        end
    end
    return found
end

function Roster:Counts()
    local online = 0
    for _, e in ipairs(list) do if e.online then online = online + 1 end end
    return #list, online
end

function Roster:Online()
    local out = {}
    for _, e in ipairs(list) do if e.online then out[#out + 1] = e end end
    return out
end

function Roster:MyEntry()
    local guid = TG.MyGUID()
    return (guid and byGUID[guid]) or members[TG.MyName()]
end

function Roster:GuildName()
    if demo then return demoGuild end
    local name = GetGuildInfo("player")
    return TG.usable(name) and name or nil
end

function Roster:OfficerRank()
    local v = TG.Store and TG.Store:Get("cfg", "officerRank")
    return tonumber(v) or 1
end

function Roster:IsGuildMaster(key)
    local e = self:Get(key)
    return e ~= nil and e.rankIndex == 0
end

function Roster:IsOfficer(key)
    local e = self:Get(key)
    return e ~= nil and e.rankIndex <= self:OfficerRank()
end

function Roster:AmGuildMaster()
    local leader = IsGuildLeader and IsGuildLeader()
    if TG.usable(leader) and leader then return true end
    local me = self:MyEntry()
    return me ~= nil and me.rankIndex == 0
end

function Roster:AmOfficer()
    if self:AmGuildMaster() then return true end
    local me = self:MyEntry()
    return me ~= nil and me.rankIndex <= self:OfficerRank()
end

function Roster:RankName(rankIndex)
    if GuildControlGetRankName then
        local ok, name = pcall(GuildControlGetRankName, rankIndex + 1)
        if ok and TG.usable(name) and name ~= "" then return name end
    end
    for _, e in ipairs(list) do
        if e.rankIndex == rankIndex then return e.rank end
    end
    return tostring(rankIndex)
end

function Roster:NumRanks()
    if GuildControlGetNumRanks then
        local ok, n = pcall(GuildControlGetNumRanks)
        if ok and TG.usable(n) and n > 0 then return n end
    end
    local max = 0
    for _, e in ipairs(list) do if e.rankIndex > max then max = e.rankIndex end end
    return max + 1
end

TG:RegisterEvent("GUILD_ROSTER_UPDATE", function()
    if reading then return end
    scheduleRead()
end)

TG:RegisterEvent("PLAYER_GUILD_UPDATE", function(_, unit)
    if unit and unit ~= "player" then return end
    local key = TG:GuildKey()
    if key ~= Roster.currentGuild then
        Roster.currentGuild = key
        members, list, byGUID, ready = {}, {}, {}, false
        TG:Fire("GUILD_CHANGED", key)
        Roster:Request()
    end
    scheduleRead()
end)

TG:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Roster.currentGuild = TG:GuildKey()
    Roster:Request()
    scheduleRead()
end)

TG.Ticker(REQUEST_INTERVAL, function() Roster:Request() end)
