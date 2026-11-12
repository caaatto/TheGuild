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
    boss_guild_5 = { "Guild Outing", "Killed a boss with at least four other guild members in the group." },
    boss_guild_5_x10 = { "Guild Outing III", "Killed 10 bosses with at least four other guild members in the group." },
    boss_guild_5_x100 = { "Guild Outing VI", "Killed 100 bosses with at least four other guild members in the group." },
    boss_guild_5_x25 = { "Guild Outing IV", "Killed 25 bosses with at least four other guild members in the group." },
    boss_guild_5_x5 = { "Guild Outing II", "Killed 5 bosses with at least four other guild members in the group." },
    boss_guild_5_x50 = { "Guild Outing V", "Killed 50 bosses with at least four other guild members in the group." },
    boss_guild_5_x500 = { "Guild Outing VII", "Killed 500 bosses with at least four other guild members in the group." },
    boss_guild_raid = { "Guild Raid", "Killed a boss with at least 10 guild members in the raid." },
    boss_screenshot = { "Photo Evidence", "Took a screenshot within 5 minutes of a boss kill." },
    boss_tabard = { "Dress Code", "Killed a boss while wearing the guild tabard." },
    buff_world_1 = { "World Buff Hunter", "Received a world buff for the first time (Dragonslayer, Warchief's Blessing, Songflower, Dire Maul tribute, Sayge's fortune or Spirit of Zandalar)." },
    buff_world_all = { "World Buff Collector", "Received every currently available world buff once: Rallying Cry of the Dragonslayer, Warchief's Blessing, Songflower Serenade, Fengus' Ferocity, Mol'dar's Moxie, Slip'kik's Savvy and a fortune from Sayge." },
    camp_fire = { "Campfire Romance", "Warmed up at a campfire for the first time." },
    capitals_all = { "Discovered all six capitals", "" },
    craft_100 = { "Craftsman I", "Crafted 100 items." },
    craft_2500 = { "Craftsman III", "Crafted 2500 items." },
    craft_500 = { "Craftsman II", "Crafted 500 items." },
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
    dng_alcaz = { "Alcaz Prison: Blazeroar", "Defeated Blazeroar in Alcaz Prison (Forever dungeon)." },
    dng_all = { "Dungeon Master", "Defeated the final boss of every dungeon, including the new Forever dungeons." },
    dng_bfd_akumai = { "Blackfathom Deeps: Aku'mai", "" },
    dng_blackmaw = { "Blackmaw Hold: Unbound Spirit", "Defeated the Unbound Spirit in Blackmaw Hold (Forever dungeon)." },
    dng_brd_thaurissan = { "Blackrock Depths: Emperor Dagran Thaurissan", "" },
    dng_clean_1 = { "Clean Run", "Finished a dungeon with at least three bosses and at least three other guild members, without a wipe and without dying yourself." },
    dng_clean_10 = { "Clean Run III", "Finished ten different dungeons cleanly (as in Clean Run)." },
    dng_clean_5 = { "Clean Run II", "Finished five different dungeons cleanly (as in Clean Run)." },
    dng_dalaran = { "Dalaran: Shade of the Archmage", "Defeated the Shade of the Archmage in Dalaran (Forever dungeon)." },
    dng_dm_east_alzzin = { "Dire Maul East: Alzzin the Wildshaper", "" },
    dng_dm_north_gordok = { "Dire Maul North: King Gordok", "" },
    dng_dm_vancleef = { "The Deadmines: Edwin VanCleef", "" },
    dng_dm_west_tortheldrin = { "Dire Maul West: Prince Tortheldrin", "" },
    dng_drowned_city = { "The Drowned City: Min'loth the Serpent", "Defeated Min'loth the Serpent in the Drowned City (Forever dungeon)." },
    dng_excavation_wetlands = { "Wetlands Excavation Site: Relic Guardian", "Defeated the Relic Guardian in the excavation site in the Wetlands (Forever dungeon)." },
    dng_gnomer_thermaplugg = { "Gnomeregan: Mekgineer Thermaplugg", "" },
    dng_hall_thanes = { "The Hall of Thanes: Durgen Dirgehammer", "Defeated Durgen Dirgehammer in the Hall of Thanes (Forever dungeon)." },
    dng_kroldok = { "Krol'dok Stronghold: Overseer Mugg", "Defeated Overseer Mugg in Krol'dok Stronghold (Forever dungeon)." },
    dng_lbrs_wyrmthalak = { "Lower Blackrock Spire: Overlord Wyrmthalak", "" },
    dng_mara_theradras = { "Maraudon: Princess Theradras", "" },
    dng_rfc_bazzalan = { "Ragefire Chasm: Bazzalan", "" },
    dng_rfd_amnennar = { "Razorfen Downs: Amnennar the Coldbringer", "" },
    dng_rfk_charlga = { "Razorfen Kraul: Charlga Razorflank", "" },
    dng_ruins_lordaeron = { "Ruins of Lordaeron: Rath'mael", "Defeated Rath'mael in the Ruins of Lordaeron (Forever dungeon)." },
    dng_scholo_gandling = { "Scholomance: Darkmaster Gandling", "" },
    dng_sfk_arugal = { "Shadowfang Keep: Archmage Arugal", "" },
    dng_shapers_terrace = { "The Shaper's Terrace: Nanaya", "Defeated Nanaya on the Shaper's Terrace (Forever dungeon)." },
    dng_sm_armory_herod = { "Scarlet Monastery, Armory: Herod", "" },
    dng_sm_cathedral_whitemane = { "Scarlet Monastery, Cathedral: High Inquisitor Whitemane", "" },
    dng_sm_graveyard_thalnos = { "Scarlet Monastery, Graveyard: Bloodmage Thalnos", "" },
    dng_sm_library_doan = { "Scarlet Monastery, Library: Arcanist Doan", "" },
    dng_st_eranikus = { "Sunken Temple: Shade of Eranikus", "" },
    dng_stockade_thredd = { "The Stockade: Bazil Thredd", "" },
    dng_strat_balnazzar = { "Stratholme (living side): Balnazzar", "" },
    dng_strat_rivendare = { "Stratholme (undead side): Baron Rivendare", "" },
    dng_ubrs_drakkisath = { "Upper Blackrock Spire: General Drakkisath", "" },
    dng_uldaman_archaedas = { "Uldaman: Archaedas", "" },
    dng_wc_mutanus = { "Wailing Caverns: Mutanus the Devourer", "" },
    dng_zf_ukorz = { "Zul'Farrak: Chief Ukorz Sandscalp", "" },
    fight_long = { "Tough Business", "Won a fight that lasted at least 5 minutes." },
    fish_100 = { "Catch of the Day I", "100 catches while fishing." },
    fish_2500 = { "Catch of the Day III", "2500 catches while fishing." },
    fish_500 = { "Catch of the Day II", "500 catches while fishing." },
    fish_junk = { "Fisherman's Tale", "Pulled a weapon or a piece of armor out of the water." },
    fish_rare = { "Tight Lines", "Caught 25 different things while fishing." },
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
    mount_1 = { "Stable Master I", "Learned the first mount." },
    mount_10 = { "Stable Master IV", "Learned 10 different mounts." },
    mount_3 = { "Stable Master II", "Learned 3 different mounts." },
    mount_first = { "Finally Mounted", "Learned riding (skill 75)." },
    mount_riding_150 = { "Seasoned Rider", "Learned riding at 150 (fast mounts)." },
    naked_10 = { "Streaker", "Reached level 10 without wearing any armor." },
    pets_10 = { "Animal Friend", "10 new pets since the addon was installed." },
    quests_100 = { "Quest Marathon I", "Turned in 100 quests." },
    quests_1000 = { "Quest Marathon IV", "Turned in 1000 quests." },
    quests_250 = { "Quest Marathon II", "Turned in 250 quests." },
    quests_500 = { "Quest Marathon III", "Turned in 500 quests." },
    raid_onyxia = { "Onyxia's Lair: Onyxia", "Defeated Onyxia in her lair." },
    rare_1 = { "Rare Hunter", "Defeated the first rare enemy." },
    rare_10 = { "Big Game Hunter", "Defeated 10 different rare enemies." },
    recipe_129_10 = { "First Aid: Recipe Book II", "Made 10 different bandages yourself." },
    recipe_129_5 = { "First Aid: Recipe Book I", "Made 5 different bandages yourself." },
    recipe_164_10 = { "Blacksmithing: Recipe Book I", "Made 10 different Blacksmithing recipes yourself." },
    recipe_164_25 = { "Blacksmithing: Recipe Book II", "Made 25 different Blacksmithing recipes yourself." },
    recipe_164_50 = { "Blacksmithing: Recipe Book III", "Made 50 different Blacksmithing recipes yourself." },
    recipe_165_10 = { "Leatherworking: Recipe Book I", "Made 10 different Leatherworking recipes yourself." },
    recipe_165_25 = { "Leatherworking: Recipe Book II", "Made 25 different Leatherworking recipes yourself." },
    recipe_165_50 = { "Leatherworking: Recipe Book III", "Made 50 different Leatherworking recipes yourself." },
    recipe_171_10 = { "Alchemy: Recipe Book I", "Made 10 different Alchemy recipes yourself." },
    recipe_171_25 = { "Alchemy: Recipe Book II", "Made 25 different Alchemy recipes yourself." },
    recipe_171_50 = { "Alchemy: Recipe Book III", "Made 50 different Alchemy recipes yourself." },
    recipe_185_10 = { "Cooking: Recipe Book I", "Made 10 different Cooking recipes yourself." },
    recipe_185_25 = { "Cooking: Recipe Book II", "Made 25 different Cooking recipes yourself." },
    recipe_185_50 = { "Cooking: Recipe Book III", "Made 50 different Cooking recipes yourself." },
    recipe_186_5 = { "Mining: Recipe Book I", "Smelted 5 different metals." },
    recipe_197_10 = { "Tailoring: Recipe Book I", "Made 10 different Tailoring recipes yourself." },
    recipe_197_25 = { "Tailoring: Recipe Book II", "Made 25 different Tailoring recipes yourself." },
    recipe_197_50 = { "Tailoring: Recipe Book III", "Made 50 different Tailoring recipes yourself." },
    recipe_202_10 = { "Engineering: Recipe Book I", "Made 10 different Engineering recipes yourself." },
    recipe_202_25 = { "Engineering: Recipe Book II", "Made 25 different Engineering recipes yourself." },
    recipe_202_50 = { "Engineering: Recipe Book III", "Made 50 different Engineering recipes yourself." },
    recipe_333_10 = { "Enchanting: Recipe Book I", "Made 10 different Enchanting recipes yourself." },
    recipe_333_25 = { "Enchanting: Recipe Book II", "Made 25 different Enchanting recipes yourself." },
    recipe_333_50 = { "Enchanting: Recipe Book III", "Made 50 different Enchanting recipes yourself." },
    recipe_any_100 = { "Recipe Collector II", "Made 100 different recipes yourself, across all professions." },
    recipe_any_25 = { "Recipe Collector I", "Made 25 different recipes yourself, across all professions." },
    recipe_any_250 = { "Recipe Collector III", "Made 250 different recipes yourself, across all professions." },
    rep_349_7 = { "Ravenholdt: Revered", "Reputation with Ravenholdt at Revered. Beyond Honored only rogues can get there (lockboxes)." },
    rep_349_8 = { "Ravenholdt: Exalted", "Reputation with Ravenholdt at Exalted. Beyond Honored only rogues can get there (lockboxes)." },
    rep_87_5 = { "Signing On", "Reputation with the Bloodsail Buccaneers at Friendly. Costs reputation with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_87_7 = { "Bosun of the Bloodsail", "Reputation with the Bloodsail Buccaneers at Revered. Costs reputation with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_87_8 = { "Admiral of the Bloodsail", "Reputation with the Bloodsail Buccaneers at Exalted. Costs reputation with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_capitals_horde = { "Ambassador of the Horde", "Exalted with Orgrimmar, Thunder Bluff, Undercity and the Darkspear Trolls." },
    rep_cartel = { "Friend of the Cartel", "Exalted with Booty Bay, Gadgetzan, Ratchet and Everlook." },
    rep_exalted_10 = { "Diplomat", "Exalted with 10 different factions." },
    rep_exalted_20 = { "World Diplomat", "Exalted with 20 different factions." },
    salute_horde = { "Loyalty to the Horde", "Saluted Thrall, Cairne Bloodhoof, Lady Sylvanas Windrunner and Vol'jin (/salute with the leader targeted)." },
    sec_mounts_5 = { "Stable Master III", "Learned 5 different mounts." },
    tf_all = { "Master of Disguise", "Experienced every transformation: pirate, ninja, skeleton, shrunk, Orb of Deception and ogre suit." },
    tf_ninja = { "Flipped Out", "Transformed into a ninja (Savory Deviate Delight)." },
    tf_ogre = { "Ogre Chic", "Disguised in the Gordok ogre suit." },
    tf_orb = { "Enemy in the Mirror", "Disguised as a member of the Alliance with the Orb of Deception." },
    tf_pirate = { "Yaaarrrr!", "Transformed into a pirate (Savory Deviate Delight)." },
    tf_shrink = { "Pretty Small", "Shrunk (Noggenfogger Elixir)." },
    tf_skeleton = { "Down to the Bones", "Transformed into a skeleton (Noggenfogger Elixir)." },
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
