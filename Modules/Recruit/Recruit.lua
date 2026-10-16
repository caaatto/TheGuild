local TG = TheGuild
local L = TG.L
local UI = TG.UI

local NS = "cand"
local MAX_NOTE = 120
local POST_COOLDOWN = 120
local KEEP_JOINED = 7 * 86400

local Recruit = TG:NewModule("Recruit", {
    title = L["Recruitment"],
    desc = L["Candidate list for officers with whisper, guild invite and status tracking."],
    order = 35,
    defaults = {
        welcomeWhisper = true,
        welcome = L["Welcome to %g, %n! If you have questions, just ask in guild chat."],
        message = L["%g is recruiting! Friendly guild, regular raids and dungeons. Whisper me for an invite."],
    },
    settings = {
        { key = "welcomeWhisper", type = "boolean", name = L["Whisper a welcome to candidates you invited once they join"], default = true },
    },
})

TG.Store:DefinePolicy(NS, "officer")

Recruit.STATUS = {
    { id = 1, text = L["New"], color = "|cffffffff" },
    { id = 2, text = L["Contacted"], color = "|cff40c0ff" },
    { id = 3, text = L["Invited"], color = "|cffffd100" },
    { id = 4, text = L["Joined"], color = "|cff40c040" },
    { id = 5, text = L["Declined"], color = "|cff808080" },
}

function Recruit:StatusText(id)
    for _, s in ipairs(self.STATUS) do
        if s.id == id then return s.color .. s.text .. "|r", s.text end
    end
    return "", ""
end

function Recruit:CanManage()
    if not IsInGuild() then return false end
    if TG.Roster:AmOfficer() then return true end
    local can = CanGuildInvite and CanGuildInvite()
    return TG.usable(can) and can == true
end

function Recruit:Candidates()
    local out = {}
    for key, item in pairs(TG.Store:Items(NS)) do
        local v = item.v
        if type(v) == "table" then
            out[#out + 1] = { key = key, note = v.n or "", status = v.s or 1, time = v.t or item.t or 0, by = v.by or item.a, inviter = v.i }
        end
    end
    table.sort(out, function(a, b)
        if a.status ~= b.status then return a.status < b.status end
        return a.time > b.time
    end)
    return out
end

local function save(key, v)
    return TG.Store:Set(NS, key, v)
end

function Recruit:Add(name, note)
    name = TG.StripRealm(TG.Trim(name or ""))
    if not name or name == "" or not self:CanManage() then return false end
    if TG.Roster:Get(name) then return false end
    if TG.Store:Get(NS, name) then return false end
    return save(name, { n = TG.Trim(note or ""):sub(1, MAX_NOTE), s = 1, t = TG.Now(), by = TG.MyName() })
end

function Recruit:Update(key, changes)
    local v = TG.Store:Get(NS, key)
    if type(v) ~= "table" or not self:CanManage() then return false end
    local copy = { n = v.n, s = v.s, t = v.t, by = v.by, i = v.i }
    for k, value in pairs(changes) do copy[k] = value end
    return save(key, copy)
end

function Recruit:SetStatus(key, status)
    return self:Update(key, { s = status })
end

function Recruit:SetNote(key, note)
    return self:Update(key, { n = TG.Trim(note or ""):sub(1, MAX_NOTE) })
end

function Recruit:Remove(key)
    if not self:CanManage() then return false end
    return TG.Store:Delete(NS, key)
end

function Recruit:Invite(key)
    if not self:CanManage() or not TG.Store:Get(NS, key) then return false end
    if C_GuildInfo and C_GuildInfo.Invite then
        C_GuildInfo.Invite(TG.Address(key))
    elseif GuildInvite then
        GuildInvite(TG.Address(key))
    else
        return false
    end
    self:Update(key, { s = 3, i = TG.MyName() })
    return true
end

local function fill(template, name)
    local guild = TG.Roster:GuildName() or ""
    return (template:gsub("%%n", TG.ShortName(name)):gsub("%%g", guild))
end

function Recruit:OnJoined(entry)
    local v = TG.Store:Get(NS, entry.key)
    if type(v) ~= "table" then return end
    TG.Log:Add("recruited", entry.key, {})
    if self.db.welcomeWhisper and v.i and TG.IsMe(v.i) and v.s ~= 4 then
        local text = fill(self.db.welcome, entry.key)
        if text ~= "" then SendChatMessage(text:sub(1, 255), "WHISPER", nil, TG.Address(entry.key)) end
    end
    if self:CanManage() and v.s ~= 4 then self:Update(entry.key, { s = 4, t = TG.Now() }) end
end

-- Joined candidates leave the list after a week.
function Recruit:Prune()
    if not self:CanManage() then return end
    local cutoff = TG.Now() - KEEP_JOINED
    for _, c in ipairs(self:Candidates()) do
        if c.status == 4 and c.time < cutoff then TG.Store:Delete(NS, c.key) end
    end
end

-- Recruitment message

local lastPost = 0

function Recruit:Channels()
    local out = {}
    if not GetChannelList then return out end
    local list = { GetChannelList() }
    for i = 1, #list, 3 do
        local id, name, disabled = list[i], list[i + 1], list[i + 2]
        if TG.usable(id) and TG.usable(name) and type(name) == "string" and not disabled then
            out[#out + 1] = { id = id, name = name }
        end
    end
    return out
end

function Recruit:Post(channelID)
    local text = TG.Trim(fill(self.db.message or "", TG.MyName()))
    if text == "" or not channelID then return false end
    if GetTime() - lastPost < POST_COOLDOWN then
        TG:Print(L["Please wait %d seconds before posting again."], math.ceil(POST_COOLDOWN - (GetTime() - lastPost)))
        return false
    end
    lastPost = GetTime()
    SendChatMessage(text:sub(1, 255), "CHANNEL", nil, channelID)
    return true
end

function Recruit:OnEnable()
    self:On("MEMBER_JOINED", function(entry) self:OnJoined(entry) end)
    self:On("UNIT_MENU", function(root, name)
        if not self:CanManage() or not name or TG.Roster:Get(name) then return end
        root:CreateButton(L["Add as recruitment candidate"], function()
            if self:Add(name, "") then TG:Print(L["%s added to the candidate list."], name) end
        end)
    end)
    TG.After(60, function() if self.enabled then self:Prune() end end)
end

-- Tab

local columns = {
    { key = "name", text = L["Name"], width = 170 },
    { key = "status", text = L["Status"], width = 90 },
    { key = "note", text = L["Note"], width = 260 },
    { key = "by", text = L["Added by"], width = 150 },
}

local selectedChannel

local function build(panel)
    local add = UI.Button(panel, L["Add candidate"], 120, function()
        StaticPopup_ShowCustomGenericInputBox({
            text = L["Name of the candidate"], acceptText = ACCEPT, cancelText = CANCEL, maxLetters = 50,
            callback = function(text)
                if not Recruit:Add(text, "") then TG:Print(L["Candidate not added. Already listed or a guild member?"]) end
                panel:OnShow()
            end,
        })
    end)
    add:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)

    local editMessage = UI.Button(panel, L["Recruitment message"], 150, function()
        UI.TextDialog(L["Recruitment message"], Recruit.db.message, function(text)
            Recruit.db.message = TG.Trim(text):sub(1, 255)
        end, L["%g is the guild name, %n your name. Posted into the chosen channel."])
    end)
    editMessage:SetPoint("LEFT", add, "RIGHT", 6, 0)

    local post = UI.Button(panel, L["Post"], 70, function()
        if selectedChannel then Recruit:Post(selectedChannel) end
    end)
    post:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)

    local channels = UI.Dropdown(panel, 150, function(_, root)
        for _, ch in ipairs(Recruit:Channels()) do
            root:CreateRadio(ch.name, function() return selectedChannel == ch.id end, function()
                selectedChannel = ch.id
                panel:OnShow()
            end)
        end
    end)
    channels:SetPoint("RIGHT", post, "LEFT", -4, 0)

    local header = UI.Header(panel, columns)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -36)

    local listFrame = CreateFrame("Frame", nil, panel)
    listFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -1)
    listFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
    local empty = UI.Empty(listFrame, L["No candidates. Add players you talked to, or use the unit menu."])
    local locked = UI.Empty(panel, L["Recruitment is for officers and members who may invite."])

    local function menu(owner, row)
        MenuUtil.CreateContextMenu(owner, function(_, root)
            root:SetTag("MENU_THEGUILD_CANDIDATE")
            root:CreateTitle(row.key)
            for _, s in ipairs(Recruit.STATUS) do
                root:CreateRadio(s.text, function() return row.status == s.id end, function() Recruit:SetStatus(row.key, s.id) panel:OnShow() end)
            end
            root:CreateDivider()
            root:CreateButton(L["Edit note"], function()
                StaticPopup_ShowCustomGenericInputBox({
                    text = L["Note for %s"]:format(row.key), acceptText = ACCEPT, cancelText = CANCEL, maxLetters = MAX_NOTE,
                    callback = function(text) Recruit:SetNote(row.key, text) panel:OnShow() end,
                })
            end)
            root:CreateButton(REMOVE, function() Recruit:Remove(row.key) panel:OnShow() end)
        end)
    end

    local list = UI.List(listFrame, 24, function(button, row)
        button.row = row
        button.cells.name:SetText(row.key)
        button.cells.status:SetText((Recruit:StatusText(row.status)))
        button.cells.note:SetText(row.note)
        button.cells.by:SetText(("%s %s"):format(TG.ShortName(row.by or "?"), date("%d.%m.", row.time)))
        button.invite:SetEnabled(row.status ~= 4)
    end, {
        inset = true,
        buildRow = function(button)
            button.cells = UI.Cells(button, columns)
            button.whisper = UI.Button(button, L["Whisper"], 70, function() TG.Whisper(button.row.key) end)
            button.whisper:SetPoint("RIGHT", button, "RIGHT", -80, 0)
            button.invite = UI.Button(button, L["Invite"], 70, function() Recruit:Invite(button.row.key) panel:OnShow() end)
            button.invite:SetPoint("RIGHT", button, "RIGHT", -6, 0)
            button:SetScript("OnClick", function(self, mouse)
                if mouse == "RightButton" then menu(self, self.row) end
            end)
        end,
    })

    function panel:OnShow()
        local can = Recruit:CanManage()
        locked:SetShown(not can)
        add:SetShown(can)
        editMessage:SetShown(can)
        post:SetShown(can)
        channels:SetShown(can)
        header:SetShown(can)
        listFrame:SetShown(can)
        if not can then return end
        local available = Recruit:Channels()
        if not selectedChannel and available[1] then selectedChannel = available[1].id end
        local current
        for _, ch in ipairs(available) do if ch.id == selectedChannel then current = ch.name end end
        channels:SetDefaultText(current or L["Channel"])
        post:SetEnabled(current ~= nil)
        local rows = Recruit:Candidates()
        empty:SetShown(#rows == 0)
        list:SetData(rows)
    end

    TG:On("STORE_CHANGED", function(ns) if ns == NS and panel:IsShown() then panel:OnShow() end end, Recruit)
    TG:On("ROSTER_UPDATED", function() if panel:IsShown() then panel:OnShow() end end, Recruit)
end

TG.Window:RegisterTab("recruit", L["Recruitment"], build, 17, "Interface\\Icons\\Achievement_GuildPerk_FastTrack")
