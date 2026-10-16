local TG = TheGuild
local L = TG.L

local NS_TEAM = "team"
local NS_ATT = "att"
local MAX_TEAMS = 9
local PARTY_LIMIT = 5

local Raids = TG:NewModule("Raids", {
    title = L["Raids"],
    desc = L["Raid teams with one click invites and attendance tracking."],
    order = 25,
    defaults = { snapshotMinutes = 5, attendanceDays = 10 },
    settings = {
        { key = "snapshotMinutes", type = "number", name = L["Attendance snapshot every (minutes)"], default = 5, min = 1, max = 15, step = 1 },
        { key = "attendanceDays", type = "number", name = L["Raid nights shown in attendance"], default = 10, min = 3, max = 30, step = 1 },
    },
})

TG.Store:DefinePolicy(NS_TEAM, "officer")
TG.Store:DefinePolicy(NS_ATT, "officer")

-- Teams

function Raids:Teams()
    local out = {}
    for id, item in pairs(TG.Store:Items(NS_TEAM)) do
        local v = item.v
        if type(v) == "table" then
            out[#out + 1] = { id = id, name = v.n or id, size = v.s or 20, members = v.m or {} }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Raids:Team(id)
    local v = TG.Store:Get(NS_TEAM, id)
    if type(v) ~= "table" then return nil end
    return { id = id, name = v.n or id, size = v.s or 20, members = v.m or {} }
end

function Raids:CanEdit()
    return TG.Store:CanWrite(NS_TEAM, "x")
end

function Raids:CreateTeam(name, size)
    if #self:Teams() >= MAX_TEAMS then return nil end
    name = TG.Trim(name):sub(1, 30)
    if name == "" then return nil end
    local id = "t" .. TG.Now() .. math.random(10, 99)
    if TG.Store:Set(NS_TEAM, id, { n = name, s = size or 20, m = {} }) then return id end
end

local function save(team)
    return TG.Store:Set(NS_TEAM, team.id, { n = team.name, s = team.size, m = team.members })
end

function Raids:RenameTeam(id, name)
    local team = self:Team(id)
    if not team then return false end
    team.name = TG.Trim(name):sub(1, 30)
    if team.name == "" then return false end
    return save(team)
end

function Raids:SetSize(id, size)
    local team = self:Team(id)
    if not team then return false end
    team.size = size
    return save(team)
end

function Raids:DeleteTeam(id)
    return TG.Store:Delete(NS_TEAM, id)
end

function Raids:AddMember(id, key)
    local team = self:Team(id)
    if not team or not TG.Roster:Get(key) then return false end
    for _, m in ipairs(team.members) do if m == key then return false end end
    if #team.members >= team.size then return false end
    team.members[#team.members + 1] = key
    return save(team)
end

function Raids:RemoveMember(id, key)
    local team = self:Team(id)
    if not team then return false end
    for i, m in ipairs(team.members) do
        if m == key then
            table.remove(team.members, i)
            return save(team)
        end
    end
    return false
end

-- Invites

local pendingInvites = {}

local function groupNames()
    local names = {}
    local n = GetNumGroupMembers()
    if not TG.usable(n) then return names end
    if IsInRaid() then
        for i = 1, n do
            local name = GetRaidRosterInfo(i)
            if TG.usable(name) then names[TG.StripRealm(name)] = true end
        end
    else
        for i = 1, n - 1 do
            local name = UnitName("party" .. i)
            if TG.usable(name) then names[TG.StripRealm(name)] = true end
        end
    end
    names[TG.MyName()] = true
    return names
end

local function sendInvites()
    if #pendingInvites == 0 then return end
    local inGroup = GetNumGroupMembers() > 0
    local room = IsInRaid() and 40 or PARTY_LIMIT
    local current = math.max(1, GetNumGroupMembers())
    if not IsInRaid() and inGroup and current + #pendingInvites > PARTY_LIMIT and C_PartyInfo.ConvertToRaid then
        C_PartyInfo.ConvertToRaid()
        return
    end
    while #pendingInvites > 0 and current < room do
        TG.Invite(table.remove(pendingInvites, 1))
        current = current + 1
    end
end

function Raids:InviteTeam(id)
    local team = self:Team(id)
    if not team then return 0 end
    local inGroup = groupNames()
    wipe(pendingInvites)
    for _, key in ipairs(team.members) do
        local e = TG.Roster:Get(key)
        if e and e.online and not inGroup[key] then pendingInvites[#pendingInvites + 1] = key end
    end
    local count = #pendingInvites
    sendInvites()
    return count
end

-- Attendance

local function today()
    return date("%Y-%m-%d")
end

function Raids:Snapshot()
    if not IsInRaid() then return end
    local leader = UnitIsGroupLeader("player")
    if not (TG.usable(leader) and leader) and not TG.Roster:AmOfficer() then return end
    if not TG.Store:CanWrite(NS_ATT, "x") then return end
    local present = {}
    local n = GetNumGroupMembers()
    if not TG.usable(n) then return end
    for i = 1, n do
        local name = GetRaidRosterInfo(i)
        if TG.usable(name) then
            local key = TG.StripRealm(name)
            if key and TG.Roster:Get(key) then present[key] = true end
        end
    end
    present[TG.MyName()] = true
    local key = today() .. "#" .. TG.MyName()
    local existing = TG.Store:Get(NS_ATT, key)
    local list = {}
    local seen = {}
    if type(existing) == "table" then
        for _, name in ipairs(existing.m or {}) do seen[name] = true list[#list + 1] = name end
    end
    local changed = existing == nil
    for name in pairs(present) do
        if not seen[name] then
            list[#list + 1] = name
            changed = true
        end
    end
    if not changed then return end
    table.sort(list)
    TG.Store:Set(NS_ATT, key, { m = list, z = TG.plain(GetZoneText(), "") })
    if existing == nil then TG.Log:Add("raid", TG.MyName(), { count = #list }) end
end

function Raids:RaidDays()
    local days = {}
    local seen = {}
    for key in pairs(TG.Store:Items(NS_ATT)) do
        local day = key:match("^(%d%d%d%d%-%d%d%-%d%d)#")
        if day and not seen[day] then
            seen[day] = true
            days[#days + 1] = day
        end
    end
    table.sort(days, function(a, b) return a > b end)
    return days
end

function Raids:PresentOn(day)
    local present = {}
    for key, item in pairs(TG.Store:Items(NS_ATT)) do
        if key:sub(1, #day) == day and type(item.v) == "table" then
            for _, name in ipairs(item.v.m or {}) do
                present[name] = true
                local main = TG.Store:Get("alt", name)
                if main then present[main] = true end
            end
        end
    end
    return present
end

function Raids:Attendance(limit)
    local days = self:RaidDays()
    while #days > limit do days[#days] = nil end
    local byDay = {}
    for _, day in ipairs(days) do byDay[day] = self:PresentOn(day) end
    local rows = {}
    for _, e in ipairs(TG.Roster:Members()) do
        if not TG.Store:Get("alt", e.key) then
            local count, last = 0, nil
            for _, day in ipairs(days) do
                if byDay[day][e.key] then
                    count = count + 1
                    if not last then last = day end
                end
            end
            if count > 0 then
                rows[#rows + 1] = { entry = e, count = count, total = #days, last = last, days = byDay }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.entry.key < b.entry.key
    end)
    return rows, days
end

function Raids:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function() sendInvites() end)
    self:Ticker(60 * self.db.snapshotMinutes, function() self:Snapshot() end)
end
