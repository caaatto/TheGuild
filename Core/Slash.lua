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

local TIPS = {
    L["Right click a member anywhere in the window for whisper, invite, roles and alt links."],
    L["Ctrl + right click on the world map places a shared guild pin."],
    L["Officers edit public notes, raid teams, loot history and the candidate list. Everyone else sees them."],
    L["Every module is its own addon in the AddOn list and can be disabled there or in the settings."],
    L["Shared data lives only on the clients of guild members with the addon. Nothing is written into the guild itself."],
    L["Ctrl + Tab switches tabs, Ctrl + F jumps to the search field. Both pause in combat."],
}

function TG:HelpText()
    local lines = { ("%s %s"):format(TG.title, TG.version), "" }
    lines[#lines + 1] = L["Commands"]
    for _, cmd in ipairs(order) do
        local c = commands[cmd]
        if c.help then lines[#lines + 1] = ("  /tg %s   %s"):format(cmd, c.help) end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Modules"]
    for _, mod in ipairs(TG.moduleOrder or {}) do
        local state = mod.enabled and L["Enabled"] or L["Disabled"]
        lines[#lines + 1] = ("  %s (%s)   %s"):format(mod.title or mod.name, state, mod.desc or "")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Key bindings"]
    lines[#lines + 1] = "  " .. L["Toggle window"]
    lines[#lines + 1] = "  " .. L["Call to Arms"]
    lines[#lines + 1] = "  " .. L["Toggle position sharing"]
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Tips"]
    for _, tip in ipairs(TIPS) do lines[#lines + 1] = "  " .. tip end
    return table.concat(lines, "\n")
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
TG:RegisterSlash("comms", function(rest)
    if tostring(rest or ""):match("^%S*"):lower() == "debug" then
        TG.Comm.debug = not TG.Comm.debug
        TG:Print("comm debug %s", TG.Comm.debug and "on" or "off")
        return
    end
    TG.Comm:PrintStats()
end, L["show communication statistics, debug logs every message"])
local function addonMemory()
    local out, total = {}, 0
    if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage and C_AddOns.GetNumAddOns) then return out, total end
    UpdateAddOnMemoryUsage()
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if type(name) == "string" and (name == TG.name or name:sub(1, #TG.name + 1) == TG.name .. "_") and C_AddOns.IsAddOnLoaded(name) then
            local kb = GetAddOnMemoryUsage(i) or 0
            out[#out + 1] = { name = name, kb = kb }
            total = total + kb
        end
    end
    table.sort(out, function(a, b) return a.kb > b.kb end)
    return out, total
end

local function sizeText(kb)
    if kb >= 1024 then return ("%.1f MB"):format(kb / 1024) end
    return ("%d KB"):format(kb)
end

function TG:MemoryReport()
    local lines = {}
    local addons, total = addonMemory()
    for _, a in ipairs(addons) do lines[#lines + 1] = ("  %s: %s"):format(a.name, sizeText(a.kb)) end
    if #addons > 0 then lines[#lines + 1] = L["Total %s, Lua %s"]:format(sizeText(total), sizeText(collectgarbage("count"))) end
    local counts, items, namespaces = {}, 0, 0
    local g = TG:GuildDB()
    for ns, list in pairs(g and g.store or {}) do
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        if n > 0 then
            namespaces = namespaces + 1
            items = items + n
            counts[#counts + 1] = ("%s %d"):format(ns, n)
        end
    end
    table.sort(counts)
    lines[#lines + 1] = L["Store: %d items in %d namespaces"]:format(items, namespaces)
    if #counts > 0 then lines[#lines + 1] = "  " .. table.concat(counts, ", ") end
    local guilds = 0
    for _ in pairs(TG.db.guilds) do guilds = guilds + 1 end
    lines[#lines + 1] = L["Log: %d entries, %d guilds in the database"]:format(#TG.Log:Entries(), guilds)
    return lines
end

TG:RegisterSlash("memory", function()
    TG:Print(L["Memory"])
    for _, line in ipairs(TG:MemoryReport()) do DEFAULT_CHAT_FRAME:AddMessage(line) end
end, L["memory and data usage"])
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

BINDING_HEADER_THEGUILD = "TheGuild"
BINDING_NAME_THEGUILD_TOGGLE = L["Toggle window"]
BINDING_NAME_THEGUILD_CTA = L["Call to Arms"]
BINDING_NAME_THEGUILD_SHARE = L["Toggle position sharing"]
BINDING_NAME_THEGUILD_VOICE_MUTE = L["Mute or unmute the microphone"]

TG.BINDINGS = { "THEGUILD_TOGGLE", "THEGUILD_CTA", "THEGUILD_SHARE", "THEGUILD_VOICE_MUTE" }

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

function TheGuild_ToggleMute()
    local voice = TG:GetModule("Voice")
    if voice and voice.enabled and voice.ToggleMute then
        voice:ToggleMute()
    else
        TG:Print(L["The Voice module is disabled."])
    end
end

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
    TG.After(90, function() TG:ForgetStaleGuilds() end)
end)
