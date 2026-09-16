# ARCH-13-SLOT-BROWSE-BUDGET

Fachlieferung vom 16. September 2026. Branch
`agent/slot-browse-budget-20260916`, auf der Spielstandsuche #135 aufgebaut.
Fester lokaler Basiscommit `e72db08d0dd74ed9f47aac7cfb3e3d8dfa306665`,
veröffentlichter Basiscommit `7f2d4ebbf8da1af84b0ae48f93de34e817290277`,
identischer Tree `18b9c3d164036e96fdf125f4fd6bbc2cf6801733`.
Die gemeinsame Spieltestbasis darunter ist #125, `d57b1ef385728728b132518a1ea05683888dcae0`.
ARCH-24 und die anderen laufenden Fachpakete bleiben unberührt.

## Verhalten

Der Spielstandbrowser öffnet mit einer Such-/Prüfanzeige und erfasst Dateien
schrittweise. Ein Prozessframe bearbeitet entweder höchstens 64
Verzeichniseinträge (zusätzlich weiches 2-ms-Budget) oder genau eine
Slot-/Sicherungsprüfung. Erst die fertige Slotliste wird in die bestehende
Suche/Sortierung übernommen; unvollständige Ergebnisse werden nicht als
vollständiger Bestand dargestellt. Suche, Sprachwechsel und Zurück bleiben
währenddessen bedienbar. Die Detailansicht verwendet die geprüfte
Zusammenfassung und lädt ihre Sicherungen ebenfalls einzeln nach.

Erneutes Laden verwirft den vorherigen Auftrag. Auswahlwechsel verwirft die
alte Historienprüfung; deren Ergebnis kann nicht unter dem nächsten Slot
erscheinen. Verbergen, Zurück und Entfernen aus dem Szenenbaum schließen
Verzeichnisiteratoren und geben vorgemerkte Ergebnisse frei. Wiederanzeigen
startet eine neue Erfassung. Unfertige Namensentwürfe und die gewählte
Sicherungsquelle bleiben über ihren Slotpfad gebunden. Während der Erfassung
sind keine alten Slotaktionen oder Wiederherstellungsknöpfe verfügbar.

## Fachanschlüsse

`core/persistence/slot_scan.gd` ist ein kurzlebiger Leseauftrag, kein neuer
Speicher oder persistenter Index. `SaveGameService.begin_slot_scan()` und
`begin_history_scan(path)` erzeugen ihn. `advance()` führt begrenzte Arbeit
aus; `cancel()` beendet den Auftrag ohne Veröffentlichung. Es gibt keine
Threads, Timer-Callbacks oder fortlaufenden Hintergrundjobs nach dem Verlassen.

Die synchronen Adapter `list_slots()` und `list_slot_history()` behalten
Ergebnisformat, Reihenfolge, Inhaltserkennung und Historien-Deduplizierung.
Beide nutzen denselben Leseauftrag. Validierung und Zukunftsversionsschutz
bleiben beim SaveGameService. Primärdateien, Backups ohne Primärdatei,
Historien ohne Primärdatei sowie der alte Standardspeicherpfad bleiben sichtbar.
Nach fehlgeschlagener Bereinigung vorhandene zusätzliche Sicherungen werden
weiterhin gelesen; der Browser schneidet sie nicht auf acht ab.

Die Listenansicht liest keine ausgewählte Datei noch einmal für deren Details.
Laden, Kopieren, Umbenennen und Wiederherstellen prüfen den tatsächlichen
Plattenstand weiterhin über den bisherigen Service. `select_slot(path)` prüft
nur den gültigen Zielpfad und dessen Inhalt, statt dafür alle anderen
Spielstände erneut einzulesen. Es entsteht keine Schreibberechtigung aus einem
veralteten UI-Ergebnis. Keine Save-Schemaänderung, Migration oder Indexdatei.

## Grenzen

Eine einzelne Dateiprüfung bleibt synchron: JSON-Parsing, Blobprüfung,
Backupprüfung und Historienzählung können länger als einen Frame dauern.
Das 2-ms-Ziel ist ausdrücklich **keine** harte Framezeitgarantie. Sortierung,
Filterung und Listenveröffentlichung verarbeiten weiterhin die vollständigen
Zusammenfassungen. Es gibt keine feste Speicherobergrenze und keinen
Metadaten-Cache. Der bestehende Menüpfad „Fortsetzen“ verwendet weiterhin den
synchronen `latest_slot()`-Adapter; dieses Paket betrifft den Spielstandbrowser
und die gezielte Slot-Auswahl. Reine Metadaten, weitere Aufteilung großer
Einzeldateien sowie native Windows-/Ziel-PC-Messungen bleiben offen.

## Gezielte Prüfung

- `slot_scan_test`: echte Dateien und Historien, Verzeichnisbudget einschließlich
  140 irrelevanter Dateien, Standardspeicher, Zukunftsprimärdatei mit gültigem
  Backup, Historienüberhang/Deduplizierung, Abbruch, Wiederholen, Sichtbarkeit,
  schnelles Umschalten, echte Tasteneingaben und Dateihashes vor/nach Browsen.
  Nachträglich auf Zukunftsversion geänderte Dateien müssen trotz früherer
  gültiger Zusammenfassung Laden/Kopieren sperren.
- `save_browser_search_test`: bestehende 31 Slotfälle, Seiten, Such-/Filterwahl,
  tatsächliche Kopie/Umbenennung/Wiederherstellung, absichtlicher Schreibfehler,
  DE/EN in zwölf Größen-/Skalierungskombinationen. Wartet nun auf Ladeabschluss.
- `save_slots_test`: bestehende Speicher-, Identitäts-, Backup- und
  Wiederherstellungsverträge der synchronen Verbraucher.
- `localization_test` und `frontend_test`: tatsächliche direkte Menüverbraucher;
  deren Prüfschritte warten auf den asynchronen Browser statt auf feste Frames.

Godot 4.6.3, Linux Headless, isolierte Nutzerdaten des vorhandenen Runners.
Finaler Quellcommit, Tree, Befehl, Ergebnis und Rohlogs werden unter
`docs/evidence/slot-browse-budget/` und in der PR-Übergabe festgehalten.
Kein Gesamtspiel-, nativer Grafik-, Export- oder FPS-Nachweis. Zentrale
Statusdokumente bleiben beim Integrationschat.
