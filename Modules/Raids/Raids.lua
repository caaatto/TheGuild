local TG = TheGuild
local L = TG.L

local NS_TEAM = "team"
local NS_ATT = "att"
local MAX_TEAMS = 9
local PARTY_LIMIT = 5
local GROUP_SIZE = 5
local LFG_ROLE = { TANK = "T", HEALER = "H", DAMAGER = "D" }

local Raids = TG:NewModule("Raids", {
    title = L["Raids"],
    desc = L["Raid teams with invites, raid builder, schedule with calendar export and attendance tracking."],
    order = 25,
    defaults = { snapshotMinutes = 5, attendanceDays = 10, calendarWeeks = 4 },
    settings = {
        { key = "snapshotMinutes", type = "number", name = L["Attendance snapshot every (minutes)"], default = 5, min = 1, max = 15, step = 1 },
        { key = "attendanceDays", type = "number", name = L["Raid nights shown in attendance"], default = 10, min = 3, max = 30, step = 1 },
        { key = "calendarWeeks", type = "number", name = L["Weeks to export into the calendar"], default = 4, min = 1, max = 8, step = 1 },
    },
})

TG.Store:DefinePolicy(NS_TEAM, "officer")
TG.Store:DefinePolicy(NS_ATT, "officer")

function Raids:Teams()
    local out = {}
    for id, item in pairs(TG.Store:Items(NS_TEAM)) do
        local v = item.v
        if type(v) == "table" then
            out[#out + 1] = { id = id, name = v.n or id, size = v.s or 20, members = v.m or {}, groups = v.g or {}, days = v.d or {} }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Raids:Team(id)
    local v = TG.Store:Get(NS_TEAM, id)
    if type(v) ~= "table" then return nil end
    return { id = id, name = v.n or id, size = v.s or 20, members = v.m or {}, groups = v.g or {}, days = v.d or {} }
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
    return TG.Store:Set(NS_TEAM, team.id, { n = team.name, s = team.size, m = team.members, g = team.groups, d = team.days })
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
            team.groups[key] = nil
            return save(team)
        end
    end
    return false
end

function Raids:GroupCount(team)
    return math.max(1, math.floor(team.size / GROUP_SIZE))
end

function Raids:Roles(team)
    local raidRoles = {}
    if IsInRaid() and UnitGroupRolesAssigned then
        local n = GetNumGroupMembers()
        for i = 1, (TG.usable(n) and n or 0) do
            local name = GetRaidRosterInfo(i)
            local lfg = UnitGroupRolesAssigned("raid" .. i)
            if TG.usable(name) and TG.usable(lfg) then raidRoles[TG.StripRealm(name)] = LFG_ROLE[lfg] end
        end
    end
    local roles = {}
    for _, key in ipairs(team.members) do
        roles[key] = TG.Store:Get("role", key) or raidRoles[key]
    end
    return roles
end

function Raids:Layout(team)
    local groups = {}
    for g = 1, self:GroupCount(team) do groups[g] = {} end
    local unassigned = {}
    for _, key in ipairs(team.members) do
        local g = team.groups[key]
        if g and groups[g] and #groups[g] < GROUP_SIZE then
            groups[g][#groups[g] + 1] = key
        else
            unassigned[#unassigned + 1] = key
        end
    end
    return groups, unassigned
end

function Raids:RoleCounts(keys, roles)
    local counts = { T = 0, H = 0, D = 0, N = 0 }
    for _, key in ipairs(keys) do
        local role = roles[key]
        if not counts[role] then role = "N" end
        counts[role] = counts[role] + 1
    end
    return counts
end

function Raids:Assign(id, key, group)
    local team = self:Team(id)
    if not team then return false end
    local inTeam = false
    for _, m in ipairs(team.members) do if m == key then inTeam = true end end
    if not inTeam then return false end
    if group then
        if group < 1 or group > self:GroupCount(team) then return false end
        local groups = self:Layout(team)
        if #groups[group] >= GROUP_SIZE and team.groups[key] ~= group then return false end
    end
    team.groups[key] = group
    return save(team)
end

function Raids:ClearLayout(id)
    local team = self:Team(id)
    if not team then return false end
    team.groups = {}
    return save(team)
end

function Raids:AutoFill(id)
    local team = self:Team(id)
    if not team then return false end
    local groups, unassigned = self:Layout(team)
    if #unassigned == 0 then return false end
    local roles = self:Roles(team)
    local order = { T = 1, H = 2, D = 3 }
    table.sort(unassigned, function(a, b)
        local ra, rb = order[roles[a]] or 4, order[roles[b]] or 4
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    local changed = false
    for _, key in ipairs(unassigned) do
        local role = roles[key]
        local best, bestScore
        for g, members in ipairs(groups) do
            if #members < GROUP_SIZE then
                local counts = self:RoleCounts(members, roles)
                local score = (role and counts[role] or 0) * 100 + #members
                if not bestScore or score < bestScore then best, bestScore = g, score end
            end
        end
        if not best then break end
        groups[best][#groups[best] + 1] = key
        team.groups[key] = best
        changed = true
    end
    return changed and save(team)
end

function Raids:ApplyLayout(id, continuing)
    local team = self:Team(id)
    if not team or not IsInRaid() or not TG.IsGroupLead() or not SetRaidSubgroup then return 0 end
    local n = GetNumGroupMembers()
    if not TG.usable(n) then return 0 end
    local index, current, filled = {}, {}, {}
    for i = 1, n do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if TG.usable(name) and TG.usable(subgroup) then
            local key = TG.StripRealm(name)
            index[key] = i
            current[key] = subgroup
            filled[subgroup] = (filled[subgroup] or 0) + 1
        end
    end
    local moves = 0
    for _, key in ipairs(team.members) do
        local target = team.groups[key]
        local i = index[key]
        if target and i and current[key] ~= target then
            if (filled[target] or 0) < GROUP_SIZE then
                SetRaidSubgroup(i, target)
                filled[target] = (filled[target] or 0) + 1
                filled[current[key]] = filled[current[key]] - 1
                current[key] = target
                moves = moves + 1
            elseif SwapRaidSubgroup then
                for other, g in pairs(current) do
                    if g == target and team.groups[other] ~= target then
                        SwapRaidSubgroup(i, index[other])
                        current[other], current[key] = current[key], target
                        moves = moves + 1
                        break
                    end
                end
            end
        end
    end
    if moves > 0 and not continuing then
        self.applying = { id = id, passes = 3 }
    end
    return moves
end

function Raids:ContinueApply()
    local a = self.applying
    if not a then return end
    a.passes = a.passes - 1
    if a.passes <= 0 or self:ApplyLayout(a.id, true) == 0 then self.applying = nil end
end

local pendingInvites = {}

local groupNames = TG.GroupMembers

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

local MAX_DAYS = 7

function Raids:WeekdayName(wday)
    return TG.Calendar.WeekdayName(wday)
end

function Raids:ServerTime()
    return TG.Calendar.ServerTime()
end

function Raids:Schedule(team)
    local out = {}
    for i, d in ipairs(team.days) do out[#out + 1] = { index = i, w = d.w, h = d.h, m = d.m } end
    table.sort(out, function(a, b)
        local wa, wb = (a.w + 5) % 7, (b.w + 5) % 7
        if wa ~= wb then return wa < wb end
        return a.h * 60 + a.m < b.h * 60 + b.m
    end)
    return out
end

function Raids:AddRaidDay(id, wday, hour, minute)
    local team = self:Team(id)
    if not team or wday < 1 or wday > 7 or #team.days >= MAX_DAYS then return false end
    for _, d in ipairs(team.days) do
        if d.w == wday and d.h == hour and d.m == minute then return false end
    end
    team.days[#team.days + 1] = { w = wday, h = hour, m = minute }
    return save(team)
end

function Raids:RemoveRaidDay(id, index)
    local team = self:Team(id)
    if not team or not team.days[index] then return false end
    table.remove(team.days, index)
    return save(team)
end

function Raids:Upcoming(team, weeks)
    local now = self:ServerTime()
    local base = time({ year = now.year, month = now.month, day = now.day, hour = 12 })
    local nowMinutes = now.hour * 60 + now.min
    local out = {}
    for _, d in ipairs(team.days) do
        for offset = 0, weeks * 7 - 1 do
            local day = date("*t", base + offset * 86400)
            if day.wday == d.w and (offset > 0 or d.h * 60 + d.m > nowMinutes) then
                out[#out + 1] = {
                    team = team, year = day.year, month = day.month, day = day.day, wday = day.wday,
                    hour = d.h, min = d.m, order = offset * 1440 + d.h * 60 + d.m,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

function Raids:NextRaid()
    local best
    for _, team in ipairs(self:Teams()) do
        local first = self:Upcoming(team, 2)[1]
        if first and (not best or first.order < best.order) then best = first end
    end
    return best
end

function Raids:FormatRaid(r, withTeam)
    local text = ("%s %02d.%02d. %02d:%02d"):format(self:WeekdayName(r.wday), r.day, r.month, r.hour, r.min)
    if withTeam then text = text .. "  " .. r.team.name end
    return text
end

function Raids:CalendarTitle(team)
    return L["Raid: %s"]:format(team.name):sub(1, 31)
end

function Raids:InCalendar(r)
    return TG.Calendar.HasEvent(self:CalendarTitle(r.team), r.year, r.month, r.day)
end

function Raids:CanExport()
    return TG.Calendar.CanAdd()
end

function Raids:ExportCalendar(id, weeks)
    local team = self:Team(id)
    if not team or not self:CanExport() then return 0, 0 end
    local title = self:CalendarTitle(team)
    local created, existing = 0, 0
    for _, r in ipairs(self:Upcoming(team, weeks)) do
        if self:InCalendar(r) then
            existing = existing + 1
        elseif TG.Calendar.Create(title, L["Created by TheGuild"], r.year, r.month, r.day, r.hour, r.min) then
            created = created + 1
        end
    end
    return created, existing
end

function Raids:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function() sendInvites() self:ContinueApply() end)
    self:Ticker(60 * self.db.snapshotMinutes, function() self:Snapshot() end)
end
