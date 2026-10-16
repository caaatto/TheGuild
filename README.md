# TheGuild

Modular guild addon for World of Warcraft: Forever (Interface 16001).

Everything the guild shares travels over the guild addon channel between members who run the addon. Nothing is written into officer notes or the guild information text, and no external server is involved.

## Modules

Every module is its own addon (`TheGuild_Map`, `TheGuild_Roster`, `TheGuild_Alerts`, `TheGuild_Social`, `TheGuild_Professions`) grouped under TheGuild in the AddOn list, so a module can be disabled there like any other addon. Loaded modules also have a runtime switch in the settings (`/tg config`). The core addon with the overview runs on its own.

The module folders live under `TheGuild/Modules/`. Release packages (see `.pkgmeta`) move them next to the core addon. For a checkout inside `Interface\AddOns`, run `tools\link-modules.cmd` once to create junctions named after the modules.

- **Overview**: guild emblem, message of the day, counts, quick actions and a live activity feed (logins, joins, level ups, deaths, calls to arms).
- **Map**: guild members on the world map and the minimap with class icon or class colored dot, name, rank badge, health and tooltip. Positions are sent every few seconds while moving, never from inside an instance, and can be hidden while stealthed. Ctrl + right click on the world map places a guild pin for everyone (temporary or permanent). Deaths show up as skulls. Toggles live in the world map and minimap tracking menus.
- **Members**: searchable, sortable roster with roles (tank, healer, damage) and main/alt links shared through the guild. Members set their own, officers set anyone's. Right click for whisper, invite, show on map, role and alt links.
- **Call to Arms**: `/tg cta`, a key binding or the overview button sends your location to the guild. Receivers get a raid warning, a sound and a popup with a waypoint button. 15 minute cooldown per character.
- **Messages**: welcomes new members, optionally greets logins and congratulates milestone levels. Waits a few seconds and stays quiet when somebody else already did. Mute list with chat filter (`/tg mute <name>`).
- **Professions**: records your recipes when a profession window opens, shares them with the guild and shows crafters in item tooltips and in a searchable recipe directory.

## Blizzard integration

- Tab on the guild window (Communities frame) that opens TheGuild.
- Entries in unit and guild member context menus.
- Entries in the world map and minimap tracking menus.
- Role, main and addon version in unit tooltips.
- Settings panel under Options > AddOns > TheGuild.
- Minimap button (LibDBIcon) and addon compartment entry.
- Key bindings for the window, call to arms and position sharing.

## Commands

```
/tg              toggle the window
/tg config       open the settings
/tg share        toggle position sharing
/tg cta [text]   send a call to arms
/tg mute <name>  mute or unmute a player
/tg sync         request a data sync
/tg comms        communication statistics
/tg version      versions of guild members running the addon
/tg help         list of commands
```

## Data

- `TheGuildDB` (account wide): settings, guild data per guild (roles, alt links, pins, deaths, recipes), activity feed.
- `TheGuildCharDB` (per character): position sharing, call to arms cooldown, greeting cooldowns.

Shared guild data uses a revision per entry. The highest revision wins, every client checks the author's rank before accepting a change, and clients compare their data on login and every 20 minutes.

## Protocol

Prefix `TheGuild`, messages `<protocol>\001<tag>\001<payload>`. Payloads starting with `=` are plain text, payloads starting with `~` are LibSerialize + LibDeflate encoded tables. Long messages are split into `K` chunks of 200 bytes. All messages go to the guild channel except sync batches, which are whispered to the requester. Sending respects the chat messaging lockdown and ChatThrottleLib.

| Tag | Content |
| --- | --- |
| HI | version:guid, presence heartbeat every 5 minutes |
| P | mapID:x:y:health:flags, flags i (instance), s (stealthed), d (dead), x (sharing off) |
| ST | one store change |
| SQ / SB | sync request with revision digest, batch of newer entries |
| CTA | call to arms with map, position, zone and text |
| PS / PQ | profession snapshot, request for snapshots |

## Beta notes

The Forever beta client has been reported to skip loading account wide saved variables on a cold start. Per character variables survive a reload. Nothing in the addon depends on saved data to work, it only loses history and settings when the client drops the file.

## Libraries

LibStub, CallbackHandler-1.0, ChatThrottleLib, LibSerialize, LibDeflate, LibDataBroker-1.1, LibDBIcon-1.0, HereBeDragons-2.0. Each ships with its own license.
