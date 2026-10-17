local TG = TheGuild
local L = TG.L
local Board = TG:GetModule("Board")

local NS_EVENT, NS_SIGNUP = "event", "signup"
local MAX_TITLE, MAX_DESC = 60, 1000
local KEEP_PAST = 86400

TG.Store:DefinePolicy(NS_EVENT, "own", 60 * 86400)
TG.Store:DefinePolicy(NS_SIGNUP, "own", 60 * 86400)

local function authorOf(key)
    return key:match("^(.-)#") or key
end

local function stamp(v)
    return time({ year = v.y, month = v.m, day = v.d, hour = v.h or 0, min = v.mi or 0 })
end

function Board:Events()
    local now = TG.Calendar.ServerTime()
    local nowStamp = time({ year = now.year, month = now.month, day = now.day, hour = now.hour, min = now.min })
    local out = {}
    for key, item in pairs(TG.Store:Items(NS_EVENT)) do
        local v = item.v
        if type(v) == "table" and tonumber(v.y) and tonumber(v.m) and tonumber(v.d) then
            local at = stamp(v)
            if at >= nowStamp - KEEP_PAST then
                out[#out + 1] = {
                    key = key, author = authorOf(key), title = v.t or "", desc = v.b or "",
                    year = v.y, month = v.m, day = v.d, hour = v.h or 0, min = v.mi or 0,
                    at = at, wday = date("*t", at).wday, past = at < nowStamp,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.key < b.key
    end)
    return out
end

function Board:ParseEventDate(text)
    text = TG.Trim(text or "")
    local d, m, y, h, mi = text:match("^(%d%d?)%.(%d%d?)%.(%d%d%d%d)%s+(%d%d?):(%d%d)$")
    if not d then
        d, m, h, mi = text:match("^(%d%d?)%.(%d%d?)%.?%s+(%d%d?):(%d%d)$")
        if d then
            local now = TG.Calendar.ServerTime()
            y = now.year
            if tonumber(m) < now.month or (tonumber(m) == now.month and tonumber(d) < now.day) then y = y + 1 end
        end
    end
    if not d then return nil end
    return tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(mi)
end

function Board:CreateEvent(title, desc, year, month, day, hour, minute)
    title = TG.Trim(title or ""):sub(1, MAX_TITLE)
    desc = TG.Trim(desc or ""):sub(1, MAX_DESC)
    if title == "" or not (year and month and day and hour and minute) then return nil end
    if month < 1 or month > 12 or day < 1 or day > 31 or hour < 0 or hour > 23 or minute < 0 or minute > 59 then return nil end
    local now = TG.Now()
    local key = TG.MyName() .. "#" .. now
    if not TG.Store:Set(NS_EVENT, key, { t = title, b = desc, y = year, m = month, d = day, h = hour, mi = minute, ts = now }) then return nil end
    TG.Log:Add("event", TG.MyName(), { title = title })
    return key
end

function Board:CanEditEvent(ev)
    return ev.author == TG.MyName() or self:CanManage()
end

function Board:DeleteEvent(key)
    if not TG.Store:Delete(NS_EVENT, key) then return false end
    local suffix = "#" .. key
    for skey in pairs(TG.Store:Items(NS_SIGNUP)) do
        if skey:sub(-#suffix) == suffix then TG.Store:Delete(NS_SIGNUP, skey) end
    end
    return true
end

function Board:SignUp(eventKey, status)
    if type(TG.Store:Get(NS_EVENT, eventKey)) ~= "table" or not (status == 1 or status == 2 or status == 3) then return false end
    return TG.Store:Set(NS_SIGNUP, TG.MyName() .. "#" .. eventKey, status)
end

function Board:MySignup(eventKey)
    return TG.Store:Get(NS_SIGNUP, TG.MyName() .. "#" .. eventKey)
end

function Board:Signups(ev)
    local lists = { {}, {}, {} }
    local suffix = "#" .. ev.key
    for skey, item in pairs(TG.Store:Items(NS_SIGNUP)) do
        local status = item.v
        if type(status) == "number" and lists[status] and skey:sub(-#suffix) == suffix then
            lists[status][#lists[status] + 1] = skey:sub(1, #skey - #suffix)
        end
    end
    for _, list in ipairs(lists) do table.sort(list) end
    return lists
end

function Board:FormatEvent(ev, withTitle)
    local text = ("%s %02d.%02d. %02d:%02d"):format(TG.Calendar.WeekdayName(ev.wday), ev.day, ev.month, ev.hour, ev.min)
    if withTitle then text = text .. "  " .. ev.title end
    return text
end

function Board:NextEvent()
    for _, ev in ipairs(self:Events()) do
        if not ev.past then return ev end
    end
    return nil
end

function Board:ExportEvent(ev)
    if TG.Calendar.HasEvent(ev.title:sub(1, 31), ev.year, ev.month, ev.day) then return false, true end
    local description = ev.desc ~= "" and ev.desc or L["Created by TheGuild"]
    return TG.Calendar.Create(ev.title, description, ev.year, ev.month, ev.day, ev.hour, ev.min), false
end

function Board:PruneEvents()
    if not self:CanManage() then return end
    local cutoff = TG.Now() - 7 * 86400
    local removed = 0
    for key, item in pairs(TG.Store:Items(NS_EVENT)) do
        local v = item.v
        if type(v) == "table" and tonumber(v.y) and stamp(v) < cutoff and removed < 10 then
            self:DeleteEvent(key)
            removed = removed + 1
        end
    end
end
