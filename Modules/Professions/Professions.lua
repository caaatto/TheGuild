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
local index
local indexDirty = true
local lastRequest = 0

-- Guild data: TG:GuildDB().profs[charName] = { c = classFile, p = { [profID] = { n, s, m, r = { [recipeID] = itemID or name }, t } } }

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

    local recipes, count = {}, 0
    for _, recipeID in ipairs(ids) do
        local okR, r = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if okR and type(r) == "table" and r.learned and not r.isDummyRecipe then
            local value = r.name or tostring(recipeID)
            local okO, out = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
            if okO and type(out) == "table" and tonumber(out.itemID) and out.itemID > 0 then
                value = out.itemID
            end
            recipes[recipeID] = value
            count = count + 1
        end
    end
    if count == 0 then return end

    local char, me = myChar()
    local prof = char.p[info.professionID] or {}
    local changed = prof.s ~= info.skillLevel or TG.Count(prof.r or {}) ~= count
    if not changed then
        for id, v in pairs(recipes) do
            if prof.r[id] ~= v then changed = true break end
        end
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
    if changed then
        TG:Print(L["Recorded %d recipes for %s."], count, prof.n or "?")
        self:Share(info.professionID)
        TG:Fire("PROFESSIONS_UPDATED")
    end
end

function Prof:Share(profID)
    if not self.db.share or not IsInGuild() then return end
    local char, me = myChar()
    local prof = char.p[profID]
    if not prof then return end
    TG.Comm:Send("PS", { c = me, k = char.c, id = profID, n = prof.n, s = prof.s, m = prof.m, r = prof.r, t = prof.t }, "BULK")
end

function Prof:ShareAll()
    if not self.db.share then return end
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
    char.c = data.k or char.c
    char.owner = sender
    local prof = char.p[data.id] or {}
    if (prof.t or 0) > (tonumber(data.t) or 0) then return end
    local recipes, count = {}, 0
    for id, v in pairs(data.r) do
        id = tonumber(id)
        if id and (type(v) == "number" or type(v) == "string") then
            recipes[id] = v
            count = count + 1
            if count > 2000 then break end
        end
    end
    prof.n, prof.s, prof.m, prof.r, prof.t = data.n, tonumber(data.s), tonumber(data.m), recipes, tonumber(data.t) or TG.Now()
    char.p[data.id] = prof
    g[name] = char
    indexDirty = true
    TG:Fire("PROFESSIONS_UPDATED")
end

function Prof:OnRequest(sender)
    if TG.IsMe(sender) then return end
    TG.After(math.random(2, 10), function() if self.enabled then self:ShareAll() end end)
end

function Prof:Request()
    if GetTime() - lastRequest < 60 then return end
    lastRequest = GetTime()
    TG.Comm:Send("PQ", "1", "BULK")
end

-- Index: recipe value (itemID or name) -> { { char, profID, profName, recipeID }, ... }

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

-- Window tab

local profFilter = nil
local searchText = ""

local function professionList()
    local out, seen = {}, {}
    for _, char in pairs(guildProfs() or {}) do
        for profID, prof in pairs(char.p or {}) do
            if not seen[profID] then
                seen[profID] = true
                out[#out + 1] = { id = profID, name = prof.n or tostring(profID) }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Prof:Rows()
    local idx = self:Index()
    local groups = {}
    local text = searchText:lower()
    local function consider(key, name, list)
        if profFilter then
            local keep = {}
            for _, e in ipairs(list) do if e.profID == profFilter then keep[#keep + 1] = e end end
            list = keep
        end
        if #list == 0 then return end
        if text ~= "" and not (name or ""):lower():find(text, 1, true) then return end
        groups[#groups + 1] = { key = key, name = name, list = list, profName = list[1].profName }
    end
    for itemID, list in pairs(idx.byItem) do
        local name = itemName(itemID)
        if text == "" or name then consider(itemID, name or ("#" .. itemID), list) end
    end
    for _, bucket in pairs(idx.byName) do
        consider(bucket.name, bucket.name, bucket.list)
    end
    table.sort(groups, function(a, b)
        if (a.profName or "") ~= (b.profName or "") then return (a.profName or "") < (b.profName or "") end
        return (a.name or "") < (b.name or "")
    end)
    return groups
end

local function build(panel)
    local search = UI.SearchBox(panel, 220, function(text)
        searchText = text
        panel:OnShow()
    end)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    panel.search = search

    local dropdown = UI.Dropdown(panel, 160, function(dd, root)
        root:CreateRadio(L["All professions"], function() return profFilter == nil end, function() profFilter = nil panel:OnShow() end)
        for _, p in ipairs(professionList()) do
            root:CreateRadio(p.name, function() return profFilter == p.id end, function() profFilter = p.id panel:OnShow() end)
        end
    end)
    dropdown:SetPoint("LEFT", search, "RIGHT", 12, 0)
    dropdown:SetDefaultText(L["All professions"])

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

    local list = UI.List(listFrame, 24, function(button, group)
        button.group = group
        if type(group.key) == "number" then
            local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(group.key)
            button.icon:SetTexture(icon or 134400)
            local _, link = C_Item.GetItemInfo(group.key)
            button.name:SetText(link or group.name)
        else
            button.icon:SetTexture(136244)
            button.name:SetText(group.name)
        end
        button.prof:SetText(group.profName or "")
        button.crafters:SetText(crafterText(group.list, 6))
    end, {
        inset = true,
        buildRow = function(button)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetSize(18, 18)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.name = UI.Cell(button, 260)
            button.name:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
            button.prof = UI.Cell(button, 110, "LEFT", "GameFontDisableSmall")
            button.prof:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
            button.crafters = UI.Cell(button, 340)
            button.crafters:SetPoint("LEFT", button.prof, "RIGHT", 4, 0)
            button:SetScript("OnEnter", function(self)
                if not self.group then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if type(self.group.key) == "number" then
                    GameTooltip:SetItemByID(self.group.key)
                else
                    GameTooltip_SetTitle(GameTooltip, self.group.name)
                end
                GameTooltip_AddBlankLineToTooltip(GameTooltip)
                GameTooltip_AddColoredLine(GameTooltip, L["Crafters"] .. ": " .. crafterText(self.group.list, 12), LIGHTBLUE_FONT_COLOR, true)
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:SetScript("OnClick", function(self, mouse)
                if not self.group then return end
                if mouse == "LeftButton" and IsModifiedClick("CHATLINK") and type(self.group.key) == "number" then
                    local _, link = C_Item.GetItemInfo(self.group.key)
                    TG.InsertLink(link)
                    return
                end
                MenuUtil.CreateContextMenu(self, function(_, root)
                    root:SetTag("MENU_THEGUILD_CRAFTERS")
                    root:CreateTitle(self.group.name)
                    for _, e in ipairs(self.group.list) do
                        local entry = TG.Roster:Get(e.char)
                        local online = entry and entry.online
                        local label = TG.ClassText(e.classFile, e.char) .. (online and "" or GRAY_FONT_COLOR:WrapTextInColorCode("  (" .. L["Offline"] .. ")"))
                        root:CreateButton(label, function() TG.Whisper(e.char) end)
                    end
                end)
            end)
        end,
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

    TG:On("PROFESSIONS_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Prof)
    TG:RegisterEvent("ITEM_DATA_LOAD_RESULT", function()
        if panel:IsShown() and not panel.refreshQueued then
            panel.refreshQueued = true
            TG.After(0.5, function() panel.refreshQueued = false if panel:IsShown() then panel:OnShow() end end)
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

TG.Window:RegisterTab("professions", L["Professions"], build, 30, "Interface\\Icons\\Trade_Engineering")
