local _, TG = ...
local L = TG.L

local issecret = issecretvalue

function TG.usable(v)
    if v == nil then return false end
    if issecret and issecret(v) then return false end
    return true
end

function TG.IsSecret(...)
    if not issecret then return false end
    for i = 1, select("#", ...) do
        if issecret((select(i, ...))) then return true end
    end
    return false
end

function TG.plain(v, fallback)
    if TG.usable(v) then return v end
    return fallback
end

function TG:Print(msg, ...)
    if select("#", ...) > 0 then msg = tostring(msg):format(...) end
    DEFAULT_CHAT_FRAME:AddMessage(TG.color .. "TheGuild:|r " .. tostring(msg))
end

function TG:Debug(msg, ...)
    if not (TG.db and TG.db.global.debug) then return end
    if select("#", ...) > 0 then msg = tostring(msg):format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888TG:|r " .. tostring(msg))
end

function TG.SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
    return ok
end

function TG.After(delay, fn)
    C_Timer.After(delay, function() TG.SafeCall(fn) end)
end

function TG.Ticker(interval, fn)
    return C_Timer.NewTicker(interval, function(t) TG.SafeCall(fn, t) end)
end

function TG.Now()
    return GetServerTime()
end

function TG.InGuild()
    return IsInGuild() or (TG.Demo ~= nil and TG.Demo.active == true)
end

function TG.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function TG.Count(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

function TG.CopyTable(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = TG.CopyTable(v) end
    return out
end

function TG.Merge(dst, defaults)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            dst[k] = TG.Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function TG.Keys(t, sortFn)
    local out = {}
    for k in pairs(t or {}) do out[#out + 1] = k end
    table.sort(out, sortFn)
    return out
end

function TG.Round(v, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(v * m + 0.5) / m
end

function TG.Clamp(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function TG.VersionNewer(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local a1, a2, a3 = a:match("^(%d+)%.(%d+)%.(%d+)")
    local b1, b2, b3 = b:match("^(%d+)%.(%d+)%.(%d+)")
    if not a1 or not b1 then return false end
    local pa, pb = { tonumber(a1), tonumber(a2), tonumber(a3) }, { tonumber(b1), tonumber(b2), tonumber(b3) }
    for i = 1, 3 do
        if pa[i] ~= pb[i] then return pa[i] > pb[i] end
    end
    return false
end

function TG.FormatAge(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds < 5 then return L["just now"] end
    if seconds < 60 then return L["%ds"]:format(seconds) end
    if seconds < 3600 then return L["%dm"]:format(math.floor(seconds / 60)) end
    if seconds < 86400 then return L["%dh"]:format(math.floor(seconds / 3600)) end
    return L["%dd"]:format(math.floor(seconds / 86400))
end

function TG.FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function hasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end
TG.HasAtlas = hasAtlas

function TG.ClassColor(classFile)
    local c = classFile and (C_ClassColor and C_ClassColor.GetClassColor(classFile) or RAID_CLASS_COLORS[classFile])
    return c or NORMAL_FONT_COLOR
end

function TG.ClassHex(classFile)
    local c = TG.ClassColor(classFile)
    if c.GenerateHexColor then return "|c" .. c:GenerateHexColor() end
    return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

function TG.ClassText(classFile, text)
    return TG.ClassHex(classFile) .. tostring(text) .. "|r"
end

function TG.ClassName(classFile)
    return classFile and (LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile) or ""
end

function TG.ClassIconMarkup(classFile, size)
    size = size or 14
    if not classFile then return "" end
    local atlas = ("classicon-%s"):format(classFile:lower())
    if hasAtlas(atlas) then
        return ("|A:%s:%d:%d|a"):format(atlas, size, size)
    end
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if c then
        return ("|TInterface\\TargetingFrame\\UI-Classes-Circles:%d:%d:0:0:256:256:%d:%d:%d:%d|t"):format(
            size, size, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
    end
    return ""
end

function TG.SetClassIcon(texture, classFile)
    local atlas = classFile and ("classicon-%s"):format(classFile:lower())
    if atlas and hasAtlas(atlas) then
        texture:SetAtlas(atlas)
        return true
    end
    local c = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    if c then
        texture:SetTexCoord(c[1], c[2], c[3], c[4])
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
    return c ~= nil
end

local ROLE_ATLAS = { T = "roleicon-tiny-tank", H = "roleicon-tiny-healer", D = "roleicon-tiny-dps" }
local ROLE_LFG = { T = "TANK", H = "HEALER", D = "DAMAGER" }
TG.ROLE_NAMES = { T = L["Tank"], H = L["Healer"], D = L["Damage"] }
TG.ROLE_ORDER = { "T", "H", "D" }

function TG.RoleIconMarkup(role, size)
    size = size or 14
    if not role or not ROLE_ATLAS[role] then return "" end
    if hasAtlas(ROLE_ATLAS[role]) then
        return ("|A:%s:%d:%d|a"):format(ROLE_ATLAS[role], size, size)
    end
    if GetTexCoordsForRoleSmallCircle then
        local l, r, t, b = GetTexCoordsForRoleSmallCircle(ROLE_LFG[role])
        return ("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:0:64:64:%d:%d:%d:%d|t"):format(
            size, size, l * 64, r * 64, t * 64, b * 64)
    end
    return ""
end

function TG.Whisper(name)
    local fn = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if fn then fn(TG.Address(name)) end
end

function TG.InsertLink(link)
    local fn = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if fn and link then fn(link) end
end

function TG.Invite(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(TG.Address(name))
    elseif InviteUnit then
        InviteUnit(TG.Address(name))
    end
end

function TG.AddChatFilter(event, fn)
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then add(event, fn) return true end
    return false
end

function TG.RemoveChatFilter(event, fn)
    local remove = (ChatFrameUtil and ChatFrameUtil.RemoveMessageEventFilter) or ChatFrame_RemoveMessageEventFilter
    if remove then remove(event, fn) end
end

function TG.RaidWarning(text)
    if RaidWarningUtil and RaidWarningUtil.AddMessage then
        local ok = pcall(RaidWarningUtil.AddMessage, text, ChatTypeInfo["RAID_WARNING"])
        if ok then return end
    end
    if RaidWarningFrame and RaidWarningFrame.AddMessage then
        local ok = pcall(RaidWarningFrame.AddMessage, RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
        if ok then return end
    end
    UIErrorsFrame:AddMessage(text, 1, 0.3, 0.3)
end

function TG.SetWaypoint(mapID, x, y)
    if not (mapID and x and y and C_Map.SetUserWaypoint and UiMapPoint) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return false end
    local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
    if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return ok
end

function TG.GroupMembers()
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

function TG.UnitForName(name)
    local first = TG.FirstName(name)
    if not first then return nil end
    first = first:lower()
    local n = GetNumGroupMembers()
    if not TG.usable(n) then return nil end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, n do
        local unit = prefix .. i
        local uname = UnitName(unit)
        if TG.usable(uname) and uname and TG.FirstName(uname):lower() == first then return unit end
    end
    return nil
end

function TG.InGroup(key)
    return TG.GroupMembers()[TG.StripRealm(key) or key] == true
end

function TG.IsGroupLead()
    local lead = UnitIsGroupLeader("player")
    if TG.usable(lead) and lead then return true end
    local assist = UnitIsGroupAssistant and UnitIsGroupAssistant("player")
    return TG.usable(assist) and assist == true
end

function TG.PlayerLink(name)
    return ("|Hplayer:%s|h[%s]|h"):format(name, name)
end

function TG.MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or L["Unknown"]
end

function TG.Lines(text)
    local out = {}
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        line = TG.Trim(line)
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end
