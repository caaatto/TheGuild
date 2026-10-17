local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Voice = TG:GetModule("Voice")

local SIZE = 40
local LIST_WIDTH = 170
local ROW_HEIGHT = 18
local MAX_ROWS = 12
local hud

local ICONS = {
    on = { "voicechat-icon-mic", "Interface\\Common\\VoiceChat-On" },
    muted = { "voicechat-icon-mic-mute", "Interface\\Common\\VoiceChat-Muted" },
    silenced = { "voicechat-icon-mic-silenced", "Interface\\Common\\VoiceChat-Muted" },
    deafened = { "voicechat-icon-speaker-mute", "Interface\\Common\\VoiceChat-Speaker" },
}

local function setIcon(tex, spec)
    if UI.HasAtlas(spec[1]) then
        tex:SetAtlas(spec[1], false)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetTexture(spec[2])
    end
end

function Voice:SetMicIcon(tex)
    setIcon(tex, self:IsSilenced() and ICONS.silenced or self:IsMuted() and ICONS.muted or ICONS.on)
end

function Voice:IsMuted()
    if self.demoChannel then return self.demoMuted == true end
    return self:LoggedIn() and C_VoiceChat.IsMuted() == true
end

function Voice:IsDeafened()
    if self.demoChannel then return self.demoDeafened == true end
    return self:LoggedIn() and C_VoiceChat.IsDeafened() == true
end

function Voice:IsSilenced()
    if self.demoChannel then return false end
    return self:LoggedIn() and C_VoiceChat.IsSilenced ~= nil and C_VoiceChat.IsSilenced() == true
end

function Voice:ToggleMute()
    if self.demoChannel then
        self.demoMuted = not self.demoMuted
    elseif self:LoggedIn() then
        C_VoiceChat.ToggleMuted()
    end
    TG:Fire("VOICE_UPDATED")
end

function Voice:ToggleDeafen()
    if self.demoChannel then
        self.demoDeafened = not self.demoDeafened
    elseif self:LoggedIn() then
        C_VoiceChat.ToggleDeafened()
    end
    TG:Fire("VOICE_UPDATED")
end

function Voice:AudibleCount()
    local n = 0
    for _, row in ipairs(self:Members()) do
        if not row.isMe and row.active and row.volume > 0 then n = n + 1 end
    end
    return n
end

local function savePosition()
    local point, _, _, x, y = hud:GetPoint(1)
    Voice.db.hudPoint, Voice.db.hudX, Voice.db.hudY = point, x, y
end

local function applyPosition()
    local db = Voice.db
    hud:ClearAllPoints()
    hud:SetPoint(db.hudPoint or "CENTER", UIParent, db.hudPoint or "CENTER", db.hudX or 0, db.hudY or -220)
end

local function hudMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetTag("MENU_THEGUILD_VOICE")
        root:CreateTitle(L["Voice"])
        if Voice:IsJoined() then
            root:CreateButton(Voice:IsMuted() and L["Unmute"] or L["Mute"], function() Voice:ToggleMute() end)
            root:CreateButton(Voice:IsDeafened() and L["Undeafen"] or L["Deafen"], function() Voice:ToggleDeafen() end)
            root:CreateButton(L["Leave voice"], function() Voice:Leave() end)
        else
            root:CreateButton(L["Join voice"], function() Voice:Join() end)
        end
        root:CreateDivider()
        for _, m in ipairs(Voice.MODES) do
            root:CreateRadio(m[2], function() return Voice:Mode() == m[1] end, function()
                Voice:SetMode(m[1])
            end)
        end
        root:CreateDivider()
        root:CreateCheckbox(L["Lock position"], function() return Voice.db.hudLock end, function() Voice.db.hudLock = not Voice.db.hudLock end)
        root:CreateCheckbox(L["Show who is in voice"], function() return Voice.db.hudList end, function()
            Voice.db.hudList = not Voice.db.hudList
            Voice:RefreshHud()
        end)
        root:CreateButton(L["Open the voice tab"], function() TG.Window:ShowTab("voice") end)
        root:CreateButton(L["Hide the microphone button"], function()
            Voice.db.hud = false
            Voice:RefreshHud()
        end)
    end)
end

local function build()
    local f = CreateFrame("Button", "TheGuildVoiceHud", UIParent, "TooltipBackdropTemplate")
    f:SetSize(SIZE, SIZE)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not Voice.db.hudLock then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() end)
    f:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(26, 26)
    f.icon:SetPoint("CENTER")
    f.deaf = f:CreateTexture(nil, "OVERLAY")
    f.deaf:SetSize(14, 14)
    f.deaf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
    setIcon(f.deaf, ICONS.deafened)
    f.count = UI.Label(f, "", "GameFontHighlightSmall", "RIGHT")
    f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)

    f.list = UI.Card(f)
    f.list:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -4)
    f.list:SetWidth(LIST_WIDTH)
    f.list:EnableMouse(false)
    f.list.rows = {}
    f.list.more = UI.Label(f.list, "", "GameFontDisableSmall")
    f.list:Hide()
    TG.Tutorial:Define("hud", {
        { target = f, text = L["Left click mutes or unmutes, right click opens the menu, drag moves the button. Green means you are talking."], point = "right" },
        { target = f.list, text = L["Who is in voice. The row of a talking member turns green, faded rows are out of your hearing range."], point = "right" },
    })

    f:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            hudMenu(self)
        elseif not Voice:IsJoined() then
            Voice:Join()
        else
            Voice:ToggleMute()
        end
    end)
    UI.Tooltip(f, function(tooltip)
        GameTooltip_SetTitle(tooltip, L["Voice"])
        local active = not Voice:IsJoined() and Voice:ActiveChannel()
        if active then GameTooltip_AddNormalLine(tooltip, L["In voice channel %s"]:format(tostring(active.name))) end
        if not Voice:IsJoined() then
            GameTooltip_AddNormalLine(tooltip, L["Not in the guild voice channel."])
            GameTooltip_AddInstructionLine(tooltip, L["Click to join the guild voice channel."])
        else
            if Voice:IsSilenced() then
                GameTooltip_AddErrorLine(tooltip, L["Silenced"])
            elseif Voice:IsMuted() then
                GameTooltip_AddErrorLine(tooltip, L["Muted"])
            else
                GameTooltip_AddColoredLine(tooltip, L["Microphone on"], GREEN_FONT_COLOR)
            end
            if Voice:IsDeafened() then GameTooltip_AddErrorLine(tooltip, L["Deafened"]) end
            GameTooltip_AddNormalLine(tooltip, Voice:ModeName())
            GameTooltip_AddNormalLine(tooltip, L["%d members audible"]:format(Voice:AudibleCount()))
            local group = Voice:Group(Voice:MyGroup())
            if group then GameTooltip_AddNormalLine(tooltip, L["Voice group: %s"]:format(group.name)) end
            GameTooltip_AddInstructionLine(tooltip, L["Left click mutes or unmutes."])
        end
        GameTooltip_AddInstructionLine(tooltip, L["Right click opens the menu, drag to move."])
    end)
    return f
end

function Voice:RefreshHud()
    if not hud then return end
    if not (self.enabled and self.db.hud and (self.demoChannel or self:Available())) then
        hud:Hide()
        return
    end
    local channel = self:ActiveChannel()
    local joined = channel ~= nil
    local muted, silenced = self:IsMuted(), self:IsSilenced()
    self:SetMicIcon(hud.icon)
    hud.icon:SetDesaturated(not joined)
    hud.icon:SetAlpha(joined and 1 or 0.5)
    hud.speaking = not muted and not silenced and self:IsSpeaking()
    if hud.speaking then
        hud.icon:SetVertexColor(0.3, 1, 0.3)
        hud.icon:SetAlpha(1)
    else
        hud.icon:SetVertexColor(1, 1, 1)
    end
    hud.deaf:SetShown(joined and self:IsDeafened())
    hud.count:SetText(self:IsJoined() and tostring(self:AudibleCount()) or "")
    self:RefreshHudList(joined)
    if not TG.Tutorial:MaybeTour() and joined then TG.Tutorial:Start("hud") end
    hud:Show()
end

local function listRow(list, i)
    local row = list.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, list)
    row:SetSize(LIST_WIDTH - 12, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - (i - 1) * ROW_HEIGHT)
    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetAllPoints()
    row.fill:SetColorTexture(0.24, 0.84, 0.36, 0.12)
    row.fill:Hide()
    row.icon = UI.ClassIcon(row, 14)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.ring = UI.Border(row, 0.24, 0.84, 0.36, 1)
    row.name = UI.Cell(row, LIST_WIDTH - 42, "LEFT", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.mute = row:CreateTexture(nil, "ARTWORK")
    row.mute:SetSize(12, 12)
    row.mute:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    setIcon(row.mute, ICONS.muted)
    list.rows[i] = row
    return row
end

function Voice:RefreshHudList(joined)
    local list = hud and hud.list
    if not list then return end
    local rows = joined and self.db.hudList and self:Members() or {}
    if #rows == 0 then
        list:Hide()
        return
    end
    local shown = math.min(#rows, MAX_ROWS)
    for i = 1, shown do
        local row = listRow(list, i)
        local data = rows[i]
        local entry = TG.Roster:Get(data.key)
        TG.SetClassIcon(row.icon, entry and entry.classFile)
        local name = TG.ShortName(data.key)
        if data.isMe then name = TG.gold .. name .. "|r" elseif entry then name = TG.ClassText(entry.classFile, name) end
        row.name:SetText(name)
        row.ring:SetShown(data.speaking)
        row.fill:SetShown(data.speaking)
        row.mute:SetShown(data.muted)
        row:SetAlpha((data.isMe or data.volume > 0) and 1 or 0.45)
        row:Show()
    end
    for i = shown + 1, #list.rows do list.rows[i]:Hide() end
    if #rows > shown then
        list.more:SetText(L["and %d more"]:format(#rows - shown))
        list.more:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - shown * ROW_HEIGHT)
        list.more:Show()
    else
        list.more:Hide()
    end
    list:SetHeight(12 + shown * ROW_HEIGHT + (#rows > shown and ROW_HEIGHT or 0))
    list:Show()
end

function Voice:SetupHud()
    if not hud then hud = build() end
    applyPosition()
    self:On("VOICE_UPDATED", function() self:RefreshHud() end)
    for _, event in ipairs({ "VOICE_CHAT_MUTED_CHANGED", "VOICE_CHAT_DEAFENED_CHANGED", "VOICE_CHAT_SILENCED_CHANGED",
        "VOICE_CHAT_CHANNEL_TRANSMIT_CHANGED", "VOICE_CHAT_CHANNEL_ACTIVATED", "VOICE_CHAT_CHANNEL_DEACTIVATED" }) do
        self:RegisterEvent(event, function() self:RefreshHud() end)
    end
    self:RefreshHud()
end

function Voice:ResetHudIfHidden()
    if not hud then return end
    local left, bottom, width, height = hud:GetLeft(), hud:GetBottom(), hud:GetWidth(), hud:GetHeight()
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    if not left or not bottom or left + width < 0 or bottom + height < 0 or left > screenW or bottom > screenH then self:ResetHud() end
end

function Voice:ResetHud()
    self.db.hudPoint, self.db.hudX, self.db.hudY = nil, nil, nil
    if hud then applyPosition() end
end

function Voice:HideHud()
    if hud then hud:Hide() end
end

function Voice:Hud()
    return hud
end
