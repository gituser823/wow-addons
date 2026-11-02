# WoW-Addons

Drei kleine Einsteiger-Addons für World of Warcraft (Lua). Die `.toc`-Dateien enthalten Interface-Versionen für Retail und Classic-Varianten.

| Addon | Funktion | Befehle |
|---|---|---|
| **SessionTracker** | Fenster mit Spielzeit, Gold und XP seit dem Login, jeweils auch pro Stunde | `/st`, `/st reset`, `/st lock` |
| **DurabilityWarner** | Warnung bei niedriger Haltbarkeit (Standard 20 %), Auto-Reparatur beim Händler, optional über die Gildenbank | `/dw`, `/dw schwelle <Prozent>`, `/dw repair`, `/dw gilde` |
| **AutoSellGrey** | Verkauft graue Items beim Händler und meldet den Erlös | `/asg`, `/asg liste` |

## Installation

Den gewünschten Addon-Ordner (z. B. `SessionTracker`) nach `<WoW-Ordner>/_retail_/Interface/AddOns/` kopieren
(Classic: `_classic_` bzw. `_classic_era_`) und im Spiel im Addon-Menü aktivieren.

Für sehr alte Clients (z. B. 3.3.5) die `## Interface:`-Zeile auf eine einzelne passende Nummer ändern;
einige neuere API-Aufrufe (z. B. `SetShown`) gibt es dort nicht.
