# ARCH-30-SHIP-INSTANCES — Flottentest, Hangar und dauerhafte Entwurfspins

Basis: `d57b1ef385728728b132518a1ea05683888dcae0` aus Spieltest-PR #125.
Branch: `agent/arch30-ship-instances-20260916`.

## Ergebnis und Bedienung

Hauptmenü → **Flottentest** → **Neuer Flottentest** erstellt einen getrennten
Kugelspielstand mit Expedition, Beiboot, einer Testfracht und einer Testprobe.
Der Spieler und seine Epoche bleiben unverändert an der Oberfläche. Dieser
Prüfeinstieg gibt weder M8/M9 frei noch erzeugt er echte Wirtschaftswaren.

1. Beiboot in der Schiffsliste und Expedition als Ziel auswählen, dann andocken.
2. Testfracht oder Probe wählen und zum Zielschiff umladen. Nur eine direkte
   Hangarverbindung erlaubt diese Übergabe; der Zielfrachtraum muss ausreichen.
3. Abdocken setzt dasselbe Schiff an den 60-m-Prüfplatz im Systemraum zurück.
   Das ist eine Verwaltungsaktion im Flottentest, kein simulierter Flug.
4. In der Schiffswerft einen vollständigen Entwurf speichern. Im Flottentest
   über die durchsuchbare, seitenweise geladene Auswahl eine weitere Instanz
   neben dem Zielschiff erzeugen. Bis zu 16 Schiffe sind zulässig.
5. Jede erfolgreiche Aktion speichert sofort. **Test laden**, Hauptmenü
   **Fortsetzen** und der normale Spielstandbrowser öffnen denselben Flottentest.
   Deutsch/Englisch und Sprachwechsel sind angeschlossen.

Die Schiffsliste zeigt den Namen und einen kurzen Instanzzusatz. Die Detailansicht
zeigt die vollständige Instanz-ID, feste Entwurfsrevision, Energie, belegten
Frachtraum und den Hangarhost. Hangarbelegung wird aus den Schiffsorten abgeleitet.

## Daten und Zuständigkeit

- Optionales Feld `C.expedition_fleet`, Schema 1, Modus `shipyard_trial`, mit
  `snapshot` und `designs`. Reguläre/neue Alt-Kampagnen erhalten kein leeres
  Flottenfeld und keine Schiffe. Kein zweiter Speicherpfad oder Autoload.
- Der bestehende ARCH-30-Struktur-/Erhaltungsvertrag liegt jetzt unter
  `space/fleet/expedition_contract.gd`. Der alte Fixture-Pfad erbt davon;
  historische Vertragsprüfungen laufen damit gegen dieselbe Implementierung.
- Jede Instanz hat eine unabhängige ID, Rolle, Energie und genau einen Ort.
  Oberflächen-, System- und Dockformen des vorhandenen Vertrags bleiben erhalten.
  Die aktuell freigegebenen Befehle sind auf System-/Hangarverwaltung begrenzt.
- `designs` enthält die vollständigen serialisierten Modulbaupläne der verwendeten
  Revisionen. Schlüssel: Design-ID und Revision. Fähigkeiten werden aus diesen
  Entwürfen und dem installierten Katalog abgeleitet und mit den gespeicherten
  Werten verglichen. Mehrere Instanzen können einen Pin teilen; verschiedene
  Revisionen bleiben nebeneinander erhalten. Umbenennen/Ändern/Löschen einer
  losen Entwurfsdatei verändert kein bereits erzeugtes Schiff.
- Derselbe Revisionsschlüssel darf nicht mit anderem Entwurfsinhalt belegt werden.
  Instanzen und Module werden bei Spielstandkopien nicht neu erzeugt; nur die
  Kampagneneigentümer-ID im Flottensnapshot wird an die Kopie angepasst.
- Fracht/Proben sind eindeutige Transportverweise. Nur `shipyard_trial`-Belege
  werden angenommen. Keine Dorfressourcen, Forschungsbelohnungen oder zweite
  Personenpopulation. Die einzige Personenreferenz gehört dem Kampagnenspieler.
- Docken benötigt ein freies, geometrisch passendes Hangarmodul, passende Rollen
  und höchstens 100 m Abstand im selben System. Große Positionen werden vor einer
  Float-Vektorumwandlung komponentenweise als Double subtrahiert.
- `SaveGameService.request_fleet_command` verarbeitet einen begrenzten Befehl plus
  erwarteter Flottenrevision. Es übernimmt keine fremden fertigen Snapshots.
  Der gemeinsame Save veröffentlicht alles atomar; bei Fehlern wird das vorherige
  Flottenfeld wiederhergestellt. Pause, laufendes Speichern/Übergaben und veraltete
  Revisionen verweigern neue Befehle. Wiederholung nach einem erfolgreichen Commit
  wird als veralteter Befehl abgelehnt und verändert keine Fracht.
- Der registrierte `game_state`-Teilnehmer prüft Inhalt und Zukunftsschutz.
  Unbekannte **oder beschädigte** Flotten, Pins, Orte und Referenzen blockieren
  Laden/Schreiben/Backup-Rückfall vollständig. Kompatible Stände ohne dieses Feld
  behalten ihre bisherigen Regeln. Kein stilles Reparieren oder Herabstufen.
- Pins liegen im vollständigen Spielstand und damit in dessen bestehenden
  Kopien/History/Archiven. Die lose Autorenbibliothek bleibt außerhalb des
  Kampagnensnapshots; nicht verwendete Entwürfe gehören weiterhin zum vollständigen
  Benutzerdatenarchiv.

## Integration und Grenzen

Gemeinsame additive Anschlüsse: `SaveGameService` (Befehle und Kopie-ID),
`SaveParticipants.game_state` (Prüfung/Zukunftsschutz), `SessionFlow` (Laden/Schließen
des Tests), Hauptmenü, Schiffswerft-Button, 40 `FLEET_*`-Sprachschlüssel und eine
Testregistrierung. Diese Stellen beim Zusammenführen mit Wetter/anderen UI-Paketen
additiv erhalten. Atmosphären-, Wetter-, Tier-/Sozial- und Terrainlogik unverändert.
Zentrale Projektstände/Roadmap-Häkchen bleiben beim Integrationschat.

Dies ist das nächste ARCH-30-Fundament mit bedienbarem Prüfeinstieg. Es liefert
keine räumliche Hangaransicht, Flugphysik, Landung, Echtfracht, Mannschaftswechsel,
Ressourcenkosten, Forschung oder normale Weltraumepoche. Die alten M9-Abhängigkeiten
und die spätere vollständige Expeditionsabnahme bleiben bestehen.

## Prüfung

`fleet_runtime_test` ist genau einmal im bestehenden Vertrag `expedition_design`
registriert. 83 Fachprüfpunkte einschließlich echter SaveService-Fehler/Rollback,
Original-/Backupbytes, neuem Prozess nach Entfernen der Autorenoriginale, belegtem
Hangar, Frachtkapazität, Doppelbelegen, verschiedenen Entwurfsrevisionen, großen
Double-Orten, Zukunftsformaten, Spielstandkopie, Hauptmenü/Weiterladen und DE/EN.
Direkte Verbraucher: `expedition_contract_test`, `shipyard_test`,
`save_participants_test`, `save_slots_test`, `frontend_test`, `localization_test`.

Prüfstände, Rohlogs und Darstellungsnachweis: `docs/evidence/arch30-ship-instances/`.
Keine Vollsuite-, Windows-Export-, Ziel-PC- oder FPS-Freigabe.
