# TheGuild

[English](README.md) | **Deutsch**

Das Gildenaddon für World of Warcraft: Forever. Eine Installation, alles im Blizzard-Look, jede Funktion ein eigenes Modul, das sich abschalten lässt, kein externer Server, nichts wird in Offiziersnotizen oder die Gildeninfo geschrieben.

![Übersicht](Screenshots/overview.jpg)

## Installation

Release herunterladen und die Ordner `TheGuild` und `TheGuild_*` nach `World of Warcraft\_classic_beta_\Interface\AddOns` kopieren. Jedes Modul erscheint in der Addonliste unter TheGuild und kann dort wie jedes andere Addon abgeschaltet werden.

Bei einem Git-Checkout einmal `tools\link-modules.cmd` ausführen. Es legt Junctions mit den Modulnamen an, damit der Client die Module im Repository findet.

Das Fenster öffnet sich mit `/tg`, über den Minimap-Knopf, das Addon-Fach oder den TheGuild-Reiter am Gildenfenster.

## Module

### Übersicht

Gildenbanner, Mitgliederzahlen, wer das Addon nutzt, dein Rang, der nächste Raidabend, das nächste Event, offene Aufträge und die Nachricht des Tages. Das Ereignislog sammelt Logins, Beitritte, Austritte, Umbenennungen, Rangwechsel, Stufenaufstiege, Tode, Rufe zu den Waffen, Raidabende, Beiträge, Umfragen, Events und Aufträge mit Filtern und Textexport.

### Mitglieder

![Mitglieder](Screenshots/members.jpg)

Durchsuchbarer und sortierbarer Roster mit Rollen (Tank, Heiler, Schaden) sowie Main- und Twink-Verknüpfungen, die über die Gilde geteilt werden. Mitglieder setzen ihre eigenen, Offiziere die aller anderen. Filter für Offiziere, inaktive Mitglieder und fehlende Rollen. Erstes Sehen, Ranghistorie, Ehemalige und Umbenennungen laufen über die Gilde. Offiziere bekommen Twink-Vorschläge aus den öffentlichen Notizen und bearbeiten Notizen aus dem Mitgliedermenü. Rechtsklick öffnet Flüstern, Einladen, Auf Karte zeigen, Rollen und Twink-Verknüpfungen.

### Karte

![Karte](Screenshots/map.jpg)

Gildenmitglieder auf Weltkarte und Minimap mit Klassensymbol oder klassenfarbenem Punkt, Name, Rangabzeichen, Leben und Tooltip. Positionen werden alle paar Sekunden beim Bewegen gesendet, nie aus Instanzen, optional nicht im Schleichen. Strg + Rechtsklick auf der Weltkarte setzt eine Gildenmarkierung für alle, zeitlich begrenzt oder dauerhaft. Tode erscheinen als Schädel. Die Schalter sitzen in den Verfolgungsmenüs von Weltkarte und Minimap. Mitglieder mit GuildMap statt TheGuild erscheinen ebenfalls, und die eigene Position geht im GuildMap-Format raus, solange eines davon online ist, so sehen sich beide Addons gegenseitig.

### Raids

![Raids](Screenshots/raids.jpg)

Benannte Raidteams mit 10, 20 oder 40 Plätzen im Gildenspeicher, Einladungen aller Online-Mitglieder mit einem Klick samt Raidumwandlung. Der Raidplaner plant die Gruppen mit Rollenzahlen pro Gruppe, verteilt Tanks und Heiler gleichmäßig und schiebt den laufenden Raid mit einem Klick in die geplanten Gruppen. Raidtage pro Team zeigen die kommenden Abende und exportieren sie als Gilden-Anmeldeevents in den Blizzard-Kalender. Offiziere im Raid erfassen die Anwesenheit automatisch, die Tabelle zeigt Prozente und die letzten Abende.

### Loot

![Loot](Screenshots/loot.jpg)

Lootsitzungen für Gruppenleiter oder Assistenten. Gegenstände kommen aus dem Lootfenster oder per `/tg loot <Link>`, alle antworten mit Bedarf, Gier, Zweitspezialisierung oder Passen, Offiziere stimmen ab, der Leiter vergibt. Vergaben werden im Gruppenchat gemeldet und in einer gemeinsamen Historie gespeichert. Gegenstände, die deine Klasse nicht nutzen kann, werden automatisch gepasst. Soft Reserves von softres.it lassen sich einfügen, reservierte Spieler werden markiert und die Liste reist mit der Sitzung. Der Handelshelfer merkt sich vergebene Gegenstände in deinen Taschen, bietet über dem Handelsfenster einen Knopf, der sie für den richtigen Spieler einlegt, und löscht den Eintrag, sobald der Gegenstand den Besitzer gewechselt hat. Seltene oder bessere Funde werden der Gilde mit Bindungsart gemeldet.

### Board

![Board](Screenshots/board.jpg)

Beiträge, Umfragen, Events und Aufträge im Gildenspeicher. Jeder schreibt, Offiziere pinnen und löschen, Beiträge verblassen nach einstellbaren Tagen. Offiziere erstellen Umfragen mit bis zu acht Optionen, Mitglieder stimmen einmal ab und können ihre Stimme bis zum Schließen ändern. Events sammeln Anmeldungen (Ja, Vielleicht, Nein) und exportieren in den Blizzard-Kalender. Aufträge sind Aufgaben mit Belohnung: Jeder schreibt einen aus, Mitglieder übernehmen ihn, der Ersteller oder ein Offizier vergibt die Belohnung.

### Voice

![Voice](Screenshots/voice.jpg)

Proximity-Voice über den Blizzard-Gildensprachkanal. Alle treten demselben Kanal bei, das Addon regelt auf deinem Client jedes Mitglied nach Entfernung lauter oder leiser: volle Lautstärke bis 30 Meter, stumm ab 90 Metern (beides einstellbar), wobei voll standardmäßig 80 Prozent heißt, weil 100 übersteuert. Die Positionen liefert das Kartenmodul. Voice-Gruppen funktionieren wie die Gruppen der Minecraft-Proximity-Mods: eine erstellen, andere treten bei, Gruppenmitglieder bleiben überall voll hörbar. Drei Modi: "Gruppe und Nähe", in dem du mit jedem reden kannst, der an dir vorbeiläuft, ohne dass deine Gruppe ihn hört; "Nur Nähe", in dem du deine Gruppe weiter hörst, die Gruppe dich aber nur in deiner Nähe hört, praktisch wenn du jemanden triffst und die Gruppe nicht vollreden willst; und "Nur Gruppe", der alle außerhalb deiner Gruppe stumm schaltet. Eine Einstellung kann aus den Gildenmitgliedern deiner Gruppe oder deines Schlachtzugs automatisch eine Voice-Gruppe machen; sie ist standardmäßig aus, Gruppen entstehen absichtlich. Die Gruppenliste hat eine Suche nach Gruppenname und Spieler. Der Tab zeigt, wer im Kanal ist, wer spricht, Entfernung und aktuelle Lautstärke. Ein kleiner verschiebbarer Mikrofonknopf auf dem Bildschirm zeigt, ob du stumm oder auf Ton aus bist und wie viele Mitglieder du gerade hörst, darunter eine kompakte Liste, wer im Kanal ist, mit Klassensymbol, Lautsprechersymbol beim Sprechen und Stummmarkierung. Linksklick schaltet stumm, Rechtsklick öffnet ein Menü mit Modus, Beitreten, Verlassen und dem Listenschalter. Die eigenen Sprechmeldungen des Spielclients über dem Chat sind ausgeblendet, solange das Modul läuft, eine Einstellung holt sie zurück. Die Zeile eines Mitglieds, das gerade spricht, bekommt einen grünen Rahmen, so wie Discord Sprecher hervorhebt.

### Statistik

![Statistik](Screenshots/stats.jpg)

Mitgliederzahlen und Aktivität, Klassen- und Stufenverteilung, Tode insgesamt nach Zone und Mitglied, Stufenaufstiege insgesamt, Lootvergaben und Raid-Anwesenheit mit kleinen Ranglisten, aus denen sich jeder Charakter austragen kann. Jeder Charakter zählt seine eigenen Tode und Stufenaufstiege und teilt die Summen, deshalb überleben die Zahlen jeden Logout und wachsen über die Lebenszeit der Gilde. Alles lässt sich als Text exportieren.

### Rekrutierung

![Rekrutierung](Screenshots/recruit.jpg)

Der Tab ist nur für Offiziere und den Gildenmeister sichtbar. Offiziere führen eine gemeinsame Kandidatenliste mit Notizen und Status. Kandidaten lassen sich aus dem Einheitenmenü jedes Spielers hinzufügen. Flüstern und Gildeneinladung sind ein Klick. Beigetretene Kandidaten werden markiert und bekommen eine Begrüßung vom einladenden Offizier. Eine Rekrutierungsnachricht lässt sich in einen gewählten Chatkanal posten.

### Berufe

![Berufe](Screenshots/professions.jpg)

Erfasst deine Rezepte beim Öffnen eines Berufsfensters, teilt sie mit der Gilde und zeigt Handwerker in Item-Tooltips und in einem durchsuchbaren Rezeptverzeichnis.

### Ruf zu den Waffen und Nachrichten

`/tg cta`, eine Tastenbelegung oder der Knopf in der Übersicht schickt deine Position an die Gilde. Empfänger bekommen eine Raidwarnung, einen Ton und ein Fenster mit Wegpunkt-Knopf. Das Nachrichtenmodul begrüßt neue Mitglieder, grüßt optional Logins, gratuliert zu Meilensteinstufen und blendet den Chat stummgeschalteter Spieler aus.

## Blizzard-Integration

Das Fenster besteht aus den Vorlagen des Clients: Porträtrahmen mit Seitentabs für die Module, Spaltenköpfe im Stil der Wer-Liste, Listen mit Inset-Rahmen, Reiterleisten in den Panels und das Gildenbanner mit Wappenrock.

- Reiter am Gildenfenster, der TheGuild öffnet.
- Einträge in den Kontextmenüs von Spielern, Ziel, Fokus und Freunden. Gildenroster- und Gruppenmenüs bleiben unangetastet, weil Blizzard dort geschützte Aktionen wie den Gildenrauswurf ausführt und jede Addon-Erweiterung sie blockieren würde.
- Einträge in den Verfolgungsmenüs von Weltkarte und Minimap.
- Rolle, Main und Addonversion in Einheiten-Tooltips.
- Einstellungen unter Optionen > AddOns > TheGuild, Profilexport und -import als Text.
- Tastenbelegungen für Fenster, Ruf zu den Waffen, Positionsfreigabe und Mikrofon, auch direkt in den Addon-Optionen belegbar.
- Tastatur: Escape schließt, Strg + Tab wechselt den Reiter, Strg + F springt ins Suchfeld. Am Gamepad wechseln die Schultertasten.
- Eine geführte Tour im Hinweisstil des Clients beim ersten Öffnen des Fensters: sie geht durch jeden Tab und erklärt die wichtigsten Bedienelemente, der Mikrofonknopf bekommt beim ersten Erscheinen eigene Hinweise. In den Einstellungen abschaltbar oder erneut startbar.

## Befehle

```
/tg              Fenster ein- oder ausblenden
/tg config       Einstellungen öffnen
/tg share        Positionsfreigabe umschalten
/tg cta [Text]   Ruf zu den Waffen senden
/tg loot <Link>  Lootsitzung starten, /tg loot end, /tg loot sr
/tg voice        Voice-Tab, /tg voice join, /tg voice mute, /tg voice group <Name>, /tg voice hud
/tg mute <Name>  Spieler stumm schalten oder freigeben
/tg export       Einstellungen als Text, /tg import fügt sie ein
/tg demo         alles mit erfundenen Daten für eine Vorführung füllen
/tg memory       Speicher des Addons und Größe der geteilten Daten
/tg keys         Status des Signaturschlüssels, /tg keys bench misst die Signaturgeschwindigkeit
/tg sync         Datenabgleich anfordern
/tg version      Versionen der Gildenmitglieder mit Addon
/tg help         Befehlsliste
```

## Wie die Daten reisen

Alles, was die Gilde teilt, läuft über den Gilden-Addonkanal zwischen Mitgliedern mit Addon. Jeder Eintrag trägt eine Revision, die höchste gewinnt, jeder Client prüft den Rang des Autors, bevor er eine Änderung annimmt, und die Clients gleichen ihre Daten beim Login und alle 20 Minuten ab. Positionen gehen nur beim Bewegen raus, Sync-Antworten sind gestaffelt und auf drei Antwortende begrenzt, große Daten werden komprimiert und gestückelt. Liefert ein Realm keine Gilden-Addon-Nachrichten aus, merkt das Addon das beim Login und schickt stattdessen Whisper an die Mitglieder, die es nutzen.

Vertrauensregeln: jeder Eintrag ist von seinem Autor signiert, mit einem Schlüsselpaar, das jeder Charakter beim ersten Login erzeugt (Ed25519-Verfahren in Lua, wenige Millisekunden pro Signatur). Ein Eintrag wird direkt vom Autor angenommen, dessen Namen der Client garantiert, oder von jedem anderen, wenn die Signatur zu einem vertrauten Schlüssel des Autors passt. Schlüssel werden vertraut, wenn man ein Mitglied direkt gesehen hat, oder über ein Zertifikat, das Offiziere und Gildenmeister automatisch für gesehene Schlüssel signieren. Der Schlüssel des Gildenmeisters gilt nur aus direktem Kontakt, Offiziersschlüssel nur aus direktem Kontakt oder einem Gildenmeister-Zertifikat, kein Offizier kann also für einen Schlüssel über seinem Rang bürgen. Wer dreimal Einträge mit falscher Signatur weiterreicht, wird zehn Minuten ignoriert, wer mehr als 256 KB entpackte Daten pro Minute schickt, fünf Minuten; Heartbeats, Berufsanfragen und Fundmeldungen sind pro Absender begrenzt. Von Offizieren weitergereichte Einträge erscheinen sofort und werden im Hintergrund geprüft, von Mitgliedern weitergereichte warten auf die Prüfung, Gildenmeister-Einstellungen warten immer. Die Prüfung läuft in kleinen Häppchen pro Frame und bremst das Spiel nie. Revisionen müssen ganze Zahlen ohne riesige Sprünge sein, unbekannte Datentypen werden verworfen, Texte anderer Spieler verlieren Textur- und Link-Escapes. Jeder Datentyp hat eine Form, die eingehende Einträge erfüllen müssen (ein Beitrag braucht einen Texttitel, eine Stimme ist eine Zahl von 1 bis 8, ein Zertifikat trägt einen 64 Zeichen langen Schlüssel), damit ein fehlerhafter Eintrag nicht das Fenster anderer Mitglieder lahmlegt. Jeder Eintrag ist auf 8 KB begrenzt, jedes Mitglied auf 300 Einträge pro Datentyp (Offiziere 2000), und kurzlebige Datentypen haben eine Aufbewahrungsfrist, nach der Einträge auf jedem Client verfallen: Beiträge und Umfragen 180 Tage, Events und Anmeldungen 60 Tage, Aufträge 90 Tage, Todesmarkierungen 14 Tage, Voice-Gruppen 30 Tage. Statistiken werden nie gelöscht: Loot-Historie, Raid-Anwesenheit, ehemalige Mitglieder und die Lebenszeitzähler, die jedes Mitglied für Tode und Stufenaufstiege führt, bleiben für immer. Gelöschte Einträge hinterlassen 45 Tage eine Markierung, damit späte Clients sie nicht wiederbeleben, dann verschwindet auch die. Eine Sync-Anfrage wird höchstens alle fünf Minuten pro Anfragendem beantwortet. Gilden, die du 90 Tage nicht besucht hast, werden aus den gespeicherten Daten entfernt. Lootsitzungen gelten nur vom Gruppenleiter oder Assistenten über den Gruppen- oder Schlachtzugskanal, Gegenstände landen erst nach einem Klick im Handelsfenster, der Handelspartner wird über die GUID erkannt. Rufe zu den Waffen sind auf einen pro Absender und Minute begrenzt. Große Nachrichten sind auf 40 Teile mit zwei offenen Übertragungen pro Absender begrenzt.

- `TheGuildDB` (accountweit): Einstellungen, Gildendaten pro Gilde, Ereignislog.
- `TheGuildCharDB` (pro Charakter): Positionsfreigabe, Abklingzeiten.

Die Nachrichtentypen stehen in der englischen README.

## Entwicklung

- Das Repository nach `Interface\AddOns\TheGuild` klonen und einmal `tools\link-modules.cmd` ausführen. Es legt Junctions `AddOns\TheGuild_<Modul>` auf `TheGuild\Modules\<Modul>` an, der Client lädt jedes Modul damit direkt aus dem Checkout.
- `TheGuild.toc` ist der Kern, jeder Ordner unter `Modules` ein eigenes Addon mit `## Dependencies: TheGuild` und `## Group: TheGuild`. Ein Modul meldet sich mit `TG:NewModule` an, registriert Ereignisse und Nachrichten über seine Modulmethoden, damit das Abschalten alles entfernt, und hängt seinen Reiter mit `TG.Window:RegisterTab` ins Fenster.
- Alle Fensterbausteine stammen aus `Core/UI.lua` und nutzen nur Vorlagen, die der Forever-Client mitbringt. Spaltenköpfe, Listen mit Inset-Rahmen, Reiterleisten, Abschnittsleisten, Karten, Kacheln, Balken und das Gildenbanner sind Helfer dort.
- Geteilte Daten laufen über `TG.Store` mit einer Regel pro Bereich: `any`, `self`, `officer`, `gm` oder `own`. Jeder Wert aus Chat, Einheiten oder Roster wird vor der Verwendung mit `TG.usable` geprüft, weil der Client geheime Werte liefert.
- Texte stehen in `Locales/enUS.lua` mit deutscher Übersetzung in `Locales/deDE.lua`. Jeder neue Text braucht beides.
- Der Code enthält bewusst keine Kommentare. Diese Datei und `ROADMAP.md` tragen die Erklärungen.
- `/tg demo` füllt alle Module ohne Gilde mit erfundenen Daten, `/tg memory` zeigt Speicher und Datenmengen, `/tg voice status` den Zustand des Sprachchats.

## Veröffentlichung

Jeder Push auf `main` startet den Workflow in `.github/workflows/release.yml`, außer Pushes, die nur READMEs, Roadmap oder Screenshots ändern. Der Workflow prüft, dass jede in einer TOC gelistete Datei existiert, zählt die Patch-Version in allen TOCs hoch, committet das als `release vX.Y.Z` mit Tag, baut das Zip im Release-Layout (`TheGuild` plus je ein Ordner `TheGuild_<Modul>`, wie in `.pkgmeta` beschrieben), veröffentlicht ein GitHub-Release mit dem Zip und lädt die Datei zu CurseForge hoch. Die CurseForge-Spielversion wird aus `## Interface` abgeleitet und im Forever-Versionstyp gesucht, ein Client-Patch braucht also nur neue TOC-Werte.

Minor- und Major-Versionen werden vor dem Push von Hand in allen TOCs gesetzt, der Workflow zählt nur die letzte Stelle. Über den Reiter Actions lässt er sich auch von Hand mit Typ release, beta oder alpha starten. Er braucht die Repository-Variable `CF_PROJECT_ID` und das Secret `CF_API_TOKEN`.

## Lizenz

TheGuild hat eine eigene Lizenz, siehe `LICENSE`. Du darfst es frei nutzen, den Quellcode lesen und forken, es für dich oder deine Gilde ändern und Beiträge einreichen. Das Addon oder eine geänderte Fassung woanders zu veröffentlichen ist nicht erlaubt, solange das Projekt gepflegt wird, also in den letzten zwölf Monaten einen Release hatte, oder innerhalb eines Monats, nachdem ein Spielupdate das Addon komplett funktionsunfähig gemacht hat. Danach dürfen geänderte Fassungen unter anderem Namen mit Verweis hierher veröffentlicht werden. Das Addon oder einen Fork zu verkaufen oder hinter eine Bezahlschranke zu stellen ist nie erlaubt. Die mitgelieferten Bibliotheken behalten ihre eigenen Lizenzen.

## Bibliotheken

LibStub, CallbackHandler-1.0, ChatThrottleLib, LibSerialize, LibDeflate, LibDataBroker-1.1, LibDBIcon-1.0, HereBeDragons-2.0. Jede bringt ihre eigene Lizenz mit.
