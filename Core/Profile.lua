local _, TG = ...
local L = TG.L
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

-- Settings travel as text so a guild can hand one setup to every member.
-- Guild data (store, log) stays out on purpose.

local Profile = {}
TG.Profile = Profile

local PREFIX = "TG1:"

function Profile:Export()
    local data = {
        v = 1,
        modules = TG.CopyTable(TG.db.modules),
        global = { minimap = TG.db.global.minimap.hide == true, debug = TG.db.global.debug == true },
    }
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    return PREFIX .. LibDeflate:EncodeForPrint(compressed)
end

function Profile:Decode(text)
    text = TG.Trim(text or "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, L["This is not a TheGuild profile."] end
    local compressed = LibDeflate:DecodeForPrint(text:sub(#PREFIX + 1))
    local serialized = compressed and LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil, L["The profile text is damaged."] end
    local ok, data = LibSerialize:Deserialize(serialized)
    if not ok or type(data) ~= "table" or type(data.modules) ~= "table" then return nil, L["The profile text is damaged."] end
    return data
end

function Profile:Import(text)
    local data, err = self:Decode(text)
    if not data then return false, err end
    local count = 0
    for name, values in pairs(data.modules) do
        local mod = TG:GetModule(name)
        if mod and type(values) == "table" then
            for k, v in pairs(values) do
                mod.db[k] = type(v) == "table" and TG.CopyTable(v) or v
            end
            if values.enabledOverride == true then TG:EnableModule(mod, true) end
            if values.enabledOverride == false then TG:DisableModule(mod, true) end
            count = count + 1
        end
    end
    if type(data.global) == "table" then
        if data.global.minimap ~= nil then
            TG.db.global.minimap.hide = data.global.minimap == true
            if TG.MinimapButton then TG.MinimapButton:Refresh() end
        end
        if data.global.debug ~= nil then TG.db.global.debug = data.global.debug == true end
    end
    TG:Fire("PROFILE_IMPORTED")
    return true, count
end

function Profile:OpenExport()
    TG.UI.TextDialog(L["Export profile"], self:Export(), nil, L["Copy the text and send it to a guild member. It contains settings only, no guild data."])
end

function Profile:OpenImport()
    TG.UI.TextDialog(L["Import profile"], "", function(text)
        local ok, result = self:Import(text)
        if ok then
            TG:Print(L["Profile imported, %d modules updated. Some changes need a /reload."], result)
        else
            TG:Print(result)
        end
    end, L["Paste a profile text. Your module settings are replaced."])
end

TG:RegisterSlash("export", function() Profile:OpenExport() end, L["export settings as text"])
TG:RegisterSlash("import", function() Profile:OpenImport() end, L["import settings from text"])
