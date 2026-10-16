local TG = TheGuild
local L = TG.L

local LOGIN_GRACE = 90
local POLITE_WINDOW = 30
local MILESTONES = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true }

local Social = TG:NewModule("Social", {
    title = L["Messages"],
    desc = L["Greet members who come online"],
    order = 40,
    defaults = {
        greet = false, welcome = true, levelup = false, cooldownHours = 12, polite = true, muteChat = true,
        greetings = { L["Hi %n!"], L["Hey %n, good to see you!"], L["Welcome back, %n!"] },
        welcomes = { L["Welcome to %g, %n!"], L["Hey %n, welcome!"], L["Welcome aboard, %n!"] },
        levelups = { L["Grats on %l, %n!"], L["%n hit %l, grats!"], L["Nice, level %l %n!"] },
        muted = {},
    },
    charDefaults = { greeted = {} },
    settings = {
        { key = "welcome", type = "boolean", name = L["Welcome new members"], default = true },
        { key = "greet", type = "boolean", name = L["Greet members who come online"], default = false },
        { key = "levelup", type = "boolean", name = L["Congratulate level ups"], default = false },
        { key = "cooldownHours", type = "number", name = L["Greeting cooldown (hours)"], default = 12, min = 1, max = 72, step = 1 },
        { key = "polite", type = "boolean", name = L["Only greet when nobody else did within 30 seconds"], default = true },
        { key = "muteChat", type = "boolean", name = L["Hide chat from muted players"], tooltip = L["Messages from muted players are hidden in guild, officer, party, raid, whisper and channel chat."], default = true },
    },
})

local loginAt = 0
local pending = {}
local seenInChat = {}

local FILTERED = {
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
}

local function fill(template, entry, level)
    local guild = TG.Roster:GuildName() or ""
    return (template:gsub("%%n", TG.ShortName(entry.key)):gsub("%%g", guild):gsub("%%l", tostring(level or entry.level or "")))
end

local function pick(list)
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

function Social:Say(text)
    if not text or text == "" or not TG.InGuild() then return end
    SendChatMessage(text:sub(1, 255), "GUILD")
end

function Social:Schedule(kind, entry, level)
    if TG.IsMe(entry.key) then return end
    local key = entry.key
    if pending[key] then return end
    pending[key] = true
    seenInChat[key] = nil
    TG.After(math.random(3, 9), function()
        pending[key] = nil
        if not self.enabled then return end
        local fresh = TG.Roster:Get(key)
        if not fresh or not fresh.online then return end
        if self.db.polite and seenInChat[key] and GetTime() - seenInChat[key] < POLITE_WINDOW then return end
        local list = kind == "welcome" and self.db.welcomes or (kind == "levelup" and self.db.levelups or self.db.greetings)
        local template = pick(list)
        if not template then return end
        self:Say(fill(template, fresh, level))
        if kind ~= "levelup" then self.cdb.greeted[key] = TG.Now() end
    end)
end

function Social:OnOnline(entry)
    if not self.db.greet or GetTime() - loginAt < LOGIN_GRACE then return end
    local last = self.cdb.greeted[entry.key]
    if last and TG.Now() - last < self.db.cooldownHours * 3600 then return end
    self:Schedule("greet", entry)
end

local joinBurst = {}

function Social:OnJoined(entry)
    if not self.db.welcome or GetTime() - loginAt < 15 then return end
    local now = GetTime()
    for i = #joinBurst, 1, -1 do
        if now - joinBurst[i] > 60 then table.remove(joinBurst, i) end
    end
    joinBurst[#joinBurst + 1] = now
    if #joinBurst > 3 then return end
    self:Schedule("welcome", entry)
end

function Social:OnLevel(entry, old)
    if not self.db.levelup or not MILESTONES[entry.level] then return end
    self:Schedule("levelup", entry, entry.level)
end

function Social:OnGuildChat(_, text, sender)
    if not TG.usable(text) or not TG.usable(sender) then return end
    if TG.IsMe(sender) then return end
    local lower = text:lower()
    for key in pairs(pending) do
        if lower:find(TG.ShortName(key):lower(), 1, true) then seenInChat[key] = GetTime() end
    end
end

function Social:IsMuted(name)
    local key = TG.StripRealm(name)
    return key ~= nil and self.db.muted[key] == true
end

function Social:ToggleMute(name)
    local key = TG.StripRealm(TG.Trim(name))
    if not key or key == "" then return end
    local entry = TG.Roster:Find(key)
    if entry then key = entry.key end
    if self.db.muted[key] then
        self.db.muted[key] = nil
        TG:Print(L["%s is no longer muted."], key)
    else
        self.db.muted[key] = true
        TG:Print(L["%s is now muted."], key)
    end
end

local function filter(_, _, text, sender)
    if not Social.enabled or not Social.db.muteChat then return false end
    if not TG.usable(sender) then return false end
    return Social:IsMuted(sender)
end

local function listCommand(self, list, label, rest)
    local action, text = rest:match("^(%S*)%s*(.-)$")
    action = action:lower()
    if action == "add" and text ~= "" then
        list[#list + 1] = text
    elseif action == "del" and tonumber(text) and list[tonumber(text)] then
        table.remove(list, tonumber(text))
    end
    TG:Print(label .. ":")
    for i, msg in ipairs(list) do DEFAULT_CHAT_FRAME:AddMessage(("  %d. %s"):format(i, msg)) end
end

function Social:OnInitialize()
    TG:RegisterSlash("mute", function(rest) self:ToggleMute(rest) end, L["mute or unmute a player"])
    TG:RegisterSlash("greet", function(rest) listCommand(self, self.db.greetings, L["Greetings"], rest) end,
        L["Greetings"] .. " (list, add <text>, del <n>)")
    TG:RegisterSlash("welcome", function(rest) listCommand(self, self.db.welcomes, L["Welcome messages"], rest) end,
        L["Welcome messages"] .. " (list, add <text>, del <n>)")
    TG:RegisterSlash("grats", function(rest) listCommand(self, self.db.levelups, L["Level up messages"], rest) end,
        L["Level up messages"] .. " (list, add <text>, del <n>)")
    for _, event in ipairs(FILTERED) do TG.AddChatFilter(event, filter) end
end

function Social:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, initial) if initial then loginAt = GetTime() end end)
    loginAt = GetTime()
    self:On("MEMBER_ONLINE", "OnOnline")
    self:On("MEMBER_JOINED", "OnJoined")
    self:On("MEMBER_LEVEL", "OnLevel")
    self:RegisterEvent("CHAT_MSG_GUILD", "OnGuildChat")
    self:On("MEMBER_MENU", function(root, entry)
        if TG.IsMe(entry.key) then return end
        root:CreateDivider()
        root:CreateButton(self:IsMuted(entry.key) and L["Unmute"] or L["Mute"], function() self:ToggleMute(entry.key) end)
    end)
end
