local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Loot = TG:GetModule("Loot")

local Frames = {}
Loot.Frames = Frames

local owner, response
local selected = 1

local function itemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetAllPoints()
    b.Border = b:CreateTexture(nil, "OVERLAY")
    b.Border:SetPoint("TOPLEFT", -2, 2)
    b.Border:SetPoint("BOTTOMRIGHT", 2, -2)
    b.Border:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.Border:SetVertexColor(1, 0.82, 0, 0)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function setItem(button, item)
    button.link = item.link
    button.Icon:SetTexture(item.icon or 134400)
    button.Icon:SetDesaturated(item.awarded ~= nil)
    local color = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
    if color then button.Border:SetVertexColor(color.r, color.g, color.b, 0.8) end
end

-- Owner and council frame

local function candidates(item)
    local rows = {}
    for name, resp in pairs(item.responses) do
        rows[#rows + 1] = { name = name, r = resp.r, roll = resp.roll or 0, votes = Loot:VoteCount(item, name) }
    end
    table.sort(rows, function(a, b)
        if a.votes ~= b.votes then return a.votes > b.votes end
        if a.r ~= b.r then return a.r < b.r end
        return a.roll > b.roll
    end)
    return rows
end

local function buildOwner()
    local f = CreateFrame("Frame", "TheGuildLootFrame", UIParent, "ButtonFrameTemplate")
    f:SetSize(620, 400)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_10_Blue")
    f:SetTitle(L["Loot session"])
    ButtonFrameTemplate_HideButtonBar(f)
    f.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
    tinsert(UISpecialFrames, "TheGuildLootFrame")

    f.items = {}
    f.itemRow = CreateFrame("Frame", nil, f.Inset)
    f.itemRow:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 10, -8)
    f.itemRow:SetSize(560, 40)

    f.selectedName = UI.Label(f.Inset, "", "GameFontNormal")
    f.selectedName:SetPoint("TOPLEFT", f.itemRow, "BOTTOMLEFT", 0, -6)
    f.selectedName:SetPoint("RIGHT", f.Inset, "RIGHT", -200, 0)

    f.endButton = UI.Button(f.Inset, L["End session"], 100, function() Loot:End() end)
    f.endButton:SetPoint("TOPRIGHT", f.Inset, "TOPRIGHT", -8, -8)
    f.addButton = UI.Button(f.Inset, L["Add item"], 90, function()
        StaticPopup_ShowCustomGenericInputBox({
            text = L["Paste an item link"], acceptText = ACCEPT, cancelText = CANCEL, maxLetters = 300,
            callback = function(text)
                local links = {}
                for link in text:gmatch("|c%x+|Hitem:.-|h%[.-%]|h|r") do links[#links + 1] = link end
                if #links > 0 then Loot:Start(links) end
            end,
        })
    end)
    f.addButton:SetPoint("RIGHT", f.endButton, "LEFT", -4, 0)

    local header = UI.Header(f.Inset, {
        { key = "name", text = L["Name"], width = 170 },
        { key = "response", text = L["Response"], width = 90 },
        { key = "roll", text = L["Roll"], width = 50, justify = "CENTER" },
        { key = "votes", text = L["Votes"], width = 50, justify = "CENTER" },
        { key = "gear", text = L["Role"], width = 60, justify = "CENTER" },
    })
    header:SetPoint("TOPLEFT", f.selectedName, "BOTTOMLEFT", 0, -6)
    f.columns = header.columns

    local listFrame = CreateFrame("Frame", nil, f.Inset)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -2)
    listFrame:SetPoint("BOTTOMRIGHT", f.Inset, "BOTTOMRIGHT", -4, 4)
    f.list = UI.List(listFrame, 24, function(button, row)
        button.row = row
        local entry = TG.Roster:Get(row.name)
        button.cells.name:SetText(entry and TG.ClassText(entry.classFile, row.name) or row.name)
        button.cells.response:SetText((Loot:ResponseText(row.r)))
        button.cells.roll:SetText(row.roll > 0 and row.roll or "")
        button.cells.votes:SetText(row.votes > 0 and row.votes or "")
        local role = TG.Store:Get("role", row.name)
        button.cells.gear:SetText(role and TG.RoleIconMarkup(role, 14) or "")
        local item = Loot.session and Loot.session.items[selected]
        local me = TG.MyName()
        button.vote:SetShown(Loot:IsCouncil() and item ~= nil and not item.awarded)
        button.vote:SetText(item and item.votes[row.name] and item.votes[row.name][me] and L["Unvote"] or L["Vote"])
        button.award:SetShown(Loot:IsOwner() and item ~= nil and not item.awarded)
    end, {
        buildRow = function(button)
            button.cells = UI.Cells(button, f.columns)
            button.vote = UI.Button(button, L["Vote"], 70, function() Loot:Vote(selected, button.row.name) end)
            button.vote:SetPoint("RIGHT", button, "RIGHT", -84, 0)
            button.award = UI.Button(button, L["Award"], 74, function() Loot:Award(selected, button.row.name, button.row.r) end)
            button.award:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        end,
    })
    f.empty = UI.Label(listFrame, L["Waiting for responses."], "GameFontDisableSmall", "CENTER")
    f.empty:SetPoint("CENTER")
    return f
end

function Frames:RefreshOwner()
    if not owner or not owner:IsShown() then return end
    local s = Loot.session
    if not s then owner:Hide() return end
    if not s.items[selected] then selected = 1 end
    for i, item in ipairs(s.items) do
        local b = owner.items[i]
        if not b then
            b = itemButton(owner.itemRow, 36)
            b:SetPoint("LEFT", owner.itemRow, "LEFT", (i - 1) * 42, 0)
            b:SetScript("OnClick", function() selected = i Frames:RefreshOwner() end)
            owner.items[i] = b
        end
        setItem(b, item)
        b:SetAlpha(i == selected and 1 or 0.6)
        b:Show()
    end
    for i = #s.items + 1, #owner.items do owner.items[i]:Hide() end
    local item = s.items[selected]
    if item then
        local text = item.link
        if item.awarded then text = text .. "  " .. GREEN_FONT_COLOR:WrapTextInColorCode(L["Awarded to %s"]:format(item.awarded.winner)) end
        owner.selectedName:SetText(text)
        local rows = candidates(item)
        owner.empty:SetShown(#rows == 0)
        owner.list:SetData(rows)
    end
    owner.endButton:SetShown(Loot:IsOwner())
    owner.addButton:SetShown(Loot:IsOwner())
    owner:SetTitle(Loot:IsOwner() and L["Loot session"] or L["Loot session of %s"]:format(s.owner))
end

function Frames:ShowOwner()
    if not Loot.session then return end
    if not owner then owner = buildOwner() end
    owner:Show()
    self:RefreshOwner()
end

-- Response frame for everyone in the group

local function buildResponse()
    local f = CreateFrame("Frame", "TheGuildLootResponse", UIParent, "ButtonFrameTemplate")
    f:SetSize(420, 200)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Bag_10_Blue")
    f:SetTitle(L["Loot"])
    ButtonFrameTemplate_HideButtonBar(f)
    f.Inset:SetPoint("BOTTOMRIGHT", -6, 4)
    f.rows = {}
    return f
end

local ROW_HEIGHT = 40

local function responseRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(390, ROW_HEIGHT)
    row.item = itemButton(row, 32)
    row.item:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.name = UI.Cell(row, 180, "LEFT", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.item, "TOPRIGHT", 6, -2)
    row.status = UI.Cell(row, 180, "LEFT", "GameFontDisableSmall")
    row.status:SetPoint("BOTTOMLEFT", row.item, "BOTTOMRIGHT", 6, 2)
    row.buttons = {}
    local x = -6
    for i = #Loot.RESPONSES, 1, -1 do
        local r = Loot.RESPONSES[i]
        local b = UI.Button(row, r.text, 62, function() Loot:Respond(row.index, r.id) Frames:RefreshResponse() end)
        b:SetPoint("RIGHT", row, "RIGHT", x, 0)
        x = x - 64
        row.buttons[r.id] = b
    end
    return row
end

function Frames:RefreshResponse()
    if not response or not response:IsShown() then return end
    local s = Loot.session
    if not s then response:Hide() return end
    local me = TG.MyName()
    local shown = 0
    for i, item in ipairs(s.items) do
        if not item.awarded then
            shown = shown + 1
            local row = response.rows[shown]
            if not row then
                row = responseRow(response.Inset, shown)
                row:SetPoint("TOPLEFT", response.Inset, "TOPLEFT", 4, -6 - (shown - 1) * ROW_HEIGHT)
                response.rows[shown] = row
            end
            row.index = i
            setItem(row.item, item)
            row.name:SetText(item.link)
            local mine = item.responses[me]
            if mine then
                row.status:SetText(L["Your response: %s"]:format((Loot:ResponseText(mine.r))))
            else
                row.status:SetText(L["%d responses"]:format(TG.Count(item.responses)))
            end
            for id, b in pairs(row.buttons) do b:SetEnabled(not mine or mine.r ~= id) end
            row:Show()
        end
    end
    for i = shown + 1, #response.rows do response.rows[i]:Hide() end
    if shown == 0 then
        response:Hide()
        return
    end
    response:SetHeight(70 + shown * ROW_HEIGHT)
end

function Frames:ShowResponse()
    if not Loot.session then return end
    if not response then response = buildResponse() end
    response:Show()
    self:RefreshResponse()
end

function Frames:Hide()
    if owner then owner:Hide() end
    if response then response:Hide() end
end

TG:On("LOOT_SESSION", function()
    Frames:RefreshOwner()
    Frames:RefreshResponse()
end, Loot)
