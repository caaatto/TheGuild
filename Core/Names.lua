local _, TG = ...

local myName
local myGUID

function TG.StripRealm(name)
    if type(name) ~= "string" then return nil end
    local bare = name:match("^([^%-]+)")
    return bare and TG.Trim(bare) or nil
end

TG.Key = TG.StripRealm

function TG.FirstName(name)
    name = TG.StripRealm(name)
    return name and name:match("^(%S+)") or name
end

function TG.MyGUID()
    if not myGUID then
        local guid = UnitGUID("player")
        if TG.usable(guid) then myGUID = guid end
    end
    return myGUID
end

function TG.LearnMyName(name)
    name = TG.StripRealm(name)
    if name and name ~= "" then
        myName = name
        if TG.cdb then TG.cdb.myName = name end
    end
end

function TG.ForgetMyName()
    myName = nil
    if TG.cdb then TG.cdb.myName = nil end
end

function TG.MyName()
    if myName then return myName end
    if TG.cdb and TG.cdb.myName then
        myName = TG.cdb.myName
        return myName
    end
    if UnitFullName then
        local first, second = UnitFullName("player")
        if TG.usable(first) and TG.usable(second) and second ~= "" and second ~= GetNormalizedRealmName() then
            return first .. " " .. second
        end
        if TG.usable(first) then return first end
    end
    return TG.plain(UnitName("player"), "")
end

function TG.IsMe(name)
    name = TG.StripRealm(name)
    if not name then return false end
    local me = TG.MyName()
    if name == me then return true end
    return TG.FirstName(me) == name and not me:find(" ", 1, true)
end

function TG.Address(name)
    name = TG.StripRealm(name)
    return name
end

function TG.ShortName(name)
    return TG.FirstName(name) or "?"
end
