local TG = TheGuild
local Loot = TG:GetModule("Loot")

local Usable = {}
Loot.Usable = Usable

local ARMOR, WEAPON = 4, 2
local CLOTH, LEATHER, MAIL, PLATE, SHIELD, LIBRAM, IDOL, TOTEM = 1, 2, 3, 4, 6, 7, 8, 9
local W = {
    AXE1 = 0, AXE2 = 1, BOW = 2, GUN = 3, MACE1 = 4, MACE2 = 5, POLEARM = 6, SWORD1 = 7, SWORD2 = 8,
    STAFF = 10, FIST = 13, MISC = 14, DAGGER = 15, THROWN = 16, SPEAR = 17, CROSSBOW = 18, WAND = 19, FISHING = 20,
}

local function set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end

local ARMOR_BY_CLASS = {
    WARRIOR = set(CLOTH, LEATHER, MAIL, PLATE, SHIELD),
    PALADIN = set(CLOTH, LEATHER, MAIL, PLATE, SHIELD, LIBRAM),
    HUNTER = set(CLOTH, LEATHER, MAIL),
    ROGUE = set(CLOTH, LEATHER),
    PRIEST = set(CLOTH),
    SHAMAN = set(CLOTH, LEATHER, MAIL, SHIELD, TOTEM),
    MAGE = set(CLOTH),
    WARLOCK = set(CLOTH),
    DRUID = set(CLOTH, LEATHER, IDOL),
}

local WEAPON_BY_CLASS = {
    WARRIOR = set(W.AXE1, W.AXE2, W.MACE1, W.MACE2, W.SWORD1, W.SWORD2, W.POLEARM, W.STAFF, W.FIST, W.DAGGER, W.BOW, W.GUN, W.CROSSBOW, W.THROWN),
    PALADIN = set(W.AXE1, W.AXE2, W.MACE1, W.MACE2, W.SWORD1, W.SWORD2, W.POLEARM),
    HUNTER = set(W.AXE1, W.AXE2, W.SWORD1, W.SWORD2, W.POLEARM, W.STAFF, W.FIST, W.DAGGER, W.BOW, W.GUN, W.CROSSBOW, W.THROWN, W.SPEAR),
    ROGUE = set(W.AXE1, W.MACE1, W.SWORD1, W.FIST, W.DAGGER, W.BOW, W.GUN, W.CROSSBOW, W.THROWN),
    PRIEST = set(W.MACE1, W.STAFF, W.DAGGER, W.WAND),
    SHAMAN = set(W.AXE1, W.AXE2, W.MACE1, W.MACE2, W.STAFF, W.FIST, W.DAGGER),
    MAGE = set(W.SWORD1, W.STAFF, W.DAGGER, W.WAND),
    WARLOCK = set(W.SWORD1, W.STAFF, W.DAGGER, W.WAND),
    DRUID = set(W.MACE1, W.MACE2, W.STAFF, W.FIST, W.DAGGER),
}

local GENERIC_SLOTS = set("INVTYPE_CLOAK", "INVTYPE_FINGER", "INVTYPE_NECK", "INVTYPE_TRINKET", "INVTYPE_HOLDABLE", "INVTYPE_TABARD", "INVTYPE_BODY", "INVTYPE_BAG")

local function myClass()
    local _, classFile = UnitClass("player")
    if TG.usable(classFile) and classFile then return classFile end
    local me = TG.Roster:MyEntry()
    return me and me.classFile
end

function Usable:CanUse(link)
    local classFile = myClass()
    if not classFile or not ARMOR_BY_CLASS[classFile] then return nil end
    local _, _, _, _, _, _, _, _, equipLoc, _, _, classID, subclassID = C_Item.GetItemInfo(link)
    if not TG.usable(classID) or classID == nil or not TG.usable(subclassID) then return nil end
    if TG.usable(equipLoc) and GENERIC_SLOTS[equipLoc] then return true end
    if classID == ARMOR then
        if subclassID == 0 or subclassID == 5 then return true end
        return ARMOR_BY_CLASS[classFile][subclassID] == true
    elseif classID == WEAPON then
        if subclassID == W.MISC or subclassID == W.FISHING then return true end
        return WEAPON_BY_CLASS[classFile][subclassID] == true
    end
    return nil
end
