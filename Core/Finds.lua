local _, TG = ...
local L = TG.L

local Finds = {}
TG.Finds = Finds

local BIND_ON_PICKUP = 1
local BIND_ON_EQUIP = 2
local RETRIES = 3
local FIND_COOLDOWN = 10

local patterns = {}
local lastFind = {}

local function toPattern(global)
    if type(global) ~= "string" then return nil end
    local p = global:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "%%d+")
    return "^" .. p .. "$"
end

for _, name in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }) do
    local p = toPattern(_G[name])
    if p then patterns[#patterns + 1] = p end
end

local function cfg()
    return TG.db.global.finds
end

local function chatQuality()
    local chat = cfg().chat
    if chat == true then return 4 end
    return tonumber(chat) or 0
end

local function qualityOf(link)
    return TG.LinkQuality(link, 0)
end

function Finds.BindText(bind)
    if bind == BIND_ON_PICKUP then return L["BoP"] end
    if bind == BIND_ON_EQUIP then return L["BoE"] end
    return nil
end

function Finds:Describe(name, data)
    local entry = TG.Roster:Get(name)
    local who = entry and TG.ClassText(entry.classFile, name) or name
    local text = L["%s found %s"]:format(who, data.link or "?")
    local info = {}
    local bind = self.BindText(data.bind)
    if bind then info[#info + 1] = bind end
    local _, _, _, _, reqLevel, _, subType, _, equipLoc = C_Item.GetItemInfo(data.link or "")
    if type(subType) == "string" and subType ~= "" then info[#info + 1] = subType end
    local slot = type(equipLoc) == "string" and equipLoc ~= "" and _G[equipLoc]
    if type(slot) == "string" and slot ~= "" then info[#info + 1] = slot end
    reqLevel = TG.usable(reqLevel) and tonumber(reqLevel) or 0
    if reqLevel > 1 then info[#info + 1] = L["from level %d"]:format(reqLevel) end
    if #info > 0 then text = text .. " (" .. table.concat(info, ", ") .. ")" end
    local where = data.zone or ""
    if data.sub and data.sub ~= "" and data.sub ~= where then
        where = where ~= "" and (where .. ", " .. data.sub) or data.sub
    end
    if where ~= "" then text = text .. GRAY_FONT_COLOR:WrapTextInColorCode(" " .. where) end
    return text
end

local function announce(name, data, attempt)
    if not C_Item.GetItemInfo(data.link) and attempt < RETRIES then
        local id = tonumber(data.link:match("item:(%d+)"))
        if id and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        TG.After(1, function() announce(name, data, attempt + 1) end)
        return
    end
    TG:Print(Finds:Describe(name, data))
end

function Finds:Record(name, data)
    TG.Log:Add("found", name, { link = data.link, quality = data.quality, bind = data.bind, zone = data.zone })
    local chat = chatQuality()
    if chat > 0 and (data.quality or 0) >= chat and not TG.IsMe(name) then announce(name, data, 1) end
end

local function send(link, attempt)
    local _, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(link)
    if not TG.usable(bindType) or bindType == nil then
        if attempt < RETRIES then
            local id = tonumber(link:match("item:(%d+)"))
            if id and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            TG.After(1, function() send(link, attempt + 1) end)
            return
        end
        bindType = 0
    end
    local c = cfg()
    quality = TG.usable(quality) and quality or qualityOf(link)
    if quality < c.quality then return end
    if c.bopOnly and bindType ~= BIND_ON_PICKUP then return end
    local data = { link = link, quality = quality, bind = bindType, zone = TG.plain(GetZoneText(), ""), sub = TG.plain(GetSubZoneText(), "") }
    Finds:Record(TG.MyName(), data)
    if c.share and TG.InGuild() then
        TG.Comm:Send("LF", { i = link, q = quality, b = bindType, z = data.zone, s = data.sub }, "NORMAL")
    end
end

function Finds:OnChatLoot(_, msg)
    if not TG.usable(msg) or type(msg) ~= "string" then return end
    local link = TG.ItemLink(msg)
    if not link then return end
    local mine = false
    for _, p in ipairs(patterns) do
        if msg:match(p) then mine = true break end
    end
    if not mine then return end
    if qualityOf(link) < cfg().quality then return end
    send(link, 1)
end

local function place(v)
    if not TG.usable(v) or type(v) ~= "string" or v:find("|", 1, true) then return "" end
    return TG.CleanText(v, 60)
end

function Finds:OnFind(sender, data)
    if type(data) ~= "table" or type(data.i) ~= "string" then return end
    local link = TG.ItemLink(data.i)
    if not link then return end
    if lastFind[sender] and GetTime() - lastFind[sender] < FIND_COOLDOWN then return end
    lastFind[sender] = GetTime()
    local quality = tonumber(data.q) or qualityOf(link)
    if quality < cfg().quality then return end
    self:Record(sender, { link = link, quality = quality, bind = tonumber(data.b) or 0,
        zone = place(data.z), sub = place(data.s) })
end

TG:RegisterEvent("CHAT_MSG_LOOT", function(...) Finds:OnChatLoot(...) end, Finds)
TG.Comm:Register("LF", function(sender, data) Finds:OnFind(sender, data) end, Finds)

TG:On("READY", function()
    local c = cfg()
    if c.chat == true then c.chat = 4 elseif c.chat == false then c.chat = 0 end
    local old = TG.db.modules.Loot
    if not old then return end
    if old.findShare ~= nil then c.share = old.findShare end
    if old.findChat ~= nil then c.chat = old.findChat and 4 or 0 end
    if old.findQuality ~= nil then c.quality = old.findQuality end
    if old.findBopOnly ~= nil then c.bopOnly = old.findBopOnly end
    old.findShare, old.findChat, old.findQuality, old.findBopOnly = nil, nil, nil, nil
end)
