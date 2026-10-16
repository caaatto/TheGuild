local _, TG = ...

local DB_VERSION = 1

local defaults = {
    version = DB_VERSION,
    global = {
        debug = false,
        minimap = { hide = false },
        window = { point = "CENTER", x = 0, y = 0, tab = 1 },
    },
    modules = {},
    guilds = {},
}

local charDefaults = {
    version = DB_VERSION,
    modules = {},
    lastGuild = nil,
}

function TG:InitDB()
    TheGuildDB = TG.Merge(TheGuildDB, defaults)
    TheGuildCharDB = TG.Merge(TheGuildCharDB, charDefaults)
    TG.db = TheGuildDB
    TG.cdb = TheGuildCharDB
end

function TG:GuildKey()
    local name = GetGuildInfo("player")
    if not TG.usable(name) or name == "" then return nil end
    local faction = UnitFactionGroup("player")
    return name .. "@" .. tostring(TG.plain(faction, "?"))
end

function TG:GuildDB()
    local key = TG:GuildKey() or TG.cdb.lastGuild
    if not key then return nil end
    TG.cdb.lastGuild = key
    local g = TG.db.guilds[key]
    if not g then
        g = { store = {}, created = TG.Now() }
        TG.db.guilds[key] = g
    end
    g.seen = TG.Now()
    return g
end

function TG:ModuleDB(name, moduleDefaults)
    TG.db.modules[name] = TG.Merge(TG.db.modules[name], moduleDefaults or {})
    return TG.db.modules[name]
end

function TG:ModuleCharDB(name, moduleDefaults)
    TG.cdb.modules[name] = TG.Merge(TG.cdb.modules[name], moduleDefaults or {})
    return TG.cdb.modules[name]
end
