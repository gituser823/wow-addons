# WoW-Addons

Kleine und mittelgroße Addons für World of Warcraft (Lua). Die `.toc`-Dateien enthalten Interface-Versionen für Retail und Classic-Varianten.

## Einsteiger

| Addon | Funktion | Befehle |
|---|---|---|
| **SessionTracker** | Fenster mit Spielzeit, Gold und XP seit dem Login, jeweils auch pro Stunde | `/st`, `/st reset`, `/st lock` |
| **DurabilityWarner** | Warnung bei niedriger Haltbarkeit (Standard 20 %), Auto-Reparatur beim Händler, optional über die Gildenbank | `/dw`, `/dw schwelle <Prozent>`, `/dw repair`, `/dw gilde` |
| **AutoSellGrey** | Verkauft graue Items beim Händler und meldet den Erlös | `/asg`, `/asg liste` |

## Größere Addons

| Addon | Funktion | Befehle |
|---|---|---|
| **FarmLog** | Zählt Beute, Gold und Farmzeit pro Zone; zeigt, welche Zone pro Stunde am meisten bringt (Items nach Händlerwert) | `/fl`, `/fl alle`, `/fl reset`, `/fl reset alle` |
| **AltOverview** | Fenster mit allen Charakteren: Level, Gegenstandsstufe, Gold, freie Taschenplätze, Berufe, Gesamtgold | `/alts`, `/alts del <Name>` |
| **RaidCheck** | Prüft Food, Flask/Elixier und frei wählbare Pflicht-Buffs der Gruppe; läuft automatisch beim Bereitschaftscheck | `/rcheck`, `/rcheck melden`, `/rcheck buff <Name>`, `/rcheck liste`, `/rcheck auto` |
| **QuestNotes** | Ton und Meldung, wenn ein Questziel erfüllt ist; optional Fortschritt im Gruppenchat; Notizen mit Kartenposition, Entfernung/Richtung und Wegpunkt | `/qn <Text>`, `/qn liste`, `/qn weg <Nr>`, `/qn del <Nr>`, `/qn gruppe` |
| **MiniMeter** | Schaden/Heilung pro Spieler für den aktuellen bzw. letzten Kampf als Balken; Klick auf den Titel wechselt die Ansicht | `/mm`, `/mm reset`, `/mm melden` |

## Installation

Den gewünschten Addon-Ordner (z. B. `SessionTracker`) nach `<WoW-Ordner>/_retail_/Interface/AddOns/` kopieren
(Classic: `_classic_` bzw. `_classic_era_`) und im Spiel im Addon-Menü aktivieren.

## Hinweise zur Kompatibilität

- Die eigene Interface-Version zeigt `/dump select(4, GetBuildInfo())`. Passt sie nicht zur `## Interface:`-Zeile, markiert WoW das Addon als veraltet.
- Für sehr alte Clients (z. B. 3.3.5) die `## Interface:`-Zeile auf eine einzelne Nummer ändern; einige neuere API-Aufrufe (`SetShown`, `C_Map`, `CombatLogGetCurrentEventInfo`) gibt es dort nicht.
- **MiniMeter** braucht Zugriff auf das Kampflog. Neuere Retail-Versionen schränken das für Addons ein; dann bleibt das Fenster leer und das Addon meldet das beim Login.
- **QuestNotes**: Wegpunkte (`/qn weg`) funktionieren nur auf Karten, die Benutzer-Wegpunkte erlauben; sonst werden die Koordinaten ausgegeben.
- **RaidCheck** erkennt Flasks am Buff-Namen (Flask, Phial, Fläschchen, Elixier …) und Food am „Satt“-Buff.

Alle Addons sind syntaxgeprüft (LuaJIT, Lua 5.1), aber noch nicht im Spiel getestet.
