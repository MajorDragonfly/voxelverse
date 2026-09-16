# UI-SAVE-BROWSER-SEARCH

Fachlieferung vom 16. September 2026. Basis ist der feste Spieltestcommit
`d57b1ef385728728b132518a1ea05683888dcae0` aus #125, Branch
`agent/save-browser-search-20260916`. Unabhängig von den Fachlieferungen #131,
#132 und #134. ARCH-24 bleibt beim anderen Fachchat; ebenso Wetter, Atmosphäre,
Kreaturenrückkehr, Schiffe und Dorfwirtschaft.

## Bedienung

Startmenü → Spielstände bietet eine Suche nach Name und Weltseed. Durch
Leerzeichen getrennte Suchwörter werden gemeinsam geprüft, ohne Beachtung von
Groß-/Kleinschreibung. Strg+F/Cmd+F fokussiert die Suche; Esc verlässt zuerst
das Suchfeld und danach die Spielstandansicht. Eingaben werden nach 180 ms Ruhe
ausgewertet.

Filter: Epoche und Zustand. „Intakte Spielstände“ enthält gültige Primärdateien;
„Prüfung / Sicherung“ enthält nicht lesbare oder neuere Dateien sowie Fälle mit
verfügbarem Backup. Das ist eine Ansicht auf die Prüfung des SaveGameService,
keine neue Freigabe zum Laden. Auch nur noch durch Historie erhaltene Slots
bleiben erreichbar. Die normale Zukunftsversionssperre gilt weiterhin.

Sortierung: zuletzt gespeichert, natürlicher Name A–Z oder meiste Spielzeit.
Gleichstände werden durch den stabilen Slotpfad entschieden. Eine Seite zeigt
höchstens zwölf Slotknöpfe und deren Vorschaubilder; Zähler und Seitenwechsel
beziehen sich auf die gefilterte Gesamtmenge. Ohne Treffer verschwinden aktive
Slotaktionen. „Zurücksetzen“ entfernt Suche/Epochen-/Zustandsfilter und behält
die gewählte Sortierung.

Die Auswahl bleibt über ihren Pfad gebunden. Bei Sprachwechsel und Umordnung
bleiben ungesicherte Namen und die gewählte historische Quelldatei erhalten.
Auch vorübergehend weggefilterte Namensentwürfe werden beim erneuten Auswählen
wieder angezeigt. Das verändert keine Datei. Nach erfolgreichem Umbenennen,
Kopieren oder Wiederherstellen wird der betroffene Slot samt richtiger Seite
gezeigt; ausschließende Filter werden dafür zurückgesetzt. Bei fehlgeschlagener
Umbenennung bleiben Quelldatei, Auswahl und eingegebener Entwurf erhalten.

Breite Fenster zeigen Liste und Details nebeneinander. Kleine Fenster wechseln
über den Slotknopf bzw. „Details“ und „Ergebnisliste“ zwischen beiden Ansichten.
Auch bei 800×600 und 150 % Skalierung bleiben Filter, Seitenwechsel und eine
vollständige Ergebniszeile erreichbar; lange Aktionsbeschriftungen umbrechen.
Alle neuen Texte stehen in DE und EN zur Verfügung, Spielernamen bleiben literal.

## Anschlüsse und Umfang

- `ui/frontend/slot_browser_query.gd`: reine Filter-/Sortier-/Seitenabfrage auf
  vorhandenen Slotzusammenfassungen, ohne Schreiben oder Verändern der Quelle.
- `ui/frontend/save_browser.gd`: vorhandene Oberfläche und Auswahl; verwendet
  weiterhin `list_slots`, `inspect_slot`, `rename_slot`, `duplicate_slot` und
  `restore_slot_copy` des SaveGameService. Laden bleibt beim SessionFlow.
- 23 additive Katalogschlüssel und generierte DE/EN-PO-Dateien; ein neuer Test
  im vorhandenen Vertrag `frontend_locale`.

Keine Save-Schemaänderung, kein zusätzlicher Index und keine zweite
Speicherverwaltung. Die UI-Seite begrenzt Controls und dekodierte Listenvorschauen.
`list_slots()` liest und validiert beim Öffnen/Aktualisieren weiterhin sämtliche
Slotdateien; deren Zusammenfassungen bleiben im Speicher. Dies ist ausdrücklich
keine Umsetzung des separaten ARCH-13-Ziels eines reinen Metadatenlesers und
keine Obergrenze für die Dauer einzelner Dateizugriffe. Suche/Filter werden nur
in dieser geöffneten Ansicht gehalten.

## Nachweis

Der neue Test arbeitet mit 31 realen Slotfällen aus dem SaveGameService,
einschließlich unabhängiger Kopien, Historie, beschädigter/neuerer Datei und
Backup ohne Primärdatei. Hinzu kommen 1.005 Zusammenfassungen mit vollständiger
Seitenprüfung, echte Button-/Tastenereignisse, Dateihashes vor/nach reinem Browsen,
gescheiterte Umbenennung und zwölf DE/EN-/Größen-/Skalierungskombinationen.

Direkte Verbraucher: bestehende Save-Slot-Verträge, Lokalisierung und die
Frontend-Kette einschließlich realem Kugelstart, Kopien und Historienwiederherstellung.
Abschlussbefehl, exakter sauberer Quellcommit/Tree, ursprüngliche Fehlerbefunde
und Logs werden unter `docs/evidence/save-browser-search/` übergeben.

Godot 4.6.3/Linux/headless; native Bildprüfung, Windows-Export und Ziel-PC-Abnahme
bleiben offen. Gemeinsame Statusseiten und Integration bleiben beim
Integrationschat. Diese Lieferung wird als Draft-PR veröffentlicht und nicht gemergt.
