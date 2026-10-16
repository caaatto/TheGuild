local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Loot = TG:GetModule("Loot")

local Reserves = {}
Loot.Reserves = Reserves

local function splitCSV(line)
    local fields, field, quoted = {}, "", false
    local i = 1
    while i <= #line do
        local c = line:sub(i, i)
        if quoted then
            if c == '"' then
                if line:sub(i + 1, i + 1) == '"' then
                    field = field .. '"'
                    i = i + 1
                else
                    quoted = false
                end
            else
                field = field .. c
            end
        elseif c == '"' then
            quoted = true
        elseif c == "," or c == ";" or c == "\t" then
            fields[#fields + 1] = field
            field = ""
        else
            field = field .. c
        end
        i = i + 1
    end
    fields[#fields + 1] = field
    return fields
end

-- Accepts the CSV export of softres.it or plain lines of "itemID name".
function Reserves:Parse(text)
    local reserves, count = {}, 0
    local idCol, nameCol, plusCol
    for _, line in ipairs(TG.Lines(text)) do
        local fields = splitCSV(line)
        local isHeader = false
        if not idCol then
            for i, f in ipairs(fields) do
                local h = TG.Trim(f):lower()
                if h == "itemid" or h == "item id" then idCol = i end
                if h == "name" or h == "player" or h == "character" then nameCol = i end
                if h == "plus" then plusCol = i end
            end
            isHeader = idCol ~= nil and nameCol ~= nil
            if not isHeader then idCol, nameCol, plusCol = nil, nil, nil end
        end
        if not isHeader then
            local id, name, plus
            if idCol then
                id, name = tonumber(TG.Trim(fields[idCol] or "")), fields[nameCol]
                plus = plusCol and tonumber(TG.Trim(fields[plusCol] or "")) or 0
            else
                local a, b = line:match("^(%d+)[,;%s]+(%a[^,;]-)%s*$")
                if a then
                    id, name = tonumber(a), b
                else
                    local n, i2 = line:match("^(%a[^,;]-)[,;%s]+(%d+)%s*$")
                    if n then id, name = tonumber(i2), n end
                end
                plus = 0
            end
            name = name and TG.Trim(name) or ""
            if id and name ~= "" then
                reserves[id] = reserves[id] or {}
                reserves[id][#reserves[id] + 1] = { name = name, plus = plus or 0 }
                count = count + 1
            end
        end
    end
    return reserves, count
end

function Reserves:Import(text)
    local reserves, count = self:Parse(text or "")
    Loot.cdb.reserves = reserves
    Loot.cdb.reservesTime = count > 0 and TG.Now() or 0
    TG:Fire("LOOT_SESSION")
    return count, TG.Count(reserves)
end

-- Display names for an item, with a plus suffix like "Anna+1".
function Reserves:Names(link)
    local id = tonumber((link or ""):match("item:(%d+)"))
    local list = id and Loot.cdb.reserves[id]
    if not list or #list == 0 then return nil end
    local out = {}
    for _, r in ipairs(list) do
        out[#out + 1] = (r.plus or 0) > 0 and (r.name .. "+" .. r.plus) or r.name
    end
    return out
end

function Reserves:Matches(names, player)
    if type(names) ~= "table" then return false end
    local first = TG.FirstName(player)
    if not first then return false end
    first = first:lower()
    for _, n in ipairs(names) do
        if type(n) == "string" and n:gsub("%+%d+$", ""):lower() == first then return true end
    end
    return false
end

function Reserves:Summary()
    local lines = {}
    for id, list in pairs(Loot.cdb.reserves) do
        for _, r in ipairs(list) do
            lines[#lines + 1] = ("%d %s"):format(id, r.name)
        end
    end
    table.sort(lines)
    return table.concat(lines, "\n")
end

function Reserves:OpenImport()
    UI.TextDialog(L["Soft reserves"], self:Summary(), function(text)
        local count, items = self:Import(text)
        TG:Print(L["%d reserves for %d items imported."], count, items)
    end, L["Paste the CSV export of softres.it. Empty text clears the list."])
end
