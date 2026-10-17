local TG = TheGuild
local L = TG.L
local UI = TG.UI

local NS_STAT = "stat"
local DAY = 86400
local TOP = 5
local MAX_ZONES = 30

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

TG.Store:DefinePolicy(NS_STAT, "self", nil, function(v)
    if v == 0 then return true end
    return TG.Store.Shape({ o = "boolean?", d = "number?", z = "table?", l = "number?", lt = "number?" })(v)
end)

local function myStat()
    local v = TG.Store:Get(NS_STAT, TG.MyName())
    if type(v) == "table" then return TG.CopyTable(v) end
    if v == 0 then return { o = true } end
    return {}
end

function Stats:Save(v)
    if not TG.InGuild() or not TG.MyName() then return false end
    return TG.Store:Set(NS_STAT, TG.MyName(), v)
end

function Stats:PublishOptIn(value)
    local v = myStat()
    v.o = (not value) or nil
    self:Save(v)
end

function Stats:Listed(name)
    local v = TG.Store:Get(NS_STAT, name)
    if v == 0 then return false end
    return not (type(v) == "table" and v.o == true)
end

function Stats:RecordDeath(zone)
    local v = myStat()
    v.d = (v.d or 0) + 1
    v.z = v.z or {}
    zone = TG.CleanText(TG.plain(zone, ""), 40)
    if zone == "" then zone = "?" end
    v.z[zone] = (v.z[zone] or 0) + 1
    while TG.Count(v.z) > MAX_ZONES do
        local minKey, minN
        for k, n in pairs(v.z) do
            if not minN or n < minN then minKey, minN = k, n end
        end
        v.z[minKey] = nil
    end
    self:Save(v)
end

function Stats:RecordLevel(level)
    local v = myStat()
    v.l = (v.l or 0) + 1
    v.lt = tonumber(level)
    self:Save(v)
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

    local deaths, byZone, byMember, lifetimeUps, upsBy = 0, {}, {}, 0, {}
    for key, item in pairs(TG.Store:Items(NS_STAT)) do
        local v = item.v
        if type(v) == "table" then
            if v.d then
                deaths = deaths + v.d
                byMember[key] = v.d
            end
            for zone, n in pairs(v.z or {}) do
                local label = zone == "?" and L["Unknown"] or zone
                byZone[label] = (byZone[label] or 0) + n
            end
            if v.l then
                lifetimeUps = lifetimeUps + v.l
                upsBy[key] = v.l
            end
        end
    end
    local recentDeaths = 0
    for _, item in pairs(TG.Store:Items("death")) do
        if type(item.v) == "table" then recentDeaths = recentDeaths + 1 end
    end
    local listed = function(key) return self:Listed(key) end
    header(rows, L["Deaths"])
    text(rows, L["Deaths recorded"], deaths)
    text(rows, L["Deaths shared"], recentDeaths)
    for _, z in ipairs(top(byZone, TOP)) do bar(rows, z.key, z.n, deaths) end
    if self.db.rankings then
        for _, m in ipairs(top(byMember, TOP, listed)) do bar(rows, memberLabel(m.key), m.n, deaths, { r = 0.8, g = 0.3, b = 0.3 }) end
    end

    local ups = 0
    for _, item in ipairs(TG.Log:Entries(function(i) return i.kind == "level" end)) do
        if (item.t or 0) >= now - 30 * DAY then ups = ups + 1 end
    end
    header(rows, L["Level ups"])
    text(rows, L["Level ups recorded"], lifetimeUps)
    text(rows, L["Level ups in the last 30 days"], ups)
    if self.db.rankings then
        for _, m in ipairs(top(upsBy, TOP, listed)) do bar(rows, memberLabel(m.key), m.n, lifetimeUps) end
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
    self:RegisterEvent("PLAYER_DEAD", function() self:RecordDeath(GetZoneText()) end)
    self:RegisterEvent("PLAYER_LEVEL_UP", function(_, level) self:RecordLevel(level) end)
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

    local list = UI.List(listFrame, 22, function(button, row)
        if row.kind == "header" then
            button.strip:Show()
            button.label:SetFontObject("GameFontNormalSmall")
            button.label:ClearAllPoints()
            button.label:SetPoint("LEFT", button, "LEFT", 8, 0)
            button.label:SetText(row.text)
            button.value:SetText("")
            button.bar:Hide()
            return
        end
        button.strip:Hide()
        button.label:SetFontObject("GameFontHighlightSmall")
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", 22, 0)
        button.label:SetText(row.label)
        if row.kind == "bar" then
            local pct = (row.max or 0) > 0 and row.value / row.max or 0
            button.bar:Set(row.value, row.max, row.color)
            button.bar.Right:SetText(("%d%%"):format(math.floor(pct * 100 + 0.5)))
            button.bar:Show()
            button.value:SetText(tostring(row.value))
        else
            button.bar:Hide()
            button.value:SetText(tostring(row.value))
        end
    end, {
        alternate = false,
        inset = true,
        buildRow = function(button)
            button.strip = button:CreateTexture(nil, "BACKGROUND")
            button.strip:SetAllPoints()
            button.strip:SetTexture("Interface\\GuildFrame\\GuildFrame")
            button.strip:SetTexCoord(0.63183594, 0.94531250, 0.57617188, 0.61523438)
            button.label = UI.Cell(button, 240)
            button.bar = UI.Bar(button, BAR_W, 12)
            button.bar:SetPoint("LEFT", button, "LEFT", 272, 0)
            button.value = UI.Cell(button, 70, "RIGHT")
            button.value:SetPoint("LEFT", button.bar, "RIGHT", 10, 0)
        end,
    })

    TG.Tutorial:Define("stats", {
        { target = export, text = L["Everything on this page exports as plain text."], point = "bottom" },
        { target = listFrame, text = L["Member counts, classes, lifetime deaths and level ups, loot and attendance. Rankings can be left in the settings."], point = "top" },
    })

    function panel:OnShow()
        list:SetData(Stats:Collect())
    end

    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Stats)
    TG:On("STORE_CHANGED", function() if panel:IsShown() then panel:OnShow() end end, Stats)
end

TG.Window:RegisterTab("stats", L["Statistics"], build, 15, "Interface\\Icons\\INV_Misc_Book_09", "Stats")