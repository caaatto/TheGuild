local TG = TheGuild
local L = TG.L
local UI = TG.UI

local Prof = TG:NewModule("Professions", {
    title = L["Professions"],
    desc = L["Share my recipes with the guild"],
    order = 50,
    defaults = { scan = true, share = true, tooltip = true, chars = {} },
    settings = {
        { key = "scan", type = "boolean", name = L["Scan professions when the profession window opens"], default = true },
        { key = "share", type = "boolean", name = L["Share my recipes with the guild"], default = true },
        { key = "tooltip", type = "boolean", name = L["Show crafters in item tooltips"], default = true },
    },
})

local scanPending = false
local sharePending = {}
local shareNotice = {}
local shareGroups = {}
local index
local indexDirty = true
local lastRequest = 0
local lastShare = 0
local requestedBy = {}

local function guildProfs()
    local g = TG:GuildDB()
    if not g then return nil end
    g.profs = g.profs or {}
    return g.profs
end

local function myChar()
    local me = TG.MyName()
    local chars = Prof.db.chars
    chars[me] = chars[me] or { p = {} }
    chars[me].c = TG.plain(select(2, UnitClass("player")), chars[me].c)
    return chars[me], me
end

local function tradeSkillUsable()
    if not C_TradeSkillUI then return false end
    if C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked() then return false end
    if C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild() then return false end
    if C_TradeSkillUI.IsNPCCrafting and C_TradeSkillUI.IsNPCCrafting() then return false end
    return true
end

function Prof:Scan()
    if not self.db.scan or not tradeSkillUsable() then return end
    local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not ok or type(info) ~= "table" or not info.professionID or info.professionID == 0 then return end
    local ok2, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok2 or type(ids) ~= "table" or #ids == 0 then return end

    local char, me = myChar()
    local prof = char.p[info.professionID] or {}
    local old = prof.r or {}
    local recipes, count, changed = {}, 0, false
    local groups, groupCount = {}, 0
    for _, recipeID in ipairs(ids) do
        local okR, r = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if okR and type(r) == "table" and r.learned and not r.isDummyRecipe then
            local cat = tonumber(r.categoryID)
            if cat and cat > 0 then
                local group = groups[cat]
                if not group then
                    group = {}
                    groups[cat] = group
                    groupCount = groupCount + 1
                end
                group[#group + 1] = recipeID
            end
            local prev = old[recipeID]
            local value = type(prev) == "number" and prev or r.name or tostring(recipeID)
            if type(value) ~= "number" then
                local okO, out = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
                if okO and type(out) == "table" and tonumber(out.itemID) and out.itemID > 0 then
                    value = out.itemID
                end
            end
            if prev == nil then changed = true end
            recipes[recipeID] = value
            count = count + 1
        end
    end
    if count == 0 then return end
    if not changed and TG.Count(old) ~= count then changed = true end
    local newGroups = groupCount > 0 and prof.g == nil
    if not changed and not newGroups and prof.s == info.skillLevel and prof.m == info.maxSkillLevel then return end

    if groupCount > 0 then
        local names, order = {}, {}
        for cat in pairs(groups) do
            local okC, c = pcall(C_TradeSkillUI.GetCategoryInfo, cat)
            if okC and type(c) == "table" and type(c.name) == "string" and c.name ~= "" then
                names[cat] = c.name
                order[cat] = tonumber(c.uiOrder) or 0
            end
        end
        prof.g, prof.gn, prof.go = groups, names, order
    else
        prof.g, prof.gn, prof.go = nil, nil, nil
    end
    prof.n = info.professionName
    prof.s = info.skillLevel
    prof.m = info.maxSkillLevel
    prof.r = recipes
    prof.t = TG.Now()
    char.p[info.professionID] = prof
    indexDirty = true
    local g = guildProfs()
    if g then g[me] = char end
    if changed then shareNotice[info.professionID] = true end
    if changed or newGroups then shareGroups[info.professionID] = true end
    self:ShareLater(info.professionID, changed and 5 or 60)
    TG:Fire("PROFESSIONS_UPDATED")
end

function Prof:ShareLater(profID, delay)
    local due = GetTime() + delay
    if sharePending[profID] and due >= sharePending[profID] then return end
    sharePending[profID] = due
    TG.After(delay, function()
        if sharePending[profID] ~= due then return end
        sharePending[profID] = nil
        if not self.enabled then return end
        if shareNotice[profID] then
            shareNotice[profID] = nil
            local prof = myChar().p[profID]
            if prof then TG:Print(L["Recorded %d recipes for %s."], TG.Count(prof.r), prof.n or "?") end
        end
        local groups = shareGroups[profID]
        shareGroups[profID] = nil
        self:Share(profID, groups)
    end)
end

local function snapshot(name, char, profID, prof, groups)
    local data = { c = name, k = char.c, id = profID, n = prof.n, s = prof.s, m = prof.m, r = prof.r, t = prof.t }
    if groups then data.g, data.gn, data.go = prof.g, prof.gn, prof.go end
    return data
end

function Prof:Share(profID, groups)
    if not self.db.share or not TG.InGuild() then return end
    local char, me = myChar()
    local prof = char.p[profID]
    if not prof then return end
    TG.Comm:Send("PS", snapshot(me, char, profID, prof, groups), "BULK")
end

function Prof:ShareAll(need)
    if not self.db.share then return end
    if GetTime() - lastShare < 300 then return end
    lastShare = GetTime()
    local cutoff = TG.Now() - 30 * 86400
    for name, char in pairs(self.db.chars) do
        for profID, prof in pairs(char.p or {}) do
            if (prof.t or 0) > cutoff then
                TG.Comm:Send("PS", snapshot(name, char, profID, prof, need and need[profID]), "BULK")
            end
        end
    end
end

local function keepGroups(prof, recipes)
    if not prof.g then return nil end
    local groups, any = {}, false
    for cat, list in pairs(prof.g) do
        local out = {}
        for _, id in ipairs(list) do
            if recipes[id] ~= nil then out[#out + 1] = id end
        end
        if #out > 0 then
            groups[cat] = out
            any = true
        end
    end
    if not any then return nil end
    return groups, prof.gn, prof.go
end

local function cleanGroups(data, recipes, prof)
    if type(data.g) ~= "table" then return keepGroups(prof, recipes) end
    local groups, names, order, cats = {}, {}, {}, 0
    for cat, list in pairs(data.g) do
        cat = tonumber(cat)
        if cat and cat > 0 and type(list) == "table" then
            local out = {}
            for _, id in ipairs(list) do
                id = tonumber(id)
                if id and recipes[id] ~= nil then out[#out + 1] = id end
            end
            if #out > 0 then
                cats = cats + 1
                if cats > 60 then break end
                groups[cat] = out
                local name = type(data.gn) == "table" and (data.gn[cat] or data.gn[tostring(cat)])
                if type(name) == "string" and name ~= "" then names[cat] = TG.CleanText(name, 40) end
                order[cat] = type(data.go) == "table" and tonumber(data.go[cat] or data.go[tostring(cat)]) or 0
            end
        end
    end
    if cats == 0 then return nil end
    return groups, names, order
end

function Prof:OnSnapshot(sender, data)
    if type(data) ~= "table" or type(data.c) ~= "string" or type(data.r) ~= "table" or not tonumber(data.id) then return end
    local g = guildProfs()
    if not g then return end
    local name = TG.StripRealm(data.c)
    if not name or (name ~= sender and not TG.Roster:Get(name) and not TG.Roster:Get(sender)) then return end
    local char = g[name] or { p = {} }
    if TG.Count(char.p) >= 12 and not char.p[data.id] then return end
    char.c = type(data.k) == "string" and #data.k <= 16 and data.k or char.c
    char.owner = sender
    local prof = char.p[data.id] or {}
    if (prof.t or 0) > (tonumber(data.t) or 0) then return end
    local recipes, count = {}, 0
    for id, v in pairs(data.r) do
        id = tonumber(id)
        if id and (type(v) == "number" or type(v) == "string") then
            recipes[id] = type(v) == "string" and TG.CleanText(v, 60) or v
            count = count + 1
            if count > 2000 then break end
        end
    end
    prof.n, prof.s, prof.m, prof.r, prof.t = TG.CleanText(data.n, 40), tonumber(data.s), tonumber(data.m), recipes, tonumber(data.t) or TG.Now()
    prof.g, prof.gn, prof.go = cleanGroups(data, recipes, prof)
    char.p[data.id] = prof
    g[name] = char
    indexDirty = true
    TG:Fire("PROFESSIONS_UPDATED")
end

function Prof:Forget()
    local g = guildProfs()
    if not g or not TG.Roster:IsReady() then return 0 end
    local removed = 0
    for name in pairs(g) do
        if not TG.IsMe(name) and not TG.Roster:Get(name) then
            g[name] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        indexDirty = true
        TG:Fire("PROFESSIONS_UPDATED")
    end
    return removed
end

function Prof:OnRequest(sender, data)
    if TG.IsMe(sender) then return end
    if requestedBy[sender] and GetTime() - requestedBy[sender] < 600 then return end
    requestedBy[sender] = GetTime()
    local need
    if type(data) == "table" and type(data.n) == "table" then
        need = {}
        for i = 1, math.min(#data.n, 20) do
            local id = tonumber(data.n[i])
            if id then need[id] = true end
        end
    end
    TG.After(math.random(2, 10), function() if self.enabled then self:ShareAll(need) end end)
end

function Prof:Uncategorized()
    local idx = self:Index()
    local seen, out = {}, {}
    for _, e in ipairs(idx.entries) do
        if not seen[e.profID] then
            local meta = idx.cats[e.profID]
            if not (meta and meta.of[e.recipeID]) then
                seen[e.profID] = true
                out[#out + 1] = e.profID
            end
        end
    end
    return out
end

function Prof:Request()
    if GetTime() - lastRequest < 60 then return end
    lastRequest = GetTime()
    local need = self:Uncategorized()
    TG.Comm:Send("PQ", #need > 0 and { n = need } or "1", "BULK")
end

function Prof:Index()
    if not indexDirty and index then return index end
    index = { byItem = {}, byName = {}, entries = {}, cats = {} }
    local g = guildProfs() or {}
    local mine = Prof.db.chars
    for name, char in pairs(g) do
        for profID, prof in pairs(char.p or {}) do
            if prof.g then
                local meta = index.cats[profID]
                if not meta then
                    meta = { of = {}, name = {}, order = {} }
                    index.cats[profID] = meta
                end
                local own = mine[name] ~= nil
                for cat, list in pairs(prof.g) do
                    for _, recipeID in ipairs(list) do meta.of[recipeID] = cat end
                    local label = prof.gn and prof.gn[cat]
                    if label and (own or not meta.name[cat]) then meta.name[cat] = label end
                    if prof.go and prof.go[cat] and (own or not meta.order[cat]) then meta.order[cat] = prof.go[cat] end
                end
            end
            for recipeID, value in pairs(prof.r or {}) do
                local entry = { char = name, classFile = char.c, profID = profID, profName = prof.n, recipeID = recipeID, value = value }
                local bucket
                if type(value) == "number" then
                    index.byItem[value] = index.byItem[value] or {}
                    bucket = index.byItem[value]
                else
                    local k = value:lower()
                    index.byName[k] = index.byName[k] or { name = value, list = {} }
                    bucket = index.byName[k].list
                end
                bucket[#bucket + 1] = entry
                index.entries[#index.entries + 1] = entry
            end
        end
    end
    indexDirty = false
    return index
end

function Prof:CraftersForItem(itemID)
    return self:Index().byItem[itemID]
end

local requestedItems = {}

local function itemName(value)
    if type(value) ~= "number" then return value end
    local name, _, _, level, minLevel = C_Item.GetItemInfo(value)
    if name then return name, tonumber(level) or 0, tonumber(minLevel) or 0 end
    if not requestedItems[value] and C_Item.RequestLoadItemDataByID then
        requestedItems[value] = true
        C_Item.RequestLoadItemDataByID(value)
    end
    return nil
end

local function crafterText(list, max)
    local names = {}
    table.sort(list, function(a, b)
        local ea, eb = TG.Roster:Get(a.char), TG.Roster:Get(b.char)
        local oa, ob = ea and ea.online or false, eb and eb.online or false
        if oa ~= ob then return oa end
        return a.char < b.char
    end)
    for i, e in ipairs(list) do
        if i > (max or 6) then
            names[#names + 1] = ("+%d"):format(#list - (max or 6))
            break
        end
        local entry = TG.Roster:Get(e.char)
        local text = TG.ClassText(e.classFile or (entry and entry.classFile), TG.ShortName(e.char))
        if not entry or not entry.online then text = GRAY_FONT_COLOR:WrapTextInColorCode(TG.ShortName(e.char)) end
        names[#names + 1] = text
    end
    return table.concat(names, ", ")
end

local function onItemTooltip(tooltip, data)
    if not Prof.enabled or not Prof.db.tooltip then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    if not data or not TG.usable(data.id) then return end
    local list = Prof:CraftersForItem(data.id)
    if not list or #list == 0 then return end
    GameTooltip_AddColoredLine(tooltip, L["Crafters"] .. ": " .. crafterText(list, 5), LIGHTBLUE_FONT_COLOR, true)
end

local searchText = ""
local expanded = {}
local expandedCat = {}
local catNames = {}

function Prof:SetSearch(text)
    searchText = TG.Trim(text or "")
end

function Prof:Toggle(profID)
    expanded[profID] = not expanded[profID] or nil
end

function Prof:ToggleCategory(profID, cat)
    local key = profID .. ":" .. cat
    expandedCat[key] = not expandedCat[key] or nil
end

local function byName(a, b)
    return (a.name or "") < (b.name or "")
end

local function byLevel(a, b)
    if a.level ~= b.level then return a.level > b.level end
    if a.minLevel ~= b.minLevel then return a.minLevel > b.minLevel end
    return (a.name or "") < (b.name or "")
end

local function byOrder(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.name < b.name
end

local function categoryName(meta, cat)
    local name = catNames[cat]
    if name == nil then
        name = false
        if C_TradeSkillUI and C_TradeSkillUI.GetCategoryInfo then
            local ok, c = pcall(C_TradeSkillUI.GetCategoryInfo, cat)
            if ok and type(c) == "table" and type(c.name) == "string" and c.name ~= "" then name = c.name end
        end
        catNames[cat] = name
    end
    return name or meta.name[cat]
end

local function categorize(p, meta, searching, rows)
    local groups, list, rest = {}, {}, nil
    for _, r in ipairs(p.recipes) do
        local cat
        for _, e in ipairs(r.list) do
            cat = meta.of[e.recipeID]
            if cat then break end
        end
        local name = cat and categoryName(meta, cat)
        if name then
            local group = groups[cat]
            if not group then
                group = { kind = "cat", prof = p.id, id = cat, name = name, order = meta.order[cat] or 0, recipes = {} }
                groups[cat] = group
                list[#list + 1] = group
            end
            group.recipes[#group.recipes + 1] = r
        else
            rest = rest or { kind = "cat", prof = p.id, id = 0, name = L["Uncategorized"], order = math.huge, recipes = {} }
            rest.recipes[#rest.recipes + 1] = r
        end
    end
    if #list == 0 then return false end
    table.sort(list, byOrder)
    if rest then list[#list + 1] = rest end
    for _, group in ipairs(list) do
        group.count = #group.recipes
        group.open = searching or expandedCat[p.id .. ":" .. group.id] == true
        rows[#rows + 1] = group
        if group.open then
            table.sort(group.recipes, byLevel)
            for _, r in ipairs(group.recipes) do
                r.indent = true
                rows[#rows + 1] = r
            end
        end
    end
    return true
end

function Prof:Rows()
    local idx = self:Index()
    local profs = {}
    local text = searchText:lower()
    local function consider(key, name, list, level, minLevel)
        if text ~= "" and not (name or ""):lower():find(text, 1, true) then return end
        local split = {}
        for _, e in ipairs(list) do
            local sub = split[e.profID]
            if not sub then
                sub = {}
                split[e.profID] = sub
            end
            sub[#sub + 1] = e
        end
        for profID, sub in pairs(split) do
            local p = profs[profID]
            if not p then
                p = { kind = "prof", id = profID, name = sub[1].profName or tostring(profID), recipes = {}, crafters = {}, list = {} }
                profs[profID] = p
            end
            p.recipes[#p.recipes + 1] = { kind = "recipe", key = key, name = name, list = sub, level = level or 0, minLevel = minLevel or 0 }
            for _, e in ipairs(sub) do
                if not p.crafters[e.char] then
                    p.crafters[e.char] = true
                    p.list[#p.list + 1] = e
                end
            end
        end
    end
    for itemID, list in pairs(idx.byItem) do
        local name, level, minLevel = itemName(itemID)
        if text == "" or name then consider(itemID, name or ("#" .. itemID), list, level, minLevel) end
    end
    for _, bucket in pairs(idx.byName) do
        consider(bucket.name, bucket.name, bucket.list)
    end
    local order = {}
    for _, p in pairs(profs) do order[#order + 1] = p end
    table.sort(order, byName)
    local rows = {}
    for _, p in ipairs(order) do
        p.open = text ~= "" or expanded[p.id] == true
        p.count = #p.recipes
        rows[#rows + 1] = p
        if p.open then
            local meta = idx.cats[p.id]
            if not (meta and categorize(p, meta, text ~= "", rows)) then
                table.sort(p.recipes, byLevel)
                for _, r in ipairs(p.recipes) do rows[#rows + 1] = r end
            end
        end
    end
    return rows
end

local function build(panel)
    local search = UI.SearchBox(panel, 220, function(text)
        Prof:SetSearch(text)
        panel:OnShow()
    end)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    panel.search = search

    local sync = UI.Button(panel, L["Request sync"], 120, function()
        Prof:Request()
        TG:Print(L["Recipes requested from the guild."])
    end)
    sync:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local info = UI.Label(panel, "", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -36)
    info:SetPoint("RIGHT", panel, "RIGHT", -12, 0)

    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -54)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)

    local list = UI.List(listFrame, 24, function(button, row)
        button.row = row
        local sub = row.kind == "cat"
        local deep = row.indent == true
        if button.sub ~= sub or button.deep ~= deep then
            button.sub, button.deep = sub, deep
            button.toggle:SetPoint("LEFT", button, "LEFT", sub and 26 or 6, 0)
            button.icon:SetPoint("LEFT", button, "LEFT", deep and 46 or 26, 0)
            button.name:SetPoint("LEFT", button, "LEFT", (sub or deep) and 70 or 50, 0)
            button.name:SetWidth((sub or deep) and 240 or 260)
        end
        if row.kind == "prof" or sub then
            button.toggle:SetTexture(row.open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
            button.toggle:Show()
            button.icon:Hide()
            button.name:SetText(sub and row.name or TG.gold .. row.name .. "|r")
            button.prof:SetText(L["%d recipes"]:format(row.count))
            button.crafters:SetText(sub and "" or crafterText(row.list, 6))
            return
        end
        button.toggle:Hide()
        button.icon:Show()
        if type(row.key) == "number" then
            local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(row.key)
            button.icon:SetTexture(icon or "Interface\\Icons\\INV_Scroll_03")
            local _, link = C_Item.GetItemInfo(row.key)
            button.name:SetText(link or row.name)
        else
            button.icon:SetTexture(136244)
            button.name:SetText(row.name)
        end
        button.prof:SetText("")
        button.crafters:SetText(crafterText(row.list, 6))
    end, {
        inset = true,
        buildRow = function(button)
            button.toggle = button:CreateTexture(nil, "ARTWORK")
            button.toggle:SetSize(16, 16)
            button.toggle:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetSize(18, 18)
            button.icon:SetPoint("LEFT", button, "LEFT", 26, 0)
            button.name = UI.Cell(button, 260)
            button.name:SetPoint("LEFT", button, "LEFT", 50, 0)
            button.prof = UI.Cell(button, 110, "LEFT", "GameFontDisableSmall")
            button.prof:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
            button.crafters = UI.Cell(button, 340)
            button.crafters:SetPoint("LEFT", button.prof, "RIGHT", 4, 0)
            button:SetScript("OnEnter", function(self)
                local row = self.row
                if not row or row.kind ~= "recipe" then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if type(row.key) == "number" then
                    GameTooltip:SetItemByID(row.key)
                else
                    GameTooltip_SetTitle(GameTooltip, row.name)
                end
                GameTooltip_AddBlankLineToTooltip(GameTooltip)
                GameTooltip_AddColoredLine(GameTooltip, L["Crafters"] .. ": " .. crafterText(row.list, 12), LIGHTBLUE_FONT_COLOR, true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:SetScript("OnClick", function(self, mouse)
                local row = self.row
                if not row then return end
                if row.kind == "prof" then
                    Prof:Toggle(row.id)
                    panel:OnShow()
                    return
                end
                if row.kind == "cat" then
                    Prof:ToggleCategory(row.prof, row.id)
                    panel:OnShow()
                    return
                end
                if mouse == "LeftButton" and IsModifiedClick("CHATLINK") and type(row.key) == "number" then
                    local _, link = C_Item.GetItemInfo(row.key)
                    TG.InsertLink(link)
                    return
                end
                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:SetTag("MENU_THEGUILD_CRAFTERS")
                    root:CreateTitle(row.name)
                    for _, e in ipairs(row.list) do
                        local entry = TG.Roster:Get(e.char)
                        local online = entry and entry.online
                        local label = TG.ClassText(e.classFile, e.char) .. (online and "" or GRAY_FONT_COLOR:WrapTextInColorCode("  (" .. L["Offline"] .. ")"))
                        root:CreateButton(label, function() TG.Whisper(e.char) end)
                    end
                end)
            end)
        end,
    })

    TG.Tutorial:Define("professions", {
        { target = search, text = L["Search recipes across the guild. Crafters also appear in item tooltips."], point = "bottom" },
        { target = sync, text = L["Your own recipes are recorded when a profession window opens and shared automatically."], point = "bottom" },
        { target = listFrame, text = L["Professions fold out to their recipes with everybody who can craft them. A search opens all of them."], point = "top" },
    })

    function panel:OnShow()
        local rows = Prof:Rows()
        local idx = Prof:Index()
        local crafters = TG.Count(guildProfs() or {})
        if #idx.entries == 0 then
            info:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(L["Open a profession window to record your recipes."]))
        else
            info:SetText(L["%d recipes from %d crafters"]:format(#idx.entries, crafters) .. "   " .. GRAY_FONT_COLOR:WrapTextInColorCode(L["Type a recipe or item name to search."]))
        end
        list:SetData(rows)
    end

    TG:On("PROFESSIONS_UPDATED", function() if panel:IsVisible() then panel:OnShow() end end, Prof)
    TG:RegisterEvent("ITEM_DATA_LOAD_RESULT", function()
        if panel:IsVisible() and not panel.refreshQueued then
            panel.refreshQueued = true
            TG.After(0.5, function() panel.refreshQueued = false if panel:IsVisible() then panel:OnShow() end end)
        end
    end, Prof)
end

function Prof:OnInitialize()
    if TooltipDataProcessor and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            TG.SafeCall(onItemTooltip, tooltip, data)
        end)
    end
end

function Prof:OnEnable()
    self:RegisterComm("PS", "OnSnapshot")
    self:RegisterComm("PQ", "OnRequest")
    self:On("ROSTER_READY", function() TG.After(30, function() if self.enabled then self:Forget() end end) end)
    self:On("MEMBER_LEFT", function() TG.After(120, function() if self.enabled then self:Forget() end end) end)
    local function queueScan()
        if scanPending then return end
        scanPending = true
        TG.After(1, function()
            scanPending = false
            if self.enabled then TG.SafeCall(self.Scan, self) end
        end)
    end
    self:RegisterEvent("TRADE_SKILL_SHOW", queueScan)
    self:RegisterEvent("TRADE_SKILL_LIST_UPDATE", queueScan)
    self:RegisterEvent("NEW_RECIPE_LEARNED", queueScan)
    self:On("PEER_HELLO", function()
        if GetTime() - lastRequest > 300 then
            TG.After(math.random(5, 15), function() if self.enabled then self:Request() end end)
        end
    end)
    self:On("GUILD_CHANGED", function() indexDirty = true end)
    TG.After(25, function() if self.enabled then self:Request() end end)
    local g = guildProfs()
    if g then
        for name, char in pairs(self.db.chars) do g[name] = char end
        indexDirty = true
    end
end

TG.Window:RegisterTab("professions", L["Professions"], build, 30, "Interface\\Icons\\Trade_Engineering", "Professions")