local TG = TheGuild
local L = TG.L
local UI = TG.UI
local Voice = TG:GetModule("Voice")

local SIZE = 40
local hud

local ICONS = {
    on = { "voicechat-icon-mic", "Interface\\Common\\VoiceChat-On" },
    muted = { "voicechat-icon-mic-mute", "Interface\\Common\\VoiceChat-Muted" },
    silenced = { "voicechat-icon-mic-silenced", "Interface\\Common\\VoiceChat-Muted" },
    deafened = { "voicechat-icon-speaker-mute", "Interface\\Common\\VoiceChat-Speaker" },
}

local function setIcon(tex, spec)
    if UI.HasAtlas(spec[1]) then tex:SetAtlas(spec[1], false) else tex:SetTexture(spec[2]) end
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

function Voice:IsTransmitting()
    local channel = self:Channel()
    return channel ~= nil and channel.isTransmitting == true
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
            root:CreateRadio(m[2], function() return Voice.db.mode == m[1] end, function()
                Voice.db.mode = m[1]
                Voice:Apply(true)
            end)
        end
        root:CreateDivider()
        root:CreateCheckbox(L["Lock position"], function() return Voice.db.hudLock end, function() Voice.db.hudLock = not Voice.db.hudLock end)
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
            if Voice.db.mode ~= "all" then GameTooltip_AddNormalLine(tooltip, L["%d members audible"]:format(Voice:AudibleCount())) end
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
    local joined = self:IsJoined()
    local muted, silenced = self:IsMuted(), self:IsSilenced()
    setIcon(hud.icon, silenced and ICONS.silenced or muted and ICONS.muted or ICONS.on)
    hud.icon:SetDesaturated(not joined)
    hud.icon:SetAlpha(joined and 1 or 0.5)
    if joined and not muted and not silenced and self:IsTransmitting() then
        hud.icon:SetVertexColor(0.3, 1, 0.3)
    else
        hud.icon:SetVertexColor(1, 1, 1)
    end
    hud.deaf:SetShown(joined and self:IsDeafened())
    hud.count:SetText(joined and self.db.mode ~= "all" and tostring(self:AudibleCount()) or "")
    hud:Show()
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
