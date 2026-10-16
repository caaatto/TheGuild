local _, TG = ...
local L = TG.L

local Calendar = {}
TG.Calendar = Calendar

local WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local WEEKDAY_GLOBALS = { "WEEKDAY_SUNDAY", "WEEKDAY_MONDAY", "WEEKDAY_TUESDAY", "WEEKDAY_WEDNESDAY", "WEEKDAY_THURSDAY", "WEEKDAY_FRIDAY", "WEEKDAY_SATURDAY" }
local requested = false

function Calendar.WeekdayName(wday)
    local name = _G[WEEKDAY_GLOBALS[wday] or ""]
    return type(name) == "string" and name or WEEKDAYS[wday] or "?"
end

function Calendar.ServerTime()
    if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
        local c = C_DateAndTime.GetCurrentCalendarTime()
        if c and TG.usable(c.year) then
            return { year = c.year, month = c.month, day = c.monthDay, hour = c.hour, min = c.minute, wday = c.weekday }
        end
    end
    local d = date("*t")
    return { year = d.year, month = d.month, day = d.day, hour = d.hour, min = d.min, wday = d.wday }
end

function Calendar.Request()
    if requested or not (C_Calendar and C_Calendar.OpenCalendar) then return end
    requested = true
    C_Calendar.OpenCalendar()
end

local function monthOffset(year, month)
    local baseMonth, baseYear
    if C_Calendar and C_Calendar.GetMonthInfo then
        local info = C_Calendar.GetMonthInfo(0)
        if info and TG.usable(info.month) then baseMonth, baseYear = info.month, info.year end
    end
    if not baseMonth then
        local now = Calendar.ServerTime()
        baseMonth, baseYear = now.month, now.year
    end
    return (year - baseYear) * 12 + (month - baseMonth)
end

function Calendar.HasEvent(title, year, month, day)
    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) then return false end
    local offset = monthOffset(year, month)
    local n = C_Calendar.GetNumDayEvents(offset, day)
    if not TG.usable(n) then return false end
    for i = 1, n do
        local ev = C_Calendar.GetDayEvent(offset, day, i)
        if ev and TG.usable(ev.title) and ev.title == title then return true end
    end
    return false
end

function Calendar.CanAdd()
    if not (C_Calendar and C_Calendar.CreateGuildSignUpEvent and C_Calendar.AddEvent) then return false end
    if C_Calendar.CanAddEvent then
        local ok = C_Calendar.CanAddEvent()
        return TG.usable(ok) and ok == true
    end
    return true
end

function Calendar.Create(title, description, year, month, day, hour, minute)
    if not Calendar.CanAdd() then return false end
    local ok = pcall(function()
        C_Calendar.CreateGuildSignUpEvent()
        C_Calendar.EventSetTitle(title:sub(1, 31))
        C_Calendar.EventSetDescription(description or L["Created by TheGuild"])
        C_Calendar.EventSetDate(month, day, year)
        C_Calendar.EventSetTime(hour, minute)
        C_Calendar.AddEvent()
    end)
    return ok
end
