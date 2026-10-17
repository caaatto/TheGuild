local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Raids = TG:GetModule("Raids")

local SIZES = { 10, 20, 40 }

local selectedTeam
local pickerText = ""
Raids.view = "teams"

local VIEWS = { { "teams", L["Teams"] }, { "builder", L["Raid builder"] }, { "schedule", L["Schedule"] }, { "attendance", L["Attendance"] } }

local function roleIcon(role)
    local markup = TG.RoleIconMarkup(role, 12)
    if markup == "" then return TG.ROLE_NAMES[role]:sub(1, 1) end
    return markup
end

local function build(panel)
    local teamDropdown = UI.Dropdown(panel, 170, function(_, root)
        for _, team in ipairs(Raids:Teams()) do
            root:CreateRadio(("%s (%d)"):format(team.name, team.size), function() return selectedTeam == team.id end, function()
                selectedTeam = team.id
                panel:OnShow()
            end)
        end
    end)
    teamDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -40)
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

    local rename = UI.Button(panel, L["Rename"], 100, function()
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
    invite:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -39)

    local viewTabs = UI.Tabs(panel, VIEWS, function(id)
        Raids.view = id
        panel:OnShow()
    end)
    viewTabs:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -2)

    local membersFrame = CreateFrame("Frame", nil, panel)
    membersFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -70)
    membersFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -4, 4)
    local membersTitle = UI.SectionHeader(membersFrame, L["Team members"])
    membersTitle:SetPoint("TOPLEFT", membersFrame, "TOPLEFT", 0, 0)
    membersTitle:SetPoint("RIGHT", membersFrame, "RIGHT", 0, 0)
    local membersList = CreateFrame("Frame", nil, membersFrame)
    membersList:SetPoint("TOPLEFT", membersFrame, "TOPLEFT", 0, -22)
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
        inset = true,
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

    local pickerFrame = CreateFrame("Frame", nil, panel)
    pickerFrame:SetPoint("TOPLEFT", panel, "TOP", 4, -70)
    pickerFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local pickerTitle = UI.SectionHeader(pickerFrame, L["Add members"])
    pickerTitle:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 0, 0)
    pickerTitle:SetPoint("RIGHT", pickerFrame, "RIGHT", 0, 0)
    local search = UI.SearchBox(pickerFrame, 160, function(text) pickerText = text panel:OnShow() end)
    search:SetPoint("RIGHT", pickerTitle, "RIGHT", -4, 0)
    panel.search = search
    local pickerList = CreateFrame("Frame", nil, pickerFrame)
    pickerList:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 0, -22)
    pickerList:SetPoint("BOTTOMRIGHT", pickerFrame, "BOTTOMRIGHT", 0, 0)
    local picker = UI.List(pickerList, 22, function(button, e)
        button.key = e.key
        TG.SetClassIcon(button.icon, e.classFile)
        local role = TG.Store:Get("role", e.key)
        button.name:SetText((role and (TG.RoleIconMarkup(role, 14) .. " ") or "") .. TG.ClassText(e.classFile, e.key) .. GRAY_FONT_COLOR:WrapTextInColorCode(" " .. (e.level or "")))
    end, {
        inset = true,
        buildRow = function(button)
            button.icon = UI.ClassIcon(button, 16)
            button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.name = UI.Cell(button, 240)
            button.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
            button.add = UI.Button(button, L["Add"], 60, function() Raids:AddMember(selectedTeam, button.key) panel:OnShow() end)
            button.add:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end,
    })

    local builderFrame = CreateFrame("Frame", nil, panel)
    builderFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -70)
    builderFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local builderHint = UI.Label(builderFrame, L["Click a slot to place a member, right click to clear it."], "GameFontDisableSmall")
    builderHint:SetPoint("TOPLEFT", builderFrame, "TOPLEFT", 8, -2)

    local BOX_W, BOX_GAP, SLOT_H, COLS = 143, 4, 20, 4
    local BOX_H = SLOT_H * 6 + 8
    local boxes = {}
    local builderRoles, builderFree = {}, {}

    local function memberText(key)
        local e = TG.Roster:Get(key)
        local short = TG.ShortName(key)
        local name = (e and e.online) and TG.ClassText(e.classFile, short) or GRAY_FONT_COLOR:WrapTextInColorCode(short)
        local role = builderRoles[key]
        return (role and (roleIcon(role) .. " ") or "") .. name
    end

    local function slotMenu(slot)
        if not Raids:CanEdit() or not selectedTeam then return end
        MenuUtil.CreateContextMenu(slot, function(_, root)
            root:SetTag("MENU_THEGUILD_RAID_SLOT")
            root:CreateTitle(L["Group %d"]:format(slot.group))
            if slot.key then
                root:CreateButton(L["Clear slot"], function() Raids:Assign(selectedTeam, slot.key, nil) panel:OnShow() end)
            end
            if #builderFree > 16 then root:SetScrollMode(16 * 20) end
            for _, key in ipairs(builderFree) do
                root:CreateButton(memberText(key), function()
                    if slot.key then Raids:Assign(selectedTeam, slot.key, nil) end
                    Raids:Assign(selectedTeam, key, slot.group)
                    panel:OnShow()
                end)
            end
        end)
    end

    local function createBox(g)
        local box = UI.Inset(builderFrame)
        box:SetSize(BOX_W, BOX_H)
        local col, row = (g - 1) % COLS, math.floor((g - 1) / COLS)
        box:SetPoint("TOPLEFT", builderFrame, "TOPLEFT", 8 + col * (BOX_W + BOX_GAP), -20 - row * (BOX_H + 6))
        box.title = UI.Label(box, L["Group %d"]:format(g), "GameFontNormalSmall")
        box.title:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
        box.counts = UI.Label(box, "", "GameFontHighlightSmall", "RIGHT")
        box.counts:SetPoint("TOPRIGHT", box, "TOPRIGHT", -6, -6)
        box.slots = {}
        for i = 1, 5 do
            local slot = CreateFrame("Button", nil, box)
            slot:SetSize(BOX_W - 8, SLOT_H - 2)
            slot:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -(SLOT_H + 4) - (i - 1) * SLOT_H)
            slot:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            slot:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
            slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            slot.text = UI.Cell(slot, BOX_W - 14)
            slot.text:SetPoint("LEFT", slot, "LEFT", 3, 0)
            slot.group = g
            slot:SetScript("OnClick", function(self, mouse)
                if mouse == "RightButton" then
                    if self.key and Raids:CanEdit() then Raids:Assign(selectedTeam, self.key, nil) panel:OnShow() end
                else
                    slotMenu(self)
                end
            end)
            UI.Tooltip(slot, function(tooltip, self)
                local e = self.key and TG.Roster:Get(self.key)
                if e then UI.MemberTooltip(tooltip, e) else GameTooltip_SetTitle(tooltip, L["Free slot"]) end
            end)
            box.slots[i] = slot
        end
        return box
    end

    local freeFrame = CreateFrame("Frame", nil, builderFrame)
    freeFrame:SetPoint("TOPLEFT", builderFrame, "TOPLEFT", 12 + COLS * (BOX_W + BOX_GAP), -2)
    freeFrame:SetPoint("BOTTOMRIGHT", builderFrame, "BOTTOMRIGHT", 0, 34)
    local freeTitle = UI.SectionHeader(freeFrame, L["Unassigned"])
    freeTitle:SetPoint("TOPLEFT", freeFrame, "TOPLEFT", 0, 0)
    freeTitle:SetPoint("RIGHT", freeFrame, "RIGHT", -4, 0)
    local freeListFrame = CreateFrame("Frame", nil, freeFrame)
    freeListFrame:SetPoint("TOPLEFT", freeFrame, "TOPLEFT", 0, -22)
    freeListFrame:SetPoint("BOTTOMRIGHT", freeFrame, "BOTTOMRIGHT", 0, 0)
    local freeList = UI.List(freeListFrame, 20, function(button, key)
        button.key = key
        button.text:SetText(memberText(key))
    end, {
        inset = true,
        buildRow = function(button)
            button.text = UI.Cell(button, 180)
            button.text:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            button:SetScript("OnClick", function(self, mouse)
                local e = TG.Roster:Get(self.key)
                if e and mouse == "RightButton" then UI.MemberMenu(self, e) end
            end)
            UI.Tooltip(button, function(tooltip, self)
                local e = TG.Roster:Get(self.key)
                if e then UI.MemberTooltip(tooltip, e) end
            end)
        end,
    })

    local builderSummary = UI.Label(builderFrame, "", "GameFontHighlightSmall")
    builderSummary:SetPoint("BOTTOMLEFT", builderFrame, "BOTTOMLEFT", 10, 10)
    local apply = UI.Button(builderFrame, L["Apply to raid"], 160, function()
        if not selectedTeam then return end
        TG:Print(L["%d members moved."], Raids:ApplyLayout(selectedTeam))
    end)
    apply:SetPoint("BOTTOMRIGHT", builderFrame, "BOTTOMRIGHT", -8, 6)
    UI.Tooltip(apply, function(tooltip)
        GameTooltip_SetTitle(tooltip, L["Apply to raid"])
        GameTooltip_AddNormalLine(tooltip, L["Moves raid members into the planned groups. You need to lead the raid."], true)
    end)
    local clearLayout = UI.Button(builderFrame, L["Clear layout"], 120, function()
        if selectedTeam then Raids:ClearLayout(selectedTeam) panel:OnShow() end
    end)
    clearLayout:SetPoint("RIGHT", apply, "LEFT", -6, 0)
    local autoFill = UI.Button(builderFrame, L["Auto fill"], 120, function()
        if selectedTeam then Raids:AutoFill(selectedTeam) panel:OnShow() end
    end)
    autoFill:SetPoint("RIGHT", clearLayout, "LEFT", -6, 0)

    local function showBuilder(team, canEdit)
        builderRoles = team and Raids:Roles(team) or {}
        local groups, free = {}, {}
        if team then groups, free = Raids:Layout(team) end
        builderFree = free
        local count = team and Raids:GroupCount(team) or 0
        for g = 1, math.max(count, #boxes) do
            if g <= count then
                boxes[g] = boxes[g] or createBox(g)
                local box = boxes[g]
                box:Show()
                local members = groups[g]
                local c = Raids:RoleCounts(members, builderRoles)
                box.counts:SetText(("%s%d %s%d %s%d"):format(roleIcon("T"), c.T, roleIcon("H"), c.H, roleIcon("D"), c.D))
                for i, slot in ipairs(box.slots) do
                    slot.key = members[i]
                    slot.text:SetText(slot.key and memberText(slot.key) or GRAY_FONT_COLOR:WrapTextInColorCode("..."))
                end
            else
                boxes[g]:Hide()
            end
        end
        freeList:SetData(free)
        local total = Raids:RoleCounts(team and team.members or {}, builderRoles)
        builderSummary:SetText(("%s %d   %s %d   %s %d   %s %d"):format(L["Tank"], total.T, L["Healer"], total.H, L["Damage"], total.D, L["No role"], total.N))
        autoFill:SetShown(canEdit and team ~= nil)
        clearLayout:SetShown(canEdit and team ~= nil)
        apply:SetEnabled(team ~= nil and IsInRaid() and TG.IsGroupLead())
    end

    local scheduleFrame = CreateFrame("Frame", nil, panel)
    scheduleFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -70)
    scheduleFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local daysTitle = UI.SectionHeader(scheduleFrame, L["Raid days"])
    daysTitle:SetPoint("TOPLEFT", scheduleFrame, "TOPLEFT", 0, 0)
    daysTitle:SetPoint("RIGHT", scheduleFrame, "CENTER", -4, 0)
    daysTitle:SetRightText(GRAY_FONT_COLOR:WrapTextInColorCode(L["Times are server time."]))

    local newDay = { w = 5, h = 20, m = 0 }
    local dayDropdown = UI.Dropdown(scheduleFrame, 130, function(_, root)
        for i = 1, 7 do
            local wday = i % 7 + 1
            root:CreateRadio(Raids:WeekdayName(wday), function() return newDay.w == wday end, function() newDay.w = wday panel:OnShow() end)
        end
    end)
    dayDropdown:SetPoint("TOPLEFT", daysTitle, "BOTTOMLEFT", 4, -6)
    local hourDropdown = UI.Dropdown(scheduleFrame, 64, function(_, root)
        for h = 0, 23 do
            root:CreateRadio(("%02d"):format(h), function() return newDay.h == h end, function() newDay.h = h panel:OnShow() end)
        end
    end)
    hourDropdown:SetPoint("LEFT", dayDropdown, "RIGHT", 4, 0)
    local minuteDropdown = UI.Dropdown(scheduleFrame, 64, function(_, root)
        for _, m in ipairs({ 0, 15, 30, 45 }) do
            root:CreateRadio(("%02d"):format(m), function() return newDay.m == m end, function() newDay.m = m panel:OnShow() end)
        end
    end)
    minuteDropdown:SetPoint("LEFT", hourDropdown, "RIGHT", 4, 0)
    local addDay = UI.Button(scheduleFrame, L["Add"], 80, function()
        if selectedTeam then Raids:AddRaidDay(selectedTeam, newDay.w, newDay.h, newDay.m) panel:OnShow() end
    end)
    addDay:SetPoint("LEFT", minuteDropdown, "RIGHT", 6, 0)

    local daysListFrame = CreateFrame("Frame", nil, scheduleFrame)
    daysListFrame:SetPoint("TOPLEFT", scheduleFrame, "TOPLEFT", 0, -54)
    daysListFrame:SetPoint("BOTTOMRIGHT", scheduleFrame, "BOTTOM", -4, 0)
    local noDays = UI.Empty(daysListFrame, L["No raid days yet."])
    local daysList = UI.List(daysListFrame, 22, function(button, row)
        button.index = row.index
        button.text:SetText(("%s %02d:%02d"):format(Raids:WeekdayName(row.w), row.h, row.m))
        button.remove:SetShown(Raids:CanEdit())
    end, {
        inset = true,
        buildRow = function(button)
            button.text = UI.Cell(button, 240)
            button.text:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.remove = UI.Button(button, REMOVE, 70, function() Raids:RemoveRaidDay(selectedTeam, button.index) panel:OnShow() end)
            button.remove:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end,
    })

    local upcomingTitle = UI.SectionHeader(scheduleFrame, L["Upcoming raid nights"])
    upcomingTitle:SetPoint("TOPLEFT", scheduleFrame, "TOP", 4, 0)
    upcomingTitle:SetPoint("RIGHT", scheduleFrame, "RIGHT", 0, 0)
    local export = UI.Button(scheduleFrame, L["Export to calendar"], 180, function()
        if not selectedTeam then return end
        local created, existing = Raids:ExportCalendar(selectedTeam, Raids.db.calendarWeeks)
        TG:Print(L["%d events created, %d already existed."], created, existing)
        panel:OnShow()
    end)
    export:SetPoint("BOTTOMRIGHT", scheduleFrame, "BOTTOMRIGHT", -4, 2)
    UI.Tooltip(export, function(tooltip)
        GameTooltip_SetTitle(tooltip, L["Export to calendar"])
        GameTooltip_AddNormalLine(tooltip, L["Creates guild sign up events for the next weeks. Existing events are kept."], true)
    end)
    local upcomingListFrame = CreateFrame("Frame", nil, scheduleFrame)
    upcomingListFrame:SetPoint("TOPLEFT", scheduleFrame, "TOP", 4, -22)
    upcomingListFrame:SetPoint("BOTTOMRIGHT", scheduleFrame, "BOTTOMRIGHT", 0, 28)
    local upcomingList = UI.List(upcomingListFrame, 22, function(button, r)
        button.text:SetText(Raids:FormatRaid(r))
        button.status:SetText(r.inCalendar and GREEN_FONT_COLOR:WrapTextInColorCode(L["in calendar"]) or "")
    end, {
        inset = true,
        buildRow = function(button)
            button.text = UI.Cell(button, 240)
            button.text:SetPoint("LEFT", button, "LEFT", 6, 0)
            button.status = UI.Cell(button, 120, "RIGHT")
            button.status:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        end,
    })

    local function showSchedule(team, canEdit)
        TG.Calendar.Request()
        dayDropdown:SetDefaultText(Raids:WeekdayName(newDay.w))
        hourDropdown:SetDefaultText(("%02d"):format(newDay.h))
        minuteDropdown:SetDefaultText(("%02d"):format(newDay.m))
        local editing = canEdit and team ~= nil
        dayDropdown:SetShown(editing)
        hourDropdown:SetShown(editing)
        minuteDropdown:SetShown(editing)
        addDay:SetShown(editing)
        local days = team and Raids:Schedule(team) or {}
        noDays:SetShown(#days == 0)
        daysList:SetData(days)
        local upcoming = team and Raids:Upcoming(team, Raids.db.calendarWeeks) or {}
        for _, r in ipairs(upcoming) do r.inCalendar = Raids:InCalendar(r) end
        upcomingList:SetData(upcoming)
        export:SetEnabled(#upcoming > 0 and Raids:CanExport())
    end

    local attendanceFrame = CreateFrame("Frame", nil, panel)
    attendanceFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -70)
    attendanceFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local attendanceInfo = UI.SectionHeader(attendanceFrame, L["Attendance"])
    attendanceInfo:SetPoint("TOPLEFT", attendanceFrame, "TOPLEFT", 0, 0)
    attendanceInfo:SetPoint("RIGHT", attendanceFrame, "RIGHT", 0, 0)
    local attendanceList = CreateFrame("Frame", nil, attendanceFrame)
    attendanceList:SetPoint("TOPLEFT", attendanceFrame, "TOPLEFT", 0, -22)
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
        inset = true,
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

    TG.Tutorial:Define("raids", {
        { target = teamDropdown, text = L["Pick a raid team. Teams are shared with the whole guild."], point = "bottom" },
        { target = newTeam, text = L["Creates a team. Officers manage teams, everyone can see them."], point = "bottom" },
        { target = sizeDropdown, text = L["Team size 10, 20 or 40. The group builder plans the subgroups accordingly."], point = "bottom" },
        { target = invite, text = L["Invites every online team member and converts to a raid when needed."], point = "bottom" },
        { target = function() return viewTabs:FirstButton() end, text = L["Members, the group builder, raid days with calendar export and attendance live in these views."], point = "bottom" },
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
        viewTabs:Select(Raids.view)
        local view = Raids.view
        membersFrame:SetShown(view == "teams")
        pickerFrame:SetShown(view == "teams" and canEdit and team ~= nil)
        builderFrame:SetShown(view == "builder")
        scheduleFrame:SetShown(view == "schedule")
        attendanceFrame:SetShown(view == "attendance")

        if view == "teams" then
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
        elseif view == "builder" then
            showBuilder(team, canEdit)
        elseif view == "schedule" then
            showSchedule(team, canEdit)
        else
            local rows, days = Raids:Attendance(Raids.db.attendanceDays)
            for _, row in ipairs(rows) do row.allDays = days end
            attendanceInfo:SetRightText(#days > 0 and L["%d raid nights, newest first"]:format(#days) or GRAY_FONT_COLOR:WrapTextInColorCode(L["No raid nights recorded yet. Officers in a raid record attendance automatically."]))
            attendance:SetData(rows)
        end
    end

    TG:On("STORE_CHANGED", function(ns) if panel:IsShown() and (ns == "team" or ns == "att" or ns == "role") then panel:OnShow() end end, Raids)
    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Raids)
    TG:RegisterEvent("GROUP_ROSTER_UPDATE", function() if panel:IsShown() and Raids.view == "builder" then panel:OnShow() end end, Raids)
    TG:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST", function() if panel:IsShown() and Raids.view == "schedule" then panel:OnShow() end end, Raids)
end

TG.Window:RegisterTab("raids", L["Raids"], build, 25, "Interface\\Icons\\INV_Misc_Head_Dragon_01", "Raids")