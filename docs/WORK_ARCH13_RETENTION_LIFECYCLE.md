# ARCH-13-RETENTION-LIFECYCLE — Archivprüfung und laufende Schreiber

Basis `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`, gemeinsamer Kandidat von
PR #110. Branch `agent/arch13-retention-lifecycle-20260915`.

Die bisherigen Aufbewahrungsberichte verglichen den Quellbaum zweimal, hatten
aber keine Vereinbarung mit laufenden Speichervorgängen. Ein Regionscheckpoint
kann bereits neue Blobs schreiben, obwohl seine Wurzel erst später mit dem
Spielstand veröffentlicht wird. Dieses Paket hält solche Laufzeiten vom
Aufbewahrungslauf und vollständigen Benutzerarchiv getrennt.

## Verhalten

- `SaveGameService` hält eine Schreiberregistrierung für seine Lebensdauer.
  Speichern, Laden als aktive Sitzung, Anlegen, Kopieren, Umbenennen, Migration,
  Wiederherstellen und Löschen prüfen den Zugang vor ihren Änderungen.
- `RegionStore` registriert sich vor dem ersten schreibenden Zugriff und hält
  die Registrierung bis zur Freigabe des Stores. Eviction, Checkpoint und die
  Wartezeit zwischen Blobschreiben und Veröffentlichung der Save-Wurzel sind
  eingeschlossen. `AtomicJson.write()` schützt auch einzelne Aufrufe außerhalb
  der Sitzung. Verschachtelte Besitzer teilen genau eine Prozessregistrierung.
- `plan-retention`, `verify-retention` und `export-user-data` halten die gemeinsame
  Zugangssperre vor dem ersten Lesen bis nach Veröffentlichung beziehungsweise
  vollständiger Nachprüfung. Eine laufende Schreiberregistrierung verweigert den
  Vorgang, bevor ein Bericht oder Archiv angelegt wird. Ein neu startender
  Schreiber erhält währenddessen einen regulären Fehler ohne Save-Veröffentlichung.
- Bestehende Save-Schemata, Trie-Wurzeln und Generationenhashes bleiben gleich.
  Aktueller Save, Backups, Slothistorien, Kopien, Migrationsoriginale, Begegnungen
  und `living_fauna/blobs` verwenden weiter die vorhandenen Referenzprüfer.

Die Befehle bleiben unverändert. Spiel und Editor vor dem Aufruf schließen;
`--user-data` bezeichnet den vollständigen, kanonischen Godot-Benutzerordner,
keinen Unterordner und keine `user://`-Adresse:

```sh
python tools/region_backup.py plan-retention --user-data /path/to/Voxelverse --output /path/to/new-plan
python tools/region_backup.py verify-retention /path/to/new-plan --user-data /path/to/Voxelverse
python tools/region_backup.py export-user-data --user-data /path/to/Voxelverse --output /path/to/new-backup
```

## Zugangsvertrag v1

Python `tools/userdata_access.py` und Godot `core/persistence/userdata_access.gd`
verwenden atomare Verzeichnisanlage auf demselben lokalen Dateisystem. Neben
dem Benutzerordner liegen `.Voxelverse.voxelverse-access-v1` als Zugangssperre
und `.Voxelverse.voxelverse-access-v1.writers` als Prozessregister. Jeder Besitzer
hat Schema, Format, PID, Hostname, Rolle und einen zufälligen 256-Bit-Token.
Diese Koordinationsdaten liegen außerhalb der Nutzdaten und werden nicht in ein
Backup übernommen. Die bestehenden Nutzdatenberichte bleiben bytekompatibel.

| Zustand | Schreiber | Archivwerkzeug |
| --- | --- | --- |
| Freier Zugang | Token unter kurzer Zugangssperre registrieren | Zugang sperren, Schreiberregister prüfen |
| Aktive Schreiber | Weitere bestehende Prozessabläufe dürfen sich registrieren | Ohne Veröffentlichung abbrechen |
| Laufende Archivprüfung | Neue Registrierung verweigern | Zugang bis nach Prüfung/Umbenennung halten |
| Sauberes Sitzungsende | Letzter Besitzer entfernt seinen eigenen Token | Nächster Lauf ist möglich |
| Hart beendeter Schreiber | Ein neuer Spielprozess kann sich registrieren | Vollständige Token desselben Hosts erst bei sicher beendeter PID entfernen |
| Hart beendetes Archivwerkzeug | Eine verbliebene Zugangssperre verweigern | Beim erneuten Aufruf vollständige Sperre mit sicher beendeter PID übernehmen |
| Unvollständige, fremde oder neuere Sperre | Verweigern | Verweigern und Original unverändert lassen |

Es gibt keine Zeitüberschreitung, die eine laufende PID verdrängt. Wiederverwendete
PIDs werden konservativ als aktiv behandelt. Eine separate `.recovery`-Sperre
serialisiert die Wiederaufnahme durch Python; ein zweiter Wiederaufnehmer darf
keinen inzwischen neu registrierten Besitzer entfernen.

**Godot übernimmt niemals eine bestehende Zugangssperre.** Seine Unix-Abfrage
`OS.is_process_running()` kann fremde Prozesse hier nicht sicher beurteilen.
Die Python-Seite verwendet unter Unix `kill(pid, 0)`, unter Windows
`OpenProcess/GetExitCodeProcess`; verweigerter oder unklarer Zugriff bleibt aktiv.
Nach einem abgebrochenen Werkzeuglauf das Werkzeug mit einem **neuen Ausgabeziel**
erneut starten. Frühere `.partial-*` und Ziel-Locks bleiben als Abbruchnachweise
erhalten und werden nicht zur fertigen Generation erklärt.

Unvollständig geschriebene Koordinationsdaten oder eine abgebrochene Wiederaufnahme
werden nicht automatisch entfernt. In diesem Sonderfall alle betroffenen
Programme schließen und die gemeldeten Koordinationsverzeichnisse separat prüfen.
Keine automatische Reparatur unbekannter Daten und kein erzwungener Zugriff.

## Grenzen und Integration

- Ausschließlich Aufbewahrung: `retain_all`, `deletion_allowed=false`. Es gibt
  keine Blobbereinigung. Entfernt werden nur überprüfte eigene beziehungsweise
  verwaiste Koordinationstoken; alle Spiel- und Archivdateien bleiben erhalten.
- Kooperative Vereinbarung für diese Version auf einem lokalen Dateisystem mit
  demselben Host und PID-Namensraum. Alte Programme, direkte Dateischreiber,
  Netzwerkfreigaben und fremde Programme erhalten dadurch keine Schreibsperre.
  Die vollständige Inventar-Nachprüfung bleibt deshalb zusätzlich bestehen.
- Das alte selektive `export --slot ... --regions-dir ...` kann verstreute Quellen
  adressieren und behält seinen bisherigen Offline-Vertrag. Die neue gemeinsame
  Sperre gilt für die drei oben genannten vollständigen Benutzerordneroperationen.
- Mehrere Spielprozesse werden nicht zu einer transaktionalen Mehrbenutzerdatenbank.
  Die Registrierung verhindert Archivprüfungen während ihrer Aktivität, ohne
  bestehende getrennte Prozessleser der Fachtests zu blockieren.
- Kein Speicherformatwechsel, keine Änderung an ARCH-24-Körperrevisionen. Der
  kleine Anschluss an `AtomicJson.write` ergänzt nur den Zugang vor der bisherigen
  Schreibfunktion; Serialisierung und Rückfallkopie bleiben unverändert.
- Neue Python-Fachprüfung einmal in `region-backup-validate.yml`; der Godot-Probe
  ist ein von Python gesteuerter Prozessendpunkt, kein zweiter registrierter
  Godot-Fachtest. Vorhandene Save-/Regions-/Migrationsprüfungen werden wiederverwendet.
- Zentrale Statusseiten, Roadmap und Katalog aktualisiert die Integration.
  ARCH-13 insgesamt bleibt wegen späterer Bereinigung und Produktanschlüsse offen.

Prüfstände, Befunde und Befehle stehen in `docs/evidence/arch13-retention-lifecycle/README.md`.
Kein Windows-/Grafik-/Export-/Ziel-PC- oder vollständiger Integrationsnachweis.
