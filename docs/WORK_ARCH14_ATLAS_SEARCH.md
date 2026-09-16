# ARCH-14-ATLAS-SEARCH — Bekannte Orte finden

Basis: `d57b1ef385728728b132518a1ea05683888dcae0`, Spieltest-PR #125,
`agent/playtest-latest-20260915`. Eigener Fachbranch:
`agent/arch14-atlas-search-20260916`.

## Bedienung

- Weltkarte mit **M** öffnen; bei bereits belegtem M gilt weiter **Umschalt+M**.
- **Strg+F** (auch Cmd+F) öffnet die Ortsliste und fokussiert die Suche. Auf
  kleinen Bildschirmen ist sie auch über **Orte** erreichbar.
- Namen oder Namensbestandteil eingeben. Die Suche berücksichtigt alle bekannten
  Orte des aktuellen Körpers, einschließlich archivierter Einträge und neuer,
  noch nicht ausgelagerter Änderungen. Groß-/Kleinschreibung und äußere
  Leerzeichen spielen keine Rolle. Gespeicherte Namen bleiben unverändert;
  automatisch benannte Orte sind auch unter ihrem aktuellen DE/EN-Namen auffindbar.
- **Eigene/Freunde** filtern vor der Aufteilung der Treffer in Seiten. Ein
  deaktivierter Filter erzeugt deshalb keine leeren Zwischenblätter. Der
  aktuelle Trefferseitenindex bleibt nach einem Filterwechsel soweit möglich
  erhalten, sonst wird die letzte verfügbare Seite angezeigt.
- Pro Seite höchstens **64 Treffer**, geordnet nach ihrer Registrierung im
  Atlas. Pfeile blättern; ein Ortsbutton zentriert die vorhandene Kartenprojektion.
- Ohne Suchtext und mit beiden Filtern bleibt die bisherige normale
  Registerseitenansicht erhalten. Diese sortiert weiterhin innerhalb ihrer Seite.
- Die Anzeige meldet laufende Suche, Treffer dieser Seite, fehlende Treffer oder
  Lesefehler. Sie behauptet keine vollständige Gesamtzahl gefilterter Treffer,
  solange weitere Seiten möglich sind.
- Im Suchfeld funktionieren Texteingabe, Pfeiltasten und Kopieren/Einfügen.
  **Esc** verlässt zunächst die Texteingabe; ein weiteres **Esc** schließt die
  Karte. Die Karte hält die normale Spielpause. Schließen oder Laden bricht
  laufende Sucharbeit ab. Sprachwechsel erhält den Suchtext und prüft die
  Treffer unter den neuen angezeigten Namen erneut.

## Daten und Arbeitsgrenzen

`AtlasPlaceQuery` ist eine kurzlebige Leseabfrage über
`ExplorationAtlas.place_page()`. Es gibt keinen neuen Speichervertrag, Index,
Spielstandteilnehmer oder zweiten Besitzer von Orten/Beziehungen. Eine Abfrage
behält nur eine Ergebnisliste mit maximal 64 Datensätzen. Ein zusätzlicher
passender Eintrag beendet die Suche mit dem Hinweis auf eine nächste Seite.

Pro `step()` werden höchstens acht Datensätze gelesen. Zwischen den Lesezugriffen
gilt zusätzlich ein weiches Zeitbudget von 2 ms. Einzelne synchrone Datei- oder
Registerzugriffe können dieses Budget überschreiten; das ist keine garantierte
Framezeit. Die Eingabe ist um 180 ms verzögert, damit schnelle Textänderungen
keine vollständigen Suchläufe auslösen. Neue Abfragen verwerfen alte Ergebnisse.

Körper-/Datensatzwechsel und geänderte Registergröße invalidieren eine laufende
Abfrage. Die normale Karte liest während ihrer Pause einen ruhenden Spielzustand.
Seitenwechsel durchsuchen den Index erneut; bei sehr großen, dünn passenden
Beständen kann dies länger dauern, bleibt aber schrittweise und abbrechbar.

`WorldMapSource.place_is_visible()` verwendet weiterhin den maßgeblichen
Begegnungsbestand: Ein fremder Marker benötigt einen lebenden Verbündeten auf
demselben Körper. Unbekannte, nicht registrierte Orte werden nicht gesucht;
Kameraschwenken oder Suchanfragen decken keine Kartenfläche auf. Ein beschädigtes
Archiv wird als Lesefehler angezeigt; der bestehende Speicherschutz bleibt aktiv.

Kleine Ortsansichten blenden die redundante Ortsüberschrift und Symbollegende
aus. Suchfeld, Filter, mindestens eine vollständige Trefferzeile und Seitenpfeile
bleiben erreichbar. Bei Fenster-/Schriftänderungen wird das Panel nach der
Neuberechnung seiner Mindestgrößen erneut eingepasst.

## Integration und Prüfung

Gemeinsame Schreibstellen: Atlaspanel/-quelle, additive zehn Sprachschlüssel
mit generierten PO-Dateien, ein Testregistry-Eintrag. Keine Änderungen an
ARCH-24, Wetter, Atmosphäre, Dorfwirtschaft, Flotte oder zentralen Statusseiten.
Den Test `atlas_search_test` genau einmal unter `discovery_map` registrieren.

Der neue Test umfasst einen archivierten Kugelatlas mit 1.025 Orten, begrenzte
Arbeit/Caches, Abbruch/Körperwechsel, unbekannte Archivversion, echte UI-Eingaben,
65 Suchtreffer hinter vier nicht passenden Rohseiten, Seitenwechsel, tote
Verbündete, echte SaveGameService-Speicherung und Suche in einem frischen Prozess.
DE/EN sowie 800×600, 1280×720 und 1920×1080 bei Skalierung 1/1,5 prüfen die
erreichbaren Controls. Die bestehende Sprachprüfung wartet jetzt auf die bewusst
schrittweise Filterabfrage, bevor sie Fokus und Scrollposition vergleicht.

[Abschlussnachweise, genaue Quellstände und ursprüngliche Befunde](evidence/arch14-atlas-search/README.md).
Native optische Abnahme, Windows-Export und Ziel-PC-Framezeiten bleiben bei der
Integration. ARCH-14 insgesamt wird durch diesen Teilauftrag nicht abgeschlossen.
