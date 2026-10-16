local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Raids = TG:GetModule("Raids")

local SIZES = { 10, 20, 40 }

local selectedTeam
local pickerText = ""
local view = "teams"

local function build(panel)
    local teamDropdown = UI.Dropdown(panel, 170, function(_, root)
        for _, team in ipairs(Raids:Teams()) do
            root:CreateRadio(("%s (%d)"):format(team.name, team.size), function() return selectedTeam == team.id end, function()
                selectedTeam = team.id
                panel:OnShow()
            end)
        end
    end)
    teamDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    teamDropdown:SetDefaultText(L["Choose a team"])

    local newTeam = UI.Button(panel, L["New team"], 90, function()
        StaticPopup_ShowCustomGenericInputBox({
            text = L["Name of the new team"], acceptText = ACCEPT, cancelText = CANCEL, maxLetters = 30,
            callback = function(text)
                local id = Raids:CreateTeam(text, 20)
                if id then selectedTeam = id end
                panel:OnShow()
            end,
        })
    end)
    newTeam:SetPoint("LEFT", teamDropdown, "RIGHT", 8, 0)

    local rename = UI.Button(panel, L["Rename"], 80, function()
        if not selectedTeam then return end
        StaticPopup_ShowCustomGenericInputBox({
            text = L["Name of the team"], acceptText = ACCEPT, cancelText = CANCEL, maxLetters = 30,
            callback = function(text) Raids:RenameTeam(selectedTeam, text) panel:OnShow() end,
        })
    end)
    rename:SetPoint("LEFT", newTeam, "RIGHT", 4, 0)

    local sizeDropdown = UI.Dropdown(panel, 70, function(_, root)
        for _, size in ipairs(SIZES) do
            root:CreateRadio(tostring(size), function()
                local team = selectedTeam and Raids:Team(selectedTeam)
                return team ~= nil and team.size == size
            end, function() if selectedTeam then Raids:SetSize(selectedTeam, size) panel:OnShow() end end)
        end
    end)
    sizeDropdown:SetPoint("LEFT", rename, "RIGHT", 4, 0)

    local delete = UI.Button(panel, DELETE, 80, function()
        if not selectedTeam then return end
        local team = Raids:Team(selectedTeam)
        StaticPopup_ShowGenericConfirmation(L["Delete team %s?"]:format(team and team.name or ""), function()
            Raids:DeleteTeam(selectedTeam)
            selectedTeam = nil
            panel:OnShow()
        end)
    end)
    delete:SetPoint("LEFT", sizeDropdown, "RIGHT", 4, 0)

    local invite = UI.Button(panel, L["Invite online"], 110, function()
        if not selectedTeam then return end
        local n = Raids:InviteTeam(selectedTeam)
        TG:Print(L["%d invitations sent."], n)
    end)
    invite:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local toggle = UI.Button(panel, L["Attendance"], 110, function()
        view = view == "teams" and "attendance" or "teams"
        panel:OnShow()
    end)
    toggle:SetPoint("RIGHT", invite, "LEFT", -6, 0)

    -- team members
    local membersFrame = CreateFrame("Frame", nil, panel)
    membersFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -40)
    membersFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -4, 4)
    local membersTitle = UI.Label(membersFrame, L["Team members"], "GameFontNormal")
    membersTitle:SetPoint("TOPLEFT", membersFrame, "TOPLEFT", 8, -2)
    local membersList = CreateFrame("Frame", nil, membersFrame)
    membersList:SetPoint("TOPLEFT", membersFrame, "TOPLEFT", 0, -20)
    membersList:SetPoint("BOTTOMRIGHT", membersFrame, "BOTTOMRIGHT", 0, 0)
    local members = UI.List(membersList, 22, function(button, key)
        local e = TG.Roster:Get(key)
        button.key = key
        TG.SetClassIcon(button.icon, e and e.classFile)
        button.icon:SetDesaturated(not (e and e.online))
        local role = TG.Store:Get("role", key)
        button.name:SetText((role and (TG.RoleIconMarkup(role, 14) .. " ") or "") .. (e and TG.ClassText(e.classFile, key) or GRAY_FONT_COLOR:WrapTextInColorCode(key)))
        button.status:SetText(e and UI.StatusText(e) or "")
        button.remove:SetShown(Raids:CanEdit())
    end, {
        buildRow = function(button)
            button.icon = UI.ClassIcon(button, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.name = UI.Cell(button, 200)
            button.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
            button.status = UI.Cell(button, 80, "LEFT", "GameFontHighlightSmall")
            button.status:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
            button.remove = UI.Button(button, REMOVE, 70, function() Raids:RemoveMember(selectedTeam, button.key) panel:OnShow() end)
            button.remove:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            button:SetScript("OnClick", function(self, mouse)
                local e = TG.Roster:Get(self.key)
                if e and mouse == "RightButton" then UI.MemberMenu(self, e) end
            end)
        end,
    })

    -- roster picker
    local pickerFrame = CreateFrame("Frame", nil, panel)
    pickerFrame:SetPoint("TOPLEFT", panel, "TOP", 4, -40)
    pickerFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local pickerTitle = UI.Label(pickerFrame, L["Add members"], "GameFontNormal")
    pickerTitle:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 8, -2)
    local search = UI.SearchBox(pickerFrame, 160, function(text) pickerText = text panel:OnShow() end)
    search:SetPoint("LEFT", pickerTitle, "RIGHT", 12, 0)
    local pickerList = CreateFrame("Frame", nil, pickerFrame)
    pickerList:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 0, -20)
    pickerList:SetPoint("BOTTOMRIGHT", pickerFrame, "BOTTOMRIGHT", 0, 0)
    local picker = UI.List(pickerList, 22, function(button, e)
        button.key = e.key
        TG.SetClassIcon(button.icon, e.classFile)
        local role = TG.Store:Get("role", e.key)
        button.name:SetText((role and (TG.RoleIconMarkup(role, 14) .. " ") or "") .. TG.ClassText(e.classFile, e.key) .. GRAY_FONT_COLOR:WrapTextInColorCode(" " .. (e.level or "")))
    end, {
        buildRow = function(button)
            button.icon = UI.ClassIcon(button, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.name = UI.Cell(button, 240)
            button.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
            button.add = UI.Button(button, L["Add"], 60, function() Raids:AddMember(selectedTeam, button.key) panel:OnShow() end)
            button.add:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end,
    })

    -- attendance
    local attendanceFrame = CreateFrame("Frame", nil, panel)
    attendanceFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -40)
    attendanceFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local attendanceInfo = UI.Label(attendanceFrame, "", "GameFontHighlightSmall")
    attendanceInfo:SetPoint("TOPLEFT", attendanceFrame, "TOPLEFT", 8, -2)
    local attendanceList = CreateFrame("Frame", nil, attendanceFrame)
    attendanceList:SetPoint("TOPLEFT", attendanceFrame, "TOPLEFT", 0, -20)
    attendanceList:SetPoint("BOTTOMRIGHT", attendanceFrame, "BOTTOMRIGHT", 0, 0)
    local attendance = UI.List(attendanceList, 22, function(button, row)
        local e = row.entry
        TG.SetClassIcon(button.icon, e.classFile)
        button.name:SetText(TG.ClassText(e.classFile, e.key))
        button.count:SetText(("%d / %d"):format(row.count, row.total))
        button.percent:SetText(("%d%%"):format(row.total > 0 and (row.count / row.total * 100) or 0))
        button.last:SetText(row.last or "")
        local dots = {}
        for _, day in ipairs(row.allDays) do
            dots[#dots + 1] = row.days[day][e.key] and "|cff40c040o|r" or "|cff606060.|r"
        end
        button.dots:SetText(table.concat(dots, " "))
    end, {
        buildRow = function(button)
            button.icon = UI.ClassIcon(button, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.name = UI.Cell(button, 180)
            button.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
            button.count = UI.Cell(button, 60, "CENTER")
            button.count:SetPoint("LEFT", button.name, "RIGHT", 4, 0)
            button.percent = UI.Cell(button, 50, "CENTER")
            button.percent:SetPoint("LEFT", button.count, "RIGHT", 4, 0)
            button.last = UI.Cell(button, 90, "LEFT", "GameFontDisableSmall")
            button.last:SetPoint("LEFT", button.percent, "RIGHT", 4, 0)
            button.dots = UI.Cell(button, 300)
            button.dots:SetPoint("LEFT", button.last, "RIGHT", 4, 0)
        end,
    })

    function panel:OnShow()
        local canEdit = Raids:CanEdit()
        local teams = Raids:Teams()
        if not selectedTeam and teams[1] then selectedTeam = teams[1].id end
        local team = selectedTeam and Raids:Team(selectedTeam)
        if not team then selectedTeam = nil end
        teamDropdown:SetDefaultText(team and ("%s (%d)"):format(team.name, team.size) or L["Choose a team"])
        teamDropdown:GenerateMenu()
        sizeDropdown:SetDefaultText(team and tostring(team.size) or "")
        newTeam:SetShown(canEdit)
        rename:SetShown(canEdit and team ~= nil)
        sizeDropdown:SetShown(canEdit and team ~= nil)
        delete:SetShown(canEdit and team ~= nil)
        invite:SetEnabled(team ~= nil)
        toggle:SetText(view == "teams" and L["Attendance"] or L["Teams"])

        local showTeams = view == "teams"
        membersFrame:SetShown(showTeams)
        pickerFrame:SetShown(showTeams and canEdit and team ~= nil)
        attendanceFrame:SetShown(not showTeams)

        if showTeams then
            membersTitle:SetText(team and ("%s: %d / %d"):format(L["Team members"], #team.members, team.size) or L["Team members"])
            members:SetData(team and team.members or {})
            local candidates = {}
            if team then
                local inTeam = {}
                for _, key in ipairs(team.members) do inTeam[key] = true end
                local text = pickerText:lower()
                for _, e in ipairs(TG.Roster:Members()) do
                    if not inTeam[e.key] and not TG.Store:Get("alt", e.key) and (text == "" or e.key:lower():find(text, 1, true)) then
                        candidates[#candidates + 1] = e
                    end
                end
            end
            picker:SetData(candidates)
        else
            local rows, days = Raids:Attendance(Raids.db.attendanceDays)
            for _, row in ipairs(rows) do row.allDays = days end
            attendanceInfo:SetText(#days > 0 and L["%d raid nights, newest first"]:format(#days) or GRAY_FONT_COLOR:WrapTextInColorCode(L["No raid nights recorded yet. Officers in a raid record attendance automatically."]))
            attendance:SetData(rows)
        end
    end

    TG:On("STORE_CHANGED", function(ns) if panel:IsShown() and (ns == "team" or ns == "att" or ns == "role") then panel:OnShow() end end, Raids)
    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Raids)
end

TG.Window:RegisterTab("raids", L["Raids"], build, 25)
