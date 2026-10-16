local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Loot = TG:GetModule("Loot")

local columns = {
    { key = "time", text = L["Date"], width = 110 },
    { key = "item", text = L["Item"], width = 260 },
    { key = "winner", text = L["Winner"], width = 150 },
    { key = "response", text = L["Response"], width = 80 },
    { key = "by", text = L["Awarded by"], width = 150 },
}

local searchText = ""

local function build(panel)
    local search = UI.SearchBox(panel, 200, function(text) searchText = text:lower() panel:OnShow() end)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)

    local session = UI.Button(panel, L["Loot session"], 110, function()
        if Loot.session then
            Loot.Frames:ShowOwner()
            Loot.Frames:ShowResponse()
        else
            TG:Print(L["Usage: /tg loot <item link>, /tg loot end"])
        end
    end)
    session:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local info = UI.Label(panel, "", "GameFontHighlightSmall")
    info:SetPoint("LEFT", search, "RIGHT", 12, 0)

    local header = UI.Header(panel, columns)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -36)

    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -2)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)

    local list = UI.List(listFrame, 22, function(button, row)
        button.row = row
        button.cells.time:SetText(date("%d.%m.%y %H:%M", row.t))
        button.cells.item:SetText(row.link or "")
        local entry = TG.Roster:Get(row.winner or "")
        button.cells.winner:SetText(entry and TG.ClassText(entry.classFile, row.winner) or (row.winner or ""))
        button.cells.response:SetText((Loot:ResponseText(row.r)))
        button.cells.by:SetText(row.by or "")
    end, {
        buildRow = function(button)
            button.cells = UI.Cells(button, columns)
            button:SetScript("OnEnter", function(self)
                if self.row and self.row.link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self.row.link)
                    GameTooltip:Show()
                end
            end)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button:SetScript("OnClick", function(self)
                if self.row and self.row.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(self.row.link) end
            end)
        end,
    })

    function panel:OnShow()
        local rows = {}
        for _, row in ipairs(Loot:History()) do
            if searchText == "" or (row.link or ""):lower():find(searchText, 1, true) or (row.winner or ""):lower():find(searchText, 1, true) then
                rows[#rows + 1] = row
            end
        end
        info:SetText(L["%d awards"]:format(#rows))
        session:SetText(Loot.session and L["Loot session"] or L["No session"])
        list:SetData(rows)
    end

    TG:On("STORE_CHANGED", function(ns) if ns == "loot" and panel:IsShown() then panel:OnShow() end end, Loot)
    TG:On("LOOT_SESSION", function() if panel:IsShown() then panel:OnShow() end end, Loot)
end

TG.Window:RegisterTab("loot", L["Loot"], build, 27)
