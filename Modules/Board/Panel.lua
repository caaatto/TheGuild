local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Board = TG:GetModule("Board")

Board.view = "posts"

local VIEWS = { { "posts", L["Posts"] }, { "polls", L["Polls"] } }
local selectedPost, selectedPoll

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

    -- left list
    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -36)
    listFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 4)
    listFrame:SetWidth(310)
    local empty = UI.Label(listFrame, "", "GameFontDisableSmall", "CENTER")
    empty:SetPoint("CENTER")

    local list = UI.List(listFrame, 36, function(button, row)
        button.row = row
        local selected = (Board.view == "posts" and selectedPost or selectedPoll) == row.key
        button.title:SetText((row.pinned and (TG.gold .. "* |r") or "") .. (selected and TG.gold or "") .. (row.title or row.question) .. (selected and "|r" or ""))
        if Board.view == "posts" then
            button.meta:SetText(("%s  %s"):format(authorText(row.author), date("%d.%m.%y %H:%M", row.time)))
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
                if Board.view == "posts" then selectedPost = self.row.key else selectedPoll = self.row.key end
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
        elseif selectedPoll then
            StaticPopup_ShowGenericConfirmation(L["Delete poll?"], function() Board:DeletePoll(selectedPoll) selectedPoll = nil panel:OnShow() end)
        end
    end)
    local toggleButton = action("", function()
        if Board.view == "posts" and selectedPost then
            local v = TG.Store:Get("post", selectedPost)
            Board:SetPinned(selectedPost, not (type(v) == "table" and v.p == true))
        elseif selectedPoll then
            local v = TG.Store:Get("poll", selectedPoll)
            Board:ClosePoll(selectedPoll, not (type(v) == "table" and v.c == true))
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
        optionsFrame:Hide()
        if current then
            title:SetText(current.title)
            meta:SetText(("%s, %s"):format(L["by %s"]:format(authorText(current.author)), date("%d.%m.%Y %H:%M", current.time)))
            body:SetText(current.body)
            bodyChild:SetHeight((tonumber(body:GetStringHeight()) or 200) + 8)
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

    function panel:OnShow()
        viewDropdown:SetDefaultText(viewName())
        newPost:SetShown(Board.view == "posts" and Board:CanPost())
        newPoll:SetShown(Board.view == "polls" and Board:CanManage())
        if Board.view == "posts" then showPost() else showPoll() end
    end

    TG:On("STORE_CHANGED", function(ns)
        if panel:IsShown() and (ns == "post" or ns == "poll" or ns == "vote") then panel:OnShow() end
    end, Board)
    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Board)
end

TG.Window:RegisterTab("board", L["Board"], build, 28)
