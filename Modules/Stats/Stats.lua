local TG = TheGuild
local L = TG.L
local UI = TG.UI

local NS_STAT = "stat"
local DAY = 86400
local TOP = 5

local Stats = TG:NewModule("Stats", {
    title = L["Statistics"],
    desc = L["Guild statistics: members, classes, levels, deaths, loot and raids."],
    order = 29,
    defaults = { rankings = true },
    charDefaults = { optIn = true },
    settings = {
        { key = "rankings", type = "boolean", name = L["Show member rankings"], default = true },
        { key = "optIn", scope = "char", type = "boolean", name = L["List this character in guild rankings"], default = true,
          onChange = function(mod, value) mod:PublishOptIn(value) end },
    },
})

TG.Store:DefinePolicy(NS_STAT, "self")

function Stats:PublishOptIn(value)
    if not IsInGuild() then return end
    if value then
        TG.Store:Delete(NS_STAT, TG.MyName())
    else
        TG.Store:Set(NS_STAT, TG.MyName(), 0)
    end
end

function Stats:Listed(name)
    return TG.Store:Get(NS_STAT, name) ~= 0
end

local function header(rows, text)
    rows[#rows + 1] = { kind = "header", text = text }
end

local function bar(rows, label, value, max, color)
    rows[#rows + 1] = { kind = "bar", label = label, value = value, max = max, color = color }
end

local function text(rows, label, value)
    rows[#rows + 1] = { kind = "text", label = label, value = value }
end

local function top(counts, limit, allowed)
    local list = {}
    for key, n in pairs(counts) do
        if not allowed or allowed(key) then list[#list + 1] = { key = key, n = n } end
    end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.key < b.key
    end)
    while #list > limit do list[#list] = nil end
    return list
end

local function memberLabel(key)
    local e = TG.Roster:Get(key)
    return e and TG.ClassText(e.classFile, key) or key
end

function Stats:Collect()
    local rows = {}
    local now = TG.Now()
    local members = TG.Roster:Members()
    local total, online, active7, active30, capped, levelSum = #members, 0, 0, 0, 0, 0
    local classes, brackets = {}, { 0, 0, 0, 0 }
    for _, e in ipairs(members) do
        if e.online then online = online + 1 end
        local seen = e.online and now or e.lastSeen or e.lastOnline
        if seen and now - seen <= 7 * DAY then active7 = active7 + 1 end
        if seen and now - seen <= 30 * DAY then active30 = active30 + 1 end
        local level = e.level or 0
        levelSum = levelSum + level
        if level >= 60 then capped = capped + 1 end
        local b = level >= 60 and 4 or level >= 40 and 3 or level >= 20 and 2 or 1
        brackets[b] = brackets[b] + 1
        if e.classFile then classes[e.classFile] = (classes[e.classFile] or 0) + 1 end
    end
    local joined, left = 0, 0
    for _, item in pairs(TG.Store:Items("hist")) do
        if type(item.v) == "table" and (item.v.f or 0) >= now - 30 * DAY then joined = joined + 1 end
    end
    for _, item in pairs(TG.Store:Items("gone")) do
        if type(item.v) == "table" and (item.v.t or 0) >= now - 30 * DAY then left = left + 1 end
    end
    header(rows, L["Members"])
    text(rows, L["Members"], total)
    text(rows, L["Online now"], online)
    text(rows, L["Active in the last 7 days"], active7)
    text(rows, L["Active in the last 30 days"], active30)
    text(rows, L["Average level"], total > 0 and ("%.1f"):format(levelSum / total) or "0")
    text(rows, L["Level 60"], capped)
    text(rows, L["Joined in the last 30 days"], joined)
    text(rows, L["Left in the last 30 days"], left)

    header(rows, L["Classes"])
    for _, c in ipairs(top(classes, 20)) do
        bar(rows, TG.ClassText(c.key, TG.ClassName(c.key)), c.n, total, TG.ClassColor(c.key))
    end

    header(rows, L["Levels"])
    local names = { "1 - 19", "20 - 39", "40 - 59", "60" }
    for i, n in ipairs(brackets) do bar(rows, names[i], n, total) end

    local deaths, byZone, byMember = 0, {}, {}
    for key, item in pairs(TG.Store:Items("death")) do
        local v = item.v
        if type(v) == "table" then
            deaths = deaths + 1
            local zone = (v.z and v.z ~= "") and v.z or L["Unknown"]
            byZone[zone] = (byZone[zone] or 0) + 1
            local who = key:match("^(.-)#") or item.a or "?"
            byMember[who] = (byMember[who] or 0) + 1
        end
    end
    local listed = function(key) return self:Listed(key) end
    header(rows, L["Deaths"])
    text(rows, L["Deaths shared"], deaths)
    for _, z in ipairs(top(byZone, TOP)) do bar(rows, z.key, z.n, deaths) end
    if self.db.rankings then
        for _, m in ipairs(top(byMember, TOP, listed)) do bar(rows, memberLabel(m.key), m.n, deaths, { r = 0.8, g = 0.3, b = 0.3 }) end
    end

    local ups, upsBy = 0, {}
    for _, item in ipairs(TG.Log:Entries(function(i) return i.kind == "level" end)) do
        if (item.t or 0) >= now - 30 * DAY then
            ups = ups + 1
            upsBy[item.name] = (upsBy[item.name] or 0) + 1
        end
    end
    header(rows, L["Level ups in the last 30 days"])
    text(rows, L["Level ups"], ups)
    if self.db.rankings then
        for _, m in ipairs(top(upsBy, TOP, listed)) do bar(rows, memberLabel(m.key), m.n, ups) end
    end

    local awards, byWinner = 0, {}
    for _, item in pairs(TG.Store:Items("loot")) do
        local v = item.v
        if type(v) == "table" and v.w then
            awards = awards + 1
            byWinner[v.w] = (byWinner[v.w] or 0) + 1
        end
    end
    header(rows, L["Loot"])
    text(rows, L["Awards"], awards)
    if self.db.rankings then
        for _, m in ipairs(top(byWinner, TOP, listed)) do bar(rows, memberLabel(m.key), m.n, awards) end
    end

    local nights, present, nightCount = {}, 0, 0
    for key, item in pairs(TG.Store:Items("att")) do
        local day = key:match("^(%d%d%d%d%-%d%d%-%d%d)#")
        if day and type(item.v) == "table" then
            nights[day] = math.max(nights[day] or 0, #(item.v.m or {}))
        end
    end
    for _, n in pairs(nights) do
        nightCount = nightCount + 1
        present = present + n
    end
    header(rows, L["Raids"])
    text(rows, L["Raid nights recorded"], nightCount)
    text(rows, L["Average members per raid night"], nightCount > 0 and ("%.1f"):format(present / nightCount) or "0")
    return rows
end

local function plain(s)
    return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function Stats:Export()
    local lines = {}
    for _, row in ipairs(self:Collect()) do
        if row.kind == "header" then
            if #lines > 0 then lines[#lines + 1] = "" end
            lines[#lines + 1] = row.text
        elseif row.kind == "bar" then
            local pct = (row.max or 0) > 0 and math.floor(row.value / row.max * 100 + 0.5) or 0
            lines[#lines + 1] = ("  %s: %d (%d%%)"):format(plain(row.label), row.value, pct)
        else
            lines[#lines + 1] = ("  %s: %s"):format(plain(row.label), tostring(row.value))
        end
    end
    return table.concat(lines, "\n")
end

function Stats:OnEnable()
    if not self.cdb.optIn then
        TG.After(30, function() if self.enabled then self:PublishOptIn(false) end end)
    end
end

local BAR_W = 300

local function build(panel)
    local info = UI.Label(panel, L["Numbers come from the roster and the shared guild data on this client."], "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
    local export = UI.Button(panel, L["Export"], 80, function() UI.TextDialog(L["Statistics"], Stats:Export()) end)
    export:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -34)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)

    local list = UI.List(listFrame, 20, function(button, row)
        if row.kind == "header" then
            button.label:SetFontObject("GameFontNormal")
            button.label:SetText(row.text)
            button.value:SetText("")
            button.bar:Hide()
            return
        end
        button.label:SetFontObject("GameFontHighlightSmall")
        button.label:SetText("    " .. row.label)
        if row.kind == "bar" then
            local pct = (row.max or 0) > 0 and row.value / row.max or 0
            button.bar:SetWidth(math.max(1, BAR_W * pct))
            local c = row.color
            if c and c.r then button.bar:SetVertexColor(c.r, c.g, c.b, 0.8) else button.bar:SetVertexColor(0.3, 0.6, 1, 0.8) end
            button.bar:Show()
            button.value:SetText(("%d  (%d%%)"):format(row.value, math.floor(pct * 100 + 0.5)))
        else
            button.bar:Hide()
            button.value:SetText(tostring(row.value))
        end
    end, {
        alternate = false,
        buildRow = function(button)
            button.label = UI.Cell(button, 260)
            button.label:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.bar = button:CreateTexture(nil, "ARTWORK")
            button.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.bar:SetHeight(12)
            button.bar:SetPoint("LEFT", button.label, "RIGHT", 8, 0)
            button.value = UI.Cell(button, 120)
            button.value:SetPoint("LEFT", button.label, "RIGHT", BAR_W + 16, 0)
        end,
    })

    function panel:OnShow()
        list:SetData(Stats:Collect())
    end

    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Stats)
    TG:On("STORE_CHANGED", function() if panel:IsShown() then panel:OnShow() end end, Stats)
end

TG.Window:RegisterTab("stats", L["Statistics"], build, 15)
