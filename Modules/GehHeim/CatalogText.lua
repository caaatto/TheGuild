local TG = TheGuild
local ns = TG.GH
if ns.off then return end

if GetLocale() == "deDE" then return end

local FACTIONS = {
    [21] = "Booty Bay", [59] = "Thorium Brotherhood", [68] = "Undercity", [76] = "Orgrimmar", [81] = "Thunder Bluff",
    [87] = "Bloodsail Buccaneers", [92] = "Gelkis Clan Centaur", [93] = "Magram Clan Centaur", [349] = "Ravenholdt",
    [369] = "Gadgetzan", [470] = "Ratchet", [510] = "The Defilers", [529] = "Argent Dawn", [530] = "Darkspear Trolls",
    [576] = "Timbermaw Hold", [577] = "Everlook", [609] = "Cenarion Circle", [629] = "Shatterspear", [630] = "Ravasaur Trainers",
    [729] = "Frostwolf Clan", [789] = "Moro'gai", [809] = "Shen'dralar", [889] = "Warsong Outriders", [909] = "Darkmoon Faire",
    [2587] = "Durotar Supply and Logistics", [2719] = "Cenarion Scouts", [2740] = "Kirin Tor", [2747] = "Barkskin Furbolg Den",
    [2758] = "Druids of the Nightclaw", [2765] = "Wardens of Hyjal", [2778] = "Windshapers", [2779] = "The High Order",
    [2782] = "Bolder'ok Clan", [2787] = "The Earthen Ring", [2798] = "Darkspear Raiders", [2819] = "The Keepers", [2827] = "Powderfuse",
}
local STANDINGS = { [5] = "Friendly", [6] = "Honored", [7] = "Revered", [8] = "Exalted" }

local TEXT = {
    boss_guild_5 = { "Guild Outing", "Killed a boss in a five-player group made up only of guild members." },
    boss_guild_raid = { "Guild Raid", "Killed a boss with at least 10 guild members in the raid." },
    boss_screenshot = { "Photo Evidence", "Took a screenshot within 5 minutes of a boss kill." },
    boss_tabard = { "Dress Code", "Killed a boss while wearing the guild tabard." },
    capitals_all = { "Discovered all six capitals", "" },
    death_1 = { "Spirit Healer Regular", "Died for the first time." },
    death_100 = { "Honorary Member of the Spirit World", "Died 100 times." },
    death_25 = { "Loyal Regular", "Died 25 times." },
    death_drown = { "Breathing Is Overrated", "Drowned." },
    death_enemy_capital = { "Banned from the Premises", "Died in a capital of the other faction." },
    death_fall = { "Gravity Wins", "Died from a fall." },
    death_fatigue = { "Tired to Death", "Died of fatigue." },
    death_hogger = { "Hogger's Victim", "Killed by Hogger." },
    death_lava = { "Hot Feet", "Died in lava." },
    death_lowlevel = { "Beginner's Bad Luck", "Died at level 1 to 3." },
    death_oneshot = { "One Puff", "Died from a single hit." },
    fight_long = { "Tough Business", "Won a fight that lasted at least 5 minutes." },
    fish_100 = { "Catch of the Day I", "100 catches while fishing." },
    fish_2500 = { "Catch of the Day III", "2500 catches while fishing." },
    fish_500 = { "Catch of the Day II", "500 catches while fishing." },
    fish_junk = { "Fisherman's Tale", "Pulled a weapon or a piece of armor out of the water." },
    fish_rare = { "Tight Lines", "Found a rare or epic item while fishing." },
    gold_100 = { "100 Gold", "" },
    gold_1000 = { "Golden Dragon", "Owned at least 1000 gold at once." },
    gold_500 = { "500 Gold", "Owned at least 500 gold at once." },
    hearth_1 = { "Geh Heim!", "Used the hearthstone for the first time." },
    hearth_100 = { "Daily Commuter", "Used the hearthstone 100 times." },
    hearth_after_wipe = { "Geh Heim after the Wipe", "Used the hearthstone within 5 minutes of a death or wipe." },
    hogger = { "Hogger Down", "Defeated Hogger." },
    level_10 = { "Level 10", "" },
    level_20 = { "Level 20", "" },
    level_30 = { "Level 30", "" },
    level_40 = { "Level 40", "" },
    level_50 = { "Level 50", "" },
    level_60 = { "Level 60", "" },
    mount_first = { "Finally Mounted", "Learned the first mount." },
    naked_10 = { "Streaker", "Reached level 10 without wearing any armor." },
    pets_10 = { "Animal Friend", "10 new pets since the addon was installed." },
    quests_100 = { "Quest Marathon I", "Turned in 100 quests." },
    quests_1000 = { "Quest Marathon IV", "Turned in 1000 quests." },
    quests_250 = { "Quest Marathon II", "Turned in 250 quests." },
    quests_500 = { "Quest Marathon III", "Turned in 500 quests." },
    rare_1 = { "Rare Hunter", "Defeated the first rare enemy." },
    rare_10 = { "Big Game Hunter", "Defeated 10 different rare enemies." },
    rep_87_5 = { "Signing On", "Reputation with the Bloodsail Buccaneers at Friendly. Costs reputation with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_87_7 = { "Bosun of the Bloodsail", "Reputation with the Bloodsail Buccaneers at Revered. Costs reputation with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_87_8 = { "Admiral of the Bloodsail", "Reputation with the Bloodsail Buccaneers at Exalted. Costs reputation with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_capitals_horde = { "Ambassador of the Horde", "Exalted with Orgrimmar, Thunder Bluff, Undercity and the Darkspear Trolls." },
    rep_cartel = { "Friend of the Cartel", "Exalted with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_exalted_10 = { "Diplomat", "Exalted with 10 different factions." },
    rep_exalted_20 = { "World Diplomat", "Exalted with 20 different factions." },
    toys_10 = { "Big Kid", "10 new toys since the addon was installed." },
    walk_100k = { "Ultra Runner", "Walked 100 km on foot." },
    walk_45k = { "Marathon Runner", "Walked 45 km on foot." },
    walk_500k = { "Pilgrim", "Walked 500 km on foot." },
    wipe_1 = { "Total Failure", "Wiped on a boss for the first time." },
    wipe_10 = { "Trial and Error", "Wiped on a boss 10 times." },
    wipe_25 = { "Undeterred", "Wiped on a boss 25 times." },
}

local SEALED = "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"
for code, t in pairs(ns.Unseal(SEALED, "text") or {}) do TEXT[code] = t end

local function factionName(id)
    local fn = C_Reputation and C_Reputation.GetFactionDataByID
    local ok, d = pcall(fn or error, id)
    local name = ok and type(d) == "table" and TG.plain(d.name, nil)
    if type(name) == "string" and name ~= "" then return name end
    return FACTIONS[id] or ("Faction " .. id)
end

local function standingName(n)
    local label = _G["FACTION_STANDING_LABEL" .. n]
    if type(label) == "string" then return label end
    return STANDINGS[n] or tostring(n)
end

for _, e in ipairs(ns.Catalog.entries) do
    local t = TEXT[e.code]
    if t then
        e.title, e.description = t[1], t[2]
    else
        local faction, standing = e.code:match("^rep_(%d+)_(%d+)$")
        if faction then
            local name, label = factionName(tonumber(faction)), standingName(tonumber(standing))
            e.title = name .. ": " .. label
            e.description = ("Reputation with %s at %s."):format(name, label)
        else
            local skill, rank = e.code:match("^skill_(%d+)_(%d+)$")
            local prof = skill and ns.PROFESSIONS[tonumber(skill)]
            if prof then e.title, e.description = prof .. " " .. rank, "" end
        end
    end
end
