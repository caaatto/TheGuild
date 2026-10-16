# Roadmap

TheGuild wants to be the one guild addon a Forever guild installs. The measure is simple: a guild master should be able to say "install TheGuild" and never need a second guild addon, and a member who dislikes a feature should be able to turn exactly that feature off.

## Principles

1. **Blizzard look, Blizzard places.** Features live where players already look: the guild window, the world map, unit menus, tooltips, the options panel. No second UI language.
2. **Every feature is a module.** Each module is its own addon under the TheGuild group in the AddOn list and has a runtime switch in the settings. The core runs alone.
3. **Works with one user, better with many.** Nothing requires the whole guild to install it. Shared data degrades gracefully to local data.
4. **No external services, no officer notes.** Forever does not let addons write guild notes or guild info. All shared state travels over the guild addon channel with revision merging and rank checks on every client.
5. **Secret values first.** Every value from chat, units or the roster is checked before it is compared or shown. Combat restrictions never break a feature, they only pause it.
6. **Low traffic.** Positions only when moved, heartbeat every 25 seconds, bulk data compressed and chunked, sync answers staggered by name order.

## What the field does well, and what we take from it

| Addon | Strength | TheGuild |
| --- | --- | --- |
| GuildMap | Live member pins, health alerts, layer filter | Map module, native data provider instead of overlay frames, pins translate to continent maps |
| GuildOS | Everything in one window, attendance, loot, professions, alliances | Module system, professions, roster roles, planned raid tools |
| Guild Roster Manager | Join and promotion history, alt grouping, event log, ban list, decentral sync | Alt links and roles today, join history and audit log planned |
| SystematicGuild | Call to arms, raid groups, bounties, no server | Call to Arms module, planned raid groups |
| Moose Guild | Death map, shared pins, guild stats | Death map and shared pins in the Map module, stats planned |
| WinterSocial | Fast online panel, no setup | Members tab, overview |
| ForeverCodex | Recipe database with sync and tooltips | Professions module |
| RCLootCouncil | Loot session with votes, history, trade helper | Planned loot module with the same flow |
| Guild Greeter, GuildMute | Small quality of life | Messages module |

## Milestones

### 0.1 Foundation (done)

Core, comm, store, settings, window, map, members, call to arms, messages, professions. Modules as separate addons with junction tooling and packager metadata.

### 0.2 Daily life (in progress)

- Done: member history (first seen, rank changes, former members, rejoin detection) in the guild store.
- Done: persistent guild event log in the overview with filters and text export.
- Done: last online for offline members, inactivity filters (14 and 30 days), officer and role filters in the members tab.
- Done: public note editing for officers from the member menu.
- Done: hide map pins below a chosen level.
- Done: alt suggestions from public notes with accept and ignore for officers.
- Done: name change detection through GUIDs with migration of roles, alt links and history.
- Layer awareness if an API or a reliable heuristic appears.

### 0.3 Raids (in progress)

- Done: raid teams with saved members, sizes 10, 20 and 40, one click invites with raid conversion.
- Done: attendance per raid night recorded by officers in the raid, synced through the guild store, attendance table with alts counted for their main.
- Done: loot sessions with responses, council votes, awards, group chat announcements and shared history, items captured from the loot window.
- Done: guild finds, rare or better loot of members reported with bind type.
- Done: raid builder with group assignments per team, role counts, auto fill and apply to the live raid.
- Done: loot trade helper, soft reserve import from softres.it, auto pass for unusable items.
- Consumable and gear readiness overview using inspect data outside combat.
- Done: raid days per team, upcoming raid nights, export as guild sign up events into the Blizzard calendar.

### 0.4 Community

- Done: voice module with proximity volume and voice groups on the Blizzard guild voice channel. Needs Blizzard voice on Forever, to be confirmed on the live client.
- Done: guild bulletin board and polls stored in the guild store (Board module).
- Done: events with sign up and bounties with claims and awards in the Board module.
- Done: guild statistics with deaths, levels, loot and raids, opt out per character for rankings. Play time milestones wait for an API that does not print to chat.
- Done: recruitment helper with candidate list, unit menu entry, guild invite button, welcome whisper and channel message.
- Allied guilds: shared crafter directory and pins between two guilds over whisper relays.

### 1.0 Launch quality

- Localization for all client languages Forever ships.
- Done: profile export and import for module settings as text.
- Done: Ctrl + Tab and gamepad shoulder buttons switch tabs, Ctrl + F focuses the search field, Escape closes. Lists stay mouse driven.
- Done in the simulator: 500 member guild loads in milliseconds, first seen records and sync answers travel in batches of 40 items, welcome messages stop after three joins per minute. With 100 online users only the three lowest names answer a sync request. Moving members send a position every 3 seconds, idle ones every 25 seconds, so 100 moving users mean about 33 small messages per second for every client. `/tg memory` prints the memory of every loaded part and the size of the shared data.
- Done: in game help from the overview. A documentation site waits for the launch.
- Done: window rebuilt on the Forever templates (side tabs, column headers, inset lists, tab strips, banner, cards, status bars).

## Open questions

- Guild bank API on Forever: readable for tabs and items, used by Guild Self Forever. A bank snapshot module is possible once the launch client confirms the API.
- Whether Blizzard adds a layer identifier. Until then no layer filter.
- Launch interface number and whether `_Camelot` stays the TOC suffix.
