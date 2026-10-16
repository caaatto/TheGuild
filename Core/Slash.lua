local _, TG = ...
local L = TG.L

local commands = {}
local order = {}

function TG:RegisterSlash(cmd, fn, help)
    commands[cmd] = { fn = fn, help = help }
    order[#order + 1] = cmd
end

local function help()
    TG:Print("%s %s", TG.title, TG.version)
    TG:Print(L["Commands"] .. ":")
    for _, cmd in ipairs(order) do
        local c = commands[cmd]
        if c.help then DEFAULT_CHAT_FRAME:AddMessage(("  /tg %s %s- %s"):format(cmd, TG.gold, c.help)) end
    end
end

SLASH_THEGUILD1 = "/tg"
SLASH_THEGUILD2 = "/theguild"
SlashCmdList.THEGUILD = function(msg)
    local cmd, rest = tostring(msg or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" then
        TG.Window:Toggle()
        return
    end
    if cmd == "help" or cmd == "?" then
        help()
        return
    end
    local c = commands[cmd]
    if not c then
        TG:Print(L["Unknown command. Type /tg help."])
        return
    end
    TG.SafeCall(c.fn, rest)
end

TG:RegisterSlash("config", function() TG:OpenSettings() end, L["open the settings"])
TG:RegisterSlash("comms", function() TG.Comm:PrintStats() end, L["show communication statistics"])
TG:RegisterSlash("sync", function()
    TG.Store:RequestSync(true)
    TG.Comm:SendHello("ALERT")
    TG:Fire("SYNC_REQUESTED")
end, L["request a data sync"])
TG:RegisterSlash("version", function()
    TG:Print("%s %s (interface %d)", TG.title, TG.version, TG.interface)
    for key, p in pairs(TG.Comm:Peers()) do
        DEFAULT_CHAT_FRAME:AddMessage(("  %s: %s"):format(key, tostring(p.version)))
    end
end, L["Version"])

-- Key bindings

BINDING_HEADER_THEGUILD = "TheGuild"
BINDING_NAME_THEGUILD_TOGGLE = L["Toggle window"]
BINDING_NAME_THEGUILD_CTA = L["Call to Arms"]
BINDING_NAME_THEGUILD_SHARE = L["Toggle position sharing"]

function TheGuild_ToggleWindow()
    TG.Window:Toggle()
end

function TheGuild_CallToArms()
    local alerts = TG:GetModule("Alerts")
    if alerts and alerts.enabled then alerts:Prompt() end
end

function TheGuild_ToggleSharing()
    local map = TG:GetModule("Map")
    if map and map.enabled then map:ToggleSharing() end
end

-- Startup

TG:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= TG.name then return end
    TG:InitDB()
end)

TG:RegisterEvent("PLAYER_LOGIN", function()
    if not TG.db then TG:InitDB() end
    TG:InitModules()
    TG.Options:Build()
    TG.MinimapButton:Init()
    TG.Blizzard:Init()
    TG:Fire("READY")
end)
