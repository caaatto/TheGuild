local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Voice = TG:GetModule("Voice")

local LEFT_WIDTH = 520

local function groupName(id)
    local group = id and Voice:Group(id)
    return group and group.name or ""
end

local function build(panel)
    local header = UI.SectionHeader(panel, L["Voice"])
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    header:SetPoint("RIGHT", panel, "RIGHT", -4, 0)

    local joinButton = UI.Button(panel, L["Join voice"], 120, function()
        if Voice:IsJoined() then Voice:Leave() else Voice:Join() end
        TG.After(0.5, function() if panel:IsShown() then panel:OnShow() end end)
    end)
    joinButton:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -8)

    local modeDropdown = UI.Dropdown(panel, 150, function(_, root)
        for _, m in ipairs(Voice.MODES) do
            root:CreateRadio(m[2], function() return Voice:Mode() == m[1] end, function()
                Voice:SetMode(m[1])
                panel:OnShow()
            end)
        end
    end)
    modeDropdown:SetPoint("LEFT", joinButton, "RIGHT", 8, 0)

    local micButton = UI.IconButton(panel, "Interface\\Common\\VoiceChat-On", function(tt)
        GameTooltip_SetTitle(tt, L["Microphone button"])
        GameTooltip_AddNormalLine(tt, L["Shows or hides the small movable microphone button on your screen."])
    end, function()
        Voice.db.hud = not Voice.db.hud
        if Voice.db.hud then Voice:ResetHudIfHidden() end
        Voice:RefreshHud()
        panel:OnShow()
    end)
    micButton:SetPoint("LEFT", modeDropdown, "RIGHT", 6, 0)
    micButton.icon:SetSize(18, 18)

    local rangeText = UI.Label(panel, "", "GameFontDisableSmall")
    rangeText:SetPoint("LEFT", micButton, "RIGHT", 10, 0)
    rangeText:SetPoint("RIGHT", panel, "RIGHT", -8, 0)

    local membersFrame = CreateFrame("Frame", nil, panel)
    membersFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -62)
    membersFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 4)
    membersFrame:SetWidth(LEFT_WIDTH)
    local membersHeader = UI.SectionHeader(membersFrame, L["In the voice channel"])
    membersHeader:SetPoint("TOPLEFT", membersFrame, "TOPLEFT", 0, 0)
    membersHeader:SetPoint("RIGHT", membersFrame, "RIGHT", 0, 0)
    local membersList = CreateFrame("Frame", nil, membersFrame)
    membersList:SetPoint("TOPLEFT", membersHeader, "BOTTOMLEFT", 0, -4)
    membersList:SetPoint("BOTTOMRIGHT", membersFrame, "BOTTOMRIGHT", 0, 0)
    local nobody = UI.Empty(membersList, L["Nobody is in the voice channel."])

    local members = UI.List(membersList, 24, function(button, row)
        button.row = row
        local entry = TG.Roster:Get(row.key)
        TG.SetClassIcon(button.icon, entry and entry.classFile)
        button.name:SetText(entry and TG.ClassText(entry.classFile, row.key) or row.key)
        button.speaker:SetShown(row.speaking)
        local groupText = groupName(row.group)
        if row.quiet and groupText ~= "" then groupText = groupText .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode(L["nearby only"]) end
        button.group:SetText(groupText)
        if row.isMe then
            button.distance:SetText("")
        elseif row.distance then
            button.distance:SetText(L["%d yd"]:format(row.distance))
        else
            button.distance:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(L["no position"]))
        end
        button.bar:Set(row.volume, 100, row.volume > 0 and GREEN_FONT_COLOR or GRAY_FONT_COLOR)
        button.bar.Right:SetText(row.volume .. "%")
        button.bar:SetShown(not row.isMe)
    end, {
        inset = true,
        buildRow = function(button)
            button.speaker = button:CreateTexture(nil, "ARTWORK")
            button.speaker:SetSize(16, 16)
            button.speaker:SetPoint("LEFT", button, "LEFT", 6, 0)
            if UI.HasAtlas("voicechat-icon-speaker") then
                button.speaker:SetAtlas("voicechat-icon-speaker")
            else
                button.speaker:SetTexture("Interface\\Common\\VoiceChat-Speaker")
            end
            button.icon = UI.ClassIcon(button, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 26, 0)
            button.name = UI.Cell(button, 150)
            button.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
            button.group = UI.Cell(button, 100, "LEFT", "GameFontDisableSmall")
            button.group:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
            button.distance = UI.Cell(button, 80, "RIGHT", "GameFontHighlightSmall")
            button.distance:SetPoint("LEFT", button.group, "RIGHT", 4, 0)
            button.bar = UI.Bar(button, 90, 12)
            button.bar:SetPoint("RIGHT", button, "RIGHT", -12, 0)
            button:SetScript("OnClick", function(self, mouse)
                local entry = TG.Roster:Get(self.row.key)
                if entry and mouse == "RightButton" then UI.MemberMenu(self, entry) end
            end)
            UI.Tooltip(button, function(tooltip, self)
                local entry = TG.Roster:Get(self.row.key)
                if entry then UI.MemberTooltip(tooltip, entry) else GameTooltip_SetTitle(tooltip, self.row.key) end
            end)
        end,
    })

    local groupsFrame = CreateFrame("Frame", nil, panel)
    groupsFrame:SetPoint("TOPLEFT", membersFrame, "TOPRIGHT", 8, 0)
    groupsFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local groupsHeader = UI.SectionHeader(groupsFrame, L["Voice groups"])
    groupsHeader:SetPoint("TOPLEFT", groupsFrame, "TOPLEFT", 0, 0)
    groupsHeader:SetPoint("RIGHT", groupsFrame, "RIGHT", 0, 0)

    local newGroup = UI.Button(groupsFrame, L["New group"], 110, function()
        StaticPopup_ShowCustomGenericInputBox({
            text = L["Name of the new voice group"], acceptText = ACCEPT, cancelText = CANCEL, maxLetters = 30,
            callback = function(text) Voice:CreateGroup(text) panel:OnShow() end,
        })
    end)
    newGroup:SetPoint("TOPRIGHT", groupsHeader, "BOTTOMRIGHT", 0, -6)
    local leaveGroup = UI.Button(groupsFrame, L["Leave group"], 110, function() Voice:LeaveGroup() panel:OnShow() end)
    leaveGroup:SetPoint("RIGHT", newGroup, "LEFT", -4, 0)

    local groupFilter = ""
    local search = UI.SearchBox(groupsFrame, 200, function(text)
        groupFilter = text:lower()
        if panel:IsShown() then panel:OnShow() end
    end)
    search:SetPoint("TOPLEFT", newGroup, "BOTTOMLEFT", 0, -6)
    search:SetPoint("LEFT", groupsFrame, "LEFT", 8, 0)
    search:SetPoint("RIGHT", groupsFrame, "RIGHT", -4, 0)
    panel.search = search

    local function matchesFilter(group)
        if groupFilter == "" then return true end
        if group.name:lower():find(groupFilter, 1, true) then return true end
        for _, key in ipairs(group.members) do
            if key:lower():find(groupFilter, 1, true) then return true end
        end
        return false
    end

    local groupsList = CreateFrame("Frame", nil, groupsFrame)
    groupsList:SetPoint("TOPLEFT", groupsFrame, "TOPLEFT", 0, -84)
    groupsList:SetPoint("BOTTOMRIGHT", groupsFrame, "BOTTOMRIGHT", 0, 0)
    local noGroups = UI.Empty(groupsList, L["No voice groups yet. Create one and let others join."])

    local groups = UI.List(groupsList, 38, function(button, group)
        button.group = group
        local mine = Voice:MyGroup() == group.id
        button.title:SetText((mine and TG.gold or "") .. group.name .. (mine and "|r" or ""))
        local names = {}
        for i, key in ipairs(group.members) do
            if i > 6 then names[#names + 1] = "..." break end
            local entry = TG.Roster:Get(key)
            names[#names + 1] = entry and TG.ClassText(entry.classFile, TG.ShortName(key)) or TG.ShortName(key)
        end
        local meta = L["%d in group"]:format(#group.members)
        if group.party then meta = L["Party group"] .. "   " .. meta end
        button.meta:SetText(("%s   %s"):format(meta, table.concat(names, ", ")))
        button.join:SetShown(not mine)
        button.delete:SetShown(Voice:CanManageGroup(group))
        UI.SetRowSelected(button, mine)
    end, {
        inset = true,
        buildRow = function(button)
            button.title = UI.Cell(button, 200, "LEFT", "GameFontNormal")
            button.title:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -5)
            button.meta = UI.Cell(button, 260, "LEFT", "GameFontDisableSmall")
            button.meta:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 8, 5)
            button.meta:SetPoint("RIGHT", button, "RIGHT", -150, 0)
            button.join = UI.Button(button, L["Join"], 70, function() Voice:JoinGroup(button.group.id) panel:OnShow() end)
            button.join:SetPoint("RIGHT", button, "RIGHT", -80, 0)
            button.delete = UI.Button(button, DELETE, 70, function() Voice:DeleteGroup(button.group.id) panel:OnShow() end)
            button.delete:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        end,
    })

    function panel:OnShow()
        header:SetRightText(Voice:StatusText())
        local joined = Voice:IsJoined()
        joinButton:SetText(joined and L["Leave voice"] or L["Join voice"])
        joinButton:SetEnabled(Voice:Available())
        modeDropdown:SetDefaultText(Voice:ModeName())
        if Voice:Mode() == "group" then
            rangeText:SetText(L["Only members of your voice group are audible."])
        elseif Voice:Mode() == "solo" then
            rangeText:SetText(L["You still hear your voice group. Your group and everyone else hear you only up to %d yards."]:format(Voice.db.nearRange))
        else
            rangeText:SetText(L["Your voice group is always audible, everyone else up to %d yards, silent beyond %d yards."]:format(Voice.db.nearRange, Voice.db.farRange))
        end
        local rows = Voice:Members()
        nobody:SetShown(#rows == 0)
        members:SetData(rows)
        local list = {}
        for _, group in ipairs(Voice:Groups()) do
            if matchesFilter(group) then list[#list + 1] = group end
        end
        noGroups:SetShown(#list == 0)
        groups:SetData(list)
        Voice:SetMicIcon(micButton.icon)
        micButton.icon:SetDesaturated(not Voice.db.hud)
        micButton.icon:SetAlpha(Voice.db.hud and 1 or 0.5)
        leaveGroup:SetShown(Voice:MyGroup() ~= nil)
    end

    TG:On("VOICE_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Voice)
    TG:On("STORE_CHANGED", function(ns) if panel:IsShown() and (ns == "vgroup" or ns == "vmem" or ns == "vquiet") then panel:OnShow() end end, Voice)
    TG:On("MAP_PEERS", function() if panel:IsShown() then members:Refresh() end end, Voice)
end

TG.Window:RegisterTab("voice", L["Voice"], build, 26, "Interface\\Icons\\INV_Misc_Horn_01")
