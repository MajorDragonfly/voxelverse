# Voxelverse: effizient zusammenarbeiten

## Freigegebener Arbeitsrahmen (Lars, 16.09.2026)

Lars hat die vorgeschlagenen Verbesserungen einschließlich dieses Arbeitsrahmens
mit „ok setz das um“ beauftragt. Für zugewiesene Voxelverse-Pakete sind Bearbeiten,
Prüfen, Committen, Push auf eigenem Branch, PR-Erstellung und zugehörige CI-Fixes
freigegeben; dafür nicht erneut um dieselbe Bestätigung bitten. „Nächstes Paket“
erlaubt die Auswahl eines passenden unbesetzten Pakets nach der zentralen Runde.
Bestehende Besitzer und bekannte Abhängigkeiten berücksichtigen.

Abgeschlossene Routinelieferungen dürfen konfliktfrei nach `main` übernommen
werden, wenn die vier Pflichtprüfungen aus `tools/workflow/main-ruleset.json`
für den aktuellen Stand erfolgreich sind, der Branch aktuell ist und alle
Abhängigkeiten integriert sind. Native Auto-Merge dafür aktivieren. Entwürfe,
ausdrückliche Merge-Sperren und fremde laufende Pakete nicht übernehmen. Solange
der Ruleset noch nicht aktiv ist, dieselben Kriterien vor einem Merge selbst
prüfen; kein grüner Entwurfsplan ersetzt die vollständige Code-Abnahme.

Neue Kosten, externe Dienste, Änderungen an Zugriffsrechten oder destruktive
Aktionen außerhalb des beauftragten Umfangs brauchen eine eigene Entscheidung.
Dieser Rahmen umgeht keine technischen Berechtigungen oder automatische Prüfung.
Ein Merge ist keine Ziel-PC-/Spielspaß-Abnahme. Einrichtung: [Entwicklungsablauf](docs/DEVELOPMENT_WORKFLOW.md).

## Einstieg und Fortsetzung

1. Lies `docs/PROJECT_STATUS.md` und den konkreten Auftrag. Bei einer Fortsetzung
   im selben Chat nutze den vorhandenen Kontext; wiederhole den Einstieg nur bei
   einer neuen Basis, einem Konflikt oder einer geänderten Anforderung.
2. `python3 tools/work_packet.py list` zeigt vorbereitete Teilaufträge.
   `python3 tools/work_packet.py show ARCH-19-TARGET-PC` gibt einen kleinen Kontext
   mit Dateien, Schreibbereichen und relevanten Prüfverträgen aus.
   `start PAKET-ID --owner CHAT` bündelt den Brief mit der datierten Basis.
   Die aktuelle Vergabe steht in [Issue #137](https://github.com/MajorDragonfly/voxelverse/issues/137);
   einmal zum Paketstart lesen (`python3 tools/project_dashboard.py round`). Eine
   neuere ausdrückliche Zuweisung hat Vorrang; fehlende Einträge bedeuten nicht frei.
3. Lies danach nur die betroffenen Implementierungen und die passenden Abschnitte
   in `docs/MODULE_CONTRACTS.md`. ROADMAP, alte Audits, alle PRs, alle Branches und
   fremde Checkouts gehören nicht zum Pflichtprogramm jedes Fachchats.
4. Hole die vereinbarte Basis einmal zum Paketstart; arbeite auf einem eigenen
   Branch/Checkout. Notiere Basis-SHA und Teilauftrags-ID. Nicht auf `main` arbeiten.
   Fremde unfertige Dateien bleiben beim Besitzer. Nutzeraufträge haben Vorrang.

## Eine Zuständigkeit pro Teilauftrag

- Eine Runde hat einen Integrationschat. Er ordnet Teilauftrags-ID, Besitzer,
  Branch, Basis-SHA und gemeinsame Schreibbereiche zu und hält die Belegung
  zentral in **einer** Rundenliste in Issue #137. Bereits laufende Chats einmal
  übernehmen; keine zweite Liste auf einem Fachbranch als Live-Belegung führen.
- Eine ARCH-Nummer allein ist keine Reservierung: ARCH-14 enthält mehrere
  unterschiedliche Lieferungen. Nutze eindeutige IDs wie `ARCH-14-ENCOUNTERS`.
- Der Paketkatalog ist ein Planungsvorschlag, keine Live-Sperre. Weder ein lokaler
  Eintrag noch ein neuer Branch reserviert Arbeit in anderen Chats. Eine unklare
  Doppelbelegung einmal mit der zentralen Zuordnung klären, nicht alle Historien lesen.
- Vor mehreren Zuweisungen: `python3 tools/work_packet.py conflicts ID ID ...`.
  Das prüft deklarierte gemeinsame Schreibbereiche, nicht sämtliche Codeabhängigkeiten.
- Gemeinsame Schreibbereiche werden nacheinander bearbeitet oder ausdrücklich
  einem Integrationsbesitzer zugeteilt. Den nötigen Anschluss im Auftrag mitführen.
  Unerwartete Änderungen daran sind ein Anlass zur Abstimmung, kein Nebenprojekt.
- Fachchats schreiben ihre kurze Übergabe im PR; `work_packet.py handoff PAKET-ID
  --base BASIS_SHA` liefert Commit/Tree/Diff vom sauberen Fachbranch, ohne Tests
  zu wiederholen. Ergebnis, Prüfbeleg und Grenzen ergänzen.
- Der Integrationschat aktualisiert `tools/workflow/project.json` einmal je Runde
  und führt `python3 tools/project_dashboard.py render` aus. README, Dashboard,
  PROJECT_STATUS und NEXT_PARALLEL_WORK werden daraus erzeugt. Fachchats pflegen
  keine Kopien der zentralen Statusdaten; historische Backlogs sind Ziel-/Kontextquellen.
  Historische Messberichte bleiben Nachweise ihres jeweiligen Stands.

## Einmal gezielt prüfen

- Verwende `tools/validation/contracts.json` als einzige Testzuordnung. Neue
  Godot-Tests genau einmal dort registrieren. `--contracts` wählt vorhandene Tests,
  zum Beispiel `python3 tools/validate_godot.py --contracts creature_body --skip-main`.
- Ein Fachchat prüft den geänderten Ablauf und betroffene direkte Verbraucher.
  Umfang nach tatsächlichem Risiko wählen; `--skip-main` eignet sich nur für ein
  abgegrenztes Paket. Save-/ID-/Körper-/Lebenszyklusänderungen brauchen ihre echten
  Fehler- und Neustartfälle. Isolierte Nutzerdaten des vorhandenen Runners nutzen.
- Import nicht unnötig wiederholen. `--skip-import` nur, wenn derselbe lokale
  Ressourcenstand bereits erfolgreich importiert wurde. CI behält seinen Import.
- Volle Suite, gemeinsame Produktions-/Reisekette und native Exporte gehören zur
  Integration. Einen bereits laufenden identischen CI-Job nicht lokal duplizieren,
  außer zur Diagnose eines konkreten Fehlers. Kein Testfehler wird wegdefiniert.
- Nachweis mit Quellcommit/Tree, sauberem Arbeitsstand, Engine, Befehl, Umgebung,
  Ergebnis und Log-/CI-Verweis übergeben. Gleicher Tree, gleicher Befehl und gleiche
  Umgebung erlauben Wiederverwendung; geänderter Merge-Tree braucht neue Prüfung.
  Bei schmutzigem Arbeitsstand zusätzlich die tatsächlich geprüften Änderungen
  identifizieren. Teilnachweise sind keine Gesamt-, Export- oder FPS-Freigabe.
- Bei unverändertem geprüften Stand stoppen. Keine wiederholten Vollabgleiche,
  umfangreichen Erfolgsausgaben oder neuen Tests für reine Textkorrekturen.

## Feste Produktgrundlage

Godot 4.6.3; Singleplayer; Kugelkampagne als einziger regulärer Spielweg;
stabile IDs und ein gemeinsamer SaveService; lokale Koordinaten und begrenzte
Nah-/Fernsimulation. Pause/geschlossenes Spiel produziert nichts. Nur die eigene
Spezies entwickelt Zivilisation, Epochenwechsel braucht Bestätigung. Gebäudeeditor
erst Mittelalter. Keine allgemeine Terrainzerstörung; kurze Orbitübergänge sind
erlaubt. Bestehende Nutzerdaten und Zukunftsversionsschutz erhalten.

Details nur bei Bedarf: `docs/PARALLEL_WORKFLOW.md`,
`docs/PROJECT_TRACKING.md`, `docs/GODOT_TECHNICAL_DIRECTION.md`, `docs/ARCHITECTURE_BACKLOG.md`.
