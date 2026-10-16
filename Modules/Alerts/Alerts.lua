local TG = TheGuild
local L = TG.L

local COOLDOWN = 900

local Alerts = TG:NewModule("Alerts", {
    title = L["Call to Arms"],
    desc = L["Everyone in the guild with TheGuild gets a warning, a sound and your location."],
    order = 30,
    defaults = { sound = true, raidWarning = true, popup = true, autoWaypoint = false, chat = true },
    charDefaults = { lastCTA = 0 },
    settings = {
        { key = "raidWarning", type = "boolean", name = L["Show a raid warning"], default = true },
        { key = "sound", type = "boolean", name = L["Play a sound"], default = true },
        { key = "popup", type = "boolean", name = L["Show a popup with a waypoint button"], default = true },
        { key = "autoWaypoint", type = "boolean", name = L["Automatically set a waypoint"], default = false },
        { key = "chat", type = "boolean", name = L["Also post the call in guild chat"], default = true },
    },
})

StaticPopupDialogs["THEGUILD_CTA"] = {
    text = "%s",
    button1 = L["Set waypoint"],
    button2 = CLOSE,
    OnAccept = function(_, data)
        TG.SetWaypoint(data.m, data.x, data.y)
    end,
    timeout = 60,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

function Alerts:Remaining()
    local left = COOLDOWN - (TG.Now() - (self.cdb.lastCTA or 0))
    return left > 0 and left or 0
end

function Alerts:Prompt()
    if not TG.InGuild() then
        TG:Print(L["You need to be in a guild."])
        return
    end
    local left = self:Remaining()
    if left > 0 then
        TG:Print(L["Call to Arms is on cooldown (%s left)."], TG.FormatDuration(left))
        return
    end
    StaticPopup_ShowCustomGenericInputBox({
        text = L["Send a call to arms"] .. "\n\n" .. L["Everyone in the guild with TheGuild gets a warning, a sound and your location."] .. "\n" .. L["Optional message"] .. ":",
        acceptText = L["Send"],
        cancelText = CANCEL,
        maxLetters = 100,
        callback = function(text) Alerts:Send(text) end,
    })
end

function Alerts:Send(text)
    if self:Remaining() > 0 then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not TG.usable(mapID) then return end
    local x, y = 0, 0
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if pos then
        local px, py = pos:GetXY()
        if TG.usable(px) and TG.usable(py) then x, y = px, py end
    end
    local zone = TG.plain(GetZoneText(), "")
    local sub = TG.plain(GetSubZoneText(), "")
    if sub ~= "" and sub ~= zone then zone = zone .. ", " .. sub end
    text = TG.Trim(text or ""):sub(1, 100)
    self.cdb.lastCTA = TG.Now()
    TG.Comm:Send("CTA", { m = mapID, x = TG.Round(x, 4), y = TG.Round(y, 4), z = zone, t = text }, "ALERT")
    if self.db.chat then
        local coords = x > 0 and (" (%.0f, %.0f)"):format(x * 100, y * 100) or ""
        local msg = L["Call to Arms"] .. ": " .. zone .. coords
        if text ~= "" then msg = msg .. " - " .. text end
        SendChatMessage(msg:sub(1, 255), "GUILD")
    end
    TG:Fire("ACTIVITY", "cta", TG.MyName(), { z = zone, t = text })
end

function Alerts:OnCTA(sender, data)
    if type(data) ~= "table" or not data.m then return end
    local entry = TG.Roster:Get(sender)
    local name = entry and TG.ClassText(entry.classFile, sender) or sender
    local zone = TG.usable(data.z) and data.z ~= "" and data.z or TG.MapName(data.m)
    local text = L["%s calls to arms in %s"]:format(name, zone)
    if TG.usable(data.t) and data.t ~= "" then text = text .. ": " .. data.t end
    TG:Print(text)
    if self.db.raidWarning then TG.RaidWarning(text) end
    if self.db.sound then PlaySound(SOUNDKIT.RAID_WARNING) end
    local hasPos = tonumber(data.x) and tonumber(data.x) > 0
    if hasPos and self.db.autoWaypoint then
        TG.SetWaypoint(data.m, data.x, data.y)
    elseif hasPos and self.db.popup then
        StaticPopup_Show("THEGUILD_CTA", text, nil, data)
    end
    TG:Fire("ACTIVITY", "cta", sender, data)
end

function Alerts:OnInitialize()
    TG:RegisterSlash("cta", function(rest)
        if not self.enabled then return end
        rest = TG.Trim(rest)
        if rest ~= "" then self:Send(rest) else self:Prompt() end
    end, L["send a call to arms"])
end

function Alerts:OnEnable()
    self:RegisterComm("CTA", "OnCTA")
end
