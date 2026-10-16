local ADDON, TG = ...

_G.TheGuild = TG

TG.name = ADDON
TG.title = "TheGuild"
TG.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
TG.prefix = "TheGuild"
TG.protocol = 1
TG.color = "|cff4dc3ff"
TG.gold = "|cffffd100"

local _, _, _, interface = GetBuildInfo()
TG.interface = interface or 0
TG.isForever = TG.interface >= 16000 and TG.interface < 17000

TG.icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01"
