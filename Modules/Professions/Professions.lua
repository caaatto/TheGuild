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
    for _, recipeID in ipairs(ids) do
        local okR, r = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if okR and type(r) == "table" and r.learned and not r.isDummyRecipe then
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
    if not changed and prof.s == info.skillLevel and prof.m == info.maxSkillLevel then return end

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
        self:Share(profID)
    end)
end

function Prof:Share(profID)
    if not self.db.share or not TG.InGuild() then return end
    local char, me = myChar()
    local prof = char.p[profID]
    if not prof then return end
    TG.Comm:Send("PS", { c = me, k = char.c, id = profID, n = prof.n, s = prof.s, m = prof.m, r = prof.r, t = prof.t }, "BULK")
end

function Prof:ShareAll()
    if not self.db.share then return end
    if GetTime() - lastShare < 300 then return end
    lastShare = GetTime()
    local cutoff = TG.Now() - 30 * 86400
    for name, char in pairs(self.db.chars) do
        for profID, prof in pairs(char.p or {}) do
            if (prof.t or 0) > cutoff then
                TG.Comm:Send("PS", { c = name, k = char.c, id = profID, n = prof.n, s = prof.s, m = prof.m, r = prof.r, t = prof.t }, "BULK")
            end
        end
    end
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

function Prof:OnRequest(sender)
    if TG.IsMe(sender) then return end
    if requestedBy[sender] and GetTime() - requestedBy[sender] < 600 then return end
    requestedBy[sender] = GetTime()
    TG.After(math.random(2, 10), function() if self.enabled then self:ShareAll() end end)
end

function Prof:Request()
    if GetTime() - lastRequest < 60 then return end
    lastRequest = GetTime()
    TG.Comm:Send("PQ", "1", "BULK")
end

function Prof:Index()
    if not indexDirty and index then return index end
    index = { byItem = {}, byName = {}, entries = {} }
    local g = guildProfs() or {}
    for name, char in pairs(g) do
        for profID, prof in pairs(char.p or {}) do
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
    local name = C_Item.GetItemInfo(value)
    if name then return name end
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

function Prof:SetSearch(text)
    searchText = TG.Trim(text or "")
end

function Prof:Toggle(profID)
    expanded[profID] = not expanded[profID] or nil
end

local function byName(a, b)
    return (a.name or "") < (b.name or "")
end

function Prof:Rows()
    local idx = self:Index()
    local profs = {}
    local text = searchText:lower()
    local function consider(key, name, list)
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
            p.recipes[#p.recipes + 1] = { kind = "recipe", key = key, name = name, list = sub }
            for _, e in ipairs(sub) do
                if not p.crafters[e.char] then
                    p.crafters[e.char] = true
                    p.list[#p.list + 1] = e
                end
            end
        end
    end
    for itemID, list in pairs(idx.byItem) do
        local name = itemName(itemID)
        if text == "" or name then consider(itemID, name or ("#" .. itemID), list) end
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
            table.sort(p.recipes, byName)
            for _, r in ipairs(p.recipes) do rows[#rows + 1] = r end
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
        if row.kind == "prof" then
            button.toggle:SetTexture(row.open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
            button.toggle:Show()
            button.icon:Hide()
            button.name:SetText(TG.gold .. row.name .. "|r")
            button.prof:SetText(L["%d recipes"]:format(row.count))
            button.crafters:SetText(crafterText(row.list, 6))
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