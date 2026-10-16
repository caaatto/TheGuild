local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Board = TG:GetModule("Board")

Board.view = "posts"

local VIEWS = { { "posts", L["Posts"] }, { "polls", L["Polls"] }, { "events", L["Events"] }, { "bounties", L["Bounties"] } }
local selectedPost, selectedPoll, selectedEvent, selectedBounty

local function viewName()
    for _, v in ipairs(VIEWS) do if v[1] == Board.view then return v[2] end end
    return ""
end

local function authorText(name)
    local e = TG.Roster:Get(name)
    return e and TG.ClassText(e.classFile, name) or name
end

local function compose(title, hint, onAccept)
    UI.TextDialog(title, "", onAccept, hint)
end

local function build(panel)
    local viewDropdown = UI.Dropdown(panel, 130, function(_, root)
        for _, v in ipairs(VIEWS) do
            root:CreateRadio(v[2], function() return Board.view == v[1] end, function()
                Board.view = v[1]
                panel:OnShow()
            end)
        end
    end)
    viewDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)

    local newPost = UI.Button(panel, L["New post"], 120, function()
        compose(L["New post"], L["The first line is the title."], function(text)
            local lines = TG.Lines(text)
            if #lines == 0 then return end
            local title = table.remove(lines, 1)
            local key = Board:Post(title, table.concat(lines, "\n"))
            if key then selectedPost = key end
            panel:OnShow()
        end)
    end)
    newPost:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local newPoll = UI.Button(panel, L["New poll"], 120, function()
        compose(L["New poll"], L["First line is the question, every further line one option (2 to 8)."], function(text)
            local lines = TG.Lines(text)
            if #lines < 3 then return end
            local question = table.remove(lines, 1)
            local key = Board:CreatePoll(question, lines)
            if key then selectedPoll = key end
            panel:OnShow()
        end)
    end)
    newPoll:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local newEvent = UI.Button(panel, L["New event"], 120, function()
        compose(L["New event"], L["First line is the title, second line date and time like 24.12.2026 19:30, the rest is the description."], function(text)
            local lines = TG.Lines(text)
            if #lines < 2 then return end
            local eventTitle = table.remove(lines, 1)
            local y, m, d, h, mi = Board:ParseEventDate(table.remove(lines, 1))
            if not y then
                TG:Print(L["Date not understood. Use 24.12.2026 19:30."])
                return
            end
            local key = Board:CreateEvent(eventTitle, table.concat(lines, "\n"), y, m, d, h, mi)
            if key then selectedEvent = key end
            panel:OnShow()
        end)
    end)
    newEvent:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local newBounty = UI.Button(panel, L["New bounty"], 120, function()
        compose(L["New bounty"], L["First line is the title, second line the reward, the rest is the description."], function(text)
            local lines = TG.Lines(text)
            if #lines < 2 then return end
            local bountyTitle = table.remove(lines, 1)
            local reward = table.remove(lines, 1)
            local key = Board:CreateBounty(bountyTitle, reward, table.concat(lines, "\n"))
            if key then selectedBounty = key end
            panel:OnShow()
        end)
    end)
    newBounty:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    -- left list
    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -36)
    listFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 4)
    listFrame:SetWidth(310)
    local empty = UI.Label(listFrame, "", "GameFontDisableSmall", "CENTER")
    empty:SetPoint("CENTER")

    local list = UI.List(listFrame, 36, function(button, row)
        button.row = row
        local current = Board.view == "posts" and selectedPost or Board.view == "polls" and selectedPoll or Board.view == "events" and selectedEvent or selectedBounty
        local selected = current == row.key
        button.title:SetText((row.pinned and (TG.gold .. "* |r") or "") .. (selected and TG.gold or "") .. (row.title or row.question) .. (selected and "|r" or ""))
        if Board.view == "posts" then
            button.meta:SetText(("%s  %s"):format(authorText(row.author), date("%d.%m.%y %H:%M", row.time)))
        elseif Board.view == "events" then
            local lists = Board:Signups(row)
            local when = Board:FormatEvent(row)
            if row.past then when = GRAY_FONT_COLOR:WrapTextInColorCode(when) end
            button.meta:SetText(("%s  %s"):format(when, L["%d yes, %d maybe"]:format(#lists[1], #lists[2])))
        elseif Board.view == "bounties" then
            local state = row.done and GRAY_FONT_COLOR:WrapTextInColorCode(L["Completed"]) or GREEN_FONT_COLOR:WrapTextInColorCode(L["Open"])
            button.meta:SetText(("%s  %s  %s"):format(state, row.reward, L["%d claimed"]:format(#Board:Claimers(row))))
        else
            local _, total = Board:Results(row)
            button.meta:SetText(("%s  %s  %s"):format(row.closed and GRAY_FONT_COLOR:WrapTextInColorCode(L["Closed"]) or GREEN_FONT_COLOR:WrapTextInColorCode(L["Open"]), L["%d votes"]:format(total), date("%d.%m.%y", row.time)))
        end
    end, {
        buildRow = function(button)
            button.title = UI.Cell(button, 280, "LEFT", "GameFontNormal")
            button.title:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -4)
            button.meta = UI.Cell(button, 280, "LEFT", "GameFontDisableSmall")
            button.meta:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 6, 4)
            button:SetScript("OnClick", function(self)
                if Board.view == "posts" then selectedPost = self.row.key
                elseif Board.view == "polls" then selectedPoll = self.row.key
                elseif Board.view == "events" then selectedEvent = self.row.key
                else selectedBounty = self.row.key end
                panel:OnShow()
            end)
        end,
    })

    -- right detail
    local detail = CreateFrame("Frame", nil, panel)
    detail:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 8, 0)
    detail:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local hint = UI.Label(detail, "", "GameFontDisableSmall", "CENTER")
    hint:SetPoint("CENTER")

    local title = UI.Label(detail, "", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -6)
    title:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    title:SetWordWrap(true)
    local meta = UI.Label(detail, "", "GameFontDisableSmall")
    meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    meta:SetPoint("RIGHT", detail, "RIGHT", -8, 0)

    local actions = {}
    local function action(text, fn)
        local b = UI.Button(detail, text, 110, fn)
        if #actions == 0 then
            b:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -8, 6)
        else
            b:SetPoint("RIGHT", actions[#actions], "LEFT", -4, 0)
        end
        actions[#actions + 1] = b
        return b
    end
    local deleteButton = action(DELETE, function()
        if Board.view == "posts" and selectedPost then
            StaticPopup_ShowGenericConfirmation(L["Delete post?"], function() Board:DeletePost(selectedPost) selectedPost = nil panel:OnShow() end)
        elseif Board.view == "polls" and selectedPoll then
            StaticPopup_ShowGenericConfirmation(L["Delete poll?"], function() Board:DeletePoll(selectedPoll) selectedPoll = nil panel:OnShow() end)
        elseif Board.view == "events" and selectedEvent then
            StaticPopup_ShowGenericConfirmation(L["Delete event?"], function() Board:DeleteEvent(selectedEvent) selectedEvent = nil panel:OnShow() end)
        elseif Board.view == "bounties" and selectedBounty then
            StaticPopup_ShowGenericConfirmation(L["Delete bounty?"], function() Board:DeleteBounty(selectedBounty) selectedBounty = nil panel:OnShow() end)
        end
    end)
    local toggleButton = action("", function()
        if Board.view == "posts" and selectedPost then
            local v = TG.Store:Get("post", selectedPost)
            Board:SetPinned(selectedPost, not (type(v) == "table" and v.p == true))
        elseif Board.view == "polls" and selectedPoll then
            local v = TG.Store:Get("poll", selectedPoll)
            Board:ClosePoll(selectedPoll, not (type(v) == "table" and v.c == true))
        elseif Board.view == "events" and selectedEvent then
            for _, ev in ipairs(Board:Events()) do
                if ev.key == selectedEvent then
                    local ok, existed = Board:ExportEvent(ev)
                    TG:Print(ok and L["Event added to the calendar."] or existed and L["The event is already in the calendar."] or L["The event could not be added to the calendar."])
                end
            end
        elseif Board.view == "bounties" and selectedBounty then
            local v = TG.Store:Get("bounty", selectedBounty)
            if type(v) == "table" and v.d then Board:ReopenBounty(selectedBounty)
            elseif Board:MyClaim(selectedBounty) then Board:Unclaim(selectedBounty)
            else Board:Claim(selectedBounty) end
        end
        panel:OnShow()
    end)

    local bodyScroll = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -10)
    bodyScroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -30, 34)
    local bodyChild = CreateFrame("Frame", nil, bodyScroll)
    bodyChild:SetSize(440, 1)
    bodyScroll:SetScrollChild(bodyChild)
    local body = UI.Label(bodyChild, "", "GameFontHighlight")
    body:SetPoint("TOPLEFT", bodyChild, "TOPLEFT", 0, 0)
    body:SetWidth(440)
    body:SetWordWrap(true)
    body:SetJustifyV("TOP")
    body:SetSpacing(2)

    local signup = CreateFrame("Frame", nil, detail)
    signup:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -8)
    signup:SetSize(300, 24)
    local signupButtons = {}
    for i, text in ipairs({ L["Yes"], L["Maybe"], L["No"] }) do
        local b = UI.Button(signup, text, 90, function() Board:SignUp(selectedEvent, i) panel:OnShow() end)
        b:SetPoint("LEFT", signup, "LEFT", (i - 1) * 96, 0)
        signupButtons[i] = b
    end

    local claimsFrame = CreateFrame("Frame", nil, detail)
    claimsFrame:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", -4, -8)
    claimsFrame:SetPoint("RIGHT", detail, "RIGHT", 0, 0)
    claimsFrame:SetHeight(110)
    local claims = UI.List(claimsFrame, 26, function(button, row)
        button.row = row
        button.text:SetText(authorText(row.name))
        button.when:SetText(date("%d.%m.%y %H:%M", row.time))
        button.award:SetShown(row.canAward)
    end, {
        buildRow = function(button)
            button.text = UI.Cell(button, 200, "LEFT", "GameFontHighlight")
            button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
            button.when = UI.Cell(button, 110, "LEFT", "GameFontDisableSmall")
            button.when:SetPoint("LEFT", button.text, "RIGHT", 6, 0)
            button.award = UI.Button(button, L["Award"], 80, function() Board:CompleteBounty(selectedBounty, button.row.name) panel:OnShow() end)
            button.award:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end,
    })

    local optionsFrame = CreateFrame("Frame", nil, detail)
    optionsFrame:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", -4, -10)
    optionsFrame:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 34)
    local options = UI.List(optionsFrame, 26, function(button, row)
        button.row = row
        button.text:SetText((row.mine and (TG.gold .. "> |r") or "") .. row.text)
        button.count:SetText(("%d  (%d%%)"):format(row.count, row.percent))
        local bar = math.floor(row.percent / 5)
        button.bar:SetText(GREEN_FONT_COLOR:WrapTextInColorCode(string.rep("|", bar)) .. GRAY_FONT_COLOR:WrapTextInColorCode(string.rep("|", 20 - bar)))
        button.vote:SetShown(row.open and not row.mine)
    end, {
        buildRow = function(button)
            button.text = UI.Cell(button, 220, "LEFT", "GameFontHighlight")
            button.text:SetPoint("LEFT", button, "LEFT", 8, 0)
            button.bar = UI.Cell(button, 90, "LEFT", "GameFontHighlightSmall")
            button.bar:SetPoint("LEFT", button.text, "RIGHT", 6, 0)
            button.count = UI.Cell(button, 80, "LEFT", "GameFontHighlightSmall")
            button.count:SetPoint("LEFT", button.bar, "RIGHT", 6, 0)
            button.vote = UI.Button(button, L["Vote"], 70, function() Board:Vote(selectedPoll, button.row.index) panel:OnShow() end)
            button.vote:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            UI.Tooltip(button, function(tooltip, self)
                GameTooltip_SetTitle(tooltip, self.row.text)
                for _, name in ipairs(self.row.voters) do GameTooltip_AddNormalLine(tooltip, authorText(name)) end
            end)
        end,
    })

    local function showPost()
        local posts = Board:Posts()
        local current
        for _, p in ipairs(posts) do if p.key == selectedPost then current = p end end
        if not current then
            current = posts[1]
            selectedPost = current and current.key
        end
        empty:SetText(L["No posts yet."])
        empty:SetShown(#posts == 0)
        list:SetData(posts)
        hint:SetText(L["Select a post."])
        hint:SetShown(current == nil)
        title:SetShown(current ~= nil)
        meta:SetShown(current ~= nil)
        bodyScroll:SetShown(current ~= nil)
        bodyScroll:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -10)
        optionsFrame:Hide()
        signup:Hide()
        claimsFrame:Hide()
        toggleButton:SetWidth(110)
        if current then
            title:SetText(current.title)
            meta:SetText(("%s, %s"):format(L["by %s"]:format(authorText(current.author)), date("%d.%m.%Y %H:%M", current.time)))
            body:SetText(current.body)
            local height = body:GetStringHeight()
            bodyChild:SetHeight((tonumber(height) or 200) + 8)
            local canEdit = Board:CanEditPost(current)
            deleteButton:SetShown(canEdit)
            toggleButton:SetShown(Board:CanManage())
            toggleButton:SetText(current.pinned and L["Unpin"] or L["Pin"])
        else
            deleteButton:Hide()
            toggleButton:Hide()
        end
    end

    local function showPoll()
        local polls = Board:Polls()
        local current
        for _, p in ipairs(polls) do if p.key == selectedPoll then current = p end end
        if not current then
            current = polls[1]
            selectedPoll = current and current.key
        end
        empty:SetText(L["No polls yet."])
        empty:SetShown(#polls == 0)
        list:SetData(polls)
        hint:SetText(L["Select a poll."])
        hint:SetShown(current == nil)
        title:SetShown(current ~= nil)
        meta:SetShown(current ~= nil)
        bodyScroll:Hide()
        signup:Hide()
        claimsFrame:Hide()
        toggleButton:SetWidth(110)
        optionsFrame:SetShown(current ~= nil)
        if current then
            local counts, total, voters = Board:Results(current)
            local mine = Board:MyVote(current.key)
            title:SetText(current.question)
            meta:SetText(("%s, %s, %s, %s"):format(L["by %s"]:format(authorText(current.author or "?")), date("%d.%m.%Y", current.time), L["%d votes"]:format(total), current.closed and L["Closed"] or L["Open"]))
            local rows = {}
            for i, text in ipairs(current.options) do
                rows[#rows + 1] = { index = i, text = text, count = counts[i], percent = total > 0 and math.floor(counts[i] / total * 100 + 0.5) or 0, mine = mine == i, open = not current.closed, voters = voters[i] }
            end
            options:SetData(rows)
            local manage = Board:CanManage()
            deleteButton:SetShown(manage)
            toggleButton:SetShown(manage)
            toggleButton:SetText(current.closed and L["Reopen"] or L["Close poll"])
        else
            deleteButton:Hide()
            toggleButton:Hide()
        end
    end

    local function names(list)
        if #list == 0 then return GRAY_FONT_COLOR:WrapTextInColorCode("...") end
        local out = {}
        for _, n in ipairs(list) do out[#out + 1] = authorText(n) end
        return table.concat(out, ", ")
    end

    local function showEvent()
        TG.Calendar.Request()
        local events = Board:Events()
        local current
        for _, e in ipairs(events) do if e.key == selectedEvent then current = e end end
        if not current then
            current = events[1]
            selectedEvent = current and current.key
        end
        empty:SetText(L["No events yet."])
        empty:SetShown(#events == 0)
        list:SetData(events)
        hint:SetText(L["Select an event."])
        hint:SetShown(current == nil)
        title:SetShown(current ~= nil)
        meta:SetShown(current ~= nil)
        optionsFrame:Hide()
        claimsFrame:Hide()
        signup:SetShown(current ~= nil)
        bodyScroll:SetShown(current ~= nil)
        bodyScroll:SetPoint("TOPLEFT", signup, "BOTTOMLEFT", 0, -8)
        toggleButton:SetWidth(170)
        if current then
            title:SetText(current.title)
            meta:SetText(("%s, %s"):format(Board:FormatEvent(current), L["by %s"]:format(authorText(current.author))))
            local lists = Board:Signups(current)
            local mine = Board:MySignup(current.key)
            for i, b in ipairs(signupButtons) do b:SetEnabled(mine ~= i and not current.past) end
            local text = ("%s%s (%d):|r %s\n%s%s (%d):|r %s\n%s%s (%d):|r %s"):format(
                TG.gold, L["Yes"], #lists[1], names(lists[1]),
                TG.gold, L["Maybe"], #lists[2], names(lists[2]),
                TG.gold, L["No"], #lists[3], names(lists[3]))
            if current.desc ~= "" then text = text .. "\n\n" .. current.desc end
            body:SetText(text)
            local height = body:GetStringHeight()
            bodyChild:SetHeight((tonumber(height) or 200) + 8)
            deleteButton:SetShown(Board:CanEditEvent(current))
            toggleButton:SetShown(TG.Calendar.CanAdd() and not current.past)
            toggleButton:SetText(L["Export to calendar"])
        else
            deleteButton:Hide()
            toggleButton:Hide()
        end
    end

    local function showBounty()
        local bounties = Board:Bounties()
        local current
        for _, b in ipairs(bounties) do if b.key == selectedBounty then current = b end end
        if not current then
            current = bounties[1]
            selectedBounty = current and current.key
        end
        empty:SetText(L["No bounties yet."])
        empty:SetShown(#bounties == 0)
        list:SetData(bounties)
        hint:SetText(L["Select a bounty."])
        hint:SetShown(current == nil)
        title:SetShown(current ~= nil)
        meta:SetShown(current ~= nil)
        optionsFrame:Hide()
        signup:Hide()
        claimsFrame:SetShown(current ~= nil)
        bodyScroll:SetShown(current ~= nil)
        bodyScroll:SetPoint("TOPLEFT", claimsFrame, "BOTTOMLEFT", 4, -6)
        toggleButton:SetWidth(110)
        if current then
            local mine = current.author == TG.MyName()
            local canEdit = Board:CanEditBounty(current)
            title:SetText(current.title)
            local state = current.done and L["Completed by %s"]:format(current.winner and authorText(current.winner) or "?") or L["Open"]
            meta:SetText(("%s, %s, %s, %s"):format(L["Reward: %s"]:format(current.reward), L["by %s"]:format(authorText(current.author)), date("%d.%m.%Y", current.time), state))
            local rows = Board:Claimers(current)
            for _, row in ipairs(rows) do row.canAward = canEdit and not current.done end
            claims:SetData(rows)
            body:SetText(#rows == 0 and not current.done and (GRAY_FONT_COLOR:WrapTextInColorCode(L["Nobody has claimed this bounty yet."]) .. "\n\n" .. current.desc) or current.desc)
            local height = body:GetStringHeight()
            bodyChild:SetHeight((tonumber(height) or 200) + 8)
            deleteButton:SetShown(canEdit)
            if current.done then
                toggleButton:SetShown(canEdit)
                toggleButton:SetText(L["Reopen"])
            else
                toggleButton:SetShown(not mine)
                toggleButton:SetText(Board:MyClaim(current.key) and L["Withdraw"] or L["Claim"])
            end
        else
            deleteButton:Hide()
            toggleButton:Hide()
        end
    end

    function panel:OnShow()
        viewDropdown:SetDefaultText(viewName())
        newPost:SetShown(Board.view == "posts" and Board:CanPost())
        newPoll:SetShown(Board.view == "polls" and Board:CanManage())
        newEvent:SetShown(Board.view == "events" and Board:CanPost())
        newBounty:SetShown(Board.view == "bounties" and Board:CanPost())
        if Board.view == "posts" then showPost()
        elseif Board.view == "polls" then showPoll()
        elseif Board.view == "events" then showEvent()
        else showBounty() end
    end

    TG:On("STORE_CHANGED", function(ns)
        if panel:IsShown() and (ns == "post" or ns == "poll" or ns == "vote" or ns == "event" or ns == "signup" or ns == "bounty" or ns == "claim") then panel:OnShow() end
    end, Board)
    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Board)
end

TG.Window:RegisterTab("board", L["Board"], build, 28)
