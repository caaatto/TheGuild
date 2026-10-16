local TG = TheGuild
local L = TG.L
local Loot = TG:GetModule("Loot")

-- Rare or better items a member loots are announced to the guild with
-- their bind type and end up in the event log.

local Finds = {}
Loot.Finds = Finds

local BIND_ON_PICKUP = 1
local BIND_ON_EQUIP = 2
local RETRIES = 3

local QUALITY_BY_COLOR = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5,
}

local patterns = {}

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

local function qualityOf(link)
    local id = tonumber(link:match("item:(%d+)"))
    local quality = id and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if TG.usable(quality) and quality then return quality end
    local color = link:match("|cff(%x%x%x%x%x%x)")
    return color and QUALITY_BY_COLOR[color:lower()] or 0
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
    local bind = self.BindText(data.bind)
    if bind then text = text .. " (" .. bind .. ")" end
    if data.zone and data.zone ~= "" then text = text .. GRAY_FONT_COLOR:WrapTextInColorCode(" " .. data.zone) end
    return text
end

function Finds:Record(name, data)
    TG.Log:Add("found", name, { link = data.link, quality = data.quality, bind = data.bind, zone = data.zone })
    if Loot.db.findChat and not TG.IsMe(name) then
        TG:Print(self:Describe(name, data))
    end
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
    quality = TG.usable(quality) and quality or qualityOf(link)
    if quality < Loot.db.findQuality then return end
    if Loot.db.findBopOnly and bindType ~= BIND_ON_PICKUP then return end
    local data = { link = link, quality = quality, bind = bindType, zone = TG.plain(GetZoneText(), "") }
    Finds:Record(TG.MyName(), data)
    if Loot.db.findShare and TG.InGuild() then
        TG.Comm:Send("LF", { i = link, q = quality, b = bindType, z = data.zone }, "NORMAL")
    end
end

function Finds:OnChatLoot(_, msg)
    if not TG.usable(msg) or type(msg) ~= "string" then return end
    local link = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not link then return end
    local mine = false
    for _, p in ipairs(patterns) do
        if msg:match(p) then mine = true break end
    end
    if not mine then return end
    if qualityOf(link) < Loot.db.findQuality then return end
    send(link, 1)
end

function Finds:OnFind(sender, data)
    if type(data) ~= "table" or type(data.i) ~= "string" or not data.i:find("|Hitem:") then return end
    local quality = tonumber(data.q) or qualityOf(data.i)
    if quality < Loot.db.findQuality then return end
    self:Record(sender, { link = data.i, quality = quality, bind = tonumber(data.b) or 0, zone = TG.usable(data.z) and data.z or "" })
end

function Finds:Enable(owner)
    TG:RegisterEvent("CHAT_MSG_LOOT", function(...) Finds:OnChatLoot(...) end, owner)
    TG.Comm:Register("LF", function(sender, data) Finds:OnFind(sender, data) end, owner)
end
