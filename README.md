# TheGuild

**English** | [Deutsch](README.de.md)

The guild addon for World of Warcraft: Forever. One installation, everything in the Blizzard look, every feature its own module that can be switched off, no external server, nothing written into officer notes or the guild information.

![Overview](Screenshots/overview.jpg)

## Installation

Download the release and copy the folders `TheGuild` and `TheGuild_*` into `World of Warcraft\_classic_beta_\Interface\AddOns`. Every module appears under TheGuild in the AddOn list and can be disabled there like any other addon.

For a git checkout, run `tools\link-modules.cmd` once. It creates junctions named after the modules so the client finds them inside the repository.

Open the window with `/tg`, the minimap button, the addon compartment or the TheGuild tab on the guild window.

## Modules

### Overview

Guild banner, member counts, who runs the addon, your rank, the next raid night, the next event, open bounties and the message of the day. The event log keeps logins, joins, leaves, renames, rank changes, level ups, deaths, calls to arms, raid nights, posts, polls, events and bounties with filters and text export.

### Members

![Members](Screenshots/members.jpg)

Searchable and sortable roster with roles (tank, healer, damage) and main and alt links shared through the guild. Members set their own, officers set anyone's. Filters for officers, inactive members and missing roles. First seen, rank history, former members and renames travel through the guild. Officers get alt suggestions from public notes and can edit notes from the member menu. Right click opens whisper, invite, show on map, roles and alt links.

### Map

![Map](Screenshots/map.jpg)

Guild members on the world map and the minimap with class icon or class colored dot, name, rank badge, health and tooltip. Positions are sent every few seconds while moving, never from inside an instance, optionally hidden while stealthed. Ctrl + right click on the world map places a guild pin for everyone, temporary or permanent. Deaths show up as skulls. Toggles live in the world map and minimap tracking menus.

### Raids

![Raids](Screenshots/raids.jpg)

Named raid teams of 10, 20 or 40 kept in the guild store, one click invites for online team members with automatic raid conversion. The raid builder plans the subgroups with role counts per group, fills tanks and healers evenly and moves the live raid into the planned groups with one click. Raid days per team show the upcoming nights and export as guild sign up events into the Blizzard calendar. Officers in a raid record attendance automatically, the attendance table shows percentages and the last nights.

### Loot

![Loot](Screenshots/loot.jpg)

Loot sessions for the group leader or an assistant. Items come from the loot window or `/tg loot <link>`, everyone answers with Need, Greed, Offspec or Pass, officers vote, the owner awards. Awards are announced in group chat and kept in a shared history. Items your class cannot use are passed automatically. Soft reserves from softres.it can be pasted, reserved players are marked and the list travels with the session. The trade helper remembers awarded items in your bags, fills the trade window and clears the entry once the item changed hands. Rare or better finds are reported to the guild with their bind type.

### Board

![Board](Screenshots/board.jpg)

Posts, polls, events and bounties kept in the guild store. Everyone posts, officers pin and delete, posts fade after a configurable number of days. Officers create polls with up to eight options, members vote once and can change their vote until the poll closes. Events collect sign ups (yes, maybe, no) and export to the Blizzard calendar. Bounties are tasks with a reward: anyone posts one, members claim it, the author or an officer awards it.

### Voice

![Voice](Screenshots/voice.jpg)

Proximity voice on the Blizzard guild voice channel. Everyone joins the same channel, the addon turns each member up or down on your client by distance: full volume up to 30 yards, silent beyond 90 (both configurable). Positions come from the Map module. Voice groups work like the groups of the Minecraft proximity mods: create one, others join, group members stay at full volume wherever they are. A group only mode silences everybody else. The tab shows who is in the channel, who speaks, distance and current volume.

### Statistics

![Statistics](Screenshots/stats.jpg)

Member counts and activity, class and level distribution, deaths by zone, level ups, loot awards and raid attendance with small rankings that each character can opt out of. Everything exports as text.

### Recruitment

![Recruitment](Screenshots/recruit.jpg)

Officers keep a shared candidate list with notes and status. Candidates can be added from the unit menu of any player. Whisper and guild invite are one click. Candidates who join are marked and get a welcome whisper from the officer who invited them. A recruitment message can be posted into a chosen chat channel.

### Professions

![Professions](Screenshots/professions.jpg)

Records your recipes when a profession window opens, shares them with the guild and shows crafters in item tooltips and in a searchable recipe directory.

### Call to Arms and Messages

`/tg cta`, a key binding or the overview button sends your location to the guild. Receivers get a raid warning, a sound and a popup with a waypoint button. The Messages module welcomes new members, optionally greets logins and congratulates milestone levels, and hides chat from muted players.

## Blizzard integration

The window is built from the client's own templates: a portrait frame with side tabs for the modules, column headers in the who list style, inset lists, tab strips inside the panels and the guild banner with the tabard.

- Tab on the guild window that opens TheGuild.
- Entries in unit and guild member context menus.
- Entries in the world map and minimap tracking menus.
- Role, main and addon version in unit tooltips.
- Settings under Options > AddOns > TheGuild, profile export and import as text.
- Key bindings for the window, call to arms and position sharing.
- Keyboard: Escape closes, Ctrl + Tab switches tabs, Ctrl + F jumps to the search field. Gamepad shoulder buttons switch tabs.

## Commands

```
/tg              toggle the window
/tg config       open the settings
/tg share        toggle position sharing
/tg cta [text]   send a call to arms
/tg loot <link>  start a loot session, /tg loot end, /tg loot sr
/tg voice        voice tab, /tg voice join, /tg voice group <name>
/tg mute <name>  mute or unmute a player
/tg export       settings as text, /tg import pastes them
/tg demo         fill everything with made up data for a presentation
/tg memory       memory of the addon and size of the shared data
/tg sync         request a data sync
/tg version      versions of guild members running the addon
/tg help         list of commands
```

## How the data travels

Everything the guild shares travels over the guild addon channel between members who run the addon. Shared data uses a revision per entry, the highest revision wins, every client checks the author's rank before accepting a change, and clients compare their data on login and every 20 minutes. Positions go out only while moving, sync answers are staggered and limited to three responders, bulk data is compressed and chunked.

- `TheGuildDB` (account wide): settings, guild data per guild, event log.
- `TheGuildCharDB` (per character): position sharing, cooldowns.

| Tag | Content |
| --- | --- |
| HI | version and guid, presence heartbeat |
| P | map, position, health and flags |
| ST / SB | one store change, batch of store items |
| SQ | sync request with revision digest |
| CTA | call to arms |
| LF | item find |
| LS / LR / LV / LA / LE | loot session messages, sent to the raid or party |
| PS / PQ | profession snapshot and request |

## Libraries

LibStub, CallbackHandler-1.0, ChatThrottleLib, LibSerialize, LibDeflate, LibDataBroker-1.1, LibDBIcon-1.0, HereBeDragons-2.0. Each ships with its own license.
